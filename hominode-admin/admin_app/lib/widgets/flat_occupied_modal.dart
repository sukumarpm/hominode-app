import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'flat_occupancy_grid_modal.dart';

/// Pixel-perfect "Flat Occupied Details" overlay modal
/// Opens when admin taps an occupied flat in the grid
class FlatOccupiedModal extends StatefulWidget {
  final FlatUnit unit;
  final Future<void> Function(FlatStatus newStatus)? onStatusChange;
  final VoidCallback? onRemoveResident;

  const FlatOccupiedModal({
    super.key,
    required this.unit,
    this.onStatusChange,
    this.onRemoveResident,
  });

  static Future<void> show(
    BuildContext context, {
    required FlatUnit unit,
    Future<void> Function(FlatStatus newStatus)? onStatusChange,
    VoidCallback? onRemoveResident,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close occupied flat details',
      barrierColor: const Color(0x59000000), // rgba(0, 0, 0, 0.35)
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlatOccupiedModal(
          unit: unit,
          onStatusChange: onStatusChange,
          onRemoveResident: onRemoveResident,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FlatOccupiedModal> createState() => _FlatOccupiedModalState();
}

class _FlatOccupiedModalState extends State<FlatOccupiedModal> {
  String _selectedStatus = 'Occupied';
  bool _isUpdating = false;

  final List<String> _statusOptions = ['Occupied', 'Vacant', 'Maintenance'];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.92,
          maxHeight: screenHeight * 0.85,
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
                      _buildResidentInformation(),
                      SizedBox(height: 24.h),
                      _buildActionButtons(),
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
                    fontSize: 14.sp,
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
              label: 'Close occupied flat details',
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
            Expanded(child: _buildOccupiedBadge()),
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

  Widget _buildOccupiedBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF15B34A),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          'Occupied',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildResidentInformation() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resident Information',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 20.h),
          _buildResidentRow(
            'Name :',
            widget.unit.residentName ?? 'Not Available',
          ),
          SizedBox(height: 16.h),
          _buildResidentRow('Flat :', widget.unit.id),
          SizedBox(height: 16.h),
          _buildResidentRow(
            widget.unit.usesFloors ? 'Floor :' : 'Unit Type :',
            widget.unit.usesFloors
                ? 'Floor ${widget.unit.floor}'
                : widget.unit.unitType.label,
          ),
        ],
      ),
    );
  }

  Widget _buildResidentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildResidentRowWithBadge(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildRemoveButton()),
        SizedBox(width: 14.w),
        Expanded(child: _buildStatusDropdown()),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return Semantics(
      label: 'Remove resident from flat',
      button: true,
      child: SizedBox(
        height: 56.h,
        child: OutlinedButton.icon(
          onPressed: _isUpdating ? null : _handleRemoveResident,
          icon: Icon(Icons.delete_outline, size: 22.w),
          label: Text(
            'Remove',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    fontWeight: FontWeight.w600,
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

  Future<void> _handleRemoveResident() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Resident'),
        content: Text(
          'Are you sure you want to remove ${widget.unit.residentName ?? "this resident"} from ${widget.unit.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        // Simulate API call

        // Update status to vacant
        widget.onStatusChange?.call(FlatStatus.vacant);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resident removed from ${widget.unit.id}'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isUpdating = false;
          _selectedStatus = 'Occupied';
        });

        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Status change not allowed'),
            content: const Text(
              'This unit is linked to an active resident. '
              'Use the resident lifecycle actions to change occupancy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleStatusChange(String selectedStatus) async {
    if (selectedStatus == 'Occupied') {
      return;
    }

    final FlatStatus newStatus;

    if (selectedStatus == 'Vacant') {
      newStatus = FlatStatus.vacant;
    } else if (selectedStatus == 'Maintenance') {
      newStatus = FlatStatus.maintenance;
    } else {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Parent owns the actual Firestore update and result messaging.
      await widget.onStatusChange?.call(newStatus);

      // Close only after the parent update succeeds.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
        _selectedStatus = 'Occupied';
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Status change not allowed'),
            content: const Text(
              'This unit is currently linked to a resident. '
              'To make the flat vacant, use Move Out from Resident Management.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
}
