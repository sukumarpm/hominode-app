import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminVisitorsPage extends StatefulWidget {
  const AdminVisitorsPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminVisitorsPage> createState() => _AdminVisitorsPageState();
}

class _AdminVisitorsPageState extends State<AdminVisitorsPage> {
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
    // Visitor data is queried only for the validated active tenant.
    //
    final visitorQuery = FirebaseFirestore.instance
        .collection('visitors')
        .where('communityId', isEqualTo: _communityId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: visitorQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionCard(
            title: 'Visitors',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load visitors for this community.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SectionCard(
            title: 'Visitors',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final visitors = snapshot.data!.docs.where((doc) {
          //
          // Defensive fail-closed tenant verification.
          //
          return doc.data()['communityId']?.toString() == _communityId;
        }).toList();

        final pendingCount = visitors
            .where((doc) => _visitorStatus(doc.data()) == 'pending')
            .length;

        final approvedCount = visitors.where((doc) {
          final status = _visitorStatus(doc.data());

          return status == 'approved' ||
              status == 'entered' ||
              status == 'exited';
        }).length;

        final insideCount = visitors
            .where((doc) => _visitorStatus(doc.data()) == 'entered')
            .length;

        final filteredVisitors =
            visitors.where((doc) {
              final data = doc.data();

              final query = _searchText.trim().toLowerCase();

              if (query.isNotEmpty) {
                final searchable = [
                  _visitorName(doc.id, data),
                  _visitorPhone(data),
                  _visitorPurpose(data),
                  _hostName(data),
                  _building(data),
                  _flat(data),
                  _visitorStatus(data),
                ].join(' ').toLowerCase();

                if (!searchable.contains(query)) {
                  return false;
                }
              }

              if (_statusFilter != 'all' &&
                  _visitorStatus(data) != _statusFilter) {
                return false;
              }

              return true;
            }).toList()..sort(
              (a, b) => _visitorSortDate(
                b.data(),
              ).compareTo(_visitorSortDate(a.data())),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VisitorsHero(
              communityName: _communityName,
              totalVisitors: visitors.length,
              pendingVisitors: pendingCount,
              approvedVisitors: approvedCount,
              insideVisitors: insideCount,
            ),

            const SizedBox(height: 16),

            _QuickNavigation(onNavigate: widget.onNavigate),

            const SizedBox(height: 16),

            SectionCard(
              title: 'Visitor Directory',
              action: _VisitorToolbar(
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
              ),
              child: filteredVisitors.isEmpty
                  ? EmptyState(
                      icon: Icons.badge_outlined,
                      message:
                          _searchText.trim().isNotEmpty ||
                              _statusFilter != 'all'
                          ? 'No visitors match the selected filters.'
                          : 'No visitor records are available for this community.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 980) {
                          return _VisitorsTable(
                            visitors: filteredVisitors,
                            onNavigate: widget.onNavigate,
                          );
                        }

                        return Column(
                          children: [
                            for (
                              var i = 0;
                              i < filteredVisitors.length;
                              i++
                            ) ...[
                              _VisitorMobileCard(
                                document: filteredVisitors[i],
                                onNavigate: widget.onNavigate,
                              ),
                              if (i != filteredVisitors.length - 1)
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

class _VisitorsHero extends StatelessWidget {
  const _VisitorsHero({
    required this.communityName,
    required this.totalVisitors,
    required this.pendingVisitors,
    required this.approvedVisitors,
    required this.insideVisitors,
  });

  final String communityName;
  final int totalVisitors;
  final int pendingVisitors;
  final int approvedVisitors;
  final int insideVisitors;

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
                  Icons.badge_outlined,
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
                      'Visitors',
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
              _HeroMetric(label: 'Total', value: totalVisitors.toString()),
              _HeroMetric(label: 'Pending', value: pendingVisitors.toString()),
              _HeroMetric(
                label: 'Approved',
                value: approvedVisitors.toString(),
              ),
              _HeroMetric(label: 'Inside', value: insideVisitors.toString()),
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
// FILTER / SEARCH
// ============================================================
//

class _VisitorToolbar extends StatelessWidget {
  const _VisitorToolbar({
    required this.searchController,
    required this.searchText,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String searchText;
  final String statusFilter;

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search visitors...',
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
                DropdownMenuItem(value: 'generated', child: Text('Generated')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'entered', child: Text('Entered')),
                DropdownMenuItem(value: 'exited', child: Text('Exited')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'expired', child: Text('Expired')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
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

class _VisitorsTable extends StatelessWidget {
  const _VisitorsTable({required this.visitors, required this.onNavigate});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> visitors;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.8),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(.7),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: WebDesign.border),
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            _TableHeader('Visitor'),
            _TableHeader('Host'),
            _TableHeader('Location'),
            _TableHeader('Purpose / Time'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final doc in visitors) _visitorRow(doc),
      ],
    );
  }

  TableRow _visitorRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return TableRow(
      children: [
        _VisitorNameCell(
          name: _visitorName(doc.id, data),
          phone: _visitorPhone(data),
        ),
        _TableTextCell(text: _hostName(data)),
        _LocationCell(building: _building(data), flat: _flat(data)),
        _PurposeCell(
          purpose: _visitorPurpose(data),
          time: _visitorDateLabel(data),
        ),
        _VisitorStatusCell(status: _visitorStatus(data)),
        _VisitorActionsCell(
          onResident: () => onNavigate('/admin/residents'),
          onBuilding: () => onNavigate('/admin/buildings'),
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

class _VisitorNameCell extends StatelessWidget {
  const _VisitorNameCell({required this.name, required this.phone});

  final String name;
  final String phone;

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
            backgroundColor: const Color(0xFFEFE8FF),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF6B35D4),
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
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
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

class _TableTextCell extends StatelessWidget {
  const _TableTextCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
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

class _PurposeCell extends StatelessWidget {
  const _PurposeCell({required this.purpose, required this.time});

  final String purpose;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            purpose.isEmpty ? 'Visit' : purpose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WebDesign.text, fontSize: 11),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              time,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitorStatusCell extends StatelessWidget {
  const _VisitorStatusCell({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _VisitorStatusPill(status: status),
      ),
    );
  }
}

class _VisitorActionsCell extends StatelessWidget {
  const _VisitorActionsCell({
    required this.onResident,
    required this.onBuilding,
  });

  final VoidCallback onResident;
  final VoidCallback onBuilding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          tooltip: 'Visitor actions',
          onSelected: (value) {
            switch (value) {
              case 'resident':
                onResident();
                break;
              case 'building':
                onBuilding();
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

class _VisitorMobileCard extends StatelessWidget {
  const _VisitorMobileCard({required this.document, required this.onNavigate});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final name = _visitorName(document.id, data);

    final phone = _visitorPhone(data);
    final host = _hostName(data);
    final building = _building(data);
    final flat = _flat(data);
    final purpose = _visitorPurpose(data);
    final status = _visitorStatus(data);
    final time = _visitorDateLabel(data);

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
                backgroundColor: const Color(0xFFEFE8FF),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF6B35D4),
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
              _VisitorStatusPill(status: status),
            ],
          ),

          const SizedBox(height: 12),

          if (host.isNotEmpty)
            _MobileInfoRow(
              icon: Icons.person_outline,
              label: 'Host',
              value: host,
            ),

          if (building.isNotEmpty || flat.isNotEmpty)
            _MobileInfoRow(
              icon: Icons.apartment_outlined,
              label: 'Location',
              value: [
                building,
                flat,
              ].where((value) => value.isNotEmpty).join(' · '),
            ),

          if (purpose.isNotEmpty)
            _MobileInfoRow(
              icon: Icons.info_outline,
              label: 'Purpose',
              value: purpose,
            ),

          if (time.isNotEmpty)
            _MobileInfoRow(
              icon: Icons.schedule_outlined,
              label: 'Visit',
              value: time,
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
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileInfoRow extends StatelessWidget {
  const _MobileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: WebDesign.muted),
          const SizedBox(width: 7),
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(color: WebDesign.muted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// STATUS
// ============================================================
//

class _VisitorStatusPill extends StatelessWidget {
  const _VisitorStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'entered':
        background = const Color(0xFFE4F7F1);
        foreground = const Color(0xFF087A5B);
        break;

      case 'approved':
        background = const Color(0xFFE6F0FF);
        foreground = const Color(0xFF246BFD);
        break;

      case 'exited':
        background = const Color(0xFFEFF2F6);
        foreground = const Color(0xFF526071);
        break;

      case 'generated':
        background = const Color(0xFFEFE8FF);
        foreground = const Color(0xFF6B35D4);
        break;

      case 'pending':
        background = const Color(0xFFFFF4D8);
        foreground = const Color(0xFFA96B00);
        break;

      case 'rejected':
      case 'expired':
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
// DATA HELPERS
//
// Field aliases are display compatibility only.
// They never broaden the Firestore query.
// ============================================================
//

String _visitorName(String documentId, Map<String, dynamic> data) {
  for (final key in const ['visitorName', 'name', 'guestName', 'personName']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return documentId;
}

String _visitorPhone(Map<String, dynamic> data) {
  for (final key in const [
    'visitorPhone',
    'phoneNumber',
    'phone',
    'mobileNumber',
    'mobile',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _hostName(Map<String, dynamic> data) {
  for (final key in const [
    'residentName',
    'hostName',
    'requestedByName',
    'createdByName',
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

String _visitorPurpose(Map<String, dynamic> data) {
  for (final key in const [
    'purpose',
    'visitPurpose',
    'reason',
    'visitorType',
    'type',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _visitorStatus(Map<String, dynamic> data) {
  for (final key in const ['status', 'visitStatus', 'approvalStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      if (value == 'pendingapproval' || value == 'pending_approval') {
        return 'pending';
      }

      return value;
    }
  }

  return 'pending';
}

DateTime _visitorSortDate(Map<String, dynamic> data) {
  for (final key in const [
    'visitDate',
    'visitAt',
    'expectedAt',
    'createdAt',
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

String _visitorDateLabel(Map<String, dynamic> data) {
  final date = _visitorSortDate(data);

  if (date.millisecondsSinceEpoch == 0) {
    return '';
  }

  final local = date.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();

  var hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';

  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }

  return '$day/$month/$year · $hour:$minute $period';
}

String _titleCase(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return 'Unknown';
  }

  final normalized = text.replaceAll('_', ' ');

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
