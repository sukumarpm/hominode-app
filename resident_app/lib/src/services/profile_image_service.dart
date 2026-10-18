import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'profile_diagnostics.dart';
import 'resident_image_operations.dart';

class ProfileImageResult {
  final bool success;
  final String? message, imageUrl, errorCode;
  ProfileImageResult({
    required this.success,
    this.message,
    this.imageUrl,
    this.errorCode,
  });
  factory ProfileImageResult.success({String? message, String? imageUrl}) =>
      ProfileImageResult(success: true, message: message, imageUrl: imageUrl);
  factory ProfileImageResult.failure({
    required String message,
    String? errorCode,
  }) => ProfileImageResult(
    success: false,
    message: message,
    errorCode: errorCode,
  );
}

class ProfileImageService {
  static final instance = ProfileImageService._internal();
  factory ProfileImageService() => instance;
  ProfileImageService._internal()
    : _operations = ResidentImageOperations(),
      _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _verifyDevice = _verifyAppCheck;

  @visibleForTesting
  ProfileImageService.forTesting({
    required ResidentImageOperations operations,
    required String? Function() currentUid,
    required Future<void> Function() verifyDevice,
  }) : _operations = operations,
       _currentUid = currentUid,
       _verifyDevice = verifyDevice;

  final ResidentImageOperations _operations;
  final String? Function() _currentUid;
  final Future<void> Function() _verifyDevice;

  static Future<void> _verifyAppCheck() async {
    // Use valid cached attestation and the SDK's normal refresh/backoff policy.
    // Forcing a token exchange on every Save tap amplifies debug-provider 403s.
    // Failure still stops private uploads before any staging or attachment.
    final token = await FirebaseAppCheck.instance.getToken().timeout(
      const Duration(seconds: 20),
    );
    if (token == null || token.isEmpty) {
      throw StateError('Device verification is unavailable.');
    }
  }

  Future<ProfileImageResult> uploadProfileImage({
    required String imagePath,
  }) async {
    var stage = 'session';
    try {
      final uid = _currentUid();
      if (uid == null) {
        throw StateError('Sign in to update your photo.');
      }
      stage = 'app-check';
      await _verifyDevice();
      stage = 'profile-read';
      final record = await _operations.record('profile', uid);
      stage = 'image-upload';
      final reference = await _operations.upload(
        feature: 'profile',
        resourceId: uid,
        imagePath: imagePath,
      );
      stage = 'image-attach';
      await _operations.save(
        feature: 'profile',
        resourceId: uid,
        revision: record['imageRevision'] as int? ?? 0,
        references: [reference],
      );
      return ProfileImageResult.success(imageUrl: reference);
    } catch (error) {
      logProfileFailure(stage, error);
      if (stage == 'app-check' && kDebugMode) {
        debugPrint(
          'Resident photo upload blocked: verify this Resident app/device App Check debug registration in Firebase Console, then retry.',
        );
      }
      return ProfileImageResult.failure(
        message: 'Unable to save your photo. Please retry.',
        errorCode: stage == 'app-check'
            ? 'APP_CHECK_UNAVAILABLE'
            : 'UPLOAD_ERROR',
      );
    }
  }

  static ProfileImageResult fromData(Map<String, dynamic>? data) {
    final reference =
        data?['profileImage'] as String? ??
        data?['profileImageUrl'] as String? ??
        data?['photoURL'] as String? ??
        data?['photoUrl'] as String?;
    return reference?.isNotEmpty == true
        ? ProfileImageResult.success(imageUrl: reference)
        : ProfileImageResult.failure(
            message: 'No image found',
            errorCode: 'IMAGE_NOT_FOUND',
          );
  }

  Future<ProfileImageResult> fetchProfileImage({
    required String userId,
  }) async => fromData(
    (await FirebaseFirestore.instance.collection('users').doc(userId).get())
        .data(),
  );
  Stream<ProfileImageResult> streamProfileImage({required String userId}) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .map((doc) => fromData(doc.data()));
  Future<ProfileImageResult> deleteProfileImage({
    required String userId,
    required String publicId,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError('Sign in to update your photo.');
      }
      final record = await _operations.record('profile', userId);
      await _operations.save(
        feature: 'profile',
        resourceId: userId,
        revision: record['imageRevision'] as int? ?? 0,
        references: [],
      );
      return ProfileImageResult.success();
    } catch (_) {
      return ProfileImageResult.failure(
        message: 'Unable to remove your photo.',
        errorCode: 'DELETE_ERROR',
      );
    }
  }

  Future<ProfileImageResult> forceRefreshProfileImage({
    required String userId,
  }) => fetchProfileImage(userId: userId);
}
