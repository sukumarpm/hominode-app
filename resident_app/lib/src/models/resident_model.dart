// lib/src/models/resident_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentModel {
  final String id;
  final String userId;
  final String communityId;
  final String role;
  final bool isActive;
  final String flatId;
  final String relationship; // 'owner', 'tenant', 'family'
  final DateTime moveInDate;
  final DateTime? moveOutDate;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResidentModel({
    required this.id,
    required this.userId,
    this.communityId = '',
    this.role = 'resident',
    this.isActive = true,
    required this.flatId,
    required this.relationship,
    required this.moveInDate,
    this.moveOutDate,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'communityId': communityId,
      'role': role,
      'isActive': isActive,
      'flatId': flatId,
      'relationship': relationship,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'moveOutDate': moveOutDate != null
          ? Timestamp.fromDate(moveOutDate!)
          : null,
      'isPrimary': isPrimary,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory ResidentModel.fromJson(Map<String, dynamic> json) {
    return ResidentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      role: json['role'] as String? ?? 'resident',
      isActive: json['isActive'] as bool? ?? true,
      flatId: json['flatId'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      moveInDate:
          (json['moveInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      moveOutDate: (json['moveOutDate'] as Timestamp?)?.toDate(),
      isPrimary: json['isPrimary'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ResidentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ResidentModel(
      id: documentId,
      userId: map['userId'] ?? '',
      communityId: map['communityId'] ?? '',
      role: map['role'] ?? 'resident',
      isActive: map['isActive'] ?? true,
      flatId: map['flatId'] ?? '',
      relationship: map['relationship'] ?? '',
      moveInDate: (map['moveInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      moveOutDate: (map['moveOutDate'] as Timestamp?)?.toDate(),
      isPrimary: map['isPrimary'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ResidentModel.fromSnapshot(DocumentSnapshot snapshot) {
    return ResidentModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  factory ResidentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResidentModel.fromMap(data, doc.id);
  }

  ResidentModel copyWith({
    String? id,
    String? userId,
    String? communityId,
    String? role,
    bool? isActive,
    String? flatId,
    String? relationship,
    DateTime? moveInDate,
    DateTime? moveOutDate,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ResidentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      flatId: flatId ?? this.flatId,
      relationship: relationship ?? this.relationship,
      moveInDate: moveInDate ?? this.moveInDate,
      moveOutDate: moveOutDate ?? this.moveOutDate,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
