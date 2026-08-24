import 'package:flutter/material.dart';
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
        final matchesSearch = broadcast.title.toLowerCase().contains(query) ||
                             broadcast.content.toLowerCase().contains(query);
        
        final matchesFilter = selectedFilter == 'All' ||
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
              padding: const EdgeInsets.all(16),
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
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'This Month',
                          _getThisMonthCount().toString(),
                          Icons.calendar_month,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  
                  const SizedBox(height: 24),
                  
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((filter) {
                        final isSelected = selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
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
                            selectedColor: const Color(0xFF2563EB).withOpacity(0.1),
                            checkmarkColor: const Color(0xFF2563EB),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  Container(
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
                        hintText: 'Search messages by title or content...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Broadcast List
                  if (filteredBroadcasts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filter',
                              style: TextStyle(
                                fontSize: 14,
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
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                  
                  // Bottom padding for navigation
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
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
      return sum + (msg.deliveredCount > 0 ? (msg.readCount / msg.deliveredCount * 100) : 0.0);
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

  const BroadcastHistoryCard({
    super.key,
    required this.broadcast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getBroadcastTypeColor(broadcast.type),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    broadcast.type,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Content Preview
            Text(
              broadcast.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 16),
            
            // Stats Row
            Row(
              children: [
                _buildStatChip(
                  Icons.people_outline,
                  '${broadcast.recipientCount}',
                  'Recipients',
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.check_circle_outline,
                  '${broadcast.deliveredCount}',
                  'Delivered',
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.visibility_outlined,
                  '${broadcast.readCount}',
                  'Read',
                ),
                const Spacer(),
                Text(
                  _formatDateTime(broadcast.sentAt),
                  style: TextStyle(
                    fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
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
        return const Color(0xFF2563EB);
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