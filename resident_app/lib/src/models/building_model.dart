// lib/src/models/building_model.dart
// Building data model

import 'package:cloud_firestore/cloud_firestore.dart';

class BuildingModel {
  final String id;
  final String name;
  final String address;
  final String? description;
  final int totalFloors;
  final int totalFlats;
  final List<String> amenities;
  final DateTime createdAt;
  final DateTime updatedAt;

  BuildingModel({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.totalFloors,
    required this.totalFlats,
    this.amenities = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'totalFloors': totalFloors,
      'totalFlats': totalFlats,
      'amenities': amenities,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory BuildingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BuildingModel(
      id: documentId,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      description: map['description'],
      totalFloors: map['totalFloors'] ?? 0,
      totalFlats: map['totalFlats'] ?? 0,
      amenities: List<String>.from(map['amenities'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory BuildingModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return BuildingModel.fromMap(data, snapshot.id);
  }

  BuildingModel copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    int? totalFloors,
    int? totalFlats,
    List<String>? amenities,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuildingModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      totalFloors: totalFloors ?? this.totalFloors,
      totalFlats: totalFlats ?? this.totalFlats,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
