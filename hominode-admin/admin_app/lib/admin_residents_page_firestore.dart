/// Resident Management Screen for Admin App with Firestore Integration
///
/// Features:
/// - List all residents (role == "resident")
/// - Search and filter by building and flat
/// - Add new resident
/// - Edit resident details
/// - Activate/deactivate resident
/// - View resident profile
/// - Real-time updates with StreamBuilder
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'desktop/admin_desktop_page_frame.dart';

import 'edit_resident_screen.dart';
import 'pending_residents_screen.dart';
import 'resident_bulk_import_screen.dart';
import 'services/billing_service.dart';
import 'services/building_service.dart';
import 'services/resident_service.dart';
import 'services/user_service.dart';
import 'widgets/add_resident_modal_clean.dart';
import 'widgets/standard_bottom_nav.dart';
import 'widgets/standard_header.dart';

class AdminResidentsPageFirestore extends StatefulWidget {
  const AdminResidentsPageFirestore({super.key});

  @override
  State<AdminResidentsPageFirestore> createState() =>
      _AdminResidentsPageFirestoreState();
}

class _AdminResidentsPageFirestoreState
    extends State<AdminResidentsPageFirestore> {
  final UserService _userService = UserService();
  final ResidentService _residentService = ResidentService();
  final BuildingService _buildingService = BuildingService();
  final BillingService _billingService = BillingService();

  // Search and filter
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedBuilding;
  String? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter residents based on search and filters
  List<UserModel> _filterResidents(List<UserModel> residents) {
    return residents.where((resident) {
      // Search filter
      final matchesSearch =
          _searchQuery.isEmpty ||
          resident.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (resident.flatLabel?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false) ||
          resident.residentId.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      // Building filter (via flatLabel prefix)
      final matchesBuilding =
          _selectedBuilding == null ||
          _selectedBuilding == 'all' ||
          (resident.flatLabel?.startsWith(_selectedBuilding!) ?? false);

      // Status filter
      final matchesStatus =
          _selectedStatus == null ||
          _selectedStatus == 'all' ||
          resident.status == _selectedStatus;

      return matchesSearch && matchesBuilding && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'resident_list_title'.tr(),
        subtitle: 'resident_list_subtitle'.tr(),
        actions: [
          IconButton.outlined(
            tooltip: 'bulk_resident_import_title'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResidentBulkImportScreen(),
              ),
            ),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton.outlined(
            tooltip: 'resident_pending_title'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PendingResidentsScreen()),
            ),
            icon: const Icon(Icons.how_to_reg_outlined),
          ),
          AdminDesktopPrimaryAction(
            label: 'add_resident'.tr(),
            icon: Icons.person_add_outlined,
            onPressed: _showAddResidentDialog,
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              SizedBox(height: 12.h),
              _buildFilters(),
              SizedBox(height: 16.h),
              _buildResidentList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          StandardHeader(title: 'resident_management_title'.tr()),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(),
                SizedBox(height: 16.h),
                _buildSearchBar(),
                SizedBox(height: 12.h),
                _buildFilters(),
                SizedBox(height: 16.h),
                _buildResidentList(),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const StandardBottomNav(selectedIndex: 2),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'resident_management_title'.tr(),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111111),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              IconButton(
                tooltip: 'bulk_resident_import_title'.tr(),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResidentBulkImportScreen(),
                  ),
                ),
                icon: const Icon(
                  Icons.upload_file_outlined,
                  color: Color(0xFF0E4778),
                ),
              ),
              IconButton(
                tooltip: 'resident_pending_title'.tr(),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PendingResidentsScreen()),
                ),
                icon: const Icon(
                  Icons.how_to_reg_outlined,
                  color: Color(0xFF0E4778),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddResidentDialog,
                icon: Icon(Icons.add, size: 18.w),
                label: Text('add'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E4778),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(fontSize: 14.sp, color: Color(0xFF111111)),
        decoration: InputDecoration(
          hintText: 'resident_search_hint'.tr(),
          hintStyle: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20.w),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 12.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFF0E4778), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<List<BuildingModel>>(
              stream: _buildingService.getBuildings(),
              builder: (context, snapshot) {
                final buildings = snapshot.data ?? [];
                return _buildFilterDropdown(
                  label: 'building'.tr(),
                  value: _selectedBuilding,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('all_buildings'.tr()),
                    ),
                    ...buildings.map(
                      (b) => DropdownMenuItem(
                        value: b.name[0], // First letter for filtering
                        child: Text(b.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedBuilding = value),
                );
              },
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildFilterDropdown(
              label: 'status'.tr(),
              value: _selectedStatus,
              items: [
                DropdownMenuItem(value: 'all', child: Text('all_status'.tr())),
                DropdownMenuItem(
                  value: 'active',
                  child: Text('resident_status_active'.tr()),
                ),
                DropdownMenuItem(
                  value: 'inactive',
                  child: Text('resident_status_inactive'.tr()),
                ),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: TextStyle(fontSize: 14.sp)),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: TextStyle(fontSize: 14.sp, color: Color(0xFF111111)),
        ),
      ),
    );
  }

  Widget _buildResidentList() {
    return StreamBuilder<List<UserModel>>(
      stream: _userService.getUsers(),
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
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'resident_list_load_failed'.tr(
                      namedArgs: {'error': '${snapshot.error}'},
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14.sp),
                  ),
                ],
              ),
            ),
          );
        }

        final allResidents = snapshot.data ?? [];
        final filteredResidents = _filterResidents(allResidents);

        if (filteredResidents.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(32.w),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 56.w,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    _searchQuery.isNotEmpty ||
                            _selectedBuilding != null ||
                            _selectedStatus != null
                        ? 'resident_search_empty'.tr()
                        : 'resident_list_empty'.tr(),
                    style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: filteredResidents.map((resident) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _buildResidentCard(resident),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildResidentCard(UserModel resident) {
    final hasAssignment =
        resident.flatId?.trim().isNotEmpty == true &&
        resident.buildingId?.trim().isNotEmpty == true;
    final isActiveCurrent =
        resident.approvalStatus == 'approved' &&
        resident.isActive &&
        resident.status == 'active' &&
        resident.occupancyStatus == 'current' &&
        hasAssignment;
    final isSuspended =
        resident.approvalStatus == 'approved' &&
        !resident.isActive &&
        resident.status == 'inactive' &&
        resident.occupancyStatus == 'suspended' &&
        hasAssignment;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
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
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF0E4778),
                    size: 28.w,
                  ),
                ),
                SizedBox(width: 12.w),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resident.name,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          _buildStatusBadge(resident.status),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'resident_unit_and_member_count'.tr(
                          namedArgs: {
                            'unit':
                                resident.flatLabel ?? 'resident_no_unit'.tr(),
                            'count': '${resident.familyMembers}',
                          },
                        ),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'resident_id_format'.tr(
                          namedArgs: {'id': resident.residentId},
                        ),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        resident.phone,
                        style: TextStyle(
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
                    IconButton(
                      icon: Icon(Icons.visibility_outlined, size: 20.w),
                      color: const Color(0xFF6B7280),
                      onPressed: () => _showResidentProfile(resident),
                      tooltip: 'resident_view_profile'.tr(),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20.w),
                      color: const Color(0xFF6B7280),
                      onPressed: () => _showEditResidentDialog(resident),
                      tooltip: 'edit'.tr(),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20.w,
                        color: Color(0xFF6B7280),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'activate':
                            _toggleResidentStatus(resident, 'active');
                            break;

                          case 'deactivate':
                            _toggleResidentStatus(resident, 'inactive');
                            break;

                          case 'move_out':
                            _moveOutResident(resident);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (isSuspended)
                          PopupMenuItem(
                            value: 'activate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18.w,
                                  color: const Color(0xFF10B981),
                                ),
                                SizedBox(width: 8.w),
                                Text('resident_reactivate'.tr()),
                              ],
                            ),
                          ),

                        if (isActiveCurrent)
                          PopupMenuItem(
                            value: 'deactivate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 18.w,
                                  color: const Color(0xFFF4A100),
                                ),
                                SizedBox(width: 8.w),
                                Text('resident_deactivate'.tr()),
                              ],
                            ),
                          ),

                        if (isActiveCurrent)
                          PopupMenuItem(
                            value: 'move_out',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  size: 18.w,
                                  color: const Color(0xFFEF4444),
                                ),
                                SizedBox(width: 8.w),
                                Text('resident_move_out'.tr()),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        isActive
            ? 'resident_status_active'.tr()
            : 'resident_status_inactive'.tr(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
      ),
    );
  }

  // Action handlers
  void _showAddResidentDialog() async {
    await AddResidentModal.show(
      context,
      onSubmit: (residentData) async {
        try {
          // Show loading indicator
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text('resident_creating'.tr()),
                  ],
                ),
                backgroundColor: Color(0xFF0E4778),
                duration: Duration(seconds: 30),
              ),
            );
          }

          await _userService.createUser(
            name: residentData.fullName,
            phone: residentData.phone,
            email: residentData.email.isNotEmpty ? residentData.email : null,
            residentType: residentData.residentType,
            familyMembers: residentData.membersCount,
          );

          // Close loading snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF059669),
                        size: 24.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'resident_onboarding_created'.tr(),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'resident_onboarding_phone_message'.tr(
                        namedArgs: {'name': residentData.fullName},
                      ),
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFF0E4778)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: Color(0xFF0E4778),
                                size: 20.w,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'resident_otp_registration'.tr(),
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0E4778),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          _buildCredentialRow('phone'.tr(), residentData.phone),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16.w,
                                color: Color(0xFF0E4778),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Text(
                                  'resident_onboarding_instructions'.tr(),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Color(0xFF0E4778),
                                    fontStyle: FontStyle.italic,
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
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: 'resident_register_with_phone'.tr(
                            namedArgs: {'phone': residentData.phone},
                          ),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('resident_instructions_copied'.tr()),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 18.w),
                    label: Text('copy'.tr()),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4778),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                    ),
                    child: Text('done'.tr()),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          // Show error with user-friendly message
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();

            final errorMessage = ResidentService.errorMessage(e);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'dismiss'.tr(),
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  void _showEditResidentDialog(UserModel resident) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditResidentScreen(resident: resident),
      ),
    );

    if (result == true && mounted) {
      // Data will auto-refresh via StreamBuilder
      setState(() {});
    }
  }

  void _showResidentProfile(UserModel resident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResidentProfilePage(resident: resident),
      ),
    );
  }

  Future<void> _toggleResidentStatus(
    UserModel resident,
    String newStatus,
  ) async {
    try {
      if (newStatus == 'active') {
        await _residentService.reactivateResident(resident.id);
      } else {
        await _residentService.deactivateResident(resident.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${resident.name} ${newStatus == "active" ? "reactivated" : "deactivated"}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResidentService.errorMessage(e)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _moveOutResident(UserModel resident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('resident_move_out_title'.tr()),
        content: Text(
          'resident_move_out_confirmation'.tr(
            namedArgs: {'name': resident.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('resident_move_out'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // Trusted lifecycle callable:
      // - deactivates resident
      // - clears current assignment
      // - vacates the flat
      // - recalculates the building occupancy summary
      await _residentService.moveOutResident(resident.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'resident_move_out_success'.tr(
                namedArgs: {'name': resident.name},
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResidentService.errorMessage(error)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // Legacy hard-delete UI is intentionally retired; historical resident
  // documents are preserved by move-out.
  // ignore: unused_element
  Future<void> _deleteResident(UserModel resident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('resident_delete_title'.tr()),
        content: Text(
          'resident_delete_confirmation'.tr(namedArgs: {'name': resident.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(resident.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'resident_delete_success'.tr(
                  namedArgs: {'name': resident.name},
                ),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'resident_delete_failed'.tr(namedArgs: {'error': '$e'}),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

// Resident Profile Page
class ResidentProfilePage extends StatelessWidget {
  final UserModel resident;

  const ResidentProfilePage({super.key, required this.resident});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'resident_details_title'.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Profile Icon
                  Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(40.r),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 40.w,
                      color: Color(0xFF0E4778),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Name
                  Text(
                    resident.name,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 8.h),

                  // Resident ID
                  Text(
                    'resident_id_format'.tr(
                      namedArgs: {'id': resident.residentId},
                    ),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // Status Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: resident.status == 'active'
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      resident.status == 'active'
                          ? 'resident_status_active'.tr()
                          : 'resident_status_inactive'.tr(),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: resident.status == 'active'
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Personal Information
            _buildSection(
              context,
              title: 'personal_information'.tr(),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'phone'.tr(),
                    value: resident.phone,
                  ),
                  if (resident.email != null && resident.email!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'email'.tr(),
                      value: resident.email!,
                    ),
                  ],
                  const Divider(height: 24),
                  _buildInfoRow(
                    icon: Icons.people_outline,
                    label: 'family_members'.tr(),
                    value: '${resident.familyMembers}',
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Login Credentials
            _buildSection(
              context,
              title: 'login_credentials'.tr(),
              badge: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12.w, color: Color(0xFFF59E0B)),
                    SizedBox(width: 4.w),
                    Text(
                      'confidential'.tr(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildCopyableInfoRow(
                    context,
                    icon: Icons.fingerprint,
                    label: 'user_id'.tr(),
                    value: resident.id, // Firebase Auth UID
                  ),
                  if (resident.password != null &&
                      resident.password!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _buildCopyableInfoRow(
                      context,
                      icon: Icons.lock_outline,
                      label: 'password'.tr(),
                      value: resident.password!,
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Flat Information
            _buildSection(
              context,
              title: 'unit_information'.tr(),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.home_outlined,
                    label: 'unit'.tr(),
                    value: resident.flatLabel ?? 'unit_not_assigned'.tr(),
                  ),
                  if (resident.ownershipType != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.key_outlined,
                      label: 'ownership'.tr(),
                      value: resident.ownershipType!,
                    ),
                  ],
                  if (resident.flatId != null) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.tag,
                      label: 'unit_id'.tr(),
                      value: resident.flatId!,
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Billing & Payments
            _buildSection(
              context,
              title: 'Billing & Payments',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment history will be displayed here',
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Show payment history
                      },
                      icon: Icon(Icons.receipt_long, size: 18.w),
                      label: const Text('View Payment History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E4778),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    Widget? badge,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                if (badge != null) ...[const Spacer(), badge],
              ],
            ),
            SizedBox(height: 16.h),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: const Color(0xFF6B7280)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: const Color(0xFF6B7280)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, size: 18.w),
          color: const Color(0xFF0E4778),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'resident_copied_to_clipboard'.tr(
                    namedArgs: {'label': label},
                  ),
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  // Password row removed - passwords are managed by Firebase Auth
  // and are not stored in Firestore for security reasons
}
