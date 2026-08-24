import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_profile.dart';
import '../models/tenant_config.dart';
import 'admin_tenant_context.dart';
import 'tenant_registry_service.dart';

abstract class ActiveTenantStore {
  Future<String?> read(String adminUid);
  Future<void> write(String adminUid, String communityId);
  Future<void> remove(String adminUid);
}

class SharedPreferencesActiveTenantStore implements ActiveTenantStore {
  static String _key(String uid) => 'admin_active_tenant_$uid';
  @override
  Future<String?> read(String adminUid) async =>
      (await SharedPreferences.getInstance()).getString(_key(adminUid));
  @override
  Future<void> write(String adminUid, String communityId) async =>
      (await SharedPreferences.getInstance()).setString(
        _key(adminUid),
        communityId,
      );
  @override
  Future<void> remove(String adminUid) async =>
      (await SharedPreferences.getInstance()).remove(_key(adminUid));
}

enum AdminTenantResolution { selected, selectionRequired, noValidTenants }

class AdminTenantSession {
  AdminTenantSession({
    ActiveTenantStore? store,
    Future<TenantConfig> Function(String id)? tenantLoader,
    AdminTenantContext? context,
  }) : _store = store ?? SharedPreferencesActiveTenantStore(),
       _tenantLoader = tenantLoader ?? TenantRegistryService().getTenantById,
       _context = context ?? AdminTenantContext.instance;

  final ActiveTenantStore _store;
  final Future<TenantConfig> Function(String id) _tenantLoader;
  final AdminTenantContext _context;

  Future<AdminTenantResolution> resolve(AdminProfile profile) async {
    final valid = <TenantConfig>[];
    for (final id in profile.authorizedCommunityIds) {
      try {
        final tenant = await _tenantLoader(id);
        if (tenant.isActive) valid.add(tenant);
      } catch (_) {
        // Missing and unreadable tenant IDs are invalid and fail closed.
      }
    }
    _context.configure(profile, valid);
    _context.clearTenant();
    final persisted = await _store.read(profile.uid);
    final restored = valid
        .where((tenant) => tenant.communityId == persisted)
        .firstOrNull;
    if (restored != null) {
      _context.selectTenant(restored);
      return AdminTenantResolution.selected;
    }
    if (persisted != null) await _store.remove(profile.uid);
    if (valid.length == 1) {
      await selectTenant(valid.single);
      return AdminTenantResolution.selected;
    }
    if (valid.isEmpty) return AdminTenantResolution.noValidTenants;
    return AdminTenantResolution.selectionRequired;
  }

  Future<void> selectTenant(TenantConfig tenant) async {
    _context.selectTenant(tenant);
    final uid = _context.adminUid;
    if (uid == null) {
      throw StateError('Admin tenant session is not initialized.');
    }
    await _store.write(uid, tenant.communityId);
  }
}
