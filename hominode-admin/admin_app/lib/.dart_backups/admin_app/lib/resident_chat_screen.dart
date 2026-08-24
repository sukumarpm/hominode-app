import 'package:flutter/material.dart';
import 'models/chat_models.dart';
import 'services/chat_service.dart';

class ResidentChatScreen extends StatefulWidget {
  final String? chatId;
  final String? residentId;
  final String? residentName;
  final String? flatLabel;
  final String? chatName;
  final ChatType? chatType;
  
  const ResidentChatScreen({
    super.key,
    this.chatId,
    this.residentId,
    this.residentName,
    this.flatLabel,
    this.chatName,
    this.chatType,
  });

  @override
  State<ResidentChatScreen> createState() => _ResidentChatScreenState();
}

class _ResidentChatScreenState extends State<ResidentChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  String? _activeChatId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (widget.chatId != null) {
      setState(() {
        _activeChatId = widget.chatId;
      });
    } else if (widget.residentId != null && widget.residentName != null && widget.flatLabel != null) {
      // Create or get chat
      setState(() {
        _isLoading = true;
      });
      
      try {
        final chatId = await _chatService.createOrGetChat(
          residentId: widget.residentId!,
          residentName: widget.residentName!,
          flatLabel: widget.flatLabel!,
        );
        
        setState(() {
          _activeChatId = chatId;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing chat: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _activeChatId == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        chatId: _activeChatId!,
        message: messageText,
      );

      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.residentName ?? widget.chatName ?? 'Resident Chat';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            if (widget.flatLabel != null)
              Text(
                widget.flatLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Text(
                widget.chatType == ChatType.group 
                    ? 'Group conversation'
                    : 'Quick chat with resident',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Show chat options menu
            },
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeChatId == null
              ? const Center(
                  child: Text(
                    'Unable to load chat',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Chat Messages with StreamBuilder
                    Expanded(
                      child: StreamBuilder<List<ChatMessageModel>>(
                        stream: _chatService.getChatMessages(_activeChatId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading messages',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final messages = snapshot.data ?? [];

                          if (messages.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start the conversation',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Reverse messages to show newest at bottom
                          final reversedMessages = messages.reversed.toList();

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            reverse: true,
                            itemCount: reversedMessages.length,
                            itemBuilder: (context, index) {
                              final message = reversedMessages[index];
                              final isAdmin = message.isSentByAdmin;
                              final showAvatar = index == reversedMessages.length - 1 || 
                                  reversedMessages[index + 1].senderId != message.senderId;

                              return _buildMessageBubbleFromModel(message, isAdmin, showAvatar);
                            },
                          );
                        },
                      ),
                    ),
                    
                    // Message Input
                    _buildMessageInput(),
                  ],
                ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isAdmin, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isAdmin && showAvatar) ...[
            _buildAvatar(message),
            const SizedBox(width: 8),
          ] else if (!isAdmin) ...[
            const SizedBox(width: 48),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAvatar && !isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          message.senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        if (message.flatNumber != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.flatNumber!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: isAdmin ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isAdmin ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAdmin ? Colors.white : const Color(0xFF1F2937),
                      height: 1.4,
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (isAdmin && showAvatar) ...[
            const SizedBox(width: 8),
            _buildAvatar(message),
          ] else if (isAdmin) ...[
            const SizedBox(width: 48),
          ],
        ],
      ),
    );
  }

  // New method for building message bubble from Firestore model
  Widget _buildMessageBubbleFromModel(ChatMessageModel message, bool isAdmin, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isAdmin && showAvatar) ...[
            _buildAvatarFromModel(message),
            const SizedBox(width: 8),
          ] else if (!isAdmin) ...[
            const SizedBox(width: 48),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAvatar && !isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          message.senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        if (widget.flatLabel != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.flatLabel!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: isAdmin ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isAdmin ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAdmin ? Colors.white : const Color(0xFF1F2937),
                      height: 1.4,
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message.timestamp != null ? _formatTimeFromDateTime(message.timestamp!) : 'Just now',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (isAdmin && showAvatar) ...[
            const SizedBox(width: 8),
            _buildAvatarFromModel(message),
          ] else if (isAdmin) ...[
            const SizedBox(width: 48),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatMessage message) {
    final isAdmin = message.senderType == 'admin';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFF2563EB) : const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message.senderName[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFromModel(ChatMessageModel message) {
    final isAdmin = message.isSentByAdmin;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFF2563EB) : const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
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

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatTimeFromDateTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

