import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminBuildingsPage extends StatefulWidget {
  const AdminBuildingsPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminBuildingsPage> createState() => _AdminBuildingsPageState();
}

class _AdminBuildingsPageState extends State<AdminBuildingsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  String get _communityId {
    return widget.session.activeTenant!.communityId;
  }

  String get _communityName {
    return widget.session.activeTenant!.name;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //
    // SECURITY:
    // Never query the complete collection here.
    // The active community comes only from the validated WebSession.
    //
    final buildingsQuery = FirebaseFirestore.instance
        .collection('buildings')
        .where('communityId', isEqualTo: _communityId);

    final flatsQuery = FirebaseFirestore.instance
        .collection('flats')
        .where('communityId', isEqualTo: _communityId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: buildingsQuery.snapshots(),
      builder: (context, buildingSnapshot) {
        if (buildingSnapshot.hasError) {
          return const SectionCard(
            title: 'Buildings',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load buildings for this community.',
            ),
          );
        }

        if (!buildingSnapshot.hasData) {
          return const SectionCard(
            title: 'Buildings',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: flatsQuery.snapshots(),
          builder: (context, flatSnapshot) {
            final buildingDocs = buildingSnapshot.data!.docs;

            final flatCounts = _buildFlatCounts(
              flatSnapshot.data?.docs ?? const [],
            );

            final totalFlats = flatCounts.values.fold<int>(
              0,
              (sum, count) => sum + count,
            );

            final filteredBuildings =
                buildingDocs.where((doc) {
                  final query = _searchText.trim().toLowerCase();

                  if (query.isEmpty) {
                    return true;
                  }

                  final data = doc.data();

                  final searchableText = [
                    _buildingName(doc.id, data),
                    _buildingAddress(data),
                    _buildingCode(data),
                    _buildingStatus(data),
                  ].join(' ').toLowerCase();

                  return searchableText.contains(query);
                }).toList()..sort((a, b) {
                  return _buildingName(a.id, a.data()).toLowerCase().compareTo(
                    _buildingName(b.id, b.data()).toLowerCase(),
                  );
                });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BuildingsHero(
                  communityName: _communityName,
                  buildingCount: buildingDocs.length,
                  flatCount: totalFlats,
                ),

                const SizedBox(height: 16),

                _QuickNavigation(onNavigate: widget.onNavigate),

                const SizedBox(height: 16),

                SectionCard(
                  title: 'Building Directory',
                  action: _SearchBox(
                    controller: _searchController,
                    searchText: _searchText,
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    onClear: () {
                      _searchController.clear();

                      setState(() {
                        _searchText = '';
                      });
                    },
                  ),
                  child: filteredBuildings.isEmpty
                      ? EmptyState(
                          icon: Icons.apartment_outlined,
                          message: _searchText.trim().isEmpty
                              ? 'No buildings have been created for this community.'
                              : 'No buildings match your search.',
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 850) {
                              return _BuildingsTable(
                                buildings: filteredBuildings,
                                flatCounts: flatCounts,
                                onNavigate: widget.onNavigate,
                              );
                            }

                            return Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < filteredBuildings.length;
                                  i++
                                ) ...[
                                  _BuildingMobileCard(
                                    document: filteredBuildings[i],
                                    flatCount:
                                        flatCounts[filteredBuildings[i].id] ??
                                        0,
                                    onNavigate: widget.onNavigate,
                                  ),
                                  if (i != filteredBuildings.length - 1)
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
      },
    );
  }

  Map<String, int> _buildFlatCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> flats,
  ) {
    final counts = <String, int>{};

    for (final flat in flats) {
      final data = flat.data();

      //
      // Even though the Firestore query is already community-scoped,
      // fail closed if malformed data is ever returned.
      //
      if (data['communityId']?.toString() != _communityId) {
        continue;
      }

      final buildingId = data['buildingId']?.toString().trim();

      if (buildingId == null || buildingId.isEmpty) {
        continue;
      }

      counts[buildingId] = (counts[buildingId] ?? 0) + 1;
    }

    return counts;
  }
}

//
// ============================================================
// HEADER / HERO
// ============================================================
//

class _BuildingsHero extends StatelessWidget {
  const _BuildingsHero({
    required this.communityName,
    required this.buildingCount,
    required this.flatCount,
  });

  final String communityName;
  final int buildingCount;
  final int flatCount;

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
          final compact = constraints.maxWidth < 700;

          final heading = Row(
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
                  Icons.apartment_rounded,
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
                      'Buildings',
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
              _HeroMetric(label: 'Buildings', value: buildingCount.toString()),
              _HeroMetric(label: 'Flats', value: flatCount.toString()),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 16), metrics],
            );
          }

          return Row(
            children: [
              Expanded(child: heading),
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
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
// QUICK NAVIGATION
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
            label: 'Complaints',
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFE34A5F),
            onTap: () => onNavigate('/admin/complaints'),
          ),
          QuickActionCard(
            label: 'Settings',
            icon: Icons.settings_outlined,
            color: const Color(0xFFE66A2C),
            onTap: () => onNavigate('/admin/settings'),
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// SEARCH
// ============================================================
//

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.searchText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String searchText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search buildings...',
          prefixIcon: const Icon(Icons.search, size: 19),
          suffixIcon: searchText.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WebDesign.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WebDesign.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: RolePalette.admin.primary,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

//
// ============================================================
// DESKTOP TABLE
// ============================================================
//

class _BuildingsTable extends StatelessWidget {
  const _BuildingsTable({
    required this.buildings,
    required this.flatCounts,
    required this.onNavigate,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> buildings;

  final Map<String, int> flatCounts;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.1),
        1: FlexColumnWidth(2.8),
        2: FlexColumnWidth(.8),
        3: FlexColumnWidth(.9),
        4: FlexColumnWidth(.7),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: WebDesign.border),
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            _TableHeader('Building'),
            _TableHeader('Address / Details'),
            _TableHeader('Flats'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final doc in buildings) _buildingRow(doc),
      ],
    );
  }

  TableRow _buildingRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final name = _buildingName(doc.id, data);

    final address = _buildingAddress(data);

    final status = _buildingStatus(data);

    final flatCount = flatCounts[doc.id] ?? 0;

    return TableRow(
      children: [
        _BuildingNameCell(name: name, code: _buildingCode(data)),
        _TableTextCell(text: address),
        _TableTextCell(text: flatCount.toString()),
        _StatusCell(status: status),
        _ActionsCell(onResidents: () => onNavigate('/admin/residents')),
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

class _BuildingNameCell extends StatelessWidget {
  const _BuildingNameCell({required this.name, required this.code});

  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: RolePalette.admin.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.apartment_outlined,
              size: 19,
              color: RolePalette.admin.primary,
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
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    code,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: WebDesign.text, fontSize: 11),
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

class _ActionsCell extends StatelessWidget {
  const _ActionsCell({required this.onResidents});

  final VoidCallback onResidents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          tooltip: 'Building actions',
          onSelected: (value) {
            if (value == 'residents') {
              onResidents();
            }
          },
          itemBuilder: (_) {
            return const [
              PopupMenuItem<String>(
                value: 'residents',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 18),
                    SizedBox(width: 8),
                    Text('View residents'),
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
// MOBILE / NARROW VIEW
// ============================================================
//

class _BuildingMobileCard extends StatelessWidget {
  const _BuildingMobileCard({
    required this.document,
    required this.flatCount,
    required this.onNavigate,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  final int flatCount;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final name = _buildingName(document.id, data);

    final address = _buildingAddress(data);

    final status = _buildingStatus(data);

    final code = _buildingCode(data);

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RolePalette.admin.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.apartment_outlined,
                  color: RolePalette.admin.primary,
                ),
              ),
              const SizedBox(width: 12),
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
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        code,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: WebDesign.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(color: WebDesign.muted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SmallInfoPill(
                icon: Icons.door_front_door_outlined,
                label: '$flatCount flats',
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onNavigate('/admin/residents'),
                icon: const Icon(Icons.people_outline, size: 17),
                label: const Text('Residents'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// SMALL COMPONENTS
// ============================================================
//

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final active = normalized == 'active' || normalized == 'approved';

    final background = active
        ? const Color(0xFFE8F8F2)
        : const Color(0xFFFFEEEE);

    final foreground = active
        ? const Color(0xFF087A5B)
        : const Color(0xFFB93C3C);

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

class _SmallInfoPill extends StatelessWidget {
  const _SmallInfoPill({required this.icon, required this.label});

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
// FIRESTORE FIELD COMPATIBILITY HELPERS
//
// These support existing/legacy field aliases without ever
// broadening the tenant query.
// ============================================================
//

String _buildingName(String documentId, Map<String, dynamic> data) {
  for (final key in const ['name', 'buildingName', 'title']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return documentId;
}

String _buildingCode(Map<String, dynamic> data) {
  for (final key in const ['code', 'buildingCode', 'shortName']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _buildingAddress(Map<String, dynamic> data) {
  for (final key in const [
    'address',
    'buildingAddress',
    'location',
    'description',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return 'Address not provided';
}

String _buildingStatus(Map<String, dynamic> data) {
  if (data['isActive'] is bool) {
    return data['isActive'] == true ? 'Active' : 'Inactive';
  }

  final status = data['status']?.toString().trim();

  if (status == null || status.isEmpty) {
    return 'Active';
  }

  return status;
}
