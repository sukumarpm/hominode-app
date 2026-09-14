import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class AdminEventsNoticesPage extends StatefulWidget {
  const AdminEventsNoticesPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminEventsNoticesPage> createState() => _AdminEventsNoticesPageState();
}

class _AdminEventsNoticesPageState extends State<AdminEventsNoticesPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _typeFilter = 'all';
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
    final eventsQuery = FirebaseFirestore.instance
        .collection('events')
        .where('communityId', isEqualTo: _communityId);

    final noticesQuery = FirebaseFirestore.instance
        .collection('notices')
        .where('communityId', isEqualTo: _communityId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: eventsQuery.snapshots(),
      builder: (context, eventSnapshot) {
        if (eventSnapshot.hasError) {
          return const SectionCard(
            title: 'Events & Notices',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load events for this community.',
            ),
          );
        }

        if (!eventSnapshot.hasData) {
          return const SectionCard(
            title: 'Events & Notices',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: noticesQuery.snapshots(),
          builder: (context, noticeSnapshot) {
            if (noticeSnapshot.hasError) {
              return const SectionCard(
                title: 'Events & Notices',
                child: EmptyState(
                  icon: Icons.error_outline,
                  message: 'Unable to load notices for this community.',
                ),
              );
            }

            if (!noticeSnapshot.hasData) {
              return const SectionCard(
                title: 'Events & Notices',
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final items = <_CommunityFeedItem>[
              ...eventSnapshot.data!.docs
                  .where(
                    (doc) =>
                        doc.data()['communityId']?.toString() == _communityId,
                  )
                  .map(
                    (doc) => _CommunityFeedItem(
                      id: doc.id,
                      kind: 'event',
                      data: doc.data(),
                    ),
                  ),
              ...noticeSnapshot.data!.docs
                  .where(
                    (doc) =>
                        doc.data()['communityId']?.toString() == _communityId,
                  )
                  .map(
                    (doc) => _CommunityFeedItem(
                      id: doc.id,
                      kind: 'notice',
                      data: doc.data(),
                    ),
                  ),
            ];

            final eventCount = items
                .where((item) => item.kind == 'event')
                .length;

            final noticeCount = items
                .where((item) => item.kind == 'notice')
                .length;

            final activeCount = items
                .where((item) => _itemStatus(item.data) == 'active')
                .length;

            final scheduledCount = items
                .where((item) => _itemStatus(item.data) == 'scheduled')
                .length;

            final filteredItems =
                items.where((item) {
                  final data = item.data;

                  final query = _searchText.trim().toLowerCase();

                  if (query.isNotEmpty) {
                    final searchable = [
                      _itemTitle(item.id, data),
                      _itemDescription(data),
                      _itemCategory(data),
                      _itemStatus(data),
                      item.kind,
                    ].join(' ').toLowerCase();

                    if (!searchable.contains(query)) {
                      return false;
                    }
                  }

                  if (_typeFilter != 'all' && item.kind != _typeFilter) {
                    return false;
                  }

                  if (_statusFilter != 'all' &&
                      _itemStatus(data) != _statusFilter) {
                    return false;
                  }

                  return true;
                }).toList()..sort(
                  (a, b) =>
                      _itemSortDate(b.data).compareTo(_itemSortDate(a.data)),
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EventsNoticesHero(
                  communityName: _communityName,
                  total: items.length,
                  events: eventCount,
                  notices: noticeCount,
                  active: activeCount,
                  scheduled: scheduledCount,
                ),
                const SizedBox(height: 16),
                _QuickNavigation(onNavigate: widget.onNavigate),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Community Updates',
                  action: _EventsNoticesToolbar(
                    searchController: _searchController,
                    searchText: _searchText,
                    typeFilter: _typeFilter,
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
                    onTypeChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _typeFilter = value;
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
                  child: filteredItems.isEmpty
                      ? EmptyState(
                          icon: Icons.campaign_outlined,
                          message:
                              _searchText.trim().isNotEmpty ||
                                  _typeFilter != 'all' ||
                                  _statusFilter != 'all'
                              ? 'No events or notices match the selected filters.'
                              : 'No events or notices are available for this community.',
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 980) {
                              return _EventsNoticesTable(
                                items: filteredItems,
                                onNavigate: widget.onNavigate,
                              );
                            }

                            return Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < filteredItems.length;
                                  i++
                                ) ...[
                                  _EventsNoticesMobileCard(
                                    item: filteredItems[i],
                                    onNavigate: widget.onNavigate,
                                  ),
                                  if (i != filteredItems.length - 1)
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
}

class _CommunityFeedItem {
  const _CommunityFeedItem({
    required this.id,
    required this.kind,
    required this.data,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> data;
}

//
// ============================================================
// HERO
// ============================================================
//

class _EventsNoticesHero extends StatelessWidget {
  const _EventsNoticesHero({
    required this.communityName,
    required this.total,
    required this.events,
    required this.notices,
    required this.active,
    required this.scheduled,
  });

  final String communityName;
  final int total;
  final int events;
  final int notices;
  final int active;
  final int scheduled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WebDesign.adminPageHeader,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

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
                  Icons.campaign_outlined,
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
                      'Events & Notices',
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
              _HeroMetric(label: 'Events', value: '$events'),
              _HeroMetric(label: 'Notices', value: '$notices'),
              _HeroMetric(label: 'Active', value: '$active'),
              _HeroMetric(label: 'Scheduled', value: '$scheduled'),
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
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

class _EventsNoticesToolbar extends StatelessWidget {
  const _EventsNoticesToolbar({
    required this.searchController,
    required this.searchText,
    required this.typeFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;

  final String searchText;
  final String typeFilter;
  final String statusFilter;

  final ValueChanged<String> onSearchChanged;

  final VoidCallback onSearchClear;

  final ValueChanged<String?> onTypeChanged;

  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 235,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search updates...',
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
          value: typeFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All types')),
            DropdownMenuItem(value: 'event', child: Text('Events')),
            DropdownMenuItem(value: 'notice', child: Text('Notices')),
          ],
          onChanged: onTypeChanged,
        ),
        _FilterDropdown(
          value: statusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All status')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
            DropdownMenuItem(value: 'expired', child: Text('Expired')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
          ],
          onChanged: onStatusChanged,
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

class _EventsNoticesTable extends StatelessWidget {
  const _EventsNoticesTable({required this.items, required this.onNavigate});

  final List<_CommunityFeedItem> items;

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(1.1),
        5: FlexColumnWidth(.7),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: WebDesign.border),
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            _TableHeader('Title'),
            _TableHeader('Type'),
            _TableHeader('Category'),
            _TableHeader('Date'),
            _TableHeader('Status'),
            _TableHeader(''),
          ],
        ),
        for (final item in items) _itemRow(item),
      ],
    );
  }

  TableRow _itemRow(_CommunityFeedItem item) {
    final data = item.data;

    return TableRow(
      children: [
        _TitleCell(
          title: _itemTitle(item.id, data),
          description: _itemDescription(data),
          kind: item.kind,
        ),
        _TypeCell(kind: item.kind),
        _TableTextCell(text: _itemCategory(data)),
        _TableTextCell(text: _itemDateLabel(data)),
        _StatusCell(status: _itemStatus(data)),
        _ActionCell(
          onCommunity: () => onNavigate('/admin/community'),
          onResidents: () => onNavigate('/admin/residents'),
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

class _TitleCell extends StatelessWidget {
  const _TitleCell({
    required this.title,
    required this.description,
    required this.kind,
  });

  final String title;
  final String description;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final isEvent = kind == 'event';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isEvent
                  ? const Color(0xFFE6F0FF)
                  : const Color(0xFFFFF4D8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEvent ? Icons.event_outlined : Icons.campaign_outlined,
              size: 19,
              color: isEvent
                  ? const Color(0xFF246BFD)
                  : const Color(0xFFA96B00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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

class _TypeCell extends StatelessWidget {
  const _TypeCell({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final isEvent = kind == 'event';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isEvent ? const Color(0xFFE6F0FF) : const Color(0xFFFFF4D8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isEvent ? 'Event' : 'Notice',
            style: TextStyle(
              color: isEvent
                  ? const Color(0xFF246BFD)
                  : const Color(0xFFA96B00),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.onCommunity, required this.onResidents});

  final VoidCallback onCommunity;
  final VoidCallback onResidents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          tooltip: 'Update actions',
          onSelected: (value) {
            switch (value) {
              case 'community':
                onCommunity();
                break;
              case 'residents':
                onResidents();
                break;
            }
          },
          itemBuilder: (_) {
            return const [
              PopupMenuItem(
                value: 'community',
                child: Row(
                  children: [
                    Icon(Icons.apartment_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('My Community'),
                  ],
                ),
              ),
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

class _EventsNoticesMobileCard extends StatelessWidget {
  const _EventsNoticesMobileCard({
    required this.item,
    required this.onNavigate,
  });

  final _CommunityFeedItem item;

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = item.data;

    final title = _itemTitle(item.id, data);

    final description = _itemDescription(data);

    final category = _itemCategory(data);

    final date = _itemDateLabel(data);

    final status = _itemStatus(data);

    final isEvent = item.kind == 'event';

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
                  color: isEvent
                      ? const Color(0xFFE6F0FF)
                      : const Color(0xFFFFF4D8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEvent ? Icons.event_outlined : Icons.campaign_outlined,
                  color: isEvent
                      ? const Color(0xFF246BFD)
                      : const Color(0xFFA96B00),
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
                    const SizedBox(height: 3),
                    Text(
                      isEvent ? 'Event' : 'Notice',
                      style: TextStyle(
                        color: isEvent
                            ? const Color(0xFF246BFD)
                            : const Color(0xFFA96B00),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: WebDesign.muted, fontSize: 11),
            ),
          ],

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (category.isNotEmpty)
                _InfoPill(icon: Icons.category_outlined, label: category),
              if (date.isNotEmpty)
                _InfoPill(icon: Icons.calendar_today_outlined, label: date),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => onNavigate('/admin/community'),
                icon: const Icon(Icons.apartment_outlined, size: 16),
                label: const Text('Community'),
              ),
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
            ],
          ),
        ],
      ),
    );
  }
}

//
// ============================================================
// SMALL UI
// ============================================================
//

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
      case 'active':
      case 'published':
        background = const Color(0xFFE8F8F2);
        foreground = const Color(0xFF087A5B);
        break;

      case 'scheduled':
        background = const Color(0xFFE6F0FF);
        foreground = const Color(0xFF246BFD);
        break;

      case 'expired':
      case 'inactive':
      case 'cancelled':
        background = const Color(0xFFF0F2F6);
        foreground = WebDesign.muted;
        break;

      default:
        background = const Color(0xFFFFF4D8);
        foreground = const Color(0xFFA96B00);
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

String _itemTitle(String documentId, Map<String, dynamic> data) {
  for (final key in const [
    'title',
    'name',
    'eventTitle',
    'noticeTitle',
    'subject',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return documentId;
}

String _itemDescription(Map<String, dynamic> data) {
  for (final key in const [
    'description',
    'message',
    'details',
    'content',
    'body',
  ]) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _itemCategory(Map<String, dynamic> data) {
  for (final key in const ['category', 'type', 'eventType', 'noticeType']) {
    final value = data[key]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

String _itemStatus(Map<String, dynamic> data) {
  if (data['isActive'] is bool && data['isActive'] == false) {
    return 'inactive';
  }

  for (final key in const ['status', 'publicationStatus', 'eventStatus']) {
    final value = data[key]?.toString().trim().toLowerCase();

    if (value != null && value.isNotEmpty) {
      return value.replaceAll(' ', '');
    }
  }

  final now = DateTime.now();

  final end = _extractDate(data, const [
    'endDate',
    'endsAt',
    'expiryDate',
    'expiresAt',
  ]);

  if (end != null && end.isBefore(now)) {
    return 'expired';
  }

  final start = _extractDate(data, const [
    'eventDate',
    'startDate',
    'startsAt',
    'scheduledAt',
  ]);

  if (start != null && start.isAfter(now)) {
    return 'scheduled';
  }

  return 'active';
}

DateTime _itemSortDate(Map<String, dynamic> data) {
  return _extractDate(data, const [
        'eventDate',
        'startDate',
        'startsAt',
        'scheduledAt',
        'publishedAt',
        'createdAt',
        'updatedAt',
      ]) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _itemDateLabel(Map<String, dynamic> data) {
  final date = _itemSortDate(data);

  if (date.millisecondsSinceEpoch == 0) {
    return '';
  }

  final local = date.toLocal();

  final day = local.day.toString().padLeft(2, '0');

  final month = local.month.toString().padLeft(2, '0');

  var hour = local.hour;

  final minute = local.minute.toString().padLeft(2, '0');

  final period = hour >= 12 ? 'PM' : 'AM';

  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }

  return '$day/$month/${local.year} · $hour:$minute $period';
}

DateTime? _extractDate(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
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

  return null;
}

String _titleCase(String value) {
  final text = value.trim().replaceAll('_', ' ');

  if (text.isEmpty) {
    return 'Unknown';
  }

  return text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
