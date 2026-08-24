import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/standard_header.dart';
import 'communication_center_screen.dart';

class BroadcastHistoryScreen extends StatefulWidget {
  const BroadcastHistoryScreen({super.key});

  @override
  State<BroadcastHistoryScreen> createState() => _BroadcastHistoryScreenState();
}

class _BroadcastHistoryScreenState extends State<BroadcastHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<BroadcastMessage> broadcastHistory;
  late List<BroadcastMessage> filteredBroadcasts;
  String selectedFilter = 'All';

  final List<String> filters = ['All', 'Push', 'Email', 'SMS'];

  @override
  void initState() {
    super.initState();
    broadcastHistory = BroadcastMessage.getSampleBroadcasts();
    filteredBroadcasts = broadcastHistory;
    _searchController.addListener(_filterBroadcasts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBroadcasts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredBroadcasts = broadcastHistory.where((broadcast) {
        final matchesSearch =
            broadcast.title.toLowerCase().contains(query) ||
            broadcast.content.toLowerCase().contains(query);

        final matchesFilter =
            selectedFilter == 'All' ||
            broadcast.type.toLowerCase() == selectedFilter.toLowerCase();

        return matchesSearch && matchesFilter;
      }).toList();
    });
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
              title: 'Broadcast History',
              subtitle: 'View all sent messages and their statistics',
              showBackButton: true,
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Messages',
                          broadcastHistory.length.toString(),
                          Icons.send_outlined,
                          const Color(0xFF0E4778),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildSummaryCard(
                          'This Month',
                          _getThisMonthCount().toString(),
                          Icons.calendar_month,
                          const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildSummaryCard(
                          'Avg. Read Rate',
                          '${_getAverageReadRate().toStringAsFixed(0)}%',
                          Icons.visibility_outlined,
                          const Color(0xFFA855F7),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((filter) {
                        final isSelected = selectedFilter == filter;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                selectedFilter = filter;
                                _filterBroadcasts();
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: const Color(
                              0xFF0E4778,
                            ).withOpacity(0.1),
                            checkmarkColor: const Color(0xFF0E4778),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF0E4778)
                                  : const Color(0xFF6B7280),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0E4778)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Search Bar
                  Container(
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

                  SizedBox(height: 20.h),

                  // Broadcast List
                  if (filteredBroadcasts.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.w),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64.w,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No messages found',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Try adjusting your search or filter',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredBroadcasts.map((broadcast) {
                      return Column(
                        children: [
                          BroadcastHistoryCard(
                            broadcast: broadcast,
                            onTap: () => _showBroadcastDetails(broadcast),
                          ),
                          SizedBox(height: 12.h),
                        ],
                      );
                    }),

                  // Bottom padding for navigation
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
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
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  int _getThisMonthCount() {
    final now = DateTime.now();
    return broadcastHistory.where((msg) {
      return msg.sentAt.month == now.month && msg.sentAt.year == now.year;
    }).length;
  }

  double _getAverageReadRate() {
    if (broadcastHistory.isEmpty) return 0.0;

    final totalReadRate = broadcastHistory.fold<double>(0.0, (sum, msg) {
      return sum +
          (msg.deliveredCount > 0
              ? (msg.readCount / msg.deliveredCount * 100)
              : 0.0);
    });

    return totalReadRate / broadcastHistory.length;
  }

  void _showBroadcastDetails(BroadcastMessage broadcast) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BroadcastDetailModal(broadcast: broadcast),
    );
  }
}

class BroadcastHistoryCard extends StatelessWidget {
  final BroadcastMessage broadcast;
  final VoidCallback? onTap;

  const BroadcastHistoryCard({super.key, required this.broadcast, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

            // Stats Row
            Row(
              children: [
                _buildStatChip(
                  Icons.people_outline,
                  '${broadcast.recipientCount}',
                  'Recipients',
                ),
                SizedBox(width: 12.w),
                _buildStatChip(
                  Icons.check_circle_outline,
                  '${broadcast.deliveredCount}',
                  'Delivered',
                ),
                SizedBox(width: 12.w),
                _buildStatChip(
                  Icons.visibility_outlined,
                  '${broadcast.readCount}',
                  'Read',
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

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.w, color: Colors.grey[600]),
          SizedBox(width: 4.w),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
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
