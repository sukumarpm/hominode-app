import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/services/billing_service.dart';

void main() {
  test('Admin can select only explicit offline payment methods', () {
    expect(offlinePaymentMethodOptions, ['Cash', 'Bank Transfer', 'Cheque']);
    expect(offlinePaymentMethodValue('Cash'), 'cash');
    expect(offlinePaymentMethodValue('Bank Transfer'), 'bank_transfer');
    expect(offlinePaymentMethodValue('Cheque'), 'cheque');
    expect(() => offlinePaymentMethodValue('UPI'), throwsArgumentError);
    expect(() => offlinePaymentMethodValue('Manual'), throwsArgumentError);
  });

  test('recordPayment requires an explicit payment method', () {
    final source = File('lib/services/billing_service.dart').readAsStringSync();
    final signatureStart = source.indexOf('Future<void> recordPayment(');
    expect(signatureStart, greaterThanOrEqualTo(0));
    final signatureEnd = source.indexOf('}) async {', signatureStart);
    expect(signatureEnd, greaterThan(signatureStart));
    final signature = source.substring(signatureStart, signatureEnd);

    expect(signature, contains('required String paymentMethod'));
    expect(signature, isNot(contains("String paymentMethod = 'manual'")));
  });

  test(
    'paid payment attribution distinguishes verification from recording',
    () {
      expect(formatSettlementAttribution('upi'), 'Verified by Admin');
      expect(formatSettlementAttribution('cash'), 'Recorded by Admin');
      expect(formatSettlementAttribution('bank_transfer'), 'Recorded by Admin');
      expect(formatSettlementAttribution('cheque'), 'Recorded by Admin');
      expect(formatSettlementAttribution('manual'), 'Recorded by Admin');
      expect(formatSettlementAttribution('external'), isNull);
    },
  );

  test(
    'BillModel retains settlement fields and normalizes payment methods',
    () {
      final paidAt = DateTime(2026, 9, 12, 10, 30);
      final bill = BillModel.fromMap('bill-1', {
        'status': 'paid',
        'paymentMethod': 'cash',
        'paymentReference': 'CASH-103',
        'paymentId': 'payment-1',
        'settledBy': 'admin-1',
        'paidAt': Timestamp.fromDate(paidAt),
      });

      expect(bill.normalizedPaymentMethod, 'Cash');
      expect(bill.paymentReference, 'CASH-103');
      expect(bill.paymentId, 'payment-1');
      expect(bill.settledBy, 'admin-1');
      expect(bill.paidAt, paidAt);
      expect(bill.toMap()['paymentMethod'], 'cash');
    },
  );

  test('legacy payment method values remain safely labeled', () {
    expect(formatPaymentMethod('upi'), 'UPI');
    expect(formatPaymentMethod('external'), 'External');
    expect(formatPaymentMethod('bank_transfer'), 'Bank Transfer');
    expect(formatPaymentMethod(null), 'Not recorded');
  });
}
