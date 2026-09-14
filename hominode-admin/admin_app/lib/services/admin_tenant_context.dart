import 'package:flutter/foundation.dart';

import '../models/admin_profile.dart';
import '../models/tenant_config.dart';

class AdminTenantContext extends ChangeNotifier {
  AdminTenantContext._();

  static final AdminTenantContext instance = AdminTenantContext._();

  List<String> _authorizedCommunityIds = const [];
  String? _selectedCommunityId;
  TenantConfig? _activeTenant;
  String? _adminUid;
  List<TenantConfig> _authorizedTenants = const [];

  List<String> get authorizedCommunityIds =>
      List.unmodifiable(_authorizedCommunityIds);
  String? get selectedCommunityId => _selectedCommunityId;
  String? get communityId => _activeTenant?.communityId ?? _selectedCommunityId;
  bool get hasSelectedCommunity => _selectedCommunityId != null;
  TenantConfig? get activeTenant => _activeTenant;
  String? get adminUid => _adminUid;
  List<TenantConfig> get authorizedTenants =>
      List.unmodifiable(_authorizedTenants);
  String? get name => _activeTenant?.name;
  String? get slug => _activeTenant?.slug;
  String? get websitePath => _activeTenant?.websitePath;
  String? get databaseId => _activeTenant?.databaseId;
  String? get logoUrl => _activeTenant?.logoUrl;
  String? get brandName => _activeTenant?.brandName;
  String? get primaryColor => _activeTenant?.primaryColor;

  void initialize(AdminProfile profile) {
    final next = List<String>.unmodifiable(profile.authorizedCommunityIds);
    final currentStillAuthorized =
        _selectedCommunityId != null && next.contains(_selectedCommunityId);
    _authorizedCommunityIds = next;
    if (!currentStillAuthorized) {
      _selectedCommunityId = next.length == 1 ? next.single : null;
      _activeTenant = null;
    } else if (_activeTenant?.communityId != _selectedCommunityId) {
      _activeTenant = null;
    }
    notifyListeners();
  }

  void configure(AdminProfile profile, List<TenantConfig> validTenants) {
    final tenants = validTenants
        .where(
          (tenant) =>
              profile.authorizedCommunityIds.contains(tenant.communityId) &&
              tenant.isActive,
        )
        .toList(growable: false);
    _adminUid = profile.uid;
    _authorizedTenants = tenants;
    _authorizedCommunityIds = List.unmodifiable(
      tenants.map((tenant) => tenant.communityId),
    );
    if (_activeTenant == null ||
        !_authorizedCommunityIds.contains(_activeTenant!.communityId)) {
      clearTenant(notify: false);
    }
    notifyListeners();
  }

  void selectCommunity(String communityId) {
    final candidate = communityId.trim();
    if (!_authorizedCommunityIds.contains(candidate)) {
      throw StateError('Community is not authorized for this admin.');
    }
    if (_selectedCommunityId == candidate) return;
    _selectedCommunityId = candidate;
    _activeTenant = null;
    notifyListeners();
  }

  void activateTenant(TenantConfig tenant) {
    selectTenant(tenant);
  }

  void selectTenant(TenantConfig tenant) {
    if (!_authorizedCommunityIds.contains(tenant.communityId)) {
      throw StateError('Community is not authorized for this admin.');
    }
    _selectedCommunityId = tenant.communityId;
    _activeTenant = tenant;
    notifyListeners();
  }

  void refreshTenant(TenantConfig tenant) {
    if (!_authorizedCommunityIds.contains(tenant.communityId)) {
      throw StateError('Community is not authorized for this admin.');
    }
    final existingIndex = _authorizedTenants.indexWhere(
      (candidate) => candidate.communityId == tenant.communityId,
    );
    if (existingIndex >= 0) {
      final refreshed = [..._authorizedTenants];
      refreshed[existingIndex] = tenant;
      _authorizedTenants = List.unmodifiable(refreshed);
    }
    _selectedCommunityId = tenant.communityId;
    _activeTenant = tenant;
    notifyListeners();
  }

  TenantConfig requireTenant() {
    final tenant = _activeTenant;
    if (tenant == null ||
        !_authorizedCommunityIds.contains(tenant.communityId) ||
        !tenant.isActive) {
      throw StateError('No authorized active tenant is selected.');
    }
    return tenant;
  }

  void clearTenant({bool notify = true}) {
    _selectedCommunityId = null;
    _activeTenant = null;
    if (notify) notifyListeners();
  }

  void addAuthorizedCommunity(String communityId, {bool select = true}) {
    final candidate = communityId.trim();
    if (candidate.isEmpty) throw ArgumentError('Community ID cannot be empty.');
    if (!_authorizedCommunityIds.contains(candidate)) {
      _authorizedCommunityIds = List.unmodifiable([
        ..._authorizedCommunityIds,
        candidate,
      ]);
    }
    if (select) {
      _selectedCommunityId = candidate;
      _activeTenant = null;
    }
    notifyListeners();
  }

  String requireCommunityId() {
    final selected = _selectedCommunityId;
    if (selected == null || !_authorizedCommunityIds.contains(selected)) {
      throw StateError('No authorized community is selected.');
    }
    return selected;
  }

  void clear({bool notify = true}) {
    _authorizedCommunityIds = const [];
    _selectedCommunityId = null;
    _activeTenant = null;
    _authorizedTenants = const [];
    _adminUid = null;
    if (notify) notifyListeners();
  }
}
