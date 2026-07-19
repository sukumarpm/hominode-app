import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result class for image operations (following flow function pattern)
class ImageResult {
  final bool success;
  final String? message;
  final String? imageUrl;
  final String? imageData;
  final String? errorCode;

  ImageResult({
    required this.success,
    this.message,
    this.imageUrl,
    this.imageData,
    this.errorCode,
  });

  factory ImageResult.success({
    String? message,
    String? imageUrl,
    String? imageData,
  }) {
    return ImageResult(
      success: true,
      message: message ?? 'Image operation successful',
      imageUrl: imageUrl,
      imageData: imageData,
    );
  }

  factory ImageResult.failure({required String message, String? errorCode}) {
    return ImageResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Image Firestore Service - Following flow function pattern
/// Stores images in Firestore and fetches them
class ImageFirestoreService {
  static final ImageFirestoreService instance = ImageFirestoreService._internal();
  factory ImageFirestoreService() => instance;
  ImageFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // UPLOAD IMAGE TO FIRESTORE
  // ============================================================================

  /// Upload image to Firestore as base64
  /// Following the flow function pattern with comprehensive logging
  /// Step 1: Validate file exists → Step 2: Read and encode → Step 3: Save to Firestore
  Future<ImageResult> uploadImageToFirestore({
    required String imagePath,
    required String collectionPath,
    required String documentId,
    required String fieldName,
    String? folder,
  }) async {
    try {
      print('🔵 IMAGE FIRESTORE SERVICE: Starting upload...');
      print('   Image path: $imagePath');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');
      print('   Field: $fieldName');

      // STEP 1: Validate file exists
      print('🔐 STEP 1: Validating image file...');

      final file = File(imagePath);
      if (!file.existsSync()) {
        print('❌ STEP 1 FAILED: Image file not found: $imagePath');
        return ImageResult.failure(
          message: 'Image file not found',
          errorCode: 'FILE_NOT_FOUND',
        );
      }

      print('✅ STEP 1 PASSED: File exists');

      // STEP 2: Read file and convert to base64
      print('🔐 STEP 2: Reading and encoding image...');

      final bytes = await file.readAsBytes();
      print('   File size: ${bytes.length} bytes');

      final base64String = base64Encode(bytes);
      print('✅ STEP 2 PASSED: Image encoded to base64');

      // Get file extension and MIME type
      final extension = imagePath.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      print('   MIME type: $mimeType');

      // Create data URL
      final dataUrl = 'data:$mimeType;base64,$base64String';

      // STEP 3: Save to Firestore
      print('🔐 STEP 3: Saving to Firestore...');

      final updateData = {
        fieldName: dataUrl,
        '${fieldName}Metadata': {
          'size': bytes.length,
          'format': extension,
          'mimeType': mimeType,
          'uploadedAt': FieldValue.serverTimestamp(),
          'uploadedBy': _auth.currentUser?.uid ?? 'unknown',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await _firestore
            .collection(collectionPath)
            .doc(documentId)
            .update(updateData);

        print('✅ STEP 3 PASSED: Image saved to Firestore');
        print('   Path: $collectionPath/$documentId/$fieldName');
      } catch (e) {
        print('❌ STEP 3 FAILED: Firestore error: $e');
        return ImageResult.failure(
          message: 'Failed to save to Firestore: $e',
          errorCode: 'FIRESTORE_ERROR',
        );
      }

      // STEP 4: Return success
      print('✅ IMAGE FIRESTORE SERVICE: SUCCESS');

      return ImageResult.success(
        message: 'Image uploaded successfully',
        imageUrl: dataUrl,
        imageData: base64String,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE FIRESTORE SERVICE: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageResult.failure(
        message: 'Failed to upload image: $e',
        errorCode: 'UPLOAD_ERROR',
      );
    }
  }

  // ============================================================================
  // FETCH IMAGE FROM FIRESTORE
  // ============================================================================

  /// Fetch image from Firestore
  /// Following the flow function pattern with comprehensive logging
  /// Step 1: Query document → Step 2: Extract image data → Step 3: Return result
  Future<ImageResult> fetchImageFromFirestore({
    required String collectionPath,
    required String documentId,
    required String fieldName,
  }) async {
    try {
      print('🔵 IMAGE FIRESTORE SERVICE: Starting fetch...');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');
      print('   Field: $fieldName');

      // STEP 1: Query Firestore document
      print('🔐 STEP 1: Querying Firestore document...');

      final doc = await _firestore
          .collection(collectionPath)
          .doc(documentId)
          .get();

      if (!doc.exists) {
        print('❌ STEP 1 FAILED: Document not found');
        return ImageResult.failure(
          message: 'Document not found',
          errorCode: 'DOC_NOT_FOUND',
        );
      }

      print('✅ STEP 1 PASSED: Document found');

      // STEP 2: Extract image data
      print('🔐 STEP 2: Extracting image data...');

      final imageData = doc.get(fieldName) as String?;

      if (imageData == null || imageData.isEmpty) {
        print('❌ STEP 2 FAILED: Image field not found or empty');
        return ImageResult.failure(
          message: 'Image not found in document',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ STEP 2 PASSED: Image data extracted');
      print('   Data size: ${imageData.length} characters');

      // STEP 3: Return success
      print('✅ IMAGE FIRESTORE SERVICE: SUCCESS');

      return ImageResult.success(
        message: 'Image fetched successfully',
        imageUrl: imageData,
        imageData: imageData,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE FIRESTORE SERVICE: Error: $e');
      print('   Stack trace: $stackTrace');
      return ImageResult.failure(
        message: 'Failed to fetch image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // STREAM IMAGE FROM FIRESTORE (Real-time)
  // ============================================================================

  /// Stream image from Firestore in real-time
  /// Following the flow function pattern with comprehensive logging
  Stream<ImageResult> streamImageFromFirestore({
    required String collectionPath,
    required String documentId,
    required String fieldName,
  }) {
    print('🔵 IMAGE FIRESTORE SERVICE: Setting up stream...');
    print('   Collection: $collectionPath');
    print('   Document: $documentId');
    print('   Field: $fieldName');

    return _firestore
        .collection(collectionPath)
        .doc(documentId)
        .snapshots()
        .map((doc) {
      try {
        if (!doc.exists) {
          print('❌ Document not found in stream');
          return ImageResult.failure(
            message: 'Document not found',
            errorCode: 'DOC_NOT_FOUND',
          );
        }

        final imageData = doc.get(fieldName) as String?;

        if (imageData == null || imageData.isEmpty) {
          print('⚠️  Image field empty in stream');
          return ImageResult.failure(
            message: 'Image not found',
            errorCode: 'IMAGE_NOT_FOUND',
          );
        }

        print('✅ Image received from stream');
        print('   Size: ${imageData.length} characters');
        return ImageResult.success(
          message: 'Image received',
          imageUrl: imageData,
          imageData: imageData,
        );
      } catch (e) {
        print('❌ Stream error: $e');
        return ImageResult.failure(
          message: 'Stream error: $e',
          errorCode: 'STREAM_ERROR',
        );
      }
    });
  }

  // ============================================================================
  // DELETE IMAGE FROM FIRESTORE
  // ============================================================================

  /// Delete image from Firestore
  /// Following the flow function pattern with comprehensive logging
  /// Step 1: Verify document exists → Step 2: Delete image field → Step 3: Return result
  Future<ImageResult> deleteImageFromFirestore({
    required String collectionPath,
    required String documentId,
    required String fieldName,
  }) async {
    try {
      print('🔵 IMAGE FIRESTORE SERVICE: Starting deletion...');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');
      print('   Field: $fieldName');

      // STEP 1: Verify document exists
      print('🔐 STEP 1: Verifying document exists...');

      final doc = await _firestore
          .collection(collectionPath)
          .doc(documentId)
          .get();

      if (!doc.exists) {
        print('❌ STEP 1 FAILED: Document not found');
        return ImageResult.failure(
          message: 'Document not found',
          errorCode: 'DOC_NOT_FOUND',
        );
      }

      print('✅ STEP 1 PASSED: Document exists');

      // STEP 2: Delete image field
      print('🔐 STEP 2: Deleting image field...');

      try {
        await _firestore
            .collection(collectionPath)
            .doc(documentId)
            .update({
          fieldName: FieldValue.delete(),
          '${fieldName}Metadata': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ STEP 2 PASSED: Image field deleted');
      } catch (e) {
        print('❌ STEP 2 FAILED: Firestore error: $e');
        return ImageResult.failure(
          message: 'Failed to delete image: $e',
          errorCode: 'DELETE_ERROR',
        );
      }

      // STEP 3: Return success
      print('✅ IMAGE FIRESTORE SERVICE: SUCCESS');

      return ImageResult.success(message: 'Image deleted successfully');
    } catch (e, stackTrace) {
      print('❌ IMAGE FIRESTORE SERVICE: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageResult.failure(
        message: 'Failed to delete image: $e',
        errorCode: 'DELETE_ERROR',
      );
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }

  /// Convert base64 data URL to Image widget
  /// Usage: Image.memory(base64Decode(imageData.split(',').last))
  static List<int> decodeImageData(String dataUrl) {
    try {
      // Extract base64 part from data URL
      final base64String = dataUrl.split(',').last;
      return base64Decode(base64String);
    } catch (e) {
      print('❌ Error decoding image: $e');
      return [];
    }
  }
}
