// lib/src/services/image_display_flow_function.dart
// Complete Image Display Flow Function - Fetch and Display Images

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Image Display Result
class ImageDisplayResult {
  final bool success;
  final String? message;
  final String? imageUrl;
  final String? errorCode;

  ImageDisplayResult({
    required this.success,
    this.message,
    this.imageUrl,
    this.errorCode,
  });

  factory ImageDisplayResult.success({
    String? message,
    String? imageUrl,
  }) {
    return ImageDisplayResult(
      success: true,
      message: message ?? 'Image fetched successfully',
      imageUrl: imageUrl,
    );
  }

  factory ImageDisplayResult.failure({
    required String message,
    String? errorCode,
  }) {
    return ImageDisplayResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Image Display Flow Function Service
/// Complete flow: Query Firestore → Get Image URL → Return for Display
class ImageDisplayFlowFunction {
  static final ImageDisplayFlowFunction instance =
      ImageDisplayFlowFunction._internal();
  factory ImageDisplayFlowFunction() => instance;
  ImageDisplayFlowFunction._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // MARKETPLACE PRODUCT IMAGE
  // ============================================================================

  /// Get marketplace product image
  /// Flow: Validate input → Query listing → Get imageUrl field → Return URL
  Future<ImageDisplayResult> getMarketplaceProductImage({
    required String listingId,
  }) async {
    try {
      print('🔵 IMAGE DISPLAY FLOW: Getting marketplace product image...');
      print('   Listing ID: $listingId');

      // Step 1: Validate input
      print('🔐 STEP 1: Validating input parameters...');

      if (listingId.isEmpty) {
        print('❌ STEP 1 FAILED: Listing ID is empty');
        return ImageDisplayResult.failure(
          message: 'Invalid listing ID',
          errorCode: 'INVALID_INPUT',
        );
      }

      print('✅ STEP 1 PASSED: Input validated');

      // Step 2: Query Firestore for listing
      print('🔐 STEP 2: Querying Firestore for listing...');

      final listingDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .get();

      if (!listingDoc.exists) {
        print('❌ STEP 2 FAILED: Listing not found');
        return ImageDisplayResult.failure(
          message: 'Listing not found',
          errorCode: 'LISTING_NOT_FOUND',
        );
      }

      print('✅ STEP 2 PASSED: Listing found');

      // Step 3: Get image URL
      print('🔐 STEP 3: Extracting image URL...');

      final data = listingDoc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String? ??
          data['image'] as String? ??
          data['productImage'] as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        print('❌ STEP 3 FAILED: No image URL found');
        print('   Available fields: ${data.keys.toList()}');
        return ImageDisplayResult.failure(
          message: 'No image found for this listing',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ STEP 3 PASSED: Image URL extracted');
      print('   URL: $imageUrl');

      // Step 4: Return result
      print('✅ IMAGE DISPLAY FLOW: SUCCESS');

      return ImageDisplayResult.success(
        message: 'Product image fetched successfully',
        imageUrl: imageUrl,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE DISPLAY FLOW: Error: $e');
      print('   Stack trace: $stackTrace');
      return ImageDisplayResult.failure(
        message: 'Failed to fetch product image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // PROFILE IMAGE
  // ============================================================================

  /// Get user profile image
  /// Flow: Validate input → Query user → Get profileImage field → Return URL
  Future<ImageDisplayResult> getProfileImage({
    required String userId,
  }) async {
    try {
      print('🔵 IMAGE DISPLAY FLOW: Getting profile image...');
      print('   User ID: $userId');

      // Step 1: Validate input
      print('🔐 STEP 1: Validating input parameters...');

      if (userId.isEmpty) {
        print('❌ STEP 1 FAILED: User ID is empty');
        return ImageDisplayResult.failure(
          message: 'Invalid user ID',
          errorCode: 'INVALID_INPUT',
        );
      }

      print('✅ STEP 1 PASSED: Input validated');

      // Step 2: Query Firestore for user
      print('🔐 STEP 2: Querying Firestore for user...');

      var userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('⚠️  User not found by ID, searching by authUid...');

        // Try to find by authUid
        final querySnapshot = await _firestore
            .collection('users')
            .where('authUid', isEqualTo: userId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          print('❌ STEP 2 FAILED: User not found');
          return ImageDisplayResult.failure(
            message: 'User not found',
            errorCode: 'USER_NOT_FOUND',
          );
        }

        userDoc = querySnapshot.docs.first;
        print('✅ Found user by authUid');
      }

      print('✅ STEP 2 PASSED: User found');

      // Step 3: Get image URL
      print('🔐 STEP 3: Extracting profile image URL...');

      final data = userDoc.data() as Map<String, dynamic>;
      final imageUrl = data['profileImage'] as String? ??
          data['profileImageUrl'] as String? ??
          data['photoURL'] as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️  No profile image found');
        return ImageDisplayResult.failure(
          message: 'No profile image available',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ STEP 3 PASSED: Profile image URL extracted');
      print('   URL: $imageUrl');

      // Step 4: Return result
      print('✅ IMAGE DISPLAY FLOW: SUCCESS');

      return ImageDisplayResult.success(
        message: 'Profile image fetched successfully',
        imageUrl: imageUrl,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE DISPLAY FLOW: Error: $e');
      print('   Stack trace: $stackTrace');
      return ImageDisplayResult.failure(
        message: 'Failed to fetch profile image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // COMPLAINT IMAGE
  // ============================================================================

  /// Get complaint image
  /// Flow: Validate input → Query complaint → Get imageUrl field → Return URL
  Future<ImageDisplayResult> getComplaintImage({
    required String complaintId,
  }) async {
    try {
      print('🔵 IMAGE DISPLAY FLOW: Getting complaint image...');
      print('   Complaint ID: $complaintId');

      // Step 1: Validate input
      print('🔐 STEP 1: Validating input parameters...');

      if (complaintId.isEmpty) {
        print('❌ STEP 1 FAILED: Complaint ID is empty');
        return ImageDisplayResult.failure(
          message: 'Invalid complaint ID',
          errorCode: 'INVALID_INPUT',
        );
      }

      print('✅ STEP 1 PASSED: Input validated');

      // Step 2: Query Firestore for complaint
      print('🔐 STEP 2: Querying Firestore for complaint...');

      final complaintDoc = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .get();

      if (!complaintDoc.exists) {
        print('❌ STEP 2 FAILED: Complaint not found');
        return ImageDisplayResult.failure(
          message: 'Complaint not found',
          errorCode: 'COMPLAINT_NOT_FOUND',
        );
      }

      print('✅ STEP 2 PASSED: Complaint found');

      // Step 3: Get image URL
      print('🔐 STEP 3: Extracting complaint image URL...');

      final data = complaintDoc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String? ??
          data['image'] as String? ??
          data['complaintImage'] as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️  No complaint image found');
        return ImageDisplayResult.failure(
          message: 'No image found for this complaint',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ STEP 3 PASSED: Complaint image URL extracted');
      print('   URL: $imageUrl');

      // Step 4: Return result
      print('✅ IMAGE DISPLAY FLOW: SUCCESS');

      return ImageDisplayResult.success(
        message: 'Complaint image fetched successfully',
        imageUrl: imageUrl,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE DISPLAY FLOW: Error: $e');
      print('   Stack trace: $stackTrace');
      return ImageDisplayResult.failure(
        message: 'Failed to fetch complaint image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // COMMUNITY WALL POST IMAGE
  // ============================================================================

  /// Get community wall post image
  /// Flow: Validate input → Query post → Get imageUrl field → Return URL
  Future<ImageDisplayResult> getCommunityWallImage({
    required String postId,
  }) async {
    try {
      print('🔵 IMAGE DISPLAY FLOW: Getting community wall image...');
      print('   Post ID: $postId');

      // Step 1: Validate input
      print('🔐 STEP 1: Validating input parameters...');

      if (postId.isEmpty) {
        print('❌ STEP 1 FAILED: Post ID is empty');
        return ImageDisplayResult.failure(
          message: 'Invalid post ID',
          errorCode: 'INVALID_INPUT',
        );
      }

      print('✅ STEP 1 PASSED: Input validated');

      // Step 2: Query Firestore for post
      print('🔐 STEP 2: Querying Firestore for post...');

      final postDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        print('❌ STEP 2 FAILED: Post not found');
        return ImageDisplayResult.failure(
          message: 'Post not found',
          errorCode: 'POST_NOT_FOUND',
        );
      }

      print('✅ STEP 2 PASSED: Post found');

      // Step 3: Get image URL
      print('🔐 STEP 3: Extracting post image URL...');

      final data = postDoc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String? ??
          data['image'] as String? ??
          data['postImage'] as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️  No post image found');
        return ImageDisplayResult.failure(
          message: 'No image found for this post',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      print('✅ STEP 3 PASSED: Post image URL extracted');
      print('   URL: $imageUrl');

      // Step 4: Return result
      print('✅ IMAGE DISPLAY FLOW: SUCCESS');

      return ImageDisplayResult.success(
        message: 'Post image fetched successfully',
        imageUrl: imageUrl,
      );
    } catch (e, stackTrace) {
      print('❌ IMAGE DISPLAY FLOW: Error: $e');
      print('   Stack trace: $stackTrace');
      return ImageDisplayResult.failure(
        message: 'Failed to fetch post image: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  // ============================================================================
  // STREAM IMAGE (Real-time)
  // ============================================================================

  /// Stream marketplace product image (real-time)
  Stream<ImageDisplayResult> streamMarketplaceProductImage({
    required String listingId,
  }) {
    print('🔵 STREAM IMAGE: Setting up marketplace product image stream...');
    print('   Listing ID: $listingId');

    return _firestore
        .collection('listings')
        .doc(listingId)
        .snapshots()
        .map((snapshot) {
      try {
        if (!snapshot.exists) {
          print('❌ Listing not found in stream');
          return ImageDisplayResult.failure(
            message: 'Listing not found',
            errorCode: 'LISTING_NOT_FOUND',
          );
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String? ??
            data['image'] as String? ??
            data['productImage'] as String?;

        if (imageUrl == null || imageUrl.isEmpty) {
          print('⚠️  No image in stream');
          return ImageDisplayResult.failure(
            message: 'No image found',
            errorCode: 'IMAGE_NOT_FOUND',
          );
        }

        print('✅ Image URL received from stream: $imageUrl');
        return ImageDisplayResult.success(
          message: 'Image received',
          imageUrl: imageUrl,
        );
      } catch (e) {
        print('❌ Stream error: $e');
        return ImageDisplayResult.failure(
          message: 'Stream error: $e',
          errorCode: 'STREAM_ERROR',
        );
      }
    });
  }

  /// Stream profile image (real-time)
  Stream<ImageDisplayResult> streamProfileImage({
    required String userId,
  }) {
    print('🔵 STREAM IMAGE: Setting up profile image stream...');
    print('   User ID: $userId');

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      try {
        if (!snapshot.exists) {
          print('❌ User not found in stream');
          return ImageDisplayResult.failure(
            message: 'User not found',
            errorCode: 'USER_NOT_FOUND',
          );
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final imageUrl = data['profileImage'] as String? ??
            data['profileImageUrl'] as String? ??
            data['photoURL'] as String?;

        if (imageUrl == null || imageUrl.isEmpty) {
          print('⚠️  No profile image in stream');
          return ImageDisplayResult.failure(
            message: 'No image found',
            errorCode: 'IMAGE_NOT_FOUND',
          );
        }

        print('✅ Profile image URL received from stream: $imageUrl');
        return ImageDisplayResult.success(
          message: 'Image received',
          imageUrl: imageUrl,
        );
      } catch (e) {
        print('❌ Stream error: $e');
        return ImageDisplayResult.failure(
          message: 'Stream error: $e',
          errorCode: 'STREAM_ERROR',
        );
      }
    });
  }
}
