import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/payment_history_screen.dart';

import 'localization_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  testWidgets(
    'Tamil payment history localizes fields and preserves references',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        withResidentLocalization(
          (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, _) => localizedMaterialApp(
              context,
              home: PaymentHistoryScreen(
                paidBills: [
                  {
                    'id': 'bill_fixture',
                    'month': 'October',
                    'year': '2026',
                    'status': 'paid',
                    'paymentMethod': 'upi',
                    'paymentReference': 'ref-fixture-42',
                    'paidAt': Timestamp.fromDate(DateTime(2026, 10, 4)),
                    'amount': 1200,
                  },
                ],
              ),
            ),
          ),
          startLocale: const Locale('ta'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('கட்டண வரலாறு'), findsOneWidget);
      expect(find.text('கட்டண தேதி'), findsOneWidget);
      expect(find.text('கட்டண முறை'), findsOneWidget);
      expect(find.text('கட்டணக் குறிப்பு'), findsOneWidget);
      expect(find.text('ref-fixture-42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
