// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import '../services/gate_service.dart';

// class EditGateModal extends StatefulWidget {
//   final GateModel gate;
//   const EditGateModal({super.key, required this.gate});

//   static Future<void> show(BuildContext context, GateModel gate) {
//     return showGeneralDialog(
//       context: context,
//       barrierDismissible: true,
//       barrierLabel: 'Close',
//       barrierColor: Colors.black.withOpacity(0.35),
//       transitionDuration: const Duration(milliseconds: 220),
//       pageBuilder: (context, animation, secondaryAnimation) {
//         return Center(
//           child: Container(
//             constraints: BoxConstraints(
//               maxWidth: MediaQuery.of(context).size.width * 0.92 > 600
//                   ? 600
//                   : MediaQuery.of(context).size.width * 0.92,
//               maxHeight: MediaQuery.of(context).size.height * 0.8,
//             ),
//             margin: EdgeInsets.symmetric(horizontal: 16.w),
//             child: Material(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20.r),
//               elevation: 8,
//               child: EditGateModal(gate: gate),
//             ),
//           ),
//         );
//       },
//       transitionBuilder: (context, animation, secondaryAnimation, child) {
//         return FadeTransition(
//           opacity: animation,
//           child: ScaleTransition(
//             scale: Tween<double>(begin: 0.96, end: 1.0).animate(
//               CurvedAnimation(parent: animation, curve: Curves.easeOut),
//             ),
//             child: child,
//           ),
//         );
//       },
//     );
//   }

//   @override
//   State<EditGateModal> createState() => _EditGateModalState();
// }

// class _EditGateModalState extends State<EditGateModal> {
//   final _formKey = GlobalKey<FormState>();
//   final GateService _gateService = GateService();
//   late String _gateName;
//   late String _gateType;
//   late String _workingStatus;
//   late String _shiftTime;
//   bool _isLoading = false;

//   final List<String> _gateTypes = [
//     'Main Gate',
//     'Side Gate',
//     'Back Gate',
//     'Parking Gate',
//     'Service Gate',
//     'Emergency Gate',
//     'Pedestrian Gate',
//     'Vehicle Gate',
//   ];
//   final List<String> _workingStatuses = [
//     'Active',
//     'Inactive',
//     'Maintenance',
//     'Under Repair',
//   ];
//   final List<String> _shiftTimes = [
//     'Full Day (24 Hours)',
//     'Morning (6 AM - 2 PM)',
//     'Afternoon (2 PM - 10 PM)',
//     'Night (10 PM - 6 AM)',
//     'Day Shift (6 AM - 6 PM)',
//     'Night Shift (6 PM - 6 AM)',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _gateName = widget.gate.gateName;
//     _gateType = widget.gate.gateType;
//     _workingStatus = widget.gate.workingStatus;
//     _shiftTime = widget.gate.shiftTime ?? 'Full Day (24 Hours)';
//   }

//   Future<void> _handleUpdateGate() async {
//     if (!_formKey.currentState!.validate()) return;
//     _formKey.currentState!.save();
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final success = await _gateService.updateGate(
//         gateId: widget.gate.id,
//         gateName: _gateName,
//         gateType: _gateType,
//         workingStatus: _workingStatus,
//         shiftTime: _shiftTime,
//       );
//       if (!mounted) return;
//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Place updated successfully'),
//             backgroundColor: Color(0xFF10B981),
//           ),
//         );
//         Navigator.pop(context);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Failed to update place'),
//             backgroundColor: Color(0xFFEF4444),
//           ),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: const Color(0xFFEF4444),
//         ),
//       );
//     } finally {
//       if (mounted)
//         setState(() {
//           _isLoading = false;
//         });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Padding(
//           padding: EdgeInsets.all(20.w),
//           child: Row(
//             children: [
//               Container(
//                 width: 40.w,
//                 height: 40.h,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFE0EDFF),
//                   borderRadius: BorderRadius.circular(10.r),
//                 ),
//                 child: Icon(
//                   Icons.edit_location_alt,
//                   color: Color(0xFF0E4778),
//                   size: 20.w,
//                 ),
//               ),
//               SizedBox(width: 12.w),
//               Expanded(
//                 child: Text(
//                   'Edit Place',
//                   style: TextStyle(
//                     fontSize: 20.sp,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF111111),
//                   ),
//                 ),
//               ),
//               InkWell(
//                 onTap: () => Navigator.pop(context),
//                 borderRadius: BorderRadius.circular(20.r),
//                 child: Container(
//                   width: 40.w,
//                   height: 40.h,
//                   alignment: Alignment.center,
//                   child: Icon(
//                     Icons.close,
//                     color: Color(0xFF9CA3AF),
//                     size: 20.w,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//         Flexible(
//           child: SingleChildScrollView(
//             padding: EdgeInsets.all(20.w),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Place Name',
//                     style: TextStyle(
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF111111),
//                     ),
//                   ),
//                   SizedBox(height: 8.h),
//                   TextFormField(
//                     initialValue: _gateName,
//                     decoration: InputDecoration(
//                       hintText: 'e.g., Main Entrance Gate',
//                       hintStyle: TextStyle(
//                         color: Color(0xFF9CA3AF),
//                         fontSize: 14.sp,
//                       ),
//                       filled: true,
//                       fillColor: Colors.white,
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFF0E4778),
//                           width: 2,
//                         ),
//                       ),
//                       contentPadding: EdgeInsets.symmetric(
//                         horizontal: 16.w,
//                         vertical: 14.h,
//                       ),
//                     ),
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty)
//                         return 'Please enter place name';
//                       return null;
//                     },
//                     onSaved: (value) => _gateName = value!.trim(),
//                   ),
//                   SizedBox(height: 16.h),
//                   Text(
//                     'Place Type',
//                     style: TextStyle(
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF111111),
//                     ),
//                   ),
//                   SizedBox(height: 8.h),
//                   DropdownButtonFormField<String>(
//                     initialValue: _gateType,
//                     decoration: InputDecoration(
//                       filled: true,
//                       fillColor: Colors.white,
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFF0E4778),
//                           width: 2,
//                         ),
//                       ),
//                       contentPadding: EdgeInsets.symmetric(
//                         horizontal: 16.w,
//                         vertical: 14.h,
//                       ),
//                     ),
//                     items: _gateTypes
//                         .map(
//                           (type) =>
//                               DropdownMenuItem(value: type, child: Text(type)),
//                         )
//                         .toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         _gateType = value!;
//                       });
//                     },
//                   ),
//                   SizedBox(height: 16.h),
//                   Text(
//                     'Working Status',
//                     style: TextStyle(
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF111111),
//                     ),
//                   ),
//                   SizedBox(height: 8.h),
//                   DropdownButtonFormField<String>(
//                     initialValue: _workingStatus,
//                     decoration: InputDecoration(
//                       filled: true,
//                       fillColor: Colors.white,
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFF0E4778),
//                           width: 2,
//                         ),
//                       ),
//                       contentPadding: EdgeInsets.symmetric(
//                         horizontal: 16.w,
//                         vertical: 14.h,
//                       ),
//                     ),
//                     items: _workingStatuses
//                         .map(
//                           (status) => DropdownMenuItem(
//                             value: status,
//                             child: Text(status),
//                           ),
//                         )
//                         .toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         _workingStatus = value!;
//                       });
//                     },
//                   ),
//                   SizedBox(height: 16.h),
//                   Text(
//                     'Shift Time',
//                     style: TextStyle(
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF111111),
//                     ),
//                   ),
//                   SizedBox(height: 8.h),
//                   DropdownButtonFormField<String>(
//                     initialValue: _shiftTime,
//                     decoration: InputDecoration(
//                       filled: true,
//                       fillColor: Colors.white,
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFFE6E9EC),
//                           width: 1,
//                         ),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.r),
//                         borderSide: const BorderSide(
//                           color: Color(0xFF0E4778),
//                           width: 2,
//                         ),
//                       ),
//                       contentPadding: EdgeInsets.symmetric(
//                         horizontal: 16.w,
//                         vertical: 14.h,
//                       ),
//                     ),
//                     items: _shiftTimes
//                         .map(
//                           (time) =>
//                               DropdownMenuItem(value: time, child: Text(time)),
//                         )
//                         .toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         _shiftTime = value!;
//                       });
//                     },
//                   ),
//                   SizedBox(height: 24.h),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton(
//                           onPressed: () => Navigator.pop(context),
//                           style: OutlinedButton.styleFrom(
//                             foregroundColor: const Color(0xFF6B7280),
//                             side: const BorderSide(
//                               color: Color(0xFFE5E7EB),
//                               width: 1,
//                             ),
//                             padding: EdgeInsets.symmetric(vertical: 14.h),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12.r),
//                             ),
//                           ),
//                           child: Text(
//                             'Cancel',
//                             style: TextStyle(
//                               fontSize: 16.sp,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(width: 12.w),
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: _isLoading ? null : _handleUpdateGate,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF0E4778),
//                             foregroundColor: Colors.white,
//                             elevation: 0,
//                             padding: EdgeInsets.symmetric(vertical: 14.h),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12.r),
//                             ),
//                             disabledBackgroundColor: const Color(0xFF93C5FD),
//                           ),
//                           child: _isLoading
//                               ? SizedBox(
//                                   width: 20.w,
//                                   height: 20.h,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                   ),
//                                 )
//                               : Text(
//                                   'Update Place',
//                                   style: TextStyle(
//                                     fontSize: 16.sp,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/gate_service.dart';

class EditGateModal extends StatefulWidget {
  final GateModel gate;

  const EditGateModal({super.key, required this.gate});

  static Future<void> show(BuildContext context, GateModel gate) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final width = MediaQuery.of(context).size.width;

        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: width * 0.92 > 600 ? 600 : width * 0.92,
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              elevation: 8,
              child: EditGateModal(gate: gate),
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

  @override
  State<EditGateModal> createState() => _EditGateModalState();
}

class _EditGateModalState extends State<EditGateModal> {
  final _formKey = GlobalKey<FormState>();
  final GateService _gateService = GateService();

  late String _gateName;
  late String _gateType;
  late String _workingStatus;
  late String _shiftTime;

  bool _isLoading = false;

  static const List<String> _defaultGateTypes = [
    'Main Gate',
    'Side Gate',
    'Back Gate',
    'Parking Gate',
    'Service Gate',
    'Emergency Gate',
    'Pedestrian Gate',
    'Vehicle Gate',
    'Security Post',
  ];

  static const List<String> _defaultWorkingStatuses = [
    'Active',
    'Inactive',
    'Maintenance',
    'Under Repair',
  ];

  static const List<String> _defaultShiftTimes = [
    'Full Day (24 Hours)',
    'Morning (6 AM - 2 PM)',
    'Afternoon (2 PM - 10 PM)',
    'Night (10 PM - 6 AM)',
    'Day Shift (6 AM - 6 PM)',
    'Night Shift (6 PM - 6 AM)',
  ];

  late List<String> _gateTypes;
  late List<String> _workingStatuses;
  late List<String> _shiftTimes;

  @override
  void initState() {
    super.initState();

    _gateName = widget.gate.gateName.trim();

    _gateType = widget.gate.gateType.trim().isNotEmpty
        ? widget.gate.gateType.trim()
        : 'Main Gate';

    _workingStatus = widget.gate.workingStatus.trim().isNotEmpty
        ? widget.gate.workingStatus.trim()
        : 'Active';

    final existingShift = widget.gate.shiftTime?.trim();

    _shiftTime = existingShift != null && existingShift.isNotEmpty
        ? existingShift
        : 'Full Day (24 Hours)';

    _gateTypes = _buildUniqueOptions(_defaultGateTypes, _gateType);

    _workingStatuses = _buildUniqueOptions(
      _defaultWorkingStatuses,
      _workingStatus,
    );

    _shiftTimes = _buildUniqueOptions(_defaultShiftTimes, _shiftTime);
  }

  List<String> _buildUniqueOptions(List<String> defaults, String currentValue) {
    final values = <String>{};

    for (final value in defaults) {
      final cleaned = value.trim();

      if (cleaned.isNotEmpty) {
        values.add(cleaned);
      }
    }

    final current = currentValue.trim();

    if (current.isNotEmpty) {
      values.add(current);
    }

    return values.toList(growable: false);
  }

  Future<void> _handleUpdateGate() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _gateService.updateGate(
        gateId: widget.gate.id,
        gateName: _gateName.trim(),
        gateType: _gateType.trim(),
        workingStatus: _workingStatus.trim(),
        shiftTime: _shiftTime.trim(),
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update place'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place updated successfully'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update place: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF111111),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(20.w),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0EDFF),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.edit_location_alt,
                  color: const Color(0xFF0E4778),
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Edit Place',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Place Name'),
                  SizedBox(height: 8.h),

                  TextFormField(
                    initialValue: _gateName,
                    enabled: !_isLoading,
                    decoration: _dropdownDecoration().copyWith(
                      hintText: 'e.g., Main Entrance Gate',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter place name';
                      }

                      return null;
                    },
                    onSaved: (value) {
                      _gateName = value?.trim() ?? '';
                    },
                  ),

                  SizedBox(height: 16.h),

                  _fieldLabel('Place Type'),
                  SizedBox(height: 8.h),

                  DropdownButtonFormField<String>(
                    initialValue: _gateTypes.contains(_gateType)
                        ? _gateType
                        : null,
                    isExpanded: true,
                    decoration: _dropdownDecoration(),
                    items: _gateTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _gateType = value;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Select a place type';
                      }

                      return null;
                    },
                  ),

                  SizedBox(height: 16.h),

                  _fieldLabel('Working Status'),
                  SizedBox(height: 8.h),

                  DropdownButtonFormField<String>(
                    initialValue: _workingStatuses.contains(_workingStatus)
                        ? _workingStatus
                        : null,
                    isExpanded: true,
                    decoration: _dropdownDecoration(),
                    items: _workingStatuses
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _workingStatus = value;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Select working status';
                      }

                      return null;
                    },
                  ),

                  SizedBox(height: 16.h),

                  _fieldLabel('Shift Time'),
                  SizedBox(height: 8.h),

                  DropdownButtonFormField<String>(
                    initialValue: _shiftTimes.contains(_shiftTime)
                        ? _shiftTime
                        : null,
                    isExpanded: true,
                    decoration: _dropdownDecoration(),
                    items: _shiftTimes
                        .map(
                          (time) => DropdownMenuItem<String>(
                            value: time,
                            child: Text(time, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _shiftTime = value;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Select shift time';
                      }

                      return null;
                    },
                  ),

                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleUpdateGate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E4778),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Update Place'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
