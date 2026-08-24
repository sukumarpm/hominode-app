import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class PinnedPostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _pinnedPostsCollection = 'pinnedPosts';

  // Get all pinned posts for admin's building
  Stream<List<PinnedPostModel>> getPinnedPosts() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection(_pinnedPostsCollection)
        .where('communityId', isEqualTo: _adminService.requireCurrentCommunityId())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('PinnedPostService: Found ${snapshot.docs.length} pinned posts');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PinnedPostModel.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // Create a new pinned post
  Future<void> createPinnedPost({
    required String title,
    required String content,
    required String category,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final adminProfile = await _adminService.getAdminProfile();
      final buildingId = adminProfile?['buildingId'] ?? '';
      final buildingName = adminProfile?['buildingName'] ?? '';

      print('PinnedPostService: Creating pinned post');

      await _firestore.collection(_pinnedPostsCollection).add({
        'title': title,
        'content': content,
        'category': category,
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'buildingId': buildingId,
        'buildingName': buildingName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('PinnedPostService: Pinned post created successfully');
    } catch (e) {
      print('PinnedPostService ERROR: Failed to create pinned post: $e');
      throw Exception('Failed to create pinned post: $e');
    }
  }

  // Update a pinned post
  Future<void> updatePinnedPost({
    required String postId,
    required String title,
    required String content,
    required String category,
  }) async {
    try {
      print('PinnedPostService: Updating pinned post: $postId');

      await _firestore.collection(_pinnedPostsCollection).doc(postId).update({
        'title': title,
        'content': content,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('PinnedPostService: Pinned post updated successfully');
    } catch (e) {
      print('PinnedPostService ERROR: Failed to update pinned post: $e');
      throw Exception('Failed to update pinned post: $e');
    }
  }

  // Delete a pinned post
  Future<void> deletePinnedPost(String postId) async {
    try {
      print('PinnedPostService: Deleting pinned post: $postId');

      await _firestore.collection(_pinnedPostsCollection).doc(postId).delete();

      print('PinnedPostService: Pinned post deleted successfully');
    } catch (e) {
      print('PinnedPostService ERROR: Failed to delete pinned post: $e');
      throw Exception('Failed to delete pinned post: $e');
    }
  }
}

// Pinned Post Model
class PinnedPostModel {
  final String id;
  final String title;
  final String content;
  final String category;
  final String adminId;
  final String buildingId;
  final String buildingName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PinnedPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.adminId,
    required this.buildingId,
    required this.buildingName,
    this.createdAt,
    this.updatedAt,
  });

  factory PinnedPostModel.fromFirestore(String id, Map<String, dynamic> data) {
    return PinnedPostModel(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? '',
      adminId: data['adminId'] ?? '',
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String getFormattedDate() {
    if (createdAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(createdAt!);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
    }
  }
}
