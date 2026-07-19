import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  final String? id;
  final String title;
  final int price;
  final String category;
  final String condition;
  final String description;
  final List<String> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String sellerId;
  final String sellerName;
  final String? sellerPhone;
  final String buildingId;
  final String status; // active, sold, deleted
  final int phoneRequestCount; // Number of phone requests
  final List<String> phoneRequestIds; // IDs of users who requested phone

  ListingModel({
    this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.condition,
    required this.description,
    this.images = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.sellerId,
    required this.sellerName,
    this.sellerPhone,
    required this.buildingId,
    this.status = 'active',
    this.phoneRequestCount = 0,
    this.phoneRequestIds = const [],
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ListingModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      price: data['price'] as int? ?? 0,
      category: data['category'] as String? ?? '',
      condition: data['condition'] as String? ?? '',
      description: data['description'] as String? ?? '',
      images: List<String>.from(data['images'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? 'Unknown',
      sellerPhone: data['sellerPhone'],
      buildingId: data['buildingId'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      phoneRequestCount: data['phoneRequestCount'] as int? ?? 0,
      phoneRequestIds: List<String>.from(data['phoneRequestIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'price': price,
      'category': category,
      'condition': condition,
      'description': description,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerPhone': sellerPhone,
      'buildingId': buildingId,
      'status': status,
      'phoneRequestCount': phoneRequestCount,
      'phoneRequestIds': phoneRequestIds,
    };
  }

  String get formattedPrice => '₹${price.toString()}';

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }
}
