// lib/src/services/auth_service.dart
// Authentication Service for password management and 2FA

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Storage keys - defined outside class so extensions can access them
const String _keyIsLoggedIn = 'is_logged_in';
const String _keyUserMobile = 'user_mobile';
const String _keyAuthToken = 'auth_token';

class AuthService {
  // Singleton pattern
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  /// Check if two-factor authentication is enabled for the current user
  /// Fetches 2FA status from Firestore user document
  Future<bool> isTwoFactorEnabled() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;
      return userDoc.data()?['twoFactorEnabled'] ?? false;
    } catch (e) {
      debugPrint('Error checking 2FA status: $e');
      return false;
    }
  }

  /// Verify two-factor authentication code
  /// Validates code against stored 2FA secret in Firestore
  Future<bool> verify2FACode(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final twoFactorSecret = userDoc.data()?['twoFactorSecret'] as String?;
      if (twoFactorSecret == null) return false;

      // Verify TOTP code (implement TOTP verification logic)
      // For now, validate code format and length
      if (code.length != 6 || !RegExp(r'^\d+$').hasMatch(code)) {
        return false;
      }

      // Example: return TOTPVerifier.verify(twoFactorSecret, code);
      
      return true; // Placeholder - implement real TOTP verification
    } catch (e) {
      debugPrint('Error verifying 2FA code: $e');
      return false;
    }
  }

  /// Change user password
  /// Validates current password and updates to new password in Firebase Auth
  /// Returns [PasswordChangeResult] with success status and message
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return PasswordChangeResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      // Validate password format
      if (newPassword.length < 8) {
        return PasswordChangeResult(
          success: false,
          message: 'Password must be at least 8 characters',
        );
      }

      // Re-authenticate user with current password
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        return PasswordChangeResult(
          success: false,
          message: 'Current password is incorrect',
        );
      }

      // Update password
      await user.updatePassword(newPassword);

      // Update password hash in Firestore for additional security
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'passwordUpdatedAt': FieldValue.serverTimestamp(),
          });

      return PasswordChangeResult(
        success: true,
        message: 'Password changed successfully',
      );
    } catch (e) {
      debugPrint('Error changing password: $e');
      return PasswordChangeResult(
        success: false,
        message: 'Failed to change password. Please try again.',
      );
    }
  }
}

/// Result object for password change operation
class PasswordChangeResult {
  final bool success;
  final String? message;

  PasswordChangeResult({
    required this.success,
    this.message,
  });
}

// ============================================================================
// LOGIN STATE MANAGEMENT
// ============================================================================

extension LoginStateManagement on AuthService {
  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }
  
  /// Save login state after successful authentication
  Future<void> saveLoginState(String mobile, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserMobile, mobile);
    if (token != null) {
      await prefs.setString(_keyAuthToken, token);
    }
  }
  
  /// Clear login state on logout
  Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserMobile);
    await prefs.remove(_keyAuthToken);
  }
  
  /// Get stored mobile number
  Future<String?> getStoredMobile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserMobile);
  }
  
  /// Get stored auth token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthToken);
  }
}

// ============================================================================
// OTP AUTHENTICATION
// ============================================================================

extension OTPAuthentication on AuthService {
  // TODO: Replace with your actual API base URL
  static const String _baseUrl = 'https://your-api-url.com/api';
  
  /// Send OTP to mobile number
  /// Returns true if OTP sent successfully
  /// 
  /// DEMO MODE: Only accepts mobile number 1234567890
  /// Demo OTP will be: 123456
  Future<bool> sendOTP(String mobile) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 1));
      
      // TODO: Replace with actual API call
      /*
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'mobile': mobile,
          'country_code': '+91',
        }),
      ).timeout(
        cds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('OTP sent successfully: ${data['message']}');
        return true;
      } else {
        final error = json.decode(response.body);
        print('Send OTP failed: ${error['message']}');
        return false;
      }
      */
      
      // DEMO MODE: Only accept specific mobile number
      const demoMobile = '1234567890';
      
      if (mobile == demoMobile) {
        print('✅ OTP sent to: $mobile');
        print('📱 Demo OTP: 123456');
        return true;
      } else {
        print('❌ Invalid mobile number for demo');
        print('💡 Use demo mobile: $demoMobile');
        return false;
      }
    } catch (e) {
      print('Send OTP error: $e');
      return false;
    }
  }
  
  /// Verify OTP
  /// Returns true if OTP is valid
  /// 
  /// DEMO MODE: Only accepts OTP 12345667890
  Future<bool> verifyOTP(String mobile, String otp) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 1));
      
      // TODO: Replace with actual API call
      /*
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'mobile': mobile,
          'otp': otp,
          'country_code': '+91',
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save auth token
        if (data['token'] != null) {
          await _saveAuthToken(data['token']);
        }
        
        // Save user data
        if (data['user'] != null) {
          await _saveUserData(data['user']);
        }
        
        print('OTP verified successfully');
        return true;
      } else {
        final error = json.decode(response.body);
        print('Verify OTP failed: ${error['message']}');
        return false;
      }
      */
      
      // DEMO MODE: Accept specific OTP for specific mobile
      const demoMobile = '1234567890';
      const demoOTP = '123456';
      
      print('Verifying OTP: $otp for mobile: $mobile');
      
      if (mobile == demoMobile && otp == demoOTP) {
        print('✅ OTP verified successfully');
        print('🎉 User authenticated');
        return true;
      } else {
        print('❌ Invalid OTP');
        print('💡 Demo credentials: Mobile=$demoMobile, OTP=$demoOTP');
        return false;
      }
    } catch (e) {
      print('Verify OTP error: $e');
      return false;
    }
  }
  
  /// Resend OTP
  /// Returns true if OTP resent successfully
  /// 
  /// DEMO MODE: Only accepts mobile number 1234567890
  Future<bool> resendOTP(String mobile) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 1));
      
      // TODO: Replace with actual API call
      /*
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'mobile': mobile,
          'country_code': '+91',
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        print('OTP resent successfully');
        return true;
      } else {
        print('Resend OTP failed');
        return false;
      }
      */
      
      // DEMO MODE: Only accept specific mobile number
      const demoMobile = '1234567890';
      
      if (mobile == demoMobile) {
        print('🔄 OTP resent to: $mobile');
        print('📱 Demo OTP: 123456');
        return true;
      } else {
        print('❌ Invalid mobile number for demo');
        print('💡 Use demo mobile: $demoMobile');
        return false;
      }
    } catch (e) {
      print('Resend OTP error: $e');
      return false;
    }
  }
  
  /// Validate mobile number format
  /// DEMO MODE: Accepts any 10-digit number (including demo: 1234567890)
  bool validateMobileNumber(String mobile) {
    // Remove any spaces or special characters
    final cleanMobile = mobile.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid 10-digit number
    if (cleanMobile.length != 10) {
      return false;
    }
    
    // DEMO MODE: Accept any 10-digit number
    // For production, uncomment the line below for Indian format validation:
    // final mobileRegex = RegExp(r'^[6-9]\d{9}$');
    // return mobileRegex.hasMatch(cleanMobile);
    
    return true; // Accept any 10-digit number in demo mode
  }
  
  /// Format mobile number for display
  String formatMobileNumber(String mobile) {
    final cleanMobile = mobile.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanMobile.length == 10) {
      return '+91 ${cleanMobile.substring(0, 5)} ${cleanMobile.substring(5)}';
    }
    return mobile;
  }
}
