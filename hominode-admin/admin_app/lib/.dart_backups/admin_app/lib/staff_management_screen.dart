import 'package:flutter/material.dart';
import 'services/staff_vendor_service.dart';
import 'widgets/add_staff_member_dialog.dart';
import 'widgets/standard_header.dart';
import 'staff_details_qr_fixed.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StaffVendorService _service = StaffVendorService();
  String _searchQuery = '';

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

  void _showAddStaffDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: const Color(0x59000000),
      builder: (BuildContext context) {
        return const AddStaffMemberDialog();
      },
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member added successfully'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _makePhoneCall(String phoneNumber, String staffName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $staffName at $phoneNumber...'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Cancel',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Widget _buildStaffCard(StaffMember staff) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffDetailsQRFixed(staffId: staff.id),
          ),
        );
      },
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
                color: _getRoleColor(staff.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getRoleIcon(staff.role),
                color: _getRoleColor(staff.role),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Details
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
                    '${staff.role} • ${staff.phone}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(staff.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
            const SizedBox(width: 8),
            // Call button
            IconButton(
              onPressed: () => _makePhoneCall(staff.phone, staff.name),
              icon: const Icon(
                Icons.phone,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
          ],
        ),
      ),
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
              title: 'Staff Management',
              subtitle: 'Manage your staff members',
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
                  // Summary Metrics Cards
                  StreamBuilder<List<StaffMember>>(
                    stream: _service.getStaffMembers(),
                    builder: (context, snapshot) {
                      final staffList = snapshot.data ?? [];
                      final totalStaff = staffList.length;
                      final presentStaff = staffList.where((s) => s.status == 'present').length;
                      final absentStaff = staffList.where((s) => s.status == 'absent').length;
                      final onLeaveStaff = staffList.where((s) => s.status == 'onLeave').length;
                      
                      return Row(
                        children: [
                          Expanded(
                            child: _StatsCard(
                              title: 'Total Staff',
                              value: totalStaff.toString(),
                              valueColor: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatsCard(
                              title: 'Present',
                              value: presentStaff.toString(),
                              valueColor: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatsCard(
                              title: 'Absent',
                              value: absentStaff.toString(),
                              valueColor: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatsCard(
                              title: 'On Leave',
                              value: onLeaveStaff.toString(),
                              valueColor: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add Staff Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _showAddStaffDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Add Staff Member',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, role, or phone...',
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
                  
                  // Staff List with StreamBuilder
                  StreamBuilder<List<StaffMember>>(
                    stream: _service.getStaffMembers(),
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
                      
                      // Filter staff based on search
                      final filteredStaff = _searchQuery.isEmpty
                          ? staffList
                          : staffList.where((staff) {
                              return staff.name.toLowerCase().contains(_searchQuery) ||
                                     staff.role.toLowerCase().contains(_searchQuery) ||
                                     staff.phone.contains(_searchQuery);
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
                                  _searchQuery.isEmpty ? 'No staff members added yet' : 'No staff found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isEmpty 
                                      ? 'Add your first staff member using the button above'
                                      : 'Try adjusting your search',
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
                              _buildStaffCard(staff),
                              const SizedBox(height: 16),
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
}

// Stats Card Widget
class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
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
