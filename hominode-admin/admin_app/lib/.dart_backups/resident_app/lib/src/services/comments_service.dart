// lib/src/services/comments_service.dart
// Comments service with API stubs

import '../models/comment.dart';

class CommentsService {
  static final CommentsService _instance = CommentsService._internal();
  factory CommentsService() => _instance;
  CommentsService._internal();

  /// Fetch comments for a post
  /// API: GET /community/posts/{postId}/comments
  Future<List<Comment>> fetchComments(String postId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockComments(postId);
  }

  /// Add a comment to a post
  /// API: POST /community/posts/{postId}/comments
  Future<Comment> addComment(String postId, String content) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return Comment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      authorName: 'You',
      profileImage: 'https://i.pravatar.cc/150?img=1',
      content: content,
      timeAgo: 'Just now',
      isMine: true,
    );
  }

  /// Delete a comment
  /// API: DELETE /community/posts/{postId}/comments/{commentId}
  Future<void> deleteComment(String postId, String commentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock success
  }

  /// Mock comments data
  List<Comment> _getMockComments(String postId) {
    return [
      Comment(
        id: 'comment_1',
        postId: postId,
        authorName: 'Neha Singh',
        profileImage: 'https://i.pravatar.cc/150?img=9',
        content: 'I can join! What time should we leave?',
        timeAgo: '1 hour ago',
        isMine: false,
      ),
      Comment(
        id: 'comment_2',
        postId: postId,
        authorName: 'Rahul Mehta',
        profileImage: 'https://i.pravatar.cc/150?img=11',
        content: 'Count me in as well!',
        timeAgo: '45 minutes ago',
        isMine: false,
      ),
      Comment(
        id: 'comment_3',
        postId: postId,
        authorName: 'Priya Sharma',
        profileImage: 'https://i.pravatar.cc/150?img=5',
        content: 'Great! Let\'s meet at the gate at 5:45 AM',
        timeAgo: '30 minutes ago',
        isMine: false,
      ),
    ];
  }
}
