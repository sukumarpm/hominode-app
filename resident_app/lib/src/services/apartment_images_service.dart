import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result class for apartment images operations (Flow Function Pattern)
class ApartmentImagesResult {
  final bool success;
  final String? message;
  final List<String>? imageUrls;
  final String? errorCode;

  ApartmentImagesResult({
    required this.success,
    this.message,
    this.imageUrls,
    this.errorCode,
  });

  factory ApartmentImagesResult.success({
    String? message,
    List<String>? imageUrls,
  }) {
    return ApartmentImagesResult(
      success: true,
      message: message ?? 'Operation successful',
      imageUrls: imageUrls ?? [],
    );
  }

  factory ApartmentImagesResult.failure({
    required String message,
    String? errorCode,
  }) {
    return ApartmentImagesResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Apartment Images Service - Flow Function Pattern
/// Fetches apartment/building images from Firestore apartmentImages collection
class ApartmentImagesService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get apartment images - Following flow function pattern
  /// Step 1: Validate authentication → Step 2: Query collection → Step 3: Extract URLs → Step 4: Return result
  Future<ApartmentImagesResult> getApartmentImages() async {
    try {
      print('🔵 APARTMENT IMAGES SERVICE: Starting fetch...');

      // STEP 1: Validate user authentication
      print('🔐 STEP 1: Validating user authentication...');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ STEP 1 FAILED: User not authenticated');
        return ApartmentImagesResult.failure(
          message: 'User not authenticated',
          errorCode: 'NOT_AUTHENTICATED',
        );
      }

      print('✅ STEP 1 PASSED: User authenticated');
      print('   User ID: ${currentUser.uid}');

      // STEP 2: Query Firestore collection
      print('🔐 STEP 2: Querying apartmentImages collection...');

      final snapshot = await _firestore.collection('apartmentImages').get();

      print('✅ STEP 2 PASSED: Query completed');
      print('   Documents found: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('⚠️  No documents in apartmentImages collection');
        return ApartmentImagesResult.success(
          message: 'No apartment images available',
          imageUrls: [],
        );
      }

      // STEP 3: Extract image URLs
      print('🔐 STEP 3: Extracting image URLs...');

      final images = <String>[];
      for (var i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        final imageUrl = data['imageUrl'] as String?;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          images.add(imageUrl);
          print('   ✅ Image $i: $imageUrl');
        } else {
          print('   ⚠️  Document ${doc.id}: No imageUrl field');
        }
      }

      print('✅ STEP 3 PASSED: Extracted ${images.length} image URLs');

      // STEP 4: Return success result
      print('✅ APARTMENT IMAGES SERVICE: SUCCESS');

      return ApartmentImagesResult.success(
        message: 'Apartment images fetched successfully',
        imageUrls: images,
      );
    } catch (e, stackTrace) {
      print('❌ APARTMENT IMAGES SERVICE: Error: $e');
      print('   Stack trace: $stackTrace');
      return ApartmentImagesResult.failure(
        message: 'Failed to fetch apartment images: $e',
        errorCode: 'FETCH_ERROR',
      );
    }
  }

  /// Stream apartment images in real-time
  /// Following flow function pattern with real-time updates
  Stream<ApartmentImagesResult> streamApartmentImages() {
    print('🔵 APARTMENT IMAGES SERVICE: Setting up stream...');

    return _firestore.collection('apartmentImages').snapshots().map((snapshot) {
      try {
        print('✅ Stream update received: ${snapshot.docs.length} documents');

        if (snapshot.docs.isEmpty) {
          print('⚠️  No documents in stream');
          return ApartmentImagesResult.success(
            message: 'No apartment images available',
            imageUrls: [],
          );
        }

        final images = <String>[];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final imageUrl = data['imageUrl'] as String?;

          if (imageUrl != null && imageUrl.isNotEmpty) {
            images.add(imageUrl);
          }
        }

        print('✅ Stream: Extracted ${images.length} image URLs');

        return ApartmentImagesResult.success(
          message: 'Apartment images received',
          imageUrls: images,
        );
      } catch (e) {
        print('❌ Stream error: $e');
        return ApartmentImagesResult.failure(
          message: 'Stream error: $e',
          errorCode: 'STREAM_ERROR',
        );
      }
    });
  }
}

