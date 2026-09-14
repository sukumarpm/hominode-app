import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_core/hominode_core.dart';
import 'package:hominode_web/src/pages/admin_dashboard.dart';
import 'package:hominode_web/src/pages/resident_dashboard.dart';
import 'package:hominode_web/src/session/web_session.dart';
import 'package:hominode_web/src/services/dashboard_repository.dart';
import 'package:hominode_web/src/theme/web_design_system.dart';
import 'package:hominode_web/src/widgets/web_shell.dart';

import '../../packages/hominode_sos/test/sos_test_client.dart';

const designTenant = TenantConfig(
  communityId: 'community',
  name: 'Oakridge Residency',
  slug: 'oakridge',
  websitePath: 'oakridge',
  databaseId: '(default)',
  isActive: true,
  brandName: 'Oakridge Residency',
);
const designRecords = [
  DashboardRecord(
    title: 'Community gathering',
    subtitle: 'Meet your neighbours in the community garden',
    status: 'Published',
  ),
  DashboardRecord(
    title: 'Swimming pool maintenance',
    subtitle: 'Please check the latest community schedule',
    status: 'Published',
  ),
];

Widget designDashboard(bool resident, TestSosClient client) {
  final session = WebSession(
    uid: 'resident',
    role: resident ? WebRole.resident : WebRole.admin,
    activeTenant: designTenant,
    displayName: 'Asha',
    buildingId: 'Tower A',
    flatLabel: '1203',
  );
  return HominodeWebShell(
    title: resident ? 'Welcome Home, Asha' : 'Admin Dashboard',
    subtitle: 'A safer, cleaner and happier community.',
    roleLabel: resident ? 'Resident' : 'Admin',
    palette: resident ? RolePalette.resident : RolePalette.admin,
    profileName: resident ? 'Asha' : 'Admin',
    profileSubtitle: designTenant.name,
    onLogout: () async {},
    destinations: [
      WebDestination(
        'Dashboard',
        Icons.home_outlined,
        resident
            ? ResidentDashboard(
                session: session,
                dataFuture: Future.value(
                  const ResidentDashboardData(
                    openComplaints: 3,
                    visitorsToday: 12,
                    pendingBills: 2,
                    pendingAmount: 3500,
                    activeNotices: 2,
                    bills: [
                      DashboardRecord(
                        title: 'September maintenance',
                        subtitle: 'Community maintenance',
                        status: 'Pending',
                      ),
                    ],
                    notices: designRecords,
                    events: designRecords,
                    recentNotices: designRecords,
                    upcomingEvents: designRecords,
                  ),
                ),
              )
            : AdminDashboard(
                session: session,
                onNavigate: (_) {},
                sosClient: client,
                dataFuture: Future.value(
                  const AdminDashboardData(
                    residents: 248,
                    buildings: 12,
                    pendingVisitors: 8,
                    openComplaints: 3,
                    visitorsToday: [
                      DashboardRecord(
                        title: 'Visitor arrival',
                        subtitle: 'Tower A · 1203',
                        status: 'Pending',
                      ),
                    ],
                    recentComplaints: [
                      DashboardRecord(
                        title: 'Water supply',
                        subtitle: 'Tower B · 804',
                        status: 'Open',
                      ),
                    ],
                    paidAmount: 98200,
                    pendingAmount: 120450,
                    overdueAmount: 29350,
                  ),
                ),
              ),
      ),
      for (final entry
          in (resident
              ? const [
                  'My Unit',
                  'Bills',
                  'Visitors',
                  'Complaints',
                  'Notices',
                  'Events',
                ]
              : const [
                  'My Community',
                  'Buildings',
                  'Residents',
                  'Visitors',
                  'Complaints',
                  'Amenities',
                  'Billing',
                  'Events & Notices',
                  'Reports',
                  'Settings',
                ]))
        WebDestination(entry, Icons.grid_view_outlined, Text('$entry content')),
    ],
  );
}

void main() {
  for (final resident in [false, true]) {
    for (final width in [360.0, 390.0, 430.0, 768.0, 1280.0, 1536.0, 1920.0]) {
      testWidgets(
        '${resident ? 'Resident' : 'Admin'} dashboard fits $width with real view widgets',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = TestSosClient();
          addTearDown(client.dispose);
          await tester.pumpWidget(
            MaterialApp(home: designDashboard(resident, client)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              resident ? 'My apartment' : 'Total maintenance collection',
            ),
            findsOneWidget,
          );
          expect(
            find.text('Community dashboard data is currently unavailable.'),
            findsNothing,
          );
          final scrollable = find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('Quick actions'),
            250,
            scrollable: scrollable,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Resident drawer preserves selection and warm theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = TestSosClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: designDashboard(true, client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Visitors'));
    await tester.pumpAndSettle();
    expect(find.text('Visitors content'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(
      Theme.of(
        tester.element(find.text('Visitors content')),
      ).colorScheme.primary,
      RolePalette.resident.primary,
    );
  });

  testWidgets('toolbar page search retains destination actions', (
    tester,
  ) async {
    final client = TestSosClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: designDashboard(false, client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Billing');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Billing').last);
    await tester.pumpAndSettle();
    expect(find.text('Billing content'), findsOneWidget);
  });
}
