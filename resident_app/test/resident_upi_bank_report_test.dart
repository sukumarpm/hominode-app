import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';

void main() {
  final preparation = DirectUpiPaymentPreparation(
    billId: 'bill-one',
    communityId: 'community-one',
    residentId: 'resident-one',
    currentRevisionId: 'revision-one',
    schemaVersion: 2,
    amount: 1900,
    amountMinor: 190000,
    paymentAmountMinor: 190000,
    outstandingAmountMinor: 190000,
    vpa: 'community@upi',
    payeeName: 'Community',
    paymentUri: Uri.parse('upi://pay?pa=community%40upi'),
  );

  test('evidence-free resident report sends no receipt or bank approval fields', () async {
    Map<String, dynamic>? received;
    final service = ResidentDirectUpiService(
      scopeLoader: () async => const ResidentDirectUpiScope(
        uid: 'resident-one',
        communityId: 'community-one',
        flatId: 'flat-one',
      ),
      reportCallable: (payload) async {
        received = payload;
        return {
          'paymentId': 'proof_v2_report_one',
          'status': 'pending',
          'receiptPath': null,
        };
      },
    );
    final id = await service.reportV2Payment(
      preparation: preparation,
      idempotencyKey: 'stable-idempotency-key',
    );
    expect(id, 'proof_v2_report_one');
    expect(received, containsPair('idempotencyKey', 'stable-idempotency-key'));
    expect(received, containsPair('paymentReference', null));
    expect(received, containsPair('submittedAmountMinor', 190000));
    expect(received, isNot(contains('receiptPath')));
    expect(received, isNot(contains('receiptExtension')));
    expect(received, isNot(contains('bankCreditConfirmed')));
  });

  test('does not accept a settled or malformed response as a pending report', () async {
    final service = ResidentDirectUpiService(
      scopeLoader: () async => const ResidentDirectUpiScope(
        uid: 'resident-one',
        communityId: 'community-one',
        flatId: 'flat-one',
      ),
      reportCallable: (_) async => {
        'paymentId': 'proof_v2_report_one',
        'status': 'completed',
        'receiptPath': null,
      },
    );
    await expectLater(
      service.reportV2Payment(
        preparation: preparation,
        idempotencyKey: 'stable-key',
      ),
      throwsA(isA<ResidentDirectUpiException>()),
    );
  });

  test('rejects reporting under a different resident identity', () async {
    var called = false;
    final service = ResidentDirectUpiService(
      scopeLoader: () async => const ResidentDirectUpiScope(
        uid: 'someone-else',
        communityId: 'community-one',
        flatId: 'flat-one',
      ),
      reportCallable: (_) async {
        called = true;
        return null;
      },
    );
    await expectLater(
      service.reportV2Payment(
        preparation: preparation,
        idempotencyKey: 'stable-key',
      ),
      throwsA(isA<ResidentDirectUpiException>()),
    );
    expect(called, isFalse);
  });
}
