import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'models/pending_resident.dart';
import 'services/building_service.dart';
import 'services/flat_service.dart';
import 'services/resident_service.dart';
import 'widgets/standard_header.dart';

class PendingResidentsScreen extends StatelessWidget {
  PendingResidentsScreen({super.key});
  final ResidentService _residents = ResidentService();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: CustomScrollView(
      slivers: [
        const StandardHeader(title: 'Pending Residents'),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: StreamBuilder<List<PendingResident>>(
            stream: _residents.watchPendingResidents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Unable to load pending residents: ${snapshot.error}',
                    ),
                  ),
                );
              }
              final residents = snapshot.data ?? const [];
              if (residents.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No pending resident registrations'),
                  ),
                );
              }
              return SliverList.builder(
                itemCount: residents.length,
                itemBuilder: (context, index) => _ResidentCard(
                  resident: residents[index],
                  residents: _residents,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.resident, required this.residents});
  final PendingResident resident;
  final ResidentService residents;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.only(bottom: 12.h),
    child: Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resident.name.isEmpty ? 'Unnamed resident' : resident.name,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.h),
          _row(Icons.phone_outlined, resident.phoneNumber),
          if (resident.email != null)
            _row(Icons.email_outlined, resident.email!),
          _row(
            Icons.apartment_outlined,
            'Submitted building: ${resident.buildingReference.isEmpty ? "Not provided" : resident.buildingReference}',
          ),
          _row(
            Icons.home_outlined,
            'Submitted unit: ${resident.unitReference.isEmpty ? "Not provided" : resident.unitReference}',
          ),
          if (resident.residentType?.trim().isNotEmpty == true)
            _row(
              Icons.person_outline,
              'Resident type: ${resident.residentType}',
            ),
          if (resident.creationSource?.trim().isNotEmpty == true)
            _row(
              Icons.how_to_reg_outlined,
              'Registration source: ${resident.creationSource}',
            ),
          _row(
            Icons.verified_user_outlined,
            'Identity: ${resident.identityVerificationStatus}',
          ),
          _row(
            Icons.schedule,
            resident.registeredAt == null
                ? 'Registration date unavailable'
                : DateFormat.yMMMd().add_jm().format(resident.registeredAt!),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      _ApprovalDialog(resident: resident, residents: residents),
                ),
                child: const Text('Review & approve'),
              ),
              OutlinedButton(
                onPressed: () => _reasonAction(
                  context,
                  'Reject registration',
                  (reason) => residents.rejectResident(
                    userId: resident.uid,
                    reason: reason,
                  ),
                ),
                child: const Text('Reject'),
              ),
              if (resident.hasIdentityProof &&
                  resident.identityVerificationStatus == 'pending')
                OutlinedButton.icon(
                  onPressed: () => _reviewIdentityProof(context),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Review identity proof'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _row(IconData icon, String text) => Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      children: [
        Icon(icon, size: 17.w, color: Colors.grey[600]),
        SizedBox(width: 8.w),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Future<void> _reasonAction(
    BuildContext context,
    String title,
    Future<void> Function(String?) action,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      controller.dispose();
      return;
    }
    try {
      await action(controller.text);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title completed')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResidentService.errorMessage(error)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _reviewIdentityProof(BuildContext context) async {
    try {
      final url = await residents.getIdentityProofUrl(resident.uid);
      if (!context.mounted) return;
      final decision = await showDialog<bool>(
        context: context,
        builder: (_) =>
            IdentityProofReviewDialog(proofImage: NetworkImage(url)),
      );
      if (decision == null) return;
      await residents.reviewIdentityProof(
        userId: resident.uid,
        verified: decision,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision
                  ? 'Identity proof verified.'
                  : 'Identity proof rejected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResidentService.errorMessage(error)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class IdentityProofReviewDialog extends StatefulWidget {
  const IdentityProofReviewDialog({super.key, required this.proofImage});

  final ImageProvider proofImage;

  @override
  State<IdentityProofReviewDialog> createState() =>
      _IdentityProofReviewDialogState();
}

class _IdentityProofReviewDialogState extends State<IdentityProofReviewDialog> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _previewLoaded = false;
  bool _previewFailed = false;
  bool isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToImage();
  }

  void _subscribeToImage() {
    final previousListener = _listener;
    if (previousListener != null) {
      _stream?.removeListener(previousListener);
    }
    _previewLoaded = false;
    _previewFailed = false;
    final stream = widget.proofImage.resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (_, synchronousCall) =>
          _setPreviewState(loaded: true, synchronousCall: synchronousCall),
      onError: (_, __) => _setPreviewState(loaded: false),
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _setPreviewState({required bool loaded, bool synchronousCall = false}) {
    void update() {
      if (!mounted) return;
      setState(() {
        _previewLoaded = loaded;
        _previewFailed = !loaded;
      });
    }

    if (synchronousCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review identity proof'),
    content: SizedBox(
      width: 420.w,
      child: _previewFailed
          ? const Text(
              'The proof preview could not be loaded. Do not verify it.',
              style: TextStyle(color: Colors.red),
            )
          : Image(
              image: widget.proofImage,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'The proof preview could not be loaded. Do not verify it.',
                style: TextStyle(color: Colors.red),
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: isSubmitting ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      OutlinedButton(
        onPressed: isSubmitting ? null : () => Navigator.pop(context, false),
        child: const Text('Reject'),
      ),
      FilledButton(
        onPressed: (!_previewLoaded || isSubmitting)
            ? null
            : () async {
                setState(() => isSubmitting = true);

                // Return true to the caller so it can perform verification.
                Navigator.pop(context, true);
              },
        child: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Verify'),
      ),
    ],
  );
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.resident, required this.residents});
  final PendingResident resident;
  final ResidentService residents;
  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _buildings = BuildingService();
  final _flats = FlatService();
  String? buildingId;
  String? unitId;
  late String residentType;
  bool busy = false;
  bool _triedBuildingReference = false;
  bool _triedUnitReference = false;
  Set<String> _canonicalBuildingIds = const {};
  Set<String> _canonicalFlatIds = const {};

  @override
  void initState() {
    super.initState();
    final initial =
        (widget.resident.residentType ??
                widget.resident.declaredResidentType ??
                'owner')
            .trim()
            .toLowerCase();
    residentType = initial == 'tenant' ? 'tenant' : 'owner';
  }

  String _normalized(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void _preselectBuilding(List<BuildingModel> buildings) {
    if (_triedBuildingReference || buildingId != null) return;
    _triedBuildingReference = true;
    final reference = _normalized(widget.resident.buildingReference);
    if (reference.isEmpty) return;
    final matches = buildings.where(
      (building) =>
          _normalized(building.name) == reference ||
          _normalized(building.buildingName ?? '') == reference,
    );
    if (matches.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || buildingId != null) return;
        setState(() {
          buildingId = matches.single.id;
          unitId = null;
          _triedUnitReference = false;
        });
      });
    }
  }

  void _preselectFlat(List<FlatModel> flats) {
    if (_triedUnitReference || unitId != null) return;
    _triedUnitReference = true;
    final reference = _normalized(widget.resident.unitReference);
    if (reference.isEmpty) return;
    final matches = flats.where(
      (flat) =>
          _normalized(flat.flatId) == reference ||
          _normalized(flat.id) == reference,
    );
    if (matches.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || unitId != null) return;
        setState(() => unitId = matches.single.id);
      });
    }
  }

  bool get _canApprove =>
      !busy &&
      buildingId != null &&
      unitId != null &&
      (residentType != 'tenant' ||
          widget.resident.identityVerificationStatus == 'verified') &&
      _canonicalBuildingIds.contains(buildingId) &&
      _canonicalFlatIds.contains(unitId);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Canonical resident assignment'),
    content: SizedBox(
      width: 420.w,
      child: StreamBuilder<List<BuildingModel>>(
        stream: _buildings.getBuildings(),
        builder: (context, buildingsSnapshot) {
          if (buildingsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (buildingsSnapshot.hasError) {
            return Text(
              'Unable to load buildings: ${buildingsSnapshot.error}',
              style: const TextStyle(color: Colors.red),
            );
          }
          final buildings = buildingsSnapshot.data ?? [];
          _canonicalBuildingIds = buildings.map((item) => item.id).toSet();
          if (buildingId != null &&
              !_canonicalBuildingIds.contains(buildingId)) {
            buildingId = null;
            unitId = null;
          }
          _preselectBuilding(buildings);
          if (buildings.isEmpty) {
            return Text(
              'No canonical buildings exist for community '
              '${widget.resident.communityId}. Create or migrate a building '
              'with this communityId before approving this resident.',
              style: const TextStyle(color: Colors.red),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: residentType,
                decoration: const InputDecoration(labelText: 'Resident type'),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                ],
                onChanged:
                    busy ||
                        widget.resident.residentType != null ||
                        widget.resident.declaredResidentType != null
                    ? null
                    : (value) =>
                          setState(() => residentType = value ?? residentType),
              ),
              if (residentType == 'tenant' &&
                  widget.resident.identityVerificationStatus != 'verified')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Verify the tenant identity proof before approval.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                initialValue: buildingId,
                decoration: const InputDecoration(
                  labelText: 'Building / tower',
                ),
                items: buildings
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        buildingId = value;
                        unitId = null;
                        _canonicalFlatIds = const {};
                        _triedUnitReference = false;
                      }),
              ),
              SizedBox(height: 16.h),
              if (buildingId == null)
                const Text(
                  'Select a canonical building. Submitted references are informational only.',
                )
              else
                StreamBuilder<List<FlatModel>>(
                  stream: _flats.getFlatsForBuilding(buildingId!),
                  builder: (context, flatsSnapshot) {
                    if (flatsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (flatsSnapshot.hasError) {
                      return Text(
                        'Unable to load units: ${flatsSnapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    final flats = (flatsSnapshot.data ?? []).where((flat) {
                      return flat.status == 'vacant' ||
                          (flat.status == 'occupied' &&
                              flat.residentUserId == widget.resident.uid);
                    }).toList();
                    _canonicalFlatIds = flats.map((item) => item.id).toSet();
                    if (unitId != null && !_canonicalFlatIds.contains(unitId)) {
                      unitId = null;
                    }
                    _preselectFlat(flats);
                    if (flats.isEmpty) {
                      return const Text(
                        'No available canonical units exist in this building.',
                        style: TextStyle(color: Colors.red),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: unitId,
                      decoration: const InputDecoration(
                        labelText: 'Unit / flat',
                      ),
                      items: flats
                          .map(
                            (f) => DropdownMenuItem(
                              value: f.id,
                              child: Text('${f.flatId} — ${f.status}'),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => unitId = value),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _canApprove ? _approve : null,
        child: busy
            ? SizedBox(
                width: 18.w,
                height: 18.h,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Approve'),
      ),
    ],
  );

  Future<void> _approve() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      await widget.residents.approveResident(
        userId: widget.resident.uid,
        buildingId: buildingId!,
        flatId: unitId!,
        residentType: residentType,
      );
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('${widget.resident.name} approved successfully'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResidentService.errorMessage(error)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
