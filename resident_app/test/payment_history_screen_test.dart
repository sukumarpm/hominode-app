import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/payment_history_screen.dart';
import 'package:resident_app/receipt_screen.dart';
import 'package:resident_app/src/utils/payment_method.dart';

void main() {
  testWidgets('shows real paid bill fields newest first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentHistoryScreen(
          paidBills: [
            {
              'id': 'bill-older',
              'month': 'June',
              'year': '2026',
              'amount': 1200,
              'status': 'paid',
              'paidAt': Timestamp.fromDate(DateTime(2026, 6, 2)),
              'paymentMethod': 'cash',
              'paymentReference': 'CASH-001',
            },
            {
              'id': 'bill-newer',
              'month': 'July',
              'year': '2026',
              'amount': 1500.5,
              'status': 'paid',
              'paidAt': Timestamp.fromDate(DateTime(2026, 7, 3)),
              'paymentReference': 'ADMIN-RECEIPT-123',
              'transactionId': 'PAY-123',
              'paymentMethod': 'upi',
            },
          ],
        ),
      ),
    );

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('₹1500.50'), findsOneWidget);
    expect(find.text('Jul 3, 2026'), findsOneWidget);
    expect(find.text('bill-newer'), findsOneWidget);
    expect(find.text('Paid'), findsNWidgets(2));
    expect(find.text('ADMIN-RECEIPT-123'), findsOneWidget);
    expect(find.text('PAY-123'), findsNothing);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('CASH-001'), findsOneWidget);

    final newer = tester.getTopLeft(find.text('July 2026')).dy;
    final older = tester.getTopLeft(find.text('June 2026')).dy;
    expect(newer, lessThan(older));
  });

  test('normalizes payment methods consistently for history and receipts', () {
    expect(normalizePaymentMethod('cash'), 'Cash');
    expect(normalizePaymentMethod('upi'), 'UPI');
    expect(normalizePaymentMethod('bank_transfer'), 'Bank Transfer');
    expect(normalizePaymentMethod('cheque'), 'Cheque');
    expect(normalizePaymentMethod('manual'), 'Manual');
    expect(normalizePaymentMethod('external'), 'External');
    expect(normalizePaymentProvider('direct_upi'), 'Direct UPI');

    expect(Receipt.fromBill({'paymentMethod': 'cash'}).paymentMethod, 'Cash');
    expect(Receipt.fromBill({'paymentMethod': 'upi'}).paymentMethod, 'UPI');
    expect(
      Receipt.fromBill({'paymentMethod': 'bank_transfer'}).paymentMethod,
      'Bank Transfer',
    );
  });

  testWidgets('does not invent a missing payment reference', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentHistoryScreen(
          paidBills: [
            {'id': 'bill-without-transaction', 'amount': 900, 'status': 'paid'},
          ],
        ),
      ),
    );

    expect(find.text('Payment reference'), findsNothing);
    expect(find.text('Not recorded'), findsNWidgets(2));
  });
}
