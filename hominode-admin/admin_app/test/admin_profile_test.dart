import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_role_router.dart';
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

  test(
    'admin role routing accepts and rejects canonical authorization cases',
    () {
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
        AdminRoleRouter.resolve(profile('admin')),
        AdminPostAuthDestination.adminTenantFlow,
      );
      expect(
        AdminRoleRouter.resolve(profile('superAdmin', communities: const [])),
        AdminPostAuthDestination.superAdminHome,
      );
      expect(
        AdminRoleRouter.resolve(
          profile('superAdmin', isActive: false, communities: const []),
        ),
        AdminPostAuthDestination.rejected,
      );
      expect(
        AdminRoleRouter.resolve(profile('unknown')),
        AdminPostAuthDestination.rejected,
      );
      expect(
        AdminRoleRouter.resolve(profile('admin', communities: const [])),
        AdminPostAuthDestination.rejected,
      );
    },
  );
}
