// lib/src/services/user_data_service.dart
// User Data Service - Fetches and manages user data from Firestore

import '../utils/resident_phone.dart';
import 'profile_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_auth_service.dart';

/// User Data Service
/// Handles fetching and caching user data from Firestore
class UserDataService {
  // Singleton pattern
  static final UserDataService instance = UserDataService._internal();
  factory UserDataService() => instance;
  UserDataService._internal()
    : _auth = FirebaseAuth.instance,
      _writeUser = null;
  @visibleForTesting
  UserDataService.forTesting({
    required FirebaseAuth auth,
    required Future<void> Function(String, Map<String, dynamic>) writeUser,
  }) : _auth = auth,
       _writeUser = writeUser;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final Future<void> Function(String, Map<String, dynamic>)? _writeUser;
  final FirestoreAuthService _authService = FirestoreAuthService();

  // Cache user data
  Map<String, dynamic>? _cachedUserData;
  String? _cachedUserId;

  /// Get current user data
  /// Returns cached data if available, otherwise fetches from Firestore
  /// Follows the standardized flow function pattern
  Future<Map<String, dynamic>?> getCurrentUserData({
    bool forceRefresh = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      if (!forceRefresh && _cachedUserId == user.uid && _cachedUserData != null)
        return _cachedUserData;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (_auth.currentUser?.uid != user.uid || !doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      data['id'] = doc.id;
      _cachedUserData = data;
      _cachedUserId = user.uid;
      return data;
    } catch (error) {
      logProfileFailure('profile-read', error);
      return null;
    }
  }

  /// Get user name
  Future<String> getUserName() async {
    final userData = await getCurrentUserData();
    return userData?['name'] ?? 'User';
  }

  /// Get user email
  Future<String> getUserEmail() async {
    final userData = await getCurrentUserData();
    return userData?['email'] ?? '';
  }

  /// Get user phone
  Future<String> getUserPhone() async {
    final userData = await getCurrentUserData();
    return residentDisplayPhone(userData);
  }

  /// Get user flat
  Future<String> getUserFlat() async {
    final userData = await getCurrentUserData();
    return userData?['flatLabel'] ?? userData?['flatId'] ?? '';
  }

  /// Get user role
  Future<String> getUserRole() async {
    final userData = await getCurrentUserData();
    return userData?['role'] ?? 'resident';
  }

  /// Get user resident ID
  Future<String> getUserResidentId() async {
    final userData = await getCurrentUserData();
    return userData?['residentId'] ?? '';
  }

  /// Get user ownership type
  Future<String> getUserOwnershipType() async {
    final userData = await getCurrentUserData();
    return userData?['ownershipType'] ?? 'Owner';
  }

  /// Get family members count
  Future<int> getFamilyMembersCount() async {
    final userData = await getCurrentUserData();
    return userData?['familyMembers'] ?? 0;
  }

  /// Get user profile photo URL
  Future<String?> getUserPhotoUrl() async {
    final userData = await getCurrentUserData();
    return userData?['photoUrl'];
  }

  /// Update user data in Firestore
  Future<bool> updateUserData(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final fields = Map<String, dynamic>.of(updates)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    try {
      if (_writeUser != null) {
        await _writeUser(user.uid, fields);
      } else {
        await _firestore.collection('users').doc(user.uid).update(fields);
      }
    } catch (error) {
      logProfileFailure('profile-write', error);
      return false;
    }
    // Firestore is the source of truth. An optional Auth display-name sync must
    // not report an already committed profile update as a failed save.
    _cachedUserData = null;
    _cachedUserId = null;
    try {
      if (_auth.currentUser?.uid == user.uid && updates.containsKey('name')) {
        await user.updateDisplayName(updates['name'] as String?);
      }
      final photo = updates['profileImage'] ?? updates['photoURL'];
      if (_auth.currentUser?.uid == user.uid &&
          photo is String &&
          {'http', 'https'}.contains(Uri.tryParse(photo)?.scheme))
        await user.updatePhotoURL(photo);
    } catch (error) {
      logProfileFailure('auth-display-sync', error);
    }
    return true;
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    return await updateUserData(updates);
  }

  /// Stream user data (real-time updates)
  Stream<Map<String, dynamic>?> streamUserData() async* {
    final userId = await _authService.getCurrentUserId();

    if (userId == null) {
      yield null;
      return;
    }

    yield* _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;

      final data = snapshot.data()!;

      // Update cache
      _cachedUserData = data;
      _cachedUserId = userId;

      return data;
    });
  }

  /// Clear cached data
  void clearCache() {
    _cachedUserData = null;
    _cachedUserId = null;
    print('🗑️  User data cache cleared');
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  /// Check if user is resident
  Future<bool> isResident() async {
    final role = await getUserRole();
    return role == 'resident';
  }

  /// Get user display info (for UI)
  Future<Map<String, String>> getUserDisplayInfo() async {
    final userData = await getCurrentUserData();

    if (userData == null) {
      return {
        'name': 'User',
        'email': '',
        'phone': '',
        'flat': '',
        'role': 'resident',
      };
    }

    return {
      'name': userData['name'] ?? 'User',
      'email': userData['email'] ?? '',
      'phone': residentDisplayPhone(userData),
      'flat': userData['flatLabel'] ?? userData['flatId'] ?? '',
      'role': userData['role'] ?? 'resident',
      'residentId': userData['residentId'] ?? '',
      'ownershipType': userData['ownershipType'] ?? 'Owner',
    };
  }

  /// Get user's language preference
  Future<String?> getUserLanguagePreference(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      final language = doc.data()?['language'] as String?;
      return language;
    } catch (e) {
      print('❌ Error fetching language preference: $e');
      return null;
    }
  }

  /// Save user's language preference
  Future<bool> saveUserLanguagePreference(
    String userId,
    String languageCode,
  ) async {
    try {
      print('📤 Saving language preference: $languageCode');

      await _firestore.collection('users').doc(userId).update({
        'language': languageCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear cache to force refresh
      _cachedUserData = null;

      print('✅ Language preference saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving language preference: $e');
      return false;
    }
  }
}
