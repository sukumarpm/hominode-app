// lib/src/services/image_upload_flow_function.dart
// Complete Image Upload Flow Function - Handles all image operations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'cloudinary_service.dart';

/// Image Upload Result
class ImageUploadResult {
  final bool success;
  final String? message;
  final String? imageUrl;
  final String? imagePath;
  final String? errorCode;

  ImageUploadResult({
    required this.success,
    this.message,
    this.imageUrl,
    this.imagePath,
    this.errorCode,
  });

  factory ImageUploadResult.success({
    String? message,
    String? imageUrl,
    String? imagePath,
  }) {
    return ImageUploadResult(
      success: true,
      message: message ?? 'Operation successful',
      imageUrl: imageUrl,
      imagePath: imagePath,
    );
  }

  factory ImageUploadResult.failure({
    required String message,
    String? errorCode,
  }) {
    return ImageUploadResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Image Upload Flow Function Service
/// Complete flow: Validate → Upload to Cloudinary → Save to Firestore → Return URL
class ImageUploadFlowFunction {
  static final ImageUploadFlowFunction instance =
      ImageUploadFlowFunction._internal();
  factory ImageUploadFlowFunction() => instance;
  ImageUploadFlowFunction._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // MAIN FLOW FUNCTION: Upload Image
  // ============================================================================

  /// Complete image upload flow function
  /// Step 1: Validate user authentication
  /// Step 2: Validate image file
  /// Step 3: Upload to Cloudinary
  /// Step 4: Save URL to Firestore
  /// Step 5: Return result with image URL
  Future<ImageUploadResult> uploadImage({
    required String imagePath,
    required String folder,
    String? publicId,
  }) async {
    try {
      print('🔵 IMAGE UPLOAD FLOW: Starting image upload...');
      print('   Image path: $imagePath');
      print('   Folder: $folder');

      // ========================================================================
      // STEP 1: Validate User Authentication
      // ========================================================================
      print('🔐 STEP 1: Validating user authentication...');

      final userId = await _validateUserAuthentication();
      if (userId == null) {
        print('❌ STEP 1 FAILED: User not authenticated');
        return ImageUploadResult.failure(
          message: 'User not authenticated. Please login first.',
          errorCode: 'NOT_AUTHENTICATED',
        );
      }

      print('✅ STEP 1 PASSED: User authenticated');
      print('   User ID: $userId');

      // ========================================================================
      // STEP 2: Validate Image File
      // ========================================================================
      print('🔐 STEP 2: Validating image file...');

      final validationResult = _validateImageFile(imagePath);
      if (!validationResult.success) {
        print('❌ STEP 2 FAILED: ${validationResult.message}');
        return validationResult;
      }

      print('✅ STEP 2 PASSED: Image file is valid');
      print('   File size: ${File(imagePath).lengthSync()} bytes');

      // ========================================================================
      // STEP 3: Upload to Cloudinary
      // ========================================================================
      print('🔐 STEP 3: Uploading to Cloudinary...');

      final finalPublicId = publicId ?? 'user_$userId';
      print('   Public ID: $finalPublicId');
      print('   Folder: $folder');

      // Validate Cloudinary configuration
      try {
        if (CloudinaryService.uploadPreset.isEmpty) {
          print('❌ STEP 3 FAILED: Cloudinary upload preset not configured');
          return ImageUploadResult.failure(
            message: 'Cloudinary is not properly configured',
            errorCode: 'CLOUDINARY_NOT_CONFIGURED',
          );
        }
        
        print('   ✅ Upload preset configured: ${CloudinaryService.uploadPreset}');
        print('   ✅ Cloud name: ${CloudinaryService.cloudName}');
        print('   ✅ Upload URL: ${CloudinaryService.uploadUrl}');
        print('   ✅ Profile pictures folder: ${CloudinaryService.profilePicturesFolder}');
      } catch (e) {
        print('❌ STEP 3 FAILED: Error checking Cloudinary config: $e');
        return ImageUploadResult.failure(
          message: 'Cloudinary configuration error: $e',
          errorCode: 'CLOUDINARY_CONFIG_ERROR',
        );
      }

      String imageUrl;
      try {
        print('   📤 Calling CloudinaryService.uploadImage()...');
        print('   📁 Uploading to folder: $folder');
        
        imageUrl = await CloudinaryService.uploadImage(
          imagePath: imagePath,
          folder: folder,
          publicId: finalPublicId,
        );

        if (imageUrl.isEmpty) {
          print('❌ STEP 3 FAILED: Cloudinary returned empty URL');
          return ImageUploadResult.failure(
            message: 'Failed to upload image to Cloudinary',
            errorCode: 'CLOUDINARY_UPLOAD_FAILED',
          );
        }

        print('✅ STEP 3 PASSED: Image uploaded to Cloudinary');
        print('   URL: $imageUrl');
        print('   URL length: ${imageUrl.length}');
        print('   URL starts with https: ${imageUrl.startsWith('https')}');
        print('   Folder in URL: $folder');
      } catch (e, stackTrace) {
        print('❌ STEP 3 FAILED: Cloudinary error: $e');
        print('   Stack trace: $stackTrace');
        return ImageUploadResult.failure(
          message: 'Cloudinary upload error: $e',
          errorCode: 'CLOUDINARY_ERROR',
        );
      }

      // ========================================================================
      // STEP 4: Save URL to Firestore
      // ========================================================================
      print('🔐 STEP 4: Saving URL to Firestore...');

      final firestoreResult = await _saveImageUrlToFirestore(
        userId: userId,
        imageUrl: imageUrl,
        folder: folder,
      );

      if (!firestoreResult.success) {
        print('❌ STEP 4 FAILED: ${firestoreResult.message}');
        return firestoreResult;
      }

      print('✅ STEP 4 PASSED: URL saved to Firestore');

      // ========================================================================
      // STEP 5: Return Success Result
      // ========================================================================
      print('🔐 STEP 5: Returning success result...');

      final result = ImageUploadResult.success(
        message: 'Image uploaded successfully',
        imageUrl: imageUrl,
        imagePath: imagePath,
      );

      print('✅ STEP 5 PASSED: Image upload complete');
      print('✅ IMAGE UPLOAD FLOW: SUCCESS');
      print('   Final URL: $imageUrl');

      return result;
    } catch (e, stackTrace) {
      print('❌ IMAGE UPLOAD FLOW: Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return ImageUploadResult.failure(
        message: 'Unexpected error: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  // ============================================================================
  // HELPER FUNCTIONS
  // ============================================================================

  /// Validate user authentication
  /// Returns user ID if authenticated, null otherwise
  Future<String?> _validateUserAuthentication() async {
    print('   Checking Firebase Auth...');

    // Try Firebase Auth first
    var userId = _auth.currentUser?.uid;

    if (userId != null) {
      print('   ✅ Found Firebase Auth UID: $userId');
      return userId;
    }

    print('   ⚠️  Firebase Auth UID not found, checking Firestore...');

    // Fallback: Query Firestore for user
    try {
      final userQuery = await _firestore
          .collection('users')
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        userId = userQuery.docs.first.id;
        print('   ✅ Found user in Firestore: $userId');
        return userId;
      }
    } catch (e) {
      print('   ❌ Firestore query error: $e');
    }

    print('   ❌ No user found');
    return null;
  }

  /// Validate image file
  ImageUploadResult _validateImageFile(String imagePath) {
    print('   Checking file exists...');

    final file = File(imagePath);

    if (!file.existsSync()) {
      print('   ❌ File does not exist: $imagePath');
      return ImageUploadResult.failure(
        message: 'Image file not found',
        errorCode: 'FILE_NOT_FOUND',
      );
    }

    print('   ✅ File exists');

    // Check file size (max 10MB)
    final fileSize = file.lengthSync();
    const maxSize = 10 * 1024 * 1024; // 10MB

    print('   Checking file size: ${fileSize / 1024 / 1024} MB');

    if (fileSize > maxSize) {
      print('   ❌ File too large');
      return ImageUploadResult.failure(
        message: 'Image file is too large (max 10MB)',
        errorCode: 'FILE_TOO_LARGE',
      );
    }

    print('   ✅ File size is valid');

    // Check file extension
    final extension = imagePath.split('.').last.toLowerCase();
    const validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    print('   Checking file extension: $extension');

    if (!validExtensions.contains(extension)) {
      print('   ❌ Invalid file extension');
      return ImageUploadResult.failure(
        message: 'Invalid image format. Supported: JPG, PNG, GIF, WebP',
        errorCode: 'INVALID_FORMAT',
      );
    }

    print('   ✅ File extension is valid');

    // Check MIME type by reading file header
    print('   Checking MIME type...');
    try {
      final bytes = file.readAsBytesSync().take(12).toList();
      
      // Check magic numbers for common image formats
      bool isValidMimeType = false;
      
      // JPEG: FF D8 FF
      if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        isValidMimeType = true;
        print('   ✅ MIME type: JPEG');
      }
      // PNG: 89 50 4E 47
      else if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        isValidMimeType = true;
        print('   ✅ MIME type: PNG');
      }
      // GIF: 47 49 46
      else if (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        isValidMimeType = true;
        print('   ✅ MIME type: GIF');
      }
      // WebP: RIFF ... WEBP
      else if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
        if (bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
          isValidMimeType = true;
          print('   ✅ MIME type: WebP');
        }
      }
      
      if (!isValidMimeType) {
        print('   ⚠️  Could not verify MIME type, but extension is valid');
      }
    } catch (e) {
      print('   ⚠️  Could not read file header: $e');
    }

    return ImageUploadResult.success(
      message: 'Image file is valid',
    );
  }

  /// Save image URL to Firestore
  Future<ImageUploadResult> _saveImageUrlToFirestore({
    required String userId,
    required String imageUrl,
    required String folder,
  }) async {
    try {
      print('   Querying user document...');
      print('   User ID: $userId');
      print('   Image URL: $imageUrl');
      print('   Folder: $folder');

      // Try to find user document
      var userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('   ⚠️  User document not found by ID, searching by authUid...');

        // Try to find by authUid field
        final querySnapshot = await _firestore
            .collection('users')
            .where('authUid', isEqualTo: userId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          print('   ❌ User document not found');
          print('   ⚠️  Image uploaded to Cloudinary but not saved to Firestore');
          print('   ⚠️  Orphaned image URL: $imageUrl');
          return ImageUploadResult.failure(
            message: 'User document not found in Firestore. Image uploaded but not linked to user.',
            errorCode: 'USER_NOT_FOUND',
          );
        }

        userDoc = querySnapshot.docs.first;
        print('   ✅ Found user document by authUid');
      } else {
        print('   ✅ Found user document by ID');
      }

      final docId = userDoc.id;
      print('   Document ID: $docId');

      // Prepare update data based on folder
      final updateData = _prepareUpdateData(imageUrl, folder);

      print('   Updating Firestore document...');
      print('   Update data keys: ${updateData.keys.toList()}');
      print('   Folder: $folder');
      print('   Image URL: $imageUrl');

      // Update document
      await _firestore.collection('users').doc(docId).update(updateData);

      print('   ✅ Firestore document updated successfully');
      print('   ✅ Fields updated:');
      updateData.forEach((key, value) {
        if (value is FieldValue) {
          print('      - $key: serverTimestamp');
        } else {
          print('      - $key: $value');
        }
      });

      return ImageUploadResult.success(
        message: 'Image URL saved to Firestore',
        imageUrl: imageUrl,
      );
    } catch (e, stackTrace) {
      print('   ❌ Firestore error: $e');
      print('   Stack trace: $stackTrace');
      return ImageUploadResult.failure(
        message: 'Failed to save image URL to Firestore: $e',
        errorCode: 'FIRESTORE_ERROR',
      );
    }
  }

  /// Prepare update data based on folder
  Map<String, dynamic> _prepareUpdateData(String imageUrl, String folder) {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    switch (folder) {
      case 'profile_pictures':
        updateData['profileImage'] = imageUrl;
        updateData['profileImageUrl'] = imageUrl;
        // Use serverTimestamp for cache-busting in stream
        updateData['profileImageUpdatedAt'] = FieldValue.serverTimestamp();
        break;

      case 'complaint_images':
        // For complaints, we'll store in a subcollection
        updateData['lastComplaintImageUrl'] = imageUrl;
        break;

      case 'community_wall':
        updateData['lastPostImageUrl'] = imageUrl;
        break;

      case 'marketplace':
        updateData['lastListingImageUrl'] = imageUrl;
        break;

      default:
        updateData['lastImageUrl'] = imageUrl;
        updateData['lastImageFolder'] = folder;
    }

    return updateData;
  }

  // ============================================================================
  // FETCH IMAGE
  // ============================================================================

  /// Fetch image URL from Firestore
  Future<ImageUploadResult> fetchImageUrl({
    required String userId,
    required String folder,
  }) async {
    try {
      print('🔵 FETCH IMAGE: Getting image URL from Firestore...');
      print('   User ID: $userId');
      print('   Folder: $folder');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        print('❌ User document not found');
        return ImageUploadResult.failure(
          message: 'User not found',
          errorCode: 'USER_NOT_FOUND',
        );
      }

      String? imageUrl;

      switch (folder) {
        case 'profile_pictures':
          imageUrl = doc.get('profileImage') as String? ??
              doc.get('profileImageUrl') as String?;
          break;

        case 'complaint_images':
          imageUrl = doc.get('lastComplaintImageUrl') as String?;
          break;

        case 'community_wall':
          imageUrl = doc.get('lastPostImageUrl') as String?;
          break;

        case 'marketplace':
          imageUrl = doc.get('lastListingImageUrl') as String?;
          break;

        default:
          imageUrl = doc.get('lastImageUrl') as String?;
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️  No image found for this folder');
        return ImageUploadResult.failure(
          message: 'No image found',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ Image URL fetched: $imageUrl');

      return ImageUploadResult.success(
        message: 'Image fetched successfully',
        imageUrl: imageUrl,
      );
    } catch (e) {
      print('❌ Error fetching image: $e');
      return ImageUploadResult.failure(
        message: 'Failed to fetch image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // DELETE IMAGE
  // ============================================================================

  /// Delete image from Cloudinary and Firestore
  Future<ImageUploadResult> deleteImage({
    required String userId,
    required String publicId,
    required String folder,
  }) async {
    try {
      print('🔵 DELETE IMAGE: Deleting image...');
      print('   User ID: $userId');
      print('   Public ID: $publicId');
      print('   Folder: $folder');

      // STEP 1: Verify image exists in Firestore
      print('   STEP 1: Verifying image exists...');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('   ❌ User document not found');
        return ImageUploadResult.failure(
          message: 'User not found',
          errorCode: 'USER_NOT_FOUND',
        );
      }

      final data = userDoc.data() as Map<String, dynamic>;
      String? existingImageUrl;

      switch (folder) {
        case 'profile_pictures':
          existingImageUrl = data['profileImage'] as String? ?? data['profileImageUrl'] as String?;
          break;
        case 'complaint_images':
          existingImageUrl = data['lastComplaintImageUrl'] as String?;
          break;
        case 'community_wall':
          existingImageUrl = data['lastPostImageUrl'] as String?;
          break;
        case 'marketplace':
          existingImageUrl = data['lastListingImageUrl'] as String?;
          break;
        default:
          existingImageUrl = data['lastImageUrl'] as String?;
      }

      if (existingImageUrl == null || existingImageUrl.isEmpty) {
        print('   ⚠️  No image found to delete');
        return ImageUploadResult.failure(
          message: 'No image found to delete',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('   ✅ Image verified: $existingImageUrl');

      // STEP 2: Delete from Cloudinary
      print('   STEP 2: Deleting from Cloudinary...');
      try {
        await CloudinaryService.deleteImage(publicId);
        print('   ✅ Deleted from Cloudinary');
      } catch (e) {
        print('   ⚠️  Cloudinary deletion failed: $e');
        print('   Continuing with Firestore cleanup...');
      }

      // STEP 3: Delete from Firestore
      print('   STEP 3: Deleting from Firestore...');

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (folder) {
        case 'profile_pictures':
          updateData['profileImage'] = FieldValue.delete();
          updateData['profileImageUrl'] = FieldValue.delete();
          updateData['profileImageUpdatedAt'] = FieldValue.delete();
          break;

        case 'complaint_images':
          updateData['lastComplaintImageUrl'] = FieldValue.delete();
          break;

        case 'community_wall':
          updateData['lastPostImageUrl'] = FieldValue.delete();
          break;

        case 'marketplace':
          updateData['lastListingImageUrl'] = FieldValue.delete();
          break;

        default:
          updateData['lastImageUrl'] = FieldValue.delete();
          updateData['lastImageFolder'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(userId).update(updateData);
      print('   ✅ Deleted from Firestore');

      print('✅ Image deleted successfully');

      return ImageUploadResult.success(
        message: 'Image deleted successfully',
      );
    } catch (e) {
      print('❌ Error deleting image: $e');
      return ImageUploadResult.failure(
        message: 'Failed to delete image: $e',
        errorCode: 'DELETE_ERROR',
      );
    }
  }
}
