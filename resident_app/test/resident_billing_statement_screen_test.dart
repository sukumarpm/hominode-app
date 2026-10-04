import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/resident_billing_statement_screen.dart';
import 'package:resident_app/src/services/resident_billing_statement_service.dart';

Map<String, dynamic> _response({
  required String period,
  int amount = 123456,
  int paid = 23456,
  int credit = 10000,
  int outstanding = 90000,
  int availableCredit = 500,
  Object? reference = 'UPI-123',
}) => {
  'success': true,
  'schemaVersion': 1,
  'communityId': 'community-1',
  'residentId': 'resident-1',
  'billingPeriod': period,
  'generatedAtMs': 1785542400000,
  'summary': {
    'billsCount': 1,
    'billedMinor': amount,
    'paidAllocationMinor': paid,
    'creditAppliedMinor': credit,
    'outstandingMinor': outstanding,
    'availableCreditMinor': availableCredit,
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
      'amountMinor': amount,
      'paidAllocationMinor': paid,
      'creditAppliedMinor': credit,
      'outstandingMinor': outstanding,
      'status': 'partially_paid',
      'dueDateKey': '2026-08-15',
      'chargeLines': [
        {
          'lineId': 'maintenance',
          'code': 'maintenance',
          'label': 'Maintenance',
          'amountMinor': amount,
        },
      ],
      'settlements': [
        if (paid > 0)
          {
            'transactionId': 'tx-1',
            'method': 'bank_transfer',
            if (reference != null) 'reference': reference,
            'receivedAt': 1785542400000,
            'netAppliedMinor': paid,
          },
      ],
    },
  ],
};

Map<String, dynamic> _emptyResponse(String period, {int availableCredit = 0}) =>
    {
      'success': true,
      'schemaVersion': 1,
      'communityId': 'community-1',
      'residentId': 'resident-1',
      'billingPeriod': period,
      'generatedAtMs': 1785542400000,
      'summary': {
        'billsCount': 0,
        'billedMinor': 0,
        'paidAllocationMinor': 0,
        'creditAppliedMinor': 0,
        'outstandingMinor': 0,
        'availableCreditMinor': availableCredit,
        'statusCounts': {
          'pending': 0,
          'partially_paid': 0,
          'paid': 0,
          'overdue': 0,
        },
      },
      'bills': <Object>[],
    };

Widget _app(ResidentBillingStatementService service) => MaterialApp(
  home: ResidentBillingStatementScreen(
    service: service,
    now: () => DateTime(2026, 8, 20),
  ),
);

void main() {
  testWidgets('loads the current local YYYY-MM and renders canonical summary', (
    tester,
  ) async {
    final periods = <String>[];
    final service = ResidentBillingStatementService(
      callable: (_, payload) async {
        periods.add(payload['billingPeriod'] as String);
        return _response(period: payload['billingPeriod'] as String);
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(periods, ['2026-08']);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('statement-selected-month')))
          .data,
      'August 2026',
    );
    expect(find.text('Total billed'), findsOneWidget);
    expect(find.text('Payments applied'), findsOneWidget);
    expect(find.text('Credit applied'), findsNWidgets(2));
    expect(find.text('Outstanding'), findsNWidgets(2));
    expect(find.text('₹1234.56'), findsNWidgets(3));
    expect(find.text('₹234.56'), findsNWidgets(3));
    expect(find.text('₹100.00'), findsNWidgets(2));
    expect(find.text('₹900.00'), findsNWidgets(2));
  });

  testWidgets('renders status counts and clearly labels account credit', (
    tester,
  ) async {
    final service = ResidentBillingStatementService(
      callable: (_, _) async => _response(period: '2026-08'),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Bill status counts'), findsOneWidget);
    expect(find.text('Partially paid'), findsOneWidget);
    expect(
      find.text('Current available credit (Account-level balance)'),
      findsOneWidget,
    );
    expect(find.text('₹5.00'), findsOneWidget);
  });

  testWidgets('renders charge lines and canonical settlement detail', (
    tester,
  ) async {
    final service = ResidentBillingStatementService(
      callable: (_, _) async => _response(period: '2026-08'),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Bank Transfer'), findsOneWidget);
    expect(find.text('Aug 1, 2026'), findsOneWidget);
    expect(find.text('Payment reference'), findsOneWidget);
    expect(find.text('UPI-123'), findsOneWidget);
    expect(find.text('Due date'), findsOneWidget);
    expect(find.text('Aug 15, 2026'), findsOneWidget);
  });

  testWidgets('does not show an absent settlement reference as recorded', (
    tester,
  ) async {
    final service = ResidentBillingStatementService(
      callable: (_, _) async => _response(period: '2026-08', reference: null),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Payment reference'), findsNothing);
    expect(find.text('Not recorded'), findsNothing);
  });

  testWidgets('month change clears old values while loading the new period', (
    tester,
  ) async {
    final nextPeriod = Completer<Object?>();
    final requested = <String>[];
    final service = ResidentBillingStatementService(
      callable: (_, payload) {
        final period = payload['billingPeriod'] as String;
        requested.add(period);
        if (period == '2026-08') return Future.value(_response(period: period));
        return nextPeriod.future;
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('₹1234.56'), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('statement-previous-month')));
    await tester.pump();
    expect(requested, ['2026-08', '2026-07']);
    expect(find.byKey(const ValueKey('statement-loading')), findsOneWidget);
    expect(find.text('₹1234.56'), findsNothing);

    nextPeriod.complete(_emptyResponse('2026-07'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('statement-selected-month')))
          .data,
      'July 2026',
    );
    expect(find.text('No bills for this period.'), findsOneWidget);
  });

  testWidgets('failed month change clears stale values and shows safe error', (
    tester,
  ) async {
    final service = ResidentBillingStatementService(
      callable: (_, payload) async {
        if (payload['billingPeriod'] == '2026-07') {
          throw StateError('private backend details');
        }
        return _response(period: payload['billingPeriod'] as String);
      },
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-previous-month')));
    await tester.pumpAndSettle();

    expect(find.text('₹1234.56'), findsNothing);
    expect(
      find.text(ResidentBillingStatementService.safeErrorMessage),
      findsOneWidget,
    );
    expect(find.textContaining('private backend'), findsNothing);
    expect(find.text('₹0.00'), findsNothing);
    expect(find.text('Total billed'), findsNothing);
  });

  testWidgets(
    'older async response cannot overwrite the latest selected month',
    (tester) async {
      final first = Completer<Object?>();
      final second = Completer<Object?>();
      var augustCalls = 0;
      final service = ResidentBillingStatementService(
        callable: (_, payload) {
          final period = payload['billingPeriod'] as String;
          if (period == '2026-08') {
            augustCalls++;
            return augustCalls == 1 ? first.future : second.future;
          }
          return Future.value(_response(period: period));
        },
      );
      await tester.pumpWidget(_app(service));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('statement-previous-month')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('statement-selected-month')),
            )
            .data,
        'July 2026',
      );
      expect(find.text('₹1234.56'), findsNWidgets(3));

      await tester.tap(find.byKey(const ValueKey('statement-next-month')));
      await tester.pump();
      expect(find.byKey(const ValueKey('statement-loading')), findsOneWidget);
      second.complete(
        _response(
          period: '2026-08',
          amount: 200000,
          paid: 0,
          credit: 0,
          outstanding: 200000,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹2000.00'), findsNWidgets(5));

      first.complete(_response(period: '2026-08'));
      await tester.pumpAndSettle();
      expect(find.text('₹2000.00'), findsNWidgets(5));
      expect(find.text('₹1234.56'), findsNothing);
    },
  );

  testWidgets('successful zero bill period and no export actions are shown', (
    tester,
  ) async {
    final service = ResidentBillingStatementService(
      callable: (_, payload) async => _emptyResponse(
        payload['billingPeriod'] as String,
        availableCredit: 500,
      ),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('No bills for this period.'), findsOneWidget);
    expect(
      find.text('Current available credit (Account-level balance)'),
      findsOneWidget,
    );
    expect(find.text('₹5.00'), findsOneWidget);
    expect(find.text('PDF'), findsNothing);
    expect(find.text('CSV'), findsNothing);
    expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
    expect(find.byIcon(Icons.download), findsNothing);
  });
}
