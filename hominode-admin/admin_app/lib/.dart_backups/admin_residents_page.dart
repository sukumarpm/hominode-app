import 'package:flutter_screenutil/flutter_screenutil.dart';
/// Resident Management Screen for Admin App
/// 
/// Integration: Add to MaterialApp routes:
/// '/residents': (context) => const AdminResidentsPage(),
/// 
/// Or use with bottom navigation as shown in the existing admin app structure.
library;

import 'package:flutter/material.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/standard_header.dart';
import 'widgets/add_resident_modal.dart' as modal;
import 'widgets/payment_history_dialog.dart';
import 'widgets/send_notice_dialog.dart';
import 'widgets/edit_resident_details_dialog.dart';
import 'models/payment_history_entry.dart';
import 'models/notice.dart';

// ============================================================================
// DATA MODEL
// ============================================================================

class ResidentModel {
  final String id;
  final String name;
  final String unit;
  final int members;
  final String phone;
  final bool hasDues;
  final double? duesAmount;
  final bool isPending;

  ResidentModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.members,
    required this.phone,
    this.hasDues = false,
    this.duesAmount,
    this.isPending = false,
  });
}

// ============================================================================
// MAIN PAGE
// ============================================================================

class AdminResidentsPage extends StatefulWidget {
  const AdminResidentsPage({super.key});

  @override
  State<AdminResidentsPage> createState() => _AdminResidentsPageState();
}

class _AdminResidentsPageState extends State<AdminResidentsPage> {
  // Tab selection: 0 = All Residents, 1 = Pending Request
  int _selectedTab = 0;
  
  // Search query
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Mock data
  final List<ResidentModel> _allResidents = [
    ResidentModel(
      id: '1',
      name: 'Rajesh Kumar',
      unit: 'A-204',
      members: 4,
      phone: '+91 98765 43210',
      hasDues: false,
      isPending: false,
    ),
    ResidentModel(
      id: '2',
      name: 'Rajesh Kumar',
      unit: 'A-204',
      members: 4,
      phone: '+91 98765 43210',
      hasDues: true,
      duesAmount: 3500,
      isPending: false,
    ),
    ResidentModel(
      id: '3',
      name: 'Rajesh Kumar',
      unit: 'A-204',
      members: 4,
      phone: '+91 98765 43210',
      hasDues: false,
      isPending: false,
    ),
    ResidentModel(
      id: '4',
      name: 'Priya Sharma',
      unit: 'B-101',
      members: 3,
      phone: '+91 98765 43211',
      hasDues: false,
      isPending: false,
    ),
    ResidentModel(
      id: '5',
      name: 'Amit Patel',
      unit: 'C-305',
      members: 5,
      phone: '+91 98765 43212',
      hasDues: true,
      duesAmount: 2000,
      isPending: false,
    ),
    // Pending requests (showing 3 for demo, but can be adjusted)
    ResidentModel(
      id: '6',
      name: 'Vikram Singh',
      unit: 'E-201',
      members: 4,
      phone: '+91 98765 43214',
      hasDues: false,
      isPending: true,
    ),
    ResidentModel(
      id: '7',
      name: 'Vikram Singh',
      unit: 'E-201',
      members: 4,
      phone: '+91 98765 43214',
      hasDues: false,
      isPending: true,
    ),
    ResidentModel(
      id: '8',
      name: 'Vikram Singh',
      unit: 'E-201',
      members: 4,
      phone: '+91 98765 43214',
      hasDues: false,
      isPending: true,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get filtered residents based on tab and search
  List<ResidentModel> get _filteredResidents {
    // Filter by tab
    List<ResidentModel> filtered = _selectedTab == 0
        ? _allResidents.where((r) => !r.isPending).toList()
        : _allResidents.where((r) => r.isPending).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(query) ||
            r.unit.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  int get _pendingCount {
    return _allResidents.where((r) => r.isPending).length;
  }

  // ============================================================================
  // ACTION HANDLERS
  // ============================================================================

  void _onAddResident() {
    modal.AddResidentModal.show(
      context,
      onSubmit: (resident) {
        setState(() {
          _allResidents.add(
            ResidentModel(
              id: resident.id,
              name: resident.fullName,
              unit: resident.unitNumber,
              members: resident.membersCount,
              phone: resident.phone,
              hasDues: false,
              isPending: false,
            ),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${resident.fullName} added successfully'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _onEditResident(ResidentModel resident) {
    // Convert to EditableResident
    final editableResident = EditableResident(
      id: resident.id,
      fullName: resident.name,
      unitNumber: resident.unit,
      phoneNumber: resident.phone,
      familyMembers: resident.members,
      vehicles: 0, // Default value, add to ResidentModel if needed
    );

    EditResidentDetailsDialog.show(
      context,
      resident: editableResident,
      onSaved: (updated) {
        setState(() {
          // Find and update the resident in the list
          final index = _allResidents.indexWhere((r) => r.id == resident.id);
          if (index != -1) {
            _allResidents[index] = ResidentModel(
              id: updated.id,
              name: updated.fullName,
              unit: updated.unitNumber,
              members: updated.familyMembers,
              phone: updated.phoneNumber,
              hasDues: resident.hasDues,
              duesAmount: resident.duesAmount,
              isPending: resident.isPending,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resident details updated'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _onDeleteResident(ResidentModel resident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resident'),
        content: Text('Are you sure you want to remove ${resident.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _allResidents.removeWhere((r) => r.id == resident.id);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${resident.name} removed'),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onPaymentHistory(ResidentModel resident) {
    // TODO: Load actual payment history from API
    final mockHistory = getMockPaymentHistory();

    PaymentHistoryDialog.show(
      context,
      residentName: resident.name,
      unitNumber: resident.unit,
      history: mockHistory,
    );
  }

  void _onSendNotice(ResidentModel resident) {
    SendNoticeDialog.show(
      context,
      residentName: resident.name,
      unitNumber: resident.unit,
      onSent: (notice) {
        // TODO: Add notice to local list or refresh from API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notice sent to ${resident.name}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _onApproveRequest(ResidentModel resident) async {
    // Simulate async API call
    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      // Remove from pending and add to all residents
      final index = _allResidents.indexWhere((r) => r.id == resident.id);
      if (index != -1) {
        _allResidents[index] = ResidentModel(
          id: resident.id,
          name: resident.name,
          unit: resident.unit,
          members: resident.members,
          phone: resident.phone,
          hasDues: false,
          isPending: false, // Mark as approved
        );
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request approved for ${resident.name}'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // TODO: Integrate with real API
    // - POST /api/residents/approve/{id}
    // - Move resident to active residents list
    // - Send welcome notification to resident
  }

  void _onRejectRequest(ResidentModel resident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text('Are you sure you want to reject the request from ${resident.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Simulate async API call
              await Future.delayed(const Duration(milliseconds: 700));

              setState(() {
                // Remove from list
                _allResidents.removeWhere((r) => r.id == resident.id);
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request rejected for ${resident.name}'),
                    backgroundColor: const Color(0xFFDC2626),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }

              // TODO: Integrate with real API
              // - POST /api/residents/reject/{id}
              // - Send rejection notification to applicant
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Resident Management'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(),
                const SizedBox(height: 12.h),
                _buildTabs(),
                const SizedBox(height: 12.h),
                _buildSearchBar(),
                const SizedBox(height: 12.h),
                _buildResidentList(),
                const SizedBox(height: 100.h), // Space for bottom nav
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(
        selectedIndex: 2, // Residents tab
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS
  // ============================================================================

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Row(
          children: [
            Semantics(
              label: 'Back',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8.r),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6.w),
            const Text(
              'Resident',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Resident Management',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          Semantics(
            label: 'Add new resident',
            button: true,
            child: InkWell(
              onTap: _onAddResident,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3.r),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                label: 'All Residents',
                isSelected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
            ),
            Expanded(
              child: _buildTabButton(
                label: 'Pending Request ($_pendingCount)',
                isSelected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF111111) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(
          fontSize: 14.sp,
          color: Color(0xFF111111),
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or unit....',
          hintStyle: const TextStyle(
            fontSize: 14.sp,
            color: Color(0xFF9CA3AF),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.w),
          ),
        ),
      ),
    );
  }

  Widget _buildResidentList() {
    final residents = _filteredResidents;

    if (residents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.r),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 56,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12.h),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No residents found'
                    : _selectedTab == 1
                        ? 'No pending requests'
                        : 'No residents yet',
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: residents.map((resident) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _selectedTab == 1
                ? _buildPendingRequestCard(resident)
                : _buildResidentCard(resident),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPendingRequestCard(ResidentModel resident) {
    return Semantics(
      label: 'Pending resident request for ${resident.name}, unit ${resident.unit}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 56.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F0FF),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF2563EB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12.w),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resident.name,
                          style: const TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 5.h),
                        Row(
                          children: [
                            const Icon(
                              Icons.home_outlined,
                              size: 14,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4.w),
                            Text(
                              resident.unit,
                              style: const TextStyle(
                                fontSize: 13.sp,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3.h),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4.w),
                            Text(
                              resident.phone,
                              style: const TextStyle(
                                fontSize: 13.sp,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5.h),
                        Text(
                          'Requested on 2025-10-30',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.h),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Approve resident request',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _onApproveRequest(resident),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.w),
                  Expanded(
                    child: Semantics(
                      label: 'Reject resident request',
                      button: true,
                      child: OutlinedButton(
                        onPressed: () => _onRejectRequest(resident),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626), width: 1.w),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidentCard(ResidentModel resident) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: Color(0xFF2563EB),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12.w),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resident.name,
                        style: const TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4.h),
                      Text(
                        '${resident.unit} • ${resident.members} members',
                        style: const TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2.h),
                      Text(
                        resident.phone,
                        style: const TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action icons
                Row(
                  children: [
                    Semantics(
                      label: 'Edit ${resident.name}',
                      button: true,
                      child: InkWell(
                        onTap: () => _onEditResident(resident),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8.r),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.w),
                    Semantics(
                      label: 'Delete ${resident.name}',
                      button: true,
                      child: InkWell(
                        onTap: () => _onDeleteResident(resident),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8.r),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFF05454),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Dues banner (conditional)
            if (resident.hasDues && resident.duesAmount != null) ...[
              const SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹ Dues : ₹${resident.duesAmount!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12.h),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'View payment history for ${resident.name}',
                    button: true,
                    child: OutlinedButton(
                      onPressed: () => _onPaymentHistory(resident),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.w),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10.w),
                Expanded(
                  child: Semantics(
                    label: 'Send notice to ${resident.name}',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () => _onSendNotice(resident),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text(
                        'Send Notice',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}

// ============================================================================
// PAYMENT HISTORY PAGE (Placeholder)
// ============================================================================

class PaymentHistoryPage extends StatelessWidget {
  final ResidentModel resident;

  const PaymentHistoryPage({
    super.key,
    required this.resident,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20.r),
                  bottomRight: Radius.circular(20.r),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8.r),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.w),
                    const Text(
                      'Payment History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.r),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 16.h),
                      Text(
                        'Payment History for',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8.h),
                      Text(
                        resident.name,
                        style: const TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4.h),
                      Text(
                        resident.unit,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24.h),
                      Text(
                        'TODO: Implement payment history list',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
