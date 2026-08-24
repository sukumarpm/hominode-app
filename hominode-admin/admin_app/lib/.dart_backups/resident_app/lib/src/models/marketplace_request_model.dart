import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceRequestModel {
  final String? id;
  final String productId;
  final String productOwnerId;
  final String requestUserId;
  final String requestUserName;
  final String requestUserFlat;
  final String buildingId;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  MarketplaceRequestModel({
    this.id,
    required this.productId,
    required this.productOwnerId,
    required this.requestUserId,
    required this.requestUserName,
    required this.requestUserFlat,
    required this.buildingId,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MarketplaceRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketplaceRequestModel(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productOwnerId: data['productOwnerId'] as String? ?? '',
      requestUserId: data['requestUserId'] as String? ?? '',
      requestUserName: data['requestUserName'] as String? ?? 'Unknown',
      requestUserFlat: data['requestUserFlat'] as String? ?? 'N/A',
      buildingId: data['buildingId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productOwnerId': productOwnerId,
      'requestUserId': requestUserId,
      'requestUserName': requestUserName,
      'requestUserFlat': requestUserFlat,
      'buildingId': buildingId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
