import 'package:flutter/material.dart';
import 'package:hominode_sos/hominode_sos.dart';

import '../services/dashboard_repository.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/community_visuals.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    super.key,
    required this.session,
    required this.onNavigate,
    this.dataFuture,
    this.sosClient,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;
  final Future<AdminDashboardData>? dataFuture;
  final SosClient? sosClient;

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminDashboardData>(
    future:
        dataFuture ??
        DashboardRepository().adminDashboard(session.activeTenant!.communityId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const SectionCard(
          title: 'Society overview',
          child: EmptyState(
            icon: Icons.error_outline,
            message: 'Community dashboard data is currently unavailable.',
          ),
        );
      }

      final data = snapshot.data!;
      final overview = SectionCard(
        title: 'Society overview',
        subtitle: session.activeTenant!.name,
        action: TextButton(
          onPressed: () => onNavigate('/admin/community'),
          child: const Text('View'),
        ),
        child: Column(
          children: [
            _OverviewRow(
              icon: Icons.people_outline,
              label: 'Residents',
              value: metricValue(data.residents),
              onTap: () => onNavigate('/admin/residents'),
            ),
            const Divider(height: 20, color: WebDesign.border),
            _OverviewRow(
              icon: Icons.apartment_outlined,
              label: 'Buildings',
              value: metricValue(data.buildings),
              onTap: () => onNavigate('/admin/buildings'),
            ),
            const Divider(height: 20, color: WebDesign.border),
            _OverviewRow(
              icon: Icons.badge_outlined,
              label: 'Pending visitors',
              value: metricValue(data.pendingVisitors),
              onTap: () => onNavigate('/admin/visitors'),
            ),
            const Divider(height: 20, color: WebDesign.border),
            _OverviewRow(
              icon: Icons.report_problem_outlined,
              label: 'Open complaints',
              value: metricValue(data.openComplaints),
              onTap: () => onNavigate('/admin/complaints'),
            ),
          ],
        ),
      );
      final visitors = SectionCard(
        title: 'Visitors today',
        action: TextButton(
          onPressed: () => onNavigate('/admin/visitors'),
          child: const Text('View all'),
        ),
        child: DashboardRecordList(
          records: data.visitorsToday,
          emptyMessage: 'No visitors are scheduled today.',
          color: RolePalette.admin.primary,
          icon: Icons.person_outline,
        ),
      );
      final complaints = SectionCard(
        title: 'Recent complaints',
        action: TextButton(
          onPressed: () => onNavigate('/admin/complaints'),
          child: const Text('View all'),
        ),
        child: DashboardRecordList(
          records: data.recentComplaints,
          emptyMessage: 'No complaint records are available.',
          color: const Color(0xFFE34A5F),
          icon: Icons.assignment_outlined,
        ),
      );
      final collection = SectionCard(
        title: 'Total maintenance collection',
        subtitle: 'Current bill status composition',
        action: TextButton(
          onPressed: () => onNavigate('/admin/billing'),
          child: const Text('Billing'),
        ),
        child:
            data.paidAmount == null ||
                data.pendingAmount == null ||
                data.overdueAmount == null
            ? const EmptyState(
                icon: Icons.cloud_off_outlined,
                message: 'Billing summary is unavailable.',
              )
            : CollectionSnapshot(
                collected: data.paidAmount!,
                pending: data.pendingAmount!,
                overdue: data.overdueAmount!,
              ),
      );
      final actions = SectionCard(
        title: 'Quick actions',
        child: QuickActionGrid(
          children: [
            QuickActionCard(
              label: 'Visitors',
              icon: Icons.badge_outlined,
              color: RolePalette.admin.primary,
              onTap: () => onNavigate('/admin/visitors'),
            ),
            QuickActionCard(
              label: 'Residents',
              icon: Icons.person_add_alt_1_outlined,
              color: const Color(0xFF246BFD),
              onTap: () => onNavigate('/admin/residents'),
            ),
            QuickActionCard(
              label: 'Notices',
              icon: Icons.campaign_outlined,
              color: const Color(0xFFE66A2C),
              onTap: () => onNavigate('/admin/events'),
            ),
            QuickActionCard(
              label: 'Billing',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF7A42D8),
              onTap: () => onNavigate('/admin/billing'),
            ),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SosActiveBanner(
            client: sosClient,
            communityId: session.activeTenant!.communityId,
          ),
          DashboardPanelGrid(
            flexes: const [3, 2],
            breakpoint: 960,
            children: [
              Column(
                children: [
                  collection,
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Today’s overview',
                    child: ResponsiveMetricGrid(
                      children: [
                        DashboardStatCard(
                          label: 'Residents',
                          value: metricValue(data.residents),
                          caption: session.activeTenant!.name,
                          icon: Icons.people_alt_outlined,
                          color: const Color(0xFF246BFD),
                        ),
                        DashboardStatCard(
                          label: 'Buildings',
                          value: metricValue(data.buildings),
                          caption: 'Society inventory',
                          icon: Icons.apartment_outlined,
                          color: RolePalette.admin.primary,
                        ),
                        DashboardStatCard(
                          label: 'Pending visitors',
                          value: metricValue(data.pendingVisitors),
                          caption: 'Awaiting action',
                          icon: Icons.badge_outlined,
                          color: const Color(0xFF7A42D8),
                        ),
                        DashboardStatCard(
                          label: 'Open complaints',
                          value: metricValue(data.openComplaints),
                          caption: 'Open or in progress',
                          icon: Icons.report_problem_outlined,
                          color: const Color(0xFFE34A5F),
                        ),
                        DashboardStatCard(
                          label: 'Due collection',
                          value: moneyValue(data.outstandingAmount),
                          caption: 'Pending and overdue',
                          icon: Icons.account_balance_wallet_outlined,
                          color: const Color(0xFFE66A2C),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  overview,
                ],
              ),
              Column(
                children: [
                  visitors,
                  const SizedBox(height: 16),
                  complaints,
                  const SizedBox(height: 16),
                  actions,
                  const SizedBox(height: 16),
                  const CommunityPromo(resident: false),
                ],
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: RolePalette.admin.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: RolePalette.admin.primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: WebDesign.muted, size: 17),
        ],
      ),
    ),
  );
}
