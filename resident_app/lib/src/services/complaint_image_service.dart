import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloudinary_service.dart';

/// Result class for complaint image operations (Flow Function Pattern)
class ComplaintImageResult {
  final bool success;
  final String? message;
  final String? imageUrl;
  final String? complaintId;
  final String? errorCode;

  ComplaintImageResult({
    required this.success,
    this.message,
    this.imageUrl,
    this.complaintId,
    this.errorCode,
  });

  factory ComplaintImageResult.success({
    String? message,
    String? imageUrl,
    String? complaintId,
  }) {
    return ComplaintImageResult(
      success: true,
      message: message ?? 'Operation successful',
      imageUrl: imageUrl,
      complaintId: complaintId,
    );
  }

  factory ComplaintImageResult.failure({
    required String message,
    String? errorCode,
  }) {
    return ComplaintImageResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Complaint Image Service - Flow Function Pattern
/// Uploads to Cloudinary, stores URL in Firestore, fetches and displays
class ComplaintImageService {
  static final ComplaintImageService instance =
      ComplaintImageService._internal();
  factory ComplaintImageService() => instance;
  ComplaintImageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // UPLOAD IMAGE - CLOUDINARY + FIRESTORE
  // ============================================================================

  /// Upload image to Cloudinary and save URL to Firestore
  /// Following the flow function pattern
  Future<ComplaintImageResult> uploadComplaintImage({
    required String imagePath,
    required String complaintId,
  }) async {
    try {
      print('🔵 Uploading complaint image...');
      print('📁 Complaint ID: $complaintId');
      print('📸 Image path: $imagePath');

      // Step 1: Upload to Cloudinary
      print('📤 Uploading to Cloudinary...');
      final imageUrl = await CloudinaryService.uploadImage(
        imagePath: imagePath,
        folder: 'complaints',
      );

      if (imageUrl.isEmpty) {
        print('❌ Cloudinary upload failed');
        return ComplaintImageResult.failure(
          message: 'Failed to upload image to Cloudinary',
          errorCode: 'CLOUDINARY_UPLOAD_FAILED',
        );
      }

      print('✅ Image uploaded to Cloudinary');
      print('🔗 URL: $imageUrl');

      // Step 2: Save URL to Firestore
      print('💾 Saving URL to Firestore...');
      await _firestore.collection('complaints').doc(complaintId).update({
        'imageUrl': imageUrl,
        'imageUploadedAt': FieldValue.serverTimestamp(),
        'imageUploadedBy': _auth.currentUser?.uid ?? 'unknown',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ URL saved to Firestore');
      print('📍 Path: complaints/$complaintId/imageUrl');

      return ComplaintImageResult.success(
        message: 'Image uploaded successfully',
        imageUrl: imageUrl,
        complaintId: complaintId,
      );
    } catch (e) {
      print('❌ Upload error: $e');
      return ComplaintImageResult.failure(
        message: 'Failed to upload image: $e',
        errorCode: 'UPLOAD_ERROR',
      );
    }
  }

  // ============================================================================
  // FETCH IMAGE FROM FIRESTORE
  // ============================================================================

  /// Fetch image URL from Firestore
  /// Following the flow function pattern
  Future<ComplaintImageResult> fetchComplaintImage({
    required String complaintId,
  }) async {
    try {
      print('🔵 Fetching complaint image...');
      print('📁 Complaint ID: $complaintId');

      // Get document
      final doc = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .get();

      if (!doc.exists) {
        print('❌ Complaint not found');
        return ComplaintImageResult.failure(
          message: 'Complaint not found',
          errorCode: 'COMPLAINT_NOT_FOUND',
        );
      }

      // Get image URL
      final imageUrl = doc.get('imageUrl') as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️ No image found for this complaint');
        return ComplaintImageResult.failure(
          message: 'No image found',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ Image URL fetched from Firestore');
      print('🔗 URL: $imageUrl');

      return ComplaintImageResult.success(
        message: 'Image fetched successfully',
        imageUrl: imageUrl,
        complaintId: complaintId,
      );
    } catch (e) {
      print('❌ Fetch error: $e');
      return ComplaintImageResult.failure(
        message: 'Failed to fetch image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // STREAM IMAGE FROM FIRESTORE (Real-time)
  // ============================================================================

  /// Stream image URL from Firestore in real-time
  /// Following the flow function pattern
  Stream<ComplaintImageResult> streamComplaintImage({
    required String complaintId,
  }) {
    print('🔵 Setting up complaint image stream...');
    print('📁 Complaint ID: $complaintId');

    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .snapshots()
        .map((doc) {
      try {
        if (!doc.exists) {
          print('❌ Complaint not found in stream');
          return ComplaintImageResult.failure(
            message: 'Complaint not found',
            errorCode: 'COMPLAINT_NOT_FOUND',
          );
        }

        final imageUrl = doc.get('imageUrl') as String?;

        if (imageUrl == null || imageUrl.isEmpty) {
          print('⚠️ No image in stream');
          return ComplaintImageResult.failure(
            message: 'No image found',
            errorCode: 'IMAGE_NOT_FOUND',
          );
        }

        print('✅ Image URL received from stream');
        return ComplaintImageResult.success(
          message: 'Image received',
          imageUrl: imageUrl,
          complaintId: complaintId,
        );
      } catch (e) {
        print('❌ Stream error: $e');
        return ComplaintImageResult.failure(
          message: 'Stream error: $e',
          errorCode: 'STREAM_ERROR',
        );
      }
    });
  }

  // ============================================================================
  // DELETE IMAGE
  // ============================================================================

  /// Delete image from Cloudinary and Firestore
  /// Following the flow function pattern
  Future<ComplaintImageResult> deleteComplaintImage({
    required String complaintId,
    required String publicId,
  }) async {
    try {
      print('🔵 Deleting complaint image...');
      print('📁 Complaint ID: $complaintId');

      // Delete from Cloudinary
      print('🗑️ Deleting from Cloudinary...');
      await CloudinaryService.deleteImage(publicId);
      print('✅ Deleted from Cloudinary');

      // Delete from Firestore
      print('🗑️ Deleting from Firestore...');
      await _firestore.collection('complaints').doc(complaintId).update({
        'imageUrl': FieldValue.delete(),
        'imageUploadedAt': FieldValue.delete(),
        'imageUploadedBy': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Deleted from Firestore');

      return ComplaintImageResult.success(
        message: 'Image deleted successfully',
        complaintId: complaintId,
      );
    } catch (e) {
      print('❌ Delete error: $e');
      return ComplaintImageResult.failure(
        message: 'Failed to delete image: $e',
        errorCode: 'DELETE_ERROR',
      );
    }
  }
}
