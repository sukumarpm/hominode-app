import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminAmenitiesPage extends StatefulWidget {
  const AdminAmenitiesPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminAmenitiesPage> createState() => _AdminAmenitiesPageState();
}

class _AdminAmenitiesPageState extends State<AdminAmenitiesPage> {
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
    // Amenities are read only from the validated active community.
    //
    final amenitiesQuery = FirebaseFirestore.instance
        .collection('amenities')
        .where('communityId', isEqualTo: _communityId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: amenitiesQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionCard(
            title: 'Amenities',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load amenities for this community.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SectionCard(
            title: 'Amenities',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final amenities = snapshot.data!.docs.where((doc) {
          return doc.data()['communityId']?.toString() == _communityId;
        }).toList();

        final activeCount = amenities
            .where((doc) => _amenityIsActive(doc.data()))
            .length;

        final inactiveCount = amenities.length - activeCount;

        final bookableCount = amenities
            .where((doc) => _amenityIsBookable(doc.data()))
            .length;

        final filteredAmenities =
            amenities.where((doc) {
              final data = doc.data();

              final query = _searchText.trim().toLowerCase();

              if (query.isNotEmpty) {
                final searchable = [
                  _amenityName(doc.id, data),
                  _amenityDescription(data),
                  _amenityLocation(data),
                  _amenityType(data),
                  _amenityStatus(data),
                ].join(' ').toLowerCase();

                if (!searchable.contains(query)) {
                  return false;
                }
              }

              if (_statusFilter == 'active' && !_amenityIsActive(data)) {
                return false;
              }

              if (_statusFilter == 'inactive' && _amenityIsActive(data)) {
                return false;
              }

              if (_statusFilter == 'bookable' && !_amenityIsBookable(data)) {
                return false;
              }

              return true;
            }).toList()..sort(
              (a, b) => _amenityName(a.id, a.data()).toLowerCase().compareTo(
                _amenityName(b.id, b.data()).toLowerCase(),
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmenitiesHero(
              communityName: _communityName,
              total: amenities.length,
              active: activeCount,
              inactive: inactiveCount,
              bookable: bookableCount,
            ),

            const SizedBox(height: 16),

            _QuickNavigation(onNavigate: widget.onNavigate),

            const SizedBox(height: 16),

            SectionCard(
              title: 'Amenity Directory',
              action: _AmenityToolbar(
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
              child: filteredAmenities.isEmpty
                  ? EmptyState(
                      icon: Icons.spa_outlined,
                      message:
                          _searchText.trim().isNotEmpty ||
                              _statusFilter != 'all'
                          ? 'No amenities match the selected filters.'
                          : 'No amenities are configured for this community.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 950) {
                          return _AmenitiesTable(
                            amenities: filteredAmenities,
                            onNavigate: widget.onNavigate,
                          );
                        }

                        return Column(
                          children: [
                            for (
                              var i = 0;
                              i < filteredAmenities.length;
                              i++
                            ) ...[
                              _AmenityMobileCard(
                                document: filteredAmenities[i],
                                onNavigate: widget.onNavigate,
                              ),
                              if (i != filteredAmenities.length - 1)
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

class _AmenitiesHero extends StatelessWidget {
  const _AmenitiesHero({
    required this.communityName,
    required this.total,
    required this.active,
    required this.inactive,
    required this.bookable,
  });

  final String communityName;
  final int total;
  final int active;
  final int inactive;
  final int bookable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WebDesign.adminPageHeader,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final heading = Row(
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
                  Icons.spa_outlined,
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
                      'Amenities',
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
              _HeroMetric(label: 'Total', value: '$total'),
              _HeroMetric(label: 'Active', value: '$active'),
              _HeroMetric(label: 'Inactive', value: '$inactive'),
              _HeroMetric(label: 'Bookable', value: '$bookable'),
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
            label: 'Reports',
            icon: Icons.analytics_outlined,
            color: const Color(0xFFE66A2C),
            onTap: () => onNavigate('/admin/reports'),
          ),
          QuickActionCard(
            label: 'Settings',
            icon: Icons.settings_outlined,
            color: const Color(0xFF7A42D8),
            onTap: () => onNavigate('/admin/settings'),
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

class _AmenityToolbar extends StatelessWidget {
  const _AmenityToolbar({
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
          width: 245,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search amenities...',
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
                DropdownMenuItem(value: 'all', child: Text('All amenities')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'bookable', child: Text('Bookable')),
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

class _AmenitiesTable extends StatelessWidget {
  const _AmenitiesTable({required this.amenities, required this.onNavigate});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> amenities;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.7),
        3: FlexColumnWidth(1.2),
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
            _TableHeader('Amenity'),
            _TableHeader('Type'),
            _TableHeader('Location'),
            _TableHeader('Booking'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final doc in amenities) _amenityRow(doc),
      ],
    );
  }

  TableRow _amenityRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return TableRow(
      children: [
        _AmenityNameCell(
          name: _amenityName(doc.id, data),
          description: _amenityDescription(data),
        ),
        _TableTextCell(text: _amenityType(data)),
        _TableTextCell(text: _amenityLocation(data)),
        _BookingCell(
          isBookable: _amenityIsBookable(data),
          fee: _amenityFee(data),
        ),
        _StatusCell(status: _amenityStatus(data)),
        _AmenityActionsCell(
          onResidents: () => onNavigate('/admin/residents'),
          onReports: () => onNavigate('/admin/reports'),
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

class _AmenityNameCell extends StatelessWidget {
  const _AmenityNameCell({required this.name, required this.description});

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: RolePalette.admin.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _amenityIcon(name),
              color: RolePalette.admin.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
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

class _BookingCell extends StatelessWidget {
  const _BookingCell({required this.isBookable, required this.fee});

  final bool isBookable;
  final String fee;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBookable ? 'Bookable' : 'No booking',
            style: TextStyle(
              color: isBookable ? const Color(0xFF087A5B) : WebDesign.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (fee.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              fee,
              style: const TextStyle(color: WebDesign.muted, fontSize: 9),
            ),
          ],
        ],
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
        child: _AmenityStatusPill(status: status),
      ),
    );
  }
}

class _AmenityActionsCell extends StatelessWidget {
  const _AmenityActionsCell({
    required this.onResidents,
    required this.onReports,
  });

  final VoidCallback onResidents;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          tooltip: 'Amenity actions',
          onSelected: (value) {
            switch (value) {
              case 'residents':
                onResidents();
                break;

              case 'reports':
                onReports();
                break;
            }
          },
          itemBuilder: (_) {
            return const [
              PopupMenuItem(
                value: 'residents',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Residents'),
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

class _AmenityMobileCard extends StatelessWidget {
  const _AmenityMobileCard({required this.document, required this.onNavigate});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final name = _amenityName(document.id, data);

    final description = _amenityDescription(data);
    final type = _amenityType(data);
    final location = _amenityLocation(data);
    final status = _amenityStatus(data);
    final isBookable = _amenityIsBookable(data);
    final fee = _amenityFee(data);

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RolePalette.admin.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _amenityIcon(name),
                  color: RolePalette.admin.primary,
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
                    if (type.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        type,
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
              _AmenityStatusPill(status: status),
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
              if (location.isNotEmpty)
                _InfoPill(icon: Icons.location_on_outlined, label: location),
              _InfoPill(
                icon: Icons.event_available_outlined,
                label: isBookable ? 'Booking available' : 'No booking',
              ),
              if (fee.isNotEmpty)
                _InfoPill(icon: Icons.payments_outlined, label: fee),
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
                onPressed: () => onNavigate('/admin/reports'),
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('Reports'),
              ),
              TextButton.icon(
                onPressed: () => onNavigate('/admin/settings'),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Settings'),
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

class _AmenityStatusPill extends StatelessWidget {
  const _AmenityStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F8F2) : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: active ? const Color(0xFF087A5B) : const Color(0xFFB93C3C),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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
// FIELD HELPERS
//
// Existing aliases are tolerated for display only.
// They never widen the community-scoped Firestore query.
// ============================================================
//

String _amenityName(String documentId, Map<String, dynamic> data) {
  for (final key in const ['name', 'amenityName', 'title']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return documentId;
}

String _amenityDescription(Map<String, dynamic> data) {
  for (final key in const ['description', 'details', 'summary']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _amenityType(Map<String, dynamic> data) {
  for (final key in const ['type', 'category', 'amenityType']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _amenityLocation(Map<String, dynamic> data) {
  for (final key in const ['location', 'area', 'buildingName', 'buildingId']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

bool _amenityIsActive(Map<String, dynamic> data) {
  if (data['isActive'] is bool) {
    return data['isActive'] == true;
  }

  final status = data['status']?.toString().trim().toLowerCase();

  if (status != null && status.isNotEmpty) {
    return status != 'inactive' && status != 'disabled' && status != 'closed';
  }

  return true;
}

String _amenityStatus(Map<String, dynamic> data) {
  return _amenityIsActive(data) ? 'Active' : 'Inactive';
}

bool _amenityIsBookable(Map<String, dynamic> data) {
  for (final key in const [
    'isBookable',
    'bookingEnabled',
    'allowBooking',
    'requiresBooking',
  ]) {
    if (data[key] is bool) {
      return data[key] == true;
    }
  }

  return false;
}

String _amenityFee(Map<String, dynamic> data) {
  for (final key in const ['bookingFee', 'fee', 'price', 'amount']) {
    final value = data[key];

    if (value == null) {
      continue;
    }

    if (value is num) {
      if (value == 0) {
        return 'Free';
      }

      return value.toString();
    }

    final text = value.toString().trim();

    if (text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

IconData _amenityIcon(String name) {
  final text = name.toLowerCase();

  if (text.contains('pool') || text.contains('swim')) {
    return Icons.pool_outlined;
  }

  if (text.contains('gym') || text.contains('fitness')) {
    return Icons.fitness_center_outlined;
  }

  if (text.contains('hall') || text.contains('function')) {
    return Icons.meeting_room_outlined;
  }

  if (text.contains('park') || text.contains('garden')) {
    return Icons.park_outlined;
  }

  if (text.contains('court') || text.contains('sport')) {
    return Icons.sports_tennis_outlined;
  }

  if (text.contains('play')) {
    return Icons.toys_outlined;
  }

  if (text.contains('club')) {
    return Icons.groups_outlined;
  }

  return Icons.spa_outlined;
}
