import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/maintenance_billing_screen.dart';
import 'package:resident_app/src/services/bill_firestore_service.dart';
import 'package:resident_app/src/services/resident_billing_statement_service.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';

import 'localization_test_app.dart';

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
  final statementPeriods = <String>[];

  late final statementService = ResidentBillingStatementService(
    callable: (_, payload) async {
      final period = payload['billingPeriod'] as String;
      statementPeriods.add(period);
      return {
        'success': true,
        'schemaVersion': 1,
        'communityId': 'community',
        'residentId': 'resident',
        'billingPeriod': period,
        'generatedAtMs': 1785542400000,
        'summary': {
          'billsCount': 0,
          'billedMinor': 0,
          'paidAllocationMinor': 0,
          'creditAppliedMinor': 0,
          'outstandingMinor': 0,
          'availableCreditMinor': 0,
          'statusCounts': {
            'pending': 0,
            'partially_paid': 0,
            'paid': 0,
            'overdue': 0,
          },
        },
        'bills': <Object>[],
      };
    },
  );

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

Widget _app(
  _Fixture fixture, {
  double width = 390,
  double textScale = 1,
  bool showBackButton = false,
  String? initialBillId,
  Locale locale = const Locale('en'),
}) => withResidentLocalization(
  (context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => localizedMaterialApp(
      context,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaintenanceBillingScreen(
          billService: fixture.billService,
          directUpiService: fixture.upiService,
          statementService: fixture.statementService,
          languageCodeOverride: locale.languageCode,
          showBackButton: showBackButton,
          initialBillId: initialBillId,
        ),
      ),
    ),
  ),
  startLocale: locale,
);

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets(
    'notification bill target uses only the existing authorized bill stream',
    (tester) async {
      _setViewport(tester);
      final fixture = _Fixture()
        ..bills = [_v2(id: 'selected'), _v2(id: 'other')];
      await tester.pumpWidget(
        _app(fixture, initialBillId: 'selected', showBackButton: true),
      );
      await tester.pumpAndSettle();
      expect(fixture.v2BillIds, contains('selected'));
      expect(fixture.v2BillIds, isNot(contains('other')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unavailable or foreign notification bill never falls back to a different bill',
    (tester) async {
      _setViewport(tester);
      final fixture = _Fixture()..bills = [_v2(id: 'owned')];
      await tester.pumpWidget(
        _app(fixture, initialBillId: 'foreign', showBackButton: true),
      );
      await tester.pumpAndSettle();
      expect(fixture.v2BillIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('current bill status and heading fit narrow large-text layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture()..bills = [_v2(status: 'partially_paid')];

    await tester.pumpWidget(_app(fixture, width: 320, textScale: 1.8));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final textScale in [1.0, 1.8]) {
      testWidgets(
        'Tamil billing empty state fits ${width.toInt()}px at ${textScale}x',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _app(
              _Fixture(),
              width: width,
              textScale: textScale,
              locale: const Locale('ta'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('பராமரிப்பு மற்றும் கட்டணங்கள்'), findsOneWidget);
          expect(find.text('நிலுவை பில்கள் இல்லை'), findsOneWidget);
          expect(
            find.text('நீங்கள் அனைத்தையும் பார்த்துவிட்டீர்கள்!'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('pushed Maintenance and Billing exposes a visible Back action', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture();
    await tester.pumpWidget(_app(fixture, showBackButton: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    expect(find.text('Maintenance & Billing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payments tab keeps the normal tab-navigation header', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(_app(_Fixture()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
  });

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
      expect(find.text('Total billed'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
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

      expect(find.text('Pending Admin Verification'), findsOneWidget);
      expect(
        find.text('Your bill remains open until the payment is verified.'),
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

    expect(find.text('Rejected'), findsOneWidget);
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

  testWidgets(
    'Monthly Statement action is available without payment history and opens statement',
    (tester) async {
      _setViewport(tester);
      final fixture = _Fixture();
      await tester.pumpWidget(_app(fixture));
      await tester.pumpAndSettle();

      expect(find.text('No Payment History'), findsOneWidget);
      expect(find.text('Monthly Statement'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-monthly-statement')));
      await tester.pumpAndSettle();

      expect(find.text('No bills for this period.'), findsOneWidget);
      expect(fixture.statementPeriods, hasLength(1));
      expect(
        fixture.statementPeriods.single,
        matches(RegExp(r'^\d{4}-\d{2}$')),
      );
    },
  );

  testWidgets('Monthly Statement action preserves View all Payment History', (
    tester,
  ) async {
    _setViewport(tester);
    final fixture = _Fixture()
      ..bills = [_v1(status: 'paid')..['year'] = '2026'];
    await tester.pumpWidget(_app(fixture));
    await tester.pumpAndSettle();

    expect(find.text('Monthly Statement'), findsOneWidget);
    expect(find.text('Payment History'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.text('Payment History'), findsOneWidget);
    expect(find.text('January 2026'), findsOneWidget);
  });
}
