import 'package:admin_app/billing_screen.dart';
import 'package:admin_app/services/billing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flexible V2 payment proof review', () {
    test('maps expected settlement failures to actionable messages', () {
      expect(
        paymentVerificationErrorMessage(
          Exception('duplicate_payment_reference'),
        ),
        contains('already recorded'),
      );
      expect(
        paymentVerificationErrorMessage(Exception('Bill revision changed')),
        contains('balance changed'),
      );
      expect(
        paymentVerificationErrorMessage(Exception('Only pending proofs')),
        contains('no longer pending'),
      );
      expect(
        paymentVerificationErrorMessage(
          Exception('receipt object does not exist'),
        ),
        contains('evidence is missing'),
      );
      expect(
        paymentVerificationErrorMessage(Exception('idempotency_conflict')),
        contains('same confirmed amount'),
      );
    });

    testWidgets('requires an entered amount and explicit bank confirmation', (
      tester,
    ) async {
      int? confirmedMinor;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  confirmedMinor = await showDialog<int>(
                    context: context,
                    builder: (_) => const FlexiblePaymentProofReviewDialog(
                      claimedAmountMinor: 123456,
                    ),
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(find.text('Resident claim: ₹1,234.56'), findsOneWidget);
      expect(find.text('Confirm Received Amount'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      final confirmButton = find.widgetWithText(
        ElevatedButton,
        'Confirm Received Amount',
      );
      expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '999.99');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This differs from the resident claim'),
        findsOneWidget,
      );
      expect(find.textContaining('₹999.99'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      expect(confirmedMinor, 99999);
    });

    testWidgets(
      'review dialog remains readable at narrow width and large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const FlexiblePaymentProofReviewDialog(
                      claimedAmountMinor: 123456,
                    ),
                  ),
                  child: const Text('Open review'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open review'));
        await tester.pumpAndSettle();
        expect(find.text('Resident claim: ₹1,234.56'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Confirm Received Amount'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'sends only the independently confirmed amount and stable proof ID',
      () async {
        final calls = <Map<String, dynamic>>[];
        final service = BillingService(
          paymentProofCallable: (name, payload) async {
            expect(name, 'verifyPaymentProofV2');
            calls.add(Map<String, dynamic>.from(payload));
            return {'success': true, 'transactionId': 'settlement-1'};
          },
        );

        await service.verifyPaymentProofV2(
          'proof-1',
          confirmedAmountMinor: 99999,
        );
        await service.verifyPaymentProofV2(
          'proof-1',
          confirmedAmountMinor: 99999,
        );

        expect(calls, [
          {'paymentId': 'proof-1', 'confirmedAmountMinor': 99999},
          {'paymentId': 'proof-1', 'confirmedAmountMinor': 99999},
        ]);
      },
    );

    test(
      'legacy verification omits the confirmed amount and requires success response',
      () async {
        Map<String, dynamic>? sent;
        final service = BillingService(
          paymentProofCallable: (_, payload) async {
            sent = Map<String, dynamic>.from(payload);
            return {'success': true, 'transactionId': 'legacy-settlement'};
          },
        );
        await service.verifyPaymentProofV2('legacy-proof');
        expect(sent, {'paymentId': 'legacy-proof'});

        final unresolved = BillingService(
          paymentProofCallable: (_, __) async => {'success': false},
        );
        await expectLater(
          unresolved.verifyPaymentProofV2('legacy-proof'),
          throwsFormatException,
        );
      },
    );
  });
}
