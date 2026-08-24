import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCommunity {
  const AdminCommunity({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    this.logoUrl,
  });
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final bool isActive;

  factory AdminCommunity.fromMap(String id, Map<String, dynamic> data) =>
      AdminCommunity(
        id: id,
        name: (data['name'] ?? '').toString(),
        slug: (data['slug'] ?? '').toString(),
        logoUrl: data['logoUrl'] as String?,
        isActive: data['isActive'] == true,
      );
}

class CommunityInvite {
  const CommunityInvite({
    required this.code,
    required this.communityId,
    required this.isActive,
    required this.useCount,
    this.createdAt,
    this.createdBy,
    this.expiresAt,
    this.maxUses,
  });
  final String code;
  final String communityId;
  final bool isActive;
  final int useCount;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? expiresAt;
  final int? maxUses;

  bool get isExpired => expiresAt?.isBefore(DateTime.now()) == true;
  bool get isExhausted => maxUses != null && useCount >= maxUses!;

  factory CommunityInvite.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(dynamic value) => value is Timestamp
        ? value.toDate()
        : value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
        : null;
    return CommunityInvite(
      code: (data['code'] ?? id).toString(),
      communityId: (data['communityId'] ?? '').toString(),
      isActive: data['isActive'] == true,
      // Resident Phase 2B currently validates `useCount`. `usedCount` is kept as the requested alias.
      useCount: (data['useCount'] ?? data['usedCount'] ?? 0) as int,
      createdAt: date(data['createdAt']),
      createdBy: data['createdBy'] as String?,
      expiresAt: date(data['expiresAt']),
      maxUses: data['maxUses'] as int?,
    );
  }
}
