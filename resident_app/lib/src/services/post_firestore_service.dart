import 'resident_image_operations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';
import 'content_moderation_service.dart';

class PostFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _images = ResidentImageOperations();

  // Cache for user document ID
  String? _cachedUserId;
  DateTime? _cacheTime;

  // Collection references
  CollectionReference get _postsCollection => _firestore.collection('posts');
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Get current user document ID (not Firebase Auth UID)
  /// Queries users collection by authUid field to find the document ID
  Future<String?> _getCurrentUserId() async {
    try {
      // Return cached value if available and not expired.
      if (_cachedUserId != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!).inMinutes < 5) {
        return _cachedUserId;
      }

      final firebaseUser = _auth.currentUser;

      if (firebaseUser == null) {
        print('❌ PostService: No Firebase Auth user');
        return null;
      }

      final uid = firebaseUser.uid;
      print('📱 PostService: Firebase Auth UID: $uid');

      // Canonical resident document ID is Firebase Auth UID.
      final userDoc = await _usersCollection.doc(uid).get();

      if (!userDoc.exists) {
        print('❌ PostService: User document not found: $uid');
        return null;
      }

      print('✅ PostService: User document found: $uid');

      _cachedUserId = uid;
      _cacheTime = DateTime.now();

      return uid;
    } catch (e) {
      print('❌ PostService: Error getting user ID: $e');
      return null;
    }
  }

  /// Clear cached user ID (call on logout)
  void clearCache() {
    _cachedUserId = null;
    _cacheTime = null;
  }

  // ============================================
  // CREATE POST
  // ============================================
  Future<ServiceResult> createPost({
    required String content,
    String? imageUrl,
    List<String>? imageUrls,
    String? imageDraftId,
  }) async {
    try {
      // Check content moderation first
      final moderationResult = await ContentModerationService().checkContent(
        text: content,
      );

      if (!moderationResult.isSafe) {
        print('⛔ Post blocked by moderation: ${moderationResult.reason}');
        return ServiceResult(
          success: false,
          message: moderationResult.reason,
          data: 'MODERATION_BLOCKED',
        );
      }

      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        return ServiceResult(success: false, message: 'User not authenticated');
      }

      final draft =
          imageDraftId ??
          await ResidentImageOperations().createDraft('community_wall');
      final result = await _images.save(
        feature: 'community_wall',
        resourceId: draft,
        revision: 0,
        references: [if (imageUrl != null) imageUrl, ...?imageUrls],
        content: {'content': content},
      );
      return ServiceResult(
        success: true,
        message: 'Post created successfully',
        data: result['resourceId'],
      );
    } catch (e) {
      print('❌ Error creating post: $e');
      return ServiceResult(
        success: false,
        message: 'Unable to save your post. Please retry, or reopen the form.',
      );
    }
  }

  // ============================================
  // GET ALL POSTS (FILTERED BY USER'S BUILDING)
  // ============================================
  Future<List<Post>> getAllPosts() async {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        return [];
      }

      // Get current user's building ID
      final userDoc = await _usersCollection.doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userBuildingId = userData?['buildingId'];

      if (userBuildingId == null || userBuildingId.toString().isEmpty) {
        print('❌ User has no building assigned - cannot access posts');
        return [];
      }

      print('📥 Fetching posts for building: $userBuildingId');

      // Query posts for user's building (all members in same building)
      final querySnapshot = await _postsCollection
          .where('buildingId', isEqualTo: userBuildingId)
          .get();

      final posts = querySnapshot.docs.map((doc) {
        return _postFromFirestore(doc, currentUserId);
      }).toList();

      // Sort by createdAt in memory (newest first)
      posts.sort((a, b) {
        // Parse timeAgo to compare (simplified)
        return _compareTimeAgo(a.timeAgo, b.timeAgo);
      });

      print('✅ Fetched ${posts.length} posts for building $userBuildingId');
      return posts;
    } catch (e) {
      print('❌ Error fetching posts: $e');
      return [];
    }
  }

  // ============================================
  // GET ADMIN POSTS (ALL POSTS FOR MANAGED BUILDING)
  // ============================================
  Future<List<Post>> getAdminPosts() async {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        return [];
      }

      // Get current user's role and building
      final userDoc = await _usersCollection.doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] ?? 'resident';
      final userBuildingId = userData?['buildingId'];

      if (userRole != 'admin') {
        print('⚠️  User is not an admin, returning building posts only');
        return await getAllPosts();
      }

      if (userBuildingId == null || userBuildingId.toString().isEmpty) {
        print('❌ Admin has no building assigned');
        return [];
      }

      print('📥 Fetching posts for admin building: $userBuildingId');

      // Query posts where buildingId matches current user's building
      final querySnapshot = await _postsCollection
          .where('buildingId', isEqualTo: userBuildingId)
          .get();

      final posts = querySnapshot.docs.map((doc) {
        return _postFromFirestore(doc, currentUserId);
      }).toList();

      // Sort by createdAt in memory (newest first)
      posts.sort((a, b) => _compareTimeAgo(a.timeAgo, b.timeAgo));

      print('✅ Fetched ${posts.length} posts for admin building');
      return posts;
    } catch (e) {
      print('❌ Error fetching admin posts: $e');
      return [];
    }
  }

  // ============================================
  // GET POSTS BY BUILDING ID
  // ============================================
  Future<List<Post>> getPostsByBuildingId(String buildingId) async {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        return [];
      }

      print('📥 Fetching posts for building: $buildingId');

      final querySnapshot = await _postsCollection
          .where('buildingId', isEqualTo: buildingId)
          .get();

      final posts = querySnapshot.docs.map((doc) {
        return _postFromFirestore(doc, currentUserId);
      }).toList();

      // Sort by createdAt in memory (newest first)
      posts.sort((a, b) => _compareTimeAgo(a.timeAgo, b.timeAgo));

      print('✅ Fetched ${posts.length} posts for building $buildingId');
      return posts;
    } catch (e) {
      print('❌ Error fetching posts by building: $e');
      return [];
    }
  }

  // ============================================
  // GET POSTS FOR CURRENT USER (AUTO-DETECT ROLE)
  // ============================================
  Future<List<Post>> getPostsForCurrentUser() async {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        return [];
      }

      // Get current user's role
      final userDoc = await _usersCollection.doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] ?? 'resident';

      if (userRole == 'admin') {
        print('👤 User is admin, fetching admin posts');
        return await getAdminPosts();
      } else {
        print('👤 User is resident, fetching flat posts');
        return await getAllPosts();
      }
    } catch (e) {
      print('❌ Error fetching posts for current user: $e');
      return [];
    }
  }

  // ============================================
  // STREAM ALL POSTS (REAL-TIME, FILTERED BY USER'S BUILDING)
  // ============================================
  Stream<List<Post>> streamAllPosts() async* {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        yield [];
        return;
      }

      // Get user's building ID first
      yield* _usersCollection.doc(currentUserId).snapshots().asyncExpand((
        userSnapshot,
      ) {
        if (!userSnapshot.exists) {
          print('❌ User document not found');
          return Stream.value([]);
        }

        final userData = userSnapshot.data() as Map<String, dynamic>?;
        final userBuildingId = userData?['buildingId'];

        if (userBuildingId == null || userBuildingId.toString().isEmpty) {
          print('❌ User has no building assigned - cannot access posts');
          return Stream.value([]);
        }

        print('📥 Streaming posts for building: $userBuildingId');

        // Stream posts for user's building (all members in same building)
        return _postsCollection
            .where('buildingId', isEqualTo: userBuildingId)
            .snapshots()
            .map((snapshot) {
              final posts = snapshot.docs.map((doc) {
                return _postFromFirestore(doc, currentUserId);
              }).toList();

              // Sort by createdAt in memory (newest first)
              posts.sort((a, b) => _compareTimeAgo(a.timeAgo, b.timeAgo));

              return posts;
            });
      });
    } catch (e) {
      print('❌ Error streaming posts: $e');
      yield [];
    }
  }

  // ============================================
  // STREAM ADMIN POSTS (REAL-TIME, ALL BUILDING MEMBERS)
  // ============================================
  Stream<List<Post>> streamAdminPosts() async* {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        yield [];
        return;
      }

      // Get user's role and building first
      yield* _usersCollection.doc(currentUserId).snapshots().asyncExpand((
        userSnapshot,
      ) {
        if (!userSnapshot.exists) {
          print('❌ User document not found');
          return Stream.value([]);
        }

        final userData = userSnapshot.data() as Map<String, dynamic>?;
        final userRole = userData?['role'] ?? 'resident';
        final userBuildingId = userData?['buildingId'];

        if (userRole != 'admin') {
          print('⚠️  User is not an admin, returning building posts stream');
          return streamAllPosts();
        }

        if (userBuildingId == null || userBuildingId.toString().isEmpty) {
          print('❌ Admin has no building assigned');
          return Stream.value([]);
        }

        print('📥 Streaming posts for admin building: $userBuildingId');

        // Stream posts where buildingId matches current user's building
        return _postsCollection
            .where('buildingId', isEqualTo: userBuildingId)
            .snapshots()
            .map((snapshot) {
              final posts = snapshot.docs.map((doc) {
                return _postFromFirestore(doc, currentUserId);
              }).toList();

              // Sort by createdAt in memory (newest first)
              posts.sort((a, b) => _compareTimeAgo(a.timeAgo, b.timeAgo));

              return posts;
            });
      });
    } catch (e) {
      print('❌ Error streaming admin posts: $e');
      yield [];
    }
  }

  // ============================================
  // STREAM POSTS FOR CURRENT USER (AUTO-DETECT ROLE)
  // ============================================
  Stream<List<Post>> streamPostsForCurrentUser() async* {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ User not authenticated');
        yield [];
        return;
      }

      // Get user's role first
      yield* _usersCollection.doc(currentUserId).snapshots().asyncExpand((
        userSnapshot,
      ) {
        if (!userSnapshot.exists) {
          print('❌ User document not found');
          return Stream.value([]);
        }

        final userData = userSnapshot.data() as Map<String, dynamic>?;
        final userRole = userData?['role'] ?? 'resident';

        if (userRole == 'admin') {
          print('👤 User is admin, streaming admin posts');
          return streamAdminPosts();
        } else {
          print('👤 User is resident, streaming flat posts');
          return streamAllPosts();
        }
      });
    } catch (e) {
      print('❌ Error streaming posts for current user: $e');
      yield [];
    }
  }

  // A transaction makes repeated taps/retries idempotent and prevents lost
  // updates when different residents react at the same time.
  Future<ServiceResult> likePost(String postId) =>
      _setPostLiked(postId, liked: true);

  Future<ServiceResult> unlikePost(String postId) =>
      _setPostLiked(postId, liked: false);

  Future<ServiceResult> _setPostLiked(
    String postId, {
    required bool liked,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return ServiceResult(success: false, message: 'User not authenticated');
    }
    try {
      final postRef = _postsCollection.doc(postId);
      final profileRef = _usersCollection.doc(uid);
      await retryCommunityWallLikeTransaction(
        () => _firestore.runTransaction<void>((transaction) async {
          final post = await transaction.get(postRef);
          final profile = await transaction.get(profileRef);
          if (_auth.currentUser?.uid != uid) {
            throw StateError('The signed-in resident changed.');
          }
          final update = buildCommunityWallLikeUpdate(
            residentId: uid,
            post: post.data() as Map<String, dynamic>?,
            profile: profile.data() as Map<String, dynamic>?,
            liked: liked,
          );
          if (update != null) transaction.update(postRef, update);
        }),
      );
      return ServiceResult(
        success: true,
        message: liked ? 'Post liked' : 'Post unliked',
      );
    } catch (_) {
      return ServiceResult(
        success: false,
        message: liked
            ? 'Failed to like post. Please try again.'
            : 'Failed to unlike post. Please try again.',
      );
    }
  }

  // ============================================
  // ADD COMMENT
  // ============================================
  Future<ServiceResult> addComment({
    required String postId,
    required String comment,
  }) async {
    try {
      // Check comment moderation first
      final moderationResult = await ContentModerationService().checkContent(
        text: comment,
      );

      if (!moderationResult.isSafe) {
        print('⛔ Comment blocked by moderation: ${moderationResult.reason}');
        return ServiceResult(
          success: false,
          message: moderationResult.reason,
          data: 'MODERATION_BLOCKED',
        );
      }

      // Use the current authenticated identity, never the cached post author.
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        return ServiceResult(success: false, message: 'User not authenticated');
      }
      final postRef = _postsCollection.doc(postId);
      final postDoc = await postRef.get();
      final userDoc = await _usersCollection.doc(currentUserId).get();
      final commentData = buildCommunityWallComment(
        postId: postId,
        authorId: currentUserId,
        post: postDoc.data() as Map<String, dynamic>?,
        profile: userDoc.data() as Map<String, dynamic>?,
        comment: comment,
      );
      final commentRef = postRef.collection('comments').doc();
      // The rules bind this counter increment to this exact new comment.
      // Either both writes succeed, or neither leaves a partial comment.
      final batch = _firestore.batch();
      batch.set(commentRef, commentData);
      batch.update(postRef, {
        'comments': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastCommentId': commentRef.id,
      });
      await batch.commit();

      print('✅ Comment added');

      return ServiceResult(success: true, message: 'Comment added');
    } catch (e) {
      print('❌ Error adding comment: $e');
      return ServiceResult(
        success: false,
        message: 'Failed to add comment: ${e.toString()}',
      );
    }
  }

  // ============================================
  // GET COMMENTS FOR POST
  // ============================================
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      print('📥 Fetching comments for post: $postId');

      final querySnapshot = await _postsCollection
          .doc(postId)
          .collection('comments')
          .get();

      final comments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'authorName': data['authorName'] ?? 'Unknown',
          'profileImage': data['profileImage'] ?? '',
          'comment': data['comment'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();

      print('✅ Fetched ${comments.length} comments');
      return comments;
    } catch (e) {
      print('❌ Error fetching comments: $e');
      return [];
    }
  }

  // ============================================
  // DELETE POST
  // ============================================
  Future<ServiceResult> deletePost(String postId) async {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        return ServiceResult(success: false, message: 'User not authenticated');
      }

      print('🗑️ Deleting post: $postId');

      // Check if user owns the post
      final postDoc = await _postsCollection.doc(postId).get();
      final postData = postDoc.data() as Map<String, dynamic>?;

      if (postData?['authorId'] != currentUserId) {
        return ServiceResult(
          success: false,
          message: 'You can only delete your own posts',
        );
      }

      await _images.save(
        feature: 'community_wall',
        resourceId: postId,
        revision: postData?['imageRevision'] as int? ?? 0,
        references: [],
        deleteResource: true,
      );
      print('✅ Post deleted');

      return ServiceResult(success: true, message: 'Post deleted');
    } catch (e) {
      print('❌ Error deleting post: $e');
      return ServiceResult(
        success: false,
        message: 'Failed to delete post: ${e.toString()}',
      );
    }
  }

  // ============================================
  // SHARE POST (INCREMENT SHARE COUNT)
  // ============================================
  Future<ServiceResult> sharePost(String postId) async {
    try {
      print('🔗 Sharing post: $postId');

      await _postsCollection.doc(postId).update({
        'shares': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Post shared');

      return ServiceResult(success: true, message: 'Post shared');
    } catch (e) {
      print('❌ Error sharing post: $e');
      return ServiceResult(
        success: false,
        message: 'Failed to share post: ${e.toString()}',
      );
    }
  }

  // ============================================
  // REPORT POST
  // ============================================
  Future<ServiceResult> reportPost(String postId, String reason) async {
    try {
      final currentUserId = await _getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        return ServiceResult(success: false, message: 'User not authenticated');
      }

      print('🚩 Reporting post: $postId');

      final reportData = {
        'postId': postId,
        'reportedBy': currentUserId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('reports').add(reportData);

      print('✅ Post reported');

      return ServiceResult(success: true, message: 'Post reported');
    } catch (e) {
      print('❌ Error reporting post: $e');
      return ServiceResult(
        success: false,
        message: 'Failed to report post: ${e.toString()}',
      );
    }
  }

  // ============================================
  // HELPER: CONVERT FIRESTORE DOC TO POST MODEL
  // ============================================
  Post _postFromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final timeAgo = _formatTimeAgo(createdAt);

    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = likedBy.contains(currentUserId);
    final isMine = data['authorId'] == currentUserId;

    // Handle both single and multiple images
    List<String>? imageUrls;
    if (data['imageUrls'] != null) {
      imageUrls = List<String>.from(data['imageUrls'] as List);
    }

    return Post(
      id: doc.id,
      authorName: data['authorName'] as String? ?? 'Unknown',
      profileImage: data['profileImage'] as String? ?? '',
      flat: data['flat'] as String? ?? 'N/A',
      timeAgo: timeAgo,
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      imageUrls: imageUrls,
      likes: data['likes'] as int? ?? 0,
      comments: data['comments'] as int? ?? 0,
      isLiked: isLiked,
      isMine: isMine,
    );
  }

  // ============================================
  // HELPER: FORMAT TIME AGO
  // ============================================
  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }

  // ============================================
  // HELPER: COMPARE TIME AGO FOR SORTING
  // ============================================
  int _compareTimeAgo(String a, String b) {
    // Simplified comparison - newer posts first
    // "Just now" > "5 minutes ago" > "2 hours ago" > "Yesterday"

    if (a == b) return 0;
    if (a == 'Just now') return -1;
    if (b == 'Just now') return 1;

    // Extract numbers for comparison
    final aNum = int.tryParse(a.split(' ')[0]) ?? 0;
    final bNum = int.tryParse(b.split(' ')[0]) ?? 0;

    if (a.contains('minute')) {
      if (b.contains('minute')) return aNum.compareTo(bNum);
      return -1; // minutes are more recent than hours/days
    }

    if (a.contains('hour')) {
      if (b.contains('minute')) return 1;
      if (b.contains('hour')) return aNum.compareTo(bNum);
      return -1; // hours are more recent than days
    }

    if (a.contains('day')) {
      if (b.contains('minute') || b.contains('hour')) return 1;
      if (b.contains('day')) return aNum.compareTo(bNum);
      return -1;
    }

    return 0;
  }
}

// ============================================
// SERVICE RESULT CLASS
// ============================================
class ServiceResult {
  final bool success;
  final String? message;
  final dynamic data;

  ServiceResult({required this.success, this.message, this.data});
}

/// Constructs the canonical comment payload; Firestore Rules remain authoritative.
Map<String, dynamic> buildCommunityWallComment({
  required String postId,
  required String authorId,
  required Map<String, dynamic>? post,
  required Map<String, dynamic>? profile,
  required String comment,
}) {
  final communityId = post?['communityId'];
  if (authorId.isEmpty ||
      postId.isEmpty ||
      comment.trim().isEmpty ||
      communityId is! String ||
      communityId.isEmpty ||
      profile == null ||
      profile['communityId'] != communityId) {
    throw ArgumentError(
      'Comment requires a current resident and community post',
    );
  }
  return {
    'postId': postId,
    'communityId': communityId,
    'authorId': authorId,
    'authorName': profile['name'] ?? 'Unknown User',
    'profileImage': profile['profileImage'] ?? '',
    'comment': comment.trim(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// Computes only the current resident's reaction. Null means an idempotent no-op.
/// Rules enforce eligibility and ownership independently of this client check.
Map<String, dynamic>? buildCommunityWallLikeUpdate({
  required String residentId,
  required Map<String, dynamic>? post,
  required Map<String, dynamic>? profile,
  required bool liked,
}) {
  final communityId = post?['communityId'];
  if (residentId.isEmpty ||
      post == null ||
      profile == null ||
      communityId is! String ||
      communityId.isEmpty ||
      profile['communityId'] != communityId ||
      (post['status'] ?? 'active') != 'active') {
    throw StateError(
      'A current resident and active community post are required.',
    );
  }
  final rawLikedBy = post.containsKey('likedBy') ? post['likedBy'] : <String>[];
  final count = post.containsKey('likes') ? post['likes'] : 0;
  if (rawLikedBy is! List ||
      rawLikedBy.any((uid) => uid is! String) ||
      count is! int ||
      count < 0 ||
      count != rawLikedBy.length ||
      rawLikedBy.toSet().length != rawLikedBy.length) {
    // Do not silently repair historical counters or other residents' reactions.
    throw const FormatException('Invalid post reaction state.');
  }
  final residents = List<String>.from(rawLikedBy);
  if (residents.contains(residentId) == liked) return null;
  // Apply own-UID transforms rather than a stale whole-array snapshot when
  // concurrent residents commit between transaction reads and rule evaluation.
  return {
    'likedBy': liked
        ? FieldValue.arrayUnion([residentId])
        : FieldValue.arrayRemove([residentId]),
    'likes': FieldValue.increment(liked ? 1 : -1),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Rules can reject a simultaneous duplicate before the version precondition
/// triggers SDK transaction retries. Re-read once: an already-applied reaction
/// becomes a no-op. Every retry still uses authenticated reads and strict Rules.
Future<void> retryCommunityWallLikeTransaction(
  Future<void> Function() transaction,
) async {
  try {
    await transaction();
  } on FirebaseException catch (error) {
    if (error.code != 'permission-denied') rethrow;
    await transaction();
  }
}
