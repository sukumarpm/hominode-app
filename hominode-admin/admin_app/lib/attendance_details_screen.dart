import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'services/attendance_service.dart';
import 'services/staff_vendor_service.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final String date;

  const AttendanceDetailsScreen({super.key, required this.date});

  @override
  State<AttendanceDetailsScreen> createState() =>
      _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _staffService = StaffVendorService();
  final AttendanceService _attendanceService = AttendanceService();
  String _searchQuery = '';
  String selectedFilter = 'All';

  final List<String> filters = ['All', 'Checked In', 'Completed'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(AttendanceRecord record) {
    if (selectedFilter == 'All') return true;
    if (selectedFilter == 'Checked In') return record.isCurrentlyOnDuty;
    if (selectedFilter == 'Completed') return record.isCompleted;
    return true;
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
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E4778), Color(0xFF061C4C)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20.r),
                  bottomRight: Radius.circular(20.r),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20.w,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Text(
                          'Attendance Details',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Display
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Color(0xFF0E4778),
                          size: 20.w,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          _formatDate(widget.date),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Summary Cards - Real-time from Firestore
                  FutureBuilder<List<AttendanceRecord>>(
                    future: _attendanceService.getAttendanceByDate(widget.date),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          children: List.generate(
                            4,
                            (index) => Expanded(
                              child: Container(
                                height: 100.h,
                                margin: EdgeInsets.only(
                                  left: index > 0 ? 12 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
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

                      if (snapshot.hasError) {
                        return Text(
                          'Error loading attendance: ${snapshot.error}',
                        );
                      }

                      final records = snapshot.data ?? [];
                      final checkedInCount = records.length;

                      final onDutyCount = records
                          .where((record) => record.isCurrentlyOnDuty)
                          .length;

                      final completedCount = records
                          .where((record) => record.isCompleted)
                          .length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Checked In',
                                  checkedInCount.toString(),
                                  const Color(0xFF10B981),
                                  Icons.check_circle,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Completed',
                                  completedCount.toString(),
                                  const Color(0xFF3B82F6),
                                  Icons.logout,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'On Duty',
                                  onDutyCount.toString(),
                                  const Color(0xFF10B981),
                                  Icons.schedule,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total',
                                  records.length.toString(),
                                  const Color(0xFF0E4778),
                                  Icons.people,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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
                        hintText: 'Search staff by name, role, or phone...',
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

                  // Staff List with Attendance - Real-time from Firestore
                  FutureBuilder<List<AttendanceRecord>>(
                    future: _attendanceService.getAttendanceByDate(widget.date),
                    builder: (context, attendanceSnapshot) {
                      if (attendanceSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0.w),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (attendanceSnapshot.hasError) {
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
                              ],
                            ),
                          ),
                        );
                      }

                      final attendanceRecords = attendanceSnapshot.data ?? [];

                      // Filter by search and filter
                      final filteredRecords = attendanceRecords.where((record) {
                        return _matchesFilter(record);
                      }).toList();

                      if (filteredRecords.isEmpty) {
                        return Center(
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
                                  'No attendance records',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'No attendance marked for this date',
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
                        children: filteredRecords.map((record) {
                          return FutureBuilder<StaffMember?>(
                            future: _staffService.getSecurityStaffMemberById(
                              record.staffId,
                            ),
                            builder: (context, staffSnapshot) {
                              if (staffSnapshot.hasError) {
                                return Text(
                                  'Error loading staff profile: '
                                  '${staffSnapshot.error}',
                                );
                              }

                              if (!staffSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final staff = staffSnapshot.data!;

                              // Apply search filter
                              if (_searchQuery.isNotEmpty) {
                                final matchesSearch =
                                    staff.name.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    staff.role.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    staff.phone.contains(_searchQuery);
                                if (!matchesSearch) {
                                  return const SizedBox.shrink();
                                }
                              }

                              return Column(
                                children: [
                                  StaffAttendanceCard(
                                    staff: staff,
                                    record: record,
                                    onTap: () =>
                                        _showStaffDetails(staff, record),
                                  ),
                                  SizedBox(height: 12.h),
                                ],
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
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

  Widget _buildSummaryCard(
    String title,
    String count,
    Color color,
    IconData icon,
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
          Icon(icon, size: 24.w, color: color),
          SizedBox(height: 8.h),
          Text(
            count,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showStaffDetails(StaffMember staff, AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StaffAttendanceDetailModal(staff: staff, record: record),
    );
  }
}

class StaffAttendanceCard extends StatelessWidget {
  final StaffMember staff;
  final AttendanceRecord record;
  final VoidCallback? onTap;

  const StaffAttendanceCard({
    super.key,
    required this.staff,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.person,
                color: _getStatusColor(record.status),
                size: 24.w,
              ),
            ),

            SizedBox(width: 12.w),

            // Staff Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    staff.role,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _getTimeInfo(record),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(record.status),
                    size: 12.w,
                    color: _getStatusColor(record.status),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _getStatusText(record.status),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(record.status),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 8.w),

            Icon(Icons.chevron_right, size: 20.w, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _getTimeInfo(AttendanceRecord record) {
    if (record.checkOutTime == null) {
      final hour = record.checkInTime.hour.toString().padLeft(2, '0');
      final minute = record.checkInTime.minute.toString().padLeft(2, '0');
      return 'In: $hour:$minute';
    } else {
      final inHour = record.checkInTime.hour.toString().padLeft(2, '0');
      final inMinute = record.checkInTime.minute.toString().padLeft(2, '0');
      final outHour = record.checkOutTime!.hour.toString().padLeft(2, '0');
      final outMinute = record.checkOutTime!.minute.toString().padLeft(2, '0');
      return 'In: $inHour:$inMinute • Out: $outHour:$outMinute';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'checked_in':
        return 'Checked In';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'checked_in':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'checked_in':
        return Icons.check_circle;
      case 'completed':
        return Icons.logout;
      default:
        return Icons.help_outline;
    }
  }
}

class StaffAttendanceDetailModal extends StatelessWidget {
  final StaffMember staff;
  final AttendanceRecord record;

  const StaffAttendanceDetailModal({
    super.key,
    required this.staff,
    required this.record,
  });

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
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: _getStatusColor(record.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        Icons.person,
                        color: _getStatusColor(record.status),
                        size: 28.w,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            staff.role,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _getStatusText(record.status),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(record.status),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // Time Details
                Text(
                  'Time Details',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12.h),

                _buildTimeRow(
                  'Check In',
                  _formatTime(record.checkInTime),
                  Icons.login,
                ),

                if (record.checkOutTime != null)
                  _buildTimeRow(
                    'Check Out',
                    _formatTime(record.checkOutTime!),
                    Icons.logout,
                  ),

                SizedBox(height: 20.h),

                // Contact Info
                Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12.h),

                _buildInfoRow('Phone', staff.phone, Icons.phone_outlined),
                if (staff.email != null)
                  _buildInfoRow('Email', staff.email!, Icons.email_outlined),

                SizedBox(height: 24.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.phone, size: 18.w),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0E4778),
                          side: const BorderSide(color: Color(0xFF0E4778)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.person, size: 18.w),
                        label: const Text('View Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E4778),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildTimeRow(String label, String time, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 16.w, color: Colors.grey[600]),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 16.w, color: Colors.grey[600]),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'checked_in':
        return 'Checked In';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'checked_in':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}
