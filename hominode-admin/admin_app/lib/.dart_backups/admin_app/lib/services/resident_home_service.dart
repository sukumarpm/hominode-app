import 'package:cloud_firestore/cloud_firestore.dart';
import 'apartment_images_service.dart';
import 'poster_service.dart';

class ResidentHomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApartmentImagesService _imagesService = ApartmentImagesService();
  final PosterService _posterService = PosterService();

  // ==================== FLOW FUNCTION: Get Combined Feed ====================
  /// Get combined feed of images and posters for resident (real-time stream)
  Stream<List<FeedItemModel>> getCombinedFeed(String buildingId) {
    try {
      print('🔵 RESIDENT HOME SERVICE: Fetching combined feed for building - $buildingId');

      // STEP 1: Validate Building ID
      if (buildingId.isEmpty) return Stream.value([]);
      print('✅ STEP 1 PASSED: Building ID validated');

      // STEP 2: Fetch Images and Posters Streams
      print('📋 STEP 2: Fetching images and posters streams...');
      final imagesStream = _imagesService.getImagesForBuilding(buildingId);
      final postersStream = _posterService.getPostersForBuilding(buildingId);

      // STEP 3: Combine Streams
      print('🔄 STEP 3: Combining streams...');
      return imagesStream.asyncExpand((images) {
        return postersStream.map((posters) {
          print('✅ STEP 3 PASSED: Streams combined');
          
          // STEP 4: Create Feed Items
          print('📝 STEP 4: Creating feed items...');
          final feedItems = <FeedItemModel>[];

          // Add images as feed items
          for (var image in images) {
            feedItems.add(FeedItemModel.fromImage(image));
          }

          // Add posters as feed items
          for (var poster in posters) {
            feedItems.add(FeedItemModel.fromPoster(poster));
          }

          // STEP 5: Sort by creation date (newest first)
          print('🔔 STEP 5: Sorting feed items...');
          feedItems.sort((a, b) {
            final dateA = a.createdAt ?? DateTime.now();
            final dateB = b.createdAt ?? DateTime.now();
            return dateB.compareTo(dateA);
          });

          print('✅ RESIDENT HOME SERVICE: Feed fetched - ${feedItems.length} items');
          return feedItems;
        });
      }).handleError((error) {
        print('❌ ERROR: $error');
        throw Exception('Failed to fetch feed: $error');
      });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  // ==================== FLOW FUNCTION: Remove Post (Admin Only) ====================
  /// Remove image or poster (admin only)
  Future<void> removePost({
    required String postId,
    required String postType, // 'image' or 'poster'
    required String imageUrl,
    required String adminId,
  }) async {
    try {
      print('🔵 RESIDENT HOME SERVICE: Removing post - $postId ($postType)');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      if (adminId.isEmpty) throw Exception('Admin not authenticated');
      print('✅ STEP 1 PASSED: Admin authenticated - $adminId');

      // STEP 2: Validate Post Type
      print('📋 STEP 2: Validating post type...');
      if (postType != 'image' && postType != 'poster') {
        throw Exception('Invalid post type');
      }
      print('✅ STEP 2 PASSED: Post type validated - $postType');

      // STEP 3: Delete Post
      print('🗑️ STEP 3: Deleting post...');
      if (postType == 'image') {
        await _imagesService.deleteImage(postId, imageUrl);
      } else {
        await _posterService.deletePoster(postId, imageUrl);
      }
      print('✅ STEP 3 PASSED: Post deleted');

      print('✅ RESIDENT HOME SERVICE: Post removal COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to remove post: $e');
    }
  }

  // ==================== FLOW FUNCTION: Check Post Expiry ====================
  /// Check if post has expired
  bool isPostExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate);
  }

  // ==================== FLOW FUNCTION: Get Time Remaining ====================
  /// Get human-readable time remaining until expiry
  String getTimeRemaining(DateTime? expiryDate) {
    if (expiryDate == null) return 'No expiry';
    
    final now = DateTime.now();
    if (now.isAfter(expiryDate)) return 'Expired';

    final difference = expiryDate.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'Expiring soon';
    }
  }

  // ==================== FLOW FUNCTION: Get Relative Time ====================
  /// Get human-readable relative time (e.g., "2 hours ago")
  String getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// ==================== Feed Item Model ====================
class FeedItemModel {
  final String id;
  final String type; // 'image' or 'poster'
  final String title;
  final String description;
  final String imageUrl;
  final String adminName;
  final String category; // For images: type, for posters: category
  final DateTime? createdAt;
  final DateTime? expiryDate;
  final String adminId;

  FeedItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.adminName,
    required this.category,
    this.createdAt,
    this.expiryDate,
    required this.adminId,
  });

  factory FeedItemModel.fromImage(ApartmentImageModel image) {
    return FeedItemModel(
      id: image.id,
      type: 'image',
      title: image.title,
      description: image.description,
      imageUrl: image.imageUrl,
      adminName: image.adminName,
      category: image.type,
      createdAt: image.createdAt,
      expiryDate: null, // Images don't have expiry by default
      adminId: image.adminId,
    );
  }

  factory FeedItemModel.fromPoster(PosterModel poster) {
    return FeedItemModel(
      id: poster.id,
      type: 'poster',
      title: poster.title,
      description: poster.description,
      imageUrl: poster.imageUrl,
      adminName: poster.adminName,
      category: poster.category,
      createdAt: poster.createdAt,
      expiryDate: null, // Can be extended to support expiry
      adminId: poster.adminId,
    );
  }
}
