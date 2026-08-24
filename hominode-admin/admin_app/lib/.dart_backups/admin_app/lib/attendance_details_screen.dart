import 'package:flutter/material.dart';
import 'services/staff_vendor_service.dart';
import 'services/attendance_service.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final String date;

  const AttendanceDetailsScreen({
    super.key,
    required this.date,
  });

  @override
  State<AttendanceDetailsScreen> createState() => _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _staffService = StaffVendorService();
  final AttendanceService _attendanceService = AttendanceService();
  String _searchQuery = '';
  String selectedFilter = 'All';

  final List<String> filters = ['All', 'Present', 'Absent', 'On Leave'];

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
    if (selectedFilter == 'Present') return record.status == 'present';
    if (selectedFilter == 'Absent') return record.status == 'absent';
    if (selectedFilter == 'On Leave') return record.status == 'onLeave';
    return true;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'onLeave':
        return 'On Leave';
      case 'offDuty':
        return 'Off Duty';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'onLeave':
        return const Color(0xFFF59E0B);
      case 'offDuty':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'onLeave':
        return Icons.event_busy;
      case 'offDuty':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Attendance Details',
                          style: TextStyle(
                            fontSize: 20,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(widget.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Summary Cards - Real-time from Firestore
                  FutureBuilder<List<AttendanceRecord>>(
                    future: _attendanceService.getAttendanceByDate(widget.date),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          children: List.generate(4, (index) => Expanded(
                            child: Container(
                              height: 100,
                              margin: EdgeInsets.only(left: index > 0 ? 12 : 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          )),
                        );
                      }

                      final records = snapshot.data ?? [];
                      final presentCount = records.where((r) => r.status == 'present').length;
                      final absentCount = records.where((r) => r.status == 'absent').length;
                      final onLeaveCount = records.where((r) => r.status == 'onLeave').length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Present',
                                  presentCount.toString(),
                                  const Color(0xFF10B981),
                                  Icons.check_circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Absent',
                                  absentCount.toString(),
                                  const Color(0xFFEF4444),
                                  Icons.cancel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'On Leave',
                                  onLeaveCount.toString(),
                                  const Color(0xFFF59E0B),
                                  Icons.event_busy,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total',
                                  records.length.toString(),
                                  const Color(0xFF2563EB),
                                  Icons.people,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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
                        hintText: 'Search staff by name, role, or phone...',
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
                  
                  // Staff List with Attendance - Real-time from Firestore
                  FutureBuilder<List<AttendanceRecord>>(
                    future: _attendanceService.getAttendanceByDate(widget.date),
                    builder: (context, attendanceSnapshot) {
                      if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (attendanceSnapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading attendance',
                                  style: TextStyle(
                                    fontSize: 16,
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
                                  'No attendance records',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No attendance marked for this date',
                                  style: TextStyle(
                                    fontSize: 14,
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
                            future: _staffService.getStaffMemberById(record.staffId),
                            builder: (context, staffSnapshot) {
                              if (!staffSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final staff = staffSnapshot.data!;
                              
                              // Apply search filter
                              if (_searchQuery.isNotEmpty) {
                                final matchesSearch = staff.name.toLowerCase().contains(_searchQuery) ||
                                    staff.role.toLowerCase().contains(_searchQuery) ||
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
                                    onTap: () => _showStaffDetails(staff, record),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
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

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
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
            size: 24,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
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
      builder: (context) => StaffAttendanceDetailModal(staff: staff, record: record),
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
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: _getStatusColor(record.status),
                size: 24,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Staff Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    staff.role,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (record.checkInTime != null || record.checkOutTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _getTimeInfo(record),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(record.status),
                    size: 12,
                    color: _getStatusColor(record.status),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(record.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(record.status),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeInfo(AttendanceRecord record) {
    if (record.checkInTime != null && record.checkOutTime == null) {
      final hour = record.checkInTime!.hour.toString().padLeft(2, '0');
      final minute = record.checkInTime!.minute.toString().padLeft(2, '0');
      return 'In: $hour:$minute';
    } else if (record.checkInTime != null && record.checkOutTime != null) {
      final inHour = record.checkInTime!.hour.toString().padLeft(2, '0');
      final inMinute = record.checkInTime!.minute.toString().padLeft(2, '0');
      final outHour = record.checkOutTime!.hour.toString().padLeft(2, '0');
      final outMinute = record.checkOutTime!.minute.toString().padLeft(2, '0');
      return 'In: $inHour:$inMinute • Out: $outHour:$outMinute';
    } else if (record.checkOutTime != null) {
      final hour = record.checkOutTime!.hour.toString().padLeft(2, '0');
      final minute = record.checkOutTime!.minute.toString().padLeft(2, '0');
      return 'Out: $hour:$minute';
    }
    return '';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'onLeave':
        return 'On Leave';
      case 'offDuty':
        return 'Off Duty';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'onLeave':
        return const Color(0xFFF59E0B);
      case 'offDuty':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'onLeave':
        return Icons.event_busy;
      case 'offDuty':
        return Icons.schedule;
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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _getStatusColor(record.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.person,
                        color: _getStatusColor(record.status),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            staff.role,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(record.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(record.status),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Time Details
                if (record.checkInTime != null || record.checkOutTime != null) ...[
                  const Text(
                    'Time Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (record.checkInTime != null)
                    _buildTimeRow('Check In', _formatTime(record.checkInTime!), Icons.login),
                  
                  if (record.checkOutTime != null)
                    _buildTimeRow('Check Out', _formatTime(record.checkOutTime!), Icons.logout),
                  
                  const SizedBox(height: 20),
                ],
                
                // Contact Info
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow('Phone', staff.phone, Icons.phone_outlined),
                if (staff.email != null)
                  _buildInfoRow('Email', staff.email!, Icons.email_outlined),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.person, size: 18),
                        label: const Text('View Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 14,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
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
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'onLeave':
        return 'On Leave';
      case 'offDuty':
        return 'Off Duty';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF10B981);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'onLeave':
        return const Color(0xFFF59E0B);
      case 'offDuty':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}