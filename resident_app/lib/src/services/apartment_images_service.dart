import 'package:hominode_storage/hominode_storage.dart';
import 'resident_image_operations.dart';
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

  static String? imageReference(Map<String, dynamic> data) {
    if (data['imageAsset'] != null) {
      final asset = StorageImageAsset.fromMap(
        Map<String, dynamic>.from(data['imageAsset'] as Map),
      );
      if (asset.feature != 'apartment' ||
          asset.state != 'ready' ||
          (data['buildingId'] != null &&
              asset.resourceId != data['buildingId'])) {
        throw const FormatException('Invalid apartment image.');
      }
      return '$privateImagePrefix${asset.assetId}';
    }
    return data['imageUrl'] as String?;
  }

  /// Get apartment images - Following flow function pattern
  /// Step 1: Validate authentication → Step 2: Query collection → Step 3: Extract URLs → Step 4: Return result
  Future<ApartmentImagesResult> getApartmentImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return ApartmentImagesResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return ApartmentImagesResult(
          success: false,
          message: 'User profile not found',
        );
      }

      final userData = userDoc.data()!;
      final buildingId = userData['buildingId']?.toString();
      final communityId = userData['communityId']?.toString().trim();

      if (buildingId == null ||
          buildingId.isEmpty ||
          communityId == null ||
          communityId.isEmpty) {
        return ApartmentImagesResult(
          success: false,
          message: 'Building not assigned',
        );
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('apartmentImages')
          .where('communityId', isEqualTo: communityId)
          .where('buildingId', isEqualTo: buildingId)
          .where('status', isEqualTo: 'active')
          .get();

      final imageUrls = snapshot.docs
          .map((doc) => imageReference(doc.data()))
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();

      return ApartmentImagesResult(success: true, imageUrls: imageUrls);
    } catch (e) {
      return ApartmentImagesResult(
        success: false,
        message: 'Failed to fetch apartment images: $e',
      );
    }
  }

  /// Stream apartment images in real-time
  /// Following flow function pattern with real-time updates
  Stream<ApartmentImagesResult> streamApartmentImages() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield ApartmentImagesResult.failure(message: 'User not authenticated');
      return;
    }
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final communityId = data?['communityId']?.toString().trim();
    final buildingId = data?['buildingId']?.toString().trim();
    if (communityId == null ||
        communityId.isEmpty ||
        buildingId == null ||
        buildingId.isEmpty) {
      yield ApartmentImagesResult.failure(
        message: 'Community or building not assigned',
      );
      return;
    }

    yield* _firestore
        .collection('apartmentImages')
        .where('communityId', isEqualTo: communityId)
        .where('buildingId', isEqualTo: buildingId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          try {
            if (snapshot.docs.isEmpty) {
              return ApartmentImagesResult.success(
                message: 'No apartment images available',
                imageUrls: [],
              );
            }

            final images = <String>[];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final imageUrl = imageReference(data);

              if (imageUrl != null && imageUrl.isNotEmpty) {
                images.add(imageUrl);
              }
            }

            return ApartmentImagesResult.success(
              message: 'Apartment images received',
              imageUrls: images,
            );
          } catch (e) {
            return ApartmentImagesResult.failure(
              message: 'Stream error: $e',
              errorCode: 'STREAM_ERROR',
            );
          }
        });
  }
}
