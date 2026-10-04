import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_billing_statement_service.dart';

Map<String, dynamic> _response({
  String period = '2026-08',
  int amountMinor = 123456,
  Object? paidAllocationMinor = 23456,
  Object? creditAppliedMinor = 10000,
  Object? outstandingMinor = 90000,
  Object? settlement = const {
    'transactionId': 'tx-1',
    'method': 'upi',
    'reference': 'UPI-123',
    'receivedAt': 1785542400000,
    'netAppliedMinor': 23456,
  },
}) => {
  'success': true,
  'schemaVersion': 1,
  'communityId': 'community-1',
  'residentId': 'resident-1',
  'billingPeriod': period,
  'generatedAtMs': 1785542400000,
  'summary': {
    'billsCount': 1,
    'billedMinor': amountMinor,
    'paidAllocationMinor': paidAllocationMinor,
    'creditAppliedMinor': creditAppliedMinor,
    'outstandingMinor': outstandingMinor,
    'availableCreditMinor': 500,
    'statusCounts': {
      'pending': 0,
      'partially_paid': 1,
      'paid': 0,
      'overdue': 0,
    },
  },
  'bills': [
    {
      'billId': 'bill-1',
      'billingPeriod': period,
      'amountMinor': amountMinor,
      'paidAllocationMinor': paidAllocationMinor,
      'creditAppliedMinor': creditAppliedMinor,
      'outstandingMinor': outstandingMinor,
      'status': 'partially_paid',
      'dueDateKey': '2026-08-15',
      'chargeLines': [
        {
          'lineId': 'maintenance',
          'code': 'maintenance',
          'label': 'Maintenance',
          'amountMinor': amountMinor,
        },
      ],
      'settlements': [if (settlement != null) settlement],
    },
  ],
};

void main() {
  test('calls the exact function with only the billing period', () async {
    String? name;
    Map<String, dynamic>? payload;
    final service = ResidentBillingStatementService(
      callable: (callableName, data) async {
        name = callableName;
        payload = data;
        return _response();
      },
    );

    await service.getStatement('2026-08');

    expect(name, 'getResidentBillingV2Statement');
    expect(payload, {'billingPeriod': '2026-08'});
  });

  test(
    'maps the canonical statement while preserving integer minor units',
    () async {
      final service = ResidentBillingStatementService(
        callable: (_, _) async => _response(),
      );

      final result = await service.getStatement('2026-08');

      expect(result.communityId, 'community-1');
      expect(result.residentId, 'resident-1');
      expect(result.generatedAtMs, 1785542400000);
      expect(result.summary.billedMinor, 123456);
      expect(result.summary.availableCreditMinor, 500);
      expect(result.bills.single.chargeLines.single.label, 'Maintenance');
      expect(result.bills.single.settlements.single.netAppliedMinor, 23456);
      expect(formatResidentStatementMoney(123456), '₹1234.56');
    },
  );

  test('rejects invalid periods before making a callable request', () async {
    var called = false;
    final service = ResidentBillingStatementService(
      callable: (_, _) async {
        called = true;
        return _response();
      },
    );
    await expectLater(service.getStatement('2026-13'), throwsArgumentError);
    expect(called, isFalse);
  });

  test('fails closed on malformed schema and mismatched period', () async {
    final missing = _response()..remove('schemaVersion');
    final wrongPeriod = _response(period: '2026-07');
    for (final response in [missing, wrongPeriod]) {
      final service = ResidentBillingStatementService(
        callable: (_, _) async => response,
      );
      await expectLater(
        service.getStatement('2026-08'),
        throwsA(isA<ResidentBillingStatementException>()),
      );
    }
  });

  test('rejects negative, fractional and string monetary values', () async {
    for (final value in [-1, 1.5, '123']) {
      final response = _response()..['summary']['billedMinor'] = value;
      final service = ResidentBillingStatementService(
        callable: (_, _) async => response,
      );
      await expectLater(
        service.getStatement('2026-08'),
        throwsA(isA<ResidentBillingStatementException>()),
      );
    }
  });

  test('rejects malformed bills and settlement records', () async {
    final malformedBill = _response()
      ..['bills'][0]['chargeLines'][0]['label'] = 42;
    final malformedSettlement = _response(
      settlement: {
        'transactionId': 'tx-1',
        'method': 'upi',
        'reference': 'UPI-123',
        'receivedAt': 1785542400000,
        'netAppliedMinor': 23456,
      },
    )..['bills'][0]['settlements'][0]['method'] = 'manual';
    for (final response in [malformedBill, malformedSettlement]) {
      final service = ResidentBillingStatementService(
        callable: (_, _) async => response,
      );
      await expectLater(
        service.getStatement('2026-08'),
        throwsA(isA<ResidentBillingStatementException>()),
      );
    }
  });

  test('accepts null or absent references without inventing one', () async {
    for (final settlement in [
      {
        'transactionId': 'tx-1',
        'method': 'cash',
        'receivedAt': 1785542400000,
        'netAppliedMinor': 23456,
      },
      {
        'transactionId': 'tx-1',
        'method': 'cash',
        'reference': null,
        'receivedAt': 1785542400000,
        'netAppliedMinor': 23456,
      },
    ]) {
      final response = _response(settlement: settlement);
      final service = ResidentBillingStatementService(
        callable: (_, _) async => response,
      );
      final result = await service.getStatement('2026-08');
      expect(result.bills.single.settlements.single.reference, isNull);
    }
  });

  test('callable errors expose only the safe message', () async {
    final service = ResidentBillingStatementService(
      callable: (_, _) async => throw StateError('private backend detail'),
    );
    await expectLater(
      service.getStatement('2026-08'),
      throwsA(
        isA<ResidentBillingStatementException>().having(
          (error) => error.message,
          'message',
          ResidentBillingStatementService.safeErrorMessage,
        ),
      ),
    );
  });
}
