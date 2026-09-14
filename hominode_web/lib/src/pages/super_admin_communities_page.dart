import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/super_admin_service.dart';
import '../tenant/web_host.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class SuperAdminCommunitiesPage extends StatefulWidget {
  const SuperAdminCommunitiesPage({super.key});

  @override
  State<SuperAdminCommunitiesPage> createState() =>
      _SuperAdminCommunitiesPageState();
}

class _SuperAdminCommunitiesPageState extends State<SuperAdminCommunitiesPage> {
  final _searchController = TextEditingController();

  String _search = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('communities').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionCard(
            title: 'Communities',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load communities.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SectionCard(
            title: 'Communities',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final all = snapshot.data!.docs;

        final filtered = all.where((doc) {
          if (_search.trim().isEmpty) {
            return true;
          }

          final data = doc.data();
          final query = _search.trim().toLowerCase();

          final text = [
            data['name'],
            data['brandName'],
            data['slug'],
            data['websitePath'],
            data['databaseId'],
          ].whereType<Object>().join(' ').toLowerCase();

          return text.contains(query);
        }).toList();

        final active = all
            .where((doc) => doc.data()['isActive'] == true)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Total Communities',
                  value: all.length.toString(),
                  icon: Icons.apartment_outlined,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Active',
                  value: active.toString(),
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF08A579),
                ),
                DashboardStatCard(
                  label: 'Inactive',
                  value: (all.length - active).toString(),
                  icon: Icons.pause_circle_outline,
                  color: const Color(0xFFE66A2C),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Communities',
              subtitle: 'Platform registry and resident web identities',
              action: FilledButton.icon(
                onPressed: _busy ? null : () => _openCommunityDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Community'),
              ),
              child: Column(
                children: [
                  WebSearchToolbar(
                    controller: _searchController,
                    hintText: 'Search communities, slugs, or domains',
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.apartment_outlined,
                      message: 'No communities found.',
                    )
                  else ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: WebDesign.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const DesktopListHeader(
                            labels: [
                              'Community',
                              'Resident URL',
                              'Status',
                              'Actions',
                            ],
                            flexes: [2, 1, 1, 1],
                          ),
                          ...filtered.map(
                            (doc) => _CommunityRow(
                              id: doc.id,
                              data: doc.data(),
                              busy: _busy,
                              onEdit: () => _openCommunityDialog(
                                id: doc.id,
                                data: doc.data(),
                              ),
                              onStatus: () => _toggleCommunity(
                                doc.id,
                                doc.data()['isActive'] == true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleCommunity(String id, bool current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            current ? 'Deactivate community?' : 'Activate community?',
          ),
          content: Text(
            current
                ? 'Local administrators and residents should no longer be able to use an inactive community.'
                : 'This community will become active again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(current ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await SuperAdminService.setCommunityActive(
        communityId: id,
        isActive: !current,
      );
    } catch (e) {
      if (mounted) {
        _error(e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openCommunityDialog({
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final editing = id != null;

    final name = TextEditingController(text: data?['name']?.toString() ?? '');

    final brand = TextEditingController(
      text: data?['brandName']?.toString() ?? '',
    );

    final slug = TextEditingController(text: data?['slug']?.toString() ?? '');
    final slugIsAssigned = slug.text.trim().isNotEmpty;
    String? slugError;

    final website = TextEditingController(
      text: data?['websitePath']?.toString() ?? '',
    );

    final database = TextEditingController(
      text: data?['databaseId']?.toString() ?? '(default)',
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(editing ? 'Edit Community' : 'Add Community'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Field(controller: name, label: 'Community Name *'),
                    _Field(controller: brand, label: 'Brand Name'),
                    _Field(
                      controller: slug,
                      label: 'Resident URL slug *',
                      readOnly: slugIsAssigned,
                      errorText: slugError,
                    ),
                    _Field(controller: website, label: 'Website Path *'),
                    _Field(controller: database, label: 'Database ID'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final candidate = slug.text.trim();
                  final validationError = CommunitySlugPolicy.validationError(
                    candidate,
                  );
                  if (name.text.trim().isEmpty ||
                      website.text.trim().isEmpty ||
                      validationError != null) {
                    setDialogState(() => slugError = validationError);
                    return;
                  }

                  Navigator.pop(dialogContext, true);
                },
                child: Text(editing ? 'Save Changes' : 'Create Community'),
              ),
            ],
          ),
        );
      },
    );

    if (result != true) return;

    setState(() => _busy = true);

    try {
      if (editing) {
        await SuperAdminService.updateCommunity(
          communityId: id,
          name: name.text,
          brandName: brand.text,
          slug: slug.text,
          websitePath: website.text,
          databaseId: database.text,
        );
      } else {
        await SuperAdminService.createCommunity(
          name: name.text,
          brandName: brand.text.isEmpty ? name.text : brand.text,
          slug: slug.text,
          websitePath: website.text,
          databaseId: database.text,
        );
      }
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _error(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Operation failed: $error')));
  }
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({
    required this.id,
    required this.data,
    required this.busy,
    required this.onEdit,
    required this.onStatus,
  });

  final String id;
  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    final active = data['isActive'] == true;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['name']?.toString() ?? id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: WebDesign.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data['websitePath']?.toString() ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: WebDesign.muted, fontSize: 10),
        ),
      ],
    );
    final menu = PopupMenuButton<String>(
      enabled: !busy,
      iconSize: 19,
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'status') {
          onStatus();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'status',
          child: Text(active ? 'Deactivate' : 'Activate'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: WebDesign.border)),
        ),
        child: constraints.maxWidth < 760
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _CommunityAvatar(),
                      const SizedBox(width: 12),
                      Expanded(child: identity),
                      StatusBadge(active: active),
                      menu,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Resident URL: ${data['slug']?.toString() ?? '—'}',
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const _CommunityAvatar(),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: identity),
                  Expanded(
                    child: Text(
                      data['slug']?.toString() ?? '—',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Align(child: StatusBadge(active: active)),
                  ),
                  Expanded(child: Align(child: menu)),
                ],
              ),
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar();

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 18,
    backgroundColor: RolePalette.superAdmin.soft,
    child: Icon(
      Icons.apartment_outlined,
      size: 18,
      color: RolePalette.superAdmin.primary,
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.readOnly = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final bool readOnly;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
