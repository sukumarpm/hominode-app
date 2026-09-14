import 'package:admin_app/admin_dashboard_page.dart';
import 'package:admin_app/admin_desktop_shell.dart';
import 'package:admin_app/auth_wrapper.dart';
import 'package:admin_app/navigation/admin_module_destinations.dart';
import 'package:admin_app/widgets/standard_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin tenant destination switches at the desktop breakpoint', () {
    expect(adminTenantDestinationForWidth(1023.99), isA<AdminDashboardPage>());
    expect(adminTenantDestinationForWidth(1024), isA<AdminDesktopShell>());
    expect(adminTenantDestinationForWidth(1920), isA<AdminDesktopShell>());
  });

  test('desktop registry has one unique entry for every admin module', () {
    expect(adminModuleDestinations, hasLength(AdminModuleId.values.length));
    expect(
      adminModuleDestinations.map((destination) => destination.id).toSet(),
      AdminModuleId.values.toSet(),
    );
    expect(
      adminModuleDestinations.map((destination) => destination.label),
      containsAll(<String>[
        'Dashboard',
        'Buildings',
        'Residents',
        'Billing',
        'Visitors',
        'Complaints',
        'Events',
        'Parking',
        'Resident Vehicles',
        'Amenities',
        'Profile',
        'Settings',
      ]),
    );
  });

  testWidgets('desktop sidebar changes the active workspace destination', (
    tester,
  ) async {
    final destinations = <AdminModuleDestination>[
      AdminModuleDestination(
        id: AdminModuleId.dashboard,
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        builder: (_) => const Text('Dashboard workspace'),
      ),
      AdminModuleDestination(
        id: AdminModuleId.buildings,
        label: 'Buildings',
        icon: Icons.apartment_outlined,
        builder: (_) => const Text('Buildings workspace'),
      ),
    ];

    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: AdminDesktopShell(destinations: destinations)),
    );

    expect(find.text('Dashboard workspace'), findsOneWidget);
    expect(find.text('Buildings workspace'), findsNothing);

    await tester.tap(find.text('Buildings').first);
    await tester.pump();

    expect(find.text('Dashboard workspace'), findsNothing);
    expect(find.text('Buildings workspace'), findsOneWidget);
  });

  testWidgets('mobile bottom navigation is absent at desktop widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StandardBottomNav(selectedIndex: 0),
        ),
      ),
    );

    expect(find.text('Home'), findsNothing);
    expect(find.text('Buildings'), findsNothing);
  });

  for (final size in <Size>[
    const Size(1024, 768),
    const Size(1366, 768),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    testWidgets('desktop shell lays out at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDesktopShell(
            destinations: <AdminModuleDestination>[
              AdminModuleDestination(
                id: AdminModuleId.dashboard,
                label: 'Dashboard',
                icon: Icons.dashboard_outlined,
                builder: (_) => const SizedBox.expand(),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('HOMINODE'), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
    });
  }
}
