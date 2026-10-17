import 'package:cloud_firestore/cloud_firestore.dart';

class VisitorModel {
  final String id;
  final String visitorName;
  final String phone;
  final String residentId;
  final String residentName;
  final String flatId;
  final String flatLabel;
  final String purpose;
  final DateTime? expectedTime;
  final String status; // For compatibility
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? updatedAt;

  // Additional fields from Firestore structure
  final bool isApproved;
  final DateTime? actualArrival;
  final DateTime? departure;
  final String? approvedBy;
  final String gateAccessStatus;
  final String? gateEntryDenialReason;
  final DateTime? gateEntryDeniedAt;

  VisitorModel({
    required this.id,
    required this.visitorName,
    required this.phone,
    required this.residentId,
    required this.residentName,
    required this.flatId,
    required this.flatLabel,
    required this.purpose,
    this.expectedTime,
    required this.status,
    this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.checkInTime,
    this.checkOutTime,
    this.updatedAt,
    this.isApproved = false,
    this.actualArrival,
    this.departure,
    this.approvedBy,
    this.gateAccessStatus = 'eligible',
    this.gateEntryDenialReason,
    this.gateEntryDeniedAt,
  });

  factory VisitorModel.fromSanitizedMap(Map<String, dynamic> data) {
    DateTime? date(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    return VisitorModel(
      id: data['visitorId']?.toString() ?? '',
      visitorName: data['visitorName']?.toString() ?? 'Visitor',
      phone: data['phoneNumber']?.toString() ?? '',
      residentId: '',
      residentName: data['hostName']?.toString() ?? 'Resident',
      flatId: data['flatId']?.toString() ?? '',
      flatLabel: data['flatLabel']?.toString() ?? '',
      purpose: data['purpose']?.toString() ?? '',
      expectedTime: date('expectedArrival'),
      status: data['status']?.toString() ?? '',
      isApproved: data['adminApproved'] == true,
      actualArrival: date('actualArrival'),
      departure: date('departure'),
      gateAccessStatus: data['gateAccessStatus']?.toString() ?? 'eligible',
      gateEntryDenialReason: data['gateEntryDenialReason']?.toString(),
      gateEntryDeniedAt: date('gateEntryDeniedAt'),
    );
  }

  factory VisitorModel.fromFirestore(String id, Map<String, dynamic> data) {
    // Map Firestore fields to the model
    final isApproved = data['isApproved'] ?? false;
    final actualArrival = (data['actualArrival'] as Timestamp?)?.toDate();
    final departure = (data['departure'] as Timestamp?)?.toDate();

    // Preserve the canonical physical status when available. Legacy records
    // without it derive gate state from timestamps, independent of approval.
    final storedStatus = data['status'];
    final terminalStates = {
      'completed',
      'checked-out',
      'checked_out',
      'departed',
      'exited',
      'rejected',
      'cancelled',
      'canceled',
      'denied',
    };
    final String status = departure != null
        ? 'checked-out'
        : storedStatus is String && terminalStates.contains(storedStatus)
        ? storedStatus
        : actualArrival != null
        ? 'inside'
        : storedStatus is String && storedStatus.isNotEmpty
        ? storedStatus
        : isApproved
        ? 'approved'
        : 'expected';

    return VisitorModel(
      id: id,
      visitorName: data['visitorName'] ?? data['hostName'] ?? '',
      phone: data['phone'] ?? data['phoneNumber'] ?? '',
      residentId: data['residentId'] ?? data['hostUserId'] ?? '',
      residentName: data['residentName'] ?? data['hostName'] ?? '',
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      purpose: data['purpose'] ?? '',
      expectedTime:
          (data['expectedTime'] ?? data['expectedArrival'] as Timestamp?)
              ?.toDate(),
      status: status,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      checkInTime: (data['checkInTime'] ?? data['actualArrival'] as Timestamp?)
          ?.toDate(),
      checkOutTime: (data['checkOutTime'] ?? data['departure'] as Timestamp?)
          ?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isApproved: isApproved,
      actualArrival: actualArrival,
      departure: departure,
      approvedBy: data['approvedBy'],
      gateAccessStatus: data['gateAccessStatus']?.toString() ?? 'eligible',
      gateEntryDenialReason: data['gateEntryDenialReason']?.toString(),
      gateEntryDeniedAt: (data['gateEntryDeniedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visitorName': visitorName,
      'phone': phone,
      'residentId': residentId,
      'residentName': residentName,
      'flatId': flatId,
      'flatLabel': flatLabel,
      'purpose': purpose,
      'expectedTime': expectedTime != null
          ? Timestamp.fromDate(expectedTime!)
          : null,
      'status': status,
      'isApproved': isApproved,
      'actualArrival': actualArrival != null
          ? Timestamp.fromDate(actualArrival!)
          : null,
      'departure': departure != null ? Timestamp.fromDate(departure!) : null,
    };
  }

  String get formattedCreatedAt {
    if (createdAt == null) return '';
    return '${createdAt!.year}-${createdAt!.month.toString().padLeft(2, '0')}-${createdAt!.day.toString().padLeft(2, '0')}';
  }
}
