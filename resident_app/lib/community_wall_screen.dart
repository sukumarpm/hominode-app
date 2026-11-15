// lib/community_wall_screen.dart
// Community Wall main screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'comments_screen.dart';
import 'src/components/post_card.dart';
import 'src/modals/add_post_modal.dart';
import 'src/modals/post_menu_bottomsheet.dart';
import 'src/models/post.dart';
import 'src/services/post_firestore_service.dart';
import 'src/widgets/resident_visitor_page_background.dart';
import 'src/widgets/wall_report_dialog.dart';
import 'src/widgets/wall_block_dialogs.dart';

const kPrimaryBlue = Color(0xFF172B4D);

class CommunityWallScreen extends StatefulWidget {
  const CommunityWallScreen({super.key, this.service});
  final PostFirestoreService? service;

  @override
  State<CommunityWallScreen> createState() => _CommunityWallScreenState();
}

class _CommunityWallScreenState extends State<CommunityWallScreen> {
  late final PostFirestoreService _service =
      widget.service ?? PostFirestoreService();
  bool _blockDialogOpen = false, _blockedDialogOpen = false;
  int _loadGeneration = 0;
  List<Post> _posts = [];
  bool _isLoading = true;
  StreamSubscription<void>? _moderationSubscription;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _moderationSubscription = _service.moderationChanges().skip(1).listen((_) {
      if (mounted) _loadPosts();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _moderationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() => _isLoading = true);
    try {
      final posts = await _service.getAllPosts();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading posts: $e');
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _handleAddPost(
    String content,
    String? imageUrl,
    String? draftId,
  ) async {
    try {
      final result = await _service.createPost(
        content: content,
        imageUrl: imageUrl,
        imageDraftId: draftId,
      );

      if (result.success) {
        _loadPosts(); // Refresh posts list
        _showSnackBar('Post created successfully!', Colors.green);
        return true;
      } else {
        _showSnackBar(result.message ?? 'Failed to create post', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Failed to create post', Colors.red);
    }
    return false;
  }

  Future<void> _handleLike(Post post) async {
    final postIndex = _posts.indexWhere((p) => p.id == post.id);
    if (postIndex == -1) return;

    // Optimistic update
    final wasLiked = post.isLiked;
    setState(() {
      if (post.isLiked) {
        _posts[postIndex].isLiked = false;
        _posts[postIndex].likes--;
      } else {
        _posts[postIndex].isLiked = true;
        _posts[postIndex].likes++;
      }
    });

    try {
      final result = wasLiked
          ? await _service.unlikePost(post.id)
          : await _service.likePost(post.id);

      if (!result.success) {
        // Revert on error
        setState(() {
          if (wasLiked) {
            _posts[postIndex].isLiked = true;
            _posts[postIndex].likes++;
          } else {
            _posts[postIndex].isLiked = false;
            _posts[postIndex].likes--;
          }
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        if (wasLiked) {
          _posts[postIndex].isLiked = true;
          _posts[postIndex].likes++;
        } else {
          _posts[postIndex].isLiked = false;
          _posts[postIndex].likes--;
        }
      });
    }
  }

  void _handleComment(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CommentsScreen(post: post)),
    ).then((_) {
      // Refresh posts when returning from comments screen
      _loadPosts();
    });
  }

  Future<void> _handleShare(Post post) async {
    try {
      final result = await _service.sharePost(post.id);
      if (result.success) {
        _showSnackBar('Post shared!', Colors.green);
      } else {
        _showSnackBar(result.message ?? 'Failed to share post', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Failed to share post', Colors.red);
    }
  }

  void _handleMenu(Post post) {
    if (_blockDialogOpen || _blockedDialogOpen) return;
    showPostMenu(
      context,
      post,
      onEdit: () => _handleEdit(post),
      onDelete: () => _handleDelete(post),
      onReport: () => _handleReport(post),
      onBlock: () => _blockUser(post.authorId),
    );
  }

  Future<void> _blockUser(String userId) async {
    if (_blockDialogOpen) return;
    setState(() => _blockDialogOpen = true);
    try {
      final blocked = await showBlockResidentDialog(
        context,
        () => _service.setUserBlocked(userId, true),
      );
      if (!mounted || !blocked) return;
      _showSnackBar('Resident blocked.', Colors.green);
      await _loadPosts();
    } finally {
      if (mounted) setState(() => _blockDialogOpen = false);
    }
  }

  Future<void> _showBlockedUsers() async {
    if (_blockedDialogOpen || _blockDialogOpen) return;
    setState(() => _blockedDialogOpen = true);
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BlockedResidentsDialog(service: _service),
      );
      if (mounted) await _loadPosts();
    } finally {
      if (mounted) setState(() => _blockedDialogOpen = false);
    }
  }

  void _handleEdit(Post post) {
    // TODO: Implement edit functionality
    _showSnackBar('Edit feature coming soon', Colors.blue);
  }

  Future<void> _handleDelete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _service.deletePost(post.id);

        if (result.success) {
          setState(() {
            _posts.removeWhere((p) => p.id == post.id);
          });
          _showSnackBar('Post deleted', Colors.green);
        } else {
          _showSnackBar(result.message ?? 'Failed to delete post', Colors.red);
        }
      } catch (e) {
        _showSnackBar('Failed to delete post', Colors.red);
      }
    }
  }

  Future<void> _handleReport(Post post) => showWallReportDialog(
    context,
    targetLabel: 'Post',
    submit: (reason) => _service.reportPost(post.id, reason),
  );

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
        actions: [
          IconButton(
            tooltip: 'Blocked users',
            onPressed: _blockDialogOpen || _blockedDialogOpen
                ? null
                : _showBlockedUsers,
            icon: const Icon(Icons.block),
          ),
        ],
        backgroundColor: Colors.white.withValues(alpha: .82),
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Community Wall',
          style: TextStyle(
            color: const Color(0xFF172B4D),
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ResidentVisitorPageBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
            ? Center(
                child: Container(
                  margin: EdgeInsets.all(24.w),
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: const Color(0xFFE2EAF3)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF172B4D).withValues(alpha: .06),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    'No posts to show right now.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF52627A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadPosts,
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return PostCard(
                      post: post,
                      onLikePressed: () => _handleLike(post),
                      onCommentPressed: () => _handleComment(post),
                      onSharePressed: () => _handleShare(post),
                      onMenuPressed: () => _handleMenu(post),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddPostModal(context, onSubmit: _handleAddPost);
        },
        backgroundColor: kPrimaryBlue,
        child: Icon(Icons.add, color: Colors.white, size: 28.w),
      ),
    );
  }
}
