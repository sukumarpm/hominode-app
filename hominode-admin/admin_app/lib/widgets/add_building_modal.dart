import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import '../services/building_service.dart';

// Input model for the modal (without id)
class BuildingInput {
  final String name;
  final int floors;
  final int flatsPerFloor;
  final int totalFlats;
  final Map<String, String> flatBhkConfig; // Map of flatId to BHK type

  BuildingInput({
    required this.name,
    required this.floors,
    required this.flatsPerFloor,
    required this.totalFlats,
    required this.flatBhkConfig,
  });
}

class AddBuildingModal extends StatefulWidget {
  final FutureOr<void> Function(BuildingInput building) onSave;
  final BuildingModel? existingBuilding;
  final bool isEditMode;

  const AddBuildingModal({
    super.key,
    required this.onSave,
    this.existingBuilding,
    this.isEditMode = false,
  });

  static Future<void> show(
    BuildContext context, {
    required FutureOr<void> Function(BuildingInput building) onSave,
    BuildingModel? existingBuilding,
  }) {
    final isEditMode = existingBuilding != null;
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddBuildingModal(
          onSave: onSave,
          existingBuilding: existingBuilding,
          isEditMode: isEditMode,
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

  @override
  State<AddBuildingModal> createState() => _AddBuildingModalState();
}

class _AddBuildingModalState extends State<AddBuildingModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _floorsController = TextEditingController();
  final _flatsPerFloorController = TextEditingController();

  bool _isLoading = false;
  bool _isFormValid = false;

  String? _nameError;
  String? _floorsError;
  String? _flatsError;

  // BHK Configuration
  String _bhkMode = 'same'; // 'same' or 'custom'
  String _defaultBhk = '2BHK'; // Default BHK for 'same' mode
  final List<String> _bhkOptions = ['1BHK', '2BHK', '3BHK', '4BHK', '5BHK'];
  final Map<String, String> _customBhkConfig =
      {}; // For custom mode: flatId -> BHK type

  @override
  void initState() {
    super.initState();

    // Pre-fill form if editing
    if (widget.isEditMode && widget.existingBuilding != null) {
      _nameController.text = widget.existingBuilding!.name;
      _floorsController.text = widget.existingBuilding!.floors.toString();
      _flatsPerFloorController.text = widget.existingBuilding!.flatsPerFloor
          .toString();
    }

    _nameController.addListener(_validateForm);
    _floorsController.addListener(_validateForm);
    _flatsPerFloorController.addListener(_validateForm);

    // Validate initial values if editing
    if (widget.isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateForm();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floorsController.dispose();
    _flatsPerFloorController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _nameError = null;
      _floorsError = null;
      _flatsError = null;

      final name = _nameController.text.trim();
      final floors = int.tryParse(_floorsController.text);
      final flats = int.tryParse(_flatsPerFloorController.text);

      bool isValid = true;

      if (name.isEmpty) {
        isValid = false;
      } else if (name.length < 2) {
        _nameError = 'Name must be at least 2 characters';
        isValid = false;
      }

      if (_floorsController.text.isEmpty) {
        isValid = false;
      } else if (floors == null || floors <= 0) {
        _floorsError = 'Must be a positive number';
        isValid = false;
      }

      if (_flatsPerFloorController.text.isEmpty) {
        isValid = false;
      } else if (flats == null || flats <= 0) {
        _flatsError = 'Must be a positive number';
        isValid = false;
      }

      _isFormValid = isValid;
    });
  }

  Future<void> _handleAddBuilding() async {
    if (!_isFormValid) {
      _validateForm();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Generate flat BHK configuration
    final flatBhkConfig = <String, String>{};
    final buildingPrefix = _nameController.text.trim()[0];

    for (int floor = 1; floor <= int.parse(_floorsController.text); floor++) {
      for (
        int flatNum = 1;
        flatNum <= int.parse(_flatsPerFloorController.text);
        flatNum++
      ) {
        final flatId = '$buildingPrefix${floor}0$flatNum';

        if (_bhkMode == 'custom' && _customBhkConfig.containsKey(flatId)) {
          flatBhkConfig[flatId] = _customBhkConfig[flatId]!;
        } else {
          flatBhkConfig[flatId] = _defaultBhk;
        }
      }
    }

    final building = BuildingInput(
      name: _nameController.text.trim(),
      floors: int.parse(_floorsController.text),
      flatsPerFloor: int.parse(_flatsPerFloorController.text),
      totalFlats: _totalFlats,
      flatBhkConfig: flatBhkConfig,
    );

    try {
      await widget.onSave(building);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalFlats {
    final floors = int.tryParse(_floorsController.text) ?? 0;
    final flats = int.tryParse(_flatsPerFloorController.text) ?? 0;
    return floors * flats;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92 > 720
              ? 720
              : MediaQuery.of(context).size.width * 0.92,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          elevation: 8,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 24.h),
                    _buildNameField(),
                    SizedBox(height: 20.h),
                    _buildNumericFields(),
                    SizedBox(height: 20.h),
                    _buildBhkSelector(),
                    SizedBox(height: 20.h),
                    _buildAmountStrip(),
                    SizedBox(height: 16.h),
                    _buildAddButton(),
                    SizedBox(height: 12.h),
                    _buildCancelButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Column(
          children: [
            Text(
              widget.isEditMode ? 'Edit Building' : 'Add New Building',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              widget.isEditMode
                  ? 'Update building or tower details'
                  : 'Configure your new building or tower with floor and flat details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            label: 'Close add building form',
            button: true,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(22.r),
              child: Container(
                width: 44.w,
                height: 44.h,
                alignment: Alignment.center,
                child: Icon(Icons.close, color: Color(0xFF9CA3AF), size: 24.w),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Building/Tower Name',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        Semantics(
          label: 'Building or tower name',
          child: TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Tower D',
              hintStyle: TextStyle(color: Color(0xFFB9BDC1), fontSize: 16.sp),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFE6E9EC),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFE6E9EC),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFF0E4778),
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (_nameError != null) ...[
          SizedBox(height: 4.h),
          Text(
            _nameError!,
            style: TextStyle(fontSize: 12.sp, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }

  Widget _buildNumericFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildNumericField(
            label: 'Floors',
            controller: _floorsController,
            hint: '10',
            error: _floorsError,
            semanticLabel: 'Number of floors',
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _buildNumericField(
            label: 'Flats per Floor',
            controller: _flatsPerFloorController,
            hint: '4',
            error: _flatsError,
            semanticLabel: 'Flats per floor',
          ),
        ),
      ],
    );
  }

  Widget _buildNumericField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? error,
    required String semanticLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        Semantics(
          label: semanticLabel,
          child: TextFormField(
            controller: controller,
            readOnly: widget.isEditMode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Color(0xFFB9BDC1), fontSize: 16.sp),
              filled: true,
              fillColor: widget.isEditMode
                  ? const Color(0xFFF3F4F6)
                  : Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFE6E9EC),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFE6E9EC),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFF0E4778),
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          SizedBox(height: 4.h),
          Text(
            error,
            style: TextStyle(fontSize: 12.sp, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }

  Widget _buildBhkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flat Type (BHK)',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 12.h),

        // Mode selector
        Row(
          children: [
            Expanded(
              child: _buildModeButton('Same for All', 'same', Icons.grid_view),
            ),
            SizedBox(width: 12.w),
            Expanded(child: _buildModeButton('Custom', 'custom', Icons.tune)),
          ],
        ),

        SizedBox(height: 16.h),

        // Show appropriate selector based on mode
        if (_bhkMode == 'same') _buildSameBhkSelector(),
        if (_bhkMode == 'custom') _buildCustomBhkSelector(),
      ],
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _bhkMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _bhkMode = mode;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0E4778)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.w,
              color: isSelected
                  ? const Color(0xFF0E4778)
                  : const Color(0xFF6B7280),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0E4778)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSameBhkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select BHK type for all flats',
          style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _bhkOptions.map((bhk) {
            final isSelected = _defaultBhk == bhk;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _defaultBhk = bhk;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0E4778) : Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0E4778)
                        : const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  bhk,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF111111),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomBhkSelector() {
    if (_floorsController.text.isEmpty ||
        _flatsPerFloorController.text.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 20.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Please enter floors and flats per floor first',
                style: TextStyle(fontSize: 13.sp, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );
    }

    final floors = int.parse(_floorsController.text);
    final flatsPerFloor = int.parse(_flatsPerFloorController.text);
    final buildingPrefix = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0]
        : 'A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Click each flat to set its BHK type',
          style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
        ),
        SizedBox(height: 12.h),

        // BHK Legend
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bhkOptions.map((bhk) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _getBhkColor(bhk).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: _getBhkColor(bhk)),
              ),
              child: Text(
                bhk,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: _getBhkColor(bhk),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 16.h),

        // Flat Grid
        Container(
          constraints: BoxConstraints(maxHeight: 300.h),
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(floors, (floorIndex) {
                final floor =
                    floors - floorIndex; // Reverse order (top floor first)
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      // Floor label
                      SizedBox(
                        width: 40.w,
                        child: Text(
                          'F$floor',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      // Flats
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(flatsPerFloor, (flatIndex) {
                            final flatNum = flatIndex + 1;
                            final flatId = '$buildingPrefix${floor}0$flatNum';
                            final bhk = _customBhkConfig[flatId] ?? _defaultBhk;

                            return GestureDetector(
                              onTap: () => _showBhkPicker(flatId),
                              child: Container(
                                width: 60.w,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: _getBhkColor(bhk).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: _getBhkColor(bhk),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      flatId,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111111),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      bhk,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: _getBhkColor(bhk),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Color _getBhkColor(String bhk) {
    switch (bhk) {
      case '1BHK':
        return const Color(0xFF10B981); // Green
      case '2BHK':
        return const Color(0xFF0E4778); // Blue
      case '3BHK':
        return const Color(0xFF8B5CF6); // Purple
      case '4BHK':
        return const Color(0xFFF59E0B); // Orange
      case '5BHK':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  void _showBhkPicker(String flatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select BHK for $flatId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _bhkOptions.map((bhk) {
            return ListTile(
              title: Text(bhk),
              leading: Container(
                width: 24.w,
                height: 24.h,
                decoration: BoxDecoration(
                  color: _getBhkColor(bhk),
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () {
                setState(() {
                  _customBhkConfig[flatId] = bhk;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAmountStrip() {
    String bhkSummary = _defaultBhk;

    if (_bhkMode == 'custom' && _customBhkConfig.isNotEmpty) {
      // Count BHK types
      final bhkCounts = <String, int>{};
      for (final bhk in _customBhkConfig.values) {
        bhkCounts[bhk] = (bhkCounts[bhk] ?? 0) + 1;
      }

      // Build summary string
      final parts = bhkCounts.entries
          .map((e) => '${e.value}x${e.key}')
          .toList();
      bhkSummary = parts.join(', ');
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Flats:',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                '$_totalFlats',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0E4778),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configuration:',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              Flexible(
                child: Text(
                  bhkSummary,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0E4778),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Semantics(
      label: 'Add building',
      button: true,
      enabled: _isFormValid && !_isLoading,
      child: ElevatedButton(
        onPressed: _isFormValid && !_isLoading ? _handleAddBuilding : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          disabledBackgroundColor: const Color(0xFF0E4778).withOpacity(0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                widget.isEditMode ? 'Update Building' : 'Add Building',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Semantics(
      label: 'Cancel',
      button: true,
      child: OutlinedButton(
        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111111),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: Text(
          'Cancel',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
