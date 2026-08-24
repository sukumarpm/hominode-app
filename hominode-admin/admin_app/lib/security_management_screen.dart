import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'security_details_screen.dart';
import 'services/gate_service.dart';
import 'services/security_service.dart';
import 'widgets/add_gate_modal.dart';
import 'widgets/edit_gate_modal.dart';

class SecurityManagementScreen extends StatefulWidget {
  const SecurityManagementScreen({super.key});

  @override
  State<SecurityManagementScreen> createState() =>
      _SecurityManagementScreenState();
}

class _SecurityManagementScreenState extends State<SecurityManagementScreen> {
  final SecurityService _securityService = SecurityService();
  final GateService _gateService = GateService();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // For segmented control

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Security Management',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16.h, bottom: 12.h),
                      child: _buildPageHeader(),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 14.h),
                      child: _buildSegmentedControl(),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 14.h),
                      child: _buildPlacesSection(),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 14.h),
                      child: _buildSearchBar(),
                    ),
                  ),

                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: _buildSecurityList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSecurityDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final securityIdController = TextEditingController();
    final shiftController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    var submitting = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                setDialogState(() {
                  submitting = true;
                });

                try {
                  await _securityService.createSecurityStaff(
                    name: nameController.text,
                    phoneNumber: phoneController.text,
                    securityId: securityIdController.text,
                    shift: shiftController.text,
                  );

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Security staff added successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  setDialogState(() {
                    submitting = false;
                  });

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(_securityProvisioningMessage(error)),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                title: const Text('Add Security Staff'),
                content: SizedBox(
                  width: 440,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'The security staff member will sign in using OTP. '
                            'No password is created or stored.',
                          ),
                          SizedBox(height: 20.h),
                          TextFormField(
                            controller: nameController,
                            enabled: !submitting,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter the staff name.';
                              }

                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: phoneController,
                            enabled: !submitting,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: '+639123456789',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final phone = value?.trim() ?? '';

                              if (!RegExp(
                                r'^\+[1-9]\d{7,14}$',
                              ).hasMatch(phone)) {
                                return 'Enter a valid number with country code.';
                              }

                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: securityIdController,
                            enabled: !submitting,
                            decoration: const InputDecoration(
                              labelText: 'Security ID (optional)',
                              hintText: 'SEC-001',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: shiftController,
                            enabled: !submitting,
                            decoration: const InputDecoration(
                              labelText: 'Shift (optional)',
                              hintText: 'Morning',
                              prefixIcon: Icon(Icons.schedule_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: submitting ? null : submit,
                    icon: submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                      submitting ? 'Adding...' : 'Add Security Staff',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      securityIdController.dispose();
      shiftController.dispose();
    }
  }

  String _securityProvisioningMessage(Object error) {
    final text = error.toString();

    if (text.contains('already-exists')) {
      return 'A Security profile already exists for this phone number.';
    }

    if (text.contains('resident')) {
      return 'This phone number already belongs to a resident.';
    }

    if (text.contains('administrator')) {
      return 'This phone number already belongs to an administrator.';
    }

    if (text.contains('permission-denied')) {
      return 'You are not allowed to add Security staff to this community.';
    }

    if (text.contains('failed-precondition')) {
      return 'The selected community is unavailable or inactive.';
    }

    return 'Security staff could not be added. Please try again.';
  }

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          final heading = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0EDFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.security,
                  color: Color(0xFF0E4778),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Security Management',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage security staff and assignments',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final buttons = Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AddGateModal.show(context);

                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Add Place'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0E4778),
                    side: const BorderSide(color: Color(0xFF0E4778)),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddSecurityDialog,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add Security'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E4778),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, const SizedBox(height: 18), buttons],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 24),
              SizedBox(width: 360, child: buttons),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.r),
        ),
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            _buildSegmentButton('All'),
            _buildSegmentButton('On Duty'),
            _buildSegmentButton('Off Duty'),
            _buildSegmentButton('On Leave'),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label) {
    final isSelected = _selectedFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = label;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF0E4778)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search security staff...',
          hintStyle: TextStyle(fontSize: 14.sp, color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280), size: 20.w),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityList() {
    return StreamBuilder<List<SecurityStaff>>(
      stream: _securityService.getSecurityStaff(),
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
              child: Text(
                'Error loading security staff',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
          );
        }

        final allStaff = snapshot.data ?? [];

        // Filter based on selected segment
        final filteredBySegment = allStaff.where((staff) {
          if (_selectedFilter == 'All') {
            return true;
          }

          return staff.getStatusDisplay() == _selectedFilter;
        }).toList();

        // Then filter by search query
        final filteredStaff = filteredBySegment.where((staff) {
          if (_searchQuery.isEmpty) return true;
          return staff.name.toLowerCase().contains(_searchQuery) ||
              staff.phone.contains(_searchQuery) ||
              (staff.gateAssignment?.toLowerCase().contains(_searchQuery) ??
                  false);
        }).toList();

        if (filteredStaff.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.0.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 64.w, color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No security staff found'
                        : 'No results found',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Use Add Security to create your first security account'
                        : 'Try a different search term',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
          physics: const ClampingScrollPhysics(),
          itemCount: filteredStaff.length,
          itemBuilder: (context, index) {
            return _buildSecurityCard(filteredStaff[index]);
          },
        );
      },
    );
  }

  Widget _buildSecurityCard(SecurityStaff staff) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            _showSecurityDetails(staff);
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Profile Picture
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0EDFF),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: staff.photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.network(
                                staff.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    color: Color(0xFF0E4778),
                                    size: 28.w,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: Color(0xFF0E4778),
                              size: 28.w,
                            ),
                    ),
                    SizedBox(width: 12.w),
                    // Name and Phone
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
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 14.w,
                                color: Color(0xFF6B7280),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                staff.phone,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: staff.getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        staff.getStatusDisplay(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: staff.getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                const Divider(height: 1),
                SizedBox(height: 12.h),
                // Work Details
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.access_time,
                        label: 'Shift',
                        value: staff.shiftTiming ?? 'Not assigned',
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.location_on,
                        label: 'Gate',
                        value: staff.gateAssignment ?? 'Not assigned',
                      ),
                    ),
                  ],
                ),
                if (staff.workStatus != null) ...[
                  SizedBox(height: 12.h),
                  _buildInfoItem(
                    icon: Icons.work,
                    label: 'Work Status',
                    value: staff.workStatus!,
                  ),
                ],
                SizedBox(height: 16.h),
                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.assignment, size: 18.w),
                    label: const Text('Work Assignment – Next Upgrade'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4778),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.w, color: const Color(0xFF6B7280)),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Color(0xFF9CA3AF)),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSecurityDetails(SecurityStaff staff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecurityDetailsScreen(staff: staff),
      ),
    );
  }

  Widget _buildPlacesSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: StreamBuilder<List<GateModel>>(
        stream: _gateService.getGates(),
        builder: (context, snapshot) {
          final places = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return InkWell(
            onTap: () => _showPlacesModal(),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0EDFF),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFF0E4778),
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Places',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          isLoading
                              ? 'Loading...'
                              : places.isEmpty
                              ? 'No places added yet'
                              : '${places.length} ${places.length == 1 ? 'place' : 'places'} configured',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0EDFF),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      '${places.length}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0E4778),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.w,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPlacesModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.92 > 600
                  ? 600
                  : MediaQuery.of(context).size.width * 0.92,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              elevation: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0EDFF),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: Color(0xFF0E4778),
                            size: 20.w,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Security Places',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20.r),
                          child: Container(
                            width: 40.w,
                            height: 40.h,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close,
                              color: Color(0xFF9CA3AF),
                              size: 20.w,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Places List
                  Flexible(
                    child: StreamBuilder<List<GateModel>>(
                      stream: _gateService.getGates(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0.w),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final places = snapshot.data ?? [];

                        if (places.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(32.0.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_off,
                                  size: 64.w,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'No Places Added',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Add security places to manage locations',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await AddGateModal.show(context);
                                    setState(() {});
                                  },
                                  icon: Icon(Icons.add, size: 18.w),
                                  label: const Text('Add Place'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0E4778),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.all(20.w),
                          itemCount: places.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            final place = places[index];
                            return _buildPlaceCard(place);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPlaceCard(GateModel place) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFF6B7280),
                  size: 22.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.gateName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 6.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: place.workingStatus == 'Active'
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFFE5E5),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            place.workingStatus,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: place.workingStatus == 'Active'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        Text(
                          place.shiftTime ?? 'No shift',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Color(0xFF6B7280),
                  size: 20.w,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18.w, color: Color(0xFF6B7280)),
                        SizedBox(width: 12.w),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          size: 18.w,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Delete',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    await EditGateModal.show(context, place);

                    if (mounted) {
                      setState(() {});
                    }
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(place);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(GateModel gate) {
    final screenContext = context;

    showDialog<void>(
      context: screenContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Remove Place',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to remove "${gate.gateName}"? '
            'The place will be archived and hidden from active security places.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  final success = await _gateService.deleteGate(gate.id);

                  if (!mounted) {
                    return;
                  }

                  if (success) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text('Security place removed successfully.'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } on FirebaseFunctionsException catch (e) {
                  if (!mounted) {
                    return;
                  }

                  String message;

                  switch (e.code) {
                    case 'failed-precondition':
                      message =
                          e.message ??
                          'This place cannot be removed while security staff is assigned.';
                      break;

                    case 'permission-denied':
                      message =
                          'You are not allowed to remove this security place.';
                      break;

                    case 'not-found':
                      message = 'Security place was not found.';
                      break;

                    case 'unauthenticated':
                      message =
                          'Your session has expired. Please sign in again.';
                      break;

                    default:
                      message =
                          e.message ??
                          'Unable to remove the security place. Please try again.';
                  }

                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } catch (e) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to remove the security place. Please try again.',
                      ),
                      backgroundColor: Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
