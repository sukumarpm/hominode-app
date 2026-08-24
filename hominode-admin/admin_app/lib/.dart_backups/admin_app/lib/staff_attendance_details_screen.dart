import 'package:flutter/material.dart';
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

  Duration? _calculateDuration(dynamic entryTime, dynamic exitTime) {
    if (entryTime == null || exitTime == null) return null;
    try {
      final entry = entryTime.toDate();
      final exit = exitTime.toDate();
      return exit.difference(entry);
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
      case 'inside':
        return const Color(0xFF10B981);
      case 'exited':
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
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final attendanceRecords = snapshot.data ?? [];

          if (attendanceRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance records found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: attendanceRecords.length,
            itemBuilder: (context, index) {
              final record = attendanceRecords[index];
              final duration = _calculateDuration(
                record['entryTime'],
                record['exitTime'],
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTime(record['entryTime']).split(',')[0],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(record['status'] ?? 'unknown')
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              record['status']?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(record['status'] ?? 'unknown'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Entry Time
                      _buildTimeRow(
                        'Entry Time',
                        _formatTime(record['entryTime']),
                        Icons.login,
                      ),
                      const SizedBox(height: 8),

                      // Exit Time
                      if (record['exitTime'] != null)
                        _buildTimeRow(
                          'Exit Time',
                          _formatTime(record['exitTime']),
                          Icons.logout,
                        ),
                      if (record['exitTime'] != null) const SizedBox(height: 8),

                      // Duration
                      if (duration != null)
                        _buildTimeRow(
                          'Duration',
                          _formatDuration(duration),
                          Icons.schedule,
                        ),
                      if (duration != null) const SizedBox(height: 8),

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
                          const SizedBox(width: 8),
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
        Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
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
