import 'package:admin_app/about_hominode_screen.dart';
import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/services/dashboard_service.dart';
import 'package:admin_app/widgets/admin_home_quick_actions_grid.dart';
import 'package:admin_app/widgets/admin_home_statistics.dart';
import 'package:admin_app/widgets/admin_property_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {double textScale = 1}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (context, _) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  tearDown(() => AdminTenantContext.instance.clear());

  void configure(int count) {
    final ids = List.generate(count, (i) => 'community-$i');
    AdminTenantContext.instance.configure(
      AdminProfile(
        uid: 'admin-1',
        phoneNumber: '+15550000001',
        role: 'admin',
        isActive: true,
        authorizedCommunityIds: ids,
      ),
      [
        for (final id in ids)
          TenantConfig.fromMap(id, {'name': 'Property $id', 'isActive': true}),
      ],
    );
  }

  Widget property() => const Scaffold(
    body: Center(
      child: AdminPropertyAction(
        child: SizedBox(
          width: 260,
          height: 46,
          child: Text('HOMINODE Property'),
        ),
      ),
    ),
  );

  testWidgets(
    'Single-community property opens About without changing pill geometry',
    (tester) async {
      configure(1);
      await tester.pumpWidget(_app(property()));
      expect(
        tester.getSize(find.byType(AdminPropertyAction)),
        const Size(260, 46),
      );
      expect(find.text('HOMINODE Property'), findsOneWidget);
      await tester.tap(find.text('HOMINODE Property'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutHominodeScreen), findsOneWidget);
      expect(find.text('HOMINODE'), findsOneWidget);
      expect(find.text('Smart place. Better lives.'), findsOneWidget);
      expect(find.text('Developed by Marantrix.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.text('HOMINODE Property'), findsOneWidget);
    },
  );

  testWidgets(
    'Multi-community property retains switching and secondary About action',
    (tester) async {
      configure(2);
      await tester.pumpWidget(_app(property()));
      await tester.tap(find.text('HOMINODE Property'));
      await tester.pumpAndSettle();
      expect(find.text('Switch Community'), findsOneWidget);
      expect(find.text('About Hominode'), findsOneWidget);
      await tester.tap(find.text('Switch Community'));
      await tester.pumpAndSettle();
      expect(find.text('Switch Community'), findsOneWidget);
      expect(find.text('Property community-0'), findsOneWidget);
      expect(find.text('Property community-1'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HOMINODE Property'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About Hominode'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutHominodeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'About links launch the specified website and support destinations',
    (tester) async {
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
          return true;
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(_app(const AboutHominodeScreen()));
      await tester.tap(find.text('https://marantrix.com'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('hominodecare@gmail.com'));
      await tester.pumpAndSettle();
      expect(launched, [
        'https://marantrix.com',
        'mailto:hominodecare@gmail.com',
      ]);
    },
  );

  testWidgets('About handles unavailable link applications', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(_app(const AboutHominodeScreen()));
    await tester.tap(find.text('https://marantrix.com'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to open this link. Please try again.'),
      findsOneWidget,
    );
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'Home keeps five KPIs and four quick actions per row at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final stats = DashboardStats(
            totalResidents: 55,
            totalFlats: 64,
            pendingVisitors: 0,
            pendingComplaints: 11,
            monthlyCollection: 0,
          );
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      AdminHomeStatistics(statsStream: Stream.value(stats)),
                      AdminHomeQuickActionsGrid(
                        children: [
                          for (var i = 0; i < 8; i++)
                            ColoredBox(
                              key: ValueKey('action-$i'),
                              color: Colors.white,
                              child: Text('Action $i'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              textScale: scale,
            ),
          );
          await tester.pump();
          final cards = find.byType(Ink);
          expect(cards, findsNWidgets(5));
          final top = tester.getTopLeft(cards.first).dy;
          for (var i = 0; i < 5; i++) {
            expect(tester.getTopLeft(cards.at(i)).dy, closeTo(top, .01));
            if (i > 0) {
              expect(
                tester.getTopLeft(cards.at(i)).dx,
                greaterThan(tester.getTopLeft(cards.at(i - 1)).dx),
              );
            }
          }
          expect(find.text('55'), findsOneWidget);
          expect(find.text('64'), findsOneWidget);
          final firstTop = tester
              .getTopLeft(find.byKey(const ValueKey('action-0')))
              .dy;
          for (var i = 0; i < 4; i++) {
            expect(
              tester.getTopLeft(find.byKey(ValueKey('action-$i'))).dy,
              closeTo(firstTop, .01),
            );
          }
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('action-4'))).dy,
            greaterThan(firstTop),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
