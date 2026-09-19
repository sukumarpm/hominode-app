import 'package:cloud_functions/cloud_functions.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';

import '../models/security_user_model.dart';
import 'auth_service.dart';

class SecuritySubscriptionEntitlementService {
  SecuritySubscriptionEntitlementService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<HominodeEntitlement?> getCurrentEntitlement(
    AuthService authService,
  ) async {
    final SecurityUserModel profile = await authService
        .requireSecurityProfile();

    return getEntitlement(profile.communityId);
  }

  Future<HominodeEntitlement?> getEntitlement(String communityId) async {
    final normalizedCommunityId = communityId.trim();

    if (normalizedCommunityId.isEmpty) {
      return null;
    }

    final result = await _functions
        .httpsCallable('getCurrentCommunityEntitlement')
        .call();

    final raw = result.data;

    if (raw == null) {
      return null;
    }

    final data = Map<String, dynamic>.from(raw as Map);

    final returnedCommunityId = (data['communityId'] ?? '').toString().trim();

    if (returnedCommunityId != normalizedCommunityId) {
      throw StateError(
        'Entitlement community mismatch: '
        'expected $normalizedCommunityId, '
        'received $returnedCommunityId',
      );
    }

    return HominodeEntitlement.fromMap(data);
  }
}
