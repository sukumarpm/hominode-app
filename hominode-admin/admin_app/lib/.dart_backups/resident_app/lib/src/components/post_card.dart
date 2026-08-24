// lib/src/components/post_card.dart
// Community post card component

import 'package:flutter/material.dart';
import '../models/post.dart';
import 'post_actions_row.dart';

const kPrimaryBlue = Color(0xFF2563EB);
const kBlackText = Color(0xFF111111);
const kGrayText = Color(0xFF8C8C8C);
const kDivider = Color(0xFFE6E6E6);

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLikePressed;
  final VoidCallback onCommentPressed;
  final VoidCallback onSharePressed;
  final VoidCallback onMenuPressed;

  const PostCard({
    super.key,
    required this.post,
    required this.onLikePressed,
    required this.onCommentPressed,
    required this.onSharePressed,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Profile image, name, flat, time, menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile image
              ClipOval(
                child: Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[300],
                  child: Image.network(
                    post.profileImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Name, flat, time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: kBlackText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.flat} • ${post.timeAgo}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: kGrayText,
                      ),
                    ),
                  ],
                ),
              ),

              // Three-dot menu
              IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(
                  Icons.more_horiz,
                  color: kGrayText,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Post content
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: kBlackText,
              height: 1.5,
            ),
          ),

          // Images if present
          if ((post.imageUrls != null && post.imageUrls!.isNotEmpty) ||
              (post.imageUrl != null && post.imageUrl!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            _buildImageGallery(post),
          ],

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: kDivider,
          ),

          const SizedBox(height: 12),

          // Actions row
          PostActionsRow(
            likes: post.likes,
            comments: post.comments,
            isLiked: post.isLiked,
            onLikePressed: onLikePressed,
            onCommentPressed: onCommentPressed,
            onSharePressed: onSharePressed,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Post post) {
    final images = post.imageUrls ?? (post.imageUrl != null ? [post.imageUrl!] : []);
    
    if (images.isEmpty) return const SizedBox.shrink();

    // Single image - full width
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          images[0],
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                  size: 48,
                ),
              ),
            );
          },
        ),
      );
    }

    // Multiple images - grid layout
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: images.length >= 4 ? 2 : (images.length == 2 ? 2 : 3),
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
