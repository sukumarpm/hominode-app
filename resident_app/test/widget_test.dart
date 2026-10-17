import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/payment_history_screen.dart';

import 'localization_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  testWidgets('Hominode payment history renders its localized empty state', (
    tester,
  ) async {
    await pumpEnglishLocalizedWidget(
      tester,
      withEnglishLocalization(
        (context) => localizedMaterialApp(
          context,
          home: const PaymentHistoryScreen(paidBills: []),
        ),
      ),
    );

    expect(find.text('Payment History'), findsOneWidget);
    expect(find.text('No Payment History'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
