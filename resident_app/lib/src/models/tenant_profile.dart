/// Tenant and authorization fields shared by resident and admin profiles.
class TenantProfile {
  final String userId;
  final String communityId;
  final String role;
  final bool isActive;
  final List<String> authorizedCommunityIds;

  const TenantProfile({
    required this.userId,
    required this.communityId,
    required this.role,
    required this.isActive,
    this.authorizedCommunityIds = const [],
  });

  factory TenantProfile.fromMap(String userId, Map<String, dynamic> data) {
    return TenantProfile(
      userId: userId,
      communityId: data['communityId'] as String? ?? '',
      role: data['role'] as String? ?? '',
      isActive: data['isActive'] == true,
      authorizedCommunityIds: List<String>.from(
        data['authorizedCommunityIds'] as List? ?? const [],
      ),
    );
  }

  bool get isAdmin => role == 'admin' || role == 'superAdmin';

  bool canAccessCommunity(String id) =>
      communityId == id || (isAdmin && authorizedCommunityIds.contains(id));
}
