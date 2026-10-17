import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/resident_visitor_page_header.dart';
import 'package:resident_app/src/widgets/resident_home_summary_navigation.dart';

import 'localization_test_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets('Home entry returns to the previous page', (tester) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openResidentHomeVisitors(
                  context,
                  destinationBuilder: (_) => ResidentVisitorBackHandler(
                    child: const Scaffold(body: ResidentVisitorBackButton()),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('direct root entry Back button replaces route with Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const Scaffold(body: ResidentVisitorBackButton()),
          onGenerateRoute: (settings) => settings.name == '/home'
              ? MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Home destination')),
                )
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(find.byType(ResidentVisitorBackButton), findsNothing);
  });

  testWidgets('system Back from a Home-opened visitor route pops to Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openResidentHomeVisitors(
                  context,
                  destinationBuilder: (_) => ResidentVisitorBackHandler(
                    child: const Scaffold(body: ResidentVisitorBackButton()),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('system Back returns Home when Visitor Management is root', (
    tester,
  ) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: ResidentVisitorBackHandler(
            child: const Scaffold(body: ResidentVisitorBackButton()),
          ),
          onGenerateRoute: (settings) => settings.name == '/home'
              ? MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Home destination')),
                )
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });

  for (final layout in [
    (width: 320.0, scale: 1.0, rtl: false),
    (width: 390.0, scale: 1.0, rtl: false),
    (width: 320.0, scale: 1.7, rtl: false),
    (width: 390.0, scale: 1.7, rtl: true),
  ]) {
    testWidgets('visitor header fits ${layout.width}px at ${layout.scale}x '
        'rtl=${layout.rtl}', (tester) async {
      tester.view.physicalSize = Size(layout.width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        withEnglishLocalization(
          (localizationContext) => ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (context, child) => localizedMaterialApp(
              localizationContext,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(layout.width, 700),
                  textScaler: TextScaler.linear(layout.scale),
                ),
                child: Directionality(
                  textDirection: layout.rtl
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  child: const Scaffold(
                    body: ResidentVisitorPageHeader(
                      title: 'إدارة الزوار المتوقعة في المجتمع السكني',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(
        find.text('إدارة الزوار المتوقعة في المجتمع السكني'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
