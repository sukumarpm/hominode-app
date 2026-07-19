// lib/src/components/post_actions_row.dart
// Post actions row with like, comment, share

import 'package:flutter/material.dart';

const kLikeRed = Color(0xFFFF3B30);
const kIconGray = Color(0xFF8C8C8C);

class PostActionsRow extends StatelessWidget {
  final int likes;
  final int comments;
  final bool isLiked;
  final VoidCallback onLikePressed;
  final VoidCallback onCommentPressed;
  final VoidCallback onSharePressed;

  const PostActionsRow({
    Key? key,
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.onLikePressed,
    required this.onCommentPressed,
    required this.onSharePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Like button
        InkWell(
          onTap: onLikePressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? kLikeRed : kIconGray,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '$likes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isLiked ? kLikeRed : kIconGray,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Comment button
        InkWell(
          onTap: onCommentPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: kIconGray,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '$comments',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: kIconGray,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Share button
        InkWell(
          onTap: onSharePressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.share_outlined,
                  color: kIconGray,
                  size: 22,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: kIconGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
