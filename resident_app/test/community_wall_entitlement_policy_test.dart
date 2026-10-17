import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_entitlements/hominode_entitlements.dart';
import 'package:resident_app/src/services/community_wall_entitlement_policy.dart';

void main() {
  for (final planId in ['essential', 'plus', 'pro']) {
    test('$planId with active Community Wall entitlement is allowed', () {
      final result = CommunityWallEntitlementPolicy.evaluate(
        _entitlement(planId: planId, enabled: true),
      );

      expect(result, CommunityWallAccessStatus.allowed);
    });
  }

  test('expired subscription remains blocked even when feature is enabled', () {
    final result = CommunityWallEntitlementPolicy.evaluate(
      _entitlement(
        planId: 'essential',
        enabled: true,
        status: HominodeSubscriptionStatus.expired,
      ),
    );

    expect(result, CommunityWallAccessStatus.subscriptionInactive);
  });

  test('active subscription with server feature disabled remains blocked', () {
    final result = CommunityWallEntitlementPolicy.evaluate(
      _entitlement(planId: 'essential', enabled: false),
    );

    expect(result, CommunityWallAccessStatus.featureUnavailable);
  });

  test('missing entitlement remains blocked', () {
    expect(
      CommunityWallEntitlementPolicy.evaluate(null),
      CommunityWallAccessStatus.featureUnavailable,
    );
  });

  test('missing subscription response has distinct classification', () {
    final result = CommunityWallEntitlementPolicy.classifyFailure(
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'This community does not have a subscription.',
      ),
    );

    expect(result, CommunityWallVerificationFailure.missingSubscription);
  });

  for (final error in [
    FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'A different precondition failed.',
    ),
    FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Auth required',
    ),
    FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Service unavailable',
    ),
    StateError('temporary verification failure'),
  ]) {
    test(
      '${error.runtimeType} remains retryable unless it is the known case',
      () {
        expect(
          CommunityWallEntitlementPolicy.classifyFailure(error),
          CommunityWallVerificationFailure.retryable,
        );
      },
    );
  }
}

HominodeEntitlement _entitlement({
  required String planId,
  required bool enabled,
  HominodeSubscriptionStatus status = HominodeSubscriptionStatus.active,
}) => HominodeEntitlement(
  communityId: 'community-a',
  planId: planId,
  status: status,
  features: {'communityWall': enabled},
  limits: const {},
);
