import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
        contains("label: const Text('Record Offline Payment')"),
      );
      expect(normalMethod, contains('_onRecordOfflinePayment(bill)'));
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

  group('Admin V2 offline payment input and recovery', () {
    final source = File('lib/billing_screen.dart').readAsStringSync();

    test('parses rupees into integer minor units without floating point', () {
      expect(parseInrRupeesToMinorUnits('1200'), 120000);
      expect(parseInrRupeesToMinorUnits('1200.5'), 120050);
      expect(parseInrRupeesToMinorUnits('1200.50'), 120050);
      expect(parseInrRupeesToMinorUnits('0.01'), 1);
    });

    test(
      'rejects zero, negative, malformed, overprecision and unsafe amounts',
      () {
        for (final input in [
          '0',
          '0.00',
          '-1',
          '1.001',
          '1.',
          '.50',
          '1,200.00',
          'not money',
          '90071992547409.92',
        ]) {
          expect(parseInrRupeesToMinorUnits(input), isNull, reason: input);
        }
        expect(
          parseInrRupeesToMinorUnits('90071992547409.91'),
          9007199254740991,
        );
      },
    );

    test(
      'creates backend-safe keys and round-trips the exact saved request',
      () {
        final key = createOfflinePaymentIdempotencyKey(
          now: DateTime.fromMicrosecondsSinceEpoch(123456789),
          random: Random(7),
        );
        expect(RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(key), isTrue);
        final attempt = OfflinePaymentAttempt(
          communityId: 'community-1',
          residentId: 'resident-1',
          amountMinor: 120050,
          paymentMethod: 'bank_transfer',
          paymentReference: 'REF-1',
          idempotencyKey: key,
        );
        final restored = OfflinePaymentAttempt.tryParse(
          jsonEncode(attempt.toJson()),
        );
        expect(restored?.toJson(), attempt.toJson());
      },
    );

    test(
      'dialog explains resident-account allocation and limits methods/reference',
      () {
        final start = source.indexOf(
          'Future<_OfflinePaymentInput?> _showOfflinePaymentEntryDialog(',
        );
        final end = source.indexOf(
          'Future<bool?> _confirmRetryOfflinePayment(',
          start,
        );
        final method = source.substring(start, end);
        expect(method, contains('Payment received for the resident account'));
        expect(method, contains('Selected bill outstanding (context only)'));
        expect(method, contains('oldest eligible '));
        expect(method, contains('outstanding bills first.'));
        expect(method, contains('Any excess becomes resident credit'));
        expect(method, contains("value: 'cash'"));
        expect(method, contains("value: 'bank_transfer'"));
        expect(method, contains("value: 'cheque'"));
        expect(method, contains('maxLength: 200'));
      },
    );

    test('eligible V2 action is guarded and V1 writer cannot receive V2', () {
      final start = source.indexOf('Widget _buildNormalPendingBillActions(');
      final end = source.indexOf('Widget _buildPaymentProofActions(', start);
      final method = source.substring(start, end);
      expect(method, contains('!bill.hasValidInrV2Financials'));
      expect(method, contains('!bill.isCurrentV2Liability'));
      expect(method, contains("label: const Text('Record Offline Payment')"));
      expect(source, contains('if (bill.isV2) return;'));
    });

    test(
      'persists new request before calling service and checks existing attempt first',
      () {
        final start = source.indexOf('Future<void> _onRecordOfflinePayment(');
        final end = source.indexOf(
          'Future<_OfflinePaymentInput?> _showOfflinePaymentEntryDialog(',
          start,
        );
        final method = source.substring(start, end);
        expect(
          method,
          contains("final saved = preferences.getString(preferenceKey)"),
        );
        expect(method, contains('if (saved != null)'));
        expect(
          method,
          contains('_confirmRetryOfflinePayment(existingAttempt)'),
        );
        final savedAttemptBranch = method.substring(
          method.indexOf('if (saved != null)'),
          method.indexOf('final input = await _showOfflinePaymentEntryDialog'),
        );
        expect(
          savedAttemptBranch,
          contains('return;'),
          reason: 'Closing recovery must not fall through to a fresh attempt.',
        );
        expect(savedAttemptBranch, isNot(contains('preferences.remove')));
        expect(savedAttemptBranch, isNot(contains('preferences.clear')));
        final persist = method.indexOf('preferences.setString(');
        final freshSubmit = method.indexOf(
          '_submitOfflinePaymentAttempt(attempt, preferences, preferenceKey)',
        );
        expect(persist, greaterThanOrEqualTo(0));
        expect(freshSubmit, greaterThan(persist));
        expect(method, contains('createOfflinePaymentIdempotencyKey()'));

        final entryStart = source.indexOf(
          'Future<_OfflinePaymentInput?> _showOfflinePaymentEntryDialog(',
        );
        final entryEnd = source.indexOf(
          'Future<bool?> _confirmRetryOfflinePayment(',
          entryStart,
        );
        final entryDialog = source.substring(entryStart, entryEnd);
        expect(entryDialog, contains("child: const Text('Cancel')"));
        expect(entryDialog, contains('Navigator.of(dialogContext).pop()'));
        expect(
          method.indexOf('if (input == null) return;'),
          lessThan(method.indexOf('final attempt = OfflinePaymentAttempt(')),
        );
        expect(
          method.indexOf('if (input == null) return;'),
          lessThan(method.indexOf('createOfflinePaymentIdempotencyKey()')),
        );
      },
    );

    test('unresolved attempt can only be closed or retried exactly', () {
      final start = source.indexOf(
        'Future<bool?> _confirmRetryOfflinePayment(',
      );
      final end = source.indexOf(
        'Future<void> _showOfflineAttemptStorageError(',
        start,
      );
      final method = source.substring(start, end);
      expect(method, contains("child: const Text('Close')"));
      expect(method, contains("child: const Text('Retry Saved Payment')"));
      expect(method, isNot(contains("Text('Cancel')")));
      expect(method, isNot(contains('preferences.remove')));
      expect(method, isNot(contains('preferences.clear')));
      expect(method, isNot(contains('discard')));
      expect(method, isNot(contains('forget')));
    });

    test(
      'retries submit only stored terms and leave ambiguous requests saved',
      () {
        final start = source.indexOf(
          'Future<void> _submitOfflinePaymentAttempt(',
        );
        final end = source.indexOf(
          'Future<void> _showOfflinePaymentResult(',
          start,
        );
        final method = source.substring(start, end);
        for (final field in [
          'communityId: attempt.communityId',
          'residentId: attempt.residentId',
          'amountMinor: attempt.amountMinor',
          'paymentMethod: attempt.paymentMethod',
          'paymentReference: attempt.paymentReference',
          'idempotencyKey: attempt.idempotencyKey',
        ]) {
          expect(method, contains(field));
        }
        expect(method, isNot(contains('billId:')));
        expect(method, contains("if (result['success'] != true)"));
        final failureGuard = method.indexOf("if (result['success'] != true)");
        final clearAttempt = method.indexOf('preferences.remove(preferenceKey)');
        expect(clearAttempt, greaterThan(failureGuard));
        expect(
          clearAttempt,
          lessThan(method.indexOf('_showOfflinePaymentResult(attempt, result)')),
        );
        expect(method, contains('Payment Result Unresolved'));
        expect(method, contains('attempt is saved and will not be replaced'));
        expect(method, contains('if (retry != true) return;'));
      },
    );

    test(
      'clears saved recovery state only after the service validates the result',
      () {
        final service = File(
          'lib/services/billing_service.dart',
        ).readAsStringSync();
        final serviceStart = service.indexOf(
          'Future<Map<String, dynamic>> recordOfflinePaymentV2',
        );
        final serviceEnd = service.indexOf('// Get all bills', serviceStart);
        final serviceMethod = service.substring(serviceStart, serviceEnd);
        expect(serviceMethod, contains('validateOfflinePaymentResultV2('));

        final start = source.indexOf(
          'Future<void> _submitOfflinePaymentAttempt(',
        );
        final end = source.indexOf(
          'Future<void> _showOfflinePaymentResult(',
          start,
        );
        final method = source.substring(start, end);
        expect(
          method.indexOf('_billingService.recordOfflinePaymentV2('),
          lessThan(method.indexOf('preferences.remove(preferenceKey)')),
        );
        final catchStart = method.indexOf('} catch (error) {');
        final catchBlock = method.substring(catchStart);
        expect(catchBlock, isNot(contains('preferences.remove')));
        expect(catchBlock, isNot(contains('preferences.clear')));
      },
    );

    test('successful and already-completed responses clear the saved attempt', () {
      final start = source.indexOf(
        'Future<void> _submitOfflinePaymentAttempt(',
      );
      final end = source.indexOf(
        'Future<void> _showOfflinePaymentResult(',
        start,
      );
      final method = source.substring(start, end);
      expect(method, contains("if (result['success'] != true)"));
      expect(method, contains('await preferences.remove(preferenceKey)'));
      expect(method, contains('_showOfflinePaymentResult(attempt, result)'));
      expect(
        method.indexOf("if (result['success'] != true)"),
        lessThan(method.indexOf('await preferences.remove(preferenceKey)')),
      );
      expect(
        method.indexOf('await preferences.remove(preferenceKey)'),
        lessThan(method.indexOf('_showOfflinePaymentResult(attempt, result)')),
      );
      expect(method, isNot(contains("result['alreadyCompleted']")));
    });

    test(
      'reports recovery, allocations, and excess credit without claiming bill settlement',
      () {
        final start = source.indexOf('Future<void> _showOfflinePaymentResult(');
        final end = source.indexOf('Future<void> _onRecordPayment(', start);
        final method = source.substring(start, end);
        expect(method, contains("result['alreadyCompleted'] == true"));
        expect(
          method,
          contains(
            'Payment already recorded. The previous request was recovered safely.',
          ),
        );
        expect(method, contains("result['transactionId']"));
        expect(method, contains("result['allocations']"));
        expect(method, contains("result['excessCreditMinor']"));
        expect(method, contains('Excess resident credit:'));
        expect(method, isNot(contains('Selected bill settled')));
      },
    );

    test('keeps V2 proof review and financial writes isolated', () {
      expect(source, contains('streamPendingV2PaymentProofForBill'));
      expect(source, contains('View Receipt First'));
      expect(source, contains('verifyPaymentProofV2(paymentId)'));
      expect(source, contains('rejectPaymentProofV2('));
      for (final collection in [
        'paymentTransactions',
        'paymentAllocations',
        'residentCreditEntries',
        'residentFinancialAccounts',
        'paymentSettlementsV2',
      ]) {
        expect(source, isNot(contains("collection('$collection')")));
      }
    });
  });
}
