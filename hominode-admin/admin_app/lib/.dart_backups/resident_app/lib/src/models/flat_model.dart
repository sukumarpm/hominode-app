// lib/src/models/flat_model.dart
// Flat/Apartment data model

import 'package:cloud_firestore/cloud_firestore.dart';

class FlatModel {
  final String id;
  final String buildingId;
  final String communityId;
  final String flatNumber;
  final String block;
  final int floor;
  final String? ownerId; // User ID of owner
  final List<String> residentIds; // User IDs of residents
  final double area; // in sq ft
  final int bedrooms;
  final int bathrooms;
  final String status; // 'occupied', 'vacant', 'maintenance'
  final DateTime createdAt;
  final DateTime updatedAt;

  FlatModel({
    required this.id,
    required this.buildingId,
    this.communityId = '',
    required this.flatNumber,
    required this.block,
    required this.floor,
    this.ownerId,
    this.residentIds = const [],
    this.area = 0,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.status = 'vacant',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buildingId': buildingId,
      'communityId': communityId,
      'flatNumber': flatNumber,
      'block': block,
      'floor': floor,
      'ownerId': ownerId,
      'residentIds': residentIds,
      'area': area,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory FlatModel.fromJson(Map<String, dynamic> json) {
    return FlatModel(
      id: json['id'] as String? ?? '',
      buildingId: json['buildingId'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      flatNumber: json['flatNumber'] as String? ?? '',
      block: json['block'] as String? ?? '',
      floor: json['floor'] as int? ?? 0,
      ownerId: json['ownerId'] as String?,
      residentIds:
          (json['residentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      area: (json['area'] as num?)?.toDouble() ?? 0,
      bedrooms: json['bedrooms'] as int? ?? 0,
      bathrooms: json['bathrooms'] as int? ?? 0,
      status: json['status'] as String? ?? 'vacant',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory FlatModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FlatModel(
      id: documentId,
      buildingId: map['buildingId'] ?? '',
      communityId: map['communityId'] ?? '',
      flatNumber: map['flatNumber'] ?? '',
      block: map['block'] ?? '',
      floor: map['floor'] ?? 0,
      ownerId: map['ownerId'],
      residentIds: List<String>.from(map['residentIds'] ?? []),
      area: (map['area'] ?? 0).toDouble(),
      bedrooms: map['bedrooms'] ?? 0,
      bathrooms: map['bathrooms'] ?? 0,
      status: map['status'] ?? 'vacant',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory FlatModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return FlatModel.fromMap(data, snapshot.id);
  }

  factory FlatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlatModel.fromMap(data, doc.id);
  }

  FlatModel copyWith({
    String? id,
    String? buildingId,
    String? communityId,
    String? flatNumber,
    String? block,
    int? floor,
    String? ownerId,
    List<String>? residentIds,
    double? area,
    int? bedrooms,
    int? bathrooms,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FlatModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      communityId: communityId ?? this.communityId,
      flatNumber: flatNumber ?? this.flatNumber,
      block: block ?? this.block,
      floor: floor ?? this.floor,
      ownerId: ownerId ?? this.ownerId,
      residentIds: residentIds ?? this.residentIds,
      area: area ?? this.area,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
