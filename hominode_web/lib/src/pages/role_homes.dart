import 'package:flutter/material.dart';

import '../services/dashboard_repository.dart';
import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/dashboard_components.dart';
import '../widgets/web_shell.dart';
import 'admin_amenities_page.dart';
import 'admin_billing_page.dart';
import 'admin_buildings_page.dart';
import 'admin_complaints_page.dart';
import 'admin_events_notices_page.dart';
import 'admin_my_community_page.dart';
import 'admin_reports_page.dart';
import 'admin_residents_page.dart';
import 'admin_settings_page.dart';
import 'admin_visitors_page.dart';
import 'super_admin_admins_page.dart';
import 'super_admin_communities_page.dart';
import 'super_admin_platform_overview_page.dart';

String _metric(int? value) => value?.toString() ?? '—';

//
// ============================================================
// SUPER ADMIN HOME
// ============================================================
//

class SuperAdminWebHome extends StatelessWidget {
  const SuperAdminWebHome({
    super.key,
    required this.initialPath,
    required this.onNavigate,
    required this.onLogout,
  });

  final String initialPath;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final index = _superAdminIndexForPath(initialPath);

    return HominodeWebShell(
      title: _superAdminTitle(initialPath),
      subtitle: 'Hominode platform management',
      roleLabel: 'Super Admin',
      palette: RolePalette.superAdmin,
      initialIndex: index,
      profileName: 'Super Admin',
      onLogout: onLogout,
      destinations: [
        WebDestination(
          'Dashboard',
          Icons.dashboard_outlined,
          _SuperDashboard(onNavigate: onNavigate),
          path: '/super-admin',
        ),
        WebDestination(
          'Communities',
          Icons.apartment_outlined,
          const SuperAdminCommunitiesPage(),
          path: '/super-admin/communities',
        ),
        WebDestination(
          'Admins',
          Icons.people_outline,
          const SuperAdminAdminsPage(),
          path: '/super-admin/admins',
        ),
        WebDestination(
          'Platform Overview',
          Icons.analytics_outlined,
          const SuperAdminPlatformOverviewPage(),
          path: '/super-admin/platform-overview',
        ),
      ],
    );
  }
}

int _superAdminIndexForPath(String path) {
  switch (path) {
    case '/super-admin/communities':
      return 1;

    case '/super-admin/admins':
      return 2;

    case '/super-admin/platform-overview':
      return 3;

    case '/super-admin':
    default:
      return 0;
  }
}

String _superAdminTitle(String path) {
  switch (path) {
    case '/super-admin/communities':
      return 'Communities';

    case '/super-admin/admins':
      return 'Community Admins';

    case '/super-admin/platform-overview':
      return 'Platform Overview';

    case '/super-admin':
    default:
      return 'Super Admin Dashboard';
  }
}

//
// ============================================================
// SUPER ADMIN DASHBOARD
// ============================================================
//

class _SuperDashboard extends StatelessWidget {
  const _SuperDashboard({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformMetrics>(
      future: DashboardRepository().platformMetrics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError) {
          return const SectionCard(
            title: 'Platform Dashboard',
            child: EmptyState(
              icon: Icons.error_outline,
              message: 'Unable to load platform information.',
            ),
          );
        }

        final data = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Total Communities',
                  value: _metric(data?.communities),
                  icon: Icons.groups_2_outlined,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Active Communities',
                  value: _metric(data?.activeCommunities),
                  icon: Icons.domain_verification_outlined,
                  color: const Color(0xFF08A579),
                ),
                DashboardStatCard(
                  label: 'Inactive Communities',
                  value: _metric(data?.inactiveCommunities),
                  icon: Icons.domain_disabled_outlined,
                  color: const Color(0xFFE66A2C),
                ),
                DashboardStatCard(
                  label: 'Community Admins',
                  value: _metric(data?.admins),
                  icon: Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF7A42D8),
                ),
                DashboardStatCard(
                  label: 'Active Admins',
                  value: _metric(data?.activeAdmins),
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xFFE34A5F),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final overview = SectionCard(
                  title: 'Platform Overview',
                  action: TextButton(
                    onPressed: () =>
                        onNavigate('/super-admin/platform-overview'),
                    child: const Text('View Overview'),
                  ),
                  child: Column(
                    children: [
                      _SuperDashboardRow(
                        icon: Icons.apartment_outlined,
                        label: 'Communities',
                        value: _metric(data?.communities),
                        onTap: () => onNavigate('/super-admin/communities'),
                      ),
                      const Divider(height: 24),
                      _SuperDashboardRow(
                        icon: Icons.domain_verification_outlined,
                        label: 'Active Communities',
                        value: _metric(data?.activeCommunities),
                        onTap: () => onNavigate('/super-admin/communities'),
                      ),
                      const Divider(height: 24),
                      _SuperDashboardRow(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Community Admins',
                        value: _metric(data?.admins),
                        onTap: () => onNavigate('/super-admin/admins'),
                      ),
                      const Divider(height: 24),
                      _SuperDashboardRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Active Admins',
                        value: _metric(data?.activeAdmins),
                        onTap: () => onNavigate('/super-admin/admins'),
                      ),
                    ],
                  ),
                );

                final actions = SectionCard(
                  title: 'Quick Actions',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      QuickActionCard(
                        label: 'Communities',
                        icon: Icons.apartment_outlined,
                        color: RolePalette.superAdmin.primary,
                        onTap: () => onNavigate('/super-admin/communities'),
                      ),
                      QuickActionCard(
                        label: 'Admins',
                        icon: Icons.person_add_alt_1_outlined,
                        color: const Color(0xFF08A579),
                        onTap: () => onNavigate('/super-admin/admins'),
                      ),
                      QuickActionCard(
                        label: 'Platform Overview',
                        icon: Icons.analytics_outlined,
                        color: const Color(0xFF7A42D8),
                        onTap: () =>
                            onNavigate('/super-admin/platform-overview'),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth >= 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: overview),
                      const SizedBox(width: 16),
                      Expanded(child: actions),
                    ],
                  );
                }

                return Column(
                  children: [overview, const SizedBox(height: 16), actions],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _SuperDashboardRow extends StatelessWidget {
  const _SuperDashboardRow({
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: RolePalette.superAdmin.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: RolePalette.superAdmin.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: WebDesign.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: WebDesign.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

//
// ============================================================
// ADMIN HOME
// ============================================================
//

class AdminWebHome extends StatelessWidget {
  const AdminWebHome({
    super.key,
    required this.session,
    required this.onSelectTenant,
    required this.onNavigate,
    required this.onLogout,
  });

  final WebSession session;
  final Future<void> Function(String) onSelectTenant;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;

  int _adminIndexForPath(String path) {
    switch (path) {
      case '/admin/community':
        return 1;

      case '/admin/buildings':
        return 2;

      case '/admin/residents':
        return 3;

      case '/admin/visitors':
        return 4;

      case '/admin/complaints':
        return 5;

      case '/admin/amenities':
        return 6;

      case '/admin/billing':
        return 7;

      case '/admin/events':
        return 8;

      case '/admin/reports':
        return 9;

      case '/admin/settings':
        return 10;

      case '/admin':
      default:
        return 0;
    }
  }

  String _adminPageTitle(String path) {
    switch (path) {
      case '/admin/community':
        return 'My Community';

      case '/admin/buildings':
        return 'Buildings';

      case '/admin/residents':
        return 'Residents';

      case '/admin/visitors':
        return 'Visitors';

      case '/admin/complaints':
        return 'Complaints';

      case '/admin/amenities':
        return 'Amenities';

      case '/admin/billing':
        return 'Billing';

      case '/admin/events':
        return 'Events & Notices';

      case '/admin/reports':
        return 'Reports';

      case '/admin/settings':
        return 'Settings';

      case '/admin':
      default:
        return 'Admin Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = ModalRoute.of(context)?.settings.name ?? '/admin';

    final initialIndex = _adminIndexForPath(currentPath);

    return HominodeWebShell(
      title: _adminPageTitle(currentPath),
      subtitle: 'Managing ${session.activeTenant!.name}',
      roleLabel: 'Admin',
      palette: RolePalette.admin,
      initialIndex: initialIndex,
      profileName: session.phoneNumber ?? 'Admin User',
      profileSubtitle: session.activeTenant!.name,
      onLogout: onLogout,
      trailing: session.availableTenants.length > 1
          ? _TenantSwitcher(session: session, onSelect: onSelectTenant)
          : null,
      destinations: [
        WebDestination(
          'Dashboard',
          Icons.dashboard_outlined,
          _AdminDashboard(session: session, onNavigate: onNavigate),
          path: '/admin',
        ),
        WebDestination(
          'My Community',
          Icons.apartment_outlined,
          AdminMyCommunityPage(session: session, onNavigate: onNavigate),
          path: '/admin/community',
        ),
        WebDestination(
          'Buildings',
          Icons.business_outlined,
          AdminBuildingsPage(session: session, onNavigate: onNavigate),
          path: '/admin/buildings',
        ),
        WebDestination(
          'Residents',
          Icons.people_outline,
          AdminResidentsPage(session: session, onNavigate: onNavigate),
          path: '/admin/residents',
        ),
        WebDestination(
          'Visitors',
          Icons.badge_outlined,
          AdminVisitorsPage(session: session, onNavigate: onNavigate),
          path: '/admin/visitors',
        ),
        WebDestination(
          'Complaints',
          Icons.report_problem_outlined,
          AdminComplaintsPage(session: session, onNavigate: onNavigate),
          path: '/admin/complaints',
        ),
        WebDestination(
          'Amenities',
          Icons.spa_outlined,
          AdminAmenitiesPage(session: session, onNavigate: onNavigate),
          path: '/admin/amenities',
        ),
        WebDestination(
          'Billing',
          Icons.receipt_long_outlined,
          AdminBillingPage(session: session, onNavigate: onNavigate),
          path: '/admin/billing',
        ),
        WebDestination(
          'Events & Notices',
          Icons.campaign_outlined,
          AdminEventsNoticesPage(session: session, onNavigate: onNavigate),
          path: '/admin/events',
        ),
        WebDestination(
          'Reports',
          Icons.analytics_outlined,
          AdminReportsPage(session: session, onNavigate: onNavigate),
          path: '/admin/reports',
        ),
        WebDestination(
          'Settings',
          Icons.settings_outlined,
          AdminSettingsPage(session: session, onNavigate: onNavigate),
          path: '/admin/settings',
        ),
      ],
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.session, required this.onNavigate});

  final WebSession session;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final communityId = session.activeTenant!.communityId;

    return FutureBuilder<DashboardMetrics>(
      future: DashboardRepository().adminMetrics(communityId),
      builder: (context, snapshot) {
        final metrics = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Total Residents',
                  value: _metric(metrics?['residents']),
                  icon: Icons.people_outline,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Total Buildings',
                  value: _metric(metrics?['buildings']),
                  icon: Icons.apartment_outlined,
                  color: RolePalette.admin.primary,
                ),
                DashboardStatCard(
                  label: 'Visitors',
                  value: _metric(metrics?['visitors']),
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF7A42D8),
                ),
                DashboardStatCard(
                  label: 'Complaints',
                  value: _metric(metrics?['complaints']),
                  icon: Icons.description_outlined,
                  color: const Color(0xFFE34A5F),
                ),
                const DashboardStatCard(
                  label: 'Due Collection',
                  value: '—',
                  caption: 'Unavailable safely',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Color(0xFF08A579),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
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
                  QuickActionCard(
                    label: 'Events & Notices',
                    icon: Icons.campaign_outlined,
                    color: const Color(0xFFE66A2C),
                    onTap: () => onNavigate('/admin/events'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final communityOverview = SectionCard(
                  title: 'Community Overview',
                  action: TextButton(
                    onPressed: () => onNavigate('/admin/community'),
                    child: const Text('View Community'),
                  ),
                  child: Column(
                    children: [
                      _AdminDashboardRow(
                        icon: Icons.people_outline,
                        label: 'Residents',
                        value: _metric(metrics?['residents']),
                        onTap: () => onNavigate('/admin/residents'),
                      ),
                      const Divider(height: 24),
                      _AdminDashboardRow(
                        icon: Icons.apartment_outlined,
                        label: 'Buildings',
                        value: _metric(metrics?['buildings']),
                        onTap: () => onNavigate('/admin/buildings'),
                      ),
                      const Divider(height: 24),
                      _AdminDashboardRow(
                        icon: Icons.badge_outlined,
                        label: 'Visitors',
                        value: _metric(metrics?['visitors']),
                        onTap: () => onNavigate('/admin/visitors'),
                      ),
                      const Divider(height: 24),
                      _AdminDashboardRow(
                        icon: Icons.report_problem_outlined,
                        label: 'Complaints',
                        value: _metric(metrics?['complaints']),
                        onTap: () => onNavigate('/admin/complaints'),
                      ),
                    ],
                  ),
                );

                final management = SectionCard(
                  title: 'Management',
                  child: Column(
                    children: [
                      _AdminDashboardLink(
                        icon: Icons.spa_outlined,
                        title: 'Amenities',
                        description:
                            'Community facilities and booking configuration',
                        onTap: () => onNavigate('/admin/amenities'),
                      ),
                      const Divider(height: 24),
                      _AdminDashboardLink(
                        icon: Icons.receipt_long_outlined,
                        title: 'Billing',
                        description: 'Bills, payments and receipt status',
                        onTap: () => onNavigate('/admin/billing'),
                      ),
                      const Divider(height: 24),
                      _AdminDashboardLink(
                        icon: Icons.campaign_outlined,
                        title: 'Events & Notices',
                        description: 'Community communication and updates',
                        onTap: () => onNavigate('/admin/events'),
                      ),
                      const Divider(height: 24),
                      _AdminDashboardLink(
                        icon: Icons.analytics_outlined,
                        title: 'Reports',
                        description: 'Operational community summaries',
                        onTap: () => onNavigate('/admin/reports'),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth >= 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: communityOverview),
                      const SizedBox(width: 16),
                      Expanded(child: management),
                    ],
                  );
                }

                return Column(
                  children: [
                    communityOverview,
                    const SizedBox(height: 16),
                    management,
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AdminDashboardRow extends StatelessWidget {
  const _AdminDashboardRow({
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: RolePalette.admin.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: RolePalette.admin.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: WebDesign.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: WebDesign.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: WebDesign.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardLink extends StatelessWidget {
  const _AdminDashboardLink({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: RolePalette.admin.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: RolePalette.admin.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: WebDesign.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: WebDesign.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WebDesign.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

//
// ============================================================
// RESIDENT HOME
// ============================================================
//

class ResidentWebHome extends StatelessWidget {
  const ResidentWebHome({
    super.key,
    required this.session,
    required this.onNavigate,
    required this.onLogout,
  });

  final WebSession session;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return HominodeWebShell(
      title:
          'Welcome Home${session.displayName == null ? '' : ', ${session.displayName}'}!',
      subtitle: session.activeTenant!.brandName,
      roleLabel: 'Resident',
      palette: RolePalette.resident,
      profileName: session.displayName ?? 'Resident',
      profileSubtitle: session.flatLabel ?? session.activeTenant!.name,
      onLogout: onLogout,
      destinations: [
        WebDestination(
          'Home',
          Icons.home_outlined,
          _ResidentDashboard(session: session),
          path: '/resident',
        ),
      ],
    );
  }
}

class _ResidentDashboard extends StatelessWidget {
  const _ResidentDashboard({required this.session});

  final WebSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardMetrics>(
      future: DashboardRepository().residentMetrics(
        communityId: session.activeTenant!.communityId,
        uid: session.uid,
        flatId: session.flatId,
      ),
      builder: (context, snapshot) {
        final metrics = snapshot.data;

        return Column(
          children: [
            ResponsiveMetricGrid(
              children: [
                DashboardStatCard(
                  label: 'Complaints',
                  value: _metric(metrics?['complaints']),
                  icon: Icons.build_outlined,
                  color: const Color(0xFFE34A5F),
                ),
                DashboardStatCard(
                  label: 'Visitors',
                  value: _metric(metrics?['visitors']),
                  icon: Icons.people_outline,
                  color: const Color(0xFF246BFD),
                ),
                DashboardStatCard(
                  label: 'Bills',
                  value: _metric(metrics?['bills']),
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFFE66A2C),
                ),
                DashboardStatCard(
                  label: 'Notices',
                  value: _metric(metrics?['notices']),
                  icon: Icons.chat_bubble_outline,
                  color: RolePalette.resident.primary,
                ),
                DashboardStatCard(
                  label: 'Events',
                  value: _metric(metrics?['events']),
                  icon: Icons.event_outlined,
                  color: const Color(0xFF08A579),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final apartment = SectionCard(
                  title: 'My Apartment',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.activeTenant!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [session.buildingId, session.flatLabel]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' · ')
                                .isEmpty
                            ? 'Apartment details unavailable'
                            : [session.buildingId, session.flatLabel]
                                  .whereType<String>()
                                  .where((value) => value.isNotEmpty)
                                  .join(' · '),
                        style: const TextStyle(color: WebDesign.muted),
                      ),
                    ],
                  ),
                );

                final quick = const SectionCard(
                  title: 'Quick Access',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      QuickActionCard(
                        label: 'Visitor',
                        icon: Icons.person_add_alt,
                        color: Color(0xFF246BFD),
                      ),
                      QuickActionCard(
                        label: 'Complaint',
                        icon: Icons.campaign_outlined,
                        color: Color(0xFFE34A5F),
                      ),
                      QuickActionCard(
                        label: 'Amenities',
                        icon: Icons.spa_outlined,
                        color: Color(0xFF08A579),
                      ),
                      QuickActionCard(
                        label: 'Payment',
                        icon: Icons.payment_outlined,
                        color: Color(0xFF6B35D4),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth >= 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: apartment),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: quick),
                    ],
                  );
                }

                return Column(
                  children: [apartment, const SizedBox(height: 16), quick],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

//
// ============================================================
// TENANT SWITCHER
// ============================================================
//

class _TenantSwitcher extends StatelessWidget {
  const _TenantSwitcher({required this.session, required this.onSelect});

  final WebSession session;
  final Future<void> Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: session.activeTenant!.communityId,
        borderRadius: BorderRadius.circular(12),
        items: session.availableTenants
            .map(
              (tenant) => DropdownMenuItem<String>(
                value: tenant.communityId,
                child: Text(tenant.name),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id != null) {
            onSelect(id);
          }
        },
      ),
    );
  }
}

//
// ============================================================
// TENANT SELECTION PAGE
// ============================================================
//

class TenantSelectionPage extends StatelessWidget {
  const TenantSelectionPage({
    super.key,
    required this.session,
    required this.onSelect,
    required this.onLogout,
  });

  final WebSession session;
  final Future<void> Function(String) onSelect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select community'),
        actions: [
          IconButton(onPressed: onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: session.availableTenants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tenant = session.availableTenants[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.apartment)),
                  title: Text(tenant.name),
                  subtitle: Text(tenant.websitePath),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => onSelect(tenant.communityId),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
