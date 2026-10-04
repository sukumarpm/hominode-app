// lib/src/models/bill_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BillChargeLineModel {
  final String lineId;
  final String code;
  final String label;
  final int? amountMinor;

  const BillChargeLineModel({
    required this.lineId,
    required this.code,
    required this.label,
    required this.amountMinor,
  });

  factory BillChargeLineModel.fromMap(Map<String, dynamic> map) {
    return BillChargeLineModel(
      lineId: map['lineId'] as String? ?? '',
      code: map['code'] as String? ?? '',
      label: map['label'] as String? ?? 'Charge',
      amountMinor: _asStrictInt(map['amountMinor']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lineId': lineId,
      'code': code,
      'label': label,
      'amountMinor': amountMinor,
    };
  }
}

class BillModel {
  final String id;
  final int schemaVersion;
  final String communityId;
  final String? residentId;
  final String flatId;
  final String? billingPeriod;
  final int? amountMinor;
  final int? outstandingAmountMinor;
  final List<BillChargeLineModel> chargeLines;
  final String type; // 'maintenance', 'electricity', 'water', 'other'
  final double amount;
  final DateTime dueDate;
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final String status; // 'pending', 'paid', 'overdue', 'cancelled'
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  BillModel({
    required this.id,
    this.schemaVersion = 1,
    this.communityId = '',
    this.residentId,
    required this.flatId,
    this.billingPeriod,
    this.amountMinor,
    this.outstandingAmountMinor,
    this.chargeLines = const [],
    required this.type,
    required this.amount,
    required this.dueDate,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    this.status = 'pending',
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'flatId': flatId,
      'type': type,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'billingPeriodStart': Timestamp.fromDate(billingPeriodStart),
      'billingPeriodEnd': Timestamp.fromDate(billingPeriodEnd),
      'status': status,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel.fromMap(json, json['id'] as String? ?? '');
  }

  factory BillModel.fromMap(Map<String, dynamic> map, String documentId) {
    final rawSchemaVersion = map['schemaVersion'];
    final schemaVersion = rawSchemaVersion is int ? rawSchemaVersion : 1;
    final isV2 = rawSchemaVersion is int && rawSchemaVersion == 2;

    final now = DateTime.now();
    final createdAt = _asDateTime(map['createdAt'], now);
    final dueDate = _asDateTime(map['dueDate'], now);

    final rawBillingPeriod = map['billingPeriod'];
    final billingPeriod =
        isV2 &&
            rawBillingPeriod is String &&
            _isCanonicalBillingPeriod(rawBillingPeriod)
        ? rawBillingPeriod
        : null;

    final parsedChargeLines = isV2 && map['chargeLines'] is List
        ? (map['chargeLines'] as List)
              .whereType<Map>()
              .map(
                (line) => BillChargeLineModel.fromMap(
                  Map<String, dynamic>.from(line),
                ),
              )
              .toList()
        : const <BillChargeLineModel>[];

    final amountMinor = isV2 ? _asStrictInt(map['amountMinor']) : null;
    final amount =
        (map['amount'] as num?)?.toDouble() ??
        (isV2 && amountMinor != null ? amountMinor / 100 : 0);

    final rawType = map['type'];
    final type = rawType is String ? rawType : (isV2 ? 'combined' : '');

    final billingPeriodStart = isV2
        ? _asDateTime(
            map['billingPeriodStart'],
            _periodStartFromKeyUtc(billingPeriod) ?? now,
          )
        : _asDateTime(map['billingPeriodStart'], now);

    final billingPeriodEnd = isV2
        ? _asDateTime(
            map['billingPeriodEnd'],
            _periodEndFromKeyUtc(billingPeriod) ?? now,
          )
        : _asDateTime(map['billingPeriodEnd'], now);

    final status = isV2
        ? (map['status'] is String ? map['status'] as String : '')
        : (map['status'] as String? ?? 'pending');

    return BillModel(
      id: documentId,
      schemaVersion: schemaVersion,
      communityId: map['communityId'] as String? ?? '',
      residentId: isV2 ? map['residentId'] as String? : null,
      flatId: map['flatId'] ?? '',
      billingPeriod: billingPeriod,
      amountMinor: amountMinor,
      outstandingAmountMinor: isV2
          ? _asStrictInt(map['outstandingAmountMinor'])
          : null,
      chargeLines: parsedChargeLines,
      type: type,
      amount: amount,
      dueDate: dueDate,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      status: status,
      description: map['description'],
      createdAt: createdAt,
      updatedAt: _asDateTime(map['updatedAt'], now),
    );
  }

  factory BillModel.fromSnapshot(DocumentSnapshot snapshot) {
    return BillModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BillModel.fromMap(data, doc.id);
  }

  bool get isOverdue {
    return status == 'pending' && DateTime.now().isAfter(dueDate);
  }

  BillModel copyWith({
    String? id,
    int? schemaVersion,
    String? communityId,
    String? residentId,
    String? flatId,
    String? billingPeriod,
    int? amountMinor,
    int? outstandingAmountMinor,
    List<BillChargeLineModel>? chargeLines,
    String? type,
    double? amount,
    DateTime? dueDate,
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillModel(
      id: id ?? this.id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      communityId: communityId ?? this.communityId,
      residentId: residentId ?? this.residentId,
      flatId: flatId ?? this.flatId,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      amountMinor: amountMinor ?? this.amountMinor,
      outstandingAmountMinor:
          outstandingAmountMinor ?? this.outstandingAmountMinor,
      chargeLines: chargeLines ?? this.chargeLines,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      billingPeriodStart: billingPeriodStart ?? this.billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd ?? this.billingPeriodEnd,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

int? _asStrictInt(Object? value) {
  if (value is int) return value;
  return null;
}

DateTime _asDateTime(Object? value, DateTime fallback) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}

bool _isCanonicalBillingPeriod(String value) {
  return RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);
}

DateTime? _periodStartFromKeyUtc(String? key) {
  if (key == null || !_isCanonicalBillingPeriod(key)) {
    return null;
  }
  final parts = key.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], 1);
}

DateTime? _periodEndFromKeyUtc(String? key) {
  if (key == null || !_isCanonicalBillingPeriod(key)) {
    return null;
  }
  final parts = key.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1] + 1, 0);
}
