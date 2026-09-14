import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

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
          await _auth.signInWithCredential(credential);
          await requireSecurityProfile();

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

      await _auth.signInWithCredential(credential);

      return requireSecurityProfile();
    } on SecurityAuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      await _safeSignOut();

      throw SecurityAuthException(e.code, _firebaseAuthMessage(e));
    } catch (_) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'verification-failed',
        'OTP verification failed. Please try again.',
      );
    }
  }

  Future<SecurityUserModel> requireSecurityProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const SecurityAuthException(
        'unauthenticated',
        'Please sign in to continue.',
      );
    }

    final doc = await _firestore
        .collection('securityStaff')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'profile-not-found',
        'No Security account is linked to this phone number. Please contact your Community Admin.',
      );
    }

    final profile = SecurityUserModel.fromFirestore(doc);

    if (profile.uid != user.uid) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'invalid-profile',
        'Security account could not be verified.',
      );
    }

    if (profile.role != 'security') {
      await _safeSignOut();

      throw const SecurityAuthException(
        'wrong-role',
        'This phone number is not registered as a Security account.',
      );
    }

    if (!profile.isActive) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'account-disabled',
        'Your Security account is not active. Please contact your Community Admin.',
      );
    }

    if (profile.communityId.trim().isEmpty) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'community-missing',
        'No community is assigned to this Security account.',
      );
    }

    final communityDoc = await _firestore
        .collection('communities')
        .doc(profile.communityId)
        .get();

    if (!communityDoc.exists) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'community-not-found',
        'Assigned community could not be found.',
      );
    }

    final community = SecurityCommunityModel.fromFirestore(communityDoc);

    if (!community.isActive) {
      await _safeSignOut();

      throw const SecurityAuthException(
        'community-inactive',
        'This community is currently unavailable.',
      );
    }

    return profile;
  }

  Future<void> logout() async {
    await HominodePushNotifications.instance.deactivateForLogout();
    await _auth.signOut();
  }

  Future<void> _safeSignOut() async {
    try {
      await HominodePushNotifications.instance.deactivateForLogout();
      await _auth.signOut();
    } catch (_) {}
  }

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
