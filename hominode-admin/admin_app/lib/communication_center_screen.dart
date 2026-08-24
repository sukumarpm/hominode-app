import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/standard_header.dart';
import 'widgets/create_pinned_post_modal.dart';
import 'chat_list_screen.dart';
import 'broadcast_history_screen.dart';
import 'services/broadcast_service.dart';
import 'services/pinned_post_service.dart';

class CommunicationCenterScreen extends StatefulWidget {
  const CommunicationCenterScreen({super.key});

  @override
  State<CommunicationCenterScreen> createState() =>
      _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState extends State<CommunicationCenterScreen> {
  final BroadcastService _broadcastService = BroadcastService();
  final PinnedPostService _pinnedPostService = PinnedPostService();
  int selectedTabIndex = 0; // Default to Messages tab
  final TextEditingController _searchController = TextEditingController();

  List<BroadcastMessage> broadcastHistory = [];
  List<BroadcastMessage> filteredBroadcasts = [];
  bool isLoadingBroadcasts = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterBroadcasts);
    _searchController.addListener(() {
      setState(() {}); // Update UI when search text changes
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBroadcasts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredBroadcasts = broadcastHistory;
      } else {
        filteredBroadcasts = broadcastHistory.where((broadcast) {
          return broadcast.title.toLowerCase().contains(query) ||
              broadcast.content.toLowerCase().contains(query) ||
              broadcast.type.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _refreshBroadcastHistory() {
    // Broadcasts are now loaded from Firestore stream
    // No need to manually refresh
  }

  void _showMessageTypeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by Message Type',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  _buildFilterOption(
                    'All Messages',
                    'all',
                    Icons.all_inclusive,
                  ),
                  _buildFilterOption(
                    'Push Notifications',
                    'push',
                    Icons.notifications,
                  ),
                  _buildFilterOption('Email Messages', 'email', Icons.email),
                  _buildFilterOption('SMS Messages', 'sms', Icons.sms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, String type, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0E4778)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        _applyMessageFilter(type);
      },
    );
  }

  void _applyMessageFilter(String type) {
    setState(() {
      if (type == 'all') {
        filteredBroadcasts = broadcastHistory;
      } else {
        filteredBroadcasts = broadcastHistory.where((broadcast) {
          return broadcast.type.toLowerCase() == type.toLowerCase();
        }).toList();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filtered by ${type == 'all' ? 'all messages' : type}'),
        backgroundColor: const Color(0xFF0E4778),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  CommunicationStats _getCommunicationStats() {
    final thisMonth = broadcastHistory.where((msg) {
      final now = DateTime.now();
      return msg.sentAt.month == now.month && msg.sentAt.year == now.year;
    }).length;

    final totalDelivered = broadcastHistory.fold<int>(
      0,
      (sum, msg) => sum + msg.deliveredCount,
    );
    final totalSent = broadcastHistory.fold<int>(
      0,
      (sum, msg) => sum + msg.recipientCount,
    );
    final deliveryRate = totalSent > 0
        ? (totalDelivered / totalSent * 100)
        : 0.0;

    final totalRead = broadcastHistory.fold<int>(
      0,
      (sum, msg) => sum + msg.readCount,
    );
    final readRate = totalDelivered > 0
        ? (totalRead / totalDelivered * 100)
        : 0.0;

    return CommunicationStats(
      messagesThisMonth: thisMonth,
      deliveryRate: deliveryRate,
      readRate: readRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _broadcastService.getBroadcasts(),
        builder: (context, snapshot) {
          // Update broadcast history from Firestore
          if (snapshot.hasData) {
            broadcastHistory = snapshot.data!.map((data) {
              return BroadcastMessage(
                id: data['id'] as String,
                title: data['title'] as String,
                content: data['content'] as String,
                type: data['type'] as String,
                recipientCount: data['recipientCount'] as int,
                deliveredCount: data['deliveredCount'] as int,
                readCount: data['readCount'] as int,
                sentAt: data['sentAt'] as DateTime,
              );
            }).toList();

            // Apply current filter
            if (_searchController.text.isEmpty) {
              filteredBroadcasts = broadcastHistory;
            } else {
              _filterBroadcasts();
            }

            isLoadingBroadcasts = false;
          } else if (snapshot.hasError) {
            isLoadingBroadcasts = false;
          }

          final stats = _getCommunicationStats();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Standard Header
              SliverToBoxAdapter(
                child: PrimaryAppHeader(
                  title: 'Communication Center',
                  subtitle: 'Send messages & manage announcements',
                  showBackButton: true,
                ),
              ),

              // Content
              SliverPadding(
                padding: EdgeInsets.all(16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stats Summary Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            stats.messagesThisMonth.toString(),
                            'This Month',
                            Icons.send_outlined,
                            const Color(0xFF0E4778),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildStatCard(
                            '${stats.deliveryRate.toStringAsFixed(1)}%',
                            'Delivered',
                            Icons.check_circle_outline,
                            const Color(0xFF10B981),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildStatCard(
                            '${stats.readRate.toStringAsFixed(1)}%',
                            'Read Rate',
                            Icons.visibility_outlined,
                            const Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // Quick Actions Row - Resident Chat Only
                    _buildQuickActionCard(
                      'Resident Chat',
                      'Direct messaging with residents',
                      Icons.chat_bubble_outline,
                      const Color(0xFF10B981),
                      () => _openResidentChat(),
                    ),

                    SizedBox(height: 24.h),

                    // Tab Switcher
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildTabButton('Messages', 0)),
                          Expanded(child: _buildTabButton('Pinned Posts', 1)),
                          Expanded(child: _buildTabButton('Analytics', 2)),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Tab Content
                    if (selectedTabIndex == 0) ...[
                      // Messages Tab
                      ..._buildMessagesTabContent(),
                    ] else if (selectedTabIndex == 1) ...[
                      // Pinned Posts Tab
                      ..._buildPinnedPostsTabContent(),
                    ] else ...[
                      // Analytics Tab
                      ..._buildAnalyticsTabContent(),
                    ],

                    // Bottom padding for navigation
                    SizedBox(height: 80.h),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: selectedTabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreatePinnedPostModal,
              backgroundColor: const Color(0xFF0E4778),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.push_pin),
              label: const Text('Create Post'),
            )
          : null,
    );
  }

  Widget _buildStatCard(
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20.w, color: color),
          SizedBox(height: 8.h),
          Text(
            number,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24.w),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTabIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessagesTabContent() {
    return [
      // Search Bar with Filter
      Row(
        children: [
          Expanded(
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
                  hintText: 'Search messages by title or content...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: 20.w,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20.w),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _showMessageTypeFilter,
            child: Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: const Color(0xFF0E4778),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E4778).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.filter_list, color: Colors.white, size: 20.w),
            ),
          ),
        ],
      ),

      SizedBox(height: 20.h),

      // Message History
      if (isLoadingBroadcasts)
        Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: 16.h),
                Text(
                  'Loading messages...',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        )
      else if (filteredBroadcasts.isEmpty)
        Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              children: [
                Icon(
                  _searchController.text.isNotEmpty
                      ? Icons.search_off
                      : Icons.message_outlined,
                  size: 64.w,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16.h),
                Text(
                  _searchController.text.isNotEmpty
                      ? 'No messages found'
                      : 'No messages yet',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _searchController.text.isNotEmpty
                      ? 'Try adjusting your search'
                      : 'Send your first broadcast message',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        )
      else
        ...filteredBroadcasts.map((broadcast) {
          return Column(
            children: [
              _buildBroadcastCard(broadcast),
              SizedBox(height: 12.h),
            ],
          );
        }),
    ];
  }

  List<Widget> _buildPinnedPostsTabContent() {
    return [
      // Pinned Posts with StreamBuilder
      StreamBuilder<List<PinnedPostModel>>(
        stream: _pinnedPostService.getPinnedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(40.0.w),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: 16.h),
                    Text(
                      'Loading pinned posts...',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(40.0.w),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64.w,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Error loading pinned posts',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final pinnedPosts = snapshot.data ?? [];

          if (pinnedPosts.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(40.0.w),
                child: Column(
                  children: [
                    Icon(
                      Icons.push_pin_outlined,
                      size: 64.w,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No pinned posts yet',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Create your first pinned post',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: pinnedPosts
                .map(
                  (post) => Column(
                    children: [
                      _buildPinnedPostCard(
                        post.id,
                        post.title,
                        post.content,
                        post.getFormattedDate(),
                        onDelete: () => _deletePinnedPost(post.id),
                        onEdit: () => _editPinnedPost(post),
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                )
                .toList(),
          );
        },
      ),
    ];
  }

  List<Widget> _buildAnalyticsTabContent() {
    return [
      // Analytics Cards with StreamBuilder for real data
      StreamBuilder<List<PinnedPostModel>>(
        stream: _pinnedPostService.getPinnedPosts(),
        builder: (context, pinnedSnapshot) {
          final pinnedPostsCount = pinnedSnapshot.data?.length ?? 0;

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Total Messages',
                      broadcastHistory.length.toString(),
                      Icons.send_outlined,
                      const Color(0xFF0E4778),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Active Chats',
                      '0', // Will be updated when chat integration is complete
                      Icons.chat_bubble_outline,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Pinned Posts',
                      pinnedPostsCount.toString(),
                      Icons.push_pin_outlined,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Response Rate',
                      '92%',
                      Icons.trending_up,
                      const Color(0xFFA855F7),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),

      SizedBox(height: 24.h),

      // View Detailed Analytics Button
      SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Message Analytics'),
                    backgroundColor: const Color(0xFF0E4778),
                    foregroundColor: Colors.white,
                  ),
                  body: Center(
                    child: Text(
                      'Message Analytics\nComing Soon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          icon: Icon(Icons.analytics_outlined, size: 18.w),
          label: const Text('View Detailed Analytics'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0E4778),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ),

      SizedBox(height: 16.h),

      // Broadcast History Button
      SizedBox(
        width: double.infinity,
        height: 48.h,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BroadcastHistoryScreen()),
            );
          },
          icon: Icon(Icons.history, size: 18.w),
          label: const Text('Broadcast History'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0E4778),
            side: const BorderSide(color: Color(0xFF0E4778)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20.w, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastCard(BroadcastMessage broadcast) {
    final deliveryPercentage = broadcast.recipientCount > 0
        ? (broadcast.deliveredCount / broadcast.recipientCount * 100)
        : 0.0;
    final readPercentage = broadcast.deliveredCount > 0
        ? (broadcast.readCount / broadcast.deliveredCount * 100)
        : 0.0;

    return GestureDetector(
      onTap: () => _showBroadcastDetails(broadcast),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    broadcast.title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _getBroadcastTypeColor(broadcast.type),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    broadcast.type,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Content Preview
            Text(
              broadcast.content,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 16.h),

            // Progress Indicators
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivered',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${deliveryPercentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      LinearProgressIndicator(
                        value: deliveryPercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF10B981),
                        ),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Read',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${readPercentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Color(0xFFA855F7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      LinearProgressIndicator(
                        value: readPercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFA855F7),
                        ),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Stats Row
            Row(
              children: [
                Icon(Icons.people_outline, size: 16.w, color: Colors.grey[500]),
                SizedBox(width: 4.w),
                Text(
                  '${broadcast.recipientCount} recipients',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 16.w),
                Icon(
                  Icons.check_circle_outline,
                  size: 16.w,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 4.w),
                Text(
                  '${broadcast.deliveredCount} delivered',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(broadcast.sentAt),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedPostCard(
    String postId,
    String title,
    String description,
    String date, {
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          // Header Row with Title and Actions
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4778),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'Pinned',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) {
                    onEdit();
                  } else if (value == 'delete' && onDelete != null) {
                    _showDeleteConfirmation(onDelete);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16.w),
                        SizedBox(width: 8.w),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16.w,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Delete',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    Icons.more_vert,
                    size: 16.w,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          SizedBox(height: 12.h),

          // Date
          Text(
            date,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePinnedPostModal() {
    showDialog(
      context: context,
      barrierColor: const Color(0x59000000),
      builder: (BuildContext context) {
        return const CreatePinnedPostModal();
      },
    ).then((result) async {
      if (result != null) {
        try {
          await _pinnedPostService.createPinnedPost(
            title: result['title'],
            content: result['content'],
            category: result['category'],
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pinned post created successfully'),
                backgroundColor: Color(0xFF16A34A),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating pinned post: $e'),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

  void _openResidentChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListScreen()),
    );
  }

  void _showBroadcastDetails(BroadcastMessage broadcast) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BroadcastDetailModal(broadcast: broadcast),
    );
  }

  void _editPinnedPost(PinnedPostModel post) {
    // Show edit modal - for now, show a simple edit dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final titleController = TextEditingController(text: post.title);
        final contentController = TextEditingController(text: post.content);

        return AlertDialog(
          title: const Text('Edit Pinned Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    contentController.text.isNotEmpty) {
                  try {
                    await _pinnedPostService.updatePinnedPost(
                      postId: post.id,
                      title: titleController.text,
                      content: contentController.text,
                      category: post.category,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pinned post updated successfully'),
                          backgroundColor: Color(0xFF16A34A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating pinned post: $e'),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E4778),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _deletePinnedPost(String postId) async {
    try {
      await _pinnedPostService.deletePinnedPost(postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pinned post deleted successfully'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting pinned post: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Pinned Post'),
          content: const Text(
            'Are you sure you want to delete this pinned post? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Color _getBroadcastTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'push':
        return const Color(0xFF0E4778);
      case 'email':
        return const Color(0xFF8B5CF6);
      case 'sms':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

// Data Models for Communication Center
class CommunicationStats {
  final int messagesThisMonth;
  final double deliveryRate;
  final double readRate;

  CommunicationStats({
    required this.messagesThisMonth,
    required this.deliveryRate,
    required this.readRate,
  });
}

class BroadcastMessage {
  final String id;
  final String title;
  final String content;
  final String type; // 'Push', 'Email', 'SMS'
  final int recipientCount;
  final int deliveredCount;
  final int readCount;
  final DateTime sentAt;

  BroadcastMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.recipientCount,
    required this.deliveredCount,
    required this.readCount,
    required this.sentAt,
  });

  static List<BroadcastMessage> getSampleBroadcasts() {
    return [
      BroadcastMessage(
        id: '1',
        title: 'Maintenance Bill Generated',
        content:
            'Your maintenance bill for January 2025 has been generated. Please check your account for details.',
        type: 'Push',
        recipientCount: 248,
        deliveredCount: 245,
        readCount: 198,
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      BroadcastMessage(
        id: '2',
        title: 'Visitor Entry Alert',
        content:
            'A visitor has been approved for your flat. Please be available to receive them.',
        type: 'Push',
        recipientCount: 1,
        deliveredCount: 1,
        readCount: 1,
        sentAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      BroadcastMessage(
        id: '3',
        title: 'New Year Celebration Invitation',
        content:
            'You are invited to the New Year celebration on January 1st at the community hall.',
        type: 'Email',
        recipientCount: 248,
        deliveredCount: 240,
        readCount: 180,
        sentAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      BroadcastMessage(
        id: '4',
        title: 'Water Supply Maintenance',
        content:
            'Water supply will be interrupted tomorrow from 10 AM to 2 PM for maintenance work.',
        type: 'SMS',
        recipientCount: 248,
        deliveredCount: 248,
        readCount: 220,
        sentAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      BroadcastMessage(
        id: '5',
        title: 'Security Update',
        content:
            'New security protocols have been implemented. Please carry your ID cards at all times.',
        type: 'Push',
        recipientCount: 248,
        deliveredCount: 242,
        readCount: 195,
        sentAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }
}

class BroadcastDetailModal extends StatelessWidget {
  final BroadcastMessage broadcast;

  const BroadcastDetailModal({super.key, required this.broadcast});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 8.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        broadcast.title,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getBroadcastTypeColor(broadcast.type),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        broadcast.type,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Content
                Text(
                  broadcast.content,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 20.h),

                // Statistics
                Text(
                  'Delivery Statistics',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),

                SizedBox(height: 12.h),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Recipients',
                        broadcast.recipientCount.toString(),
                        Icons.people_outline,
                        const Color(0xFF0E4778),
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Delivered',
                        broadcast.deliveredCount.toString(),
                        Icons.check_circle_outline,
                        const Color(0xFF10B981),
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Read',
                        broadcast.readCount.toString(),
                        Icons.visibility_outlined,
                        const Color(0xFFA855F7),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // Sent Time
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16.w, color: Colors.grey[500]),
                    SizedBox(width: 8.w),
                    Text(
                      'Sent ${_formatDateTime(broadcast.sentAt)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20.w, color: color),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Color _getBroadcastTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'push':
        return const Color(0xFF0E4778);
      case 'email':
        return const Color(0xFF8B5CF6);
      case 'sms':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
