import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_web/src/theme/web_design_system.dart';
import 'package:hominode_web/src/widgets/dashboard_components.dart';
import 'package:hominode_web/src/widgets/web_shell.dart';

void main() {
  for (final size in <Size>[
    const Size(1440, 900),
    const Size(1024, 768),
    const Size(768, 900),
    const Size(390, 844),
  ]) {
    testWidgets('dashboard shell lays out at ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: HominodeWebShell(
            title: 'Admin Dashboard',
            subtitle: 'Tenant-safe overview',
            roleLabel: 'Admin',
            palette: RolePalette.admin,
            profileName: 'Admin User',
            onLogout: () async {},
            destinations: [
              const WebDestination(
                'Dashboard',
                Icons.dashboard_outlined,
                ResponsiveMetricGrid(
                  children: [
                    DashboardStatCard(
                      label: 'Residents',
                      value: '—',
                      icon: Icons.people_outline,
                      color: Color(0xFF008C72),
                    ),
                  ],
                ),
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
