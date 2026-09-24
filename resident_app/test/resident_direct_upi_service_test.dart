import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/community_payment_config.dart';
import 'package:resident_app/src/services/resident_direct_upi_service.dart';

const _uid = 'resident-1';
const _communityId = 'community-a';
const _flatId = 'flat-101';
const _billId = 'bill-123';
final _updatedAt = Timestamp.fromMillisecondsSinceEpoch(1780000000000);

Map<String, dynamic> _paymentConfig({
  String communityId = _communityId,
  Map<String, dynamic>? directUpi,
}) => {
  'communityId': communityId,
  'version': 1,
  'directUpi':
      directUpi ??
      {
        'enabled': true,
        'vpa': ' association@upi-bank ',
        'payeeName': ' Community Association ',
      },
  'updatedBy': 'admin-1',
  'updatedAt': _updatedAt,
};

Map<String, dynamic> _bill({
  String communityId = _communityId,
  String flatId = _flatId,
  String status = 'pending',
  num amount = 850,
  Map<String, dynamic> extra = const {},
}) => {
  'communityId': communityId,
  'flatId': flatId,
  'status': status,
  'amount': amount,
  ...extra,
};

ResidentDirectUpiScope _scope({
  String uid = _uid,
  String communityId = _communityId,
  String flatId = _flatId,
}) =>
    ResidentDirectUpiScope(uid: uid, communityId: communityId, flatId: flatId);

ResidentDirectUpiService _service({
  ResidentDirectUpiScope? scope,
  Map<String, dynamic>? bill,
  bool billExists = true,
  Map<String, dynamic>? paymentConfig,
  bool configExists = true,
  List<String>? billDocumentIds,
  List<String>? configDocumentIds,
  List<String>? readOrder,
}) => ResidentDirectUpiService(
  scopeLoader: () async {
    readOrder?.add('scope');
    return scope ?? _scope();
  },
  billLoader: (documentId) async {
    billDocumentIds?.add(documentId);
    readOrder?.add('bill');
    return ResidentDirectUpiDocument(exists: billExists, data: bill ?? _bill());
  },
  paymentConfigLoader: (documentId) async {
    configDocumentIds?.add(documentId);
    readOrder?.add('config');
    return ResidentDirectUpiDocument(
      exists: configExists,
      data: paymentConfig ?? _paymentConfig(),
    );
  },
);

Future<void> _expectFailure(
  Future<DirectUpiPaymentPreparation> result,
  ResidentDirectUpiFailure failure,
) async {
  await expectLater(
    result,
    throwsA(
      isA<ResidentDirectUpiException>().having(
        (error) => error.failure,
        'failure',
        failure,
      ),
    ),
  );
}

void main() {
  group('resident community payment config model', () {
    test('parses enabled config and trims VPA and payee name', () {
      final config = CommunityPaymentConfig.fromMap(
        _communityId,
        _paymentConfig(),
      );

      expect(config.communityId, _communityId);
      expect(config.version, 1);
      expect(config.configured, isTrue);
      expect(config.directUpi.enabled, isTrue);
      expect(config.directUpi.isUsable, isTrue);
      expect(config.directUpi.vpa, 'association@upi-bank');
      expect(config.directUpi.payeeName, 'Community Association');
      expect(config.updatedBy, 'admin-1');
      expect(config.updatedAt, _updatedAt.toDate());
    });

    test('disabled config does not expose stale destination fields', () {
      final config = CommunityPaymentConfig.fromMap(
        _communityId,
        _paymentConfig(
          directUpi: {
            'enabled': false,
            'vpa': 'stale@upi',
            'payeeName': 'Old Association',
          },
        ),
      );

      expect(config.directUpi.enabled, isFalse);
      expect(config.directUpi.isUsable, isFalse);
      expect(config.directUpi.vpa, isNull);
      expect(config.directUpi.payeeName, isNull);
    });

    test('rejects malformed enabled config and invalid metadata safely', () {
      for (final directUpi in <Map<String, dynamic>>[
        {'enabled': true, 'vpa': '', 'payeeName': 'Association'},
        {'enabled': true, 'vpa': 'no-handle', 'payeeName': 'Association'},
        {'enabled': true, 'vpa': 'a@@b', 'payeeName': 'Association'},
        {'enabled': true, 'vpa': 'a@b', 'payeeName': '  '},
        {'enabled': true, 'vpa': 'a b@upi', 'payeeName': 'Association'},
        {'enabled': 'true', 'vpa': 'a@b', 'payeeName': 'Association'},
      ]) {
        expect(
          () => CommunityPaymentConfig.fromMap(
            _communityId,
            _paymentConfig(directUpi: directUpi),
          ),
          throwsA(isA<FormatException>()),
        );
      }

      expect(
        () => CommunityPaymentConfig.fromMap(_communityId, {
          ..._paymentConfig(),
          'updatedAt': 'not a timestamp',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'missing config factory represents safe unconfigured disabled state',
      () {
        final config = CommunityPaymentConfig.unconfigured(_communityId);

        expect(config.configured, isFalse);
        expect(config.directUpi.enabled, isFalse);
        expect(config.directUpi.vpa, isNull);
        expect(config.directUpi.payeeName, isNull);
      },
    );
  });

  group('resident direct UPI preparation', () {
    test(
      'reads the exact bill then config paths from authoritative scope',
      () async {
        final billIds = <String>[];
        final configIds = <String>[];
        final order = <String>[];
        final service = _service(
          billDocumentIds: billIds,
          configDocumentIds: configIds,
          readOrder: order,
        );

        final result = await service.preparePayment(_billId);

        expect(result.billId, _billId);
        expect(billIds, [_billId]);
        expect(configIds, [_communityId]);
        expect(order, ['scope', 'bill', 'config']);
      },
    );

    test(
      'uses only the authoritative server bill amount with two decimals',
      () async {
        final result = await _service(
          bill: _bill(amount: 850),
        ).preparePayment(_billId);

        expect(result.amount, 850);
        expect(result.paymentUri.queryParameters['am'], '850.00');
        expect(result.paymentUri.queryParameters['am'], isNot('0.01'));
      },
    );

    test(
      'accepts a half-rupee server amount and formats two decimals',
      () async {
        final result = await _service(
          bill: _bill(amount: 42.5),
        ).preparePayment(_billId);

        expect(result.amount, 42.5);
        expect(result.paymentUri.queryParameters['am'], '42.50');
      },
    );

    test('accepts one paisa and formats two decimals', () async {
      final result = await _service(
        bill: _bill(amount: 0.01),
      ).preparePayment(_billId);

      expect(result.amount, 0.01);
      expect(result.paymentUri.queryParameters['am'], '0.01');
    });

    test('accepts 0.29 and formats two decimals', () async {
      final result = await _service(
        bill: _bill(amount: 0.29),
      ).preparePayment(_billId);

      expect(result.amount, 0.29);
      expect(result.paymentUri.queryParameters['am'], '0.29');
    });

    test('accepts large two-decimal amounts without a low cap', () async {
      final result = await _service(
        bill: _bill(amount: 1200000.01),
      ).preparePayment(_billId);

      expect(result.amount, 1200000.01);
      expect(result.paymentUri.queryParameters['am'], '1200000.01');
    });

    test(
      'rejects missing bill and invalid bill IDs without reading config',
      () async {
        final configIds = <String>[];
        await _expectFailure(
          _service(
            billExists: false,
            configDocumentIds: configIds,
          ).preparePayment(_billId),
          ResidentDirectUpiFailure.billUnavailable,
        );
        await _expectFailure(
          _service(configDocumentIds: configIds).preparePayment('bad/id'),
          ResidentDirectUpiFailure.billUnavailable,
        );
        expect(configIds, isEmpty);
      },
    );

    test('rejects bills outside resident community or flat', () async {
      await _expectFailure(
        _service(
          bill: _bill(communityId: 'community-b'),
        ).preparePayment(_billId),
        ResidentDirectUpiFailure.billOwnershipMismatch,
      );
      await _expectFailure(
        _service(bill: _bill(flatId: 'flat-other')).preparePayment(_billId),
        ResidentDirectUpiFailure.billOwnershipMismatch,
      );
    });

    test(
      'rejects mismatched residentId and userId fields when present',
      () async {
        for (final field in ['residentId', 'userId']) {
          await _expectFailure(
            _service(
              bill: _bill(extra: {field: 'someone-else'}),
            ).preparePayment(_billId),
            ResidentDirectUpiFailure.billOwnershipMismatch,
          );
        }
      },
    );

    test('rejects settled status or payment settlement markers', () async {
      for (final settledBill in [
        _bill(status: 'paid'),
        _bill(extra: {'paymentId': 'payment-1'}),
        _bill(extra: {'paidAt': DateTime(2026)}),
        _bill(extra: {'paidAmount': 850}),
      ]) {
        await _expectFailure(
          _service(bill: settledBill).preparePayment(_billId),
          ResidentDirectUpiFailure.billSettled,
        );
      }
    });

    test('accepts pending and overdue unpaid bills', () async {
      for (final status in ['pending', 'overdue']) {
        final result = await _service(
          bill: _bill(status: status),
        ).preparePayment(_billId);
        expect(result.amount, 850);
      }
    });

    test('rejects invalid bill amounts', () async {
      for (final amount in <dynamic>[
        0,
        -1,
        double.nan,
        double.infinity,
        10.999,
        850.001,
        '850',
      ]) {
        await _expectFailure(
          _service(
            bill: _bill(extra: {'amount': amount}),
          ).preparePayment(_billId),
          ResidentDirectUpiFailure.billUnavailable,
        );
      }
    });

    test('missing and disabled payment configs prevent preparation', () async {
      await _expectFailure(
        _service(configExists: false).preparePayment(_billId),
        ResidentDirectUpiFailure.directUpiNotConfigured,
      );
      await _expectFailure(
        _service(
          paymentConfig: _paymentConfig(directUpi: {'enabled': false}),
        ).preparePayment(_billId),
        ResidentDirectUpiFailure.directUpiDisabled,
      );
    });

    test('rejects malformed or community-mismatched payment config', () async {
      await _expectFailure(
        _service(
          paymentConfig: _paymentConfig(
            directUpi: {
              'enabled': true,
              'vpa': 'malformed-vpa',
              'payeeName': 'Association',
            },
          ),
        ).preparePayment(_billId),
        ResidentDirectUpiFailure.paymentConfigInvalid,
      );
      await _expectFailure(
        _service(
          paymentConfig: _paymentConfig(communityId: 'community-b'),
        ).preparePayment(_billId),
        ResidentDirectUpiFailure.paymentConfigInvalid,
      );
    });

    test(
      'builds a generic UPI URI with exactly the V1 payment fields',
      () async {
        final result = await _service().preparePayment(_billId);
        final uri = result.paymentUri;

        expect(uri.scheme, 'upi');
        expect(uri.host, 'pay');
        expect(uri.queryParameters, {
          'pa': 'association@upi-bank',
          'pn': 'Community Association',
          'am': '850.00',
          'cu': 'INR',
        });
        expect(uri.queryParameters.keys.toSet(), {'pa', 'pn', 'am', 'cu'});
        expect(uri.toString(), startsWith('upi://pay?'));
        expect(uri.toString(), isNot(contains('gpay')));
        expect(uri.toString(), isNot(contains('phonepe')));
        expect(uri.toString(), isNot(contains('paytm')));
        expect(uri.queryParameters.keys, isNot(contains('mc')));
        expect(uri.queryParameters.keys, isNot(contains('tr')));
      },
    );

    test(
      'URI encodes VPA and payee special characters and uses config values',
      () async {
        final result = await _service(
          paymentConfig: _paymentConfig(
            directUpi: {
              'enabled': true,
              'vpa': 'resident+unit@upi.example',
              'payeeName': 'Green & Community / East',
            },
          ),
        ).preparePayment(_billId);

        expect(result.vpa, 'resident+unit@upi.example');
        expect(result.payeeName, 'Green & Community / East');
        expect(
          result.paymentUri.queryParameters['pa'],
          'resident+unit@upi.example',
        );
        expect(
          result.paymentUri.queryParameters['pn'],
          'Green & Community / East',
        );
        expect(result.paymentUri.toString(), contains('%2B'));
        expect(result.paymentUri.toString(), contains('%40'));
        expect(result.paymentUri.toString(), contains('%26'));
        expect(result.paymentUri.toString(), contains('%2F'));
      },
    );
  });
}
