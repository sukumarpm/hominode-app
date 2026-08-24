import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/super_admin_admins_screen.dart';
import 'package:admin_app/theme/hominode_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Super Admin can list admin registry data', (tester) async {
    const admin = AdminProfile(
      uid: 'admin-1',
      phoneNumber: '+15550000002',
      role: 'admin',
      isActive: true,
      authorizedCommunityIds: ['A', 'B'],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: HominodeTheme.light,
        home: SuperAdminAdminsScreen(adminsLoader: () async => [admin]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+15550000002'), findsOneWidget);
    expect(find.text('Role: admin'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Communities: A, B'), findsOneWidget);
  });
}
