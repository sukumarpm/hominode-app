import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'flat_occupancy_grid_modal.dart';

/// Pixel-perfect "Flat Maintenance Status" overlay modal
/// Opens when admin taps a flat in maintenance status
class FlatMaintenanceModal extends StatefulWidget {
  final FlatUnit unit;
  final Function(FlatStatus newStatus)? onStatusChange;

  const FlatMaintenanceModal({
    super.key,
    required this.unit,
    this.onStatusChange,
  });

  /// Show the modal with fade-in and scale animation
  static Future<void> show(
    BuildContext context, {
    required FlatUnit unit,
    Function(FlatStatus newStatus)? onStatusChange,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close maintenance modal',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatMaintenanceModal(unit: unit, onStatusChange: onStatusChange);
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

  @override
  State<FlatMaintenanceModal> createState() => _FlatMaintenanceModalState();
}

class _FlatMaintenanceModalState extends State<FlatMaintenanceModal> {
  String _selectedStatus = 'Keep in Maintenance';
  bool _isUpdating = false;

  final List<String> _statusOptions = [
    'Keep in Maintenance',
    'Mark as Vacant',
    'Mark as Occupied',
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.92,
          maxHeight: screenHeight * 0.80,
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          elevation: 8,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailsGrid(),
                      SizedBox(height: 24.h),
                      _buildWarningBox(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 44.w),
            child: Column(
              children: [
                Text(
                  widget.unit.id,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'View and manage unit details, resident information, and status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Semantics(
              label: 'Close maintenance modal',
              button: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22.r),
                child: Container(
                  width: 44.w,
                  height: 44.h,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 22.w,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Column(
      children: [
        // Row 1: Labels
        Row(
          children: [
            Expanded(
              child: _buildLabel(
                widget.unit.usesFloors ? 'Floor' : 'Unit Type',
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(child: _buildLabel('Configuration')),
          ],
        ),
        SizedBox(height: 16.h),
        // Row 2: Values
        Row(
          children: [
            Expanded(
              child: _buildValue(
                widget.unit.usesFloors
                    ? 'Floor ${widget.unit.floor}'
                    : widget.unit.unitType.label,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(child: _buildValue(widget.unit.type)),
          ],
        ),
        SizedBox(height: 24.h),
        // Row 3: Labels
        Row(
          children: [
            Expanded(child: _buildLabel('Area')),
            SizedBox(width: 16.w),
            Expanded(child: _buildLabel('Status')),
          ],
        ),
        SizedBox(height: 16.h),
        // Row 4: Values
        Row(
          children: [
            Expanded(child: _buildValue(widget.unit.area)),
            SizedBox(width: 16.w),
            Expanded(child: _buildMaintenanceBadge()),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildValue(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildMaintenanceBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF2B100),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          'Maintenance',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This unit is under maintenance. Change status when ready.',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9A3A2A),
              height: 1.5,
            ),
          ),
          SizedBox(height: 16.h),
          _buildStatusDropdown(),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E2E2)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          icon: Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF9CA3AF),
              size: 24.w,
            ),
          ),
          borderRadius: BorderRadius.circular(14.r),
          items: _statusOptions.map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: _isUpdating
              ? null
              : (value) {
                  if (value != null && value != _selectedStatus) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _handleStatusChange(value);
                  }
                },
        ),
      ),
    );
  }

  Future<void> _handleStatusChange(String selectedOption) async {
    if (selectedOption == 'Keep in Maintenance') {
      return; // No change needed
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Determine new status
      FlatStatus newStatus;
      if (selectedOption == 'Mark as Vacant') {
        newStatus = FlatStatus.vacant;
      } else if (selectedOption == 'Mark as Occupied') {
        newStatus = FlatStatus.occupied;
      } else {
        return;
      }

      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 800));

      // Update status via callback
      widget.onStatusChange?.call(newStatus);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flat ${widget.unit.id} status updated successfully'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _selectedStatus = 'Keep in Maintenance';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
