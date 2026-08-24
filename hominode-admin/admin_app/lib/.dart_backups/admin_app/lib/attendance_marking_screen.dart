import 'package:flutter/material.dart';
import 'services/staff_vendor_service.dart';
import 'services/attendance_service.dart';
import 'security_staff_qr_scanner.dart';

class AttendanceMarkingScreen extends StatefulWidget {
  const AttendanceMarkingScreen({super.key});

  @override
  State<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _staffService = StaffVendorService();
  final AttendanceService _attendanceService = AttendanceService();
  String _searchQuery = '';
  String selectedFilter = 'All';

  final List<String> filters = ['All', 'Present', 'Absent', 'On Leave', 'Pending'];

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

  bool _matchesFilter(StaffMember staff) {
    if (selectedFilter == 'All') return true;
    if (selectedFilter == 'Present') return staff.status == 'present';
    if (selectedFilter == 'Absent') return staff.status == 'absent';
    if (selectedFilter == 'On Leave') return staff.status == 'onLeave';
    if (selectedFilter == 'Pending') return staff.status == 'pending';
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
                          'Mark Attendance',
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
                  // Quick Stats - Real-time from Firestore
                  FutureBuilder<AttendanceStats>(
                    future: _attendanceService.getTodayStats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          children: List.generate(3, (index) => Expanded(
                            child: Container(
                              height: 80,
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

                      final stats = snapshot.data ?? AttendanceStats(
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
                              'Present',
                              stats.present.toString(),
                              const Color(0xFF10B981),
                              Icons.check_circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickStatCard(
                              'Absent',
                              stats.absent.toString(),
                              const Color(0xFFEF4444),
                              Icons.cancel,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                  
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markAllPresent,
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Mark All Present'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openQRScanner,
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('Scan QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                  
                  // Staff List - Real-time from Firestore
                  StreamBuilder<List<StaffMember>>(
                    stream: _staffService.getStaffMembers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
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
                                  'Error loading staff',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    fontSize: 14,
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
                        final matchesSearch = _searchQuery.isEmpty ||
                            staff.name.toLowerCase().contains(_searchQuery) ||
                            staff.role.toLowerCase().contains(_searchQuery) ||
                            staff.phone.contains(_searchQuery);
                        
                        return matchesSearch && _matchesFilter(staff);
                      }).toList();

                      if (filteredStaff.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  _searchQuery.isEmpty ? Icons.people : Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? 'No staff members yet' : 'No staff found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Add staff members to mark attendance'
                                      : 'Try adjusting your search or filter',
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
                        children: filteredStaff.map((staff) {
                          return Column(
                            children: [
                              StaffMarkingCard(
                                staff: staff,
                                onStatusChanged: (newStatus) => _updateStaffStatus(staff, newStatus),
                              ),
                              const SizedBox(height: 12),
                            ],
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

  Widget _buildQuickStatCard(String title, String count, Color color, IconData icon) {
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
            count,
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
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _updateStaffStatus(StaffMember staff, String newStatus) async {
    try {
      // Mark attendance in Firestore
      if (newStatus == 'present') {
        await _attendanceService.markPresent(staff.id);
      } else if (newStatus == 'absent') {
        await _attendanceService.markAbsent(staff.id);
      } else if (newStatus == 'onLeave') {
        await _attendanceService.markOnLeave(staff.id);
      }

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name} marked as ${_getStatusText(newStatus)}'),
            backgroundColor: _getStatusColor(newStatus),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking attendance: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _markAllPresent() async {
    try {
      await _attendanceService.markAllPresent();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All staff marked as present'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking all present: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  void _openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecurityStaffQRScanner(),
      ),
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
  final Function(String) onStatusChanged;

  const StaffMarkingCard({
    super.key,
    required this.staff,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          // Staff Info Row
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(staff.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: _getStatusColor(staff.status),
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Staff Details
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
                    if (staff.lastCheckIn != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Checked in: ${staff.getCheckInTimeDisplay()}',
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
              
              // Current Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(staff.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  staff.getStatusDisplay(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(staff.status),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: staff.status == 'present' 
                      ? null 
                      : () => onStatusChanged('present'),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Present'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: staff.status == 'present' 
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: staff.status == 'absent' 
                      ? null 
                      : () => onStatusChanged('absent'),
                  icon: const Icon(Icons.cancel, size: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: staff.status == 'onLeave' 
                      ? null 
                      : () => onStatusChanged('onLeave'),
                  icon: const Icon(Icons.event_busy, size: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
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