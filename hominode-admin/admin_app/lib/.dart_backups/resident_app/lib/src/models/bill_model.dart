// lib/src/models/bill_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BillModel {
  final String id;
  final String communityId;
  final String flatId;
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
    this.communityId = '',
    required this.flatId,
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
    return BillModel(
      id: json['id'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      flatId: json['flatId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      billingPeriodStart:
          (json['billingPeriodStart'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      billingPeriodEnd:
          (json['billingPeriodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      description: json['description'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory BillModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BillModel(
      id: documentId,
      communityId: map['communityId'] as String? ?? '',
      flatId: map['flatId'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      billingPeriodStart:
          (map['billingPeriodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      billingPeriodEnd:
          (map['billingPeriodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      description: map['description'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    String? communityId,
    String? flatId,
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
      communityId: communityId ?? this.communityId,
      flatId: flatId ?? this.flatId,
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
