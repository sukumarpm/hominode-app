enum PaymentMode { mock, real }

enum PaymentMethod { upi, card, netBanking }

class PaymentResult {
  final bool success;
  final String? transactionId;
  final PaymentMethod paymentMethod;
  final DateTime paidAt;
  final String message;

  const PaymentResult({
    required this.success,
    required this.transactionId,
    required this.paymentMethod,
    required this.paidAt,
    required this.message,
  });
}

abstract interface class PaymentService {
  PaymentMode get mode;

  Future<PaymentResult> processPayment({
    required PaymentMethod paymentMethod,
    required String billId,
  });
}

abstract final class PaymentConfig {
  // TODO: Change this mode and inject a real PaymentService implementation when
  // a payment gateway is introduced.
  static const PaymentMode mode = PaymentMode.mock;
}

abstract final class PaymentServiceFactory {
  static PaymentService create({PaymentMode mode = PaymentConfig.mode}) {
    switch (mode) {
      case PaymentMode.mock:
        return MockPaymentService();
      case PaymentMode.real:
        throw UnsupportedError('Real payment provider is not configured.');
    }
  }
}

class MockPaymentService implements PaymentService {
  @override
  PaymentMode get mode => PaymentMode.mock;

  @override
  Future<PaymentResult> processPayment({
    required PaymentMethod paymentMethod,
    required String billId,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    final paidAt = DateTime.now();
    final transactionPrefix = switch (paymentMethod) {
      PaymentMethod.upi => 'MOCK-UPI',
      PaymentMethod.card => 'MOCK-CARD',
      PaymentMethod.netBanking => 'MOCK-NETBANK',
    };

    return PaymentResult(
      success: true,
      transactionId: '$transactionPrefix-${paidAt.millisecondsSinceEpoch}',
      paymentMethod: paymentMethod,
      paidAt: paidAt,
      message: 'Test payment completed',
    );
  }
}
