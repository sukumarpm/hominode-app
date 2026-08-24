import 'package:flutter/material.dart';
import 'widgets/add_staff_member_dialog.dart';
import 'widgets/standard_header.dart';
import 'services/staff_vendor_service.dart';
import 'models/staff_models.dart' as models;
import 'staff_details_qr_fixed.dart';

class StaffVendorManagementScreen extends StatefulWidget {
  const StaffVendorManagementScreen({super.key});

  @override
  State<StaffVendorManagementScreen> createState() => _StaffVendorManagementScreenState();
}

class _StaffVendorManagementScreenState extends State<StaffVendorManagementScreen> {
  final StaffVendorService _staffService = StaffVendorService();
  final TextEditingController _searchController = TextEditingController();
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
      barrierColor: const Color(0x40000000), // Semi-transparent black background
      builder: (BuildContext context) {
        return const AddStaffMemberDialog();
      },
    ).then((result) {
      if (result == true) {
        // No need to manually refresh - StreamBuilder handles it automatically
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

  void _navigateToStaffDetails(StaffMember firestoreStaff) {
    // Convert Firestore model to old model for details screen
    final oldModelStaff = models.StaffMember(
      id: firestoreStaff.id,
      name: firestoreStaff.name,
      role: firestoreStaff.role,
      phone: firestoreStaff.phone,
      email: firestoreStaff.email ?? 'Not provided',
      shift: 'Not Set', // Default value - can be added to Firestore model later
      checkedIn: firestoreStaff.getCheckInTimeDisplay(),
      checkedOut: firestoreStaff.getCheckOutTimeDisplay(),
      salary: firestoreStaff.salary != null ? '₹${firestoreStaff.salary!.toStringAsFixed(0)}/month' : 'Not Set',
      status: _convertStatus(firestoreStaff.status),
      joinDate: firestoreStaff.joiningDate ?? DateTime.now(),
      address: firestoreStaff.address ?? 'Not provided',
      emergencyContact: 'Not Set', // Can be added to Firestore model later
      emergencyContactPhone: 'Not Set', // Can be added to Firestore model later
      skills: [], // Can be added to Firestore model later
      rating: 0.0, // Can be added to Firestore model later
      totalTasks: 0, // Can be added to Firestore model later
      completedTasks: 0, // Can be added to Firestore model later
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffDetailsQRFixed(staffId: firestoreStaff.id),
      ),
    );
  }

  models.StaffStatus _convertStatus(String status) {
    switch (status) {
      case 'present':
        return models.StaffStatus.present;
      case 'absent':
        return models.StaffStatus.absent;
      case 'onLeave':
        return models.StaffStatus.onLeave;
      case 'offDuty':
        return models.StaffStatus.offDuty;
      case 'pending':
      default:
        return models.StaffStatus.offDuty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(
            title: 'Staff Management',
            showBackButton: true,
          ),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Header Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.people,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manage staff members',
                              style: TextStyle(
                                fontSize: 14,
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
                
                const SizedBox(height: 20),
                
                // Add Staff Member Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _showAddStaffDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                ),
                
                const SizedBox(height: 16),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
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
                ),
                
                const SizedBox(height: 20),
                
                // Staff List - Real-time from Firestore
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StreamBuilder<List<StaffMember>>(
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

                      final staffMembers = snapshot.data ?? [];
                      
                      // Filter staff based on search
                      final filteredStaff = _searchQuery.isEmpty
                          ? staffMembers
                          : staffMembers.where((staff) {
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
                                  _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
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
                        children: filteredStaff.asMap().entries.map((entry) {
                          final index = entry.key;
                          final staff = entry.value;
                          return Column(
                            children: [
                              if (index > 0) const SizedBox(height: 12),
                              StaffListItem(
                                staffMember: staff,
                                onTap: () => _navigateToStaffDetails(staff),
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 80), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Staff List Item Widget
class StaffListItem extends StatelessWidget {
  final StaffMember staffMember;
  final VoidCallback? onTap;

  const StaffListItem({
    super.key,
    required this.staffMember,
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
            // Header Row
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Name and Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffMember.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        staffMember.role,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                _buildStatusBadge(staffMember.status),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Details
            Column(
              children: [
                _buildDetailRow('Phone:', staffMember.phone),
                if (staffMember.salary != null) ...[
                  const SizedBox(height: 4),
                  _buildDetailRow('Salary:', '₹${staffMember.salary!.toStringAsFixed(0)}/month'),
                ],
                if (staffMember.getCheckInTimeDisplay() != null) ...[
                  const SizedBox(height: 4),
                  _buildDetailRow('Checked in:', staffMember.getCheckInTimeDisplay()!),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Bottom Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  staffMember.joiningDate != null
                      ? 'Joined: ${_formatDate(staffMember.joiningDate!)}'
                      : 'New Staff',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                GestureDetector(
                  onTap: onTap,
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String text;
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'present':
        text = 'Present';
        backgroundColor = const Color(0xFF16A34A);
        textColor = Colors.white;
        break;
      case 'absent':
        text = 'Absent';
        backgroundColor = const Color(0xFFDC2626);
        textColor = Colors.white;
        break;
      case 'offDuty':
        text = 'Off Duty';
        backgroundColor = const Color(0xFF6B7280);
        textColor = Colors.white;
        break;
      case 'onLeave':
        text = 'On Leave';
        backgroundColor = const Color(0xFF7C3AED);
        textColor = Colors.white;
        break;
      case 'pending':
      default:
        text = 'Pending';
        backgroundColor = const Color(0xFFF59E0B);
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}