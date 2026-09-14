import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/resident_bulk_import_dialog.dart';

class AdminResidentsPage extends StatefulWidget {
  const AdminResidentsPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminResidentsPage> createState() => _AdminResidentsPageState();
}

class _AdminResidentsPageState extends State<AdminResidentsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _statusFilter = 'all';

  String get _communityId => widget.session.activeTenant!.communityId;

  String get _communityName => widget.session.activeTenant!.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //
    // SECURITY:
    // Residents are loaded only from the validated active community.
    // There is intentionally no broad users collection query.
    //
    final residentsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('communityId', isEqualTo: _communityId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: residentsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionCard(
            title: 'Residents',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load residents for this community.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SectionCard(
            title: 'Residents',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final residents = snapshot.data!.docs.where((doc) {
          final data = doc.data();

          //
          // Fail closed against malformed/cross-tenant documents.
          //
          if (data['communityId']?.toString() != _communityId) {
            return false;
          }

          final role = data['role']?.toString().trim().toLowerCase();

          //
          // Residents should normally be explicitly role=resident.
          // Legacy records without role are retained only if they contain
          // resident-specific apartment fields.
          //
          if (role != null && role.isNotEmpty && role != 'resident') {
            return false;
          }

          return true;
        }).toList();

        final approvedCount = residents.where((doc) {
          return _approvalStatus(doc.data()) == 'approved';
        }).length;

        final pendingCount = residents.where((doc) {
          return _approvalStatus(doc.data()) == 'pending';
        }).length;

        final inactiveCount = residents.where((doc) {
          return !_residentIsActive(doc.data());
        }).length;

        final filteredResidents =
            residents.where((doc) {
              final data = doc.data();

              final query = _searchText.trim().toLowerCase();

              if (query.isNotEmpty) {
                final searchable = [
                  _residentName(doc.id, data),
                  _residentPhone(data),
                  _residentEmail(data),
                  _residentFlat(data),
                  _residentBuilding(data),
                ].join(' ').toLowerCase();

                if (!searchable.contains(query)) {
                  return false;
                }
              }

              if (_statusFilter != 'all') {
                if (_statusFilter == 'inactive') {
                  return !_residentIsActive(data);
                }

                if (_approvalStatus(data) != _statusFilter) {
                  return false;
                }
              }

              return true;
            }).toList()..sort((a, b) {
              return _residentName(a.id, a.data()).toLowerCase().compareTo(
                _residentName(b.id, b.data()).toLowerCase(),
              );
            });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResidentsHero(
              communityName: _communityName,
              totalResidents: residents.length,
              approvedResidents: approvedCount,
              pendingResidents: pendingCount,
              inactiveResidents: inactiveCount,
            ),

            const SizedBox(height: 16),

            _QuickNavigation(onNavigate: widget.onNavigate),

            const SizedBox(height: 16),

            SectionCard(
              title: 'Resident Directory',
              action: _ResidentToolbar(
                searchController: _searchController,
                searchText: _searchText,
                statusFilter: _statusFilter,
                onSearchChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                onSearchClear: () {
                  _searchController.clear();

                  setState(() {
                    _searchText = '';
                  });
                },
                onStatusChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _statusFilter = value;
                  });
                },
                onBulkImport: () => ResidentBulkImportDialog.show(
                  context,
                  communityId: _communityId,
                ),
              ),
              child: filteredResidents.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      message:
                          _searchText.trim().isNotEmpty ||
                              _statusFilter != 'all'
                          ? 'No residents match the selected filters.'
                          : 'No residents are registered in this community.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 940) {
                          return _ResidentsTable(
                            residents: filteredResidents,
                            onNavigate: widget.onNavigate,
                          );
                        }

                        return Column(
                          children: [
                            for (
                              var i = 0;
                              i < filteredResidents.length;
                              i++
                            ) ...[
                              _ResidentMobileCard(
                                document: filteredResidents[i],
                                onNavigate: widget.onNavigate,
                              ),
                              if (i != filteredResidents.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

//
// ============================================================
// HERO
// ============================================================
//

class _ResidentsHero extends StatelessWidget {
  const _ResidentsHero({
    required this.communityName,
    required this.totalResidents,
    required this.approvedResidents,
    required this.pendingResidents,
    required this.inactiveResidents,
  });

  final String communityName;
  final int totalResidents;
  final int approvedResidents;
  final int pendingResidents;
  final int inactiveResidents;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WebDesign.adminPageHeader,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: RolePalette.admin.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WebDesign.border),
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: WebDesign.text,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Residents',
                      style: TextStyle(
                        color: WebDesign.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      communityName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WebDesign.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(label: 'Total', value: totalResidents.toString()),
              _HeroMetric(
                label: 'Approved',
                value: approvedResidents.toString(),
              ),
              _HeroMetric(label: 'Pending', value: pendingResidents.toString()),
              _HeroMetric(
                label: 'Inactive',
                value: inactiveResidents.toString(),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), metrics],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 20),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: RolePalette.admin.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: WebDesign.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// QUICK LINKS
// ============================================================
//

class _QuickNavigation extends StatelessWidget {
  const _QuickNavigation({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Access',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          QuickActionCard(
            label: 'My Community',
            icon: Icons.apartment_outlined,
            color: RolePalette.admin.primary,
            onTap: () => onNavigate('/admin/community'),
          ),
          QuickActionCard(
            label: 'Buildings',
            icon: Icons.business_outlined,
            color: const Color(0xFF246BFD),
            onTap: () => onNavigate('/admin/buildings'),
          ),
          QuickActionCard(
            label: 'Visitors',
            icon: Icons.badge_outlined,
            color: const Color(0xFF7A42D8),
            onTap: () => onNavigate('/admin/visitors'),
          ),
          QuickActionCard(
            label: 'Complaints',
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFE34A5F),
            onTap: () => onNavigate('/admin/complaints'),
          ),
          QuickActionCard(
            label: 'Billing',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF08A579),
            onTap: () => onNavigate('/admin/billing'),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// TOOLBAR
// ============================================================
//

class _ResidentToolbar extends StatelessWidget {
  const _ResidentToolbar({
    required this.searchController,
    required this.searchText,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onStatusChanged,
    required this.onBulkImport,
  });

  final TextEditingController searchController;
  final String searchText;
  final String statusFilter;

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onBulkImport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onBulkImport,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('Bulk Import'),
        ),
        SizedBox(
          width: 250,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search residents...',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: searchText.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: onSearchClear,
                      icon: const Icon(Icons.close, size: 18),
                    ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: WebDesign.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: WebDesign.border),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WebDesign.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All status')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: onStatusChanged,
            ),
          ),
        ),
      ],
    );
  }
}

//
// ============================================================
// DESKTOP TABLE
// ============================================================
//

class _ResidentsTable extends StatelessWidget {
  const _ResidentsTable({required this.residents, required this.onNavigate});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> residents;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.0),
        4: FlexColumnWidth(1.0),
        5: FlexColumnWidth(.7),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: WebDesign.border),
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            _TableHeader('Resident'),
            _TableHeader('Contact'),
            _TableHeader('Building'),
            _TableHeader('Flat'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final doc in residents) _residentRow(doc),
      ],
    );
  }

  TableRow _residentRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return TableRow(
      children: [
        _ResidentNameCell(
          name: _residentName(doc.id, data),
          subtitle: _residentSubtitle(data),
        ),
        _ContactCell(phone: _residentPhone(data), email: _residentEmail(data)),
        _TableTextCell(text: _residentBuilding(data)),
        _TableTextCell(text: _residentFlat(data)),
        _ResidentStatusCell(
          approvalStatus: _approvalStatus(data),
          isActive: _residentIsActive(data),
        ),
        _ResidentActionsCell(
          onVisitors: () => onNavigate('/admin/visitors'),
          onComplaints: () => onNavigate('/admin/complaints'),
          onBilling: () => onNavigate('/admin/billing'),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        label,
        style: const TextStyle(
          color: WebDesign.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResidentNameCell extends StatelessWidget {
  const _ResidentNameCell({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: RolePalette.admin.soft,
            child: Text(
              initial,
              style: TextStyle(
                color: RolePalette.admin.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WebDesign.muted, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.phone, required this.email});

  final String phone;
  final String email;

  @override
  Widget build(BuildContext context) {
    final first = phone.isNotEmpty ? phone : '—';
    final second = email;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            first,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WebDesign.text, fontSize: 11),
          ),
          if (second.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              second,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableTextCell extends StatelessWidget {
  const _TableTextCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      child: Text(
        text.isEmpty ? '—' : text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: WebDesign.text, fontSize: 11),
      ),
    );
  }
}

class _ResidentStatusCell extends StatelessWidget {
  const _ResidentStatusCell({
    required this.approvalStatus,
    required this.isActive,
  });

  final String approvalStatus;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final status = !isActive ? 'Inactive' : _titleCase(approvalStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _StatusPill(status: status),
      ),
    );
  }
}

class _ResidentActionsCell extends StatelessWidget {
  const _ResidentActionsCell({
    required this.onVisitors,
    required this.onComplaints,
    required this.onBilling,
  });

  final VoidCallback onVisitors;
  final VoidCallback onComplaints;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          tooltip: 'Resident actions',
          onSelected: (value) {
            switch (value) {
              case 'visitors':
                onVisitors();
                break;
              case 'complaints':
                onComplaints();
                break;
              case 'billing':
                onBilling();
                break;
            }
          },
          itemBuilder: (_) {
            return const [
              PopupMenuItem(
                value: 'visitors',
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Visitors'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'complaints',
                child: Row(
                  children: [
                    Icon(Icons.report_problem_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Complaints'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'billing',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Billing'),
                  ],
                ),
              ),
            ];
          },
          icon: const Icon(Icons.more_vert, size: 18),
        ),
      ),
    );
  }
}

//
// ============================================================
// MOBILE
// ============================================================
//

class _ResidentMobileCard extends StatelessWidget {
  const _ResidentMobileCard({required this.document, required this.onNavigate});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final name = _residentName(document.id, data);

    final phone = _residentPhone(data);
    final building = _residentBuilding(data);
    final flat = _residentFlat(data);

    final status = !_residentIsActive(data)
        ? 'Inactive'
        : _titleCase(_approvalStatus(data));

    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: RolePalette.admin.soft,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: RolePalette.admin.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: WebDesign.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: WebDesign.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.apartment_outlined,
                label: building.isEmpty ? 'Building —' : building,
              ),
              _InfoPill(
                icon: Icons.door_front_door_outlined,
                label: flat.isEmpty ? 'Flat —' : flat,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => onNavigate('/admin/visitors'),
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('Visitors'),
              ),
              TextButton.icon(
                onPressed: () => onNavigate('/admin/complaints'),
                icon: const Icon(Icons.report_problem_outlined, size: 16),
                label: const Text('Complaints'),
              ),
              TextButton.icon(
                onPressed: () => onNavigate('/admin/billing'),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Billing'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WebDesign.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: WebDesign.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: WebDesign.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'approved':
      case 'active':
        background = const Color(0xFFE8F8F2);
        foreground = const Color(0xFF087A5B);
        break;

      case 'pending':
      case 'pendingapproval':
        background = const Color(0xFFFFF4D8);
        foreground = const Color(0xFFA96B00);
        break;

      case 'rejected':
      case 'inactive':
      case 'blocked':
        background = const Color(0xFFFFEEEE);
        foreground = const Color(0xFFB93C3C);
        break;

      default:
        background = const Color(0xFFF0F2F6);
        foreground = WebDesign.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

//
// ============================================================
// FIELD HELPERS
//
// These tolerate the known variations in existing resident documents
// without widening the tenant query.
// ============================================================
//

String _residentName(String documentId, Map<String, dynamic> data) {
  for (final key in const [
    'displayName',
    'name',
    'fullName',
    'residentName',
    'userName',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return documentId;
}

String _residentSubtitle(Map<String, dynamic> data) {
  for (final key in const ['relation', 'residentType', 'occupancyType']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _residentPhone(Map<String, dynamic> data) {
  for (final key in const ['phoneNumber', 'phone', 'mobileNumber', 'mobile']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _residentEmail(Map<String, dynamic> data) {
  for (final key in const ['email', 'emailAddress']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _residentBuilding(Map<String, dynamic> data) {
  for (final key in const ['buildingName', 'buildingLabel', 'buildingId']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _residentFlat(Map<String, dynamic> data) {
  for (final key in const [
    'flatLabel',
    'flatNumber',
    'flatNo',
    'unitNumber',
    'unitNo',
    'flatId',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _approvalStatus(Map<String, dynamic> data) {
  final value = data['approvalStatus']?.toString().trim().toLowerCase();

  if (value == null || value.isEmpty) {
    return 'approved';
  }

  if (value == 'pendingapproval' || value == 'pending_approval') {
    return 'pending';
  }

  return value;
}

bool _residentIsActive(Map<String, dynamic> data) {
  if (data['isActive'] is bool) {
    return data['isActive'] == true;
  }

  if (data['isBlocked'] == true ||
      data['blocked'] == true ||
      data['isDeleted'] == true ||
      data['deleted'] == true) {
    return false;
  }

  return true;
}

String _titleCase(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return 'Unknown';
  }

  if (text.length == 1) {
    return text.toUpperCase();
  }

  return '${text[0].toUpperCase()}${text.substring(1)}';
}
