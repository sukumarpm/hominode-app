import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
// Reuse installed Firebase SDK interfaces to keep layout tests off native APIs.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/screens/verify_otp_screen_single_field.dart';

class _AuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    dynamic currentUser,
    String? languageCode,
  }) => this;
}

Finder digits() => find.byWidgetPredicate((widget) {
  if (widget is! Container || widget.decoration is! BoxDecoration) return false;
  final border = (widget.decoration as BoxDecoration).border;
  return border is Border &&
      border.bottom.width == 2 &&
      border.top == BorderSide.none;
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _AuthPlatform();

    // Match mobile typography rather than the test font's square glyph widths.
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
    final loader = FontLoader('Roboto');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final bytes = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/$font',
      ).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Future<void> mount(
    WidgetTester tester,
    Size size,
    double scale,
    bool keyboard,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 320 : 0);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
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
          home: const VerifyOTPScreenSingleField(
            mobileNumber: '+639171234567',
            verificationId: 'layout-test-only',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  void expectIndicatorsFit(
    WidgetTester tester,
    Size size, {
    required bool keyboard,
  }) {
    expect(digits(), findsNWidgets(6));
    final fieldRect = tester.getRect(find.byType(TextField));
    final rectangles = [
      for (final element in digits().evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    final first = rectangles.first;
    for (final rect in rectangles) {
      expect(rect.width, greaterThan(0));
      expect(rect.width, closeTo(first.width, 0.01));
      expect(rect.top, closeTo(first.top, 0.01));
      expect(rect.left, greaterThanOrEqualTo(fieldRect.left - 0.01));
      expect(rect.right, lessThanOrEqualTo(fieldRect.right + 0.01));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(size.height - (keyboard ? 320 : 0)),
      );
    }
    final gap = rectangles[1].left - first.right;
    expect(gap, greaterThan(0));
    for (var i = 1; i < rectangles.length; i++) {
      expect(rectangles[i].left - rectangles[i - 1].right, closeTo(gap, 0.01));
    }
    expect(
      (first.left + rectangles.last.right) / 2,
      closeTo(fieldRect.center.dx, 0.01),
    );
    for (final widget in tester.widgetList<Container>(digits())) {
      final border = (widget.decoration as BoxDecoration).border! as Border;
      expect(border.bottom.style, BorderStyle.solid);
      expect(border.bottom.color.a, greaterThan(0));
    }
  }

  for (final size in [
    const Size(393, 852),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 1.5]) {
      for (final keyboard in [false, true]) {
        testWidgets(
          'OTP fits ${size.width}x${size.height}, scale $scale, keyboard $keyboard',
          (tester) async {
            await mount(tester, size, scale, keyboard);
            expect(tester.takeException(), isNull);
            expectIndicatorsFit(tester, size, keyboard: keyboard);
            if (size.width == 393 && scale == 1) {
              expect(
                tester.getSize(digits().first).width,
                closeTo(34 * size.width / 390, 0.01),
              );
            }
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, isEmpty);
            final verifyButton = find.ancestor(
              of: find.text('Verify OTP'),
              matching: find.byType(InkWell),
            );
            expect(tester.widget<InkWell>(verifyButton).onTap, isNull);
            await tester.tap(find.byType(TextField));
            await tester.enterText(find.byType(TextField), '12x34567');
            await tester.pumpAndSettle();
            expect(field.controller!.text, '123456');
            expect(field.focusNode!.hasFocus, isTrue);
            expect(tester.widget<InkWell>(verifyButton).onTap, isNotNull);
            for (var i = 0; i < 6; i++) {
              expect(
                find.descendant(
                  of: digits().at(i),
                  matching: find.text('${i + 1}'),
                ),
                findsOneWidget,
              );
              final border =
                  (tester.widget<Container>(digits().at(i)).decoration
                              as BoxDecoration)
                          .border!
                      as Border;
              expect(border.bottom.color, const Color(0xFF33D6FF));
            }
            expectIndicatorsFit(tester, size, keyboard: keyboard);
            await tester.enterText(find.byType(TextField), '12');
            await tester.pumpAndSettle();
            expect(field.controller!.text, '12');
            expect(tester.widget<InkWell>(verifyButton).onTap, isNull);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
