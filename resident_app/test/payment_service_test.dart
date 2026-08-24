import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/payment_service.dart';

void main() {
  group('MockPaymentService', () {
    final service = MockPaymentService();

    final cases = <PaymentMethod, String>{
      PaymentMethod.upi: 'MOCK-UPI-',
      PaymentMethod.card: 'MOCK-CARD-',
      PaymentMethod.netBanking: 'MOCK-NETBANK-',
    };

    for (final entry in cases.entries) {
      test('${entry.key.name} completes as a test payment', () async {
        final beforePayment = DateTime.now();
        final result = await service.processPayment(
          paymentMethod: entry.key,
          billId: 'bill-123',
        );

        expect(result.success, isTrue);
        expect(result.paymentMethod, entry.key);
        expect(result.transactionId, startsWith(entry.value));
        expect(result.paidAt.isBefore(beforePayment), isFalse);
        expect(result.message, 'Test payment completed');
        expect(service.mode, PaymentMode.mock);
      });
    }
  });
}
