// lib/src/models/staff_model.dart
// Staff model for maintenance/technician staff assigned to complaints

import 'package:cloud_firestore/cloud_firestore.dart';

class StaffModel {
  final String id;
  final String name;
  final String phone;
  final String role; // 'plumber', 'electrician', 'maintenance', 'cleaner', 'security', 'general'
  final String? email;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StaffModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'email': email,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StaffModel(
      id: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'general',
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory StaffModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() => toMap();

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'general',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'plumber':
        return 'Plumber';
      case 'electrician':
        return 'Electrician';
      case 'maintenance':
        return 'Maintenance Technician';
      case 'cleaner':
        return 'Cleaning Staff';
      case 'security':
        return 'Security Personnel';
      case 'general':
        return 'Support Staff';
      default:
        return role;
    }
  }

  StaffModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    String? email,
    String? avatarUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
