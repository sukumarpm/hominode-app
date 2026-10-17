import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/components/app_segmented_control.dart';

void main() {
  testWidgets('long RTL visitor labels wrap and selection follows direction', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: AppSegmentedControl(
                    segments: const [
                      'قيد الانتظار',
                      'موافق عليه',
                      'مرفوض',
                      'التسليمات',
                    ],
                    selectedIndex: 0,
                    allowLabelWrap: true,
                    onChanged: (index) => selected = index,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final firstLabel = tester.widget<Text>(find.text('قيد الانتظار'));
    expect(firstLabel.maxLines, 2);
    expect(firstLabel.softWrap, isTrue);
    expect(firstLabel.overflow, TextOverflow.visible);

    final control = tester.getRect(
      find.byKey(const ValueKey('app-segmented-control-track')),
    );
    final selectedPill = tester.getRect(
      find.byKey(const ValueKey('app-segmented-control-selected-pill')),
    );
    expect(selectedPill.center.dx, greaterThan(control.center.dx));

    await tester.tap(find.text('موافق عليه'));
    expect(selected, 1);
  });

  testWidgets('Tamil visitor labels are not forced into ellipsis', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: AppSegmentedControl(
              segments: const [
                'நிலுவையில்',
                'அனுமதிக்கப்பட்டது',
                'நிராகரிக்கப்பட்டது',
                'விநியோகங்கள்',
              ],
              selectedIndex: 1,
              allowLabelWrap: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    for (final label in [
      'நிலுவையில்',
      'அனுமதிக்கப்பட்டது',
      'நிராகரிக்கப்பட்டது',
      'விநியோகங்கள்',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.visible);
    }
  });

  for (final width in [320.0, 390.0]) {
    for (final textScale in [1.0, 1.7]) {
      testWidgets('scrollable Tamil visitor tabs keep each word intact at '
          '${width.toInt()}px and ${textScale}x text', (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const labels = [
          'வரவிருக்கும் விருந்தினர்கள்',
          'உள்ளே வந்தவர்கள்',
          'வரலாறு',
          'விநியோகங்கள்',
        ];

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (context, child) => MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 720),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: width,
                        child: AppSegmentedControl(
                          segments: labels,
                          selectedIndex: 0,
                          scrollable: true,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app-segmented-control-scroll')),
          findsOneWidget,
        );
        for (final label in labels) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 1);
          expect(text.softWrap, isFalse);
          expect(text.overflow, TextOverflow.visible);
        }

        await tester.drag(
          find.byKey(const ValueKey('app-segmented-control-scroll')),
          const Offset(180, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
