import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/community_feature_flags.dart';
import '../models/community_model.dart';
import '../models/tenant_profile.dart';

enum TenantResolutionFailure {
  unauthenticated,
  profileMissing,
  profileInactive,
  communityMissing,
  communityInactive,
}

class TenantResolutionException implements Exception {
  final TenantResolutionFailure reason;
  final String message;

  const TenantResolutionException(this.reason, this.message);

  @override
  String toString() => message;
}

class TenantContext {
  final TenantProfile profile;
  final CommunityModel community;

  const TenantContext({required this.profile, required this.community});

  String get communityId => community.id;
  CommunityFeatureFlags get featureFlags => community.features;
}

/// Single source of truth for resolving the signed-in user's tenant.
class TenantResolutionService extends ChangeNotifier {
  TenantResolutionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  TenantContext? _current;

  TenantContext? get current => _current;
  CommunityModel? get community => _current?.community;
  String? get communityId => _current?.communityId;

  Future<TenantContext> resolve() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const TenantResolutionException(
        TenantResolutionFailure.unauthenticated,
        'A Firebase-authenticated user is required.',
      );
    }

    final profileDocument = await _loadProfile(user.uid);
    if (profileDocument == null) {
      throw const TenantResolutionException(
        TenantResolutionFailure.profileMissing,
        'No resident or admin profile exists for this account.',
      );
    }

    final profile = TenantProfile.fromMap(user.uid, profileDocument);
    if (!profile.isActive) {
      throw const TenantResolutionException(
        TenantResolutionFailure.profileInactive,
        'This account is inactive.',
      );
    }
    if (profile.communityId.trim().isEmpty) {
      throw const TenantResolutionException(
        TenantResolutionFailure.profileMissing,
        'This account is not assigned to a community.',
      );
    }

    final communityDocument = await _firestore
        .collection('communities')
        .doc(profile.communityId)
        .get();
    if (!communityDocument.exists) {
      throw const TenantResolutionException(
        TenantResolutionFailure.communityMissing,
        'The assigned community does not exist.',
      );
    }

    final community = CommunityModel.fromFirestore(communityDocument);
    if (!community.isActive) {
      throw const TenantResolutionException(
        TenantResolutionFailure.communityInactive,
        'The assigned community is inactive.',
      );
    }

    _current = TenantContext(profile: profile, community: community);
    notifyListeners();
    return _current!;
  }

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    final user = await _firestore.collection('users').doc(uid).get();
    if (user.exists) return user.data();

    final admin = await _firestore.collection('admins').doc(uid).get();
    return admin.data();
  }

  void clear() {
    _current = null;
    notifyListeners();
  }
}
