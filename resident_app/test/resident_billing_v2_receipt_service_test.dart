import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_billing_v2_receipt_service.dart';

Map<String, dynamic> _response({
  int money = 1250,
  int allocated = 1000,
  int excess = 250,
  Object? reference = 'UPI-REFERENCE-7',
  String status = 'verified',
}) => {
  'success': true,
  'schemaVersion': 1,
  'receiptId': 'HOMINODE-V2-tx-7',
  'transactionId': 'tx-7',
  'community': {
    'communityId': 'community-1',
    'name': 'Green Wave Residences',
    'address': 'Community Address',
  },
  'currency': 'INR',
  'method': 'upi',
  'paymentReference': reference,
  'receivedAt': 1785542400000,
  'moneyReceivedMinor': money,
  'confirmedAmountMinor': money,
  'claimedAmountMinor': 1200,
  'amountMismatch': money != 1200,
  'confirmation': {
    'status': status,
    'verifiedAt': 1785542401000,
    'verifiedBy': 'Community Admin',
  },
  'allocations': [
    {
      'billId': 'internal-bill-1',
      'amountMinor': allocated,
      'allocatedAt': 1785542400000,
    },
  ],
  'allocatedAmountMinor': allocated,
  'excessCreditMinor': excess,
  'reconciliation': {
    'confirmedAmountMinor': money,
    'allocatedAmountMinor': allocated,
    'excessCreditMinor': excess,
  },
  'accountingBasis': {
    'amountsAreMinorUnits': true,
    'allocationsAreFromThisPayment': true,
    'existingCreditApplicationsExcluded': true,
  },
  'snapshot': 'original_settlement',
  'laterAdjustments': {
    'reversedAllocationMinor': 100,
    'revisionCreditIssuedMinor': 100,
  },
};

void main() {
  test(
    'calls the receipt callable with the verified transaction ID only',
    () async {
      String? callableName;
      Map<String, dynamic>? payload;
      final service = ResidentBillingV2ReceiptService(
        callable: (name, request) async {
          callableName = name;
          payload = request;
          return _response();
        },
      );

      final receipt = await service.getReceipt('tx-7');

      expect(callableName, 'getResidentBillingV2Receipt');
      expect(payload, {'transactionId': 'tx-7'});
      expect(receipt.moneyReceivedMinor, 1250);
      expect(receipt.claimedAmountMinor, 1200);
      expect(receipt.paymentReference, 'UPI-REFERENCE-7');
      expect(receipt.communityName, 'Green Wave Residences');
      expect(receipt.allocations.single.amountMinor, 1000);
      expect(receipt.excessCreditMinor, 250);
      expect(receipt.reversedAllocationMinor, 100);
      expect(receipt.revisionCreditIssuedMinor, 100);
    },
  );

  test(
    'keeps missing references null and separates applied credit from received money',
    () async {
      final service = ResidentBillingV2ReceiptService(
        callable: (_, _) async => _response(reference: null),
      );
      final receipt = await service.getReceipt('tx-7');
      expect(receipt.paymentReference, isNull);
      expect(receipt.moneyReceivedMinor, 1250);
      expect(receipt.excessCreditMinor, 250);
    },
  );

  test(
    'rejects inconsistent totals and any response not marked verified',
    () async {
      for (final response in [
        _response()..['excessCreditMinor'] = 249,
        _response(status: 'pending'),
        _response()..['receiptId'] = 'invented-receipt',
      ]) {
        final service = ResidentBillingV2ReceiptService(
          callable: (_, _) async => response,
        );
        await expectLater(
          service.getReceipt('tx-7'),
          throwsA(isA<ResidentBillingV2ReceiptException>()),
        );
      }
    },
  );

  test(
    'callable authorization errors produce a safe retryable message',
    () async {
      final service = ResidentBillingV2ReceiptService(
        callable: (_, _) async =>
            throw StateError('private transaction details'),
      );
      await expectLater(
        service.getReceipt('tx-7'),
        throwsA(
          isA<ResidentBillingV2ReceiptException>().having(
            (error) => error.message,
            'safe message',
            ResidentBillingV2ReceiptService.safeErrorMessage,
          ),
        ),
      );
    },
  );
}
