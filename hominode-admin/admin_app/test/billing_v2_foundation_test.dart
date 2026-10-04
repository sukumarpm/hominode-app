import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/services/billing_service.dart';

void main() {
  group('Admin Billing V2 offline payment result validation', () {
    const submittedAmountMinor = 120050;
    final valid = {
      'success': true,
      'transactionId': 'transaction-1',
      'allocations': [
        {'billId': 'bill-1', 'amountMinor': 120000},
      ],
      'excessCreditMinor': 50,
      'alreadyCompleted': false,
    };

    test('normalizes a complete valid allocation result', () {
      expect(
        validateOfflinePaymentResultV2(
          valid,
          submittedAmountMinor: submittedAmountMinor,
        ),
        valid,
      );
    });

    test('rejects responses without an explicit success envelope', () {
      for (final response in [null, 'success', {...valid, 'success': false}]) {
        expect(
          () => validateOfflinePaymentResultV2(
            response,
            submittedAmountMinor: submittedAmountMinor,
          ),
          throwsFormatException,
        );
      }
    });

    test('accepts a fully allocated as resident credit result', () {
      final result = validateOfflinePaymentResultV2({
        ...valid,
        'allocations': <Map<String, dynamic>>[],
        'excessCreditMinor': submittedAmountMinor,
      }, submittedAmountMinor: submittedAmountMinor);
      expect(result['allocations'], isEmpty);
      expect(result['excessCreditMinor'], submittedAmountMinor);
    });

    test('rejects missing, blank, or malformed transaction IDs', () {
      for (final transactionId in [null, '', '  ', 'transaction/1']) {
        expect(
          () => validateOfflinePaymentResultV2({
            ...valid,
            'transactionId': transactionId,
          }, submittedAmountMinor: submittedAmountMinor),
          throwsFormatException,
        );
      }
    });

    test('rejects a missing or non-list allocations field', () {
      for (final allocations in [null, 'not a list']) {
        expect(
          () => validateOfflinePaymentResultV2({
            ...valid,
            'allocations': allocations,
          }, submittedAmountMinor: submittedAmountMinor),
          throwsFormatException,
        );
      }
    });

    test('rejects every malformed, unsafe, or duplicate allocation', () {
      final invalidAllocationLists = <List<Object?>>[
        [null],
        [
          {'billId': '', 'amountMinor': 120000},
        ],
        [
          {'billId': 'bill/1', 'amountMinor': 120000},
        ],
        [
          {'billId': 'bill-1', 'amountMinor': 0},
        ],
        [
          {'billId': 'bill-1', 'amountMinor': -1},
        ],
        [
          {'billId': 'bill-1', 'amountMinor': 1.5},
        ],
        [
          {'billId': 'bill-1', 'amountMinor': 9007199254740992},
        ],
        [
          {'billId': 'bill-1', 'amountMinor': 60000},
          {'billId': 'bill-1', 'amountMinor': 60000},
        ],
      ];
      for (final allocations in invalidAllocationLists) {
        expect(
          () => validateOfflinePaymentResultV2({
            ...valid,
            'allocations': allocations,
          }, submittedAmountMinor: submittedAmountMinor),
          throwsFormatException,
        );
      }
    });

    test('rejects invalid excess credit and alreadyCompleted values', () {
      for (final excess in [-1, 1.5, 9007199254740992]) {
        expect(
          () => validateOfflinePaymentResultV2({
            ...valid,
            'excessCreditMinor': excess,
          }, submittedAmountMinor: submittedAmountMinor),
          throwsFormatException,
        );
      }
      for (final alreadyCompleted in [null, 'false', 0]) {
        expect(
          () => validateOfflinePaymentResultV2({
            ...valid,
            'alreadyCompleted': alreadyCompleted,
          }, submittedAmountMinor: submittedAmountMinor),
          throwsFormatException,
        );
      }
    });

    test('uses exact integer arithmetic and requires the submitted total', () {
      expect(
        () => validateOfflinePaymentResultV2({
          ...valid,
          'excessCreditMinor': 49,
        }, submittedAmountMinor: submittedAmountMinor),
        throwsFormatException,
      );
      expect(
        () => validateOfflinePaymentResultV2({
          ...valid,
          'allocations': [
            {'billId': 'bill-1', 'amountMinor': 9007199254740991},
          ],
        }, submittedAmountMinor: submittedAmountMinor),
        throwsFormatException,
      );
    });
  });

  group('BillModel V2 foundation', () {
    test('detects only exact schemaVersion 2 and retains V1 behavior', () {
      final v2 = BillModel.fromMap('v2', {
        'schemaVersion': 2,
        'currency': 'INR',
        'amountMinor': 9007199254740991,
        'paidAmountMinor': 0,
        'creditAppliedMinor': 0,
        'outstandingAmountMinor': 9007199254740991,
        'currentRevisionId': 'revision-1',
        'amount': 123.45,
      });
      final v1 = BillModel.fromMap('v1', {
        'schemaVersion': '2',
        'amount': 123.45,
        'status': 'paid',
        'paymentId': 'legacy-payment',
      });

      expect(v2.isV2, isTrue);
      expect(v2.amountMinor, 9007199254740991);
      expect(v2.amount, 123.45); // Generic V1 amount remains independent.
      expect(v1.isV2, isFalse);
      expect(v1.amount, 123.45);
      expect(v1.paymentId, 'legacy-payment');
      expect(v1.toMap().containsKey('schemaVersion'), isFalse);
    });

    test('recognizes valid liabilities and settled projections', () {
      final partial = BillModel.fromMap('bill', {
        'schemaVersion': 2,
        'currency': 'INR',
        'amountMinor': 250000,
        'paidAmountMinor': 100000,
        'creditAppliedMinor': 30000,
        'outstandingAmountMinor': 120000,
        'currentRevisionId': 'revision-1',
        'status': 'partially_paid',
      });
      final zero = BillModel.fromMap('zero', {
        'schemaVersion': 2,
        'currency': 'INR',
        'amountMinor': 1000,
        'paidAmountMinor': 1000,
        'creditAppliedMinor': 0,
        'outstandingAmountMinor': 0,
        'currentRevisionId': 'revision-2',
        'status': 'partially_paid',
      });
      final paid = BillModel.fromMap('paid', {
        'schemaVersion': 2,
        'currency': 'INR',
        'amountMinor': 1000,
        'paidAmountMinor': 1000,
        'creditAppliedMinor': 0,
        'outstandingAmountMinor': 0,
        'currentRevisionId': 'revision-2',
        'status': 'paid',
      });

      expect(partial.hasValidInrV2Financials, isTrue);
      expect(partial.isCurrentV2Liability, isTrue);
      expect(partial.isSettledV2, isFalse);
      expect(zero.isCurrentV2Liability, isFalse);
      expect(zero.isSettledV2, isTrue);
      expect(paid.isSettledV2, isTrue);
    });

    test('fails closed for malformed or non-INR V2 financial data', () {
      for (final overrides in [
        {'currency': 'USD'},
        {'amountMinor': 1.5},
        {'outstandingAmountMinor': 9007199254740992},
        {'currentRevisionId': ''},
      ]) {
        final bill = BillModel.fromMap('bad', {
          'schemaVersion': 2,
          'currency': 'INR',
          'amountMinor': 1000,
          'paidAmountMinor': 0,
          'creditAppliedMinor': 0,
          'outstandingAmountMinor': 1000,
          'currentRevisionId': 'revision-1',
          'status': 'pending',
          ...overrides,
        });
        expect(bill.hasValidInrV2Financials, isFalse);
        expect(bill.isCurrentV2Liability, isFalse);
        expect(bill.formatV2MinorAmount(bill.amountMinor), 'Unavailable');
      }
    });

    test('formats safe integer minor units without double conversion', () {
      expect(formatInrMinorUnits(0), '₹0.00');
      expect(formatInrMinorUnits(123456), '₹1,234.56');
      expect(formatInrMinorUnits(123456789), '₹12,34,567.89');
      expect(formatInrMinorUnits(-1), 'Unavailable');
    });

    test('parses chargeLines safely and keeps V1 settlement fields', () {
      final bill = BillModel.fromMap('bill', {
        'schemaVersion': 2,
        'currency': 'INR',
        'amountMinor': 300,
        'paidAmountMinor': 0,
        'creditAppliedMinor': 0,
        'outstandingAmountMinor': 300,
        'currentRevisionId': 'revision-1',
        'chargeLines': [
          {'lineId': 'maintenance', 'label': 'Maintenance', 'amountMinor': 300},
          {'label': 'Malformed', 'amountMinor': 2.5},
          'not a line',
        ],
      });
      final v1 = BillModel.fromMap('legacy', {
        'status': 'paid',
        'paymentMethod': 'cash',
        'paymentReference': 'CASH-10',
        'paymentId': 'payment-1',
        'settledBy': 'admin-1',
      });

      expect(bill.chargeLines, hasLength(1));
      expect(bill.chargeLines.single.amountMinor, 300);
      expect(v1.normalizedPaymentMethod, 'Cash');
      expect(v1.paymentReference, 'CASH-10');
      expect(v1.paymentId, 'payment-1');
      expect(v1.settledBy, 'admin-1');
    });
  });

  group('BillingService V2 callable/source contracts', () {
    final source = File('lib/services/billing_service.dart').readAsStringSync();

    test('keeps V1 proof and offline callable names unchanged', () {
      expect(source, contains("collection('payments')"));
      expect(source, contains("httpsCallable('verifyPaymentProof')"));
      expect(source, contains("httpsCallable('rejectPaymentProof')"));
      expect(source, contains("httpsCallable('recordManualPayment')"));
      expect(source, contains('Future<void> recordPayment('));
    });

    test(
      'V2 proof stream queries paymentProofsV2 scoped by community and bill',
      () {
        final start = source.indexOf(
          'Stream<Map<String, dynamic>?> streamPendingV2',
        );
        final end = source.indexOf(
          'Future<Uint8List> loadPaymentReceipt',
          start,
        );
        final method = source.substring(start, end);
        expect(method, contains("collection('paymentProofsV2')"));
        expect(
          method,
          contains("where('communityId', isEqualTo: communityId)"),
        );
        expect(method, contains("where('billId', isEqualTo: billId)"));
        expect(method, contains("data['status'] == 'pending'"));
        expect(method, contains("'id': pending.first.id"));
        expect(method, isNot(contains("collection('payments')")));
      },
    );

    test(
      'V2 verify and reject call only their V2 endpoints with validation',
      () {
        expect(source, contains("httpsCallable('verifyPaymentProofV2')"));
        expect(source, contains("httpsCallable('rejectPaymentProofV2')"));
        expect(
          source,
          contains("if (id.isEmpty) throw ArgumentError.value(paymentId"),
        );
        expect(source, contains('reason.length > 1000'));
      },
    );

    test(
      'offline V2 wrapper is resident scoped and preserves caller idempotency',
      () {
        final start = source.indexOf(
          'Future<Map<String, dynamic>> recordOfflinePaymentV2',
        );
        final end = source.indexOf('// Get all bills', start);
        final method = source.substring(start, end);
        expect(method, contains("httpsCallable('recordOfflinePaymentV2')"));
        expect(method, contains("'communityId': community"));
        expect(method, contains("'residentId': resident"));
        expect(method, contains("'amountMinor': amountMinor"));
        expect(method, contains("'paymentMethod': paymentMethod"));
        expect(method, contains("'paymentReference':"));
        expect(method, contains("'idempotencyKey': idempotencyKey"));
        expect(method, isNot(contains("'billId'")));
        expect(method, contains("{'cash', 'bank_transfer', 'cheque'}"));
        expect(method, contains('amountMinor > safeIntegerMax'));
        expect(method, contains('reference.length > 200'));
      },
    );

    test('adds no client-side V2 financial ledger writes', () {
      expect(source, isNot(contains("collection('paymentTransactions')")));
      expect(source, isNot(contains("collection('paymentAllocations')")));
      expect(source, isNot(contains("collection('residentCreditEntries')")));
      expect(
        source,
        isNot(contains("collection('residentFinancialAccounts')")),
      );
      expect(source, isNot(contains("collection('paymentSettlementsV2')")));
    });
  });
}
