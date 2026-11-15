import 'package:resident_app/src/services/resident_private_images.dart';
// lib/comments_screen.dart
// Comments screen for a post

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/models/post.dart';
import 'src/services/post_firestore_service.dart';
import 'src/widgets/resident_visitor_page_background.dart';
import 'src/widgets/wall_report_dialog.dart';
import 'src/widgets/wall_block_dialogs.dart';

const kPrimaryBlue = Color(0xFF172B4D);
const kBlackText = Color(0xFF172B4D);
const kGrayText = Color(0xFF52627A);
const kDivider = Color(0xFFE2EAF3);

class CommentsScreen extends StatefulWidget {
  final Post post;

  const CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final PostFirestoreService _service = PostFirestoreService();
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _unavailable = false;
  bool _blockingResident = false;
  StreamSubscription<void>? _moderationSubscription;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _moderationSubscription = _service.moderationChanges().skip(1).listen((_) {
      if (mounted) _loadComments();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _commentController.dispose();
    _moderationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _blockResident(String userId) async {
    if (_blockingResident) return;
    setState(() => _blockingResident = true);
    try {
      final blocked = await showBlockResidentDialog(
        context,
        () => _service.setUserBlocked(userId, true),
      );
      if (!mounted || !blocked) return;
      _showSnackBar('Resident blocked.', Colors.green);
      await _loadComments();
    } finally {
      if (mounted) setState(() => _blockingResident = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _service.getComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _unavailable = false;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading comments: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _unavailable = true;
          _isLoading = false;
        });
      }
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .82),
        foregroundColor: kPrimaryBlue,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: kPrimaryBlue, size: 20.w),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Comments',
          style: TextStyle(
            color: kPrimaryBlue,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ResidentVisitorPageBackground(
        child: _unavailable
            ? const Center(child: Text('This post is unavailable.'))
            : Column(
                children: [
                  // Post preview
                  _buildPostPreview(),

                  // Comments list
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet.\nBe the first to comment!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: kGrayText,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
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
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: kDivider),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B4D).withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Container(
              width: 40.w,
              height: 40.h,
              color: Colors.grey[300],
              child: Image(
                image: residentImageProvider(widget.post.profileImage),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person, color: Colors.grey);
                },
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.authorName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: kBlackText,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.post.content,
                  softWrap: true,
                  style: TextStyle(fontSize: 14.sp, color: kGrayText),
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
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Container(
              width: 36.w,
              height: 36.h,
              color: Colors.grey[300],
              child: profileImage.isNotEmpty
                  ? Image(
                      image: residentImageProvider(profileImage),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 20.w,
                        );
                      },
                    )
                  : Icon(Icons.person, color: Colors.grey, size: 20.w),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 3.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: kBlackText,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 12.sp, color: kGrayText),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  commentText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: kBlackText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (comment['authorId'] != null &&
              comment['authorId'] != FirebaseAuth.instance.currentUser?.uid)
            PopupMenuButton<String>(
              enabled: !_blockingResident,
              onSelected: (action) async {
                try {
                  if (action == 'report') {
                    await showWallReportDialog(
                      context,
                      targetLabel: 'Comment',
                      submit: (reason) => _service.reportWallContent(
                        widget.post.id,
                        commentId: comment['id'] as String,
                        reason: reason,
                      ),
                    );
                  } else {
                    await _blockResident(comment['authorId'] as String);
                  }
                } catch (_) {
                  if (mounted) {
                    _showSnackBar('Unable to complete action', Colors.red);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report comment')),
                PopupMenuItem(value: 'block', child: Text('Block user')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: kDivider),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B4D).withValues(alpha: .05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: kGrayText, fontSize: 14.sp),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: const BorderSide(color: kDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: const BorderSide(color: kDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: kPrimaryBlue,
                shape: BoxShape.circle,
              ),
              child: _isSubmitting
                  ? Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _handleAddComment,
                      icon: Icon(Icons.send, color: Colors.white, size: 20.w),
                      padding: EdgeInsets.zero,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
