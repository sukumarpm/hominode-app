// lib/comments_screen.dart
// Comments screen for a post

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'src/models/post.dart';
import 'src/services/post_firestore_service.dart';

const kPrimaryBlue = Color(0xFF2563EB);
const kBlackText = Color(0xFF111111);
const kGrayText = Color(0xFF8C8C8C);
const kDivider = Color(0xFFE6E6E6);

class CommentsScreen extends StatefulWidget {
  final Post post;

  const CommentsScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final PostFirestoreService _service = PostFirestoreService();
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _service.getComments(widget.post.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading comments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAddComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await _service.addComment(
        postId: widget.post.id,
        comment: _commentController.text.trim(),
      );
      
      if (result.success) {
        _commentController.clear();
        _loadComments(); // Refresh comments list
        FocusScope.of(context).unfocus();
      } else {
        _showSnackBar(result.message ?? 'Failed to add comment', Colors.red);
      }
      
      setState(() => _isSubmitting = false);
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Failed to add comment', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Post preview
          _buildPostPreview(),

          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet.\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: kGrayText,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: kDivider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Container(
              width: 40,
              height: 40,
              color: Colors.grey[300],
              child: Image.network(
                widget.post.profileImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person, color: Colors.grey);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.authorName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kBlackText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kGrayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final authorName = comment['authorName'] as String? ?? 'Unknown';
    final profileImage = comment['profileImage'] as String? ?? '';
    final commentText = comment['comment'] as String? ?? '';
    final createdAt = comment['createdAt'];
    
    // Format time ago
    String timeAgo = 'Just now';
    if (createdAt != null) {
      final timestamp = createdAt as Timestamp;
      final dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours}h ago';
      } else {
        timeAgo = '${difference.inDays}d ago';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Container(
              width: 36,
              height: 36,
              color: Colors.grey[300],
              child: profileImage.isNotEmpty
                  ? Image.network(
                      profileImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person, color: Colors.grey, size: 20);
                      },
                    )
                  : const Icon(Icons.person, color: Colors.grey, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kBlackText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kGrayText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kBlackText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: kDivider, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: const TextStyle(color: kGrayText, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kPrimaryBlue,
                shape: BoxShape.circle,
              ),
              child: _isSubmitting
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _handleAddComment,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
