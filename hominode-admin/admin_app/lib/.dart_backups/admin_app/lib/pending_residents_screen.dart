import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.all(16),
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
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resident.name.isEmpty ? 'Unnamed resident' : resident.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
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
          _row(
            Icons.schedule,
            resident.registeredAt == null
                ? 'Registration date unavailable'
                : DateFormat.yMMMd().add_jm().format(resident.registeredAt!),
          ),
          const SizedBox(height: 14),
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
            ],
          ),
        ],
      ),
    ),
  );

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 17, color: Colors.grey[600]),
        const SizedBox(width: 8),
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
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    controller.dispose();
  }
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
  bool busy = false;
  bool _triedBuildingReference = false;
  bool _triedUnitReference = false;
  Set<String> _canonicalBuildingIds = const {};
  Set<String> _canonicalFlatIds = const {};

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
      _canonicalBuildingIds.contains(buildingId) &&
      _canonicalFlatIds.contains(unitId);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Canonical resident assignment'),
    content: SizedBox(
      width: 420,
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
              const SizedBox(height: 16),
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
            ? const SizedBox(
                width: 18,
                height: 18,
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
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
