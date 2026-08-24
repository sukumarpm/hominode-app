import '../models/admin_profile.dart';

enum AdminPostAuthDestination { adminTenantFlow, superAdminHome, rejected }

class AdminRoleRouter {
  const AdminRoleRouter._();

  static AdminPostAuthDestination resolve(AdminProfile profile) {
    if (!profile.isActive || !profile.hasValidAdminRole) {
      return AdminPostAuthDestination.rejected;
    }
    if (profile.isSuperAdmin) {
      return AdminPostAuthDestination.superAdminHome;
    }
    if (profile.authorizedCommunityIds.isEmpty) {
      return AdminPostAuthDestination.rejected;
    }
    return AdminPostAuthDestination.adminTenantFlow;
  }

  static bool canOpenSuperAdminRoute(AdminProfile profile) =>
      resolve(profile) == AdminPostAuthDestination.superAdminHome;
}
