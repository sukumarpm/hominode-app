// lib/src/screens/admin_chat_conversation_screen.dart
// Admin chat conversation screen with real-time messaging

import 'package:flutter/material.dart';
import '../models/admin_chat_model.dart';
import '../services/admin_chat_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'admin_chat_query_selection_screen.dart';

class AdminChatConversationScreen extends StatefulWidget {
  final AdminChatModel chat;

  const AdminChatConversationScreen({
    super.key,
    required this.chat,
  });

  @override
  State<AdminChatConversationScreen> createState() => _AdminChatConversationScreenState();
}

class _AdminChatConversationScreenState extends State<AdminChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AdminChatService _adminChatService = AdminChatService.instance;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read
    _adminChatService.markAsRead(widget.chat.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chat.adminName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.chat.category.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Status badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.chat.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(widget.chat.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(widget.chat.status),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.border,
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<AdminChatMessageModel>>(
              stream: _adminChatService.streamMessages(widget.chat.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSizes.pagePadding),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isResident = message.senderRole == 'resident';
                    
                    return _buildMessageBubble(message, isResident);
                  },
                );
              },
            ),
          ),

          // Resolved status banner
          if (widget.chat.status == AdminChatStatus.resolved)
            _buildResolvedBanner(),

          // Message input (only if not resolved)
          if (widget.chat.status != AdminChatStatus.resolved)
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AdminChatMessageModel message, bool isResident) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isResident ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name and time
          Padding(
            padding: EdgeInsets.only(
              left: isResident ? 0 : 12,
              right: isResident ? 12 : 0,
              bottom: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isResident ? 'You' : message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Message bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isResident ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isResident ? 16 : 4),
                bottomRight: Radius.circular(isResident ? 4 : 16),
              ),
              border: isResident ? null : Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Query badge (if it's a query)
                if (message.isQuery)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isResident 
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 12,
                          color: isResident ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Query',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isResident ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Message text
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isResident ? Colors.white : AppColors.textPrimary,
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

  Widget _buildResolvedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        border: Border(
          top: BorderSide(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Query Resolved',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'This query has been marked as resolved by admin',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminChatQuerySelectionScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'New Query',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      await _adminChatService.sendMessage(
        chatId: widget.chat.id,
        text: text,
        isQuery: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      final hour = timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Color _getStatusColor(AdminChatStatus status) {
    switch (status) {
      case AdminChatStatus.open:
        return const Color(0xFF3B82F6);
      case AdminChatStatus.resolved:
        return const Color(0xFF10B981);
      case AdminChatStatus.closed:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(AdminChatStatus status) {
    switch (status) {
      case AdminChatStatus.open:
        return 'Open';
      case AdminChatStatus.resolved:
        return 'Resolved';
      case AdminChatStatus.closed:
        return 'Closed';
    }
  }
}
