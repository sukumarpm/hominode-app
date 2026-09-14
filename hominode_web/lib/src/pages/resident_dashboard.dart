import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import '../session/web_session.dart';
import '../tenant/web_host.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/community_visuals.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key, required this.session, this.dataFuture});

  final WebSession session;
  final Future<ResidentDashboardData>? dataFuture;

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  late Future<ResidentDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ResidentDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid ||
        oldWidget.session.activeTenant?.communityId !=
            widget.session.activeTenant?.communityId ||
        oldWidget.session.flatId != widget.session.flatId) {
      _future = _load();
    }
  }

  Future<ResidentDashboardData> _load() =>
      widget.dataFuture ??
      DashboardRepository().residentDashboard(
        communityId: widget.session.activeTenant!.communityId,
        uid: widget.session.uid,
        flatId: widget.session.flatId,
      );

  void _navigateTo(String internalPath) {
    final externalPath = WebHostScope.maybeOf(
      context,
    )?.externalPathFor(internalPath);
    if (externalPath == null ||
        ModalRoute.of(context)?.settings.name == externalPath) {
      return;
    }
    Navigator.of(context).pushNamed(externalPath);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ResidentDashboardData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const SectionCard(
          title: 'Home overview',
          child: EmptyState(
            icon: Icons.error_outline,
            message: 'Your resident dashboard is currently unavailable.',
          ),
        );
      }

      final data = snapshot.data!;
      final apartment = SectionCard(
        title: 'My apartment',
        subtitle: widget.session.activeTenant!.name,
        action: TextButton(
          onPressed: () => _navigateTo('/resident/unit'),
          child: const Text('View all'),
        ),
        child: _ApartmentCard(session: widget.session),
      );
      final actions = SectionCard(
        title: 'Quick actions',

        child: QuickActionGrid(
          children: [
            QuickActionCard(
              label: 'My unit',
              icon: Icons.apartment_outlined,
              color: RolePalette.resident.primary,
              onTap: () => _navigateTo('/resident/unit'),
            ),
            QuickActionCard(
              label: 'Bills',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFFE66A2C),
              onTap: () => _navigateTo('/resident/bills'),
            ),
            QuickActionCard(
              label: 'Notices',
              icon: Icons.campaign_outlined,
              color: const Color(0xFF246BFD),
              onTap: () => _navigateTo('/resident/notices'),
            ),
            QuickActionCard(
              label: 'Events',
              icon: Icons.event_outlined,
              color: const Color(0xFF08A579),
              onTap: () => _navigateTo('/resident/events'),
            ),
            QuickActionCard(
              label: 'Visitors',
              icon: Icons.people_outline,
              color: const Color(0xFF246BFD),
              onTap: () => _navigateTo('/resident/visitors'),
            ),
            QuickActionCard(
              label: 'Complaints',
              icon: Icons.report_problem_outlined,
              color: const Color(0xFFE34A5F),
              onTap: () => _navigateTo('/resident/complaints'),
            ),
          ],
        ),
      );
      final notices = SectionCard(
        title: 'Community announcements',
        subtitle: 'Published and unexpired notices for your unit',
        action: TextButton(
          onPressed: () => _navigateTo('/resident/notices'),
          child: const Text('View all'),
        ),
        child: DashboardRecordList(
          records: data.recentNotices,
          emptyMessage: 'No active notices are available.',
          color: RolePalette.resident.primary,
          icon: Icons.campaign_outlined,
        ),
      );
      final events = SectionCard(
        title: 'Upcoming events',
        subtitle: 'Dated community events',
        action: TextButton(
          onPressed: () => _navigateTo('/resident/events'),
          child: const Text('View all'),
        ),
        child: DashboardRecordList(
          records: data.upcomingEvents,
          emptyMessage: 'No upcoming events are scheduled.',
          color: const Color(0xFF08A579),
          icon: Icons.event_outlined,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardPanelGrid(
            flexes: const [6, 5, 5],
            breakpoint: 1120,
            children: [
              Column(
                children: [
                  apartment,
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'At a glance',
                    child: ResponsiveMetricGrid(
                      children: [
                        DashboardStatCard(
                          label: 'Complaints',
                          value: metricValue(data.openComplaints),
                          caption: 'Open or in progress',
                          icon: Icons.campaign_outlined,
                          color: const Color(0xFFE34A5F),
                        ),
                        DashboardStatCard(
                          label: 'Visitors',
                          value: metricValue(data.visitorsToday),
                          caption: 'Today',
                          icon: Icons.people_outline,
                          color: const Color(0xFF246BFD),
                        ),
                        DashboardStatCard(
                          label: 'Pending bills',
                          value: metricValue(data.pendingBills),
                          caption: data.pendingAmount == null
                              ? 'Amount unavailable'
                              : '${moneyValue(data.pendingAmount)} due',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFE66A2C),
                        ),
                        DashboardStatCard(
                          label: 'Notices',
                          value: metricValue(data.activeNotices),
                          caption: 'Active for your unit',
                          icon: Icons.chat_bubble_outline,
                          color: RolePalette.resident.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  events,
                ],
              ),
              Column(
                children: [
                  notices,
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'My bills',
                    action: TextButton(
                      onPressed: () => _navigateTo('/resident/bills'),
                      child: const Text('View all'),
                    ),
                    child: DashboardRecordList(
                      records: data.bills?.take(3).toList(),
                      emptyMessage: 'No bills to show.',
                      color: RolePalette.resident.primary,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const CommunityPromo(),
                  const SizedBox(height: 16),
                  actions,
                  const SizedBox(height: 16),
                  _CommunityBanner(
                    communityName: widget.session.activeTenant!.brandName,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) {
    final unit = [
      session.buildingId,
      session.flatLabel,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RolePalette.resident.soft,
            RolePalette.resident.soft.withValues(alpha: .35),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: RolePalette.resident.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.isEmpty ? 'Unit details unavailable' : unit,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.activeTenant!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: WebDesign.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner({required this.communityName});

  final String communityName;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF254F40),
      borderRadius: BorderRadius.circular(WebDesign.radius),
      boxShadow: const [WebDesign.shadow],
    ),
    child: Row(
      children: [
        const Icon(Icons.favorite_outline, color: Colors.white, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                communityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Stay connected with your apartment and community updates.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
