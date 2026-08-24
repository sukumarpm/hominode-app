enum AdminRole { superAdmin, admin }

class AdminProfile {
  const AdminProfile({
    required this.uid,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    required this.authorizedCommunityIds,
  });
  final String uid;
  final String phoneNumber;
  final AdminRole role;
  final bool isActive;
  final List<String> authorizedCommunityIds;
  bool get isSuperAdmin => role == AdminRole.superAdmin;
  bool get isAdmin => role == AdminRole.admin;

  static AdminProfile? tryParse(String documentId, Map<String, dynamic> data) {
    final uid = _string(data['uid']);
    final role = switch (_string(data['role'])) {
      'superAdmin' => AdminRole.superAdmin,
      'admin' => AdminRole.admin,
      _ => null,
    };
    if (uid != documentId || role == null || data['isActive'] is! bool)
      return null;
    final rawIds = data['authorizedCommunityIds'];
    final ids = rawIds is List
        ? rawIds
              .whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    return AdminProfile(
      uid: uid,
      phoneNumber: _string(data['phoneNumber']),
      role: role,
      isActive: data['isActive'] == true,
      authorizedCommunityIds: List.unmodifiable(ids),
    );
  }
}

String _string(Object? value) => value is String ? value.trim() : '';
