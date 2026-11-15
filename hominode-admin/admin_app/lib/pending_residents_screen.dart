import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'models/pending_resident.dart';
import 'services/building_service.dart';
import 'services/flat_service.dart';
import 'services/resident_service.dart';
import 'widgets/standard_header.dart';

String _residentTypeLabel(String value) => switch (value.trim().toLowerCase()) {
  'owner' => 'resident_owner'.tr(),
  'tenant' => 'resident_tenant'.tr(),
  _ => value,
};

String _flatStatusLabel(String value) => switch (value.trim().toLowerCase()) {
  'vacant' => 'unit_status_vacant'.tr(),
  'occupied' => 'unit_status_occupied'.tr(),
  'maintenance' => 'unit_status_maintenance'.tr(),
  'reserved' => 'unit_status_reserved'.tr(),
  _ => value,
};

class PendingResidentsScreen extends StatelessWidget {
  PendingResidentsScreen({
    super.key,
    ResidentService? residents,
    this.buildings,
    this.flats,
  }) : _residents = residents ?? ResidentService();
  final ResidentService _residents;
  final BuildingService? buildings;
  final FlatService? flats;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    body: CustomScrollView(
      slivers: [
        StandardHeader(title: 'resident_pending_title'.tr()),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: StreamBuilder<List<PendingResident>>(
            stream: _residents.watchPendingResidents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'resident_pending_load_failed'.tr(
                        namedArgs: {'error': '${snapshot.error}'},
                      ),
                    ),
                  ),
                );
              }
              final residents = snapshot.data ?? const [];
              if (residents.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Text('resident_no_pending'.tr())),
                );
              }
              return SliverList.builder(
                itemCount: residents.length,
                itemBuilder: (context, index) => _ResidentCard(
                  key: ValueKey(residents[index].uid),
                  resident: residents[index],
                  residents: _residents,
                  buildings: buildings,
                  flats: flats,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ResidentCard extends StatefulWidget {
  const _ResidentCard({
    super.key,
    required this.resident,
    required this.residents,
    this.buildings,
    this.flats,
  });
  final PendingResident resident;
  final ResidentService residents;
  final BuildingService? buildings;
  final FlatService? flats;

  @override
  State<_ResidentCard> createState() => _ResidentCardState();
}

class _ResidentCardState extends State<_ResidentCard> {
  PendingResident get resident => widget.resident;
  ResidentService get residents => widget.residents;
  bool _proofDialogOpen = false;
  bool _registrationDialogOpen = false;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.only(bottom: 12.h),
    child: Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resident.name.isEmpty ? 'resident_unnamed'.tr() : resident.name,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.h),
          _row(Icons.phone_outlined, resident.phoneNumber),
          if (resident.email != null)
            _row(Icons.email_outlined, resident.email!),
          _row(
            Icons.apartment_outlined,
            'resident_submitted_building'.tr(
              namedArgs: {
                'building': resident.buildingReference.isEmpty
                    ? 'not_provided'.tr()
                    : resident.buildingReference,
              },
            ),
          ),
          _row(
            Icons.home_outlined,
            'resident_submitted_unit'.tr(
              namedArgs: {
                'unit': resident.unitReference.isEmpty
                    ? 'not_provided'.tr()
                    : resident.unitReference,
              },
            ),
          ),
          if (resident.residentType?.trim().isNotEmpty == true)
            _row(
              Icons.person_outline,
              'resident_type_summary'.tr(
                namedArgs: {'type': _residentTypeLabel(resident.residentType!)},
              ),
            ),
          if (resident.creationSource?.trim().isNotEmpty == true)
            _row(
              Icons.how_to_reg_outlined,
              'resident_registration_source'.tr(
                namedArgs: {'source': resident.creationSource!},
              ),
            ),
          _row(
            Icons.verified_user_outlined,
            'resident_identity_status'.tr(
              namedArgs: {'status': resident.identityVerificationStatus},
            ),
          ),
          _row(
            Icons.schedule,
            resident.registeredAt == null
                ? 'resident_registration_date_unavailable'.tr()
                : DateFormat.yMMMd().add_jm().format(resident.registeredAt!),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8,
            children: [
              if (resident.canApproveRegistration)
                FilledButton(
                  onPressed: _registrationDialogOpen
                      ? null
                      : () => _showRegistrationDialog(
                          (_) => _ApprovalDialog(
                            resident: resident,
                            residents: residents,
                            buildings: widget.buildings,
                            flats: widget.flats,
                          ),
                        ),
                  child: Text('resident_approve_registration_action'.tr()),
                ),
              if (resident.canReviewRegistration)
                OutlinedButton(
                  onPressed: _registrationDialogOpen
                      ? null
                      : () => _showRegistrationDialog(
                          (_) => _RegistrationRejectionDialog(
                            resident: resident,
                            residents: residents,
                          ),
                        ),
                  child: Text('resident_reject_registration_action'.tr()),
                ),
              if (resident.hasIdentityProof &&
                  resident.identityVerificationStatus == 'pending')
                OutlinedButton.icon(
                  onPressed: _registrationDialogOpen
                      ? null
                      : () => _reviewIdentityProof(context),
                  icon: const Icon(Icons.badge_outlined),
                  label: Text('resident_review_identity_proof'.tr()),
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

  Future<void> _showRegistrationDialog(WidgetBuilder builder) async {
    if (_registrationDialogOpen ||
        !(resident.canReviewRegistration || resident.canApproveRegistration)) {
      return;
    }
    setState(() => _registrationDialogOpen = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: builder,
      );
    } finally {
      if (mounted) setState(() => _registrationDialogOpen = false);
    }
  }

  Future<void> _reviewIdentityProof(BuildContext context) async {
    if (_proofDialogOpen) return;
    _proofDialogOpen = true;
    final uid = resident.uid;
    final service = residents;
    try {
      final decision = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IdentityProofReviewDialog(
          key: ValueKey('identity-proof-$uid'),
          residentId: uid,
          loadProof: () async {
            try {
              final url = await service.getIdentityProofUrl(uid);
              return NetworkImage(url);
            } on FirebaseFunctionsException catch (error) {
              if (error.code == 'not-found') return null;
              rethrow;
            }
          },
          onReview: (verified) =>
              service.reviewIdentityProof(userId: uid, verified: verified),
        ),
      );
      if (decision == null) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision
                  ? 'resident_identity_proof_verified'.tr()
                  : 'resident_identity_proof_rejected'.tr(),
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
    } finally {
      _proofDialogOpen = false;
    }
  }
}

enum _ProofState { loading, ready, failed, missing }

class IdentityProofReviewDialog extends StatefulWidget {
  const IdentityProofReviewDialog({
    super.key,
    this.residentId,
    this.proofImage,
    this.loadProof,
    required this.onReview,
    this.loadTimeout = const Duration(seconds: 30),
  }) : assert(proofImage != null || loadProof != null);

  final String? residentId;
  final ImageProvider? proofImage;

  /// Null means the backend confirmed that no uploaded proof exists.
  final Future<ImageProvider?> Function()? loadProof;
  final Future<void> Function(bool verified) onReview;
  final Duration loadTimeout;

  @override
  State<IdentityProofReviewDialog> createState() =>
      _IdentityProofReviewDialogState();
}

class _IdentityProofReviewDialogState extends State<IdentityProofReviewDialog> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;
  Timer? _timer;
  int _generation = 0;
  bool _started = false;
  _ProofState _proofState = _ProofState.loading;
  bool isSubmitting = false;
  String? _submissionError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startLoad();
    }
  }

  @override
  void didUpdateWidget(covariant IdentityProofReviewDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.residentId != widget.residentId ||
        oldWidget.proofImage != widget.proofImage) {
      _startLoad();
    }
  }

  void _detach() {
    _timer?.cancel();
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _clearImage() {
    final image = _image;
    _image = null;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
  }

  void _startLoad() {
    _detach();
    _clearImage();
    final generation = ++_generation;
    _proofState = _ProofState.loading;
    isSubmitting = false;
    _submissionError = null;
    _timer = Timer(widget.loadTimeout, () => _finishFailure(generation));
    _load(generation);
  }

  bool _isCurrent(int generation) => mounted && generation == _generation;

  void _finishFailure(int generation, {bool missing = false}) {
    if (!_isCurrent(generation)) return;
    ++_generation; // Ignore fetches or image callbacks completing after failure/timeout.
    _detach();
    setState(
      () => _proofState = missing ? _ProofState.missing : _ProofState.failed,
    );
  }

  void _retry() {
    if (_proofState == _ProofState.loading || isSubmitting) return;
    setState(_startLoad);
  }

  Future<void> _load(int generation) async {
    try {
      final provider = widget.loadProof != null
          ? await widget.loadProof!()
          : widget.proofImage;
      if (!mounted || generation != _generation) return;
      if (provider == null) {
        _finishFailure(generation, missing: true);
        return;
      }
      final stream = provider.resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener(
        (image, synchronousCall) {
          void show() {
            if (!_isCurrent(generation)) {
              image.dispose();
              return;
            }
            _timer?.cancel();
            _clearImage();
            setState(() {
              _image = image;
              _proofState = _ProofState.ready;
            });
          }

          if (synchronousCall) {
            WidgetsBinding.instance.addPostFrameCallback((_) => show());
          } else {
            show();
          }
        },
        onError: (_, __) {
          // Some image providers report cached errors synchronously during build.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _finishFailure(generation),
          );
        },
      );
      _stream = stream;
      _listener = listener;
      stream.addListener(listener);
    } catch (_) {
      // Never log signed URLs, document contents, or raw image/transport errors.
      _finishFailure(generation);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _detach();
    _clearImage();
    super.dispose();
  }

  Future<void> _submit(bool verified) async {
    if (isSubmitting || _proofState != _ProofState.ready) return;
    final generation = _generation;
    setState(() {
      isSubmitting = true;
      _submissionError = null;
    });
    try {
      await widget.onReview(verified);
      if (!mounted || generation != _generation) return;
      setState(() => isSubmitting = false);
      Navigator.pop(context, verified);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      setState(() {
        isSubmitting = false;
        _submissionError = ResidentService.errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !isSubmitting,
    child: AlertDialog(
      title: Text('resident_review_identity_proof'.tr()),
      content: SizedBox(
        width: 420.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_submissionError != null)
              Text(
                _submissionError!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_proofState == _ProofState.loading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('resident_proof_loading'.tr()),
            ] else if (_proofState == _ProofState.ready)
              Flexible(
                child: Semantics(
                  label: 'resident_proof_preview'.tr(),
                  image: true,
                  child: RawImage(
                    image: _image?.image,
                    fit: BoxFit.contain,
                    scale: _image?.scale ?? 1,
                  ),
                ),
              )
            else ...[
              Text(
                (_proofState == _ProofState.missing
                        ? 'resident_proof_missing'
                        : 'resident_proof_load_failed')
                    .tr(),
                style: const TextStyle(color: Colors.red),
              ),
              TextButton(
                onPressed: _retry,
                child: Text('resident_proof_retry'.tr()),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        OutlinedButton(
          onPressed: isSubmitting || _proofState != _ProofState.ready
              ? null
              : () => _submit(false),
          child: Text('resident_reject_identity_action'.tr()),
        ),
        FilledButton(
          onPressed: isSubmitting || _proofState != _ProofState.ready
              ? null
              : () => _submit(true),
          child: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('resident_verify_identity_action'.tr()),
        ),
      ],
    ),
  );
}

class _RegistrationRejectionDialog extends StatefulWidget {
  const _RegistrationRejectionDialog({
    required this.resident,
    required this.residents,
  });
  final PendingResident resident;
  final ResidentService residents;
  @override
  State<_RegistrationRejectionDialog> createState() =>
      _RegistrationRejectionDialogState();
}

class _RegistrationRejectionDialogState
    extends State<_RegistrationRejectionDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    if (_busy || !widget.resident.canReviewRegistration) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.residents.rejectResident(
        userId: widget.resident.uid,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('resident_registration_rejected_success'.tr())),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = ResidentService.errorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('resident_reject_registration_action'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('resident_registration_rejection_confirmation'.tr()),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'resident_reason_optional'.tr(),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_busy) ...[
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
            Text('resident_registration_processing'.tr()),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: _busy ? null : _reject,
          child: Text('resident_reject_registration_action'.tr()),
        ),
      ],
    ),
  );
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({
    required this.resident,
    required this.residents,
    this.buildings,
    this.flats,
  });
  final PendingResident resident;
  final ResidentService residents;
  final BuildingService? buildings;
  final FlatService? flats;
  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  late final _buildings = widget.buildings ?? BuildingService();
  late final _flats = widget.flats ?? FlatService();
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
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text('resident_canonical_assignment_title'.tr()),
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
                'resident_building_load_failed'.tr(
                  namedArgs: {'error': '${buildingsSnapshot.error}'},
                ),
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
                'resident_no_canonical_buildings'.tr(
                  namedArgs: {'community': widget.resident.communityId},
                ),
                style: const TextStyle(color: Colors.red),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: residentType,
                  decoration: InputDecoration(
                    labelText: 'resident_type_label'.tr(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'owner',
                      child: Text('resident_owner'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'tenant',
                      child: Text('resident_tenant'.tr()),
                    ),
                  ],
                  onChanged:
                      busy ||
                          widget.resident.residentType != null ||
                          widget.resident.declaredResidentType != null
                      ? null
                      : (value) => setState(
                          () => residentType = value ?? residentType,
                        ),
                ),
                if (residentType == 'tenant' &&
                    widget.resident.identityVerificationStatus != 'verified')
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'resident_verify_tenant_identity_first'.tr(),
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  initialValue: buildingId,
                  decoration: InputDecoration(
                    labelText: 'resident_building_tower'.tr(),
                  ),
                  items: buildings
                      .map(
                        (b) =>
                            DropdownMenuItem(value: b.id, child: Text(b.name)),
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
                  Text('resident_select_canonical_building'.tr())
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
                          'resident_units_load_failed'.tr(
                            namedArgs: {'error': '${flatsSnapshot.error}'},
                          ),
                          style: const TextStyle(color: Colors.red),
                        );
                      }
                      final flats = (flatsSnapshot.data ?? []).where((flat) {
                        return flat.status == 'vacant' ||
                            (flat.status == 'occupied' &&
                                flat.residentUserId == widget.resident.uid) ||
                            (flat.status == 'reserved' &&
                                flat.id == widget.resident.flatId &&
                                flat.buildingId == widget.resident.buildingId &&
                                flat.reservedOnboardingId != null);
                      }).toList();
                      _canonicalFlatIds = flats.map((item) => item.id).toSet();
                      if (unitId != null &&
                          !_canonicalFlatIds.contains(unitId)) {
                        unitId = null;
                      }
                      _preselectFlat(flats);
                      if (flats.isEmpty) {
                        return Text(
                          'resident_no_available_units'.tr(),
                          style: TextStyle(color: Colors.red),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: unitId,
                        decoration: InputDecoration(
                          labelText: 'resident_unit_flat'.tr(),
                        ),
                        items: flats
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(
                                  '${f.flatId} — ${_flatStatusLabel(f.status)}',
                                ),
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
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: _canApprove ? _approve : null,
          child: busy
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('resident_approve_action'.tr()),
        ),
      ],
    ),
  );

  Future<void> _approve() async {
    if (!_canApprove) return;
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
            content: Text(
              'resident_approved_successfully'.tr(
                namedArgs: {'name': widget.resident.name},
              ),
            ),
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
