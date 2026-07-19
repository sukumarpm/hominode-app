// lib/src/models/resident_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentModel {
  final String id;
  final String userId;
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
      'flatId': flatId,
      'relationship': relationship,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'moveOutDate': moveOutDate != null ? Timestamp.fromDate(moveOutDate!) : null,
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
      flatId: json['flatId'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      moveInDate: (json['moveInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    return ResidentModel.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
  }

  factory ResidentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResidentModel.fromMap(data, doc.id);
  }

  ResidentModel copyWith({
    String? id,
    String? userId,
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
