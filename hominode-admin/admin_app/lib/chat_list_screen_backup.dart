import 'package:flutter/material.dart';
import 'widgets/standard_header.dart';
import 'resident_chat_screen.dart';
import 'models/chat_models.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
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

  // Sample chat data
  final List<ChatConversation> recentChats = [
    ChatConversation(
      id: '1',
      name: 'Rajesh Kumar',
      flatNumber: 'A-101',
      lastMessage: 'Thank you for resolving the maintenance issue.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      unreadCount: 0,
      isOnline: true,
      chatType: ChatType.individual,
    ),
    ChatConversation(
      id: '2',
      name: 'Building A Residents',
      flatNumber: null,
      lastMessage: 'Meeting scheduled for tomorrow at 6 PM',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 3,
      isOnline: false,
      chatType: ChatType.group,
      memberCount: 85,
    ),
    ChatConversation(
      id: '3',
      name: 'Priya Sharma',
      flatNumber: 'B-205',
      lastMessage: 'When will the elevator be fixed?',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      unreadCount: 1,
      isOnline: false,
      chatType: ChatType.individual,
    ),
    ChatConversation(
      id: '4',
      name: 'Committee Members',
      flatNumber: null,
      lastMessage: 'Budget discussion completed',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      chatType: ChatType.group,
      memberCount: 8,
    ),
  ];

  final List<ResidentContact> allResidents = [
    ResidentContact(
      id: '1',
      name: 'Rajesh Kumar',
      flatNumber: 'A-101',
      isOnline: true,
      hasExistingChat: true,
    ),
    ResidentContact(
      id: '2',
      name: 'Priya Sharma',
      flatNumber: 'B-205',
      isOnline: false,
      hasExistingChat: true,
    ),
    ResidentContact(
      id: '3',
      name: 'Amit Patel',
      flatNumber: 'A-103',
      isOnline: true,
      hasExistingChat: false,
    ),
    ResidentContact(
      id: '4',
      name: 'Sunita Gupta',
      flatNumber: 'B-201',
      isOnline: false,
      hasExistingChat: false,
    ),
    ResidentContact(
      id: '5',
      name: 'Vikram Singh',
      flatNumber: 'C-301',
      isOnline: true,
      hasExistingChat: false,
    ),
  ];

  final List<GroupChat> groups = [
    GroupChat(
      id: '1',
      name: 'Building A Residents',
      memberCount: 85,
      description: 'All residents of Building A',
      isActive: true,
    ),
    GroupChat(
      id: '2',
      name: 'Committee Members',
      memberCount: 8,
      description: 'Society management committee',
      isActive: true,
    ),
    GroupChat(
      id: '3',
      name: 'Floor 2 Residents',
      memberCount: 15,
      description: 'Second floor community',
      isActive: false,
    ),
  ];

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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          // Tab Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
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
                tabs: const [
                  Tab(
                    child: Text(
                      'Recent',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Residents',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Groups',
                      style: TextStyle(
                        fontSize: 14,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
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
    final filteredChats = recentChats.where((chat) {
      return chat.name.toLowerCase().contains(searchQuery) ||
             (chat.flatNumber?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();

    if (filteredChats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'No recent conversations',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start a conversation with residents',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return _buildChatTile(chat);
      },
    );
  }

  Widget _buildResidentsList() {
    final filteredResidents = allResidents.where((resident) {
      return resident.name.toLowerCase().contains(searchQuery) ||
             resident.flatNumber.toLowerCase().contains(searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredResidents.length,
      itemBuilder: (context, index) {
        final resident = filteredResidents[index];
        return _buildResidentTile(resident);
      },
    );
  }

  Widget _buildGroupsList() {
    final filteredGroups = groups.where((group) {
      return group.name.toLowerCase().contains(searchQuery) ||
             group.description.toLowerCase().contains(searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredGroups.length,
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        return _buildGroupTile(group);
      },
    );
  }

  Widget _buildChatTile(ChatConversation chat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: chat.chatType == ChatType.group 
                        ? const Color(0xFF8B5CF6) 
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: chat.chatType == ChatType.group
                        ? const Icon(Icons.group, color: Colors.white, size: 24)
                        : Text(
                            chat.name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
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
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(chat.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat.flatNumber != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            chat.flatNumber!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (chat.memberCount != null) ...[
                        Icon(
                          Icons.group,
                          size: 14,
                          color: const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${chat.memberCount} members',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: const TextStyle(
                            fontSize: 14,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chat.unreadCount.toString(),
                  style: const TextStyle(
                    fontSize: 12,
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

  Widget _buildResidentTile(ResidentContact resident) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      resident.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
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
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Resident Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resident.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          resident.flatNumber,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (resident.hasExistingChat)
                        const Text(
                          'Previous conversation',
                          style: TextStyle(
                            fontSize: 12,
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
              color: const Color(0xFF2563EB),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(GroupChat group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openGroupChat(group),
        child: Row(
          children: [
            // Group Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: group.isActive ? const Color(0xFF8B5CF6) : const Color(0xFF9CA3AF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(Icons.group, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            
            // Group Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      if (!group.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CA3AF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.group,
                        size: 14,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberCount} members',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
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
            
            // Options Menu
            IconButton(
              onPressed: () => _showGroupOptions(group),
              icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create New Chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 20),
              
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person_add, color: Color(0xFF2563EB)),
                ),
                title: const Text('New Individual Chat'),
                subtitle: const Text('Start conversation with a resident'),
                onTap: () {
                  Navigator.pop(context);
                  _tabController.animateTo(1); // Switch to Residents tab
                },
              ),
              
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.group_add, color: Color(0xFF8B5CF6)),
                ),
                title: const Text('Create Group Chat'),
                subtitle: const Text('Add multiple residents to a group'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateGroupDialog();
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    // TODO: Implement create group dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create Group feature - Coming soon')),
    );
  }

  void _showGroupOptions(GroupChat group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 20),
              
              ListTile(
                leading: const Icon(Icons.people, color: Color(0xFF2563EB)),
                title: const Text('Manage Members'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to manage members screen
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF059669)),
                title: const Text('Edit Group Info'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show edit group dialog
                },
              ),
              
              if (group.isActive)
                ListTile(
                  leading: const Icon(Icons.pause_circle, color: Color(0xFFF59E0B)),
                  title: const Text('Deactivate Group'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Deactivate group
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.play_circle, color: Color(0xFF10B981)),
                  title: const Text('Activate Group'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Activate group
                  },
                ),
              
              const SizedBox(height: 20),
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

  void _openGroupChat(GroupChat group) {
    if (!group.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This group is currently inactive')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentChatScreen(
          chatId: group.id,
          chatName: group.name,
          chatType: ChatType.group,
        ),
      ),
    );
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

