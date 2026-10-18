import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  ProfileImageService._internal();
  final _operations = ResidentImageOperations();
  Future<ProfileImageResult> uploadProfileImage({
    required String imagePath,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('Sign in to update your photo.');
      }
      final record = await _operations.record('profile', uid);
      final reference = await _operations.upload(
        feature: 'profile',
        resourceId: uid,
        imagePath: imagePath,
      );
      await _operations.save(
        feature: 'profile',
        resourceId: uid,
        revision: record['imageRevision'] as int? ?? 0,
        references: [reference],
      );
      return ProfileImageResult.success(imageUrl: reference);
    } catch (_) {
      return ProfileImageResult.failure(
        message: 'Unable to save your photo. Please retry.',
        errorCode: 'UPLOAD_ERROR',
      );
    }
  }

  static ProfileImageResult fromData(Map<String, dynamic>? data) {
    final reference =
        data?['profileImage'] as String? ?? data?['profileImageUrl'] as String?;
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
