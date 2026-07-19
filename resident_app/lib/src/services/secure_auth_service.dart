// lib/src/services/secure_auth_service.dart
// Secure authentication service - NEVER stores passwords in Firestore
// Uses Firebase Auth for password management

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'validation_service.dart';

/// Secure authentication result
class SecureAuthResult {
  final bool success;
  final String? message;
  final String? userId;
  final String? buildingId;
  final String? flatId;
  final String? role;
  final String? errorCode;

  SecureAuthResult({
    required this.success,
    this.message,
    this.userId,
    this.buildingId,
    this.flatId,
    this.role,
    this.errorCode,
  });

  factory SecureAuthResult.success({
    required String userId,
    required String buildingId,
    required String flatId,
    required String role,
  }) {
    return SecureAuthResult(
      success: true,
      message: 'Login successful',
      userId: userId,
      buildingId: buildingId,
      flatId: flatId,
      role: role,
    );
  }

  factory SecureAuthResult.failure({
    required String message,
    String? errorCode,
  }) {
    return SecureAuthResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Secure authentication service
/// Uses Firebase Auth for password management (never stores passwords in Firestore)
class SecureAuthService {
  static final SecureAuthService instance = SecureAuthService._internal();
  factory SecureAuthService() => instance;
  SecureAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValidationService _validation = ValidationService.instance;

  /// Sign up with email and password
  /// Creates Firebase Auth user and Firestore user document
  Future<SecureAuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String buildingId,
    required String flatId,
  }) async {
    try {
      print('🔵 SecureAuthService: Starting sign up...');
      print('   Email: $email');

      // Validate inputs
      if (email.isEmpty || !email.contains('@')) {
        return SecureAuthResult.failure(message: 'Invalid email address');
      }

      if (password.length < 6) {
        return SecureAuthResult.failure(message: 'Password must be at least 6 characters');
      }

      if (name.isEmpty) {
        return SecureAuthResult.failure(message: 'Name is required');
      }

      // Validate building and flat exist
      final buildingResult = await _validation.validateBuilding(buildingId);
      if (!buildingResult.isValid) {
        return SecureAuthResult.failure(message: buildingResult.errorMessage!);
      }

      final flatResult = await _validation.validateFlat(flatId, ''); // Empty userId for new user
      if (!flatResult.isValid) {
        return SecureAuthResult.failure(message: flatResult.errorMessage!);
      }

      // Create Firebase Auth user
      print('🔐 Creating Firebase Auth user...');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUid = userCredential.user!.uid;
      print('✅ Firebase Auth user created: $firebaseUid');

      // Create Firestore user document
      print('📝 Creating Firestore user document...');
      final userId = firebaseUid; // Use Firebase UID as document ID
      
      await _firestore.collection('users').doc(userId).set({
        'email': email.trim(),
        'phone': phone.trim(),
        'name': name.trim(),
        'role': 'resident',
        'buildingId': buildingId,
        'flatId': flatId,
        'authUid': firebaseUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Firestore user document created');

      // Add user to flat residents list
      await _firestore.collection('flats').doc(flatId).update({
        'residents': FieldValue.arrayUnion([userId]),
      });

      print('✅ User added to flat residents');

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_email', email.trim());
      await prefs.setString('building_id', buildingId);
      await prefs.setString('flat_id', flatId);

      return SecureAuthResult.success(
        userId: userId,
        buildingId: buildingId,
        flatId: flatId,
        role: 'resident',
      );
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      
      String message = 'Sign up failed';
      if (e.code == 'email-already-in-use') {
        message = 'Email is already registered';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }

      return SecureAuthResult.failure(
        message: message,
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ SecureAuthService: Sign up error: $e');
      return SecureAuthResult.failure(message: 'Sign up failed: $e');
    }
  }

  /// Sign in with email and password
  /// Uses Firebase Auth (passwords never stored in Firestore)
  Future<SecureAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 SecureAuthService: Starting sign in...');
      print('   Email: $email');

      // Validate inputs
      if (email.isEmpty || !email.contains('@')) {
        return SecureAuthResult.failure(message: 'Invalid email address');
      }

      if (password.isEmpty) {
        return SecureAuthResult.failure(message: 'Password is required');
      }

      // Sign in with Firebase Auth
      print('🔐 Signing in with Firebase Auth...');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUid = userCredential.user!.uid;
      print('✅ Firebase Auth sign in successful: $firebaseUid');

      // Get user document from Firestore
      print('📝 Fetching user document...');
      final userDoc = await _firestore.collection('users').doc(firebaseUid).get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return SecureAuthResult.failure(message: 'User document not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final buildingId = userData['buildingId']?.toString() ?? '';
      final flatId = userData['flatId']?.toString() ?? '';
      final role = userData['role']?.toString() ?? 'resident';

      // Validate user has required fields
      if (buildingId.isEmpty || flatId.isEmpty) {
        return SecureAuthResult.failure(
          message: 'User is not properly assigned to a building or flat',
        );
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', firebaseUid);
      await prefs.setString('user_email', email.trim());
      await prefs.setString('building_id', buildingId);
      await prefs.setString('flat_id', flatId);

      print('✅ Sign in successful');

      return SecureAuthResult.success(
        userId: firebaseUid,
        buildingId: buildingId,
        flatId: flatId,
        role: role,
      );
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      
      String message = 'Sign in failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      }

      return SecureAuthResult.failure(
        message: message,
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ SecureAuthService: Sign in error: $e');
      return SecureAuthResult.failure(message: 'Sign in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      print('🔵 SecureAuthService: Signing out...');
      
      // Clear validation cache
      _validation.clearCache();
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('building_id');
      await prefs.remove('flat_id');
      
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ SecureAuthService: Sign out error: $e');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  /// Reset password
  Future<SecureAuthResult> resetPassword({required String email}) async {
    try {
      print('🔵 SecureAuthService: Sending password reset email...');
      
      if (email.isEmpty || !email.contains('@')) {
        return SecureAuthResult.failure(message: 'Invalid email address');
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
      
      print('✅ Password reset email sent');
      return SecureAuthResult.failure(
        message: 'Password reset email sent to $email',
      );
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      return SecureAuthResult.failure(
        message: 'Failed to send password reset email',
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ SecureAuthService: Reset password error: $e');
      return SecureAuthResult.failure(message: 'Failed to send password reset email');
    }
  }
}
