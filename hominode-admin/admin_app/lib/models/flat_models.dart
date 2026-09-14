/// Central data models for flat management system
/// This file defines the single source of truth for buildings, floors, and flats
library;

enum FlatStatus { vacant, reserved, occupied, maintenance }

/// Resident model with complete information
class Resident {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String type; // Owner / Tenant / Lease
  final int familyMembers;
  final String? generatedPassword; // For newly created residents

  Resident({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.type,
    this.familyMembers = 1,
    this.generatedPassword,
  });

  Resident copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? type,
    int? familyMembers,
    String? generatedPassword,
  }) {
    return Resident(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      type: type ?? this.type,
      familyMembers: familyMembers ?? this.familyMembers,
      generatedPassword: generatedPassword ?? this.generatedPassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'type': type,
      'familyMembers': familyMembers,
    };
  }

  factory Resident.fromJson(Map<String, dynamic> json) {
    return Resident(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      type: json['type'] as String,
      familyMembers: json['familyMembers'] as int? ?? 1,
    );
  }
}

/// FlatUnit model - represents a single flat with all its properties
class FlatUnit {
  final String id; // e.g., "A101" - sequential ID
  final String docId; // Firestore document ID
  final int floor; // 1..N
  final String config; // "2BHK", "3BHK", etc.
  final int areaSqft;
  FlatStatus status;
  Resident? resident; // null if vacant/maintenance

  FlatUnit({
    required this.id,
    required this.docId,
    required this.floor,
    required this.config,
    required this.areaSqft,
    required this.status,
    this.resident,
  });

  /// Helper to get area as formatted string
  String get areaFormatted => '$areaSqft Sqft';

  /// Helper to check if flat has a resident
  bool get hasResident => resident != null;

  /// Helper to get resident name or default text
  String get residentNameOrDefault => resident?.name ?? 'Vacant';

  FlatUnit copyWith({
    String? id,
    String? docId,
    int? floor,
    String? config,
    int? areaSqft,
    FlatStatus? status,
    Resident? resident,
    bool clearResident = false,
  }) {
    return FlatUnit(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      floor: floor ?? this.floor,
      config: config ?? this.config,
      areaSqft: areaSqft ?? this.areaSqft,
      status: status ?? this.status,
      resident: clearResident ? null : (resident ?? this.resident),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'floor': floor,
      'config': config,
      'areaSqft': areaSqft,
      'status': status.name,
      'resident': resident?.toJson(),
    };
  }

  factory FlatUnit.fromJson(Map<String, dynamic> json) {
    return FlatUnit(
      id: json['id'] as String,
      docId: json['docId'] as String? ?? json['id'] as String,
      floor: json['floor'] as int,
      config: json['config'] as String,
      areaSqft: json['areaSqft'] as int,
      status: FlatStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => FlatStatus.maintenance,
      ),
      resident: json['resident'] != null
          ? Resident.fromJson(json['resident'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Building model - represents a tower/building with multiple floors
class Building {
  final String id;
  final String name;
  final int totalFloors;
  final Map<String, FlatUnit> flatsById; // Central store for all flats

  Building({
    required this.id,
    required this.name,
    required this.totalFloors,
    required this.flatsById,
  });

  /// Get all flats for a specific floor
  List<FlatUnit> getFlatsForFloor(int floor) {
    return flatsById.values.where((flat) => flat.floor == floor).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Get flat by ID
  FlatUnit? getFlatById(String flatId) {
    return flatsById[flatId];
  }

  /// Get counts by status
  int get vacantCount =>
      flatsById.values.where((f) => f.status == FlatStatus.vacant).length;
  int get occupiedCount =>
      flatsById.values.where((f) => f.status == FlatStatus.occupied).length;
  int get maintenanceCount =>
      flatsById.values.where((f) => f.status == FlatStatus.maintenance).length;
  int get totalFlats => flatsById.length;

  Building copyWith({
    String? id,
    String? name,
    int? totalFloors,
    Map<String, FlatUnit>? flatsById,
  }) {
    return Building(
      id: id ?? this.id,
      name: name ?? this.name,
      totalFloors: totalFloors ?? this.totalFloors,
      flatsById: flatsById ?? Map.from(this.flatsById),
    );
  }
}
