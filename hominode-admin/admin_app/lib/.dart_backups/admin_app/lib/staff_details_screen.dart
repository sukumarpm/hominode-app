import 'package:flutter/material.dart';
import 'services/staff_vendor_service.dart';
import 'services/attendance_service.dart';
import 'widgets/edit_staff_member_dialog.dart';
import 'widgets/delete_confirmation_dialog.dart';

class StaffDetailsScreen extends StatefulWidget {
  final String staffId;

  const StaffDetailsScreen({
    super.key,
    required this.staffId,
  });

  @override
  State<StaffDetailsScreen> createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends State<StaffDetailsScreen> {
  final StaffVendorService _service = StaffVendorService();
  final AttendanceService _attendanceService = AttendanceService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffMember?>(
      future: _service.getStaffMemberById(widget.staffId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Staff Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading staff details',
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

        final staff = snapshot.data!;
        return _buildStaffDetails(staff);
      },
    );
  }

  Widget _buildStaffDetails(StaffMember staff) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Staff Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF2563EB)),
            onPressed: () => _handleEdit(staff),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            onPressed: () => _handleDelete(staff),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getRoleColor(staff.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      _getRoleIcon(staff.role),
                      size: 40,
                      color: _getRoleColor(staff.role),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(staff.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      staff.role,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(staff.role),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(staff.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      staff.getStatusDisplay(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(staff.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Contact Information
            _buildSection(
              title: 'Contact Information',
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: staff.phone,
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: Color(0xFF2563EB)),
                      onPressed: () => _makePhoneCall(staff.phone),
                    ),
                  ),
                  if (staff.email != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: staff.email!,
                    ),
                  ],
                  if (staff.address != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: staff.address!,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Employment Details
            _buildSection(
              title: 'Employment Details',
              child: Column(
                children: [
                  if (staff.joiningDate != null) ...[
                    _buildInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Joining Date',
                      value: _formatDate(staff.joiningDate!),
                    ),
                    const Divider(height: 24),
                  ],
                  if (staff.salary != null) ...[
                    _buildInfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Monthly Salary',
                      value: '₹${staff.salary!.toStringAsFixed(0)}',
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Attendance Summary (Last 30 days)
            FutureBuilder<StaffAttendanceStats>(
              future: _attendanceService.getStaffAttendanceStats(staff.id, days: 30),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final stats = snapshot.data!;
                
                return _buildSection(
                  title: 'Attendance Summary (Last 30 Days)',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttendanceStatCard(
                              'Present',
                              stats.present.toString(),
                              const Color(0xFF10B981),
                              Icons.check_circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAttendanceStatCard(
                              'Absent',
                              stats.absent.toString(),
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
                            child: _buildAttendanceStatCard(
                              'On Leave',
                              stats.onLeave.toString(),
                              const Color(0xFFF59E0B),
                              Icons.event_busy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAttendanceStatCard(
                              'Attendance',
                              '${stats.attendancePercentage.toStringAsFixed(1)}%',
                              const Color(0xFF2563EB),
                              Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            // Attendance Summary (if available)
            if (staff.lastCheckIn != null || staff.lastCheckOut != null) ...[
              _buildSection(
                title: 'Today\'s Attendance',
                child: Column(
                  children: [
                    if (staff.lastCheckIn != null) ...[
                      _buildInfoRow(
                        icon: Icons.login,
                        label: 'Check In',
                        value: staff.getCheckInTimeDisplay() ?? 'N/A',
                        valueColor: const Color(0xFF10B981),
                      ),
                    ],
                    if (staff.lastCheckOut != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        icon: Icons.logout,
                        label: 'Check Out',
                        value: staff.getCheckOutTimeDisplay() ?? 'N/A',
                        valueColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAttendanceStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'security':
        return Icons.security;
      case 'housekeeping':
        return Icons.cleaning_services;
      case 'electrician':
        return Icons.electrical_services;
      case 'plumber':
        return Icons.plumbing;
      case 'gardener':
        return Icons.yard;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'security':
        return const Color(0xFF2563EB);
      case 'housekeeping':
        return const Color(0xFF10B981);
      case 'electrician':
        return const Color(0xFFF59E0B);
      case 'plumber':
        return const Color(0xFF3B82F6);
      case 'gardener':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF6B7280);
    }
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $phoneNumber...'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  Future<void> _handleEdit(StaffMember staff) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditStaffMemberDialog(staff: staff),
    );

    if (result == true) {
      // Refresh staff data by rebuilding the FutureBuilder
      setState(() {});
    }
  }

  Future<void> _handleDelete(StaffMember staff) async {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Staff Member',
        message: 'Are you sure you want to delete this staff member? This action cannot be undone.',
        itemName: staff.name,
        confirmButtonText: 'Delete Staff',
        requireReason: true,
        onConfirm: () async {
          try {
            await _service.deleteStaffMember(staff.id);
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Go back to staff list
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Staff member deleted successfully'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
          } catch (e) {
            Navigator.of(context).pop(); // Close dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting staff member: $e'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        },
      ),
    );
  }
}
