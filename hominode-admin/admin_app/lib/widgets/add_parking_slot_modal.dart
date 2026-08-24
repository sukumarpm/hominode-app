import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/parking_service.dart';
import '../services/admin_service.dart';

class AddParkingSlotModal extends StatefulWidget {
  final List<String> buildingIds;
  final VoidCallback onSlotAdded;

  const AddParkingSlotModal({
    super.key,
    required this.buildingIds,
    required this.onSlotAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSlotAdded,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          color: Colors.transparent,
          child: AddParkingSlotModal(
            buildingIds: const [],
            onSlotAdded: onSlotAdded,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  @override
  State<AddParkingSlotModal> createState() => _AddParkingSlotModalState();
}

class _AddParkingSlotModalState extends State<AddParkingSlotModal> {
  final ParkingService _parkingService = ParkingService();
  final AdminService _adminService = AdminService();
  final TextEditingController _slotNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedVehicleType = 'Car';
  String _selectedBuildingId = '';
  bool _isLoading = false;
  List<String> _adminBuildingIds = [];

  final List<String> _vehicleTypes = ['Car', 'Bike', 'Scooter'];

  @override
  void initState() {
    super.initState();
    _initializeBuildings();
  }

  Future<void> _initializeBuildings() async {
    try {
      final buildingIds = await _adminService.getAdminBuildingIds();
      if (buildingIds.isNotEmpty) {
        setState(() {
          _adminBuildingIds = buildingIds;
          _selectedBuildingId = buildingIds.first;
        });
      }
    } catch (e) {
      print('Error initializing buildings: $e');
    }
  }

  @override
  void dispose() {
    _slotNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createParkingSlot() async {
    if (_slotNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter slot number'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _parkingService.createParkingSlot(
        slotNumber: _slotNumberController.text.trim(),
        slotType: _selectedVehicleType,
        buildingId: _selectedBuildingId,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.w),
                SizedBox(width: 8.w),
                Text('Parking slot created successfully'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        widget.onSlotAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              24.h,
              24.w,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Parking Slot',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 20.w,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Slot Number Field
                Text(
                  'Slot Number',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _slotNumberController,
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF111827)),
                  decoration: InputDecoration(
                    hintText: 'e.g., A1, A2, B1',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: Color(0xFF0E4778),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // Vehicle Type Dropdown
                Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedVehicleType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                    items: _vehicleTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedVehicleType = value);
                      }
                    },
                  ),
                ),
                SizedBox(height: 20.h),

                // Notes Field
                Text(
                  'Notes (Optional)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _notesController,
                  style: TextStyle(fontSize: 14.sp, color: Color(0xFF111827)),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any notes about this slot...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: Color(0xFF0E4778),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createParkingSlot,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E4778),
                          disabledBackgroundColor: const Color(0xFFD1D5DB),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Create',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
      ),
    );
  }
}
