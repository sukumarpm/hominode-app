import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminComplaintsPage extends StatefulWidget {
  const AdminComplaintsPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminComplaintsPage> createState() => _AdminComplaintsPageState();
}

class _AdminComplaintsPageState extends State<AdminComplaintsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

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
    // Complaints are queried only for the validated active tenant.
    //
    final complaintsQuery = FirebaseFirestore.instance
        .collection('complaints')
        .where('communityId', isEqualTo: _communityId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: complaintsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionCard(
            title: 'Complaints',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load complaints for this community.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SectionCard(
            title: 'Complaints',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final complaints = snapshot.data!.docs.where((doc) {
          return doc.data()['communityId']?.toString() == _communityId;
        }).toList();

        final openCount = complaints.where((doc) {
          final status = _complaintStatus(doc.data());

          return status == 'open' ||
              status == 'pending' ||
              status == 'inprogress';
        }).length;

        final resolvedCount = complaints.where((doc) {
          final status = _complaintStatus(doc.data());

          return status == 'resolved' ||
              status == 'closed' ||
              status == 'completed';
        }).length;

        final highPriorityCount = complaints.where((doc) {
          return _complaintPriority(doc.data()) == 'high';
        }).length;

        final filteredComplaints =
            complaints.where((doc) {
              final data = doc.data();

              final query = _searchText.trim().toLowerCase();

              if (query.isNotEmpty) {
                final searchable = [
                  _complaintTitle(doc.id, data),
                  _complaintCategory(data),
                  _complaintDescription(data),
                  _residentName(data),
                  _building(data),
                  _flat(data),
                  _complaintStatus(data),
                  _complaintPriority(data),
                ].join(' ').toLowerCase();

                if (!searchable.contains(query)) {
                  return false;
                }
              }

              if (_statusFilter != 'all') {
                final status = _complaintStatus(data);

                if (_statusFilter == 'open') {
                  if (status != 'open' &&
                      status != 'pending' &&
                      status != 'inprogress') {
                    return false;
                  }
                } else if (_statusFilter == 'resolved') {
                  if (status != 'resolved' &&
                      status != 'closed' &&
                      status != 'completed') {
                    return false;
                  }
                } else if (status != _statusFilter) {
                  return false;
                }
              }

              if (_priorityFilter != 'all' &&
                  _complaintPriority(data) != _priorityFilter) {
                return false;
              }

              return true;
            }).toList()..sort(
              (a, b) =>
                  _complaintDate(b.data()).compareTo(_complaintDate(a.data())),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ComplaintsHero(
              communityName: _communityName,
              total: complaints.length,
              open: openCount,
              resolved: resolvedCount,
              highPriority: highPriorityCount,
            ),

            const SizedBox(height: 16),

            _QuickNavigation(onNavigate: widget.onNavigate),

            const SizedBox(height: 16),

            SectionCard(
              title: 'Complaint Directory',
              action: _ComplaintToolbar(
                searchController: _searchController,
                searchText: _searchText,
                statusFilter: _statusFilter,
                priorityFilter: _priorityFilter,
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
                onPriorityChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _priorityFilter = value;
                  });
                },
              ),
              child: filteredComplaints.isEmpty
                  ? EmptyState(
                      icon: Icons.report_problem_outlined,
                      message:
                          _searchText.trim().isNotEmpty ||
                              _statusFilter != 'all' ||
                              _priorityFilter != 'all'
                          ? 'No complaints match the selected filters.'
                          : 'No complaints are available for this community.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 1000) {
                          return _ComplaintsTable(
                            complaints: filteredComplaints,
                            onNavigate: widget.onNavigate,
                          );
                        }

                        return Column(
                          children: [
                            for (
                              var i = 0;
                              i < filteredComplaints.length;
                              i++
                            ) ...[
                              _ComplaintMobileCard(
                                document: filteredComplaints[i],
                                onNavigate: widget.onNavigate,
                              ),
                              if (i != filteredComplaints.length - 1)
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

class _ComplaintsHero extends StatelessWidget {
  const _ComplaintsHero({
    required this.communityName,
    required this.total,
    required this.open,
    required this.resolved,
    required this.highPriority,
  });

  final String communityName;
  final int total;
  final int open;
  final int resolved;
  final int highPriority;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: RolePalette.admin.gradient,
        borderRadius: BorderRadius.circular(WebDesign.radius + 2),
      ),
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
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.report_problem_outlined,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complaints',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      communityName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
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
              _HeroMetric(label: 'Total', value: '$total'),
              _HeroMetric(label: 'Open', value: '$open'),
              _HeroMetric(label: 'Resolved', value: '$resolved'),
              _HeroMetric(label: 'High Priority', value: '$highPriority'),
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
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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
// QUICK ACCESS
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
            label: 'Residents',
            icon: Icons.people_outline,
            color: const Color(0xFF246BFD),
            onTap: () => onNavigate('/admin/residents'),
          ),
          QuickActionCard(
            label: 'Buildings',
            icon: Icons.business_outlined,
            color: const Color(0xFF08A579),
            onTap: () => onNavigate('/admin/buildings'),
          ),
          QuickActionCard(
            label: 'Reports',
            icon: Icons.analytics_outlined,
            color: const Color(0xFFE66A2C),
            onTap: () => onNavigate('/admin/reports'),
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

class _ComplaintToolbar extends StatelessWidget {
  const _ComplaintToolbar({
    required this.searchController,
    required this.searchText,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onStatusChanged,
    required this.onPriorityChanged,
  });

  final TextEditingController searchController;

  final String searchText;
  final String statusFilter;
  final String priorityFilter;

  final ValueChanged<String> onSearchChanged;

  final VoidCallback onSearchClear;

  final ValueChanged<String?> onStatusChanged;

  final ValueChanged<String?> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search complaints...',
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
        _FilterDropdown(
          value: statusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All status')),
            DropdownMenuItem(value: 'open', child: Text('Open')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'inprogress', child: Text('In progress')),
            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
            DropdownMenuItem(value: 'closed', child: Text('Closed')),
          ],
          onChanged: onStatusChanged,
        ),
        _FilterDropdown(
          value: priorityFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All priority')),
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'high', child: Text('High')),
          ],
          onChanged: onPriorityChanged,
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;

  final List<DropdownMenuItem<String>> items;

  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WebDesign.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

//
// ============================================================
// TABLE
// ============================================================
//

class _ComplaintsTable extends StatelessWidget {
  const _ComplaintsTable({required this.complaints, required this.onNavigate});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> complaints;

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.3),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.4),
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
            _TableHeader('Complaint'),
            _TableHeader('Resident'),
            _TableHeader('Location'),
            _TableHeader('Priority'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final doc in complaints) _complaintRow(doc),
      ],
    );
  }

  TableRow _complaintRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return TableRow(
      children: [
        _ComplaintCell(
          title: _complaintTitle(doc.id, data),
          category: _complaintCategory(data),
          date: _complaintDateLabel(data),
        ),
        _TableTextCell(text: _residentName(data)),
        _LocationCell(building: _building(data), flat: _flat(data)),
        _PriorityCell(priority: _complaintPriority(data)),
        _StatusCell(status: _complaintStatus(data)),
        _ComplaintActionsCell(
          onResident: () => onNavigate('/admin/residents'),
          onBuilding: () => onNavigate('/admin/buildings'),
          onReports: () => onNavigate('/admin/reports'),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        text,
        style: const TextStyle(
          color: WebDesign.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ComplaintCell extends StatelessWidget {
  const _ComplaintCell({
    required this.title,
    required this.category,
    required this.date,
  });

  final String title;
  final String category;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              size: 19,
              color: Color(0xFFE34A5F),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WebDesign.muted, fontSize: 9),
                  ),
                ],
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    date,
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

class _TableTextCell extends StatelessWidget {
  const _TableTextCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      child: Text(
        text.isEmpty ? '—' : text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: WebDesign.text, fontSize: 11),
      ),
    );
  }
}

class _LocationCell extends StatelessWidget {
  const _LocationCell({required this.building, required this.flat});

  final String building;
  final String flat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            building.isEmpty ? '—' : building,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (flat.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              flat,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityCell extends StatelessWidget {
  const _PriorityCell({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _PriorityPill(priority: priority),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _StatusPill(status: status),
      ),
    );
  }
}

class _ComplaintActionsCell extends StatelessWidget {
  const _ComplaintActionsCell({
    required this.onResident,
    required this.onBuilding,
    required this.onReports,
  });

  final VoidCallback onResident;
  final VoidCallback onBuilding;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          tooltip: 'Complaint actions',
          onSelected: (value) {
            switch (value) {
              case 'resident':
                onResident();
                break;
              case 'building':
                onBuilding();
                break;
              case 'reports':
                onReports();
                break;
            }
          },
          itemBuilder: (_) {
            return const [
              PopupMenuItem(
                value: 'resident',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Residents'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'building',
                child: Row(
                  children: [
                    Icon(Icons.business_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Buildings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Reports'),
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

class _ComplaintMobileCard extends StatelessWidget {
  const _ComplaintMobileCard({
    required this.document,
    required this.onNavigate,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final title = _complaintTitle(document.id, data);

    final category = _complaintCategory(data);

    final description = _complaintDescription(data);

    final resident = _residentName(data);

    final building = _building(data);

    final flat = _flat(data);

    final status = _complaintStatus(data);

    final priority = _complaintPriority(data);

    final date = _complaintDateLabel(data);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.report_problem_outlined,
                  color: Color(0xFFE34A5F),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WebDesign.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          color: WebDesign.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: status),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 11),
            ),
          ],

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.flag_outlined, label: _titleCase(priority)),
              if (resident.isNotEmpty)
                _InfoPill(icon: Icons.person_outline, label: resident),
              if (building.isNotEmpty)
                _InfoPill(icon: Icons.business_outlined, label: building),
              if (flat.isNotEmpty)
                _InfoPill(icon: Icons.door_front_door_outlined, label: flat),
              if (date.isNotEmpty)
                _InfoPill(icon: Icons.schedule_outlined, label: date),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => onNavigate('/admin/residents'),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Residents'),
              ),
              TextButton.icon(
                onPressed: () => onNavigate('/admin/buildings'),
                icon: const Icon(Icons.business_outlined, size: 16),
                label: const Text('Buildings'),
              ),
              TextButton.icon(
                onPressed: () => onNavigate('/admin/reports'),
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('Reports'),
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

//
// ============================================================
// BADGES
// ============================================================
//

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final normalized = priority.toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'high':
      case 'urgent':
        background = const Color(0xFFFFEEEE);
        foreground = const Color(0xFFB93C3C);
        break;

      case 'medium':
      case 'normal':
        background = const Color(0xFFFFF4D8);
        foreground = const Color(0xFFA96B00);
        break;

      default:
        background = const Color(0xFFE8F8F2);
        foreground = const Color(0xFF087A5B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _titleCase(priority),
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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
      case 'resolved':
      case 'closed':
      case 'completed':
        background = const Color(0xFFE8F8F2);
        foreground = const Color(0xFF087A5B);
        break;

      case 'inprogress':
      case 'in_progress':
        background = const Color(0xFFE6F0FF);
        foreground = const Color(0xFF246BFD);
        break;

      case 'pending':
      case 'open':
        background = const Color(0xFFFFF4D8);
        foreground = const Color(0xFFA96B00);
        break;

      case 'rejected':
      case 'cancelled':
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
        _titleCase(status),
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
// ============================================================
//

String _complaintTitle(String documentId, Map<String, dynamic> data) {
  for (final key in const [
    'title',
    'subject',
    'complaintTitle',
    'issueTitle',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  final description = _complaintDescription(data);

  if (description.isNotEmpty) {
    return description.length > 45
        ? '${description.substring(0, 45)}...'
        : description;
  }

  return documentId;
}

String _complaintDescription(Map<String, dynamic> data) {
  for (final key in const ['description', 'details', 'message', 'complaint']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _complaintCategory(Map<String, dynamic> data) {
  for (final key in const [
    'category',
    'complaintCategory',
    'issueType',
    'type',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _residentName(Map<String, dynamic> data) {
  for (final key in const [
    'residentName',
    'userName',
    'createdByName',
    'submittedByName',
    'name',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _building(Map<String, dynamic> data) {
  for (final key in const ['buildingName', 'buildingLabel', 'buildingId']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _flat(Map<String, dynamic> data) {
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

String _complaintStatus(Map<String, dynamic> data) {
  for (final key in const ['status', 'complaintStatus', 'resolutionStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      final normalized = value.replaceAll(' ', '');

      if (normalized == 'in_progress' || normalized == 'inprogress') {
        return 'inprogress';
      }

      return normalized;
    }
  }

  return 'open';
}

String _complaintPriority(Map<String, dynamic> data) {
  for (final key in const ['priority', 'severity', 'urgency']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      if (value == 'urgent') {
        return 'high';
      }

      if (value == 'normal') {
        return 'medium';
      }

      return value;
    }
  }

  return 'medium';
}

DateTime _complaintDate(Map<String, dynamic> data) {
  for (final key in const [
    'createdAt',
    'submittedAt',
    'reportedAt',
    'updatedAt',
  ]) {
    final value = data[key];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _complaintDateLabel(Map<String, dynamic> data) {
  final date = _complaintDate(data);

  if (date.millisecondsSinceEpoch == 0) {
    return '';
  }

  final local = date.toLocal();

  final day = local.day.toString().padLeft(2, '0');

  final month = local.month.toString().padLeft(2, '0');

  return '$day/$month/${local.year}';
}

String _titleCase(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return 'Unknown';
  }

  final normalized = text.replaceAll('_', ' ');

  if (normalized.toLowerCase() == 'inprogress') {
    return 'In Progress';
  }

  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
