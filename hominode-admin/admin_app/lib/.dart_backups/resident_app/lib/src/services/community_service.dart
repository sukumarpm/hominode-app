// lib/src/services/community_service.dart
// Community service with API stubs and mock data

import '../models/post.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  /// Fetch all community posts
  /// API: GET /community/posts
  Future<List<Post>> fetchPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockPosts();
  }

  /// Create a new post
  /// API: POST /community/posts
  Future<Post> createPost(String content) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final newPost = Post(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'You',
      profileImage: 'https://i.pravatar.cc/150?img=1',
      flat: 'A-101',
      timeAgo: 'Just now',
      content: content,
      likes: 0,
      comments: 0,
      isLiked: false,
      isMine: true,
    );
    
    return newPost;
  }

  /// Delete a post
  /// API: DELETE /community/posts/{id}
  Future<void> deletePost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock success
  }

  /// Like a post
  /// API: POST /community/posts/{id}/like
  Future<void> likePost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Mock success
  }

  /// Unlike a post
  /// API: DELETE /community/posts/{id}/like
  Future<void> unlikePost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Mock success
  }

  /// Report a post
  /// API: POST /community/posts/{id}/report
  Future<void> reportPost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock success
  }

  /// Share a post (stub for share functionality)
  Future<void> sharePost(Post post) async {
    // TODO: Implement share functionality using share_plus package
    // Example: await Share.share('${post.content}\n\n- ${post.authorName} (${post.flat})');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Mock data matching the screenshot
  List<Post> _getMockPosts() {
    return [
      Post(
        id: 'post_1',
        authorName: 'Priya Sharma',
        profileImage: 'https://i.pravatar.cc/150?img=5',
        flat: 'A-205',
        timeAgo: '2 hours ago',
        content: 'Looking for someone to share a cab to the airport tomorrow morning around 6 AM. Anyone interested?',
        likes: 23,
        comments: 30,
        isLiked: false,
        isMine: false,
      ),
      Post(
        id: 'post_2',
        authorName: 'Raj Patel',
        profileImage: 'https://i.pravatar.cc/150?img=12',
        flat: 'B-101',
        timeAgo: '5 hours ago',
        content: 'Anyone interested in playing badminton tomorrow evening at 6 PM? We need 2 more players!',
        likes: 23,
        comments: 30,
        isLiked: true,
        isMine: false,
      ),
      Post(
        id: 'post_3',
        authorName: 'Amit Kumar',
        profileImage: 'https://i.pravatar.cc/150?img=8',
        flat: 'C-302',
        timeAgo: 'Yesterday',
        content: 'Thank you to the security team for their quick response last night. You guys are doing a great job! 👏',
        likes: 23,
        comments: 30,
        isLiked: false,
        isMine: false,
      ),
    ];
  }
}
