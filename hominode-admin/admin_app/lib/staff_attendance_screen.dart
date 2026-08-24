import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/standard_header.dart';
import 'widgets/quick_broadcast_modal.dart';
import 'attendance_details_screen.dart';
import 'attendance_marking_screen.dart';
import 'services/attendance_service.dart';
import 'services/admin_service.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AttendanceService _attendanceService = AttendanceService();
  final AdminService _adminService = AdminService();
  String _searchQuery = '';
  bool _isInitialized = false;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      print('🔵 ATTENDANCE SCREEN: Starting initialization...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      _adminId = user.uid;
      print('✅ STEP 1 PASSED: Admin authenticated - $_adminId');

      // STEP 2: Validate Admin Access
      print('📋 STEP 2: Validating admin access...');
      final adminProfile = await _adminService.getAdminProfile();
      if (adminProfile == null) {
        throw Exception('Admin profile not found');
      }
      print('✅ STEP 2 PASSED: Admin access validated');

      // STEP 3: Initialize Data Streams
      print('🔄 STEP 3: Initializing data streams...');
      // Streams are initialized in build method via StreamBuilder
      print('✅ STEP 3 PASSED: Data streams ready');

      // STEP 4: Update UI State
      print('🔔 STEP 4: Updating UI state...');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      print('✅ STEP 4 PASSED: UI state updated');
      print('✅ ATTENDANCE SCREEN: Initialization COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing attendance: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickBroadcast() {
    showDialog(
      context: context,
      barrierColor: const Color(0x59000000),
      builder: (BuildContext context) {
        return const QuickBroadcastModal();
      },
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast sent successfully to all staff members'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Staff Attendance', showBackButton: true),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),

                // Header Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E4778).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF0E4778),
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Attendance',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Track and manage attendance',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // Summary Metrics Cards - Real-time from Firestore
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: FutureBuilder<AttendanceStats>(
                    future: _attendanceService.getTodayStats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          children: List.generate(
                            4,
                            (index) => Expanded(
                              child: Container(
                                height: 80.h,
                                margin: EdgeInsets.only(
                                  left: index > 0 ? 12 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final stats =
                          snapshot.data ??
                          AttendanceStats(
                            totalStaff: 0,
                            present: 0,
                            absent: 0,
                            onLeave: 0,
                            pending: 0,
                          );

                      return Row(
                        children: [
                          Expanded(
                            child: TopMetricCard(
                              title: 'Total Staff',
                              value: stats.totalStaff.toString(),
                              valueColor: const Color(0xFF0E4778),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: TopMetricCard(
                              title: 'Present Today',
                              value: stats.present.toString(),
                              valueColor: const Color(0xFF10B981),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: TopMetricCard(
                              title: 'Absent',
                              value: stats.absent.toString(),
                              valueColor: const Color(0xFFF59E0B),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: TopMetricCard(
                              title: 'On Leave',
                              value: stats.onLeave.toString(),
                              valueColor: const Color(0xFF9333EA),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                SizedBox(height: 20.h),

                // Quick Broadcast Card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: FutureBuilder<AttendanceStats>(
                    future: _attendanceService.getTodayStats(),
                    builder: (context, snapshot) {
                      final stats =
                          snapshot.data ??
                          AttendanceStats(
                            totalStaff: 0,
                            present: 0,
                            absent: 0,
                            onLeave: 0,
                            pending: 0,
                          );

                      final percentage = stats.totalStaff > 0
                          ? ((stats.present / stats.totalStaff) * 100).round()
                          : 0;

                      return GestureDetector(
                        onTap: _showQuickBroadcast,
                        child: Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0E4778).withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick Broadcast',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Send instant notification to all staff',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${stats.present} / ${stats.totalStaff}',
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 16.h),

                // Search Bar
                Padding(
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
                        hintText: 'Search attendance by date...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                          size: 20.w,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
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

                SizedBox(height: 20.h),

                // Attendance History List - Real-time from Firestore
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: StreamBuilder<List<DailyAttendanceSummary>>(
                    stream: _attendanceService.getAttendanceHistory(days: 30),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0.w),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0.w),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64.w,
                                  color: Color(0xFFEF4444),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Error loading attendance',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final summaries = snapshot.data ?? [];

                      // Filter by search query
                      final filteredSummaries = _searchQuery.isEmpty
                          ? summaries
                          : summaries.where((summary) {
                              return summary.date.toLowerCase().contains(
                                _searchQuery,
                              );
                            }).toList();

                      if (filteredSummaries.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.w),
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.calendar_today
                                      : Icons.search_off,
                                  size: 64.w,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No attendance records yet'
                                      : 'No attendance records found',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Start marking attendance to see history'
                                      : 'Try adjusting your search',
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
                        children: filteredSummaries.asMap().entries.map((
                          entry,
                        ) {
                          final index = entry.key;
                          final summary = entry.value;
                          return Column(
                            children: [
                              if (index > 0) SizedBox(height: 16.h),
                              DateAttendanceSection(
                                date: summary.date,
                                present: summary.present,
                                absent: summary.absent,
                                onLeave: summary.onLeave,
                                total: summary.totalStaff,
                                percentage: summary.attendancePercentage,
                                onTap: () =>
                                    _showAttendanceDetails(summary.date),
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                SizedBox(height: 80.h),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AttendanceMarkingScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF0E4778),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Mark Attendance'),
      ),
    );
  }

  void _showAttendanceDetails(String date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceDetailsScreen(date: date),
      ),
    );
  }
}

class TopMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const TopMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.h,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Date Attendance Section Widget
class DateAttendanceSection extends StatelessWidget {
  final String date;
  final int present;
  final int absent;
  final int onLeave;
  final int total;
  final double percentage;
  final VoidCallback? onTap;

  const DateAttendanceSection({
    super.key,
    required this.date,
    required this.present,
    required this.absent,
    required this.onLeave,
    required this.total,
    required this.percentage,
    this.onTap,
  });

  Color _getBadgeColor() {
    if (percentage == 100) {
      return const Color(0xFF22C55E); // Green for 100%
    } else if (percentage >= 80) {
      return const Color(0xFFF59E0B); // Orange for 80-99%
    } else {
      return const Color(0xFFEF4444); // Red for <80%
    }
  }

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
          children: [
            // Date Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16.w,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getBadgeColor(),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '$present / $total',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.chevron_right,
                        size: 20.w,
                        color: Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Attendance Summary Cards
            Row(
              children: [
                Expanded(
                  child: AttendanceSummaryCard(
                    value: present.toString(),
                    label: 'Present',
                    valueColor: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AttendanceSummaryCard(
                    value: absent.toString(),
                    label: 'Absent',
                    valueColor: const Color(0xFFEF4444),
                    icon: Icons.cancel_outlined,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AttendanceSummaryCard(
                    value: onLeave.toString(),
                    label: 'On Leave',
                    valueColor: const Color(0xFF9333EA),
                    icon: Icons.event_busy_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

// Attendance Summary Card Widget
class AttendanceSummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final IconData? icon;

  const AttendanceSummaryCard({
    super.key,
    required this.value,
    required this.label,
    required this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: valueColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: valueColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20.w, color: valueColor),
            SizedBox(height: 8.h),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: valueColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
