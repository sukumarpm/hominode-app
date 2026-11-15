import 'dart:async';
import 'dart:io';

import 'package:admin_app/billing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  final source = File('lib/billing_screen.dart').readAsStringSync();

  test('cash payment dialog waits for backend success before closing', () {
    final start = source.indexOf('Widget _buildConfirmPaymentDialog(');
    final end = source.indexOf('Widget _buildDialogDetailRow(', start);
    final dialog = source.substring(start, end);

    expect(dialog, contains('onSubmit: () => _billingService.recordPayment('));
    expect(source, contains('await widget.onSubmit();'));
    expect(source, contains('Navigator.of(context).pop(true)'));
  });

  test('cash submission locks repeated taps while request is pending', () {
    final start = source.indexOf('class PaymentSubmissionActions');
    final end = source.indexOf('Stream<T> withInitialLoadTimeout', start);
    final actions = source.substring(start, end);
    expect(actions, contains('bool _saving = false;'));
    expect(actions, contains('if (_saving) return;'));
    expect(actions, contains('onPressed: _saving ? null : _submit'));
    expect(actions, contains('_saving = true;'));
    expect(actions, contains('_saving = false;'));
  });

  test('Bills tab handles timeout, retry, refresh and empty state', () {
    expect(source, contains('withInitialLoadTimeout('));
    expect(source, contains('_billingService.getBills(_billsCommunityId)'));
    expect(source, contains("'No bills yet.'"));
    expect(source, contains("'No payment history yet.'"));
    expect(source, contains('onRefresh: _refreshBills'));
    expect(source, contains("'Unable to load bills.'"));
    expect(source, contains("label: const Text('Retry')"));
  });

  test('payment proof lookup timeout exposes a safe retry state', () {
    final start = source.indexOf('Widget _buildActionButtons(BillModel bill)');
    final end = source.indexOf('Widget _buildPaymentHistory(', start);
    final actions = source.substring(start, end);
    expect(actions, contains('Payment status could not be checked.'));
    expect(actions, contains('_retryPaymentProofLookup(bill)'));
    expect(actions, contains('_buildNormalPendingBillActions(bill)'));
  });

  testWidgets('payment success closes the confirmation dialog', (tester) async {
    var calls = 0;
    await _showActions(
      tester,
      onSubmit: () async {
        calls++;
      },
    );
    await tester.tap(find.text('Confirm Cash Received'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Confirm Cash Received'), findsNothing);
    expect(find.text('Open payment dialog'), findsOneWidget);
  });

  testWidgets('failure stays open and retry succeeds with inputs intact', (
    tester,
  ) async {
    var calls = 0;
    final reference = TextEditingController(text: 'receipt-42');
    await _showActions(
      tester,
      reference: reference,
      onSubmit: () async {
        calls++;
        if (calls == 1) throw StateError('network failure');
      },
    );
    await tester.tap(find.text('Confirm Cash Received'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cash-payment-save-error')),
      findsOneWidget,
    );
    expect(find.text('Confirm Cash Received'), findsOneWidget);
    expect(reference.text, 'receipt-42');
    await tester.tap(find.text('Confirm Cash Received'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Open payment dialog'), findsOneWidget);
  });

  testWidgets('pending submission ignores repeated taps', (tester) async {
    final request = Completer<void>();
    var calls = 0;
    await _showActions(
      tester,
      onSubmit: () {
        calls++;
        return request.future;
      },
    );
    await tester.tap(find.text('Confirm Cash Received'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    request.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open payment dialog'), findsOneWidget);
  });

  test('Bills stream delivers success data', () async {
    await expectLater(withInitialLoadTimeout(Stream<int>.value(3)), emits(3));
  });

  test(
    'Bills stream turns a stalled initial load into a retryable error',
    () async {
      final source = StreamController<int>();
      final expectation = expectLater(
        withInitialLoadTimeout(
          source.stream,
          timeout: const Duration(milliseconds: 1),
        ),
        emitsError(isA<TimeoutException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await expectation;
      await source.close();
    },
  );
}

Future<void> _showActions(
  WidgetTester tester, {
  required Future<void> Function() onSubmit,
  TextEditingController? reference,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: reference),
                      PaymentSubmissionActions(
                        label: 'Confirm Cash Received',
                        onSubmit: onSubmit,
                        onCancel: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Open payment dialog'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open payment dialog'));
  await tester.pumpAndSettle();
}
