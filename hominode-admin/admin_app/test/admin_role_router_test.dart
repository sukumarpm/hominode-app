import 'package:admin_app/models/admin_profile.dart';
import 'package:admin_app/services/admin_role_router.dart';
import 'package:flutter_test/flutter_test.dart';

AdminProfile profile(
  String role, {
  bool isActive = true,
  List<String> communities = const [],
}) => AdminProfile(
  uid: 'uid-1',
  phoneNumber: '+15550000001',
  role: role,
  isActive: isActive,
  authorizedCommunityIds: communities,
);

void main() {
  test('superAdmin login routes to Super Admin home', () {
    expect(
      AdminRoleRouter.resolve(profile('superAdmin')),
      AdminPostAuthDestination.superAdminHome,
    );
  });

  test('ordinary admin login keeps the tenant flow', () {
    expect(
      AdminRoleRouter.resolve(
        profile('admin', communities: const ['community-a']),
      ),
      AdminPostAuthDestination.adminTenantFlow,
    );
  });

  test('restored superAdmin session resolves to Super Admin home', () {
    expect(
      AdminRoleRouter.canOpenSuperAdminRoute(profile('superAdmin')),
      isTrue,
    );
  });

  test('ordinary admin cannot open a Super Admin route', () {
    expect(
      AdminRoleRouter.canOpenSuperAdminRoute(
        profile('admin', communities: const ['community-a']),
      ),
      isFalse,
    );
  });

  test('inactive and unknown roles are rejected', () {
    expect(
      AdminRoleRouter.resolve(profile('superAdmin', isActive: false)),
      AdminPostAuthDestination.rejected,
    );
    expect(
      AdminRoleRouter.resolve(profile('unknown')),
      AdminPostAuthDestination.rejected,
    );
  });
}
