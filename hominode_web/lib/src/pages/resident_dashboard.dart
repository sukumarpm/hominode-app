import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key, required this.session});

  final WebSession session;

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
      DashboardRepository().residentDashboard(
        communityId: widget.session.activeTenant!.communityId,
        uid: widget.session.uid,
        flatId: widget.session.flatId,
      );

  void _navigateTo(String path) {
    if (ModalRoute.of(context)?.settings.name == path) return;
    Navigator.of(context).pushNamed(path);
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveMetricGrid(
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
          const SizedBox(height: 14),
          DashboardPanelGrid(
            flexes: const [1, 2],
            children: [
              SectionCard(
                title: 'My apartment',
                subtitle: widget.session.activeTenant!.name,
                child: _ApartmentCard(session: widget.session),
              ),
              SectionCard(
                title: 'Quick access',
                subtitle: 'Jump to your dashboard information',
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DashboardPanelGrid(
            children: [
              SectionCard(
                title: 'Recent notices',
                subtitle: 'Published and unexpired notices for your unit',
                child: DashboardRecordList(
                  records: data.recentNotices,
                  emptyMessage: 'No active notices are available.',
                  color: RolePalette.resident.primary,
                  icon: Icons.campaign_outlined,
                ),
              ),
              SectionCard(
                title: 'Upcoming events',
                subtitle: 'Dated community events',
                child: DashboardRecordList(
                  records: data.upcomingEvents,
                  emptyMessage: 'No upcoming events are scheduled.',
                  color: const Color(0xFF08A579),
                  icon: Icons.event_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CommunityBanner(
            communityName: widget.session.activeTenant!.brandName,
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
            child: const Icon(
              Icons.apartment_rounded,
              color: Color(0xFF6B35D4),
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
      gradient: LinearGradient(
        colors: [RolePalette.resident.dark, RolePalette.resident.primary],
      ),
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
