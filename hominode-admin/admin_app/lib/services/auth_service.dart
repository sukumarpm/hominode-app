import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

import '../models/admin_profile.dart';
import 'admin_tenant_context.dart';

enum AdminAuthStatus {
  authorized,
  unauthenticated,
  profileMissing,
  invalidProfile,
  wrongRole,
  inactive,
  noCommunities,
  error,
}

class AuthResult {
  const AuthResult({
    required this.success,
    required this.message,
    required this.status,
    this.user,
    this.adminProfile,
  });
  final bool success;
  final String message;
  final AdminAuthStatus status;
  final User? user;
  final AdminProfile? adminProfile;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? getCurrentUser() => _auth.currentUser;
  String? getCurrentUserId() => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String, int?) onCodeSent,
    required void Function(AuthResult) onVerificationCompleted,
    required void Function(String) onError,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async =>
          onVerificationCompleted(await _signInAndAuthorize(credential)),
      verificationFailed: (error) => onError(_phoneError(error.code)),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<AuthResult> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) => _signInAndAuthorize(
    PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    ),
  );

  Future<AuthResult> _signInAndAuthorize(AuthCredential credential) async {
    try {
      final credentialResult = await _auth.signInWithCredential(credential);

      debugPrint(
        '✅ ADMIN FIREBASE AUTH SUCCESS: ${credentialResult.user?.uid}',
      );
      debugPrint('   Phone: ${credentialResult.user?.phoneNumber}');

      final result = await resolveAdminAuthorization();

      debugPrint('🔐 ADMIN AUTH RESULT');
      debugPrint('   success: ${result.success}');
      debugPrint('   status: ${result.status}');
      debugPrint('   message: ${result.message}');

      if (!result.success) {
        debugPrint('❌ Admin authorization failed - signing out');
        await _auth.signOut();
      }

      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth error: ${e.code} / ${e.message}');

      return AuthResult(
        success: false,
        message: _phoneError(e.code),
        status: AdminAuthStatus.error,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Admin login unexpected error: $e');
      debugPrintStack(stackTrace: stackTrace);

      return const AuthResult(
        success: false,
        message: 'Unable to verify this code. Please try again.',
        status: AdminAuthStatus.error,
      );
    }
  }

  Future<AuthResult> resolveAdminAuthorization() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(
        success: false,
        message: 'Please sign in with your admin phone number.',
        status: AdminAuthStatus.unauthenticated,
      );
    }
    if (user.phoneNumber == null ||
        !user.providerData.any(
          (p) => p.providerId == PhoneAuthProvider.PROVIDER_ID,
        )) {
      return AuthResult(
        success: false,
        message: 'This session was not authenticated by phone OTP.',
        status: AdminAuthStatus.invalidProfile,
        user: user,
      );
    }
    try {
      final doc = await _firestore.collection('admins').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        return AuthResult(
          success: false,
          message: 'No admin profile is linked to this phone account.',
          status: AdminAuthStatus.profileMissing,
          user: user,
        );
      }
      final profile = AdminProfile.fromMap(doc.id, doc.data()!);
      if (profile.uid != user.uid ||
          profile.phoneNumber.isEmpty ||
          profile.phoneNumber != user.phoneNumber) {
        return AuthResult(
          success: false,
          message:
              'The admin profile does not match this verified phone account.',
          status: AdminAuthStatus.invalidProfile,
          user: user,
          adminProfile: profile,
        );
      }
      if (!profile.hasValidAdminRole) {
        return AuthResult(
          success: false,
          message: 'This account is not authorized as an administrator.',
          status: AdminAuthStatus.wrongRole,
          user: user,
          adminProfile: profile,
        );
      }
      if (!profile.isActive) {
        return AuthResult(
          success: false,
          message:
              'This admin account is inactive. Contact a system administrator.',
          status: AdminAuthStatus.inactive,
          user: user,
          adminProfile: profile,
        );
      }
      if (profile.isAdmin && profile.authorizedCommunityIds.isEmpty) {
        return AuthResult(
          success: false,
          message: 'No communities are assigned to this admin account.',
          status: AdminAuthStatus.noCommunities,
          user: user,
          adminProfile: profile,
        );
      }
      return AuthResult(
        success: true,
        message: 'Login successful',
        status: AdminAuthStatus.authorized,
        user: user,
        adminProfile: profile,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ ADMIN AUTHORIZATION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      return AuthResult(
        success: false,
        message: 'Admin authorization could not be verified: $e',
        status: AdminAuthStatus.error,
        user: user,
      );
    }
  }

  Future<String?> getCurrentBuildingId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('admins').doc(uid).get();
    return doc.data()?['buildingId'] as String?;
  }

  Future<void> signOut() async {
    // 1. Notification cleanup MUST happen while Firebase user is still authenticated.
    try {
      await HominodePushNotifications.instance.deactivateForLogout();
    } catch (e, stackTrace) {
      debugPrint('Notification device removal failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Notification cleanup failure must not block logout.
    }

    // 2. Sign out from Firebase.
    await FirebaseAuth.instance.signOut();

    // 3. Clear Admin tenant/session state only after auth sign-out.
    AdminTenantContext.instance.clear(notify: false);
  }

  String _phoneError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Enter a valid phone number.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check the OTP and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'This verification session has expired. Please request a new OTP.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'quota-exceeded':
        return 'OTP service is temporarily unavailable. Please try again later.';
      case 'user-disabled':
        return 'This authentication account has been disabled.';
      default:
        return 'Phone authentication failed. Please try again.';
    }
  }
}
