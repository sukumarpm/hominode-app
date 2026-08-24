import 'package:flutter/material.dart';

import 'models/admin_profile.dart';
import 'models/tenant_config.dart';
import 'services/admin_registry_service.dart';
import 'services/tenant_registry_service.dart';

class SuperAdminAdminsScreen extends StatefulWidget {
  const SuperAdminAdminsScreen({this.adminsLoader, super.key});
  final Future<List<AdminProfile>> Function()? adminsLoader;
  @override
  State<SuperAdminAdminsScreen> createState() => _SuperAdminAdminsScreenState();
}

class _SuperAdminAdminsScreenState extends State<SuperAdminAdminsScreen> {
  AdminRegistryService? _registry;
  AdminRegistryService get _service => _registry ??= AdminRegistryService();
  late Future<List<AdminProfile>> _admins = _load();
  Future<List<AdminProfile>> _load() =>
      widget.adminsLoader?.call() ?? _service.getAdmins();
  void _refresh() => setState(() => _admins = _load());

  Future<void> _create() async {
    final tenants = await TenantRegistryService().getActiveTenants();
    if (!mounted) return;
    if (await showDialog<bool>(
          context: context,
          builder: (_) =>
              _AdminProvisionDialog(service: _service, tenants: tenants),
        ) ==
        true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admins'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.person_add),
      label: const Text('Provision admin'),
    ),
    body: RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<AdminProfile>>(
        future: _admins,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Unable to load admins: ${snapshot.error}'),
                ),
              ],
            );
          }
          final admins = snapshot.data ?? const [];
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 210,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: admins.length,
                itemBuilder: (_, index) => _AdminCard(
                  profile: admins[index],
                  onOpen: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SuperAdminAdminDetailsScreen(
                          profile: admins[index],
                        ),
                      ),
                    );
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.profile, required this.onOpen});
  final AdminProfile profile;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    profile.phoneNumber.isEmpty
                        ? profile.uid
                        : profile.phoneNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(profile.isActive ? 'Active' : 'Inactive')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Role: ${profile.role}'),
            Text(
              'Communities: ${profile.authorizedCommunityIds.isEmpty ? 'None' : profile.authorizedCommunityIds.join(', ')}',
            ),
            const Spacer(),
            Text('Created: ${profile.createdAt?.toIso8601String() ?? '—'}'),
            Text('Updated: ${profile.updatedAt?.toIso8601String() ?? '—'}'),
          ],
        ),
      ),
    ),
  );
}

class SuperAdminAdminDetailsScreen extends StatefulWidget {
  const SuperAdminAdminDetailsScreen({required this.profile, super.key});
  final AdminProfile profile;
  @override
  State<SuperAdminAdminDetailsScreen> createState() =>
      _SuperAdminAdminDetailsScreenState();
}

class _SuperAdminAdminDetailsScreenState
    extends State<SuperAdminAdminDetailsScreen> {
  final _service = AdminRegistryService();
  late AdminProfile _profile = widget.profile;
  Future<void> _assign() async {
    final tenants = await TenantRegistryService().getActiveTenants();
    if (!mounted) return;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AssignmentDialog(
        tenants: tenants,
        selected: _profile.authorizedCommunityIds,
      ),
    );
    if (selected == null) return;
    await _service.updateAssignments(_profile.uid, selected);
    setState(
      () => _profile = AdminProfile(
        uid: _profile.uid,
        phoneNumber: _profile.phoneNumber,
        role: _profile.role,
        isActive: _profile.isActive,
        authorizedCommunityIds: selected,
        createdAt: _profile.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _status() async {
    if (_profile.isSuperAdmin) return;
    if (_profile.isActive) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Deactivate admin?'),
              content: Text(
                '${_profile.phoneNumber} will immediately fail Admin authorization.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Deactivate'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }
    await _service.setAdminActive(_profile.uid, !_profile.isActive);
    setState(
      () => _profile = AdminProfile(
        uid: _profile.uid,
        phoneNumber: _profile.phoneNumber,
        role: _profile.role,
        isActive: !_profile.isActive,
        authorizedCommunityIds: _profile.authorizedCommunityIds,
        createdAt: _profile.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin details')),
    body: FutureBuilder<List<TenantConfig>>(
      future: TenantRegistryService().getTenants(),
      builder: (context, snapshot) {
        final names = {
          for (final tenant in snapshot.data ?? const <TenantConfig>[])
            tenant.communityId: tenant.name,
        };
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in <String, String>{
              'UID': _profile.uid,
              'Phone': _profile.phoneNumber,
              'Role': _profile.role,
              'Status': _profile.isActive ? 'Active' : 'Inactive',
              'Assigned communities': _profile.authorizedCommunityIds
                  .map((id) => names[id] ?? id)
                  .join(', '),
              'Authorized community IDs': _profile.authorizedCommunityIds.join(
                ', ',
              ),
              'Created at': _profile.createdAt?.toIso8601String() ?? '',
              'Updated at': _profile.updatedAt?.toIso8601String() ?? '',
            }.entries)
              ListTile(
                title: Text(entry.key),
                subtitle: Text(entry.value.isEmpty ? '—' : entry.value),
              ),
            if (_profile.isAdmin) ...[
              FilledButton.tonal(
                onPressed: _assign,
                child: const Text('Edit community assignments'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _status,
                child: Text(
                  _profile.isActive ? 'Deactivate admin' : 'Activate admin',
                ),
              ),
            ] else
              const ListTile(
                title: Text('Protected superAdmin'),
                subtitle: Text(
                  'Role and status changes require a separate privileged workflow.',
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _AdminProvisionDialog extends StatefulWidget {
  const _AdminProvisionDialog({required this.service, required this.tenants});
  final AdminRegistryService service;
  final List<TenantConfig> tenants;
  @override
  State<_AdminProvisionDialog> createState() => _AdminProvisionDialogState();
}

class _AdminProvisionDialogState extends State<_AdminProvisionDialog> {
  final _phone = TextEditingController();
  final Set<String> _selected = {};
  bool _active = true;
  String? _error;
  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (_selected.isEmpty) {
        throw ArgumentError('Select at least one community.');
      }
      await widget.service.createAdmin(
        phoneNumber: _phone.text,
        communityIds: _selected.toList(),
        isActive: _active,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Provision admin'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Phone number (E.164)',
              ),
            ),
            for (final tenant in widget.tenants)
              CheckboxListTile(
                value: _selected.contains(tenant.communityId),
                title: Text(tenant.name),
                onChanged: (value) => setState(
                  () => value == true
                      ? _selected.add(tenant.communityId)
                      : _selected.remove(tenant.communityId),
                ),
              ),
            SwitchListTile(
              value: _active,
              title: const Text('Active'),
              onChanged: (value) => setState(() => _active = value),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Create')),
    ],
  );
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.tenants, required this.selected});
  final List<TenantConfig> tenants;
  final List<String> selected;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late final Set<String> _selected = widget.selected.toSet();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Community assignments'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tenant in widget.tenants)
            CheckboxListTile(
              value: _selected.contains(tenant.communityId),
              title: Text(tenant.name),
              onChanged: (value) => setState(
                () => value == true
                    ? _selected.add(tenant.communityId)
                    : _selected.remove(tenant.communityId),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, _selected.toList()),
        child: const Text('Save'),
      ),
    ],
  );
}
