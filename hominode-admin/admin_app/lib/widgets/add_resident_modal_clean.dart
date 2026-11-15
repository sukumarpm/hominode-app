/// Add New Resident Modal - Simplified Version
///
/// A centered overlay modal for adding new residents to the society.
/// Admin creation requires an explicitly selected vacant unit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../utils/phone_input_validation.dart';
import '../data/country_dial_codes.dart';
import '../services/resident_service.dart' show ResidentService;
import 'phone_country_picker.dart';
import 'resident_unit_selector.dart';
export 'resident_unit_selector.dart'
    show ResidentUnitOption, ResidentBuildingOption;

// ============================================================================
// RESIDENT MODEL
// ============================================================================

class ResidentModel {
  final String id;
  final String fullName;
  final String phone;
  final String? phoneCountryCode;
  final String email;
  final int membersCount;
  final String residentType;
  final String buildingId;
  final String flatId;

  ResidentModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.phoneCountryCode,
    required this.email,
    required this.membersCount,
    required this.residentType,
    required this.buildingId,
    required this.flatId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      if (phoneCountryCode != null) 'phoneCountryCode': phoneCountryCode,
      'email': email,
      'membersCount': membersCount,
      'residentType': residentType,
      'buildingId': buildingId,
      'flatId': flatId,
    };
  }

  @override
  String toString() {
    return 'ResidentModel(id: $id, fullName: $fullName, phone: $phone, email: $email, membersCount: $membersCount, residentType: $residentType)';
  }
}

// ============================================================================
// ADD RESIDENT MODAL
// ============================================================================

class AddResidentModal extends StatefulWidget {
  final Future<void> Function(ResidentModel resident) onSubmit;
  final Future<List<ResidentUnitOption>> Function()? loadUnits;
  final Future<List<ResidentBuildingOption>> Function()? loadBuildings;

  const AddResidentModal({
    super.key,
    required this.onSubmit,
    this.loadUnits,
    this.loadBuildings,
  });

  /// Show the modal with fade and scale animation
  static Future<ResidentModel?> show(
    BuildContext context, {
    required Future<void> Function(ResidentModel resident) onSubmit,
    Future<List<ResidentUnitOption>> Function()? loadUnits,
    Future<List<ResidentBuildingOption>> Function()? loadBuildings,
  }) {
    return showGeneralDialog<ResidentModel>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'close'.tr(),
      barrierColor: const Color(0x59000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddResidentModal(
          onSubmit: onSubmit,
          loadUnits: loadUnits,
          loadBuildings: loadBuildings,
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
  State<AddResidentModal> createState() => _AddResidentModalState();
}

class _AddResidentModalState extends State<AddResidentModal> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _membersController = TextEditingController(text: '4');

  bool _isSubmitting = false;
  String _residentType = 'owner';
  String? _phoneCountryCode;
  List<ResidentUnitOption> _units = [];
  ResidentUnitOption? _unit;
  String? _buildingId;
  List<ResidentBuildingOption> _buildings = [];
  bool _unitsLoading = true;
  String? _unitLoadError;
  final Map<String, String> _fieldErrors = {};
  String? _submitError;
  bool _hasSubmitted = false;

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors.remove(field));
    }
  }

  void _showSubmissionError(Object error) {
    final message = ResidentService.errorMessage(error);
    final code = error is FirebaseFunctionsException ? error.code : '';
    final details = error is FirebaseFunctionsException ? error.details : null;
    final field = details is Map ? details['field'] : null;
    final lower = message.toLowerCase();
    String? target;
    if ([
      'residentName',
      'phoneNumber',
      'email',
      'familyMembers',
      'flatId',
      'residentType',
    ].contains(field)) {
      target = field as String;
    } else if (code == 'already-exists' ||
        code == 'invalid-argument' && lower.contains('phone')) {
      target = 'phoneNumber';
    } else if ([
          'invalid-argument',
          'failed-precondition',
          'not-found',
        ].contains(code) &&
        (lower.contains('unit') ||
            lower.contains('building') ||
            lower.contains('flat'))) {
      target = 'flatId';
    }
    setState(() {
      if (target != null) {
        _fieldErrors[target] = message;
      } else {
        _submitError = ['unavailable', 'deadline-exceeded'].contains(code)
            ? 'Could not reach the Resident service. Check your connection and try again.'
            : message;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _openPhoneCountryPicker() async {
    final selected = await showPhoneCountryPicker(
      context,
      useAdminTheme: true,
      selectedCountry: kCountryDialCodes
          .where((country) => country.isoCode == _phoneCountryCode)
          .firstOrNull,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _phoneCountryCode = selected.isoCode;
      _fieldErrors.remove('phoneNumber');
    });
  }

  @override
  void initState() {
    super.initState();
    final region = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    _phoneCountryCode =
        kCountryDialCodes
            .where((country) => country.isoCode == region)
            .firstOrNull
            ?.isoCode ??
        'IN';
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await widget.loadUnits?.call() ?? <ResidentUnitOption>[];
      final buildings =
          await widget.loadBuildings?.call() ??
          [
            for (final entry in {
              for (final u in units)
                u.buildingId: u.buildingName.isEmpty
                    ? u.buildingId
                    : u.buildingName,
            }.entries)
              ResidentBuildingOption(id: entry.key, name: entry.value),
          ];
      if (mounted) {
        setState(() {
          _units = units;
          _buildings = buildings;
          _unitsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unitsLoading = false;
          _unitLoadError =
              'Units could not be loaded. Close this form and retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _hasSubmitted = true;
      _fieldErrors.clear();
      _submitError = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final id = 'RES${DateTime.now().millisecondsSinceEpoch}';

      final resident = ResidentModel(
        id: id,
        fullName: _fullNameController.text.trim(),
        phone: normalizeResidentPhoneInput(
          _phoneController.text,
          countryCode: _phoneCountryCode,
        ),
        phoneCountryCode: _phoneCountryCode,
        email: _emailController.text.trim(),
        membersCount: int.parse(_membersController.text.trim()),
        residentType: _residentType,
        buildingId: _unit!.buildingId,
        flatId: _unit!.flatId,
      );

      await widget.onSubmit(resident);
      if (mounted) Navigator.of(context).pop(resident);
    } catch (e) {
      if (mounted) _showSubmissionError(e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInsets = MediaQuery.of(context).viewInsets;

    return PopScope(
      canPop: !_isSubmitting,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth > 720 ? 720 : screenWidth * 0.92,
            maxHeight: screenHeight * 0.85,
          ),
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: keyboardInsets.bottom > 0
                          ? keyboardInsets.bottom + 12
                          : 20,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _hasSubmitted
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        onChanged: () => setState(() {}),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 18.h),
                            _buildFullNameField(),
                            SizedBox(height: 16.h),
                            _buildPhoneField(),
                            SizedBox(height: 16.h),
                            _buildEmailField(),
                            SizedBox(height: 16.h),
                            _buildResidentTypeField(),
                            SizedBox(height: 16.h),
                            ResidentUnitSelector(
                              buildings: _buildings,
                              units: _units,
                              buildingId: _buildingId,
                              unit: _unit,
                              disabled: _isSubmitting,
                              loading: _unitsLoading,
                              loadError: _unitLoadError,
                              unitError: () => _fieldErrors['flatId'],
                              onChanged: (buildingId, unit) => setState(() {
                                _buildingId = buildingId;
                                _unit = unit;
                                _fieldErrors.remove('flatId');
                              }),
                            ),
                            SizedBox(height: 16.h),
                            _buildMembersField(),
                            SizedBox(height: 24.h),
                            _buildCredentialsInfo(),
                            SizedBox(height: 24.h),
                            if (_submitError != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _submitError!,
                                  key: const ValueKey('resident-submit-error'),
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                            ],
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 16.h),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 40.w),
            child: Column(
              children: [
                Text(
                  'add_new_resident'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'add_new_resident_description'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: _isSubmitting ? null : () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                width: 40.w,
                height: 40.h,
                alignment: Alignment.center,
                child: Icon(Icons.close, color: Color(0xFF9CA3AF), size: 22.w),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'full_name'.tr(),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          key: const ValueKey('resident-name-input'),
          enabled: !_isSubmitting,
          onChanged: (_) => _clearFieldError('residentName'),
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 15.sp, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: 'enter_full_name'.tr(),
            hintStyle: TextStyle(fontSize: 15.sp, color: Color(0xFFD1D5DB)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (_fieldErrors['residentName'] != null) {
              return _fieldErrors['residentName'];
            }
            if (value == null || value.trim().isEmpty) {
              return 'full_name_required'.tr();
            }
            if (value.trim().length < 2) {
              return 'name_min_length'.tr();
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'phone_number'.tr(),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        PhoneCountrySelector(
          key: const ValueKey('resident-phone-country'),
          useAdminTheme: true,
          selectedCountry: kCountryDialCodes
              .where((country) => country.isoCode == _phoneCountryCode)
              .firstOrNull,
          disabled: _isSubmitting,
          onTap: _openPhoneCountryPicker,
        ),
        SizedBox(height: 8.h),
        TextFormField(
          key: const ValueKey('resident-phone-input'),
          enabled: !_isSubmitting,
          onChanged: (_) => _clearFieldError('phoneNumber'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 15.sp, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: '+63 917 123 4567 / +91 98765 43210',
            hintStyle: TextStyle(fontSize: 15.sp, color: Color(0xFFD1D5DB)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (_fieldErrors['phoneNumber'] != null) {
              return _fieldErrors['phoneNumber'];
            }
            final error = validateResidentPhoneInput(
              value,
              countryCode: _phoneCountryCode,
            );
            return switch (error) {
              null => null,
              'Phone number is required' => 'phone_number_required'.tr(),
              'Enter a valid phone number. Use digits and standard phone formatting.' =>
                'invalid_phone_format'.tr(),
              'Enter a valid phone number with 7 to 15 digits.' =>
                'invalid_phone_length'.tr(),
              _ => error,
            };
          },
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'email'.tr(),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          key: const ValueKey('resident-email-input'),
          enabled: !_isSubmitting,
          onChanged: (_) => _clearFieldError('email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 15.sp, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: 'email@example.com',
            hintStyle: TextStyle(fontSize: 15.sp, color: Color(0xFFD1D5DB)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (_fieldErrors['email'] != null) return _fieldErrors['email'];
            if (value != null && value.trim().isNotEmpty) {
              if (!value.contains('@') || !value.contains('.')) {
                return 'valid_email'.tr();
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMembersField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'number_of_members'.tr(),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          key: const ValueKey('resident-members-input'),
          enabled: !_isSubmitting,
          onChanged: (_) => _clearFieldError('familyMembers'),
          controller: _membersController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(fontSize: 15.sp, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: '4',
            hintStyle: TextStyle(fontSize: 15.sp, color: Color(0xFFD1D5DB)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
          validator: (value) {
            if (_fieldErrors['familyMembers'] != null) {
              return _fieldErrors['familyMembers'];
            }
            if (value == null || value.trim().isEmpty) {
              return 'members_required'.tr();
            }
            final number = int.tryParse(value.trim());
            if (number == null || number < 1) {
              return 'at_least_one_member'.tr();
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildResidentTypeField() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('resident-type'),
      initialValue: _residentType,
      decoration: InputDecoration(
        labelText: 'resident_type'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      items: [
        DropdownMenuItem(value: 'owner', child: Text('owner'.tr())),
        DropdownMenuItem(value: 'tenant', child: Text('tenant'.tr())),
      ],
      onChanged: _isSubmitting
          ? null
          : (value) => setState(() {
              _residentType = value ?? 'owner';
              _fieldErrors.remove('residentType');
            }),
      validator: (_) => _fieldErrors['residentType'],
    );
  }

  Widget _buildCredentialsInfo() {
    final phone = _phoneController.text.trim();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFF061C4C), size: 22.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'otp_registration'.tr(),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF061C4C),
                  ),
                ),
                SizedBox(height: 8.h),
                _buildBulletPoint(
                  phone.isNotEmpty
                      ? 'resident_registers_with_phone'.tr(
                          namedArgs: {'phone': phone},
                        )
                      : 'resident_registers_with_phone_above'.tr(),
                ),
                SizedBox(height: 4.h),
                _buildBulletPoint(
                  'The Resident must sign in with their own phone OTP. No password or session is issued.',
                ),
                SizedBox(height: 8.h),
                Text(
                  'Admin creation assigns the Resident directly. Required identity verification still applies.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Color(0xFF061C4C),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            fontSize: 14.sp,
            color: Color(0xFF061C4C),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: Color(0xFF061C4C),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        key: const ValueKey('resident-save'),
        onPressed: isEnabled ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          disabledBackgroundColor: const Color(0x662563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'add_resident'.tr(),
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
