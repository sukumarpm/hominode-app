import 'package:flutter/material.dart';
import 'widgets/standard_header.dart';

class MessageAnalyticsScreen extends StatefulWidget {
  const MessageAnalyticsScreen({super.key});

  @override
  State<MessageAnalyticsScreen> createState() => _MessageAnalyticsScreenState();
}

class _MessageAnalyticsScreenState extends State<MessageAnalyticsScreen> {
  String selectedPeriod = 'This Month';
  final List<String> periods = ['This Week', 'This Month', 'Last 3 Months', 'This Year'];

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
              title: 'Message Analytics',
              subtitle: 'Detailed communication insights',
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
                  // Period Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: periods.map((period) {
                        final isSelected = selectedPeriod == period;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedPeriod = period;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ] : null,
                              ),
                              child: Text(
                                period,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.black : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Overview Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Messages',
                          '156',
                          Icons.send_outlined,
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Delivery Rate',
                          '98.7%',
                          Icons.check_circle_outline,
                          const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Read Rate',
                          '87.3%',
                          Icons.visibility_outlined,
                          const Color(0xFFA855F7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Response Rate',
                          '23.1%',
                          Icons.reply_outlined,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Message Types Breakdown
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        const Text(
                          'Message Types',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildMessageTypeRow('Push Notifications', 89, const Color(0xFF2563EB)),
                        const SizedBox(height: 12),
                        _buildMessageTypeRow('Email Messages', 45, const Color(0xFF8B5CF6)),
                        const SizedBox(height: 12),
                        _buildMessageTypeRow('SMS Messages', 22, const Color(0xFF10B981)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Peak Hours Chart
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        const Text(
                          'Peak Activity Hours',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Simple bar chart representation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildHourBar('9AM', 0.3),
                            _buildHourBar('10AM', 0.7),
                            _buildHourBar('11AM', 0.9),
                            _buildHourBar('12PM', 1.0),
                            _buildHourBar('1PM', 0.8),
                            _buildHourBar('2PM', 0.6),
                            _buildHourBar('3PM', 0.4),
                            _buildHourBar('4PM', 0.5),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Recent Activity
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildActivityItem(
                          'Maintenance Bill Generated',
                          '245 delivered, 198 read',
                          '2 hours ago',
                          const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 12),
                        _buildActivityItem(
                          'Visitor Entry Alert',
                          '1 delivered, 1 read',
                          '4 hours ago',
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        _buildActivityItem(
                          'New Year Celebration',
                          '240 delivered, 180 read',
                          '1 day ago',
                          const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ),
                  
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTypeRow(String type, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            type,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHourBar(String hour, double height) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 80 * height,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hour,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String stats, String time, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stats,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}