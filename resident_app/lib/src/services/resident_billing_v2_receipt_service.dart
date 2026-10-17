import 'package:cloud_functions/cloud_functions.dart';

typedef ResidentBillingV2ReceiptCallable =
    Future<Object?> Function(String callableName, Map<String, dynamic> payload);

class ResidentBillingV2ReceiptException implements Exception {
  const ResidentBillingV2ReceiptException();

  String get message =>
      'Could not load this verified payment receipt. Please retry.';

  @override
  String toString() => message;
}

class ResidentBillingV2ReceiptService {
  ResidentBillingV2ReceiptService({ResidentBillingV2ReceiptCallable? callable})
    : _callable = callable ?? _callFirebaseCallable;

  static const String callableName = 'getResidentBillingV2Receipt';
  static const String safeErrorMessage =
      'Could not load this verified payment receipt. Please retry.';
  static const int _maxSafeInteger = 9007199254740991;

  final ResidentBillingV2ReceiptCallable _callable;

  static Future<Object?> _callFirebaseCallable(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    final result = await functions.httpsCallable(name).call<Object?>(payload);
    return result.data;
  }

  Future<ResidentBillingV2Receipt> getReceipt(String transactionId) async {
    if (transactionId.trim().isEmpty || transactionId != transactionId.trim()) {
      throw ArgumentError.value(transactionId, 'transactionId');
    }
    try {
      final response = await _callable(callableName, {
        'transactionId': transactionId,
      });
      return ResidentBillingV2Receipt.fromResponse(response);
    } catch (_) {
      throw const ResidentBillingV2ReceiptException();
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw _InvalidResponse();
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw _InvalidResponse();
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static void _keys(
    Map<String, dynamic> value,
    Set<String> required, {
    Set<String> optional = const {},
  }) {
    if (!value.keys.toSet().containsAll(required) ||
        value.keys.any(
          (key) => !required.contains(key) && !optional.contains(key),
        )) {
      throw _InvalidResponse();
    }
  }

  static String _string(Object? value, {bool allowEmpty = false}) {
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw _InvalidResponse();
    }
    return value;
  }

  static int _integer(Object? value, {bool positive = false}) {
    if (value is! int ||
        value < (positive ? 1 : 0) ||
        value > _maxSafeInteger) {
      throw _InvalidResponse();
    }
    return value;
  }

  static int? _nullableInteger(Object? value) =>
      value == null ? null : _integer(value);

  static String? _nullableString(Object? value) =>
      value == null ? null : _string(value, allowEmpty: true);
}

class ResidentBillingV2Receipt {
  const ResidentBillingV2Receipt({
    required this.receiptId,
    required this.transactionId,
    required this.communityId,
    required this.communityName,
    required this.communityAddress,
    required this.currency,
    required this.method,
    required this.paymentReference,
    required this.receivedAt,
    required this.moneyReceivedMinor,
    required this.claimedAmountMinor,
    required this.amountMismatch,
    required this.verifiedAt,
    required this.allocations,
    required this.allocatedAmountMinor,
    required this.excessCreditMinor,
    required this.reversedAllocationMinor,
    required this.revisionCreditIssuedMinor,
  });

  final String receiptId;
  final String transactionId;
  final String communityId;
  final String? communityName;
  final String? communityAddress;
  final String currency;
  final String method;
  final String? paymentReference;
  final int receivedAt;
  final int moneyReceivedMinor;
  final int? claimedAmountMinor;
  final bool? amountMismatch;
  final int verifiedAt;
  final List<ResidentBillingV2ReceiptAllocation> allocations;
  final int allocatedAmountMinor;
  final int excessCreditMinor;
  final int reversedAllocationMinor;
  final int revisionCreditIssuedMinor;

  static ResidentBillingV2Receipt fromResponse(Object? response) {
    try {
      final data = ResidentBillingV2ReceiptService._map(response);
      ResidentBillingV2ReceiptService._keys(data, {
        'success',
        'schemaVersion',
        'receiptId',
        'transactionId',
        'community',
        'currency',
        'method',
        'paymentReference',
        'receivedAt',
        'moneyReceivedMinor',
        'confirmedAmountMinor',
        'claimedAmountMinor',
        'amountMismatch',
        'confirmation',
        'allocations',
        'allocatedAmountMinor',
        'excessCreditMinor',
        'reconciliation',
        'accountingBasis',
        'snapshot',
        'laterAdjustments',
      });
      if (data['success'] != true ||
          data['schemaVersion'] != 1 ||
          data['currency'] != 'INR' ||
          data['snapshot'] != 'original_settlement') {
        throw _InvalidResponse();
      }
      final transactionId = ResidentBillingV2ReceiptService._string(
        data['transactionId'],
      );
      final receiptId = ResidentBillingV2ReceiptService._string(
        data['receiptId'],
      );
      if (receiptId != 'HOMINODE-V2-$transactionId') throw _InvalidResponse();
      final method = ResidentBillingV2ReceiptService._string(data['method']);
      if (!const {'upi', 'cash', 'bank_transfer', 'cheque'}.contains(method)) {
        throw _InvalidResponse();
      }
      final community = ResidentBillingV2ReceiptService._map(data['community']);
      ResidentBillingV2ReceiptService._keys(community, {
        'communityId',
        'name',
        'address',
      });
      final confirmation = ResidentBillingV2ReceiptService._map(
        data['confirmation'],
      );
      ResidentBillingV2ReceiptService._keys(confirmation, {
        'status',
        'verifiedAt',
        'verifiedBy',
      });
      if (confirmation['status'] != 'verified') throw _InvalidResponse();
      final basis = ResidentBillingV2ReceiptService._map(
        data['accountingBasis'],
      );
      ResidentBillingV2ReceiptService._keys(basis, {
        'amountsAreMinorUnits',
        'allocationsAreFromThisPayment',
        'existingCreditApplicationsExcluded',
      });
      if (basis['amountsAreMinorUnits'] != true ||
          basis['allocationsAreFromThisPayment'] != true ||
          basis['existingCreditApplicationsExcluded'] != true) {
        throw _InvalidResponse();
      }
      final allocationsRaw = data['allocations'];
      if (allocationsRaw is! List) throw _InvalidResponse();
      final allocations = allocationsRaw
          .map(ResidentBillingV2ReceiptAllocation.fromResponse)
          .toList(growable: false);
      final allocatedAmountMinor = ResidentBillingV2ReceiptService._integer(
        data['allocatedAmountMinor'],
      );
      final excessCreditMinor = ResidentBillingV2ReceiptService._integer(
        data['excessCreditMinor'],
      );
      final moneyReceivedMinor = ResidentBillingV2ReceiptService._integer(
        data['moneyReceivedMinor'],
        positive: true,
      );
      final confirmedAmountMinor = ResidentBillingV2ReceiptService._integer(
        data['confirmedAmountMinor'],
        positive: true,
      );
      final sum = allocations.fold<BigInt>(
        BigInt.zero,
        (total, item) => total + BigInt.from(item.amountMinor),
      );
      final reconciliation = ResidentBillingV2ReceiptService._map(
        data['reconciliation'],
      );
      ResidentBillingV2ReceiptService._keys(reconciliation, {
        'confirmedAmountMinor',
        'allocatedAmountMinor',
        'excessCreditMinor',
      });
      if (sum != BigInt.from(allocatedAmountMinor) ||
          confirmedAmountMinor != moneyReceivedMinor ||
          BigInt.from(allocatedAmountMinor) + BigInt.from(excessCreditMinor) !=
              BigInt.from(moneyReceivedMinor) ||
          reconciliation['confirmedAmountMinor'] != confirmedAmountMinor ||
          reconciliation['allocatedAmountMinor'] != allocatedAmountMinor ||
          reconciliation['excessCreditMinor'] != excessCreditMinor ||
          community['communityId'] is! String ||
          (community['communityId'] as String).trim().isEmpty) {
        throw _InvalidResponse();
      }
      final adjustments = ResidentBillingV2ReceiptService._map(
        data['laterAdjustments'],
      );
      ResidentBillingV2ReceiptService._keys(adjustments, {
        'reversedAllocationMinor',
        'revisionCreditIssuedMinor',
      });
      final receivedAt = ResidentBillingV2ReceiptService._integer(
        data['receivedAt'],
      );
      final verifiedAt = ResidentBillingV2ReceiptService._integer(
        confirmation['verifiedAt'],
      );
      return ResidentBillingV2Receipt(
        receiptId: receiptId,
        transactionId: transactionId,
        communityId: community['communityId'] as String,
        communityName: ResidentBillingV2ReceiptService._nullableString(
          community['name'],
        ),
        communityAddress: ResidentBillingV2ReceiptService._nullableString(
          community['address'],
        ),
        currency: 'INR',
        method: method,
        paymentReference: ResidentBillingV2ReceiptService._nullableString(
          data['paymentReference'],
        ),
        receivedAt: receivedAt,
        moneyReceivedMinor: moneyReceivedMinor,
        claimedAmountMinor: ResidentBillingV2ReceiptService._nullableInteger(
          data['claimedAmountMinor'],
        ),
        amountMismatch: data['amountMismatch'] == null
            ? null
            : data['amountMismatch'] as bool,
        verifiedAt: verifiedAt,
        allocations: allocations,
        allocatedAmountMinor: allocatedAmountMinor,
        excessCreditMinor: excessCreditMinor,
        reversedAllocationMinor: ResidentBillingV2ReceiptService._integer(
          adjustments['reversedAllocationMinor'],
        ),
        revisionCreditIssuedMinor: ResidentBillingV2ReceiptService._integer(
          adjustments['revisionCreditIssuedMinor'],
        ),
      );
    } on _InvalidResponse {
      rethrow;
    } catch (_) {
      throw _InvalidResponse();
    }
  }
}

class ResidentBillingV2ReceiptAllocation {
  const ResidentBillingV2ReceiptAllocation({
    required this.amountMinor,
    required this.allocatedAt,
  });

  // Bill IDs are intentionally parsed for schema validation, not exposed in
  // the receipt UI; they are internal financial identifiers.
  final int amountMinor;
  final int allocatedAt;

  static ResidentBillingV2ReceiptAllocation fromResponse(Object? value) {
    final data = ResidentBillingV2ReceiptService._map(value);
    ResidentBillingV2ReceiptService._keys(data, {
      'billId',
      'amountMinor',
      'allocatedAt',
    });
    final billId = ResidentBillingV2ReceiptService._string(data['billId']);
    if (billId.contains('/')) throw _InvalidResponse();
    return ResidentBillingV2ReceiptAllocation(
      amountMinor: ResidentBillingV2ReceiptService._integer(
        data['amountMinor'],
        positive: true,
      ),
      allocatedAt: ResidentBillingV2ReceiptService._integer(
        data['allocatedAt'],
      ),
    );
  }
}

class _InvalidResponse implements Exception {}
