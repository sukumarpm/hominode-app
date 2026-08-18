import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/tenant_profile.dart';
import 'tenant_resolution_service.dart';

class AuthResult {
  final bool success;
  final String? message;
  final String? errorCode;
  final User? user;
  final TenantContext? tenant;

  const AuthResult({
    required this.success,
    this.message,
    this.errorCode,
    this.user,
    this.tenant,
  });

  factory AuthResult.success({
    String? message,
    User? user,
    TenantContext? tenant,
  }) => AuthResult(
    success: true,
    message: message ?? 'Operation successful',
    user: user,
    tenant: tenant,
  );

  factory AuthResult.failure({required String message, String? errorCode}) =>
      AuthResult(success: false, message: message, errorCode: errorCode);
}

/// Resident authentication gateway. Firebase Phone Auth is the only supported
/// sign-in mechanism; profile and tenant authorization are checked afterwards.
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;

  User? get currentUser => _auth.currentUser;
  User? getCurrentUser() => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required TenantResolutionService tenantResolver,
    required ValueChanged<String> onCodeSent,
    required ValueChanged<AuthResult> onVerificationCompleted,
    required ValueChanged<AuthResult> onError,
    bool forceResend = false,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResend ? _resendToken : null,
      verificationCompleted: (credential) async {
        final result = await _completePhoneSignIn(credential, tenantResolver);
        onVerificationCompleted(result);
      },
      verificationFailed: (error) => onError(
        AuthResult.failure(
          message: _messageForCode(error.code),
          errorCode: error.code,
        ),
      ),
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) =>
          _verificationId = verificationId,
    );
  }

  Future<AuthResult> verifyOtp({
    required String smsCode,
    required TenantResolutionService tenantResolver,
    String? verificationId,
  }) async {
    final id = verificationId ?? _verificationId;
    if (id == null || id.isEmpty) {
      return AuthResult.failure(
        message: 'Verification session expired. Request a new OTP.',
        errorCode: 'missing-verification-id',
      );
    }
    return _completePhoneSignIn(
      PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode),
      tenantResolver,
    );
  }

  Future<AuthResult> restoreResidentSession(
    TenantResolutionService tenantResolver,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult.failure(message: 'No authenticated session.');
    }
    return _resolveResident(user, tenantResolver);
  }

  Future<AuthResult> _completePhoneSignIn(
    PhoneAuthCredential credential,
    TenantResolutionService tenantResolver,
  ) async {
    try {
      final user = (await _auth.signInWithCredential(credential)).user;
      if (user == null || user.phoneNumber == null) {
        await _rejectSession(tenantResolver);
        return AuthResult.failure(message: 'Phone authentication failed.');
      }
      return _resolveResident(user, tenantResolver);
    } on FirebaseAuthException catch (error) {
      await _rejectSession(tenantResolver);
      return AuthResult.failure(
        message: _messageForCode(error.code),
        errorCode: error.code,
      );
    } catch (_) {
      await _rejectSession(tenantResolver);
      return AuthResult.failure(
        message: 'Unable to verify this phone number. Please try again.',
      );
    }
  }

  Future<AuthResult> _resolveResident(
    User user,
    TenantResolutionService tenantResolver,
  ) async {
    try {
      final tenant = await tenantResolver.resolve();
      final roleFailure = validateResidentProfile(tenant.profile);
      if (roleFailure != null) {
        await _rejectSession(tenantResolver);
        return AuthResult.failure(
          message: roleFailure,
          errorCode: 'wrong-role',
        );
      }
      return AuthResult.success(
        message: 'Phone verified successfully.',
        user: user,
        tenant: tenant,
      );
    } on TenantResolutionException catch (error) {
      await _rejectSession(tenantResolver);
      return AuthResult.failure(
        message: error.message,
        errorCode: error.reason.name,
      );
    } catch (_) {
      await _rejectSession(tenantResolver);
      return AuthResult.failure(
        message:
            'Unable to load your resident profile. Please contact support.',
      );
    }
  }

  @visibleForTesting
  static String? validateResidentProfile(TenantProfile profile) {
    if (!profile.isActive) {
      return 'This resident account is inactive.';
    }
    if (profile.communityId.isEmpty) {
      return 'This account is not assigned to a community.';
    }
    if (profile.role != 'resident') {
      return 'This app is available to resident accounts only.';
    }
    return null;
  }

  Future<AuthResult> signOut([TenantResolutionService? tenantResolver]) async {
    try {
      await _auth.signOut();
      tenantResolver?.clear();
      return AuthResult.success(message: 'Signed out successfully.');
    } catch (_) {
      return AuthResult.failure(
        message: 'Failed to sign out. Please try again.',
      );
    }
  }

  Future<void> _rejectSession(TenantResolutionService tenantResolver) async {
    tenantResolver.clear();
    await _auth.signOut();
  }

  bool validatePhoneNumber(String phone) =>
      RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(formatPhoneNumber(phone));

  String formatPhoneNumber(String phone) =>
      phone.trim().replaceAll(RegExp(r'[\s()-]'), '');

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Enter a valid phone number with country code.';
      case 'invalid-verification-code':
        return 'The OTP is incorrect. Please try again.';
      case 'session-expired':
      case 'missing-verification-id':
        return 'The OTP expired. Request a new code.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled. Please contact support.';
      default:
        return 'Phone authentication failed. Please try again.';
    }
  }
}
