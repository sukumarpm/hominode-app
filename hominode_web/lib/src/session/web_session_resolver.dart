import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hominode_core/hominode_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_session.dart';

abstract interface class WebProfileStore {
  Future<Map<String, dynamic>?> admin(String uid);
  Future<Map<String, dynamic>?> resident(String uid);
  Future<Map<String, dynamic>?> tenant(String communityId);
}

abstract interface class TenantSelectionStore {
  Future<String?> read(String uid);
  Future<void> write(String uid, String communityId);
  Future<void> clear(String uid);
}

class FirestoreWebProfileStore implements WebProfileStore {
  FirestoreWebProfileStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  Future<Map<String, dynamic>?> _get(String collection, String id) async =>
      (await _firestore.collection(collection).doc(id).get()).data();
  @override
  Future<Map<String, dynamic>?> admin(String uid) => _get('admins', uid);
  @override
  Future<Map<String, dynamic>?> resident(String uid) => _get('users', uid);
  @override
  Future<Map<String, dynamic>?> tenant(String communityId) async {
    try {
      return await _get('communities', communityId);
    } on FirebaseException catch (error) {
      // Rules intentionally make inactive or unauthorized tenants invisible.
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return null;
      }
      rethrow;
    }
  }
}

class LocalTenantSelectionStore implements TenantSelectionStore {
  String _key(String uid) => 'hominode_web_active_tenant_$uid';
  @override
  Future<String?> read(String uid) async =>
      (await SharedPreferences.getInstance()).getString(_key(uid));
  @override
  Future<void> write(String uid, String communityId) async =>
      (await SharedPreferences.getInstance()).setString(_key(uid), communityId);
  @override
  Future<void> clear(String uid) async =>
      (await SharedPreferences.getInstance()).remove(_key(uid));
}

class WebSessionResolver {
  WebSessionResolver(this.profiles, this.selections);
  final WebProfileStore profiles;
  final TenantSelectionStore selections;

  Future<WebSession> resolve(String uid) async {
    final adminData = await profiles.admin(uid);
    if (adminData != null) return _resolveAdmin(uid, adminData);
    final residentData = await profiles.resident(uid);
    if (residentData == null) {
      throw const SessionResolutionException(
        'No Hominode profile exists for this account.',
      );
    }
    return _resolveResident(uid, residentData);
  }

  Future<WebSession> _resolveAdmin(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final profile = AdminProfile.tryParse(uid, data);
    if (profile == null || !profile.isActive) {
      throw const SessionResolutionException(
        'Invalid or inactive admin profile.',
      );
    }
    if (profile.isSuperAdmin) {
      return WebSession(
        uid: uid,
        role: WebRole.superAdmin,
        phoneNumber: data['phoneNumber'] as String?,
      );
    }
    if (profile.authorizedCommunityIds.isEmpty) {
      throw const SessionResolutionException(
        'No communities are authorized for this admin.',
      );
    }
    final active = <TenantConfig>[];
    for (final id in profile.authorizedCommunityIds) {
      final data = await profiles.tenant(id);
      if (data == null) continue;
      final tenant = TenantConfig.fromMap(id, data);
      if (tenant.isActive) active.add(tenant);
    }
    if (active.isEmpty) {
      throw const SessionResolutionException(
        'No authorized active communities are available.',
      );
    }
    final persisted = await selections.read(uid);
    final restored = active
        .where((tenant) => tenant.communityId == persisted)
        .firstOrNull;
    final selected = restored ?? (active.length == 1 ? active.single : null);
    if (persisted != null && restored == null) await selections.clear(uid);
    if (selected != null) await selections.write(uid, selected.communityId);
    return WebSession(
      uid: uid,
      role: WebRole.admin,
      activeTenant: selected,
      availableTenants: List.unmodifiable(active),
      phoneNumber: data['phoneNumber'] as String?,
    );
  }

  Future<WebSession> _resolveResident(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final profile = ResidentProfile.tryParse(uid, data);

    if (profile == null || !profile.canEnter) {
      throw const SessionResolutionException(
        'Invalid, inactive, or unapproved resident profile.',
      );
    }
    final tenantData = await profiles.tenant(profile.communityId);
    if (tenantData == null) {
      throw const SessionResolutionException(
        'Assigned community does not exist.',
      );
    }
    final tenant = TenantConfig.fromMap(profile.communityId, tenantData);
    if (!tenant.isActive) {
      throw const SessionResolutionException('Assigned community is inactive.');
    }
    return WebSession(
      uid: uid,
      role: WebRole.resident,
      activeTenant: tenant,
      availableTenants: [tenant],
      displayName: (data['name'] ?? data['fullName']) as String?,
      phoneNumber: data['phoneNumber'] as String?,
      buildingId: data['buildingId'] as String?,
      flatId: data['flatId'] as String?,
      flatLabel: (data['flatLabel'] ?? data['flatNumber']) as String?,
    );
  }

  Future<WebSession> selectAdminTenant(
    WebSession session,
    String communityId,
  ) async {
    if (session.role != WebRole.admin) {
      throw const SessionResolutionException(
        'Only ordinary admins may select a tenant.',
      );
    }
    final tenant = session.availableTenants
        .where((item) => item.communityId == communityId && item.isActive)
        .firstOrNull;
    if (tenant == null) {
      throw const SessionResolutionException('That tenant is not authorized.');
    }
    await selections.write(session.uid, tenant.communityId);
    return session.withTenant(tenant);
  }
}
