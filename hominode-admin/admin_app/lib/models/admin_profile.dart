import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProfile {
  const AdminProfile({
    required this.uid,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    required this.authorizedCommunityIds,
    this.createdAt,
    this.updatedAt,
  });
  final String uid;
  final String phoneNumber;
  final String role;
  final bool isActive;
  final List<String> authorizedCommunityIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == 'admin';
  bool get isSuperAdmin => role == 'superAdmin';
  bool get hasValidAdminRole => isAdmin || isSuperAdmin;

  factory AdminProfile.fromMap(String documentId, Map<String, dynamic> data) {
    DateTime? date(dynamic value) => value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
    final communities =
        (data['authorizedCommunityIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(growable: false);
    final storedUid = (data['uid'] as String? ?? '').trim();
    return AdminProfile(
      uid: storedUid.isEmpty ? documentId : storedUid,
      phoneNumber: (data['phoneNumber'] as String? ?? '').trim(),
      role: (data['role'] as String? ?? '').trim(),
      isActive: data['isActive'] == true,
      authorizedCommunityIds: communities,
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }
}
