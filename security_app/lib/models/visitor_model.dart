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
  });

  factory VisitorModel.fromFirestore(String id, Map<String, dynamic> data) {
    // Map Firestore fields to the model
    final isApproved = data['isApproved'] ?? false;
    final actualArrival = (data['actualArrival'] as Timestamp?)?.toDate();
    final departure = (data['departure'] as Timestamp?)?.toDate();
    
    // Determine status based on fields
    String status;
    if (departure != null) {
      status = 'checked-out';
    } else if (actualArrival != null && isApproved) {
      status = 'active';
    } else if (isApproved) {
      status = 'approved';
    } else {
      status = 'pending';
    }
    
    return VisitorModel(
      id: id,
      visitorName: data['visitorName'] ?? data['hostName'] ?? '',
      phone: data['phone'] ?? data['phoneNumber'] ?? '',
      residentId: data['residentId'] ?? data['hostUserId'] ?? '',
      residentName: data['residentName'] ?? data['hostName'] ?? '',
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      purpose: data['purpose'] ?? '',
      expectedTime: (data['expectedTime'] ?? data['expectedArrival'] as Timestamp?)?.toDate(),
      status: status,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      checkInTime: (data['checkInTime'] ?? data['actualArrival'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] ?? data['departure'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isApproved: isApproved,
      actualArrival: actualArrival,
      departure: departure,
      approvedBy: data['approvedBy'],
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
      'expectedTime': expectedTime != null ? Timestamp.fromDate(expectedTime!) : null,
      'status': status,
      'isApproved': isApproved,
      'actualArrival': actualArrival != null ? Timestamp.fromDate(actualArrival!) : null,
      'departure': departure != null ? Timestamp.fromDate(departure!) : null,
    };
  }

  String get formattedCreatedAt {
    if (createdAt == null) return '';
    return '${createdAt!.year}-${createdAt!.month.toString().padLeft(2, '0')}-${createdAt!.day.toString().padLeft(2, '0')}';
  }
}
