import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the tenant-aware admin authorization contract', () {
    final profile = AdminProfile.fromMap('uid-1', {
      'uid': 'uid-1',
      'phoneNumber': '+919876543210',
      'role': 'admin',
      'isActive': true,
      'authorizedCommunityIds': [
        'community-a',
        '',
        'community-a',
        'community-b',
      ],
    });
    expect(profile.uid, 'uid-1');
    expect(profile.role, 'admin');
    expect(profile.isActive, isTrue);
    expect(profile.authorizedCommunityIds, ['community-a', 'community-b']);
  });

  test('missing authorization values fail closed in the model', () {
    final profile = AdminProfile.fromMap('uid-2', const {});
    expect(profile.uid, 'uid-2');
    expect(profile.phoneNumber, isEmpty);
    expect(profile.role, isEmpty);
    expect(profile.isActive, isFalse);
    expect(profile.authorizedCommunityIds, isEmpty);
  });

  test('recognizes only canonical admin roles', () {
    AdminProfile parse(String role, {bool isActive = true}) =>
        AdminProfile.fromMap('uid-role', {
          'uid': 'uid-role',
          'role': role,
          'isActive': isActive,
        });

    expect(parse('admin').isAdmin, isTrue);
    expect(parse('admin').hasValidAdminRole, isTrue);
    expect(parse('superAdmin').isSuperAdmin, isTrue);
    expect(parse('superAdmin').hasValidAdminRole, isTrue);
    expect(parse('superadmin').hasValidAdminRole, isFalse);
    expect(parse('unknown').hasValidAdminRole, isFalse);
    expect(parse('superAdmin', isActive: false).isActive, isFalse);
  });

  test('admin authorization policy accepts and rejects canonical roles', () {
    AdminProfile profile(
      String role, {
      bool isActive = true,
      List<String> communities = const ['community-a'],
    }) => AdminProfile(
      uid: 'uid-policy',
      phoneNumber: '+15550000001',
      role: role,
      isActive: isActive,
      authorizedCommunityIds: communities,
    );

    expect(
      adminAuthorizationStatus(profile('admin')),
      AdminAuthStatus.authorized,
    );
    expect(
      adminAuthorizationStatus(profile('superAdmin', communities: const [])),
      AdminAuthStatus.authorized,
    );
    expect(
      adminAuthorizationStatus(
        profile('superAdmin', isActive: false, communities: const []),
      ),
      AdminAuthStatus.inactive,
    );
    expect(
      adminAuthorizationStatus(profile('unknown')),
      AdminAuthStatus.wrongRole,
    );
    expect(
      adminAuthorizationStatus(profile('admin', communities: const [])),
      AdminAuthStatus.noCommunities,
    );
  });
}
