import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    } else if (widget.residentId != null &&
        widget.residentName != null &&
        widget.flatLabel != null) {
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
    final displayName =
        widget.residentName ?? widget.chatName ?? 'Resident Chat';

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
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            if (widget.flatLabel != null)
              Text(
                widget.flatLabel!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Text(
                widget.chatType == ChatType.group
                    ? 'Group conversation'
                    : 'Quick chat with resident',
                style: TextStyle(
                  fontSize: 12.sp,
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
          ? Center(
              child: Text(
                'Unable to load chat',
                style: TextStyle(fontSize: 16.sp, color: Color(0xFF6B7280)),
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
                              Icon(
                                Icons.error_outline,
                                size: 64.w,
                                color: Color(0xFF9CA3AF),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'Error loading messages',
                                style: TextStyle(
                                  fontSize: 16.sp,
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
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64.w,
                                color: Color(0xFF9CA3AF),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Start the conversation',
                                style: TextStyle(
                                  fontSize: 14.sp,
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
                        padding: EdgeInsets.all(16.w),
                        reverse: true,
                        itemCount: reversedMessages.length,
                        itemBuilder: (context, index) {
                          final message = reversedMessages[index];
                          final isAdmin = message.isSentByAdmin;
                          final showAvatar =
                              index == reversedMessages.length - 1 ||
                              reversedMessages[index + 1].senderId !=
                                  message.senderId;

                          return _buildMessageBubbleFromModel(
                            message,
                            isAdmin,
                            showAvatar,
                          );
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

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isAdmin,
    bool showAvatar,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isAdmin
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isAdmin && showAvatar) ...[
            _buildAvatar(message),
            SizedBox(width: 8.w),
          ] else if (!isAdmin) ...[
            SizedBox(width: 48.w),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isAdmin
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showAvatar && !isAdmin)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      children: [
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        if (message.flatNumber != null) ...[
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E4778).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              message.flatNumber!,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0E4778),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFF0E4778) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r).copyWith(
                      bottomLeft: isAdmin
                          ? Radius.circular(16.r)
                          : Radius.circular(4.r),
                      bottomRight: isAdmin
                          ? Radius.circular(4.r)
                          : Radius.circular(16.r),
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
                      fontSize: 14.sp,
                      color: isAdmin ? Colors.white : const Color(0xFF1F2937),
                      height: 1.4,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(fontSize: 11.sp, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),

          if (isAdmin && showAvatar) ...[
            SizedBox(width: 8.w),
            _buildAvatar(message),
          ] else if (isAdmin) ...[
            SizedBox(width: 48.w),
          ],
        ],
      ),
    );
  }

  // New method for building message bubble from Firestore model
  Widget _buildMessageBubbleFromModel(
    ChatMessageModel message,
    bool isAdmin,
    bool showAvatar,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isAdmin
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isAdmin && showAvatar) ...[
            _buildAvatarFromModel(message),
            SizedBox(width: 8.w),
          ] else if (!isAdmin) ...[
            SizedBox(width: 48.w),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isAdmin
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showAvatar && !isAdmin)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      children: [
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        if (widget.flatLabel != null) ...[
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E4778).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              widget.flatLabel!,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0E4778),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFF0E4778) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r).copyWith(
                      bottomLeft: isAdmin
                          ? Radius.circular(16.r)
                          : Radius.circular(4.r),
                      bottomRight: isAdmin
                          ? Radius.circular(4.r)
                          : Radius.circular(16.r),
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
                      fontSize: 14.sp,
                      color: isAdmin ? Colors.white : const Color(0xFF1F2937),
                      height: 1.4,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    message.timestamp != null
                        ? _formatTimeFromDateTime(message.timestamp!)
                        : 'Just now',
                    style: TextStyle(fontSize: 11.sp, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),

          if (isAdmin && showAvatar) ...[
            SizedBox(width: 8.w),
            _buildAvatarFromModel(message),
          ] else if (isAdmin) ...[
            SizedBox(width: 48.w),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatMessage message) {
    final isAdmin = message.senderType == 'admin';
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFF0E4778) : const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: Text(
          message.senderName[0].toUpperCase(),
          style: TextStyle(
            fontSize: 14.sp,
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
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFF0E4778) : const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: Text(
          message.senderName.isNotEmpty
              ? message.senderName[0].toUpperCase()
              : 'U',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44.w,
                height: 44.h,
                decoration: const BoxDecoration(
                  color: Color(0xFF0E4778),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send, color: Colors.white, size: 20.w),
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
