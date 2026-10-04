import 'package:cloud_functions/cloud_functions.dart';

import 'bill_firestore_service.dart';

typedef ResidentBillingStatementCallable =
    Future<Object?> Function(String callableName, Map<String, dynamic> payload);

class ResidentBillingStatementException implements Exception {
  const ResidentBillingStatementException();

  String get message =>
      'Could not load the monthly statement. Please try again.';

  @override
  String toString() => message;
}

class ResidentBillingStatementService {
  ResidentBillingStatementService({ResidentBillingStatementCallable? callable})
    : _callable = callable ?? _callFirebaseCallable;

  static const String callableName = 'getResidentBillingV2Statement';
  static const String safeErrorMessage =
      'Could not load the monthly statement. Please try again.';
  static const int _maxSafeInteger = 9007199254740991;

  final ResidentBillingStatementCallable _callable;

  static Future<Object?> _callFirebaseCallable(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    final result = await functions.httpsCallable(name).call<Object?>(payload);
    return result.data;
  }

  Future<ResidentBillingStatement> getStatement(String billingPeriod) async {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(billingPeriod)) {
      throw ArgumentError.value(billingPeriod, 'billingPeriod');
    }
    try {
      final response = await _callable(callableName, {
        'billingPeriod': billingPeriod,
      });
      return ResidentBillingStatement.fromResponse(response, billingPeriod);
    } catch (_) {
      throw const ResidentBillingStatementException();
    }
  }

  static Map<String, dynamic> _map(Object? value, String field) {
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

  static BigInt _safeSum(Iterable<int> values) {
    final sum = values.fold<BigInt>(
      BigInt.zero,
      (total, value) => total + BigInt.from(value),
    );
    if (sum > BigInt.from(_maxSafeInteger)) throw _InvalidResponse();
    return sum;
  }

  static String _period(Object? value) {
    final period = _string(value);
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(period)) {
      throw _InvalidResponse();
    }
    return period;
  }

  static String _dueDateKey(Object? value) {
    final date = _string(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw _InvalidResponse();
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null ||
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
            date) {
      throw _InvalidResponse();
    }
    return date;
  }

  static Never _invalid() => throw _InvalidResponse();
}

class ResidentBillingStatement {
  const ResidentBillingStatement({
    required this.communityId,
    required this.residentId,
    required this.billingPeriod,
    required this.generatedAtMs,
    required this.summary,
    required this.bills,
  });

  final String communityId;
  final String residentId;
  final String billingPeriod;
  final int generatedAtMs;
  final ResidentBillingStatementSummary summary;
  final List<ResidentStatementBill> bills;

  static ResidentBillingStatement fromResponse(
    Object? response,
    String requestedPeriod,
  ) {
    try {
      final data = ResidentBillingStatementService._map(response, 'response');
      ResidentBillingStatementService._keys(data, {
        'success',
        'schemaVersion',
        'communityId',
        'residentId',
        'billingPeriod',
        'generatedAtMs',
        'summary',
        'bills',
      });
      if (data['success'] != true || data['schemaVersion'] != 1) {
        ResidentBillingStatementService._invalid();
      }
      final period = ResidentBillingStatementService._period(
        data['billingPeriod'],
      );
      if (period != requestedPeriod) ResidentBillingStatementService._invalid();
      final summary = ResidentBillingStatementSummary._parse(data['summary']);
      final rawBills = data['bills'];
      if (rawBills is! List) ResidentBillingStatementService._invalid();
      final bills = rawBills
          .map(ResidentStatementBill._parse)
          .toList(growable: false);
      if (bills.length != summary.billsCount ||
          bills.any((bill) => bill.billingPeriod != period) ||
          bills.map((bill) => bill.billId).toSet().length != bills.length) {
        ResidentBillingStatementService._invalid();
      }
      summary._validateAgainst(bills);
      return ResidentBillingStatement(
        communityId: ResidentBillingStatementService._string(
          data['communityId'],
        ),
        residentId: ResidentBillingStatementService._string(data['residentId']),
        billingPeriod: period,
        generatedAtMs: ResidentBillingStatementService._integer(
          data['generatedAtMs'],
        ),
        summary: summary,
        bills: bills,
      );
    } on _InvalidResponse {
      rethrow;
    } catch (_) {
      throw _InvalidResponse();
    }
  }
}

class ResidentBillingStatementSummary {
  const ResidentBillingStatementSummary({
    required this.billsCount,
    required this.billedMinor,
    required this.paidAllocationMinor,
    required this.creditAppliedMinor,
    required this.outstandingMinor,
    required this.availableCreditMinor,
    required this.statusCounts,
  });

  final int billsCount;
  final int billedMinor;
  final int paidAllocationMinor;
  final int creditAppliedMinor;
  final int outstandingMinor;
  final int availableCreditMinor;
  final Map<String, int> statusCounts;

  static ResidentBillingStatementSummary _parse(Object? value) {
    final data = ResidentBillingStatementService._map(value, 'summary');
    ResidentBillingStatementService._keys(data, {
      'billsCount',
      'billedMinor',
      'paidAllocationMinor',
      'creditAppliedMinor',
      'outstandingMinor',
      'availableCreditMinor',
      'statusCounts',
    });
    final statusData = ResidentBillingStatementService._map(
      data['statusCounts'],
      'statusCounts',
    );
    ResidentBillingStatementService._keys(statusData, {
      'pending',
      'partially_paid',
      'paid',
      'overdue',
    });
    return ResidentBillingStatementSummary(
      billsCount: ResidentBillingStatementService._integer(data['billsCount']),
      billedMinor: ResidentBillingStatementService._integer(
        data['billedMinor'],
      ),
      paidAllocationMinor: ResidentBillingStatementService._integer(
        data['paidAllocationMinor'],
      ),
      creditAppliedMinor: ResidentBillingStatementService._integer(
        data['creditAppliedMinor'],
      ),
      outstandingMinor: ResidentBillingStatementService._integer(
        data['outstandingMinor'],
      ),
      availableCreditMinor: ResidentBillingStatementService._integer(
        data['availableCreditMinor'],
      ),
      statusCounts: {
        for (final key in const [
          'pending',
          'partially_paid',
          'paid',
          'overdue',
        ])
          key: ResidentBillingStatementService._integer(statusData[key]),
      },
    );
  }

  void _validateAgainst(List<ResidentStatementBill> bills) {
    var billed = BigInt.zero;
    var paid = BigInt.zero;
    var credit = BigInt.zero;
    var outstanding = BigInt.zero;
    final counts = <String, int>{
      'pending': 0,
      'partially_paid': 0,
      'paid': 0,
      'overdue': 0,
    };
    for (final bill in bills) {
      billed += BigInt.from(bill.amountMinor);
      paid += BigInt.from(bill.paidAllocationMinor);
      credit += BigInt.from(bill.creditAppliedMinor);
      outstanding += BigInt.from(bill.outstandingMinor);
      counts[bill.status] = counts[bill.status]! + 1;
    }
    final maxSafe = BigInt.from(
      ResidentBillingStatementService._maxSafeInteger,
    );
    if ([billed, paid, credit, outstanding].any((total) => total > maxSafe) ||
        billed != BigInt.from(billedMinor) ||
        paid != BigInt.from(paidAllocationMinor) ||
        credit != BigInt.from(creditAppliedMinor) ||
        outstanding != BigInt.from(outstandingMinor) ||
        counts.entries.any((entry) => statusCounts[entry.key] != entry.value) ||
        statusCounts.values.fold<int>(0, (sum, count) => sum + count) !=
            billsCount) {
      ResidentBillingStatementService._invalid();
    }
  }
}

class ResidentStatementBill {
  const ResidentStatementBill({
    required this.billId,
    required this.billingPeriod,
    required this.amountMinor,
    required this.paidAllocationMinor,
    required this.creditAppliedMinor,
    required this.outstandingMinor,
    required this.status,
    required this.dueDateKey,
    required this.chargeLines,
    required this.settlements,
  });

  final String billId;
  final String billingPeriod;
  final int amountMinor;
  final int paidAllocationMinor;
  final int creditAppliedMinor;
  final int outstandingMinor;
  final String status;
  final String dueDateKey;
  final List<ResidentStatementChargeLine> chargeLines;
  final List<ResidentStatementSettlement> settlements;

  static ResidentStatementBill _parse(Object? value) {
    final data = ResidentBillingStatementService._map(value, 'bill');
    ResidentBillingStatementService._keys(data, {
      'billId',
      'billingPeriod',
      'amountMinor',
      'paidAllocationMinor',
      'creditAppliedMinor',
      'outstandingMinor',
      'status',
      'dueDateKey',
      'chargeLines',
      'settlements',
    });
    final period = ResidentBillingStatementService._period(
      data['billingPeriod'],
    );
    final amount = ResidentBillingStatementService._integer(
      data['amountMinor'],
    );
    final paid = ResidentBillingStatementService._integer(
      data['paidAllocationMinor'],
    );
    final credit = ResidentBillingStatementService._integer(
      data['creditAppliedMinor'],
    );
    final outstanding = ResidentBillingStatementService._integer(
      data['outstandingMinor'],
    );
    final status = ResidentBillingStatementService._string(data['status']);
    if (!const {
          'pending',
          'partially_paid',
          'paid',
          'overdue',
        }.contains(status) ||
        BigInt.from(paid) + BigInt.from(credit) + BigInt.from(outstanding) !=
            BigInt.from(amount)) {
      ResidentBillingStatementService._invalid();
    }
    final rawLines = data['chargeLines'];
    final rawSettlements = data['settlements'];
    if (rawLines is! List || rawSettlements is! List) {
      ResidentBillingStatementService._invalid();
    }
    final lines = rawLines
        .map(ResidentStatementChargeLine._parse)
        .toList(growable: false);
    final settlements = rawSettlements
        .map(ResidentStatementSettlement._parse)
        .toList(growable: false);
    if (lines.map((line) => line.lineId).toSet().length != lines.length ||
        settlements.map((item) => item.transactionId).toSet().length !=
            settlements.length ||
        ResidentBillingStatementService._safeSum(
              lines.map((line) => line.amountMinor),
            ) !=
            BigInt.from(amount) ||
        ResidentBillingStatementService._safeSum(
              settlements.map((item) => item.netAppliedMinor),
            ) !=
            BigInt.from(paid)) {
      ResidentBillingStatementService._invalid();
    }
    return ResidentStatementBill(
      billId: ResidentBillingStatementService._string(data['billId']),
      billingPeriod: period,
      amountMinor: amount,
      paidAllocationMinor: paid,
      creditAppliedMinor: credit,
      outstandingMinor: outstanding,
      status: status,
      dueDateKey: ResidentBillingStatementService._dueDateKey(
        data['dueDateKey'],
      ),
      chargeLines: lines,
      settlements: settlements,
    );
  }
}

class ResidentStatementChargeLine {
  const ResidentStatementChargeLine({
    required this.lineId,
    required this.code,
    required this.label,
    required this.amountMinor,
  });

  final String lineId;
  final String code;
  final String label;
  final int amountMinor;

  static ResidentStatementChargeLine _parse(Object? value) {
    final data = ResidentBillingStatementService._map(value, 'chargeLine');
    ResidentBillingStatementService._keys(data, {
      'lineId',
      'code',
      'label',
      'amountMinor',
    });
    return ResidentStatementChargeLine(
      lineId: ResidentBillingStatementService._string(data['lineId']),
      code: ResidentBillingStatementService._string(data['code']),
      label: ResidentBillingStatementService._string(data['label']),
      amountMinor: ResidentBillingStatementService._integer(
        data['amountMinor'],
      ),
    );
  }
}

class ResidentStatementSettlement {
  const ResidentStatementSettlement({
    required this.transactionId,
    required this.method,
    required this.reference,
    required this.receivedAt,
    required this.netAppliedMinor,
  });

  final String transactionId;
  final String method;
  final String? reference;
  final int receivedAt;
  final int netAppliedMinor;

  static ResidentStatementSettlement _parse(Object? value) {
    final data = ResidentBillingStatementService._map(value, 'settlement');
    ResidentBillingStatementService._keys(
      data,
      {'transactionId', 'method', 'receivedAt', 'netAppliedMinor'},
      optional: {'reference'},
    );
    final method = ResidentBillingStatementService._string(data['method']);
    if (!const {'upi', 'cash', 'bank_transfer', 'cheque'}.contains(method)) {
      ResidentBillingStatementService._invalid();
    }
    final rawReference = data['reference'];
    if (rawReference != null && rawReference is! String) {
      ResidentBillingStatementService._invalid();
    }
    return ResidentStatementSettlement(
      transactionId: ResidentBillingStatementService._string(
        data['transactionId'],
      ),
      method: method,
      reference: rawReference as String?,
      receivedAt: ResidentBillingStatementService._integer(data['receivedAt']),
      netAppliedMinor: ResidentBillingStatementService._integer(
        data['netAppliedMinor'],
        positive: true,
      ),
    );
  }
}

class _InvalidResponse implements Exception {}

String formatResidentStatementMoney(int amountMinor) =>
    BillFirestoreService.formatInrMinorUnits(amountMinor);
