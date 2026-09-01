import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'services/staff_qr_service.dart';

class StaffAttendanceDetailsScreen extends StatefulWidget {
  final String staffId;
  final String staffName;

  const StaffAttendanceDetailsScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffAttendanceDetailsScreen> createState() =>
      _StaffAttendanceDetailsScreenState();
}

class _StaffAttendanceDetailsScreenState
    extends State<StaffAttendanceDetailsScreen> {
  final StaffQRService _qrService = StaffQRService();
  late Future<List<Map<String, dynamic>>> _attendanceFuture;

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _qrService.getStaffAttendance(widget.staffId);
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = timestamp.toDate();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  Duration? _calculateDuration(dynamic checkInTime, dynamic checkOutTime) {
    if (checkInTime == null || checkOutTime == null) return null;
    try {
      final checkIn = checkInTime.toDate();
      final checkOut = checkOutTime.toDate();
      return checkOut.difference(checkIn);
    } catch (e) {
      return null;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours h $minutes m';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'checked_in':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.staffName} - Attendance'),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final attendanceRecords = snapshot.data ?? [];

          if (attendanceRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64.w,
                    color: const Color(0xFFE5E7EB),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No attendance records found',
                    style: TextStyle(fontSize: 16.sp, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: attendanceRecords.length,
            itemBuilder: (context, index) {
              final record = attendanceRecords[index];
              final duration = _calculateDuration(
                record['checkInTime'],
                record['checkOutTime'],
              );

              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTime(record['checkInTime']).split(',')[0],
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                record['status'] ?? 'unknown',
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              record['status']?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(
                                  record['status'] ?? 'unknown',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Entry Time
                      _buildTimeRow(
                        'Check In',
                        _formatTime(record['checkInTime']),
                        Icons.login,
                      ),
                      SizedBox(height: 8.h),

                      // Exit Time
                      if (record['checkOutTime'] != null)
                        _buildTimeRow(
                          'Check Out',
                          _formatTime(record['checkOutTime']),
                          Icons.logout,
                        ),
                      if (record['checkOutTime'] != null) SizedBox(height: 8.h),

                      // Duration
                      if (duration != null)
                        _buildTimeRow(
                          'Duration',
                          _formatDuration(duration),
                          Icons.schedule,
                        ),
                      if (duration != null) SizedBox(height: 8.h),

                      // Gate and Building
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              'Gate',
                              record['gateName'] ?? 'N/A',
                              Icons.location_on,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildInfoChip(
                              'Building',
                              record['buildingId'] ?? 'N/A',
                              Icons.apartment,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18.w, color: const Color(0xFF3B82F6)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12.sp, color: Color(0xFF6B7280)),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.w, color: const Color(0xFF6B7280)),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
