import 'package:flutter/foundation.dart';

import '../models/admin_profile.dart';

class AdminTenantContext extends ChangeNotifier {
  AdminTenantContext._();

  static final AdminTenantContext instance = AdminTenantContext._();

  List<String> _authorizedCommunityIds = const [];
  String? _selectedCommunityId;

  List<String> get authorizedCommunityIds =>
      List.unmodifiable(_authorizedCommunityIds);
  String? get selectedCommunityId => _selectedCommunityId;
  bool get hasSelectedCommunity => _selectedCommunityId != null;

  void initialize(AdminProfile profile) {
    final next = List<String>.unmodifiable(profile.authorizedCommunityIds);
    final currentStillAuthorized =
        _selectedCommunityId != null && next.contains(_selectedCommunityId);
    _authorizedCommunityIds = next;
    if (!currentStillAuthorized) {
      _selectedCommunityId = next.length == 1 ? next.single : null;
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
    notifyListeners();
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
    if (select) _selectedCommunityId = candidate;
    notifyListeners();
  }

  String requireCommunityId() {
    final selected = _selectedCommunityId;
    if (selected == null || !_authorizedCommunityIds.contains(selected)) {
      throw StateError('No authorized community is selected.');
    }
    return selected;
  }

  void clear() {
    _authorizedCommunityIds = const [];
    _selectedCommunityId = null;
    notifyListeners();
  }
}
