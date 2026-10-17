import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_floating_bottom_navigation.dart';

import 'localization_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  Future<void> pumpNavigation(
    WidgetTester tester, {
    required double width,
    required double textScale,
    Locale locale = const Locale('en'),
    ui.TextDirection direction = ui.TextDirection.ltr,
  }) async {
    resetTestLocalizationPreferences();
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      KeyedSubtree(
        // Recreate the EasyLocalization state when successive cases request
        // different start locales; otherwise its controller can retain the
        // previous case's locale despite a fresh SharedPreferences fixture.
        key: ValueKey('navigation-locale-${locale.languageCode}'),
        child: withResidentLocalization(
          (localizationContext) => ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, _) => localizedMaterialApp(
              localizationContext,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 760),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () =>
                              context.setLocale(const Locale('ta')),
                          child: const Text('Switch language'),
                        ),
                      ),
                      bottomNavigationBar: ResidentFloatingBottomNavigation(
                        selectedIndex: 0,
                        onSelected: (_) {},
                        items: [
                          ResidentNavigationItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home,
                            label: 'nav_home'.tr(context: context),
                          ),
                          ResidentNavigationItem(
                            icon: Icons.event_outlined,
                            activeIcon: Icons.event,
                            label: 'nav_facilities'.tr(context: context),
                          ),
                          ResidentNavigationItem(
                            icon: Icons.groups_outlined,
                            activeIcon: Icons.groups,
                            label: 'nav_community'.tr(context: context),
                          ),
                          ResidentNavigationItem(
                            icon: Icons.credit_card_outlined,
                            activeIcon: Icons.credit_card,
                            label: 'nav_payments'.tr(context: context),
                          ),
                          ResidentNavigationItem(
                            icon: Icons.apps_outlined,
                            activeIcon: Icons.apps,
                            label: 'nav_more'.tr(context: context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          startLocale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('navigation labels switch from English to Tamil at runtime', (
    tester,
  ) async {
    await pumpNavigation(tester, width: 390, textScale: 1);
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Switch language'));
    await tester.pumpAndSettle();
    for (final label in ['வீடு', 'வசதி', 'குழு', 'பணம்', 'பிற']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tamil labels and Arabic RTL fit narrow and normal widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0]) {
      await pumpNavigation(
        tester,
        width: width,
        textScale: 1.7,
        locale: const Locale('ta'),
      );
      expect(find.text('வசதி'), findsOneWidget);
      expect(find.text('பணம்'), findsOneWidget);
      for (final label in ['வீடு', 'வசதி', 'குழு', 'பணம்', 'பிற']) {
        final paragraph =
            tester.renderObject(find.text(label)) as RenderParagraph;
        expect(
          paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: label.length),
              )
              .length,
          lessThanOrEqualTo(1),
          reason: '$label should not split across lines at $width px',
        );
      }
      expect(
        tester.getRect(find.byType(ResidentFloatingBottomNavigation)).height,
        lessThan(160),
      );
      expect(tester.takeException(), isNull);
    }

    await pumpNavigation(
      tester,
      width: 320,
      textScale: 1.7,
      locale: const Locale('ar'),
      direction: ui.TextDirection.rtl,
    );
    expect(find.text('مرافق'), findsOneWidget);
    expect(find.text('دفع'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
