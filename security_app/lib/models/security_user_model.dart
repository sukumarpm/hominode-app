import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityUserModel {
  final String uid;
  final String communityId;
  final String role;
  final bool isActive;

  final String name;
  final String phoneNumber;
  final String? securityId;

  final String? buildingId;
  final String? gateId;
  final String? gateAssignment;

  final String? shift;
  final String? shiftTiming;

  final String? workStatus;
  final String? status;
  final String? specialInstructions;

  final String? photoUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SecurityUserModel({
    required this.uid,
    required this.communityId,
    required this.role,
    required this.isActive,
    required this.name,
    required this.phoneNumber,
    this.securityId,
    this.buildingId,
    this.gateId,
    this.gateAssignment,
    this.shift,
    this.shiftTiming,
    this.workStatus,
    this.status,
    this.specialInstructions,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory SecurityUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      throw StateError('Security profile ${doc.id} has no data.');
    }

    String? readString(dynamic value) {
      if (value is! String) {
        return null;
      }

      final cleaned = value.trim();
      return cleaned.isEmpty ? null : cleaned;
    }

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }

      return null;
    }

    return SecurityUserModel(
      uid: readString(data['uid']) ?? doc.id,
      communityId: readString(data['communityId']) ?? '',
      role: readString(data['role']) ?? '',
      isActive: data['isActive'] == true,
      name: readString(data['name']) ?? '',
      phoneNumber: readString(data['phoneNumber']) ?? '',
      securityId: readString(data['securityId']),
      buildingId: readString(data['buildingId']),
      gateId: readString(data['gateId']),
      gateAssignment: readString(data['gateAssignment']),
      shift: readString(data['shift']),
      shiftTiming: readString(data['shiftTiming']),
      workStatus: readString(data['workStatus']),
      status: readString(data['status']),
      specialInstructions: readString(data['specialInstructions']),
      photoUrl: readString(data['photoUrl']),
      createdAt: readDate(data['createdAt']),
      updatedAt: readDate(data['updatedAt']),
    );
  }

  bool get isValidSecurityProfile {
    return uid.isNotEmpty &&
        communityId.isNotEmpty &&
        role == 'security' &&
        isActive;
  }

  String get displayShift {
    return shiftTiming ?? shift ?? 'Not assigned';
  }

  String get displayGate {
    return gateAssignment ?? 'Not assigned';
  }

  String get displayWorkStatus {
    if (workStatus != null && workStatus!.isNotEmpty) {
      return workStatus!;
    }

    switch (status) {
      case 'on-duty':
        return 'On Duty';
      case 'off-duty':
        return 'Off Duty';
      case 'on-leave':
        return 'On Leave';
      case 'break':
        return 'Break';
      default:
        return 'Off Duty';
    }
  }
}
