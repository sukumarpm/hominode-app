import 'package:cloud_functions/cloud_functions.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';

enum CommunityWallAccessStatus {
  allowed,
  subscriptionInactive,
  featureUnavailable,
}

enum CommunityWallVerificationFailure { missingSubscription, retryable }

/// Applies the existing server-authored entitlement without inferring access
/// from a plan name or weakening subscription lifecycle checks.
class CommunityWallEntitlementPolicy {
  static CommunityWallAccessStatus evaluate(HominodeEntitlement? entitlement) {
    if (entitlement == null) {
      return CommunityWallAccessStatus.featureUnavailable;
    }
    if (!entitlement.isUsable()) {
      return CommunityWallAccessStatus.subscriptionInactive;
    }
    if (entitlement.canUseFeature('communityWall')) {
      return CommunityWallAccessStatus.allowed;
    }
    return CommunityWallAccessStatus.featureUnavailable;
  }

  static CommunityWallVerificationFailure classifyFailure(Object error) {
    if (error is FirebaseFunctionsException &&
        error.code == 'failed-precondition' &&
        error.message?.trim() ==
            'This community does not have a subscription.') {
      return CommunityWallVerificationFailure.missingSubscription;
    }
    return CommunityWallVerificationFailure.retryable;
  }
}
