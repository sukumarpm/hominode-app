import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/widgets/resident_home_due_payment_content.dart';

void main() {
  for (final layout in [
    (width: 320.0, scale: 1.0, rtl: false),
    (width: 390.0, scale: 1.0, rtl: false),
    (width: 320.0, scale: 1.7, rtl: false),
    (width: 390.0, scale: 1.7, rtl: true),
  ]) {
    for (final isEmpty in [false, true]) {
      testWidgets(
        'due-payment ${isEmpty ? 'empty' : 'populated'} content lays out '
        'at ${layout.width}px, scale ${layout.scale}, rtl ${layout.rtl}',
        (tester) async {
          tester.view.physicalSize = Size(layout.width, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var billingTaps = 0;
          final billTitle = isEmpty
              ? 'No current bill'
              : layout.rtl
              ? 'رسوم الصيانة الشهرية المستحقة'
              : 'Monthly maintenance charges due';

          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(390, 844),
              minTextAdapt: true,
              builder: (context, child) => MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(layout.width, 760),
                    textScaler: TextScaler.linear(layout.scale),
                  ),
                  child: Directionality(
                    textDirection: layout.rtl
                        ? ui.TextDirection.rtl
                        : ui.TextDirection.ltr,
                    child: Scaffold(
                      body: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ResidentHomeDuePaymentContent(
                            amount: layout.rtl ? '‏₹ ٢٬٨٥٠' : '₹2,850',
                            isEmpty: isEmpty,
                            billTitle: billTitle,
                            onViewBilling: () => billingTaps++,
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

          expect(find.text(billTitle), findsOneWidget);
          expect(
            find.text(layout.rtl ? '‏₹ ٢٬٨٥٠' : '₹2,850'),
            isEmpty ? findsNothing : findsOneWidget,
          );
          expect(find.text('View Billing'), findsOneWidget);
          await tester.tap(find.text('View Billing'));
          expect(billingTaps, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
