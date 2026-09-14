import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_web/src/theme/web_design_system.dart';
import 'package:hominode_web/src/widgets/dashboard_components.dart';
import 'package:hominode_web/src/widgets/web_shell.dart';

void main() {
  for (final size in <Size>[
    const Size(1920, 1080),
    const Size(1440, 900),
    const Size(1366, 768),
    const Size(1024, 768),
    const Size(768, 900),
    const Size(390, 844),
    const Size(320, 700),
  ]) {
    testWidgets('dashboard family has no overflow at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final content = Column(
        children: [
          const ResponsiveMetricGrid(
            children: [
              DashboardStatCard(
                label: 'Residents',
                value: '125',
                caption: 'Community scoped',
                icon: Icons.people_outline,
                color: Color(0xFF008C72),
              ),
              DashboardStatCard(
                label: 'Pending visitors',
                value: '12',
                caption: 'Awaiting action',
                icon: Icons.badge_outlined,
                color: Color(0xFF6B35D4),
              ),
              DashboardStatCard(
                label: 'Open complaints',
                value: '5',
                caption: 'Open or in progress',
                icon: Icons.report_problem_outlined,
                color: Color(0xFFE34A5F),
              ),
              DashboardStatCard(
                label: 'Due collection',
                value: '₹24.5K',
                caption: 'Pending and overdue',
                icon: Icons.account_balance_wallet_outlined,
                color: Color(0xFFE66A2C),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const DashboardPanelGrid(
            children: [
              SectionCard(
                title: 'Society overview',
                child: Text('Tenant-safe operational summary'),
              ),
              SectionCard(
                title: 'Quick actions',
                child: QuickActionGrid(
                  children: [
                    QuickActionCard(
                      label: 'Visitors',
                      icon: Icons.badge_outlined,
                      color: Color(0xFF008C72),
                    ),
                    QuickActionCard(
                      label: 'Notices',
                      icon: Icons.campaign_outlined,
                      color: Color(0xFF6B35D4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HominodeWebShell(
            title: 'Admin Dashboard',
            subtitle: 'Responsive production dashboard',
            roleLabel: 'Admin',
            palette: RolePalette.admin,
            profileName: 'Admin User',
            onLogout: () async {},
            destinations: [
              WebDestination('Dashboard', Icons.dashboard_outlined, content),
              for (var index = 0; index < 10; index++)
                WebDestination(
                  'Navigation item $index',
                  Icons.circle_outlined,
                  const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  }
}
