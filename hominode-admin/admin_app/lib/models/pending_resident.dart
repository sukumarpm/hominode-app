import 'package:cloud_firestore/cloud_firestore.dart';

class PendingResident {
  const PendingResident({
    required this.uid,
    required this.name,
    required this.phoneNumber,
    required this.communityId,
    required this.buildingReference,
    required this.unitReference,
    required this.approvalStatus,
    required this.isActive,
    this.email,
    this.buildingId,
    this.flatId,
    this.unitId,
    this.buildingName,
    this.flatLabel,
    this.residentType,
    this.creationSource,
    this.declaredResidentType,
    this.identityVerificationStatus = 'verification_required',
    this.hasIdentityProof = false,
    this.registeredAt,
  });

  final String uid;
  final String name;
  final String phoneNumber;
  final String communityId;
  final String buildingReference;
  final String unitReference;
  final String approvalStatus;
  final bool isActive;
  final String? email;
  final String? buildingId;
  final String? flatId;
  final String? unitId;
  final String? buildingName;
  final String? flatLabel;
  final String? residentType;
  final String? creationSource;
  final String? declaredResidentType;
  final String identityVerificationStatus;
  final bool hasIdentityProof;
  final DateTime? registeredAt;

  factory PendingResident.fromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    String reference(dynamic value) {
      if (value is String) return value;
      if (value is Map) {
        return (value['name'] ??
                value['label'] ??
                value['id'] ??
                value.toString())
            .toString();
      }
      return value?.toString() ?? '';
    }

    final timestamp =
        data['createdAt'] ??
        data['registrationTimestamp'] ??
        data['registeredAt'];
    return PendingResident(
      uid: documentId,
      name: (data['name'] ?? data['fullName'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? data['phone'] ?? '').toString(),
      communityId: (data['communityId'] ?? '').toString(),
      buildingReference: reference(
        data['buildingReference'] ?? data['buildingName'] ?? data['buildingId'],
      ),
      unitReference: reference(
        data['unitReference'] ??
            data['flatLabel'] ??
            data['unitId'] ??
            data['flatId'],
      ),
      approvalStatus: (data['approvalStatus'] ?? '').toString(),
      isActive: data['isActive'] == true,
      email: (data['email'] as String?)?.trim().isEmpty == true
          ? null
          : data['email'] as String?,
      buildingId: data['buildingId']?.toString(),
      flatId: data['flatId']?.toString(),
      unitId: data['unitId']?.toString(),
      buildingName: data['buildingName']?.toString(),
      flatLabel: data['flatLabel']?.toString(),
      residentType: (data['residentType'] ?? data['ownershipType'])?.toString(),
      creationSource: data['creationSource']?.toString(),
      declaredResidentType: data['declaredResidentType']?.toString(),
      identityVerificationStatus:
          data['identityVerificationStatus']?.toString() ??
          (data['identityVerified'] == true
              ? 'verified'
              : 'verification_required'),
      hasIdentityProof:
          data['identityProofStoragePath'] is String &&
          (data['identityProofStoragePath'] as String).trim().isNotEmpty,
      registeredAt: timestamp is Timestamp
          ? timestamp.toDate()
          : timestamp is DateTime
          ? timestamp
          : null,
    );
  }
}

class ResidentApprovalPolicy {
  static bool isPendingForCommunity(
    Map<String, dynamic> user,
    String communityId,
  ) =>
      user['communityId'] == communityId &&
      user['role'] == 'resident' &&
      user['approvalStatus'] == 'pending' &&
      user['isActive'] == false;

  static bool canReview(Map<String, dynamic> user, String communityId) =>
      user['communityId'] == communityId && user['role'] == 'resident';

  static bool canonicalAssignmentMatches({
    required Map<String, dynamic> building,
    required Map<String, dynamic> unit,
    required String communityId,
    required String buildingId,
  }) =>
      building['communityId'] == communityId &&
      unit['communityId'] == communityId &&
      unit['buildingId'] == buildingId;

  static bool flatCanBeAssigned(
    Map<String, dynamic> flat,
    String residentUserId,
  ) {
    final status = (flat['status'] ?? 'vacant').toString();
    final assignedUser = flat['residentUserId']?.toString();
    return status == 'vacant' ||
        (status == 'occupied' && assignedUser == residentUserId);
  }
}
