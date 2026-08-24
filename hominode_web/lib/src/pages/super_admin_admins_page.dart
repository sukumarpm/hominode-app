import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/super_admin_service.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class SuperAdminAdminsPage extends StatefulWidget {
  const SuperAdminAdminsPage({super.key});

  @override
  State<SuperAdminAdminsPage> createState() => _SuperAdminAdminsPageState();
}

class _SuperAdminAdminsPageState extends State<SuperAdminAdminsPage> {
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
    final adminsQuery = FirebaseFirestore.instance
        .collection('admins')
        .where('role', isEqualTo: 'admin');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: adminsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionCard(
            title: 'Admins',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load administrators.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SectionCard(
            title: 'Admins',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final admins = snapshot.data!.docs;

        final filtered = admins.where((doc) {
          final query = _search.trim().toLowerCase();

          if (query.isEmpty) {
            return true;
          }

          final data = doc.data();

          return [
            data['phoneNumber'],
            data['name'],
            doc.id,
          ].whereType<Object>().join(' ').toLowerCase().contains(query);
        }).toList();

        final active = admins
            .where((doc) => doc.data()['isActive'] == true)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Community Admins',
                  value: admins.length.toString(),
                  icon: Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Active Admins',
                  value: active.toString(),
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xFF08A579),
                ),
                DashboardStatCard(
                  label: 'Inactive Admins',
                  value: (admins.length - active).toString(),
                  icon: Icons.person_off_outlined,
                  color: const Color(0xFFE66A2C),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Community Administrators',
              action: FilledButton.icon(
                onPressed: _busy ? null : _showCreateAdminDialog,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Admin'),
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
                      hintText: 'Search admins...',
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
                      icon: Icons.people_outline,
                      message: 'No community administrators found.',
                    )
                  else
                    ...filtered.map(
                      (doc) => _AdminRow(
                        id: doc.id,
                        data: doc.data(),
                        busy: _busy,
                        onEdit: () => _showAssignmentDialog(doc.id, doc.data()),
                        onStatus: () => _toggleAdmin(
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadCommunities() async {
    final result = await FirebaseFirestore.instance
        .collection('communities')
        .get();

    return result.docs;
  }

  Future<void> _showCreateAdminDialog() async {
    final communities = await _loadCommunities();

    if (!mounted) return;

    final phone = TextEditingController();
    final selected = <String>{};

    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Community Admin'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: '+639XXXXXXXXX',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Assigned Communities *',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (final community in communities)
                        CheckboxListTile(
                          value: selected.contains(community.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            community.data()['name']?.toString() ??
                                community.id,
                          ),
                          subtitle: Text(
                            community.data()['websitePath']?.toString() ?? '',
                          ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(community.id);
                              } else {
                                selected.remove(community.id);
                              }
                            });
                          },
                        ),
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
                  onPressed: phone.text.trim().isEmpty || selected.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Create Admin'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) return;

    setState(() => _busy = true);

    try {
      await SuperAdminService.createAdmin(
        phoneNumber: phone.text,
        communityIds: selected.toList(),
      );
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showAssignmentDialog(
    String adminId,
    Map<String, dynamic> data,
  ) async {
    final communities = await _loadCommunities();

    if (!mounted) return;

    final existing =
        (data['authorizedCommunityIds'] as List?)
            ?.whereType<String>()
            .toSet() ??
        <String>{};

    final selected = <String>{...existing};

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Community Access\n${data['phoneNumber'] ?? adminId}',
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final community in communities)
                        CheckboxListTile(
                          value: selected.contains(community.id),
                          title: Text(
                            community.data()['name']?.toString() ??
                                community.id,
                          ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(community.id);
                              } else {
                                selected.remove(community.id);
                              }
                            });
                          },
                        ),
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
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Save Assignments'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) return;

    setState(() => _busy = true);

    try {
      await SuperAdminService.updateAdminAssignments(
        adminId: adminId,
        communityIds: selected.toList(),
      );
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleAdmin(String id, bool active) async {
    setState(() => _busy = true);

    try {
      await SuperAdminService.setAdminActive(adminId: id, isActive: !active);
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

class _AdminRow extends StatelessWidget {
  const _AdminRow({
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

    final communityIds =
        (data['authorizedCommunityIds'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];

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
              Icons.person_outline,
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
                  data['phoneNumber']?.toString() ?? id,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Community Admin',
                  style: TextStyle(color: WebDesign.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              communityIds.length == 1
                  ? '1 community'
                  : '${communityIds.length} communities',
            ),
          ),
          StatusBadge(active: active),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            enabled: !busy,
            onSelected: (value) {
              if (value == 'access') {
                onEdit();
              } else if (value == 'status') {
                onStatus();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'access',
                child: Text('Manage Communities'),
              ),
              PopupMenuItem(
                value: 'status',
                child: Text(active ? 'Deactivate Admin' : 'Activate Admin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
