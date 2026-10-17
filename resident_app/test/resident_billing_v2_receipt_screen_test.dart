import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/receipt_screen.dart';
import 'package:resident_app/src/services/resident_billing_v2_receipt_service.dart';

import 'localization_test_app.dart';

Map<String, dynamic> _receiptResponse() => {
  'success': true,
  'schemaVersion': 1,
  'receiptId': 'HOMINODE-V2-tx-7',
  'transactionId': 'tx-7',
  'community': {
    'communityId': 'community-1',
    'name': 'Green Wave Residences',
    'address': 'Community Address',
  },
  'currency': 'INR',
  'method': 'upi',
  'paymentReference': 'UPI-REFERENCE-7',
  'receivedAt': 1785542400000,
  'moneyReceivedMinor': 1250,
  'confirmedAmountMinor': 1250,
  'claimedAmountMinor': 1200,
  'amountMismatch': true,
  'confirmation': {
    'status': 'verified',
    'verifiedAt': 1785542401000,
    'verifiedBy': 'Community Admin',
  },
  'allocations': [
    {
      'billId': 'internal-bill-1',
      'amountMinor': 1000,
      'allocatedAt': 1785542400000,
    },
  ],
  'allocatedAmountMinor': 1000,
  'excessCreditMinor': 250,
  'reconciliation': {
    'confirmedAmountMinor': 1250,
    'allocatedAmountMinor': 1000,
    'excessCreditMinor': 250,
  },
  'accountingBasis': {
    'amountsAreMinorUnits': true,
    'allocationsAreFromThisPayment': true,
    'existingCreditApplicationsExcluded': true,
  },
  'snapshot': 'original_settlement',
  'laterAdjustments': {
    'reversedAllocationMinor': 100,
    'revisionCreditIssuedMinor': 100,
  },
};

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets('legacy V1 receipt still shows its transaction and PDF actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => localizedMaterialApp(
            context,
            home: ReceiptScreen(receipt: Receipt.sample()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TXN_20251105_001'), findsOneWidget);
    expect(find.text('Download Receipt'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets(
    'loads verified receipt and shows received money, allocations and excess separately',
    (tester) async {
      final receiptResult = Completer<Map<String, dynamic>>();
      final service = ResidentBillingV2ReceiptService(
        callable: (_, payload) async {
          expect(payload, {'transactionId': 'tx-7'});
          return receiptResult.future;
        },
      );
      await tester.pumpWidget(
        withEnglishLocalization(
          (context) => ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => localizedMaterialApp(
              context,
              home: ResidentBillingV2ReceiptScreen(
                transactionId: 'tx-7',
                service: service,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('v2-receipt-loading')), findsOneWidget);
      receiptResult.complete(_receiptResponse());
      await tester.pumpAndSettle();

      expect(find.text('UPI-REFERENCE-7'), findsOneWidget);
      expect(find.text('Green Wave Residences'), findsWidgets);
      expect(find.text('Bill allocation 1'), findsOneWidget);
      expect(find.text('₹10.00'), findsOneWidget);
      expect(find.text('Excess credit created'), findsOneWidget);
      expect(find.text('₹2.50'), findsOneWidget);
      expect(find.text('Amount Received'), findsOneWidget);
      expect(find.text('₹12.50'), findsOneWidget);
      expect(
        find.textContaining('Later bill revision adjustments'),
        findsOneWidget,
      );
      expect(find.text('internal-bill-1'), findsNothing);
    },
  );

  testWidgets('receipt access failure shows safe retry and can recover', (
    tester,
  ) async {
    var calls = 0;
    final service = ResidentBillingV2ReceiptService(
      callable: (_, _) async {
        calls++;
        if (calls == 1) throw StateError('private authorization detail');
        return _receiptResponse();
      },
    );
    await tester.pumpWidget(
      withEnglishLocalization(
        (context) => ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => localizedMaterialApp(
            context,
            home: ResidentBillingV2ReceiptScreen(
              transactionId: 'tx-7',
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(ResidentBillingV2ReceiptService.safeErrorMessage),
      findsOneWidget,
    );
    expect(find.textContaining('private authorization'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('v2-receipt-retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Amount Received'), findsOneWidget);
  });
}
