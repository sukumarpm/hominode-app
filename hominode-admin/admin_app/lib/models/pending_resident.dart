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
    this.status,
    this.identityVerified = false,
    this.registrationCompleted = false,
    this.ownerIdentityVerificationRequired = false,
    this.occupancyStatus,
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
  final bool? isActive;
  final String? email;
  final String? status;
  final bool? identityVerified;
  final bool registrationCompleted;
  final bool ownerIdentityVerificationRequired;
  final String? occupancyStatus;
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

  bool get canApproveRegistration =>
      approvalStatus == 'pending' &&
      isActive == false &&
      creationSource != 'admin_direct' &&
      status != 'deleted';

  bool get awaitingAdminIdentityApproval =>
      creationSource == 'admin_direct' &&
      ['pending', 'approved'].contains(approvalStatus) &&
      isActive != null &&
      identityVerified == false &&
      !registrationCompleted &&
      [
        'verification_required',
        'pending',
        'rejected',
      ].contains(identityVerificationStatus) &&
      !['deleted', 'completed', 'rejected'].contains(status) &&
      !['moved_out', 'suspended', 'rejected'].contains(occupancyStatus) &&
      ((residentType ?? declaredResidentType) == 'tenant' ||
          (residentType ?? declaredResidentType) == 'owner' &&
              ownerIdentityVerificationRequired);

  bool get canReviewRegistration =>
      !registrationCompleted &&
      identityVerified != true &&
      identityVerificationStatus != 'verified' &&
      !['deleted', 'completed'].contains(status) &&
      (canApproveRegistration || awaitingAdminIdentityApproval);

  factory PendingResident.fromMap(
    String documentId,
    Map<String, dynamic> data, {
    bool ownerIdentityVerificationRequired = false,
  }) {
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
      status: data['status']?.toString(),
      identityVerified: data['identityVerified'] is bool
          ? data['identityVerified'] as bool
          : null,
      registrationCompleted: data['registrationCompletedAt'] != null,
      occupancyStatus: data['occupancyStatus']?.toString(),
      ownerIdentityVerificationRequired: ownerIdentityVerificationRequired,
      isActive: data['isActive'] is bool ? data['isActive'] as bool : null,
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
          (data['creationSource'] == 'admin_direct'
              ? ''
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
  static bool needsReviewForCommunity(
    Map<String, dynamic> user,
    String communityId, {
    bool ownerIdentityVerificationRequired = false,
  }) {
    if (!canReview(user, communityId) || user['status'] == 'deleted') {
      return false;
    }
    final resident = PendingResident.fromMap(
      '',
      user,
      ownerIdentityVerificationRequired: ownerIdentityVerificationRequired,
    );
    return resident.canApproveRegistration ||
        resident.canReviewRegistration ||
        (resident.approvalStatus == 'approved' &&
            resident.identityVerificationStatus == 'pending' &&
            resident.hasIdentityProof);
  }

  static bool isPendingForCommunity(
    Map<String, dynamic> user,
    String communityId, {
    bool ownerIdentityVerificationRequired = false,
  }) =>
      canReview(user, communityId) &&
      PendingResident.fromMap(
        '',
        user,
        ownerIdentityVerificationRequired: ownerIdentityVerificationRequired,
      ).canReviewRegistration;

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
