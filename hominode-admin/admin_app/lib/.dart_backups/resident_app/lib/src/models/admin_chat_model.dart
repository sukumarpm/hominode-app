// lib/src/models/admin_chat_model.dart
// Models for admin chat system

import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin chat status
enum AdminChatStatus {
  open,
  resolved,
  closed,
}

/// Query category
enum QueryCategory {
  billing,
  maintenance,
  amenities,
  complaints,
  building,
  other,
}

/// Extension for QueryCategory
extension QueryCategoryExtension on QueryCategory {
  String get displayName {
    switch (this) {
      case QueryCategory.billing:
        return 'Billing & Payments';
      case QueryCategory.maintenance:
        return 'Maintenance Request';
      case QueryCategory.amenities:
        return 'Amenities & Bookings';
      case QueryCategory.complaints:
        return 'Complaints & Issues';
      case QueryCategory.building:
        return 'Building & Society';
      case QueryCategory.other:
        return 'Other Query';
    }
  }

  String get icon {
    switch (this) {
      case QueryCategory.billing:
        return '💰';
      case QueryCategory.maintenance:
        return '🔧';
      case QueryCategory.amenities:
        return '🏊';
      case QueryCategory.complaints:
        return '📝';
      case QueryCategory.building:
        return '🏢';
      case QueryCategory.other:
        return '❓';
    }
  }

  String get description {
    switch (this) {
      case QueryCategory.billing:
        return 'Questions about bills, receipts';
      case QueryCategory.maintenance:
        return 'Report issues, track repairs';
      case QueryCategory.amenities:
        return 'Questions about facilities';
      case QueryCategory.complaints:
        return 'Report problems, get updates';
      case QueryCategory.building:
        return 'General building questions';
      case QueryCategory.other:
        return 'Any other questions';
    }
  }

  List<String> get templates {
    switch (this) {
      case QueryCategory.billing:
        return [
          'When is my next bill due?',
          'I didn\'t receive my bill',
          'Question about bill amount',
          'Payment confirmation needed',
          'Request payment receipt',
          'Billing discrepancy',
        ];
      case QueryCategory.maintenance:
        return [
          'Plumbing issue in my flat',
          'Electrical problem',
          'Lift not working',
          'Common area maintenance',
          'Track my maintenance request',
          'Emergency repair needed',
        ];
      case QueryCategory.amenities:
        return [
          'How to book amenity?',
          'Booking cancellation',
          'Amenity not available',
          'Question about amenity rules',
          'Booking confirmation',
        ];
      case QueryCategory.complaints:
        return [
          'Noise complaint',
          'Parking issue',
          'Security concern',
          'Cleanliness issue',
          'Track my complaint status',
        ];
      case QueryCategory.building:
        return [
          'Society rules and regulations',
          'Upcoming events',
          'Building announcements',
          'Visitor policy',
          'General inquiry',
        ];
      case QueryCategory.other:
        return [];
    }
  }
}

/// Admin chat model
class AdminChatModel {
  final String id;
  final String buildingId;
  final String adminId;
  final String adminName;
  final String? adminPhoto;
  final String residentId;
  final String residentName;
  final String? residentPhoto;
  final String flatId;
  final String flatNumber;
  final AdminChatStatus status;
  final QueryCategory category;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageBy; // 'resident' or 'admin'
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminChatModel({
    required this.id,
    required this.buildingId,
    required this.adminId,
    required this.adminName,
    this.adminPhoto,
    required this.residentId,
    required this.residentName,
    this.residentPhoto,
    required this.flatId,
    required this.flatNumber,
    required this.status,
    required this.category,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory AdminChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdminChatModel(
      id: doc.id,
      buildingId: data['buildingId'] ?? '',
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? 'Building Admin',
      adminPhoto: data['adminPhoto'],
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'] ?? 'Resident',
      residentPhoto: data['residentPhoto'],
      flatId: data['flatId'] ?? '',
      flatNumber: data['flatNumber'] ?? 'Unknown',
      status: _parseStatus(data['status']),
      category: _parseCategory(data['category']),
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageBy: data['lastMessageBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'buildingId': buildingId,
      'adminId': adminId,
      'adminName': adminName,
      'adminPhoto': adminPhoto,
      'residentId': residentId,
      'residentName': residentName,
      'residentPhoto': residentPhoto,
      'flatId': flatId,
      'flatNumber': flatNumber,
      'status': status.toString().split('.').last,
      'category': category.toString().split('.').last,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageBy': lastMessageBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Parse status from string
  static AdminChatStatus _parseStatus(String? status) {
    switch (status) {
      case 'resolved':
        return AdminChatStatus.resolved;
      case 'closed':
        return AdminChatStatus.closed;
      default:
        return AdminChatStatus.open;
    }
  }

  /// Parse category from string
  static QueryCategory _parseCategory(String? category) {
    switch (category) {
      case 'billing':
        return QueryCategory.billing;
      case 'maintenance':
        return QueryCategory.maintenance;
      case 'amenities':
        return QueryCategory.amenities;
      case 'complaints':
        return QueryCategory.complaints;
      case 'building':
        return QueryCategory.building;
      default:
        return QueryCategory.other;
    }
  }
}

/// Admin chat message model
class AdminChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'resident' or 'admin'
  final String text;
  final bool isQuery;
  final QueryCategory? queryType;
  final DateTime timestamp;
  final List<String> readBy;

  AdminChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.isQuery = false,
    this.queryType,
    required this.timestamp,
    this.readBy = const [],
  });

  /// Create from Firestore document
  factory AdminChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdminChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderRole: data['senderRole'] ?? 'resident',
      text: data['text'] ?? '',
      isQuery: data['isQuery'] ?? false,
      queryType: data['queryType'] != null 
          ? AdminChatModel._parseCategory(data['queryType'])
          : null,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'isQuery': isQuery,
      'queryType': queryType?.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
    };
  }
}
