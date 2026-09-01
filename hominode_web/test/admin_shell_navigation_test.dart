import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_web/src/theme/web_design_system.dart';
import 'package:hominode_web/src/widgets/web_shell.dart';

void main() {
  testWidgets('routed shell destination keeps route and body aligned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/admin/billing',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => Builder(
            builder: (context) => HominodeWebShell(
              title: 'Admin',
              subtitle: '',
              roleLabel: 'Admin',
              palette: RolePalette.admin,
              initialIndex: settings.name == '/admin/billing' ? 1 : 0,
              onLogout: () async {},
              onNavigate: (path) =>
                  Navigator.of(context).pushReplacementNamed(path),
              destinations: const [
                WebDestination(
                  'Dashboard',
                  Icons.dashboard_outlined,
                  Text('DASHBOARD_BODY', key: Key('dashboard-body')),
                  path: '/admin',
                ),
                WebDestination(
                  'Billing',
                  Icons.receipt_long_outlined,
                  Text('BILLING_BODY', key: Key('billing-body')),
                  path: '/admin/billing',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('billing-body')), findsOneWidget);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-body')), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byKey(const Key('dashboard-body'))),
      )?.settings.name,
      '/admin',
    );
  });
}
