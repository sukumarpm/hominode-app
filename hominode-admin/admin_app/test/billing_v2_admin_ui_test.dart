import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/billing_screen.dart';
import 'package:admin_app/services/billing_service.dart';

BillModel makeBill({
  int? schemaVersion,
  String status = 'pending',
  String currency = 'INR',
  Object? amountMinor = 250000,
  Object? paidAmountMinor = 100000,
  Object? creditAppliedMinor = 30000,
  Object? outstandingAmountMinor = 120000,
  String? currentRevisionId = 'revision-1',
  double amount = 2500,
}) => BillModel.fromMap('bill-1', {
  'schemaVersion': schemaVersion,
  'currency': currency,
  'amountMinor': amountMinor,
  'paidAmountMinor': paidAmountMinor,
  'creditAppliedMinor': creditAppliedMinor,
  'outstandingAmountMinor': outstandingAmountMinor,
  'currentRevisionId': currentRevisionId,
  'status': status,
  'amount': amount,
});

void main() {
  group('Admin billing list routing', () {
    test('keeps V1 pending/overdue current and paid in history', () {
      final pending = makeBill(status: 'pending');
      final overdue = makeBill(status: 'overdue');
      final paid = makeBill(status: 'paid');
      final legacySettled = makeBill(status: 'settled');

      expect(pending.isV2, isFalse);
      expect(isAdminBillingCurrentBill(pending), isTrue);
      expect(isAdminBillingCurrentBill(overdue), isTrue);
      expect(isAdminBillingHistoryBill(paid), isTrue);
      expect(isAdminBillingCurrentBill(paid), isFalse);
      expect(isAdminBillingHistoryBill(legacySettled), isFalse);
      expect(isAdminBillingCurrentBill(legacySettled), isFalse);
    });

    test('routes partially paid V2 liabilities to current billing', () {
      final bill = makeBill(schemaVersion: 2, status: 'partially_paid');
      expect(bill.isCurrentV2Liability, isTrue);
      expect(isAdminBillingCurrentBill(bill), isTrue);
      expect(isAdminBillingHistoryBill(bill), isFalse);
    });

    test('routes zero outstanding V2 projection to history', () {
      final bill = makeBill(
        schemaVersion: 2,
        status: 'partially_paid',
        paidAmountMinor: 250000,
        creditAppliedMinor: 0,
        outstandingAmountMinor: 0,
      );
      expect(bill.isSettledV2, isTrue);
      expect(isAdminBillingHistoryBill(bill), isTrue);
      expect(isAdminBillingCurrentBill(bill), isFalse);
    });

    test(
      'keeps malformed and non-INR V2 records visible in safe current state',
      () {
        for (final bill in [
          makeBill(schemaVersion: 2, currency: 'USD'),
          makeBill(schemaVersion: 2, amountMinor: 2500.5),
        ]) {
          expect(bill.hasValidInrV2Financials, isFalse);
          expect(isAdminBillingCurrentBill(bill), isTrue);
          expect(isAdminBillingHistoryBill(bill), isFalse);
          expect(bill.formatV2MinorAmount(bill.amountMinor), 'Unavailable');
        }
      },
    );
  });

  group('Admin V2 proof UI source contracts', () {
    final source = File('lib/billing_screen.dart').readAsStringSync();

    test('uses distinct V1/V2 proof stream and cache keys', () {
      final start = source.indexOf(
        'Stream<Map<String, dynamic>?> _paymentProofStreamForBill',
      );
      final end = source.indexOf('@override', start);
      final method = source.substring(start, end);
      expect(method, contains("bill.isV2 ? 'v2' : 'v1'"));
      expect(method, contains('streamPendingV2PaymentProofForBill'));
      expect(method, contains('streamPendingPaymentForBill'));
    });

    test(
      'shows V2 proof submitted amount/reference and preserves V1 reference',
      () {
        final start = source.indexOf('Widget _buildPaymentProofActions(');
        final end = source.indexOf(
          'Future<void> _onVerifyPaymentProof(',
          start,
        );
        final method = source.substring(start, end);
        expect(method, contains("payment['submittedAmountMinor']"));
        expect(method, contains("payment['paymentReference']"));
        expect(method, contains("payment['transactionId']"));
        expect(method, contains('Submitted amount:'));
        expect(method, contains('View Receipt'));
        expect(method, contains('!receiptViewed'));
      },
    );

    test('routes verify and reject actions by exact bill version', () {
      final verifyStart = source.indexOf('Future<void> _onVerifyPaymentProof(');
      final verifyEnd = source.indexOf('// ACTION HANDLERS', verifyStart);
      final verifyMethod = source.substring(verifyStart, verifyEnd);
      expect(verifyMethod, contains('if (bill.isV2)'));
      expect(verifyMethod, contains('verifyPaymentProofV2(paymentId)'));
      expect(verifyMethod, contains('verifyPaymentProof(paymentId)'));
      expect(verifyMethod, contains("payment['submittedAmountMinor']"));
      expect(verifyMethod, contains('Verify this submitted payment of'));

      final rejectStart = source.indexOf('Future<void> _onRejectPaymentProof(');
      final rejectEnd = source.indexOf(
        'Widget _buildNormalPendingBillActions(',
        rejectStart,
      );
      final rejectMethod = source.substring(rejectStart, rejectEnd);
      expect(rejectMethod, contains('rejectPaymentProofV2('));
      expect(rejectMethod, contains('rejectPaymentProof('));
      expect(rejectMethod, contains('text.isEmpty'));
    });

    test('keeps no-proof V2 action away from V1 offline payment writer', () {
      final normalStart = source.indexOf(
        'Widget _buildNormalPendingBillActions(',
      );
      final normalEnd = source.indexOf(
        'Widget _buildPaymentProofActions(',
        normalStart,
      );
      final normalMethod = source.substring(normalStart, normalEnd);
      final v2BranchStart = normalMethod.indexOf('if (bill.isV2)');
      final v2BranchReturn = normalMethod.indexOf(
        'return Column(',
        v2BranchStart,
      );
      final v1RecordAction = normalMethod.indexOf('_onRecordPayment(bill)');
      expect(v2BranchStart, greaterThanOrEqualTo(0));
      expect(v2BranchReturn, lessThan(v1RecordAction));
      expect(
        normalMethod,
        contains(
          'Offline payment recording available in the next Billing V2 step',
        ),
      );
      expect(normalMethod, contains("label: const Text('Record Payment')"));

      final actionStart = source.indexOf('Widget _buildActionButtons(');
      final actionEnd = source.indexOf(
        'Widget _buildPaymentHistory(',
        actionStart,
      );
      final actionMethod = source.substring(actionStart, actionEnd);
      expect(actionMethod, contains('!bill.hasValidInrV2Financials'));
      expect(actionMethod, contains('bill.isSettledV2'));
      expect(actionMethod, contains('_paymentProofStreamForBill(bill)'));
      expect(source, contains('if (bill.isV2) return;'));
    });

    test(
      'renders V2 totals from minor units while retaining V1 decimal amount',
      () {
        final summaryStart = source.indexOf('Widget _buildV2BillFinancials(');
        final summaryEnd = source.indexOf(
          'Widget _buildBillCard(',
          summaryStart,
        );
        final summary = source.substring(summaryStart, summaryEnd);
        for (final label in [
          'Total',
          'Paid',
          'Credit applied',
          'Outstanding',
        ]) {
          expect(summary, contains("('$label', bill."));
        }
        expect(summary, contains('formatV2MinorAmount'));
        expect(source, contains('bill.amount.toStringAsFixed(0)'));
        expect(source, contains('_v2TableAmountLabel(bill)'));
        expect(source, contains('maxLines: bill.isV2 ? 4 : 1'));
      },
    );

    test(
      'performs no direct V2 financial collection writes in the Billing UI',
      () {
        for (final name in [
          'paymentTransactions',
          'paymentAllocations',
          'residentCreditEntries',
          'residentFinancialAccounts',
          'paymentSettlementsV2',
        ]) {
          expect(source, isNot(contains("collection('$name')")));
        }
      },
    );

    test('keeps legacy KPI and export calculations V1-only', () {
      expect(source, contains('bills.where((bill) => !bill.isV2).toList()'));
      expect(source, contains('allBills.where((bill) => !bill.isV2).toList()'));
    });
  });
}
