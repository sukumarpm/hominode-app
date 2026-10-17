import 'package:admin_app/super_admin_home_screen.dart';
import 'package:admin_app/theme/hominode_theme.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's installed platform interface provides its official test mocks.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async => Firebase.initializeApp());

  testWidgets('shows only the minimal Super Admin destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HominodeTheme.light,
        home: const SuperAdminHomeScreen(),
        routes: {
          for (final route in [
            SuperAdminHomeScreen.communitiesRouteName,
            SuperAdminHomeScreen.adminsRouteName,
            SuperAdminHomeScreen.overviewRouteName,
          ])
            route: (_) => Scaffold(body: Text(route)),
        },
      ),
    );

    expect(find.text('Hominode Super Admin'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Admins'), findsOneWidget);
    expect(find.text('Platform Overview'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);
    expect(find.text('Refresh Public Statistics'), findsOneWidget);
    for (final destination in {
      'Communities': SuperAdminHomeScreen.communitiesRouteName,
      'Admins': SuperAdminHomeScreen.adminsRouteName,
      'Platform Overview': SuperAdminHomeScreen.overviewRouteName,
    }.entries) {
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
      Navigator.of(tester.element(find.text(destination.value))).pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
