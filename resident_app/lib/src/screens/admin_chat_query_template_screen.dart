// lib/src/screens/admin_chat_query_template_screen.dart
// Query template selection screen for admin chat

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/admin_chat_model.dart';
import '../services/admin_chat_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'admin_chat_conversation_screen.dart';

class AdminChatQueryTemplateScreen extends StatefulWidget {
  final QueryCategory category;

  const AdminChatQueryTemplateScreen({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<AdminChatQueryTemplateScreen> createState() => _AdminChatQueryTemplateScreenState();
}

class _AdminChatQueryTemplateScreenState extends State<AdminChatQueryTemplateScreen> {
  final TextEditingController _customQueryController = TextEditingController();
  final AdminChatService _adminChatService = AdminChatService.instance;
  bool _isLoading = false;
  String? _selectedTemplate;

  @override
  void dispose() {
    _customQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.category.templates;
    final hasTemplates = templates.isNotEmpty;

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
          widget.category.displayName,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            
            if (hasTemplates) ...[
              // Quick queries header
              Text(
                'Quick queries:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                'Tap a query to send it to admin',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Template buttons
              ...templates.map((template) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTemplateButton(template),
              )).toList(),
              
              const SizedBox(height: 24),
              
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
            
            // Custom query input
            Text(
              hasTemplates ? 'Type your own question:' : 'Type your question:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _customQueryController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe your query in detail...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Send button
            ElevatedButton(
              onPressed: _isLoading ? null : _sendCustomQuery,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Query',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateButton(String template) {
    final isSelected = _selectedTemplate == template;
    
    return GestureDetector(
      onTap: () => _sendTemplateQuery(template),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                template,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTemplateQuery(String template) async {
    setState(() {
      _selectedTemplate = template;
      _isLoading = true;
    });

    await _createChatAndNavigate(template);
  }

  Future<void> _sendCustomQuery() async {
    final query = _customQueryController.text.trim();
    
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your question'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _createChatAndNavigate(query);
  }

  Future<void> _createChatAndNavigate(String query) async {
    try {
      final chat = await _adminChatService.getOrCreateAdminChat(
        category: widget.category,
        initialMessage: query,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (chat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to create admin chat. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate to conversation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminChatConversationScreen(
            chat: chat,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
