import 'package:admin_app/quick_access_page.dart';
import 'package:admin_app/apartment_images_management_screen.dart';
import 'package:admin_app/widgets/standard_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget _testApp({required Widget home}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  minTextAdapt: true,
  builder: (context, child) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.8)),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  testWidgets(
    'Quick Access tiles wrap long labels on a narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp(home: const QuickAccessPage()));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Community & Invites'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Community & Invites'));
      expect(label.maxLines, isNull);
      expect(label.softWrap, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Community Photos quick access opens COMMUNITY management', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        home: QuickAccessPage(
          communityPhotosBuilder: (_) =>
              const Scaffold(body: Text('Community photos scope: COMMUNITY')),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Community Photos'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Community Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community Photos'));
    await tester.pumpAndSettle();
    expect(find.text('Community photos scope: COMMUNITY'), findsOneWidget);
    expect(
      ApartmentImagesManagementScreen.ownershipScopeFor(null),
      'COMMUNITY',
    );
    expect(
      ApartmentImagesManagementScreen.ownershipScopeFor('building-1'),
      'BUILDING',
    );
  });

  testWidgets('bottom navigation labels wrap at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        home: const Scaffold(
          bottomNavigationBar: StandardBottomNav(selectedIndex: 0),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Buildings'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Buildings')).maxLines, 2);
    expect(tester.takeException(), isNull);
  });
}
