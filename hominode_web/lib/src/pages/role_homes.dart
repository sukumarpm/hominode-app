import 'package:flutter/material.dart';

import '../session/web_session.dart';
import '../theme/web_design_system.dart';
import '../widgets/web_shell.dart';
import 'admin_amenities_page.dart';
import 'admin_billing_page.dart';
import 'admin_buildings_page.dart';
import 'admin_complaints_page.dart';
import 'admin_dashboard.dart';
import 'admin_events_notices_page.dart';
import 'admin_my_community_page.dart';
import 'admin_reports_page.dart';
import 'admin_residents_page.dart';
import 'admin_settings_page.dart';
import 'admin_visitors_page.dart';
import 'resident_bills_page.dart';
import 'resident_complaints_page.dart';
import 'resident_dashboard.dart';
import 'resident_events_page.dart';
import 'resident_notices_page.dart';
import 'resident_unit_page.dart';
import 'resident_visitors_page.dart';
import 'super_admin_admins_page.dart';
import 'super_admin_communities_page.dart';
import 'super_admin_dashboard.dart';
import 'super_admin_platform_overview_page.dart';

const residentSidebarLabels = <String>[
  'Home',
  'My Unit',
  'Bills',
  'Visitors',
  'Complaints',
  'Notices',
  'Events',
];

const residentRoutePaths = <String>{
  '/resident',
  '/resident/unit',
  '/resident/bills',
  '/resident/visitors',
  '/resident/complaints',
  '/resident/notices',
  '/resident/events',
};

int residentIndexForPath(String path) => switch (path) {
  '/resident/unit' => 1,
  '/resident/bills' => 2,
  '/resident/visitors' => 3,
  '/resident/complaints' => 4,
  '/resident/notices' => 5,
  '/resident/events' => 6,
  _ => 0,
};

String residentTitleForPath(String path, String? residentName) =>
    switch (path) {
      '/resident/unit' => 'My Unit',
      '/resident/bills' => 'Bills',
      '/resident/visitors' => 'Visitors',
      '/resident/complaints' => 'Complaints',
      '/resident/notices' => 'Notices',
      '/resident/events' => 'Events',
      _ =>
        residentName == null || residentName.isEmpty
            ? 'Welcome Home'
            : 'Welcome Home, $residentName',
    };

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
  Widget build(BuildContext context) => HominodeWebShell(
    title: _superAdminTitle(initialPath),
    subtitle: 'Overview of the Hominode platform registry',
    roleLabel: 'Super Admin',
    palette: RolePalette.superAdmin,
    initialIndex: _superAdminIndexForPath(initialPath),
    profileName: 'Super Admin',
    onLogout: onLogout,
    destinations: [
      WebDestination(
        'Dashboard',
        Icons.dashboard_outlined,
        SuperAdminDashboard(onNavigate: onNavigate),
        path: '/super-admin',
      ),
      const WebDestination(
        'Communities',
        Icons.holiday_village_outlined,
        SuperAdminCommunitiesPage(),
        path: '/super-admin/communities',
      ),
      const WebDestination(
        'Admins',
        Icons.admin_panel_settings_outlined,
        SuperAdminAdminsPage(),
        path: '/super-admin/admins',
      ),
      const WebDestination(
        'Platform Overview',
        Icons.donut_large_outlined,
        SuperAdminPlatformOverviewPage(),
        path: '/super-admin/platform-overview',
      ),
    ],
  );
}

int _superAdminIndexForPath(String path) => switch (path) {
  '/super-admin/communities' => 1,
  '/super-admin/admins' => 2,
  '/super-admin/platform-overview' => 3,
  _ => 0,
};

String _superAdminTitle(String path) => switch (path) {
  '/super-admin/communities' => 'Communities',
  '/super-admin/admins' => 'Community Admins',
  '/super-admin/platform-overview' => 'Platform Overview',
  _ => 'Super Admin Dashboard',
};

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

  int _indexForPath(String path) => switch (path) {
    '/admin/community' => 1,
    '/admin/buildings' => 2,
    '/admin/residents' => 3,
    '/admin/visitors' => 4,
    '/admin/complaints' => 5,
    '/admin/amenities' => 6,
    '/admin/billing' => 7,
    '/admin/events' => 8,
    '/admin/reports' => 9,
    '/admin/settings' => 10,
    _ => 0,
  };

  String _pageTitle(String path) => switch (path) {
    '/admin/community' => 'My Community',
    '/admin/buildings' => 'Buildings',
    '/admin/residents' => 'Residents',
    '/admin/visitors' => 'Visitors',
    '/admin/complaints' => 'Complaints',
    '/admin/amenities' => 'Amenities',
    '/admin/billing' => 'Billing',
    '/admin/events' => 'Events & Notices',
    '/admin/reports' => 'Reports',
    '/admin/settings' => 'Settings',
    _ => 'Admin Dashboard',
  };

  @override
  Widget build(BuildContext context) {
    final currentPath = ModalRoute.of(context)?.settings.name ?? '/admin';
    return HominodeWebShell(
      title: _pageTitle(currentPath),
      subtitle: 'Society overview for ${session.activeTenant!.name}',
      roleLabel: 'Admin',
      palette: RolePalette.admin,
      initialIndex: _indexForPath(currentPath),
      profileName: session.displayName ?? session.phoneNumber ?? 'Admin User',
      profileSubtitle: session.activeTenant!.name,
      onLogout: onLogout,
      onNavigate: onNavigate,
      trailing: session.availableTenants.length > 1
          ? _TenantSwitcher(session: session, onSelect: onSelectTenant)
          : null,
      destinations: [
        WebDestination(
          'Dashboard',
          Icons.dashboard_outlined,
          AdminDashboard(session: session, onNavigate: onNavigate),
          path: '/admin',
        ),
        WebDestination(
          'My Community',
          Icons.holiday_village_outlined,
          AdminMyCommunityPage(session: session, onNavigate: onNavigate),
          path: '/admin/community',
        ),
        WebDestination(
          'Buildings',
          Icons.apartment_outlined,
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

class ResidentWebHome extends StatelessWidget {
  const ResidentWebHome({
    super.key,
    required this.session,
    required this.currentPath,
    required this.onNavigate,
    required this.onLogout,
  });

  final WebSession session;
  final String currentPath;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final name = session.displayName?.trim();
    return HominodeWebShell(
      title: residentTitleForPath(currentPath, name),
      subtitle: 'Your home and community at a glance',
      roleLabel: 'Resident',
      palette: RolePalette.resident,
      initialIndex: residentIndexForPath(currentPath),
      profileName: name == null || name.isEmpty ? 'Resident' : name,
      profileSubtitle: session.flatLabel ?? session.activeTenant!.name,
      onLogout: onLogout,
      onNavigate: onNavigate,
      destinations: [
        WebDestination(
          residentSidebarLabels[0],
          Icons.home_outlined,
          ResidentDashboard(session: session),
          path: '/resident',
        ),
        WebDestination(
          residentSidebarLabels[1],
          Icons.apartment_outlined,
          ResidentUnitPage(session: session),
          path: '/resident/unit',
        ),
        WebDestination(
          residentSidebarLabels[2],
          Icons.receipt_long_outlined,
          ResidentBillsPage(session: session),
          path: '/resident/bills',
        ),
        WebDestination(
          residentSidebarLabels[3],
          Icons.people_outline,
          ResidentVisitorsPage(session: session),
          path: '/resident/visitors',
        ),
        WebDestination(
          residentSidebarLabels[4],
          Icons.report_problem_outlined,
          ResidentComplaintsPage(session: session),
          path: '/resident/complaints',
        ),
        WebDestination(
          residentSidebarLabels[5],
          Icons.campaign_outlined,
          ResidentNoticesPage(session: session),
          path: '/resident/notices',
        ),
        WebDestination(
          residentSidebarLabels[6],
          Icons.event_outlined,
          ResidentEventsPage(session: session),
          path: '/resident/events',
        ),
      ],
    );
  }
}

class _TenantSwitcher extends StatelessWidget {
  const _TenantSwitcher({required this.session, required this.onSelect});

  final WebSession session;
  final Future<void> Function(String) onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: RolePalette.admin.soft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: session.activeTenant!.communityId,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        style: const TextStyle(
          color: WebDesign.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        items: session.availableTenants
            .map(
              (tenant) => DropdownMenuItem<String>(
                value: tenant.communityId,
                child: Text(
                  tenant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id != null) onSelect(id);
        },
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Scaffold(
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
          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
