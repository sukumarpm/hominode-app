import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/gate_service.dart';
import '../services/security_service.dart';

class AssignSecurityWorkModal extends StatefulWidget {
  final SecurityStaff staff;

  const AssignSecurityWorkModal({super.key, required this.staff});

  static Future<void> show(BuildContext context, SecurityStaff staff) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AssignSecurityWorkModal(staff: staff);
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
  State<AssignSecurityWorkModal> createState() =>
      _AssignSecurityWorkModalState();
}

class _AssignSecurityWorkModalState extends State<AssignSecurityWorkModal> {
  final SecurityService _securityService = SecurityService();
  final GateService _gateService = GateService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedShift;

  // Display name
  String? _selectedGate;

  // Firestore document ID
  String? _selectedGateId;

  String? _selectedWorkStatus;
  final TextEditingController _instructionsController = TextEditingController();

  bool _isLoading = false;
  List<GateModel> _availableGates = [];
  bool _loadingGates = true;

  final List<String> _defaultShifts = [
    'Morning Shift (6 AM - 2 PM)',
    'Evening Shift (2 PM - 10 PM)',
    'Night Shift (10 PM - 6 AM)',
  ];

  late List<String> _shifts;

  final List<String> _workStatuses = ['On Duty', 'Off Duty', 'Break'];

  @override
  void initState() {
    super.initState();

    _selectedShift = _clean(widget.staff.shiftTiming);
    _selectedGate = _clean(widget.staff.gateAssignment);
    _selectedWorkStatus = _clean(widget.staff.workStatus);

    _instructionsController.text =
        widget.staff.specialInstructions?.trim() ?? '';

    _shifts = _buildUniqueOptions(_defaultShifts, _selectedShift);

    _loadGates();
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  List<String> _buildUniqueOptions(
    List<String> defaults,
    String? currentValue,
  ) {
    final values = <String>{};

    for (final value in defaults) {
      final cleaned = value.trim();

      if (cleaned.isNotEmpty) {
        values.add(cleaned);
      }
    }

    final current = currentValue?.trim();

    if (current != null && current.isNotEmpty) {
      values.add(current);
    }

    return values.toList(growable: false);
  }

  Future<void> _loadGates() async {
    print('Loading gates...');
    try {
      final gatesStream = _gateService.getGates();
      gatesStream.listen((gates) {
        print('Gates loaded: ${gates.length}');
        for (var gate in gates) {
          print('Gate: ${gate.gateName} - ${gate.workingStatus}');
        }
        if (mounted) {
          setState(() {
            _availableGates = gates;
            _loadingGates = false;
            if (_selectedGate != null && _selectedGateId == null) {
              for (final gate in gates) {
                if (gate.gateName == _selectedGate) {
                  _selectedGateId = gate.id;
                  break;
                }
              }
            }
          });
        }
      });
    } catch (e) {
      print('Error loading gates: $e');
      if (mounted) {
        setState(() {
          _loadingGates = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92 > 600
              ? 600
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
                    _buildShiftTimingField(),
                    SizedBox(height: 20.h),
                    _buildSecurityPlaceField(),
                    SizedBox(height: 20.h),
                    _buildWorkStatusField(),
                    SizedBox(height: 20.h),
                    _buildInstructionsField(),
                    SizedBox(height: 24.h),
                    _buildAssignButton(),

                    if (widget.staff.gateAssignment != null &&
                        widget.staff.gateAssignment!.trim().isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _buildRemoveAssignmentButton(),
                    ],

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

  Widget _buildRemoveAssignmentButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading
          ? null
          : () async {
              try {
                setState(() {
                  _isLoading = true;
                });

                await _securityService.removeAssignment(
                  staffId: widget.staff.uid,
                );

                if (!mounted) return;

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Security assignment removed successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } on FirebaseFunctionsException catch (e) {
                if (!mounted) return;

                setState(() {
                  _isLoading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message ?? 'Unable to remove assignment.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                setState(() {
                  _isLoading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to remove assignment.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
      icon: const Icon(Icons.link_off),
      label: const Text('Remove Assignment'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: const BorderSide(color: Color(0xFFEF4444)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
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
              'Assign Work',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              widget.staff.name,
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
      ],
    );
  }

  Widget _buildShiftTimingField() {
    final selectedValue =
        _selectedShift != null && _shifts.contains(_selectedShift)
        ? _selectedShift
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Timing',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Select shift timing',
            hintStyle: TextStyle(
              color: const Color(0xFFB9BDC1),
              fontSize: 16.sp,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
          items: _shifts
              .map(
                (shift) => DropdownMenuItem<String>(
                  value: shift,
                  child: Text(
                    shift,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: _isLoading
              ? null
              : (value) {
                  setState(() {
                    _selectedShift = value;
                  });
                },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please select shift timing';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSecurityPlaceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Place',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        if (_loadingGates)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE6E9EC)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12.w),
                Text('Loading places...'),
              ],
            ),
          )
        else
          InkWell(
            onTap: _availableGates.isEmpty ? null : _showGateSelectionModal,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE6E9EC), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20.w,
                    color: _selectedGate != null
                        ? const Color(0xFF0E4778)
                        : const Color(0xFF6B7280),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _selectedGate ??
                          (_availableGates.isEmpty
                              ? 'No places available'
                              : 'Select security place'),
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: _selectedGate != null
                            ? const Color(0xFF111111)
                            : const Color(0xFFB9BDC1),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.w,
                    color: _availableGates.isEmpty
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        if (_availableGates.isEmpty && !_loadingGates) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_off, size: 18.w, color: Color(0xFFF59E0B)),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'No places available. Add places from Security Management screen.',
                    style: TextStyle(fontSize: 13.sp, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showGateSelectionModal() {
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
              maxWidth: MediaQuery.of(context).size.width * 0.92 > 500
                  ? 500
                  : MediaQuery.of(context).size.width * 0.92,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                            'Select Security Place',
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
                  // Gate List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(20.w),
                      itemCount: _availableGates.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final gate = _availableGates[index];
                        final isSelected = _selectedGateId == gate.id;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGate = gate.gateName;
                              _selectedGateId = gate.id;
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEFF6FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0E4778)
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44.w,
                                  height: 44.h,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0E4778)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                    size: 22.w,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gate.gateName,
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF0E4778)
                                              : const Color(0xFF111111),
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Wrap(
                                        spacing: 8.w,
                                        runSpacing: 6.h,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  gate.workingStatus == 'Active'
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFFFE5E5),
                                              borderRadius:
                                                  BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              gate.workingStatus,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    gate.workingStatus ==
                                                        'Active'
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            gate.shiftTime ?? 'No shift',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF0E4778),
                                    size: 24.w,
                                  ),
                              ],
                            ),
                          ),
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

  Widget _buildWorkStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Work Status',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _selectedWorkStatus,
          decoration: InputDecoration(
            hintText: 'Select work status',
            hintStyle: TextStyle(color: Color(0xFFB9BDC1), fontSize: 16.sp),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
          ),
          items: _workStatuses.map((status) {
            return DropdownMenuItem(value: status, child: Text(status));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedWorkStatus = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select work status';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInstructionsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Instructions (Optional)',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter any special instructions...',
            hintStyle: TextStyle(color: Color(0xFFB9BDC1), fontSize: 16.sp),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.all(16.w),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE6E9EC), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _assignWork,
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
              'Assign Work',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
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
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _assignWork() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that a gate is selected
    if (_selectedGate == null || _selectedGate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a security place'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Assign work to security staff (updates staff collection and status)
      if (_selectedGateId == null || _selectedGateId!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a security place.')),
        );
        return;
      }

      await _securityService.assignWork(
        staffId: widget.staff.uid,
        gateId: _selectedGateId!,
        shiftTiming: _selectedShift!,
        workStatus: _selectedWorkStatus!,
        specialInstructions: _instructionsController.text,
      );

      // Step 2: Find the gate by name and update it with assignment details
      final gates = await _gateService.getGates().first;
      final selectedGate = gates.firstWhere(
        (gate) => gate.gateName == _selectedGate,
        orElse: () => throw Exception('Gate not found'),
      );

      // Step 3: Update gate collection with security assignment details
      await _gateService.assignSecurityToGate(
        gateId: selectedGate.id,
        securityId: widget.staff.id,
        securityName: widget.staff.name,
        shiftTiming: _selectedShift!,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work assigned to ${widget.staff.name}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign work: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
