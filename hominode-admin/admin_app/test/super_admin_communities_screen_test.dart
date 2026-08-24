import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/super_admin_communities_screen.dart';
import 'package:admin_app/theme/hominode_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Super Admin can list community registry data', (tester) async {
    final tenant = TenantConfig.fromMap('GV-1', {
      'name': 'Green Valley',
      'slug': 'green-valley',
      'websitePath': 'green-valley',
      'databaseId': '(default)',
      'isActive': true,
      'createdBy': 'super-1',
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: HominodeTheme.light,
        home: SuperAdminCommunitiesScreen(tenantsLoader: () async => [tenant]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Green Valley'), findsOneWidget);
    expect(find.text('/green-valley'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Database: (default)'), findsOneWidget);
  });
}
