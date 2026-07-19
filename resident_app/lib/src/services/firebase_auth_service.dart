// lib/src/services/firebase_auth_service.dart
// Firebase Authentication Service with Phone OTP and Email/Password support

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result class for authentication operations
class AuthResult {
  final bool success;
  final String? message;
  final String? errorCode;
  final User? user;

  AuthResult({
    required this.success,
    this.message,
    this.errorCode,
    this.user,
  });

  factory AuthResult.success({String? message, User? user}) {
    return AuthResult(
      success: true,
      message: message ?? 'Operation successful',
      user: user,
    );
  }

  factory AuthResult.failure({required String message, String? errorCode}) {
    return AuthResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Firebase Authentication Service
class FirebaseAuthService {
  // Singleton pattern
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Storage keys
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserMobile = 'user_mobile';
  static const String _keyUserEmail = 'user_email';
  
  // Phone verification
  String? _verificationId;
  int? _resendToken;

  // ============================================================================
  // PHONE AUTHENTICATION
  // ============================================================================

  /// Send OTP to phone number
  /// 
  /// [phoneNumber] should be in E.164 format (e.g., +911234567890)
  /// 
  /// Returns [AuthResult] with success status
  Future<AuthResult> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        
        // Auto-retrieval on Android
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto-verification completed');
          if (onAutoVerify != null) {
            onAutoVerify(credential);
          } else {
            // Auto sign in
            final result = await _signInWithCredential(credential);
            if (result.success) {
              await _saveLoginState(phoneNumber: phoneNumber);
            }
          }
        },
        
        // Verification failed
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Verification failed: ${e.code} - ${e.message}');
          final errorMessage = _getErrorMessage(e.code);
          onError(errorMessage);
        },
        
        // Code sent successfully
        codeSent: (String verificationId, int? resendToken) {
          print('📱 OTP sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        
        // Auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ Auto-retrieval timeout');
          _verificationId = verificationId;
        },
        
        // For resending OTP
        forceResendingToken: _resendToken,
      );

      return AuthResult.success(message: 'OTP sent successfully');
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('Error sending OTP: $e');
      return AuthResult.failure(
        message: 'Failed to send OTP. Please check your connection.',
      );
    }
  }

  /// Verify OTP code
  /// 
  /// [smsCode] is the 6-digit code received via SMS
  /// 
  /// Returns [AuthResult] with user data if successful
  Future<AuthResult> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    try {
      final vid = verificationId ?? _verificationId;
      
      if (vid == null) {
        return AuthResult.failure(
          message: 'Verification ID not found. Please request OTP again.',
        );
      }

      // Create credential
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: smsCode,
      );

      // Sign in with credential
      final result = await _signInWithCredential(credential);
      
      if (result.success && result.user != null) {
        // Save login state
        await _saveLoginState(phoneNumber: result.user!.phoneNumber);
      }

      return result;
    } on FirebaseAuthException catch (e) {
      print('OTP Verification Error: ${e.code} - ${e.message}');
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('Error verifying OTP: $e');
      return AuthResult.failure(
        message: 'Failed to verify OTP. Please try again.',
      );
    }
  }

  /// Resend OTP
  /// 
  /// Uses the stored phone number and resend token
  Future<AuthResult> resendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    return await signInWithPhone(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  // ============================================================================
  // EMAIL/PASSWORD AUTHENTICATION
  // ============================================================================

  /// Sign in with email and password
  /// Supports login with email OR phone number
  /// 
  /// Returns [AuthResult] with user data if successful
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      String loginEmail = email.trim();

      // Check if input is a phone number (contains only digits and +)
      final isPhoneNumber = RegExp(r'^[\d+\s()-]+$').hasMatch(loginEmail);

      if (isPhoneNumber) {
        print('📱 Phone number detected, looking up email in Firestore...');
        
        // Clean phone number (remove spaces, dashes, parentheses, and leading +91)
        String cleanPhone = loginEmail.replaceAll(RegExp(r'[\s()-]'), '');
        
        // Remove country code if present
        if (cleanPhone.startsWith('+91')) {
          cleanPhone = cleanPhone.substring(3);
        } else if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(2);
        }
        
        print('🔍 Searching for phone: $cleanPhone');
        
        // Import Firestore
        final firestore = FirebaseFirestore.instance;
        
        // Try multiple phone format variations
        final phoneVariations = [
          cleanPhone,                    // 7010678124
          '+91$cleanPhone',              // +917010678124
          '91$cleanPhone',               // 917010678124
        ];
        
        QuerySnapshot? querySnapshot;
        
        // Try each variation
        for (var phoneVar in phoneVariations) {
          print('  Trying: $phoneVar');
          final query = await firestore
              .collection('users')
              .where('phone', isEqualTo: phoneVar)
              .limit(1)
              .get();
          
          if (query.docs.isNotEmpty) {
            querySnapshot = query;
            print('  ✅ Found match with: $phoneVar');
            break;
          }
        }

        if (querySnapshot == null || querySnapshot.docs.isEmpty) {
          print('❌ No user found with phone number: $cleanPhone');
          print('💡 Tried variations: ${phoneVariations.join(", ")}');
          return AuthResult.failure(
            message: 'No account found with this phone number',
          );
        }

        // Get the email from Firestore
        final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        loginEmail = userData['email'] as String;
        print('✅ Found email for phone number: $loginEmail');
      }

      // Now login with email
      print('🔐 Attempting login with email: $loginEmail');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );

      if (userCredential.user != null) {
        print('✅ Login successful for user: ${userCredential.user!.uid}');
        await _saveLoginState(email: loginEmail);
        
        return AuthResult.success(
          message: 'Signed in successfully',
          user: userCredential.user,
        );
      }

      return AuthResult.failure(message: 'Sign in failed');
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('❌ Error signing in: $e');
      return AuthResult.failure(
        message: 'Failed to sign in. Please try again.',
      );
    }
  }

  /// Create account with email and password
  /// 
  /// Returns [AuthResult] with user data if successful
  Future<AuthResult> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        await _saveLoginState(email: email);
        
        return AuthResult.success(
          message: 'Account created successfully',
          user: userCredential.user,
        );
      }

      return AuthResult.failure(message: 'Account creation failed');
    } on FirebaseAuthException catch (e) {
      print('Create Account Error: ${e.code} - ${e.message}');
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('Error creating account: $e');
      return AuthResult.failure(
        message: 'Failed to create account. Please try again.',
      );
    }
  }

  /// Send password reset email
  /// 
  /// Returns [AuthResult] with success status
  Future<AuthResult> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      return AuthResult.success(
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      print('Password Reset Error: ${e.code} - ${e.message}');
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('Error sending password reset email: $e');
      return AuthResult.failure(
        message: 'Failed to send reset email. Please try again.',
      );
    }
  }

  // ============================================================================
  // USER MANAGEMENT
  // ============================================================================

  /// Get current user
  /// 
  /// Returns [User] if signed in, null otherwise
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is signed in
  /// 
  /// Returns true if user is authenticated
  Future<bool> isSignedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      return true;
    }
    
    // Also check SharedPreferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Sign out current user
  /// 
  /// Returns [AuthResult] with success status
  Future<AuthResult> signOut() async {
    try {
      await _auth.signOut();
      await _clearLoginState();
      
      return AuthResult.success(message: 'Signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      return AuthResult.failure(
        message: 'Failed to sign out. Please try again.',
      );
    }
  }

  /// Update user profile
  /// 
  /// [displayName] - User's display name
  /// [photoURL] - User's profile photo URL
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        return AuthResult.failure(message: 'No user signed in');
      }

      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
      await user.reload();
      
      return AuthResult.success(message: 'Profile updated successfully');
    } on FirebaseAuthException catch (e) {
      print('Update Profile Error: ${e.code} - ${e.message}');
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('Error updating profile: $e');
      return AuthResult.failure(
        message: 'Failed to update profile. Please try again.',
      );
    }
  }

  /// Delete user account
  /// 
  /// Returns [AuthResult] with success status
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        return AuthResult.failure(message: 'No user signed in');
      }

      await user.delete();
      await _clearLoginState();
      
      return AuthResult.success(message: 'Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      print('Delete Account Error: ${e.code} - ${e.message}');
      
      if (e.code == 'requires-recent-login') {
        return AuthResult.failure(
          message: 'Please sign in again before deleting your account.',
          errorCode: e.code,
        );
      }
      
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    } catch (e) {
      print('Error deleting account: $e');
      return AuthResult.failure(
        message: 'Failed to delete account. Please try again.',
      );
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Sign in with credential (internal method)
  Future<AuthResult> _signInWithCredential(AuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        return AuthResult.success(
          message: 'Signed in successfully',
          user: userCredential.user,
        );
      }

      return AuthResult.failure(message: 'Sign in failed');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        message: _getErrorMessage(e.code),
        errorCode: e.code,
      );
    }
  }

  /// Save login state to SharedPreferences
  Future<void> _saveLoginState({
    String? phoneNumber,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    
    if (phoneNumber != null) {
      await prefs.setString(_keyUserMobile, phoneNumber);
    }
    
    if (email != null) {
      await prefs.setString(_keyUserEmail, email);
    }
  }

  /// Clear login state from SharedPreferences
  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserMobile);
    await prefs.remove(_keyUserEmail);
  }

  /// Get user-friendly error message
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      // Phone Auth Errors
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      
      // Email/Password Errors
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Invalid credentials. Please check and try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and try again.';
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid credentials. Please check and try again.';
      
      // General Errors
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Validate phone number format
  /// 
  /// Accepts 10-digit Indian mobile numbers
  bool validatePhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid 10-digit number
    if (cleanPhone.length != 10) {
      return false;
    }
    
    // Indian mobile numbers start with 6-9
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    return phoneRegex.hasMatch(cleanPhone);
  }

  /// Format phone number to E.164 format
  /// 
  /// Converts 10-digit Indian number to +91XXXXXXXXXX
  String formatPhoneNumber(String phone, {String countryCode = '+91'}) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$countryCode$cleanPhone';
  }

  /// Validate email format
  bool validateEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate password strength
  /// 
  /// Returns error message if password is weak, null if valid
  String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    return null; // Password is valid
  }

  /// Listen to auth state changes
  /// 
  /// Returns a stream of [User] objects
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
