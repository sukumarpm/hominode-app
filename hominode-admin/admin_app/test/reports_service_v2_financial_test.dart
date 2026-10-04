import 'dart:io';

import 'package:admin_app/services/reports_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportsService Billing V2 financial summary', () {
    test('maps callable response and preserves canonical V2 values', () async {
      Map<String, dynamic>? capturedPayload;
      final service = ReportsService(
        firestore: FakeFirebaseFirestore(),
        currentAdminIdProvider: () => 'admin-1',
        currentCommunityIdProvider: () => 'community-1',
        financialReportCallable: (payload) async {
          capturedPayload = payload;
          return {
            'success': true,
            'schemaVersion': 1,
            'communityId': 'community-1',
            'billingPeriod': '2030-01',
            'generatedAtMs': 1000,
            'liabilitySummary': {
              'billsCount': 12,
              'billedMinor': 450000,
              'paidAllocationMinor': 280000,
              'creditAppliedMinor': 10000,
              'outstandingMinor': 160000,
              'overdueOutstandingMinor': 60000,
              'statusCounts': {
                'pending': 4,
                'partially_paid': 3,
                'paid': 3,
                'overdue': 2,
              },
            },
            'collectionActivity': {
              'transactionCount': 11,
              'totalReceivedMinor': 300000,
              'methods': {
                'upi': {'count': 5, 'totalMinor': 170000},
                'cash': {'count': 3, 'totalMinor': 70000},
                'bank_transfer': {'count': 2, 'totalMinor': 50000},
                'cheque': {'count': 1, 'totalMinor': 10000},
              },
            },
            'creditPosition': {
              'accountsCount': 8,
              'residentsWithCreditCount': 2,
              'totalAvailableCreditMinor': 25000,
            },
          };
        },
      );

      final summary = await service.getFinancialSummary(year: 2030, month: 1);

      expect(capturedPayload, {
        'communityId': 'community-1',
        'billingPeriod': '2030-01',
      });

      expect(summary.totalBills, 12);
      expect(summary.pendingBills, 4);
      expect(summary.partiallyPaidBills, 3);
      expect(summary.paidBills, 3);
      expect(summary.overdueBills, 2);

      expect(summary.totalBilledMinor, 450000);
      expect(summary.collectionsReceivedMinor, 300000);
      expect(summary.outstandingMinor, 160000);
      expect(summary.overdueOutstandingMinor, 60000);
      expect(summary.availableCreditMinor, 25000);
      expect(summary.creditAppliedMinor, 10000);

      expect(summary.formattedTotalBilled, '₹4,500.00');
      expect(summary.formattedCollectionsReceived, '₹3,000.00');
      expect(summary.formattedOutstanding, '₹1,600.00');
      expect(summary.formattedOverdueOutstanding, '₹600.00');
      expect(summary.formattedAvailableCredit, '₹250.00');

      expect(summary.upiCollection.count, 5);
      expect(summary.upiCollection.totalMinor, 170000);
      expect(summary.cashCollection.count, 3);
      expect(summary.bankTransferCollection.totalMinor, 50000);
      expect(summary.chequeCollection.totalMinor, 10000);
    });

    test('formats INR minor units safely', () {
      expect(formatInrMinorUnitsForReports(0), '₹0.00');
      expect(formatInrMinorUnitsForReports(1), '₹0.01');
      expect(formatInrMinorUnitsForReports(123456789), '₹12,34,567.89');
      expect(formatInrMinorUnitsForReports(-1), 'Unavailable');
    });

    test('surfaces backend errors safely without silent fallback', () async {
      final service = ReportsService(
        firestore: FakeFirebaseFirestore(),
        currentAdminIdProvider: () => 'admin-1',
        currentCommunityIdProvider: () => 'community-1',
        financialReportCallable: (_) async {
          throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'billing_v2_financial_report_financial_history_limit',
          );
        },
      );

      await expectLater(
        service.getFinancialSummary(year: 2030, month: 1),
        throwsA(
          isA<ReportsServiceException>().having(
            (e) => e.userMessage,
            'userMessage',
            'Financial report is unavailable right now. Please try again shortly.',
          ),
        ),
      );
    });

    test('uses callable V2 authority and does not retain legacy paid-status path', () {
      final source = File('lib/services/reports_service.dart').readAsStringSync();
      final start = source.indexOf('Future<FinancialSummary> getFinancialSummary');
      final end = source.indexOf('Future<List<MonthlyRevenue>> getMonthlyRevenueTrends', start);
      final method = source.substring(start, end);

      expect(method, contains('_callBillingV2FinancialReport({'));
      expect(method, isNot(contains("collection('bills')")));
      expect(method, isNot(contains("status == 'paid'")));
      expect(method, isNot(contains('totalAmount')));
    });
  });
}
