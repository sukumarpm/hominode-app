import 'package:hominode_entitlements/hominode_entitlements.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 19, 12);

  HominodeEntitlement entitlement({
    String planId = 'plus',
    String status = 'active',
    int? startsAtMs,
    int? endsAtMs,
    Map<String, dynamic>? features,
    Map<String, dynamic>? limits,
  }) {
    return HominodeEntitlement.fromMap({
      'communityId': 'TEST-001',
      'planId': planId,
      'status': status,
      'startsAtMs': startsAtMs,
      'endsAtMs': endsAtMs,
      'features':
          features ??
          {'facilityBooking': true, 'events': true, 'communityWall': true},
      'limits': limits ?? {'maxCommunityBankAccounts': 2},
    });
  }

  group('subscription usability', () {
    test('active without end date is usable', () {
      expect(entitlement(status: 'active').isUsable(now: now), isTrue);
    });

    test('active with future end date is usable', () {
      expect(
        entitlement(
          status: 'active',
          endsAtMs: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        ).isUsable(now: now),
        isTrue,
      );
    });

    test('active with expired end date is blocked', () {
      expect(
        entitlement(
          status: 'active',
          endsAtMs: now
              .subtract(const Duration(seconds: 1))
              .millisecondsSinceEpoch,
        ).isUsable(now: now),
        isFalse,
      );
    });

    test('trial before end date is usable', () {
      expect(
        entitlement(
          status: 'trial',
          endsAtMs: now.add(const Duration(days: 7)).millisecondsSinceEpoch,
        ).isUsable(now: now),
        isTrue,
      );
    });

    test('expired trial is blocked', () {
      expect(
        entitlement(
          status: 'trial',
          endsAtMs: now
              .subtract(const Duration(seconds: 1))
              .millisecondsSinceEpoch,
        ).isUsable(now: now),
        isFalse,
      );
    });

    test('trial without end date is blocked defensively', () {
      expect(entitlement(status: 'trial').isUsable(now: now), isFalse);
    });

    test('valid grace period is usable', () {
      expect(
        entitlement(
          status: 'grace',
          endsAtMs: now.add(const Duration(days: 3)).millisecondsSinceEpoch,
        ).isUsable(now: now),
        isTrue,
      );
    });

    test('expired status is blocked', () {
      expect(entitlement(status: 'expired').isUsable(now: now), isFalse);
    });

    test('suspended status is blocked', () {
      expect(entitlement(status: 'suspended').isUsable(now: now), isFalse);
    });

    test('cancelled status is blocked', () {
      expect(entitlement(status: 'cancelled').isUsable(now: now), isFalse);
    });

    test('future subscription start is blocked', () {
      expect(
        entitlement(
          startsAtMs: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        ).isUsable(now: now),
        isFalse,
      );
    });
  });

  group('features', () {
    test('enabled feature is allowed on usable subscription', () {
      expect(entitlement().canUseFeature('facilityBooking', now: now), isTrue);
    });

    test('disabled feature is denied', () {
      expect(
        entitlement(
          features: {'facilityBooking': false},
        ).canUseFeature('facilityBooking', now: now),
        isFalse,
      );
    });

    test('missing feature is denied', () {
      expect(
        entitlement(
          features: const {},
        ).canUseFeature('somethingUnknown', now: now),
        isFalse,
      );
    });

    test('enabled feature is denied when subscription is suspended', () {
      expect(
        entitlement(
          status: 'suspended',
          features: {'facilityBooking': true},
        ).canUseFeature('facilityBooking', now: now),
        isFalse,
      );
    });
  });

  group('limits', () {
    test('reads integer limit', () {
      final value = entitlement().getIntLimit('maxCommunityBankAccounts');

      expect(value, 2);
    });

    test('null limit represents unlimited', () {
      final value = entitlement(limits: {'maxCommunityBankAccounts': null});

      expect(value.hasLimit('maxCommunityBankAccounts'), isTrue);
      expect(value.isUnlimited('maxCommunityBankAccounts'), isTrue);
      expect(value.getIntLimit('maxCommunityBankAccounts'), isNull);
    });

    test('missing limit is distinguishable from unlimited', () {
      final value = entitlement(limits: const {});

      expect(value.hasLimit('maxCommunityBankAccounts'), isFalse);
      expect(value.isUnlimited('maxCommunityBankAccounts'), isFalse);
    });
  });

  test('rejects unsupported subscription status', () {
    expect(() => entitlement(status: 'unknown'), throwsArgumentError);
  });
}
