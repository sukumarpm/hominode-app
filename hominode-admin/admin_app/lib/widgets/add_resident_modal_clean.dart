/// Add New Resident Modal - Simplified Version
///
/// A centered overlay modal for adding new residents to the society.
/// No unit number field - residents are added without flat assignment.
/// Flat assignment is done separately via Building Management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/phone_input_validation.dart';

// ============================================================================
// RESIDENT MODEL
// ============================================================================

class ResidentModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final int membersCount;
  final String residentType;

  ResidentModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.membersCount,
    required this.residentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'membersCount': membersCount,
      'residentType': residentType,
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
  final void Function(ResidentModel resident) onSubmit;

  const AddResidentModal({super.key, required this.onSubmit});

  /// Show the modal with fade and scale animation
  static Future<void> show(
    BuildContext context, {
    required void Function(ResidentModel resident) onSubmit,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close'.tr(),
      barrierColor: const Color(0x59000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddResidentModal(onSubmit: onSubmit);
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    if (_fullNameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;

    if (validateResidentPhoneInput(_phoneController.text) != null) return false;

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      if (!email.contains('@') || !email.contains('.')) return false;
    }

    final members = int.tryParse(_membersController.text.trim());
    if (members == null || members < 1) return false;

    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_fill_required_fields'.tr()),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final id = 'RES${DateTime.now().millisecondsSinceEpoch}';

      final resident = ResidentModel(
        id: id,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        membersCount: int.parse(_membersController.text.trim()),
        residentType: _residentType,
      );

      if (mounted) {
        widget.onSubmit(resident);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_add_resident_retry'.tr()),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInsets = MediaQuery.of(context).viewInsets;

    return Center(
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
                          _buildMembersField(),
                          SizedBox(height: 24.h),
                          _buildCredentialsInfo(),
                          SizedBox(height: 24.h),
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
              onTap: () => Navigator.of(context).pop(),
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
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 15.sp, color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: '+91 XXXXXX XXXXX',
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
            final error = validateResidentPhoneInput(value);
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
          : (value) => setState(() => _residentType = value ?? 'owner'),
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
                _buildBulletPoint('admin_creates_no_auth'.tr()),
                SizedBox(height: 8.h),
                Text(
                  'approval_pending_after_otp'.tr(),
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
    final isEnabled = _isFormValid && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
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
