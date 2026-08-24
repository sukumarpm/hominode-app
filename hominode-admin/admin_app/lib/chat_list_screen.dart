import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/standard_header.dart';
import 'resident_chat_screen.dart';
import 'models/chat_models.dart';
import 'services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Standard Header
          SliverToBoxAdapter(
            child: PrimaryAppHeader(
              title: 'Messages',
              subtitle: 'Chat with residents & groups',
              showBackButton: true,
              actionWidget: GestureDetector(
                onTap: _showCreateChatOptions,
                child: Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 20.w),
                ),
              ),
            ),
          ),

          // Tab Bar
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(16.w),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Text(
                      'Recent',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Residents',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Groups',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search messages, residents...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[400],
                      size: 20.w,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20.w),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 16.h)),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentChats(),
                _buildResidentsList(),
                _buildGroupsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChats() {
    return StreamBuilder<List<ChatConversationModel>>(
      stream: _chatService.getChatConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64.w, color: Color(0xFF9CA3AF)),
                SizedBox(height: 16.h),
                Text(
                  'Error loading conversations',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final allChats = snapshot.data ?? [];
        final filteredChats = allChats.where((chat) {
          return chat.residentName.toLowerCase().contains(searchQuery) ||
              chat.flatLabel.toLowerCase().contains(searchQuery);
        }).toList();

        if (filteredChats.isEmpty) {
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
                  'No recent conversations',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Start a conversation with residents',
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chat = filteredChats[index];
            return _buildChatTileFromModel(chat);
          },
        );
      },
    );
  }

  Widget _buildResidentsList() {
    return StreamBuilder<List<ResidentContactModel>>(
      stream: _chatService.getResidents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64.w, color: Color(0xFF9CA3AF)),
                SizedBox(height: 16.h),
                Text(
                  'Error loading residents',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final allResidents = snapshot.data ?? [];
        final filteredResidents = allResidents.where((resident) {
          return resident.name.toLowerCase().contains(searchQuery) ||
              resident.flatLabel.toLowerCase().contains(searchQuery);
        }).toList();

        if (filteredResidents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64.w,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(height: 16.h),
                Text(
                  'No residents found',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: filteredResidents.length,
          itemBuilder: (context, index) {
            final resident = filteredResidents[index];
            return _buildResidentTileFromModel(resident);
          },
        );
      },
    );
  }

  Widget _buildGroupsList() {
    // Group chats feature coming soon
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64.w, color: Color(0xFF9CA3AF)),
          SizedBox(height: 16.h),
          Text(
            'Group Chats',
            style: TextStyle(
              fontSize: 16.sp,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Coming soon',
            style: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatConversation chat) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openChat(chat),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: chat.chatType == ChatType.group
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF0E4778),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Center(
                    child: chat.chatType == ChatType.group
                        ? Icon(Icons.group, color: Colors.white, size: 24.w)
                        : Text(
                            chat.name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                if (chat.isOnline && chat.chatType == ChatType.individual)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14.w,
                      height: 14.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(7.r),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(chat.timestamp),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      if (chat.flatNumber != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E4778).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            chat.flatNumber!,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0E4778),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      if (chat.memberCount != null) ...[
                        Icon(
                          Icons.group,
                          size: 14.w,
                          color: const Color(0xFF6B7280),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${chat.memberCount} members',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unread Badge
            if (chat.unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  chat.unreadCount.toString(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // New method for building chat tile from Firestore model
  Widget _buildChatTileFromModel(ChatConversationModel chat) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openChatFromModel(chat),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: const Color(0xFF0E4778),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Center(
                child: Text(
                  chat.residentName.isNotEmpty
                      ? chat.residentName[0].toUpperCase()
                      : 'R',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.residentName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Text(
                        chat.getFormattedTime(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E4778).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          chat.flatLabel,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0E4778),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty
                              ? 'No messages yet'
                              : chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unread Badge
            // TODO: Implement unread count from Firestore
          ],
        ),
      ),
    );
  }

  Widget _buildResidentTile(ResidentContact resident) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _startChatWithResident(resident),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Center(
                    child: Text(
                      resident.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (resident.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14.w,
                      height: 14.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(7.r),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),

            // Resident Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resident.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E4778).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          resident.flatNumber,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0E4778),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (resident.hasExistingChat)
                        Text(
                          'Previous conversation',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Icon
            Icon(
              resident.hasExistingChat ? Icons.chat : Icons.chat_bubble_outline,
              color: const Color(0xFF0E4778),
              size: 20.w,
            ),
          ],
        ),
      ),
    );
  }

  // New method for building resident tile from Firestore model
  Widget _buildResidentTileFromModel(ResidentContactModel resident) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _startChatWithResidentFromModel(resident),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Center(
                child: Text(
                  resident.name.isNotEmpty
                      ? resident.name[0].toUpperCase()
                      : 'R',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Resident Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resident.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E4778).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          resident.flatLabel,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0E4778),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Icon
            Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF0E4778),
              size: 20.w,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Create New Chat',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 20.h),

              ListTile(
                leading: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E4778).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: const Icon(Icons.person_add, color: Color(0xFF0E4778)),
                ),
                title: const Text('New Individual Chat'),
                subtitle: const Text('Start conversation with a resident'),
                onTap: () {
                  Navigator.pop(context);
                  _tabController.animateTo(1); // Switch to Residents tab
                },
              ),

              SizedBox(height: 20.h),
            ],
          ),
        );
      },
    );
  }

  void _openChat(ChatConversation chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentChatScreen(
          chatId: chat.id,
          chatName: chat.name,
          chatType: chat.chatType,
        ),
      ),
    );
  }

  void _openChatFromModel(ChatConversationModel chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentChatScreen(
          chatId: chat.id,
          residentId: chat.residentId,
          residentName: chat.residentName,
          flatLabel: chat.flatLabel,
        ),
      ),
    );
  }

  void _startChatWithResident(ResidentContact resident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentChatScreen(
          chatId: resident.id,
          chatName: resident.name,
          chatType: ChatType.individual,
        ),
      ),
    );
  }

  void _startChatWithResidentFromModel(ResidentContactModel resident) async {
    try {
      // Create or get existing chat
      final chatId = await _chatService.createOrGetChat(
        residentId: resident.id,
        residentName: resident.name,
        flatLabel: resident.flatLabel,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResidentChatScreen(
              chatId: chatId,
              residentId: resident.id,
              residentName: resident.name,
              flatLabel: resident.flatLabel,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
