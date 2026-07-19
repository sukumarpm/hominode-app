// lib/src/modals/post_menu_bottomsheet.dart
// Bottom sheet menu for post options

import 'package:flutter/material.dart';
import '../models/post.dart';

void showPostMenu(
  BuildContext context,
  Post post, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onReport,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => PostMenuBottomSheet(
      post: post,
      onEdit: onEdit,
      onDelete: onDelete,
      onReport: onReport,
    ),
  );
}

class PostMenuBottomSheet extends StatelessWidget {
  final Post post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const PostMenuBottomSheet({
    Key? key,
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            if (post.isMine) ...[
              // Edit option
              _buildMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Post',
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
              const Divider(height: 1),
              // Delete option
              _buildMenuItem(
                icon: Icons.delete_outline,
                label: 'Delete Post',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ] else ...[
              // Report option
              _buildMenuItem(
                icon: Icons.flag_outlined,
                label: 'Report Post',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  onReport();
                },
              ),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: color ?? const Color(0xFF111111),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color ?? const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
