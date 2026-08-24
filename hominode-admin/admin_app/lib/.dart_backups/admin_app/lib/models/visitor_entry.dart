/// Visitor Entry Model
/// 
/// Represents a visitor entry in the society management system.
library;

enum VisitorStatus {
  pending,
  active,
  history,
}

class VisitorEntry {
  final String id;
  final String visitorName;
  final String phone;
  final String residentName;
  final String unit;
  final String purpose;
  final DateTime requestedTime;
  VisitorStatus status;

  VisitorEntry({
    required this.id,
    required this.visitorName,
    required this.phone,
    required this.residentName,
    required this.unit,
    required this.purpose,
    required this.requestedTime,
    required this.status,
  });

  // TODO: Connect to backend API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitorName': visitorName,
      'phone': phone,
      'residentName': residentName,
      'unit': unit,
      'purpose': purpose,
      'requestedTime': requestedTime.toIso8601String(),
      'status': status.name,
    };
  }

  factory VisitorEntry.fromJson(Map<String, dynamic> json) {
    return VisitorEntry(
      id: json['id'] as String,
      visitorName: json['visitorName'] as String,
      phone: json['phone'] as String,
      residentName: json['residentName'] as String,
      unit: json['unit'] as String,
      purpose: json['purpose'] as String,
      requestedTime: DateTime.parse(json['requestedTime'] as String),
      status: VisitorStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => VisitorStatus.pending,
      ),
    );
  }
}
