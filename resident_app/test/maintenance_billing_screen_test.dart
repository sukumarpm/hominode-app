import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/maintenance_billing_screen.dart';
import 'package:resident_app/src/services/bill_firestore_service.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';

Map<String, dynamic> _v1({String status = 'pending', String id = 'v1'}) => {
  'id': id,
  'communityId': 'community',
  'flatId': 'flat',
  'schemaVersion': 1,
  'status': status,
  'month': 'January',
  'amount': 2500.0,
  'chargeBreakdown': {'Maintenance': 2000.0, 'Water': 500.0},
};

Map<String, dynamic> _v2({
  String status = 'pending',
  String id = 'v2',
  int outstanding = 120000,
}) => {
  'id': id,
  'communityId': 'community',
  'residentId': 'resident',
  'flatId': 'flat',
  'schemaVersion': 2,
  'currency': 'INR',
  'status': status,
  'billingPeriod': '2026-08',
  'amountMinor': 250000,
  'paidAmountMinor': 100000,
  'creditAppliedMinor': 30000,
  'outstandingAmountMinor': outstanding,
  'currentRevisionId': 'revision_1',
  'chargeLines': [
    {
      'lineId': 'maintenance',
      'code': 'maintenance',
      'label': 'Maintenance',
      'amountMinor': 200000,
    },
    {
      'lineId': 'water',
      'code': 'water',
      'label': 'Water',
      'amountMinor': 50000,
    },
  ],
};

Map<String, dynamic> _proof(String status, {String? rejectionReason}) => {
  'schemaVersion': 2,
  'id': 'proof-1',
  'communityId': 'community',
  'residentId': 'resident',
  'userId': 'resident',
  'billId': 'v2',
  'status': status,
  'submittedAmountMinor': 250000,
  'submittedBillRevisionId': 'revision_1',
  'receiptPath': 'payment_receipts/community/v2/resident/proof-1.jpg',
  if (rejectionReason != null) 'rejectionReason': rejectionReason,
};

class _Fixture {
  List<Map<String, dynamic>> bills = [];
  Map<String, dynamic>? v1Payment;
  Map<String, dynamic>? v2Proof;
  final v1BillIds = <String>[];
  final v2BillIds = <String>[];
  final prepareCalls = <Map<String, dynamic>>[];

  late final billService = BillFirestoreService(
    billsStreamLoader: () => Stream.value(bills),
    v1PaymentStreamLoader: (billId) {
      v1BillIds.add(billId);
      return Stream.value(v1Payment);
    },
    v2ProofStreamLoader: (billId) {
      v2BillIds.add(billId);
      return Stream.value(v2Proof);
    },
  );

  late final upiService = ResidentDirectUpiService(
    scopeLoader: () async => const ResidentDirectUpiScope(
      uid: 'resident',
      communityId: 'community',
      flatId: 'flat',
    ),
    billLoader: (billId) async => ResidentDirectUpiDocument(
      exists: true,
      data: bills.firstWhere((bill) => bill['id'] == billId),
    ),
    paymentConfigLoader: (_) async => const ResidentDirectUpiDocument(
      exists: true,
      data: {
        'communityId': 'community',
        'version': 1,
        'directUpi': {
          'enabled': true,
          'vpa': 'community@upi',
          'payeeName': 'Community',
        },
        'updatedBy': 'admin',
      },
    ),
    v2ProofLoader:
        ({required communityId, required billId, required residentId}) async =>
            v2Proof == null ? [] : [v2Proof!],
    prepareProof: (payload) async {
      prepareCalls.add(payload);
      return {
        'paymentId': 'proof-new',
        'receiptPath':
            'payment_receipts/community/${payload['billId']}/resident/proof-new.${payload['receiptExtension']}',
        'status': 'pending',
      };
    },
    receiptMetadataLoader: (_) async => null,
    receiptUploader:
        ({
          required receiptPath,
          required bytes,
          required contentType,
          required customMetadata,
        }) async {},
  );
}

Widget _app(_Fixture fixture) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: MaintenanceBillingScreen(
      billService: fixture.billService,
      directUpiService: fixture.upiService,
      languageCodeOverride: 'en',
    ),
  ),
);

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('V1 pending bill keeps its amount and chargeBreakdown UI', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()..bills = [_v1()];
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(find.text('January Bill'), findsOneWidget);
    expect(find.text('₹2500'), findsNWidgets(2));
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('₹2000'), findsOneWidget);
    expect(find.text('Pay via UPI'), findsOneWidget);
    expect(fixture.v1BillIds, ['v1']);
    expect(fixture.v2BillIds, isEmpty);
  });

  for (final status in ['pending', 'overdue', 'partially_paid']) {
    testWidgets('V2 $status bill displays exact totals and remains payable', (
      tester,
    ) async {
      _setViewport(tester);
      final fixture = _Fixture()
        ..bills = [_v2(status: status, outstanding: 120000)];
      await tester.pumpWidget(_app(fixture));
      await tester.pumpAndSettle();

      expect(find.text('August 2026 Bill'), findsOneWidget);
      expect(find.text('₹2500.00'), findsNWidgets(2));
      expect(find.text('Total bill'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Credit applied'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('₹1000.00'), findsOneWidget);
      expect(find.text('₹300.00'), findsOneWidget);
      expect(find.text('₹1200.00'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Pay via UPI'), findsOneWidget);
      expect(fixture.v2BillIds, ['v2']);
      expect(fixture.v1BillIds, isEmpty);
    });
  }

  testWidgets('V2 zero outstanding has no payment action', (tester) async {
    _setViewport(tester);
    final fixture = _Fixture()
      ..bills = [_v2(status: 'partially_paid', outstanding: 0)];
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(
      find.text('No outstanding balance. No payment is due.'),
      findsOneWidget,
    );
    expect(find.text('Pay via UPI'), findsNothing);
    expect(find.text('Already paid? Submit payment proof'), findsNothing);
  });

  testWidgets('V1 and V2 current bills can coexist in the billing view', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()
      ..bills = [_v2(status: 'partially_paid', outstanding: 120000), _v1()];
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(find.text('January Bill'), findsOneWidget);
    expect(find.text('August 2026 Bill'), findsOneWidget);
    expect(find.text('Pay via UPI'), findsNWidgets(2));
    expect(fixture.v1BillIds, ['v1']);
    expect(fixture.v2BillIds, ['v2']);
  });

  testWidgets('all outstanding V2 bills render with their own balances', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()
      ..bills = [
        _v2(id: 'v2-aug', status: 'pending', outstanding: 120000),
        _v2(id: 'v2-jul', status: 'partially_paid', outstanding: 45000)
          ..['billingPeriod'] = '2026-07',
        _v2(id: 'v2-jun', status: 'settled', outstanding: 0),
      ];
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(find.text('August 2026 Bill'), findsOneWidget);
    expect(find.text('July 2026 Bill'), findsOneWidget);
    expect(find.text('June 2026 Bill'), findsNothing);
    expect(find.text('Pay via UPI'), findsNWidgets(2));
    expect(fixture.v2BillIds, containsAll(['v2-aug', 'v2-jul']));
  });

  testWidgets('non-INR V2 bill is unavailable and cannot be paid as INR', (
    tester,
  ) async {
    _setViewport(tester);
    final invalid = _v2()..['currency'] = 'USD';
    final fixture = _Fixture()..bills = [invalid];
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(find.textContaining('Billing details unavailable'), findsOneWidget);
    expect(find.text('₹2500.00'), findsNothing);
    expect(find.text('Pay via UPI'), findsNothing);
    expect(find.textContaining('Credit applied'), findsNothing);
    expect(fixture.v2BillIds, isEmpty);
  });

  testWidgets(
    'pending V2 proof blocks another submit and offers safe recovery',
    (tester) async {
      _setViewport(tester);
      final fixture = _Fixture()
        ..bills = [_v2()]
        ..v2Proof = _proof('pending');
      await tester.pumpWidget(_app(fixture));
      await tester.pumpAndSettle();

      expect(
        find.text('Payment submitted / awaiting Admin verification'),
        findsOneWidget,
      );
      expect(find.text('Check receipt or resume upload'), findsOneWidget);
      expect(find.text('Pay via UPI'), findsNothing);
      expect(fixture.prepareCalls, isEmpty);
    },
  );

  testWidgets('failed V2 proof shows rejection reason and resubmit action', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()
      ..bills = [_v2()]
      ..v2Proof = _proof('failed', rejectionReason: 'Receipt is unreadable');
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(find.text('Payment Rejected'), findsOneWidget);
    expect(find.text('Reason: Receipt is unreadable'), findsOneWidget);
    expect(find.text('Resubmit Payment Proof'), findsOneWidget);
    expect(fixture.v1BillIds, isEmpty);
  });

  testWidgets('completed V2 proof is verified and cannot resume that proof', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()
      ..bills = [_v2()]
      ..v2Proof = _proof('completed');
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(
      find.text('Payment verified by your community administrator.'),
      findsOneWidget,
    );
    expect(find.text('Check receipt or resume upload'), findsNothing);
    expect(find.text('Resubmit Payment Proof'), findsNothing);
    expect(find.text('Pay via UPI'), findsOneWidget);
  });
}
