// lib/src/models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String communityId;
  final String billId;
  final String flatId;
  final String userId;
  final double amount;
  final String method; // 'cash', 'card', 'upi', 'bank_transfer'
  final String status; // 'pending', 'completed', 'failed', 'refunded'
  final String? transactionId;
  final String? receiptUrl;
  final DateTime paymentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    this.communityId = '',
    required this.billId,
    required this.flatId,
    required this.userId,
    required this.amount,
    required this.method,
    this.status = 'pending',
    this.transactionId,
    this.receiptUrl,
    required this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'billId': billId,
      'flatId': flatId,
      'userId': userId,
      'amount': amount,
      'method': method,
      'status': status,
      'transactionId': transactionId,
      'receiptUrl': receiptUrl,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      billId: json['billId'] as String? ?? '',
      flatId: json['flatId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      transactionId: json['transactionId'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      paymentDate:
          (json['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PaymentModel(
      id: documentId,
      communityId: map['communityId'] as String? ?? '',
      billId: map['billId'] ?? '',
      flatId: map['flatId'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      method: map['method'] ?? '',
      status: map['status'] ?? 'pending',
      transactionId: map['transactionId'],
      receiptUrl: map['receiptUrl'],
      paymentDate:
          (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PaymentModel.fromSnapshot(DocumentSnapshot snapshot) {
    return PaymentModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel.fromMap(data, doc.id);
  }

  bool get isSuccessful => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  PaymentModel copyWith({
    String? id,
    String? communityId,
    String? billId,
    String? flatId,
    String? userId,
    double? amount,
    String? method,
    String? status,
    String? transactionId,
    String? receiptUrl,
    DateTime? paymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      billId: billId ?? this.billId,
      flatId: flatId ?? this.flatId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
