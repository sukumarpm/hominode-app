// lib/src/models/visitor_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitorModel {
  final String id;
  final String communityId;
  final String flatId;
  final String? flatLabel;
  final String? adminId;
  final String hostUserId;
  final String visitorName;
  final String? visitorPhone;
  final String purpose;
  final DateTime expectedArrival;
  final DateTime? actualArrival;
  final DateTime? departure;
  final String status; // 'expected', 'arrived', 'departed', 'cancelled'
  final String? vehicleNumber;
  final String? photoUrl;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  VisitorModel({
    required this.id,
    this.communityId = '',
    required this.flatId,
    this.flatLabel,
    this.adminId,
    required this.hostUserId,
    required this.visitorName,
    this.visitorPhone,
    required this.purpose,
    required this.expectedArrival,
    this.actualArrival,
    this.departure,
    this.status = 'expected',
    this.vehicleNumber,
    this.photoUrl,
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'communityId': communityId,
      'flatId': flatId,
      'flatLabel': flatLabel,
      'adminId': adminId,
      'hostUserId': hostUserId,
      'visitorName': visitorName,
      'visitorPhone': visitorPhone,
      'purpose': purpose,
      'expectedArrival': Timestamp.fromDate(expectedArrival),
      'actualArrival': actualArrival != null
          ? Timestamp.fromDate(actualArrival!)
          : null,
      'departure': departure != null ? Timestamp.fromDate(departure!) : null,
      'status': status,
      'vehicleNumber': vehicleNumber,
      'photoUrl': photoUrl,
      'approvedBy': approvedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() => toMap();

  factory VisitorModel.fromJson(Map<String, dynamic> json) {
    return VisitorModel(
      id: json['id'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      flatId: json['flatId'] as String? ?? '',
      flatLabel: json['flatLabel'] as String?,
      adminId: json['adminId'] as String?,
      hostUserId: json['hostUserId'] as String? ?? '',
      visitorName: json['visitorName'] as String? ?? '',
      visitorPhone: json['visitorPhone'] as String?,
      purpose: json['purpose'] as String? ?? '',
      expectedArrival:
          (json['expectedArrival'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualArrival: (json['actualArrival'] as Timestamp?)?.toDate(),
      departure: (json['departure'] as Timestamp?)?.toDate(),
      status: json['status'] as String? ?? 'expected',
      vehicleNumber: json['vehicleNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      approvedBy: json['approvedBy'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory VisitorModel.fromMap(Map<String, dynamic> map, String documentId) {
    return VisitorModel(
      id: documentId,
      communityId: map['communityId'] as String? ?? '',
      flatId: map['flatId'] ?? '',
      flatLabel: map['flatLabel'],
      adminId: map['adminId'],
      hostUserId: map['hostUserId'] ?? '',
      visitorName: map['visitorName'] ?? '',
      visitorPhone: map['visitorPhone'],
      purpose: map['purpose'] ?? '',
      expectedArrival:
          (map['expectedArrival'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualArrival: (map['actualArrival'] as Timestamp?)?.toDate(),
      departure: (map['departure'] as Timestamp?)?.toDate(),
      status: map['status'] ?? 'expected',
      vehicleNumber: map['vehicleNumber'],
      photoUrl: map['photoUrl'],
      approvedBy: map['approvedBy'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory VisitorModel.fromSnapshot(DocumentSnapshot snapshot) {
    return VisitorModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  factory VisitorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitorModel.fromMap(data, doc.id);
  }

  bool get hasArrived => actualArrival != null;
  bool get hasDeparted => departure != null;
  bool get isActive => status == 'arrived' || status == 'expected';

  VisitorModel copyWith({
    String? id,
    String? communityId,
    String? flatId,
    String? flatLabel,
    String? adminId,
    String? hostUserId,
    String? visitorName,
    String? visitorPhone,
    String? purpose,
    DateTime? expectedArrival,
    DateTime? actualArrival,
    DateTime? departure,
    String? status,
    String? vehicleNumber,
    String? photoUrl,
    String? approvedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VisitorModel(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      flatId: flatId ?? this.flatId,
      flatLabel: flatLabel ?? this.flatLabel,
      adminId: adminId ?? this.adminId,
      hostUserId: hostUserId ?? this.hostUserId,
      visitorName: visitorName ?? this.visitorName,
      visitorPhone: visitorPhone ?? this.visitorPhone,
      purpose: purpose ?? this.purpose,
      expectedArrival: expectedArrival ?? this.expectedArrival,
      actualArrival: actualArrival ?? this.actualArrival,
      departure: departure ?? this.departure,
      status: status ?? this.status,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
