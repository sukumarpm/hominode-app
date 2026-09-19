import 'package:cloud_functions/cloud_functions.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';

import 'tenant_resolution_service.dart';

class ResidentSubscriptionEntitlementService {
  ResidentSubscriptionEntitlementService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<HominodeEntitlement?> getCurrentEntitlement(
    TenantResolutionService tenantResolution,
  ) async {
    var communityId = tenantResolution.communityId;

    if (communityId == null || communityId.trim().isEmpty) {
      final context = await tenantResolution.resolve();
      communityId = context.communityId;
    }

    return getEntitlement(communityId);
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
