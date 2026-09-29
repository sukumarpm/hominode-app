import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';

const _scope = ResidentDirectUpiScope(
  uid: 'resident',
  communityId: 'community',
  flatId: 'flat',
);
Map<String, dynamic> _bill() => {
  'schemaVersion': 2,
  'communityId': 'community',
  'residentId': 'resident',
  'flatId': 'flat',
  'currency': 'INR', 'amountMinor': 100000, 'outstandingAmountMinor': 100000,
  'currentRevisionId': 'revision_1', 'status': 'pending',
  // Compatibility amounts are deliberately different and must be ignored.
  'amount': 9999, 'paidAmount': 555,
};
Map<String, dynamic> _pending() => {
  'communityId': 'community',
  'residentId': 'resident',
  'billId': 'bill',
  'status': 'pending',
};
Matcher _failure(ResidentDirectUpiFailure value) => throwsA(
  isA<ResidentDirectUpiException>().having((e) => e.failure, 'failure', value),
);

class _Fixture {
  Map<String, dynamic> bill = _bill();
  ResidentDirectUpiScope scope = _scope;
  Map<String, dynamic> config = {
    'communityId': 'community',
    'version': 1,
    'directUpi': {
      'enabled': true,
      'vpa': 'community@upi',
      'payeeName': 'Community',
    },
    'updatedBy': 'admin',
    'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1780000000000),
  };
  List<Map<String, dynamic>> proofs = [];
  final proofQueries = <Map<String, dynamic>>[];
  final calls = <Map<String, dynamic>>[];
  final uploads = <Map<String, dynamic>>[];
  Map<String, dynamic>? response;
  Object? callableError;
  bool uploadFails = false;
  bool proofReadFails = false;
  int v1Reads = 0;
  int v2Reads = 0;
  Completer<void>? uploadGate;
  late final service = ResidentDirectUpiService(
    scopeLoader: () async => scope,
    billLoader: (_) async =>
        ResidentDirectUpiDocument(exists: true, data: bill),
    paymentConfigLoader: (_) async =>
        ResidentDirectUpiDocument(exists: true, data: config),
    paymentProofLoader:
        ({
          required communityId,
          required flatId,
          required billId,
          required userId,
        }) async {
          v1Reads++;
          return [];
        },
    v2ProofLoader:
        ({required communityId, required billId, required residentId}) async {
          v2Reads++;
          proofQueries.add({
            'communityId': communityId,
            'billId': billId,
            'residentId': residentId,
          });
          if (proofReadFails) throw StateError('offline');
          return proofs;
        },
    prepareProof: (payload) async {
      calls.add(Map.of(payload));
      if (callableError != null) throw callableError!;
      return response ??
          {
            'paymentId': 'server-proof',
            'receiptPath':
                'payment_receipts/community/bill/resident/server-proof.${payload['receiptExtension']}',
            'status': 'pending',
          };
    },
    receiptUploader:
        ({
          required receiptPath,
          required bytes,
          required contentType,
          required customMetadata,
        }) async {
          uploads.add({
            'receiptPath': receiptPath,
            'bytes': bytes.toList(),
            'contentType': contentType,
            'metadata': customMetadata,
          });
          if (uploadGate != null) await uploadGate!.future;
          if (uploadFails) throw StateError('private URL and raw SDK error');
        },
  );
  Future<ResidentV2ProofSubmissionAttempt> attempt({
    String extension = 'jpg',
    String? reference,
  }) async => service.createV2ProofSubmissionAttempt(
    preparation: await service.preparePayment('bill'),
    receiptBytes: Uint8List.fromList([1, 2, 3]),
    receiptExtension: extension,
    paymentReference: reference,
  );
}

void main() {
  test(
    'V2 full outstanding uses minor units, identity and current config',
    () async {
      final f = _Fixture();
      final p = await f.service.preparePayment('bill');
      expect(p.isV2, true);
      expect(p.residentId, 'resident');
      expect(p.amountMinor, 100000);
      expect(p.outstandingAmountMinor, 100000);
      expect(p.currentRevisionId, 'revision_1');
      expect(p.amount, 1000);
      expect(p.paymentUri.queryParameters, {
        'pa': 'community@upi',
        'pn': 'Community',
        'am': '1000.00',
        'cu': 'INR',
      });
      expect(f.v1Reads, 0);
      expect(f.proofQueries, [
        {
          'communityId': 'community',
          'billId': 'bill',
          'residentId': 'resident',
        },
      ]);
    },
  );
  for (final status in ['pending', 'overdue', 'partially_paid']) {
    test('V2 $status pays only the partial outstanding', () async {
      final f = _Fixture()
        ..bill.addAll({'status': status, 'outstandingAmountMinor': 12345});
      final p = await f.service.preparePayment('bill');
      expect(p.amount, 123.45);
      expect(p.paymentUri.queryParameters['am'], '123.45');
      expect(p.amountMinor, 100000);
      expect(p.outstandingAmountMinor, 12345);
    });
  }
  test(
    'paise formatting stays exact for one paisa and maximum safe integer',
    () async {
      for (final pair in [
        (1, '0.01'),
        (29, '0.29'),
        (9007199254740991, '90071992547409.91'),
      ]) {
        final f = _Fixture()
          ..bill.addAll({
            'amountMinor': pair.$1,
            'outstandingAmountMinor': pair.$1,
          });
        expect(
          (await f.service.preparePayment(
            'bill',
          )).paymentUri.queryParameters['am'],
          pair.$2,
        );
      }
    },
  );
  test('zero outstanding and paid status are rejected', () async {
    for (final fields in [
      {'outstandingAmountMinor': 0},
      {'status': 'paid'},
    ]) {
      final f = _Fixture()..bill.addAll(fields);
      await expectLater(
        f.service.preparePayment('bill'),
        _failure(ResidentDirectUpiFailure.billSettled),
      );
    }
  });
  test(
    'invalid currency and unsafe, fractional, missing or excessive minor amounts fail closed',
    () async {
      for (final fields in <Map<String, dynamic>>[
        {'currency': 'USD'},
        {'currency': null},
        {'amountMinor': null},
        {'amountMinor': 0},
        {'outstandingAmountMinor': null},
        {'outstandingAmountMinor': '100'},
        {'outstandingAmountMinor': -1},
        {'outstandingAmountMinor': 10.5},
        {'outstandingAmountMinor': 100001},
        {
          'amountMinor': 9007199254740992,
          'outstandingAmountMinor': 9007199254740992,
        },
      ]) {
        final f = _Fixture()..bill.addAll(fields);
        await expectLater(
          f.service.preparePayment('bill'),
          _failure(ResidentDirectUpiFailure.billUnavailable),
        );
      }
    },
  );
  test(
    'wrong or missing canonical resident and wrong community cannot prepare',
    () async {
      for (final fields in [
        {'residentId': 'other'},
        {'residentId': null},
        {'communityId': 'other'},
        {'userId': 'other'},
      ]) {
        final f = _Fixture()..bill.addAll(fields);
        await expectLater(
          f.service.preparePayment('bill'),
          _failure(ResidentDirectUpiFailure.billOwnershipMismatch),
        );
      }
    },
  );
  test(
    'historical V2 ownership uses resident and community, not current flat occupant',
    () async {
      final f = _Fixture()..bill['flatId'] = 'old-flat';
      expect((await f.service.preparePayment('bill')).residentId, 'resident');
    },
  );
  test('missing or malformed current revision is rejected', () async {
    for (final revision in [null, '', 'bad/path', ' revision_1', 1]) {
      final f = _Fixture()..bill['currentRevisionId'] = revision;
      await expectLater(
        f.service.preparePayment('bill'),
        _failure(ResidentDirectUpiFailure.billRevisionChanged),
      );
    }
  });
  test(
    'stale revision or outstanding rejects submission before callable or upload',
    () async {
      for (final fields in [
        {'currentRevisionId': 'revision_2'},
        {'outstandingAmountMinor': 90000},
      ]) {
        final f = _Fixture();
        final attempt = await f.attempt();
        f.bill.addAll(fields);
        await expectLater(
          f.service.submitV2PaymentProof(attempt),
          _failure(ResidentDirectUpiFailure.billRevisionChanged),
        );
        expect(f.calls, isEmpty);
        expect(f.uploads, isEmpty);
      }
    },
  );
  test(
    'V2 also rechecks disabled or community-mismatched UPI config',
    () async {
      final f = _Fixture();
      final attempt = await f.attempt();
      f.config['directUpi'] = {'enabled': false};
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.directUpiDisabled),
      );
      f.config['communityId'] = 'other';
      await expectLater(
        f.service.preparePayment('bill'),
        _failure(ResidentDirectUpiFailure.paymentConfigInvalid),
      );
      expect(f.calls, isEmpty);
    },
  );
  test(
    'correct callable payload, returned path and Storage metadata; no Firestore writer is needed',
    () async {
      // No Firebase app/Firestore writer is configured. All writes must go through
      // the callable and receipt uploader, so direct client Firestore writes fail.
      final f = _Fixture()
        ..bill.addAll({
          'status': 'partially_paid',
          'outstandingAmountMinor': 12345,
        });
      final attempt = await f.attempt(extension: 'png', reference: ' REF-123 ');
      final result = await f.service.submitV2PaymentProof(attempt);
      expect(f.calls.single, {
        'billId': 'bill',
        'submittedAmountMinor': 12345,
        'submittedBillRevisionId': 'revision_1',
        'idempotencyKey': attempt.idempotencyKey,
        'receiptExtension': 'png',
        'paymentReference': 'REF-123',
      });
      expect(result.paymentId, 'server-proof');
      expect(
        result.receiptPath,
        'payment_receipts/community/bill/resident/server-proof.png',
      );
      expect(f.uploads.single, {
        'receiptPath': result.receiptPath,
        'bytes': [1, 2, 3],
        'contentType': 'image/png',
        'metadata': {
          'paymentId': 'server-proof',
          'billId': 'bill',
          'communityId': 'community',
          'residentUid': 'resident',
        },
      });
      expect(f.bill['status'], 'partially_paid');
      expect(f.bill['outstandingAmountMinor'], 12345);
    },
  );
  test(
    'pending V2 proofs block initial preparation and a fresh submission attempt',
    () async {
      final f = _Fixture();
      final attempt = await f.attempt();
      f.proofs = [_pending()];
      await expectLater(
        f.service.preparePayment('bill'),
        _failure(ResidentDirectUpiFailure.paymentProofAlreadyPending),
      );
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.paymentProofAlreadyPending),
      );
      expect(f.calls, isEmpty);
      expect(f.v1Reads, 0);
    },
  );
  test(
    'failed and unrelated V2 proofs do not block; unavailable proof status fails closed',
    () async {
      final f = _Fixture()
        ..proofs = [
          {..._pending(), 'status': 'failed'},
          {..._pending(), 'communityId': 'other'},
          {..._pending(), 'residentId': 'other'},
          {..._pending(), 'billId': 'other'},
        ];
      expect((await f.service.preparePayment('bill')).isV2, true);
      f.proofReadFails = true;
      await expectLater(
        f.service.preparePayment('bill'),
        _failure(ResidentDirectUpiFailure.paymentProofStatusUnavailable),
      );
    },
  );
  test(
    'upload failure reports safely and same attempt retries its reserved pending proof',
    () async {
      final f = _Fixture()..uploadFails = true;
      final attempt = await f.attempt();
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.proofUploadFailed),
      );
      expect(f.bill['status'], 'pending');
      f.proofs = [_pending()];
      f.uploadFails = false;
      final result = await f.service.submitV2PaymentProof(attempt);
      expect(result.paymentId, 'server-proof');
      expect(f.calls[0], f.calls[1]);
      expect(f.uploads[0], f.uploads[1]);
      expect(f.calls[1]['idempotencyKey'], attempt.idempotencyKey);
      final again = await f.service.submitV2PaymentProof(attempt);
      expect(again, same(result));
      expect(f.uploads.length, 2);
    },
  );
  test(
    'ambiguous callable failure retries the same key and immutable original intent',
    () async {
      final f = _Fixture()..callableError = StateError('network response lost');
      final attempt = await f.attempt();
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.proofPreparationFailed),
      );
      expect(f.uploads, isEmpty);
      f.proofs = [_pending()];
      f.bill['currentRevisionId'] = 'revision_2';
      f.callableError = null;
      await f.service.submitV2PaymentProof(attempt);
      expect(f.calls[0], f.calls[1]);
      expect(f.calls.last['submittedBillRevisionId'], 'revision_1');
    },
  );
  test(
    'backend stale-revision rejection never uploads or fabricates success',
    () async {
      final f = _Fixture()
        ..callableError = FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Bill revision changed',
        );
      final attempt = await f.attempt();
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.proofPreparationFailed),
      );
      expect(f.uploads, isEmpty);
    },
  );
  test(
    'unexpected server status or receipt path cannot redirect an upload',
    () async {
      for (final response in [
        {
          'paymentId': 'server-proof',
          'receiptPath': 'https://evil/path',
          'status': 'pending',
        },
        {
          'paymentId': 'server-proof',
          'receiptPath':
              'payment_receipts/other/bill/resident/server-proof.jpg',
          'status': 'pending',
        },
        {
          'paymentId': 'server-proof',
          'receiptPath':
              'payment_receipts/community/bill/resident/server-proof.jpg',
          'status': 'completed',
        },
        {'paymentId': null, 'receiptPath': null, 'status': 'pending'},
      ]) {
        final f = _Fixture()..response = response;
        final attempt = await f.attempt();
        await expectLater(
          f.service.submitV2PaymentProof(attempt),
          _failure(ResidentDirectUpiFailure.proofPreparationFailed),
        );
        expect(f.uploads, isEmpty);
      }
    },
  );
  test(
    'one attempt coalesces concurrent submits while new attempts receive different keys',
    () async {
      final f = _Fixture()..uploadGate = Completer<void>();
      final first = await f.attempt(), second = await f.attempt();
      expect(first.idempotencyKey, isNot(second.idempotencyKey));
      final a = f.service.submitV2PaymentProof(first),
          b = f.service.submitV2PaymentProof(first);
      expect(a, same(b));
      f.uploadGate!.complete();
      await Future.wait([a, b]);
      expect(f.calls.length, 1);
      expect(f.uploads.length, 1);
    },
  );
  test(
    'identity change during retry cannot upload evidence for another resident',
    () async {
      final f = _Fixture()..uploadFails = true;
      final attempt = await f.attempt();
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.proofUploadFailed),
      );
      f.scope = const ResidentDirectUpiScope(
        uid: 'other',
        communityId: 'community',
        flatId: 'flat',
      );
      await expectLater(
        f.service.submitV2PaymentProof(attempt),
        _failure(ResidentDirectUpiFailure.billOwnershipMismatch),
      );
      expect(f.calls.length, 1);
    },
  );
  test(
    'receipt bytes are frozen and invalid receipts are rejected before any call',
    () async {
      final f = _Fixture();
      final p = await f.service.preparePayment('bill');
      final bytes = Uint8List.fromList([1, 2, 3]);
      final attempt = f.service.createV2ProofSubmissionAttempt(
        preparation: p,
        receiptBytes: bytes,
        receiptExtension: 'jpeg',
      );
      bytes[0] = 99;
      await f.service.submitV2PaymentProof(attempt);
      expect(f.uploads.single['bytes'], [1, 2, 3]);
      expect(f.uploads.single['contentType'], 'image/jpeg');
      for (final data in [Uint8List(0), Uint8List(10 * 1024 * 1024)]) {
        expect(
          () => f.service.createV2ProofSubmissionAttempt(
            preparation: p,
            receiptBytes: data,
            receiptExtension: 'jpg',
          ),
          _failure(ResidentDirectUpiFailure.receiptInvalid),
        );
      }
      expect(
        () => f.service.createV2ProofSubmissionAttempt(
          preparation: p,
          receiptBytes: bytes,
          receiptExtension: 'pdf',
        ),
        _failure(ResidentDirectUpiFailure.receiptInvalid),
      );
    },
  );
  test(
    'V1 detection and amounts stay unchanged unless schemaVersion equals 2',
    () async {
      for (final schemaVersion in [null, 1, '2', 3]) {
        final f = _Fixture()
          ..bill = {
            'schemaVersion': schemaVersion,
            'communityId': 'community',
            'flatId': 'flat',
            'amount': 42.5,
            'amountMinor': 999,
            'outstandingAmountMinor': 1,
            'status': 'pending',
          };
        final p = await f.service.preparePayment('bill');
        expect(p.isV2, false);
        expect(p.amount, 42.5);
        expect(p.paymentUri.queryParameters['am'], '42.50');
        await f.service.ensureNoPendingProofForBill('bill');
        expect(f.v1Reads, 2);
        expect(f.v2Reads, 0);
      }
    },
  );
  test(
    'legacy proof screen preflight rejects V2 before its direct V1 writer',
    () async {
      final f = _Fixture();
      await expectLater(
        f.service.ensureNoPendingProofForBill('bill'),
        _failure(ResidentDirectUpiFailure.v2ProofSubmissionRequired),
      );
      expect(f.v1Reads, 0);
      expect(f.calls, isEmpty);
    },
  );
}
