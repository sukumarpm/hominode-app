import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/app_segmented_control.dart';
import 'package:resident_app/src/components/resident_visitor_empty_state.dart';

import 'localization_test_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  final emptyTabs = [
    (
      'visitor_tab_expected',
      'visitor_empty_expected',
      'visitor_empty_expected_hint',
      Icons.pending_outlined,
    ),
    (
      'visitor_tab_checked_in',
      'visitor_empty_checked_in',
      'visitor_empty_checked_in_hint',
      Icons.check_circle_outline,
    ),
    (
      'visitor_tab_history',
      'visitor_empty_history',
      'visitor_empty_history_hint',
      Icons.cancel_outlined,
    ),
    (
      'deliveries',
      'visitor_empty_deliveries',
      'visitor_empty_deliveries_hint',
      Icons.local_shipping_outlined,
    ),
  ];

  for (final locale in ['ta', 'ar']) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.7]) {
        testWidgets(
          '$locale Visitor empty states are legible at ${width.toInt()}px and ${scale}x text',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                builder: (context, child) => withResidentLocalization(
                  (context) => MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: Size(width, 800),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: const _VisitorEmptyTabs(),
                    ),
                  ),
                  startLocale: Locale(locale),
                ),
              ),
            );
            await tester.pumpAndSettle();

            for (var index = 0; index < emptyTabs.length; index++) {
              final tab = emptyTabs[index];
              if (index > 0) {
                await tester.ensureVisible(find.text(tab.$1.tr()));
                await tester.tap(find.text(tab.$1.tr()));
                await tester.pumpAndSettle();
              }
              expect(find.text(tab.$2.tr()), findsOneWidget);
              expect(find.text(tab.$3.tr()), findsOneWidget);
              expect(find.byIcon(tab.$4), findsOneWidget);
            }

            final heading = tester.widget<Text>(
              find.text(emptyTabs.last.$2.tr()),
            );
            final description = tester.widget<Text>(
              find.text(emptyTabs.last.$3.tr()),
            );
            final icon = tester.widget<Icon>(find.byIcon(emptyTabs.last.$4));
            final surface = tester.widget<Container>(
              find.descendant(
                of: find.byType(ResidentVisitorEmptyState),
                matching: find.byType(Container),
              ),
            );
            final decoration = surface.decoration! as BoxDecoration;

            expect(heading.style!.color, ResidentVisitorEmptyState.titleColor);
            expect(
              description.style!.color,
              ResidentVisitorEmptyState.descriptionColor,
            );
            expect(icon.color, ResidentVisitorEmptyState.iconColor);
            expect(decoration.color, ResidentVisitorEmptyState.surfaceColor);
            expect(decoration.color!.a, greaterThanOrEqualTo(0.94));
            expect(heading.softWrap, isTrue);
            expect(description.softWrap, isTrue);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

class _VisitorEmptyTabs extends StatefulWidget {
  const _VisitorEmptyTabs();

  @override
  State<_VisitorEmptyTabs> createState() => _VisitorEmptyTabsState();
}

class _VisitorEmptyTabsState extends State<_VisitorEmptyTabs> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppSegmentedControl(
              segments: [
                'visitor_tab_expected'.tr(),
                'visitor_tab_checked_in'.tr(),
                'visitor_tab_history'.tr(),
                'deliveries'.tr(),
              ],
              selectedIndex: selected,
              scrollable: true,
              onChanged: (index) => setState(() => selected = index),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ResidentVisitorEmptyState.forTab(selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
