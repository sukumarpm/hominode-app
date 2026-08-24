import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/standard_header.dart';

class MessageAnalyticsScreen extends StatefulWidget {
  const MessageAnalyticsScreen({super.key});

  @override
  State<MessageAnalyticsScreen> createState() => _MessageAnalyticsScreenState();
}

class _MessageAnalyticsScreenState extends State<MessageAnalyticsScreen> {
  String selectedPeriod = 'This Month';
  final List<String> periods = [
    'This Week',
    'This Month',
    'Last 3 Months',
    'This Year',
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
              title: 'Message Analytics',
              subtitle: 'Detailed communication insights',
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
                  // Period Selector
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12.r),
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
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
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
                                period,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Overview Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Messages',
                          '156',
                          Icons.send_outlined,
                          const Color(0xFF0E4778),
                        ),
                      ),
                      SizedBox(width: 12.w),
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

                  SizedBox(height: 12.h),

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
                      SizedBox(width: 12.w),
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

                  SizedBox(height: 24.h),

                  // Message Types Breakdown
                  Container(
                    padding: EdgeInsets.all(20.w),
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
                        Text(
                          'Message Types',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        _buildMessageTypeRow(
                          'Push Notifications',
                          89,
                          const Color(0xFF0E4778),
                        ),
                        SizedBox(height: 12.h),
                        _buildMessageTypeRow(
                          'Email Messages',
                          45,
                          const Color(0xFF8B5CF6),
                        ),
                        SizedBox(height: 12.h),
                        _buildMessageTypeRow(
                          'SMS Messages',
                          22,
                          const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Peak Hours Chart
                  Container(
                    padding: EdgeInsets.all(20.w),
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
                        Text(
                          'Peak Activity Hours',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 16.h),

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

                  SizedBox(height: 24.h),

                  // Recent Activity
                  Container(
                    padding: EdgeInsets.all(20.w),
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
                        Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        _buildActivityItem(
                          'Maintenance Bill Generated',
                          '245 delivered, 198 read',
                          '2 hours ago',
                          const Color(0xFF0E4778),
                        ),
                        SizedBox(height: 12.h),
                        _buildActivityItem(
                          'Visitor Entry Alert',
                          '1 delivered, 1 read',
                          '4 hours ago',
                          const Color(0xFF10B981),
                        ),
                        SizedBox(height: 12.h),
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
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
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

  Widget _buildMessageTypeRow(String type, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            type,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14.sp,
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
          width: 24.w,
          height: 80.h * height,
          decoration: BoxDecoration(
            color: const Color(0xFF0E4778),
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          hour,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String stats,
    String time,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                stats,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
