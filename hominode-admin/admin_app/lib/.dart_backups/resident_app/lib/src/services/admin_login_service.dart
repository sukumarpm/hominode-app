// lib/src/services/admin_login_service.dart
// Admin Login Service - Firestore-only authentication (no Firebase Auth needed)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result class for admin login operations
class AdminLoginResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? userData;
  final String? adminId;
  final String? buildingId;
  final String? errorCode;

  AdminLoginResult({
    required this.success,
    this.message,
    this.userData,
    this.adminId,
    this.buildingId,
    this.errorCode,
  });

  factory AdminLoginResult.success({
    required Map<String, dynamic> userData,
    required String adminId,
    required String buildingId,
  }) {
    return AdminLoginResult(
      success: true,
      message: 'Admin login successful',
      userData: userData,
      adminId: adminId,
      buildingId: buildingId,
    );
  }

  factory AdminLoginResult.failure({
    required String message,
    String? errorCode,
  }) {
    return AdminLoginResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Admin Login Service
/// Validates admin credentials and enforces admin role
class AdminLoginService {
  // Singleton pattern
  static final AdminLoginService instance = AdminLoginService._internal();
  factory AdminLoginService() => instance;
  AdminLoginService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Login as admin using Firestore-only authentication
  /// 
  /// STEP 1: Validate Input
  /// STEP 2: Query Firestore for user
  /// STEP 3: Validate password
  /// STEP 4: Validate admin role
  /// STEP 5: Save login state
  Future<AdminLoginResult> loginAsAdmin({
    required String identifier,
    required String password,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════');
      print('🔐 ADMIN LOGIN FLOW (FIRESTORE-ONLY)');
      print('═══════════════════════════════════════════════════\n');

      // STEP 1: Validate Input
      print('📋 STEP 1: Validating input...');
      final cleanIdentifier = identifier.trim();
      final cleanPassword = password.trim();

      if (cleanIdentifier.isEmpty || cleanPassword.isEmpty) {
        print('❌ STEP 1 FAILED: Empty credentials');
        return AdminLoginResult.failure(
          message: 'Email and password are required',
        );
      }
      print('✅ STEP 1 PASSED: Input validated\n');

      // STEP 2: Query Firestore for user
      print('📋 STEP 2: Querying Firestore for user...');
      
      QuerySnapshot userQuery;
      final isPhone = RegExp(r'^[\d+\s()-]+$').hasMatch(cleanIdentifier);

      if (isPhone) {
        // Clean phone number
        String cleanPhone = cleanIdentifier.replaceAll(RegExp(r'[\s()-]'), '');
        if (cleanPhone.startsWith('+91')) {
          cleanPhone = cleanPhone.substring(3);
        } else if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(2);
        }

        print('   📱 Searching by phone: $cleanPhone');
        userQuery = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();
      } else {
        print('   📧 Searching by email: $cleanIdentifier');
        userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: cleanIdentifier)
            .limit(1)
            .get();
      }

      if (userQuery.docs.isEmpty) {
        print('❌ STEP 2 FAILED: User not found');
        return AdminLoginResult.failure(
          message: 'No account found with this email/phone',
        );
      }

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      final adminId = userQuery.docs.first.id;
      print('✅ STEP 2 PASSED: User found\n');

      // STEP 3: Validate password
      print('📋 STEP 3: Validating password...');
      final storedPassword = userData['password'] as String?;

      if (storedPassword == null || storedPassword.isEmpty) {
        print('❌ STEP 3 FAILED: No password set in Firestore');
        return AdminLoginResult.failure(
          message: 'Account not properly configured',
        );
      }

      if (storedPassword != cleanPassword) {
        print('❌ STEP 3 FAILED: Password incorrect');
        return AdminLoginResult.failure(
          message: 'Incorrect password',
        );
      }
      print('✅ STEP 3 PASSED: Password validated\n');

      // STEP 4: Validate admin role
      print('📋 STEP 4: Validating admin role...');
      final role = userData['role'] as String?;
      final buildingId = userData['buildingId'] as String?;

      print('   Role: $role');
      print('   Building ID: $buildingId');

      if (role != 'admin') {
        print('❌ STEP 4 FAILED: User is not admin (role: $role)');
        return AdminLoginResult.failure(
          message: 'Only administrators can access this app',
        );
      }

      if (buildingId == null || buildingId.isEmpty) {
        print('❌ STEP 4 FAILED: No building assigned');
        return AdminLoginResult.failure(
          message: 'No building assigned to this admin',
        );
      }
      print('✅ STEP 4 PASSED: Admin role validated\n');

      // STEP 5: Save login state
      print('💾 STEP 5: Saving login state...');
      await _saveLoginState(
        adminId: adminId,
        email: userData['email'] as String,
        buildingId: buildingId,
      );
      print('✅ STEP 5 PASSED: Login state saved\n');

      print('═══════════════════════════════════════════════════');
      print('✅ ADMIN LOGIN FLOW: COMPLETE');
      print('═══════════════════════════════════════════════════\n');

      return AdminLoginResult.success(
        userData: userData,
        adminId: adminId,
        buildingId: buildingId,
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return AdminLoginResult.failure(
        message: 'Login failed: $e',
      );
    }
  }

  /// Save login state to local storage
  Future<void> _saveLoginState({
    required String adminId,
    required String email,
    required String buildingId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_admin_logged_in', true);
      await prefs.setString('admin_id', adminId);
      await prefs.setString('admin_email', email);
      await prefs.setString('building_id', buildingId);
      print('✅ Login state saved to SharedPreferences');
    } catch (e) {
      print('⚠️  Warning: Could not save login state: $e');
    }
  }

  /// Get error message from Firebase Auth error code
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Email/password login is not enabled';
      default:
        return 'Login failed. Please check your credentials and try again';
    }
  }

  /// Check if admin is logged in
  Future<bool> isAdminLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_admin_logged_in') ?? false;
    } catch (e) {
      print('Error checking login state: $e');
      return false;
    }
  }

  /// Get current admin ID
  Future<String?> getCurrentAdminId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('admin_id');
    } catch (e) {
      print('Error getting admin ID: $e');
      return null;
    }
  }

  /// Get current building ID
  Future<String?> getCurrentBuildingId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('building_id');
    } catch (e) {
      print('Error getting building ID: $e');
      return null;
    }
  }

  /// Logout admin
  Future<void> logout() async {
    try {
      print('🔐 Logging out admin...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_admin_logged_in');
      await prefs.remove('admin_id');
      await prefs.remove('admin_email');
      await prefs.remove('building_id');
      
      print('✅ Admin logged out successfully');
    } catch (e) {
      print('❌ Error logging out: $e');
    }
  }
}
