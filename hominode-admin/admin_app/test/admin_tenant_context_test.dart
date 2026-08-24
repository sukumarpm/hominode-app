import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_tenant_context.dart';
import 'package:admin_app/models/tenant_config.dart';
import 'package:flutter_test/flutter_test.dart';

AdminProfile profile(List<String> communities) => AdminProfile(
  uid: 'admin-1',
  phoneNumber: '+919876543210',
  role: 'admin',
  isActive: true,
  authorizedCommunityIds: communities,
);

void main() {
  final context = AdminTenantContext.instance;
  tearDown(context.clear);

  test('single-community admin is selected automatically', () {
    context.initialize(profile(['community-a']));
    expect(context.requireCommunityId(), 'community-a');
  });

  test('multi-community admin fails closed until selection', () {
    context.initialize(profile(['community-a', 'community-b']));
    expect(context.hasSelectedCommunity, isFalse);
    expect(context.requireCommunityId, throwsStateError);
    context.selectCommunity('community-b');
    expect(context.requireCommunityId(), 'community-b');
  });

  test('unauthorized community cannot be selected', () {
    context.initialize(profile(['community-a', 'community-b']));
    expect(() => context.selectCommunity('community-c'), throwsStateError);
  });

  test('newly authorized community is added once and selected', () {
    context.initialize(profile(['community-a']));
    context.addAuthorizedCommunity('GV-0701');
    context.addAuthorizedCommunity('GV-0701');
    expect(context.authorizedCommunityIds, ['community-a', 'GV-0701']);
    expect(context.requireCommunityId(), 'GV-0701');
  });

  test('fresh selected tenant replaces stale cached location', () {
    context.initialize(profile(['community-a']));
    final stale = TenantConfig.fromMap('community-a', {
      'name': 'Community A',
      'isActive': true,
      'locationConfigured': false,
    });
    final fresh = TenantConfig.fromMap('community-a', {
      'name': 'Community A',
      'isActive': true,
      'locationConfigured': true,
      'location': {
        'latitude': 14.5995,
        'longitude': 120.9842,
        'formattedAddress': 'Community A, Manila',
        'placeId': 'place-a',
        'attendanceRadiusMeters': 150,
      },
    });
    context.selectTenant(stale);
    expect(context.activeTenant?.locationConfigured, isFalse);
    context.refreshTenant(fresh);
    expect(context.activeTenant?.locationConfigured, isTrue);
    expect(
      context.activeTenant?.location?.formattedAddress,
      'Community A, Manila',
    );
    expect(context.activeTenant?.location?.attendanceRadiusMeters, 150);
  });
}
