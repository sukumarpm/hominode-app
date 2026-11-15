import 'dart:io';

import 'package:admin_app/widgets/admin_home_promo_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _heading = 'Smart Community,\nBetter Living';
const _description =
    'Manage your society, connect with residents and simplify everyday tasks.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Flutter Roboto font not found');
      }
      directory = parent;
    }
    final fonts = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final bytes = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/$font',
      ).readAsBytesSync();
      fonts.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await fonts.load();
  });

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets(
        'full promotion at ${size.width}x${size.height}, scale $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(390, 844),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (_, _) => MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: AdminHomePromoBanner()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final clip = find.descendant(
            of: find.byType(AdminHomePromoBanner),
            matching: find.byType(ClipRRect),
          );
          final banner = tester.getRect(clip);
          expect(banner.left, closeTo(15 * size.width / 390, 0.01));
          expect(
            banner.width,
            closeTo(size.width - 30 * size.width / 390, 0.01),
          );
          final arrow = find.byIcon(Icons.arrow_forward_rounded);
          final arrowBounds = tester.getRect(arrow);
          expect(arrow, findsOneWidget);
          expect(arrowBounds.center.dy, closeTo(banner.center.dy, 0.01));
          expect(arrowBounds.right, lessThanOrEqualTo(banner.right));
          for (final label in [_heading, _description]) {
            final finder = find.text(label);
            expect(finder, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
            final text = tester.widget<Text>(finder);
            final context = tester.element(finder);
            final painter = TextPainter(
              text: TextSpan(
                text: label,
                style: DefaultTextStyle.of(context).style.merge(text.style),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: paragraph.size.width);
            expect(
              paragraph.size.height,
              greaterThanOrEqualTo(painter.height - 0.01),
              reason: label,
            );
            painter.dispose();
            final textBounds = tester.getRect(finder);
            expect(
              textBounds.top,
              greaterThanOrEqualTo(banner.top + 16 * size.height / 844 - 0.01),
            );
            expect(
              textBounds.bottom,
              lessThanOrEqualTo(banner.bottom - 16 * size.height / 844 + 0.01),
            );
            expect(
              textBounds.left,
              closeTo(banner.left + 108 * size.width / 390, 0.01),
            );
            expect(
              textBounds.right,
              lessThanOrEqualTo(banner.right - 56 * size.width / 390 + 0.01),
            );
          }
          expect(
            tester.getRect(find.text(_description)).top,
            greaterThan(tester.getRect(find.text(_heading)).bottom),
          );
          expect(find.byIcon(Icons.phone_iphone_rounded), findsOneWidget);
          expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
          expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
          expect(
            tester.widget<Text>(find.text(_heading)).style!.fontSize,
            closeTo(15.sp, 0.01),
          );
          expect(
            tester.widget<Text>(find.text(_description)).style!.fontSize,
            closeTo(8.8.sp, 0.01),
          );
          if (size.width == 393 && scale == 1) {
            expect(banner.height, closeTo(104 * size.height / 844, 0.01));
          }
        },
      );
    }
  }
}
