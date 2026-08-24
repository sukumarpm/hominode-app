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
    if (data['role'] != 'resident' || data['isActive'] is! bool) return null;
    final storedUid = _string(data['uid']);
    if (storedUid.isNotEmpty && storedUid != documentId) return null;
    return ResidentProfile(
      uid: documentId,
      communityId: _string(data['communityId']),
      isActive: data['isActive'] == true,
      approvalStatus: _string(data['approvalStatus']),
    );
  }
}

String _string(Object? value) => value is String ? value.trim() : '';
