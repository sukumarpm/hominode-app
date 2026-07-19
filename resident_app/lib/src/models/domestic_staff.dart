// lib/src/models/domestic_staff.dart
class DomesticStaff {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String? avatarUrl;
  final bool isActive;
  final String schedule;
  final DateTime? lastEntry;

  DomesticStaff({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.avatarUrl,
    required this.isActive,
    required this.schedule,
    this.lastEntry,
  });

  factory DomesticStaff.fromJson(Map<String, dynamic> json) {
    return DomesticStaff(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      isActive: json['isActive'] ?? true,
      schedule: json['schedule'],
      lastEntry: json['lastEntry'] != null ? DateTime.parse(json['lastEntry']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'schedule': schedule,
      'lastEntry': lastEntry?.toIso8601String(),
    };
  }
}

class StaffAttendance {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;

  StaffAttendance({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    this.checkIn,
    this.checkOut,
  });

  factory StaffAttendance.fromJson(Map<String, dynamic> json) {
    return StaffAttendance(
      id: json['id'],
      staffId: json['staffId'],
      staffName: json['staffName'],
      date: DateTime.parse(json['date']),
      checkIn: json['checkIn'] != null ? DateTime.parse(json['checkIn']) : null,
      checkOut: json['checkOut'] != null ? DateTime.parse(json['checkOut']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'date': date.toIso8601String(),
      'checkIn': checkIn?.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
    };
  }
}
