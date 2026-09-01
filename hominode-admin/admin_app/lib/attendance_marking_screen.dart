import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/staff_vendor_service.dart';
import 'services/attendance_service.dart';
import 'security_staff_qr_scanner.dart';

class AttendanceMarkingScreen extends StatefulWidget {
  const AttendanceMarkingScreen({super.key});

  @override
  State<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _staffService = StaffVendorService();
  final AttendanceService _attendanceService = AttendanceService();
  String _searchQuery = '';
  String selectedFilter = 'All';

  final List<String> filters = ['All'];

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
                          'Mark Attendance',
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
                  // Quick Stats - Real-time from Firestore
                  FutureBuilder<AttendanceStats>(
                    future: _attendanceService.getTodayStats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          children: List.generate(
                            3,
                            (index) => Expanded(
                              child: Container(
                                height: 80.h,
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
                            child: _buildQuickStatCard(
                              'Checked In',
                              stats.present.toString(),
                              const Color(0xFF10B981),
                              Icons.check_circle,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildQuickStatCard(
                              'On Duty',
                              stats.currentlyOnDuty.toString(),
                              const Color(0xFF10B981),
                              Icons.schedule,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildQuickStatCard(
                              'Pending',
                              stats.pending.toString(),
                              const Color(0xFFF59E0B),
                              Icons.schedule,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 24.h),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: Icon(Icons.check_circle, size: 18.w),
                          label: const Text('Mark All Present'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openQRScanner,
                          icon: Icon(Icons.qr_code_2, size: 18.w),
                          label: const Text('Scan QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
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

                  // Staff List - Real-time from Firestore
                  StreamBuilder<List<StaffMember>>(
                    stream: _staffService.getSecurityStaffMembers(),
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
                                  'Error loading staff',
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

                      final staffList = snapshot.data ?? [];

                      // Filter staff based on search and filter
                      final filteredStaff = staffList.where((staff) {
                        final matchesSearch =
                            _searchQuery.isEmpty ||
                            staff.name.toLowerCase().contains(_searchQuery) ||
                            staff.role.toLowerCase().contains(_searchQuery) ||
                            staff.phone.contains(_searchQuery);

                        return matchesSearch;
                      }).toList();

                      if (filteredStaff.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.w),
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.people
                                      : Icons.search_off,
                                  size: 64.w,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No staff members yet'
                                      : 'No staff found',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Add staff members to mark attendance'
                                      : 'Try adjusting your search or filter',
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
                        children: filteredStaff.map((staff) {
                          return Column(
                            children: [
                              StaffMarkingCard(staff: staff),
                              SizedBox(height: 12.h),
                            ],
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

  Widget _buildQuickStatCard(
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
          Icon(icon, size: 20.w, color: color),
          SizedBox(height: 8.h),
          Text(
            count,
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
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecurityStaffQRScanner()),
    ).then((result) {
      if (result == true && mounted) {
        // Refresh the staff list after scanning
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff attendance marked via QR code'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }
}

class StaffMarkingCard extends StatelessWidget {
  final StaffMember staff;

  const StaffMarkingCard({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
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
          // Staff Info Row
          Row(
            children: [
              // Avatar
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: _getStatusColor(staff.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.person,
                  color: _getStatusColor(staff.status),
                  size: 24.w,
                ),
              ),

              SizedBox(width: 12.w),

              // Staff Details
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
                    if (staff.lastCheckIn != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Checked in: ${staff.getCheckInTimeDisplay()}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Current Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(staff.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  staff.getStatusDisplay(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(staff.status),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.check_circle, size: 16.w),
                  label: const Text('Present'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: staff.status == 'present'
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    textStyle: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.cancel, size: 16.w),
                  label: const Text('Absent'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: staff.status == 'absent'
                        ? const Color(0xFFEF4444).withOpacity(0.5)
                        : const Color(0xFFEF4444),
                    side: BorderSide(
                      color: staff.status == 'absent'
                          ? const Color(0xFFEF4444).withOpacity(0.5)
                          : const Color(0xFFEF4444),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    textStyle: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.event_busy, size: 16.w),
                  label: const Text('Leave'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: staff.status == 'onLeave'
                        ? const Color(0xFFF59E0B).withOpacity(0.5)
                        : const Color(0xFFF59E0B),
                    side: BorderSide(
                      color: staff.status == 'onLeave'
                          ? const Color(0xFFF59E0B).withOpacity(0.5)
                          : const Color(0xFFF59E0B),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    textStyle: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'onleave':
        return const Color(0xFFF59E0B);
      case 'offduty':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}
