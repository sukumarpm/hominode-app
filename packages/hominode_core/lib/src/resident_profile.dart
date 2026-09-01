class ResidentProfile {
  const ResidentProfile({
    required this.uid,
    required this.communityId,
    required this.isActive,
    required this.approvalStatus,
  });

  final String uid;
  final String communityId;
  final bool isActive;
  final String approvalStatus;

  bool get canEnter =>
      isActive && approvalStatus == 'approved' && communityId.isNotEmpty;

  static ResidentProfile? tryParse(
    String documentId,
    Map<String, dynamic> data,
  ) {
    if (data['role'] != 'resident' || data['isActive'] is! bool) {
      return null;
    }

    final isActive = data['isActive'] == true;
    final storedApprovalStatus = _string(data['approvalStatus']);

    return ResidentProfile(
      uid: documentId,
      communityId: _string(data['communityId']),
      isActive: isActive,
      approvalStatus: storedApprovalStatus.isNotEmpty
          ? storedApprovalStatus
          : (isActive ? 'approved' : 'blocked'),
    );
  }
}

String _string(Object? value) => value is String ? value.trim() : '';
