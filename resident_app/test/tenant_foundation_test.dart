import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/community_feature_flags.dart';
import 'package:resident_app/src/models/tenant_profile.dart';
import 'package:resident_app/src/services/tenant_firestore.dart';

void main() {
  test('feature flags default closed and parse explicit values', () {
    const defaults = CommunityFeatureFlags();
    expect(defaults.visitors, isFalse);
    expect(defaults.payments, isFalse);

    final flags = CommunityFeatureFlags.fromMap({
      'visitors': true,
      'payments': true,
      'unknownFutureFlag': true,
    });
    expect(flags.visitors, isTrue);
    expect(flags.payments, isTrue);
    expect(flags.chat, isFalse);
  });

  test('admin access is constrained to assigned communities', () {
    final profile = TenantProfile.fromMap('admin-1', {
      'communityId': 'community-a',
      'role': 'admin',
      'isActive': true,
      'authorizedCommunityIds': ['community-b'],
    });

    expect(profile.canAccessCommunity('community-a'), isTrue);
    expect(profile.canAccessCommunity('community-b'), isTrue);
    expect(profile.canAccessCommunity('community-c'), isFalse);
  });

  test('tenant stamp overrides untrusted communityId', () {
    final data = TenantFirestore.stamp('community-a', {
      'communityId': 'community-b',
      'title': 'Test',
    });

    expect(data['communityId'], 'community-a');
    expect(data['title'], 'Test');
    expect(() => TenantFirestore.stamp('', {}), throwsArgumentError);
  });
}
