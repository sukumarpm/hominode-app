import 'package:hominode_core/hominode_core.dart';

enum WebRole { superAdmin, admin, resident }

class WebSession {
  const WebSession({
    required this.uid,
    required this.role,
    this.activeTenant,
    this.availableTenants = const [],
    this.displayName,
    this.phoneNumber,
    this.buildingId,
    this.flatId,
    this.flatLabel,
  });
  final String uid;
  final WebRole role;
  final TenantConfig? activeTenant;
  final List<TenantConfig> availableTenants;
  final String? displayName;
  final String? phoneNumber;
  final String? buildingId;
  final String? flatId;
  final String? flatLabel;
  bool get needsTenantSelection =>
      role == WebRole.admin &&
      activeTenant == null &&
      availableTenants.length > 1;
  String get canonicalPath => switch (role) {
    WebRole.superAdmin => '/super-admin',
    WebRole.admin => '/admin',
    WebRole.resident => '/resident',
  };
  WebSession withTenant(TenantConfig tenant) => WebSession(
    uid: uid,
    role: role,
    activeTenant: tenant,
    availableTenants: availableTenants,
    displayName: displayName,
    phoneNumber: phoneNumber,
    buildingId: buildingId,
    flatId: flatId,
    flatLabel: flatLabel,
  );
}

class SessionResolutionException implements Exception {
  const SessionResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}
