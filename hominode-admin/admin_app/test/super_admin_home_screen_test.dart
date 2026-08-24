import 'package:admin_app/super_admin_home_screen.dart';
import 'package:admin_app/theme/hominode_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows only the minimal Super Admin destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HominodeTheme.light,
        home: const SuperAdminHomeScreen(),
      ),
    );

    expect(find.text('Hominode Super Admin'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Admins'), findsOneWidget);
    expect(find.text('Platform Overview'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);
  });
}
