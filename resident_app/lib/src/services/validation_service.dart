// lib/src/services/validation_service.dart
// Global validation service for user access and data integrity

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.data,
  });

  factory ValidationResult.valid({Map<String, dynamic>? data}) {
    return ValidationResult(isValid: true, data: data);
  }

  factory ValidationResult.invalid({required String errorMessage}) {
    return ValidationResult(isValid: false, errorMessage: errorMessage);
  }
}

/// Global validation service
class ValidationService {
  static final ValidationService instance = ValidationService._internal();
  factory ValidationService() => instance;
  ValidationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for performance
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, Map<String, dynamic>> _buildingCache = {};
  final Map<String, Map<String, dynamic>> _flatCache = {};

  /// Get current user ID from Firebase Auth or Firestore
  Future<String?> getCurrentUserId() async {
    try {
      // Try Firebase Auth first
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          return doc.id;
        }

        // Try by authUid field
        final query = await _firestore
            .collection('users')
            .where('authUid', isEqualTo: firebaseUser.uid)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          return query.docs.first.id;
        }
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (e) {
      print('❌ ValidationService: Error getting user ID: $e');
      return null;
    }
  }

  /// Validate user exists and has required fields
  Future<ValidationResult> validateUser(String userId) async {
    try {
      // Check cache first
      if (_userCache.containsKey(userId)) {
        final userData = _userCache[userId]!;
        return ValidationResult.valid(data: userData);
      }

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return ValidationResult.invalid(errorMessage: 'User not found');
      }

      final userData = doc.data() as Map<String, dynamic>;

      // Validate required fields
      if (userData['email'] == null || userData['email'].toString().isEmpty) {
        return ValidationResult.invalid(errorMessage: 'User email is missing');
      }

      if (userData['name'] == null || userData['name'].toString().isEmpty) {
        return ValidationResult.invalid(errorMessage: 'User name is missing');
      }

      // Cache the result
      _userCache[userId] = userData;

      return ValidationResult.valid(data: userData);
    } catch (e) {
      print('❌ ValidationService: Error validating user: $e');
      return ValidationResult.invalid(errorMessage: 'Error validating user: $e');
    }
  }

  /// Validate building exists
  Future<ValidationResult> validateBuilding(String buildingId) async {
    try {
      if (buildingId.isEmpty) {
        return ValidationResult.invalid(errorMessage: 'Building ID is empty');
      }

      // Check cache first
      if (_buildingCache.containsKey(buildingId)) {
        final buildingData = _buildingCache[buildingId]!;
        return ValidationResult.valid(data: buildingData);
      }

      final doc = await _firestore.collection('buildings').doc(buildingId).get();

      if (!doc.exists) {
        return ValidationResult.invalid(errorMessage: 'Building not found');
      }

      final buildingData = doc.data() as Map<String, dynamic>;

      // Cache the result
      _buildingCache[buildingId] = buildingData;

      return ValidationResult.valid(data: buildingData);
    } catch (e) {
      print('❌ ValidationService: Error validating building: $e');
      return ValidationResult.invalid(errorMessage: 'Error validating building: $e');
    }
  }

  /// Validate flat exists and user is assigned to it
  Future<ValidationResult> validateFlat(String flatId, String userId) async {
    try {
      if (flatId.isEmpty) {
        return ValidationResult.invalid(errorMessage: 'Flat ID is empty');
      }

      // Check cache first
      if (_flatCache.containsKey(flatId)) {
        final flatData = _flatCache[flatId]!;
        
        // Verify user is in residents list
        final residents = flatData['residents'] as List<dynamic>? ?? [];
        if (!residents.contains(userId)) {
          return ValidationResult.invalid(
            errorMessage: 'User is not assigned to this flat',
          );
        }

        return ValidationResult.valid(data: flatData);
      }

      final doc = await _firestore.collection('flats').doc(flatId).get();

      if (!doc.exists) {
        return ValidationResult.invalid(errorMessage: 'Flat not found');
      }

      final flatData = doc.data() as Map<String, dynamic>;

      // Verify user is in residents list
      final residents = flatData['residents'] as List<dynamic>? ?? [];
      if (!residents.contains(userId)) {
        return ValidationResult.invalid(
          errorMessage: 'User is not assigned to this flat',
        );
      }

      // Cache the result
      _flatCache[flatId] = flatData;

      return ValidationResult.valid(data: flatData);
    } catch (e) {
      print('❌ ValidationService: Error validating flat: $e');
      return ValidationResult.invalid(errorMessage: 'Error validating flat: $e');
    }
  }

  /// Validate user has access to building
  Future<ValidationResult> validateUserBuildingAccess(
    String userId,
    String buildingId,
  ) async {
    try {
      // Get user data
      final userResult = await validateUser(userId);
      if (!userResult.isValid) {
        return userResult;
      }

      final userData = userResult.data!;
      final userBuildingId = userData['buildingId']?.toString().trim();

      if (userBuildingId == null || userBuildingId.isEmpty) {
        return ValidationResult.invalid(
          errorMessage: 'User is not assigned to any building',
        );
      }

      if (userBuildingId != buildingId) {
        return ValidationResult.invalid(
          errorMessage: 'User does not have access to this building',
        );
      }

      // Validate building exists
      return await validateBuilding(buildingId);
    } catch (e) {
      print('❌ ValidationService: Error validating building access: $e');
      return ValidationResult.invalid(
        errorMessage: 'Error validating building access: $e',
      );
    }
  }

  /// Validate user has access to flat
  Future<ValidationResult> validateUserFlatAccess(
    String userId,
    String flatId,
  ) async {
    try {
      // Get user data
      final userResult = await validateUser(userId);
      if (!userResult.isValid) {
        return userResult;
      }

      final userData = userResult.data!;
      final userFlatId = userData['flatId']?.toString().trim();

      if (userFlatId == null || userFlatId.isEmpty) {
        return ValidationResult.invalid(
          errorMessage: 'User is not assigned to any flat',
        );
      }

      if (userFlatId != flatId) {
        return ValidationResult.invalid(
          errorMessage: 'User does not have access to this flat',
        );
      }

      // Validate flat exists and user is in it
      return await validateFlat(flatId, userId);
    } catch (e) {
      print('❌ ValidationService: Error validating flat access: $e');
      return ValidationResult.invalid(
        errorMessage: 'Error validating flat access: $e',
      );
    }
  }

  /// Validate user role
  Future<ValidationResult> validateUserRole(String userId, String requiredRole) async {
    try {
      final userResult = await validateUser(userId);
      if (!userResult.isValid) {
        return userResult;
      }

      final userData = userResult.data!;
      final userRole = userData['role']?.toString().trim().toLowerCase();

      if (userRole == null || userRole.isEmpty) {
        return ValidationResult.invalid(errorMessage: 'User role is not set');
      }

      if (userRole != requiredRole.toLowerCase()) {
        return ValidationResult.invalid(
          errorMessage: 'User does not have required role: $requiredRole',
        );
      }

      return ValidationResult.valid(data: userData);
    } catch (e) {
      print('❌ ValidationService: Error validating user role: $e');
      return ValidationResult.invalid(errorMessage: 'Error validating user role: $e');
    }
  }

  /// Clear cache (call on logout)
  void clearCache() {
    _userCache.clear();
    _buildingCache.clear();
    _flatCache.clear();
    print('🗑️  ValidationService: Cache cleared');
  }

  /// Get safe user data with null checks
  static Map<String, dynamic> getSafeUserData(Map<String, dynamic> userData) {
    return {
      'userId': userData['id']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'phone': userData['phone']?.toString() ?? '',
      'name': userData['name']?.toString() ?? 'Unknown',
      'role': userData['role']?.toString().toLowerCase() ?? 'resident',
      'buildingId': userData['buildingId']?.toString() ?? '',
      'flatId': userData['flatId']?.toString() ?? '',
      'authUid': userData['authUid']?.toString(),
    };
  }

  /// Validate required fields in map
  static ValidationResult validateRequiredFields(
    Map<String, dynamic> data,
    List<String> requiredFields,
  ) {
    for (final field in requiredFields) {
      final value = data[field];
      if (value == null || (value is String && value.isEmpty)) {
        return ValidationResult.invalid(
          errorMessage: 'Required field missing: $field',
        );
      }
    }
    return ValidationResult.valid();
  }
}
