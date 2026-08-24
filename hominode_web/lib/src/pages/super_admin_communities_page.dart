import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/super_admin_service.dart';
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
              action: FilledButton.icon(
                onPressed: _busy ? null : () => _openCommunityDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Community'),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search communities...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();

                                setState(() {
                                  _search = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.apartment_outlined,
                      message: 'No communities found.',
                    )
                  else
                    ...filtered.map(
                      (doc) => _CommunityRow(
                        id: doc.id,
                        data: doc.data(),
                        busy: _busy,
                        onEdit: () =>
                            _openCommunityDialog(id: doc.id, data: doc.data()),
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
        return AlertDialog(
          title: Text(editing ? 'Edit Community' : 'Add Community'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field(controller: name, label: 'Community Name *'),
                  _Field(controller: brand, label: 'Brand Name'),
                  _Field(controller: slug, label: 'Slug *'),
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
                if (name.text.trim().isEmpty ||
                    slug.text.trim().isEmpty ||
                    website.text.trim().isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: Text(editing ? 'Save Changes' : 'Create Community'),
            ),
          ],
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WebDesign.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: RolePalette.superAdmin.soft,
            child: Icon(
              Icons.apartment_outlined,
              color: RolePalette.superAdmin.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name']?.toString() ?? id,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data['websitePath']?.toString() ?? '—',
                  style: const TextStyle(color: WebDesign.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(child: Text(data['slug']?.toString() ?? '—')),
          StatusBadge(active: active),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            enabled: !busy,
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
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
