import 'package:flutter/material.dart';
import 'package:hominode_sos/hominode_sos.dart';

import 'admin_residents_page_firestore.dart';
import 'amenities_management_screen.dart';
import 'billing_screen.dart';
import 'complaint_management_screen.dart';
import 'desktop/admin_desktop_design.dart';
import 'events_announcements_screen.dart';
import 'manage_buildings_page.dart';
import 'notifications_screen.dart';
import 'parking_management_screen.dart';
import 'profile_screen.dart';
import 'services/admin_tenant_context.dart';
import 'services/dashboard_service.dart';
import 'visitor_management_screen.dart';

class AdminDashboardDesktopContent extends StatefulWidget {
  const AdminDashboardDesktopContent({
    super.key,
    this.statsStream,
    this.communityName,
  });

  /// Test seams keep widget tests off Firebase without changing services.
  final Stream<DashboardStats>? statsStream;
  final String? communityName;

  @override
  State<AdminDashboardDesktopContent> createState() =>
      _AdminDashboardDesktopContentState();
}

class _AdminDashboardDesktopContentState
    extends State<AdminDashboardDesktopContent> {
  late Stream<DashboardStats> _statsStream;

  @override
  void initState() {
    super.initState();
    _statsStream =
        widget.statsStream ??
        DashboardService().getDashboardStats(
          AdminTenantContext.instance.requireCommunityId(),
        );
  }

  @override
  void didUpdateWidget(covariant AdminDashboardDesktopContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statsStream != null &&
        widget.statsStream != oldWidget.statsStream) {
      _statsStream = widget.statsStream!;
    }
  }

  String get _communityName {
    final override = widget.communityName?.trim();
    if (override != null && override.isNotEmpty) return override;
    final tenantName = AdminTenantContext.instance.name?.trim();
    return tenantName == null || tenantName.isEmpty
        ? 'Hominode Community'
        : tenantName;
  }

  void _open(Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => page));
  }

  void _openModule(String moduleName, Widget fallbackPage) {
    final shell = AdminDesktopShellScope.maybeOf(context);
    if (shell != null) {
      shell.onSelectModule(moduleName);
      return;
    }
    _open(fallbackPage);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AdminDesktopDesign.background,
    child: StreamBuilder<DashboardStats>(
      stream: _statsStream,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            stats == null;

        return CustomScrollView(
          key: const Key('admin-desktop-dashboard'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              sliver: SliverList.list(
                children: [
                  const Text(
                    'Welcome back, Admin!',
                    style: TextStyle(
                      color: AdminDesktopDesign.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Here’s what’s happening in your community today.',
                    style: TextStyle(
                      color: AdminDesktopDesign.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!AdminDesktopShellScope.isActive(context)) ...[
                    _DashboardHeader(
                      communityName: _communityName,
                      onNotifications: () => _open(const NotificationsScreen()),
                      onProfile: () => _open(const ProfileScreen()),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (AdminTenantContext.instance.communityId != null)
                    SosActiveBanner(
                      communityId: AdminTenantContext.instance
                          .requireCommunityId(),
                    ),
                  if (snapshot.hasError)
                    const _DataErrorBanner()
                  else
                    _KpiRow(
                      stats: stats,
                      loading: loading,
                      onResidents: () => _openModule(
                        'residents',
                        const AdminResidentsPageFirestore(),
                      ),
                      onFlats: () =>
                          _openModule('buildings', const ManageBuildingsPage()),
                      onVisitors: () => _openModule(
                        'visitors',
                        const VisitorManagementScreen(),
                      ),
                      onComplaints: () => _openModule(
                        'complaints',
                        const ComplaintManagementScreen(),
                      ),
                      onBilling: () =>
                          _openModule('billing', const BillingScreen()),
                    ),
                  const SizedBox(height: 14),
                  _DashboardMainGrid(
                    stats: stats,
                    loading: loading,
                    onResidents: () => _openModule(
                      'residents',
                      const AdminResidentsPageFirestore(),
                    ),
                    onBuildings: () =>
                        _openModule('buildings', const ManageBuildingsPage()),
                    onVisitors: () => _openModule(
                      'visitors',
                      const VisitorManagementScreen(),
                    ),
                    onComplaints: () => _openModule(
                      'complaints',
                      const ComplaintManagementScreen(),
                    ),
                    onBilling: () =>
                        _openModule('billing', const BillingScreen()),
                    onEvents: () => _openModule(
                      'events',
                      const EventsAnnouncementsScreen(),
                    ),
                    onParking: () => _openModule(
                      'parking',
                      const ParkingManagementScreenEnhanced(),
                    ),
                    onAmenities: () => _openModule(
                      'amenities',
                      const AmenitiesManagementScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.communityName,
    required this.onNotifications,
    required this.onProfile,
  });

  final String communityName;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: AdminDesktopDesign.text,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Monitor your community and manage daily operations.',
              style: TextStyle(color: AdminDesktopDesign.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AdminDesktopDesign.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.apartment_outlined,
              size: 17,
              color: Color(0xFF247B8A),
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                communityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminDesktopDesign.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      _HeaderButton(
        tooltip: 'Notifications',
        icon: Icons.notifications_none_outlined,
        onPressed: onNotifications,
      ),
      const SizedBox(width: 8),
      _HeaderButton(
        tooltip: 'Profile',
        icon: Icons.account_circle_outlined,
        onPressed: onProfile,
      ),
    ],
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton.outlined(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(42, 42),
        foregroundColor: AdminDesktopDesign.muted,
        side: const BorderSide(color: AdminDesktopDesign.border),
        backgroundColor: Colors.white,
      ),
    ),
  );
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.stats,
    required this.loading,
    required this.onResidents,
    required this.onFlats,
    required this.onVisitors,
    required this.onComplaints,
    required this.onBilling,
  });

  final DashboardStats? stats;
  final bool loading;
  final VoidCallback onResidents;
  final VoidCallback onFlats;
  final VoidCallback onVisitors;
  final VoidCallback onComplaints;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 12.0;
      final cardWidth = ((constraints.maxWidth - spacing * 4) / 5).clamp(
        136.0,
        220.0,
      );
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          _KpiCard(
            width: cardWidth,
            label: 'Total Residents',
            value: loading ? '—' : '${stats?.totalResidents ?? 0}',
            icon: Icons.people_alt_outlined,
            color: const Color(0xFF2F61D7),
            onTap: onResidents,
          ),
          _KpiCard(
            width: cardWidth,
            label: 'Total Flats',
            value: loading ? '—' : '${stats?.totalFlats ?? 0}',
            icon: Icons.apartment_outlined,
            color: const Color(0xFF13866A),
            onTap: onFlats,
          ),
          _KpiCard(
            width: cardWidth,
            label: 'Pending Visitors',
            value: loading ? '—' : '${stats?.pendingVisitors ?? 0}',
            icon: Icons.badge_outlined,
            color: const Color(0xFF7652B8),
            onTap: onVisitors,
          ),
          _KpiCard(
            width: cardWidth,
            label: 'Open Complaints',
            value: loading ? '—' : '${stats?.pendingComplaints ?? 0}',
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFD24B4B),
            onTap: onComplaints,
          ),
          _KpiCard(
            width: cardWidth,
            label: 'This Month Collection',
            value: loading ? '—' : (stats?.formattedCollection ?? '₹0'),
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF17845F),
            onTap: onBilling,
          ),
        ],
      );
    },
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 104,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AdminDesktopDesign.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 19, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: AdminDesktopDesign.text,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminDesktopDesign.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashboardMainGrid extends StatelessWidget {
  const _DashboardMainGrid({
    required this.stats,
    required this.loading,
    required this.onResidents,
    required this.onBuildings,
    required this.onVisitors,
    required this.onComplaints,
    required this.onBilling,
    required this.onEvents,
    required this.onParking,
    required this.onAmenities,
  });

  final DashboardStats? stats;
  final bool loading;
  final VoidCallback onResidents;
  final VoidCallback onBuildings;
  final VoidCallback onVisitors;
  final VoidCallback onComplaints;
  final VoidCallback onBilling;
  final VoidCallback onEvents;
  final VoidCallback onParking;
  final VoidCallback onAmenities;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final summaries = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SummaryPanel(
              title: 'Visitors',
              value: loading ? '—' : '${stats?.pendingVisitors ?? 0}',
              detail: 'Awaiting approval',
              icon: Icons.badge_outlined,
              color: const Color(0xFF7652B8),
              onTap: onVisitors,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryPanel(
              title: 'Complaints',
              value: loading ? '—' : '${stats?.pendingComplaints ?? 0}',
              detail: 'Pending or in progress',
              icon: Icons.report_problem_outlined,
              color: const Color(0xFFD24B4B),
              onTap: onComplaints,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryPanel(
              title: 'Collections',
              value: loading ? '—' : (stats?.formattedCollection ?? '₹0'),
              detail: 'Received this month',
              icon: Icons.payments_outlined,
              color: const Color(0xFF17845F),
              onTap: onBilling,
            ),
          ),
        ],
      );

      final responsiveSummaries = constraints.maxWidth < 760
          ? Column(
              children: [
                _SummaryPanel(
                  title: 'Visitors',
                  value: loading ? '—' : '${stats?.pendingVisitors ?? 0}',
                  detail: 'Awaiting approval',
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF7652B8),
                  onTap: onVisitors,
                ),
                const SizedBox(height: 12),
                _SummaryPanel(
                  title: 'Complaints',
                  value: loading ? '—' : '${stats?.pendingComplaints ?? 0}',
                  detail: 'Pending or in progress',
                  icon: Icons.report_problem_outlined,
                  color: const Color(0xFFD24B4B),
                  onTap: onComplaints,
                ),
                const SizedBox(height: 12),
                _SummaryPanel(
                  title: 'Collections',
                  value: loading ? '—' : (stats?.formattedCollection ?? '₹0'),
                  detail: 'Received this month',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF17845F),
                  onTap: onBilling,
                ),
              ],
            )
          : summaries;

      final overview = _OverviewPanel(
        stats: stats,
        loading: loading,
        onResidents: onResidents,
        onBuildings: onBuildings,
      );
      final actions = _QuickActionsPanel(
        onBuildings: onBuildings,
        onBilling: onBilling,
        onVisitors: onVisitors,
        onResidents: onResidents,
        onEvents: onEvents,
        onParking: onParking,
        onAmenities: onAmenities,
      );

      if (constraints.maxWidth < 1040) {
        return Column(
          children: [
            _MonthlyCollection(
              stats: stats,
              loading: loading,
              onTap: onBilling,
            ),
            const SizedBox(height: 16),
            overview,
            const SizedBox(height: 16),
            responsiveSummaries,
            const SizedBox(height: 16),
            actions,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _MonthlyCollection(
                  stats: stats,
                  loading: loading,
                  onTap: onBilling,
                ),
                const SizedBox(height: 16),
                overview,
                const SizedBox(height: 16),
                summaries,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: actions),
        ],
      );
    },
  );
}

class _MonthlyCollection extends StatelessWidget {
  const _MonthlyCollection({
    required this.stats,
    required this.loading,
    required this.onTap,
  });
  final DashboardStats? stats;
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: AdminDesktopDesign.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total maintenance collection',
          style: TextStyle(
            color: AdminDesktopDesign.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          loading || stats == null ? '—' : stats!.formattedCollection,
          style: const TextStyle(
            color: AdminDesktopDesign.text,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Received this month',
          style: TextStyle(color: AdminDesktopDesign.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AdminDesktopDesign.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AdminDesktopDesign.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Community collections',
                    style: TextStyle(
                      color: AdminDesktopDesign.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: const Text('View billing details'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.stats,
    required this.loading,
    required this.onResidents,
    required this.onBuildings,
  });

  final DashboardStats? stats;
  final bool loading;
  final VoidCallback onResidents;
  final VoidCallback onBuildings;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Community Overview',
    subtitle: 'Current community occupancy and resident totals',
    child: Row(
      children: [
        Expanded(
          child: _OverviewMetric(
            label: 'Residents',
            value: loading ? '—' : '${stats?.totalResidents ?? 0}',
            icon: Icons.groups_outlined,
            onTap: onResidents,
          ),
        ),
        Container(width: 1, height: 54, color: const Color(0xFFE1E8EF)),
        Expanded(
          child: _OverviewMetric(
            label: 'Flats',
            value: loading ? '—' : '${stats?.totalFlats ?? 0}',
            icon: Icons.domain_outlined,
            onTap: onBuildings,
          ),
        ),
      ],
    ),
  );
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: const Color(0xFF247B8A)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF66788A), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Panel(
    title: title,
    compact: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: color),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF102A43),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF66788A), fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: const Text('Open module'),
        ),
      ],
    ),
  );
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({
    required this.onBuildings,
    required this.onBilling,
    required this.onVisitors,
    required this.onResidents,
    required this.onEvents,
    required this.onParking,
    required this.onAmenities,
  });

  final VoidCallback onBuildings;
  final VoidCallback onBilling;
  final VoidCallback onVisitors;
  final VoidCallback onResidents;
  final VoidCallback onEvents;
  final VoidCallback onParking;
  final VoidCallback onAmenities;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Quick Actions',
    subtitle: 'Common administration tasks',
    child: LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: constraints.maxWidth < 430 ? 3 : 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _QuickAction(
            label: 'Add Building',
            icon: Icons.add_business_outlined,
            onTap: onBuildings,
          ),
          _QuickAction(
            label: 'Add Bill',
            icon: Icons.post_add_outlined,
            onTap: onBilling,
          ),
          _QuickAction(
            label: 'Approve Visitor',
            icon: Icons.how_to_reg_outlined,
            onTap: onVisitors,
          ),
          _QuickAction(
            label: 'Residents',
            icon: Icons.people_outline,
            onTap: onResidents,
          ),
          _QuickAction(
            label: 'Events',
            icon: Icons.event_outlined,
            onTap: onEvents,
          ),
          _QuickAction(
            label: 'Parking',
            icon: Icons.local_parking_outlined,
            onTap: onParking,
          ),
          _QuickAction(
            label: 'Amenities',
            icon: Icons.pool_outlined,
            onTap: onAmenities,
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      AdminDesktopActionTile(label: label, icon: icon, onTap: onTap);
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => AdminDesktopSectionCard(
    title: title,
    subtitle: subtitle,
    compact: compact,
    child: child,
  );
}

class _DataErrorBanner extends StatelessWidget {
  const _DataErrorBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF3C77C)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Color(0xFF9C6500), size: 20),
        SizedBox(width: 10),
        Text(
          'Dashboard data is temporarily unavailable.',
          style: TextStyle(color: Color(0xFF704B00), fontSize: 13),
        ),
      ],
    ),
  );
}
