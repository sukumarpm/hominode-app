// lib/src/screens/admin_chat_query_selection_screen.dart
// Query category selection screen for admin chat

import 'package:flutter/material.dart';
import '../models/admin_chat_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'admin_chat_query_template_screen.dart';

class AdminChatQuerySelectionScreen extends StatelessWidget {
  const AdminChatQuerySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat with Admin',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.border,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            // Header text
            Text(
              'Select your query category:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'Choose the category that best matches your question',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Query categories
            _buildCategoryCard(
              context,
              category: QueryCategory.billing,
            ),
            
            const SizedBox(height: 16),
            
            _buildCategoryCard(
              context,
              category: QueryCategory.maintenance,
            ),
            
            const SizedBox(height: 16),
            
            _buildCategoryCard(
              context,
              category: QueryCategory.amenities,
            ),
            
            const SizedBox(height: 16),
            
            _buildCategoryCard(
              context,
              category: QueryCategory.complaints,
            ),
            
            const SizedBox(height: 16),
            
            _buildCategoryCard(
              context,
              category: QueryCategory.building,
            ),
            
            const SizedBox(height: 16),
            
            _buildCategoryCard(
              context,
              category: QueryCategory.other,
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required QueryCategory category,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminChatQueryTemplateScreen(
              category: category,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: _getCategoryGradient(category),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getCategoryGradient(QueryCategory category) {
    switch (category) {
      case QueryCategory.billing:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QueryCategory.maintenance:
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QueryCategory.amenities:
        return const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QueryCategory.complaints:
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QueryCategory.building:
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case QueryCategory.other:
        return const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
