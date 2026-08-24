import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloudinary_service.dart';

/// Result class for image upload operations (Flow Function Pattern)
class ImageUploadServiceResult {
  final bool success;
  final String? message;
  final String? url;
  final List<String>? urls;
  final String? errorCode;

  ImageUploadServiceResult({
    required this.success,
    this.message,
    this.url,
    this.urls,
    this.errorCode,
  });

  factory ImageUploadServiceResult.success({
    String? message,
    String? url,
    List<String>? urls,
  }) {
    return ImageUploadServiceResult(
      success: true,
      message: message ?? 'Operation successful',
      url: url,
      urls: urls,
    );
  }

  factory ImageUploadServiceResult.failure({
    required String message,
    String? errorCode,
  }) {
    return ImageUploadServiceResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Image Upload Service - Flow Function Pattern
/// Uploads images to Cloudinary and saves URLs to Firestore
class ImageUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload image to Cloudinary and save URL to Firestore
  /// Following the flow function pattern with proper logging and error handling
  /// 
  /// Parameters:
  /// - [imagePath]: Local file path of the image
  /// - [collectionPath]: Firestore collection path (e.g., 'complaints', 'profiles')
  /// - [documentId]: Firestore document ID
  /// - [fieldName]: Field name to store the URL (e.g., 'imageUrl', 'profilePicture')
  /// - [folder]: Cloudinary folder name
  /// - [additionalData]: Additional fields to update in Firestore
  /// 
  /// Returns: ImageUploadServiceResult with success status and URL
  Future<ImageUploadServiceResult> uploadImageToCloudinaryAndFirestore({
    required String imagePath,
    required String collectionPath,
    required String documentId,
    required String fieldName,
    String? folder,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('🔵 IMAGE UPLOAD SERVICE: Starting upload...');
      print('   Image path: $imagePath');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');
      print('   Field: $fieldName');
      print('   Folder: $folder');

      // STEP 1: Upload to Cloudinary
      print('🔐 STEP 1: Uploading to Cloudinary...');
      
      String imageUrl;
      try {
        imageUrl = await CloudinaryService.uploadImage(
          imagePath: imagePath,
          folder: folder,
        );

        if (imageUrl.isEmpty) {
          print('❌ STEP 1 FAILED: Cloudinary returned empty URL');
          return ImageUploadServiceResult.failure(
            message: 'Cloudinary upload failed - empty URL',
            errorCode: 'CLOUDINARY_EMPTY_URL',
          );
        }

        print('✅ STEP 1 PASSED: Image uploaded to Cloudinary');
        print('   URL: $imageUrl');
      } catch (e) {
        print('❌ STEP 1 FAILED: Cloudinary error: $e');
        return ImageUploadServiceResult.failure(
          message: 'Cloudinary upload error: $e',
          errorCode: 'CLOUDINARY_ERROR',
        );
      }

      // STEP 2: Prepare Firestore update data
      print('🔐 STEP 2: Preparing Firestore update data...');

      final updateData = {
        fieldName: imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add any additional data
      if (additionalData != null) {
        updateData.addAll(additionalData);
        print('   Added ${additionalData.length} additional fields');
      }

      print('✅ STEP 2 PASSED: Update data prepared');

      // STEP 3: Update Firestore document
      print('🔐 STEP 3: Updating Firestore document...');

      try {
        await _firestore
            .collection(collectionPath)
            .doc(documentId)
            .update(updateData);

        print('✅ STEP 3 PASSED: Firestore document updated');
        print('   Path: $collectionPath/$documentId');
      } catch (e) {
        print('❌ STEP 3 FAILED: Firestore error: $e');
        return ImageUploadServiceResult.failure(
          message: 'Failed to save URL to Firestore: $e',
          errorCode: 'FIRESTORE_ERROR',
        );
      }

      // STEP 4: Return success result
      print('✅ IMAGE UPLOAD SERVICE: SUCCESS');

      return ImageUploadServiceResult.success(
        message: 'Image uploaded successfully',
        url: imageUrl,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE UPLOAD SERVICE: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageUploadServiceResult.failure(
        message: 'Unexpected error: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Upload image with metadata to Cloudinary and save to Firestore
  /// Following the flow function pattern with proper logging and error handling
  Future<ImageUploadServiceResult> uploadImageWithMetadataToFirestore({
    required String imagePath,
    required String collectionPath,
    required String documentId,
    required String fieldName,
    String? folder,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('🔵 IMAGE UPLOAD SERVICE: Starting upload with metadata...');
      print('   Image path: $imagePath');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');

      // STEP 1: Upload to Cloudinary with metadata
      print('🔐 STEP 1: Uploading to Cloudinary with metadata...');

      Map<String, dynamic> metadata;
      try {
        metadata = await CloudinaryService.uploadImageWithMetadata(
          imagePath: imagePath,
          folder: folder,
        );

        if (metadata['url'] == null || (metadata['url'] as String).isEmpty) {
          print('❌ STEP 1 FAILED: Cloudinary returned empty URL');
          return ImageUploadServiceResult.failure(
            message: 'Cloudinary upload failed - empty URL',
            errorCode: 'CLOUDINARY_EMPTY_URL',
          );
        }

        print('✅ STEP 1 PASSED: Image uploaded with metadata');
        print('   URL: ${metadata['url']}');
        print('   Size: ${metadata['size']} bytes');
      } catch (e) {
        print('❌ STEP 1 FAILED: Cloudinary error: $e');
        return ImageUploadServiceResult.failure(
          message: 'Cloudinary upload error: $e',
          errorCode: 'CLOUDINARY_ERROR',
        );
      }

      // STEP 2: Prepare Firestore update data
      print('🔐 STEP 2: Preparing Firestore update data with metadata...');

      final updateData = {
        fieldName: metadata['url'],
        '${fieldName}Metadata': {
          'publicId': metadata['publicId'],
          'width': metadata['width'],
          'height': metadata['height'],
          'size': metadata['size'],
          'format': metadata['format'],
          'uploadedAt': metadata['uploadedAt'],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add any additional data
      if (additionalData != null) {
        updateData.addAll(additionalData);
        print('   Added ${additionalData.length} additional fields');
      }

      print('✅ STEP 2 PASSED: Update data prepared');

      // STEP 3: Update Firestore document
      print('🔐 STEP 3: Updating Firestore document...');

      try {
        await _firestore
            .collection(collectionPath)
            .doc(documentId)
            .update(updateData);

        print('✅ STEP 3 PASSED: Firestore document updated');
      } catch (e) {
        print('❌ STEP 3 FAILED: Firestore error: $e');
        return ImageUploadServiceResult.failure(
          message: 'Failed to save to Firestore: $e',
          errorCode: 'FIRESTORE_ERROR',
        );
      }

      // STEP 4: Return success result
      print('✅ IMAGE UPLOAD SERVICE: SUCCESS');

      return ImageUploadServiceResult.success(
        message: 'Image uploaded successfully with metadata',
        url: metadata['url'] as String,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE UPLOAD SERVICE: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageUploadServiceResult.failure(
        message: 'Unexpected error: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Upload multiple images and save URLs to Firestore
  /// Following the flow function pattern with proper logging and error handling
  Future<ImageUploadServiceResult> uploadMultipleImages({
    required List<String> imagePaths,
    required String collectionPath,
    required String documentId,
    required String fieldName,
    String? folder,
  }) async {
    try {
      print('🔵 IMAGE UPLOAD SERVICE: Starting batch upload...');
      print('   Image count: ${imagePaths.length}');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');

      // STEP 1: Upload all images to Cloudinary
      print('🔐 STEP 1: Uploading ${imagePaths.length} images to Cloudinary...');

      final uploadedUrls = <String>[];
      final errors = <String>[];

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        try {
          print('   Uploading image ${i + 1}/${imagePaths.length}: $imagePath');
          
          final url = await CloudinaryService.uploadImage(
            imagePath: imagePath,
            folder: folder,
          );

          if (url.isNotEmpty) {
            uploadedUrls.add(url);
            print('   ✅ Image ${i + 1} uploaded: $url');
          } else {
            errors.add('Image ${i + 1}: Empty URL returned');
            print('   ⚠️  Image ${i + 1}: Empty URL');
          }
        } catch (e) {
          errors.add('Image ${i + 1}: $e');
          print('   ❌ Image ${i + 1} failed: $e');
        }
      }

      if (uploadedUrls.isEmpty) {
        print('❌ STEP 1 FAILED: All uploads failed');
        return ImageUploadServiceResult.failure(
          message: 'All uploads failed: ${errors.join(', ')}',
          errorCode: 'ALL_UPLOADS_FAILED',
        );
      }

      print('✅ STEP 1 PASSED: ${uploadedUrls.length}/${imagePaths.length} images uploaded');

      // STEP 2: Update Firestore with uploaded URLs
      print('🔐 STEP 2: Updating Firestore with ${uploadedUrls.length} URLs...');

      try {
        await _firestore
            .collection(collectionPath)
            .doc(documentId)
            .update({
          fieldName: uploadedUrls,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ STEP 2 PASSED: Firestore document updated');
      } catch (e) {
        print('❌ STEP 2 FAILED: Firestore error: $e');
        return ImageUploadServiceResult.failure(
          message: 'Failed to save URLs to Firestore: $e',
          errorCode: 'FIRESTORE_ERROR',
        );
      }

      // STEP 3: Return success result
      print('✅ IMAGE UPLOAD SERVICE: SUCCESS');
      print('   Uploaded: ${uploadedUrls.length}');
      print('   Failed: ${errors.length}');

      return ImageUploadServiceResult.success(
        message: 'Uploaded ${uploadedUrls.length} images successfully',
        urls: uploadedUrls,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE UPLOAD SERVICE: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageUploadServiceResult.failure(
        message: 'Unexpected error: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Delete image from Cloudinary and update Firestore
  /// Following the flow function pattern with proper logging and error handling
  Future<ImageUploadServiceResult> deleteImageFromCloudinaryAndFirestore({
    required String publicId,
    required String collectionPath,
    required String documentId,
    required String fieldName,
  }) async {
    try {
      print('🔵 IMAGE UPLOAD SERVICE: Starting image deletion...');
      print('   Public ID: $publicId');
      print('   Collection: $collectionPath');
      print('   Document: $documentId');

      // STEP 1: Delete from Cloudinary
      print('🔐 STEP 1: Deleting from Cloudinary...');

      try {
        await CloudinaryService.deleteImage(publicId);
        print('✅ STEP 1 PASSED: Image deleted from Cloudinary');
      } catch (e) {
        print('⚠️  STEP 1 WARNING: Cloudinary deletion failed: $e');
        print('   Continuing with Firestore cleanup...');
      }

      // STEP 2: Update Firestore to remove URL
      print('🔐 STEP 2: Updating Firestore document...');

      try {
        await _firestore
            .collection(collectionPath)
            .doc(documentId)
            .update({
          fieldName: FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ STEP 2 PASSED: Firestore document updated');
      } catch (e) {
        print('❌ STEP 2 FAILED: Firestore error: $e');
        return ImageUploadServiceResult.failure(
          message: 'Failed to update Firestore: $e',
          errorCode: 'FIRESTORE_ERROR',
        );
      }

      // STEP 3: Return success result
      print('✅ IMAGE UPLOAD SERVICE: SUCCESS');

      return ImageUploadServiceResult.success(
        message: 'Image deleted successfully',
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE UPLOAD SERVICE: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageUploadServiceResult.failure(
        message: 'Unexpected error: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }
}
