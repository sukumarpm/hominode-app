import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'models/tenant_config.dart';
import 'services/tenant_registry_service.dart';

class SuperAdminCommunitiesScreen extends StatefulWidget {
  const SuperAdminCommunitiesScreen({this.tenantsLoader, super.key});

  final Future<List<TenantConfig>> Function()? tenantsLoader;

  @override
  State<SuperAdminCommunitiesScreen> createState() =>
      _SuperAdminCommunitiesScreenState();
}

class _SuperAdminCommunitiesScreenState
    extends State<SuperAdminCommunitiesScreen> {
  TenantRegistryService? _registry;
  TenantRegistryService get _service => _registry ??= TenantRegistryService();
  late Future<List<TenantConfig>> _tenants = _loadTenants();

  Future<List<TenantConfig>> _loadTenants() =>
      widget.tenantsLoader?.call() ?? _service.getTenants();

  void _refresh() => setState(() => _tenants = _loadTenants());

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _TenantFormDialog(service: _service),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Communities'),
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
      icon: const Icon(Icons.add),
      label: const Text('Create community'),
    ),
    body: RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<TenantConfig>>(
        future: _tenants,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Unable to load communities: ${snapshot.error}'),
                ),
              ],
            );
          }
          final tenants = snapshot.data ?? const [];
          if (tenants.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No communities found.'),
                ),
              ],
            );
          }
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
                  mainAxisExtent: 180,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: tenants.length,
                itemBuilder: (_, index) => _TenantCard(
                  tenant: tenants[index],
                  onOpen: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SuperAdminCommunityDetailsScreen(
                          communityId: tenants[index].communityId,
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

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.tenant, required this.onOpen});
  final TenantConfig tenant;
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
                CircleAvatar(
                  backgroundImage: tenant.logoUrl == null
                      ? null
                      : NetworkImage(tenant.logoUrl!),
                  child: tenant.logoUrl == null
                      ? const Icon(Icons.apartment)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tenant.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(tenant.isActive ? 'Active' : 'Inactive')),
              ],
            ),
            const SizedBox(height: 16),
            Text('/${tenant.websitePath}'),
            Text('Slug: ${tenant.slug}'),
            const Spacer(),
            Text('Database: ${tenant.databaseId}'),
          ],
        ),
      ),
    ),
  );
}

class SuperAdminCommunityDetailsScreen extends StatefulWidget {
  const SuperAdminCommunityDetailsScreen({
    required this.communityId,
    super.key,
  });
  final String communityId;
  @override
  State<SuperAdminCommunityDetailsScreen> createState() =>
      _SuperAdminCommunityDetailsScreenState();
}

class _SuperAdminCommunityDetailsScreenState
    extends State<SuperAdminCommunityDetailsScreen> {
  final _service = TenantRegistryService();
  late Future<TenantConfig> _tenant = _service.getTenantById(
    widget.communityId,
  );
  void _refresh() =>
      setState(() => _tenant = _service.getTenantById(widget.communityId));

  Future<void> _changeStatus(TenantConfig tenant) async {
    if (tenant.isActive) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Deactivate community?'),
              content: Text(
                '${tenant.name} will no longer pass tenant resolution.',
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
    await _service.setTenantActive(tenant.communityId, !tenant.isActive);
    _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TenantConfig>(
    future: _tenant,
    builder: (context, snapshot) {
      final tenant = snapshot.data;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Community details'),
          actions: tenant == null
              ? null
              : [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () async {
                      if (await showDialog<bool>(
                            context: context,
                            builder: (_) => _TenantFormDialog(
                              service: _service,
                              tenant: tenant,
                            ),
                          ) ==
                          true) {
                        _refresh();
                      }
                    },
                    icon: const Icon(Icons.edit),
                  ),
                ],
        ),
        body: tenant == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final entry in <String, String>{
                    'Community ID': tenant.communityId,
                    'Name': tenant.name,
                    'Slug': tenant.slug,
                    'Website path': tenant.websitePath,
                    'Database ID': tenant.databaseId,
                    'Status': tenant.isActive ? 'Active' : 'Inactive',
                    'Brand name': tenant.brandName ?? '',
                    'Logo URL': tenant.logoUrl ?? '',
                    'Primary color': tenant.primaryColor ?? '',
                    'Created by': tenant.createdBy,
                    'Created at': tenant.createdAt?.toIso8601String() ?? '',
                    'Updated at': tenant.updatedAt?.toIso8601String() ?? '',
                  }.entries)
                    ListTile(
                      title: Text(entry.key),
                      subtitle: Text(entry.value.isEmpty ? '—' : entry.value),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => _changeStatus(tenant),
                    child: Text(
                      tenant.isActive
                          ? 'Deactivate community'
                          : 'Activate community',
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _TenantFormDialog extends StatefulWidget {
  const _TenantFormDialog({required this.service, this.tenant});
  final TenantRegistryService service;
  final TenantConfig? tenant;
  @override
  State<_TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<_TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    _fields = {
      'name': TextEditingController(text: t?.name),
      'slug': TextEditingController(text: t?.slug),
      'websitePath': TextEditingController(text: t?.websitePath),
      'databaseId': TextEditingController(
        text: t?.databaseId ?? TenantConfig.defaultDatabaseId,
      ),
      'brandName': TextEditingController(text: t?.brandName),
      'logoUrl': TextEditingController(text: t?.logoUrl),
      'primaryColor': TextEditingController(text: t?.primaryColor),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = _fields.map((key, value) => MapEntry(key, value.text));
      if (widget.tenant == null) {
        await widget.service.createTenant(values);
      } else {
        await widget.service.updateTenant(widget.tenant!.communityId, values);
      }
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (error) {
      setState(() => _error = error.message ?? 'Unable to save community.');
    } catch (error) {
      setState(() => _error = error.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.tenant == null ? 'Create community' : 'Edit community'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.value,
                    decoration: InputDecoration(labelText: _label(entry.key)),
                    validator: entry.key == 'name'
                        ? (value) => value == null || value.trim().isEmpty
                              ? 'Required'
                              : null
                        : null,
                  ),
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
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
  String _label(String key) => const {
    'name': 'Name',
    'slug': 'Slug',
    'websitePath': 'Website path',
    'databaseId': 'Database ID',
    'brandName': 'Brand name (optional)',
    'logoUrl': 'Logo URL (optional)',
    'primaryColor': 'Primary color (optional)',
  }[key]!;
}
