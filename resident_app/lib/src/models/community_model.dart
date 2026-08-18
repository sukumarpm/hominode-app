import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_feature_flags.dart';

class CommunityModel {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final List<String> bannerUrls;
  final String? supportPhone;
  final String? supportEmail;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CommunityFeatureFlags features;

  const CommunityModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.bannerUrls = const [],
    this.supportPhone,
    this.supportEmail,
    this.address,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.features = const CommunityFeatureFlags(),
  });

  factory CommunityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (!document.exists || data == null) {
      throw StateError('Community ${document.id} does not exist.');
    }

    return CommunityModel(
      id: document.id,
      name: data['name'] as String? ?? '',
      slug: data['slug'] as String? ?? '',
      logoUrl: data['logoUrl'] as String?,
      primaryColor: data['primaryColor'] as String?,
      secondaryColor: data['secondaryColor'] as String?,
      bannerUrls: List<String>.from(data['bannerUrls'] as List? ?? const []),
      supportPhone: data['supportPhone'] as String?,
      supportEmail: data['supportEmail'] as String?,
      address: data['address'] as String?,
      isActive: data['isActive'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      features: CommunityFeatureFlags.fromMap(
        data['features'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'slug': slug,
    'logoUrl': logoUrl,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'bannerUrls': bannerUrls,
    'supportPhone': supportPhone,
    'supportEmail': supportEmail,
    'address': address,
    'isActive': isActive,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    'features': features.toMap(),
  };
}
