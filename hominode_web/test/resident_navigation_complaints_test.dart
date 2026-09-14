import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_web/src/app.dart';
import 'package:hominode_web/src/pages/role_homes.dart';
import 'package:hominode_web/src/session/web_session.dart';
import 'package:hominode_web/src/theme/web_design_system.dart';
import 'package:hominode_web/src/widgets/web_shell.dart';

void main() {
  Widget shellAtRoute({
    required String initialRoute,
    ValueChanged<String>? onNavigate,
  }) {
    return MaterialApp(
      initialRoute: initialRoute,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => HominodeWebShell(
          title: residentTitleForPath(settings.name ?? '/resident', 'Asha'),
          subtitle: 'Resident test shell',
          roleLabel: 'Resident',
          palette: RolePalette.resident,
          initialIndex: residentIndexForPath(settings.name ?? '/resident'),
          onLogout: () async {},
          onNavigate: onNavigate,
          destinations: const [
            WebDestination(
              'Home',
              Icons.home_outlined,
              Text('Home body', key: Key('home-body')),
              path: '/resident',
            ),
            WebDestination(
              'My Unit',
              Icons.apartment_outlined,
              Text('Unit body', key: Key('unit-body')),
              path: '/resident/unit',
            ),
            WebDestination(
              'Bills',
              Icons.receipt_long_outlined,
              Text('Bills body', key: Key('bills-body')),
              path: '/resident/bills',
            ),
            WebDestination(
              'Visitors',
              Icons.people_outline,
              Text('Visitors body', key: Key('visitors-body')),
              path: '/resident/visitors',
            ),
            WebDestination(
              'Complaints',
              Icons.report_problem_outlined,
              Text('Complaints body', key: Key('complaints-body')),
              path: '/resident/complaints',
            ),
            WebDestination(
              'Notices',
              Icons.campaign_outlined,
              Text('Notices body', key: Key('notices-body')),
              path: '/resident/notices',
            ),
            WebDestination(
              'Events',
              Icons.event_outlined,
              Text('Events body', key: Key('events-body')),
              path: '/resident/events',
            ),
          ],
        ),
      ),
    );
  }

  test('resident sidebar labels are exactly as required', () {
    expect(residentSidebarLabels, const [
      'Home',
      'My Unit',
      'Bills',
      'Visitors',
      'Complaints',
      'Notices',
      'Events',
    ]);
  });

  test('resident route helper maps complaints and index correctly', () {
    expect(residentRoutePaths.contains('/resident/complaints'), isTrue);
    expect(residentIndexForPath('/resident'), 0);
    expect(residentIndexForPath('/resident/unit'), 1);
    expect(residentIndexForPath('/resident/bills'), 2);
    expect(residentIndexForPath('/resident/visitors'), 3);
    expect(residentIndexForPath('/resident/complaints'), 4);
    expect(residentIndexForPath('/resident/notices'), 5);
    expect(residentIndexForPath('/resident/events'), 6);
    expect(residentIndexForPath('/resident/unknown'), 0);
  });

  test('resident title follows route source of truth', () {
    expect(residentTitleForPath('/resident/complaints', 'Asha'), 'Complaints');
    expect(residentTitleForPath('/resident/notices', 'Asha'), 'Notices');
    expect(residentTitleForPath('/resident', 'Asha'), 'Welcome Home, Asha');
  });

  testWidgets(
    'selecting complaints destination navigates to resident complaints path',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final observed = <String>[];

      await tester.pumpWidget(
        shellAtRoute(initialRoute: '/resident', onNavigate: observed.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complaints').first);
      await tester.pumpAndSettle();

      expect(observed, contains('/resident/complaints'));
    },
  );

  testWidgets('resident routed shell keeps route and body aligned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/resident/bills',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => HominodeWebShell(
            title: residentTitleForPath(settings.name ?? '/resident', 'Asha'),
            subtitle: 'Resident test shell',
            roleLabel: 'Resident',
            palette: RolePalette.resident,
            initialIndex: residentIndexForPath(settings.name ?? '/resident'),
            onLogout: () async {},
            onNavigate: (path) =>
                Navigator.of(context).pushReplacementNamed(path),
            destinations: const [
              WebDestination(
                'Home',
                Icons.home_outlined,
                Text('Home body', key: Key('home-body')),
                path: '/resident',
              ),
              WebDestination(
                'My Unit',
                Icons.apartment_outlined,
                Text('Unit body', key: Key('unit-body')),
                path: '/resident/unit',
              ),
              WebDestination(
                'Bills',
                Icons.receipt_long_outlined,
                Text('Bills body', key: Key('bills-body')),
                path: '/resident/bills',
              ),
              WebDestination(
                'Visitors',
                Icons.people_outline,
                Text('Visitors body', key: Key('visitors-body')),
                path: '/resident/visitors',
              ),
              WebDestination(
                'Complaints',
                Icons.report_problem_outlined,
                Text('Complaints body', key: Key('complaints-body')),
                path: '/resident/complaints',
              ),
              WebDestination(
                'Notices',
                Icons.campaign_outlined,
                Text('Notices body', key: Key('notices-body')),
                path: '/resident/notices',
              ),
              WebDestination(
                'Events',
                Icons.event_outlined,
                Text('Events body', key: Key('events-body')),
                path: '/resident/events',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bills-body')), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byKey(const Key('bills-body'))),
      )?.settings.name,
      '/resident/bills',
    );

    await tester.tap(find.text('Complaints').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('complaints-body')), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byKey(const Key('complaints-body'))),
      )?.settings.name,
      '/resident/complaints',
    );
  });

  test('wrong roles are rejected by existing route policy', () {
    const adminSession = WebSession(uid: 'admin', role: WebRole.admin);
    const superSession = WebSession(uid: 'super', role: WebRole.superAdmin);

    expect(
      WebAuthGuardStatePolicy.guardedPath('/resident/complaints', adminSession),
      '/admin',
    );
    expect(
      WebAuthGuardStatePolicy.guardedPath('/resident/complaints', superSession),
      '/super-admin',
    );
  });
}
