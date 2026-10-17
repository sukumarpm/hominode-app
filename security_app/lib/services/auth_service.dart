import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hominode_notifications/hominode_notifications.dart';

import '../models/security_community_model.dart';
import '../models/security_user_model.dart';

class SecurityAuthException implements Exception {
  final String code;
  final String message;

  const SecurityAuthException(this.code, this.message);

  @override
  String toString() => message;
}

class PhoneOtpStartResult {
  final String? verificationId;
  final bool autoVerified;

  const PhoneOtpStartResult({this.verificationId, required this.autoVerified});
}

abstract interface class SecurityProfileStore {
  Future<SecurityUserModel?> getSecurityProfile(String uid);

  Future<bool?> isCommunityActive(String communityId);
}

class _FirestoreSecurityProfileStore implements SecurityProfileStore {
  _FirestoreSecurityProfileStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<SecurityUserModel?> getSecurityProfile(String uid) async {
    final document = await _firestore
        .collection('securityStaff')
        .doc(uid)
        .get();
    if (!document.exists) return null;
    try {
      return SecurityUserModel.fromFirestore(document);
    } catch (_) {
      throw const SecurityAuthException(
        'invalid-profile',
        'Security account could not be verified.',
      );
    }
  }

  @override
  Future<bool?> isCommunityActive(String communityId) async {
    final document = await _firestore
        .collection('communities')
        .doc(communityId)
        .get();
    if (!document.exists) return null;
    return SecurityCommunityModel.fromFirestore(document).isActive;
  }
}

class AuthService {
  final FirebaseAuth _auth;
  final SecurityProfileStore _profileStore;
  final Future<void> Function() _deactivateNotifications;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SecurityProfileStore? profileStore,
    Future<void> Function()? deactivateNotifications,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _profileStore =
           profileStore ??
           _FirestoreSecurityProfileStore(
             firestore ?? FirebaseFirestore.instance,
           ),
       _deactivateNotifications =
           deactivateNotifications ??
           HominodePushNotifications.instance.deactivateForLogout;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isLoggedIn => _auth.currentUser != null;

  Future<PhoneOtpStartResult> sendOtp(String phoneNumber) async {
    final phone = phoneNumber.trim();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      throw const SecurityAuthException(
        'invalid-phone-number',
        'Enter a valid phone number.',
      );
    }

    final completer = Completer<PhoneOtpStartResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final credentialResult = await _auth.signInWithCredential(credential);
          final user = credentialResult.user;
          if (user == null) {
            throw const SecurityAuthException(
              'unauthenticated',
              'Please sign in to continue.',
            );
          }
          await _requireSecurityProfileForUser(user);

          if (!completer.isCompleted) {
            completer.complete(const PhoneOtpStartResult(autoVerified: true));
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(
            SecurityAuthException(error.code, _firebaseAuthMessage(error)),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpStartResult(
              verificationId: verificationId,
              autoVerified: false,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpStartResult(
              verificationId: verificationId,
              autoVerified: false,
            ),
          );
        }
      },
    );

    return completer.future;
  }

  Future<SecurityUserModel> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final code = smsCode.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const SecurityAuthException(
        'invalid-code',
        'Enter the 6-digit OTP.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      final credentialResult = await _auth.signInWithCredential(credential);
      final user = credentialResult.user;
      if (user == null) {
        throw const SecurityAuthException(
          'unauthenticated',
          'Please sign in to continue.',
        );
      }
      return _requireSecurityProfileForUser(user);
    } on SecurityAuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw SecurityAuthException(e.code, _firebaseAuthMessage(e));
    }
  }

  Future<SecurityUserModel> requireSecurityProfile({
    bool Function()? isSessionCurrent,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Future.error(
        const SecurityAuthException(
          'unauthenticated',
          'Please sign in to continue.',
        ),
      );
    }
    return _requireSecurityProfileForUser(
      user,
      isSessionCurrent: isSessionCurrent,
    );
  }

  Future<SecurityUserModel> _requireSecurityProfileForUser(
    User user, {
    bool Function()? isSessionCurrent,
  }) async {
    bool isCurrentSession() =>
        _auth.currentUser?.uid == user.uid &&
        (isSessionCurrent?.call() ?? true);

    void ensureCurrentSession() {
      if (!isCurrentSession()) {
        throw const SecurityAuthException(
          'session-changed',
          'Authentication changed. Please retry verification.',
        );
      }
    }

    ensureCurrentSession();
    final tokenResult = await user.getIdTokenResult();
    ensureCurrentSession();
    final verifiedPhoneSession = hasVerifiedPhoneAuth(
      phoneNumber: user.phoneNumber,
      signInProvider: tokenResult.signInProvider,
    );
    if (!verifiedPhoneSession) {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'phone-auth-required',
          'Please sign in with a verified phone number.',
        ),
      );
    }

    final profile = await _profileStore.getSecurityProfile(user.uid);
    ensureCurrentSession();

    if (profile == null) {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'profile-not-found',
          'No Security account is linked to this phone number. Please contact your Community Admin.',
        ),
      );
    }

    if (!profile.matchesVerifiedPhone(
      expectedUid: user.uid,
      phone: user.phoneNumber!,
    )) {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'invalid-profile',
          'Security account could not be verified.',
        ),
      );
    }

    if (profile.role != 'security') {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'wrong-role',
          'This phone number is not registered as a Security account.',
        ),
      );
    }

    if (!profile.isActive) {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'account-disabled',
          'Your Security account is not active. Please contact your Community Admin.',
        ),
      );
    }

    if (profile.communityId.trim().isEmpty) {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'community-missing',
          'No community is assigned to this Security account.',
        ),
      );
    }

    final communityIsActive = await _profileStore.isCommunityActive(
      profile.communityId,
    );
    ensureCurrentSession();

    if (communityIsActive == null) {
      await _denySession(
        user,
        isCurrentSession,
        const SecurityAuthException(
          'community-not-found',
          'Assigned community could not be found.',
        ),
      );
    }

    if (!communityIsActive) {
      await _denySession(
        user,
        isSessionCurrent,
        const SecurityAuthException(
          'community-inactive',
          'This community is currently unavailable.',
        ),
      );
    }

    ensureCurrentSession();
    return profile;
  }

  Future<Never> _denySession(
    User user,
    bool Function()? isSessionCurrent,
    SecurityAuthException error,
  ) async {
    await _safeSignOut(
      expectedUid: user.uid,
      isSessionCurrent: isSessionCurrent,
    );
    throw error;
  }

  Future<void> logout() async {
    await _deactivateNotifications();
    await _auth.signOut();
  }

  Future<void> _safeSignOut({
    required String expectedUid,
    bool Function()? isSessionCurrent,
  }) async {
    bool shouldSignOut() =>
        _auth.currentUser?.uid == expectedUid &&
        (isSessionCurrent?.call() ?? true);

    if (!shouldSignOut()) return;
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _deactivateNotifications();
    } catch (_) {}
  }

  @visibleForTesting
  static bool hasVerifiedPhoneAuth({
    required String? phoneNumber,
    required String? signInProvider,
  }) =>
      phoneNumber?.trim().isNotEmpty == true &&
      signInProvider == PhoneAuthProvider.PROVIDER_ID;

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Enter a valid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'OTP service is temporarily unavailable. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check the OTP and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'This verification session has expired. Please request a new OTP.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'app-not-authorized':
        return 'This app is not authorized for phone authentication.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
