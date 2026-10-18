import '../utils/resident_phone.dart';
import 'package:resident_app/src/services/resident_private_images.dart';
// lib/src/screens/edit_profile_screen.dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_image_service.dart';
import '../services/profile_diagnostics.dart';
import '../services/user_data_service.dart';
import '../widgets/resident_visitor_page_background.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.profileLoader,
    this.profileSaver,
    this.photoUploader,
    this.photoPicker,
  });

  @visibleForTesting
  final Future<Map<String, dynamic>?> Function()? profileLoader;
  @visibleForTesting
  final Future<bool> Function(Map<String, dynamic>)? profileSaver;
  @visibleForTesting
  final Future<ProfileImageResult> Function(String)? photoUploader;
  @visibleForTesting
  final Future<String?> Function()? photoPicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final UserDataService? _userDataService;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _flatNumberController;

  String? _photoUrl;
  File? _photoFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userDataService = widget.profileLoader == null ? UserDataService() : null;
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _flatNumberController = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = widget.profileLoader != null
          ? await widget.profileLoader!()
          : await _userDataService!.getCurrentUserData(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (data == null) return;
        _nameController.text = data['name'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? '';
        _phoneController.text = residentDisplayPhone(data);
        _flatNumberController.text =
            data['flatLabel'] as String? ?? data['flatId'] as String? ?? '';
        _photoUrl = ProfileImageService.fromData(data).imageUrl;
      });
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_not_found_contact_admin'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      logProfileFailure('profile-load', error);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('edit_profile_load_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _flatNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('edit_profile_title'.tr()),
        backgroundColor: Colors.white.withValues(alpha: 0.82),
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: const Color(0xFF172B4D),
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: ResidentVisitorPageBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(color: const Color(0xFFE2EAF3)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF172B4D,
                          ).withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildPhotoSection(),
                          SizedBox(height: 24.h),
                          _buildTextField(
                            label: 'full_name'.tr(),
                            controller: _nameController,
                            hint: 'enter_your_name'.tr(),
                            icon: Icons.person_outline,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            label: 'email'.tr(),
                            controller: _emailController,
                            hint: 'enter_your_email'.tr(),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            enabled: true, // Enabled for editing
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null; // Email is optional for phone-auth residents.
                              }
                              final emailRegex = RegExp(
                                r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'invalid_email_address'.tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            label: 'phone'.tr(),
                            controller: _phoneController,
                            hint: 'enter_your_phone'.tr(),
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            enabled:
                                false, // Phone changes require OTP re-verification
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            label: 'flat_number'.tr(),
                            controller: _flatNumberController,
                            hint: 'flat_number_example'.tr(),
                            icon: Icons.home_outlined,
                            enabled:
                                false, // Flat/unit assignment is managed by Admin
                          ),
                          SizedBox(height: 32.h),
                          _buildSaveButton(),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0E7FF),
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: ClipOval(
                  child: _photoFile != null
                      ? Image.file(_photoFile!, fit: BoxFit.cover)
                      : _photoUrl != null
                      ? Image(
                          image: residentImageProvider(_photoUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.person),
                        )
                      : Icon(
                          Icons.person,
                          size: 50.w,
                          color: const Color(0xFF0E4778),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E4778),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18.w,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'tap_to_change_photo'.tr(),
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          validator:
              validator ??
              (value) {
                if (!enabled) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'field_required'.tr(namedArgs: {'field': label});
                }
                return null;
              },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF0E4778), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          disabledBackgroundColor: const Color(0xFF93C5FD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'save_changes'.tr(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      if (widget.photoPicker != null) {
        final path = await widget.photoPicker!();
        if (mounted && path != null) setState(() => _photoFile = File(path));
        return;
      }
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'select_photo_source'.tr(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 20.h),
                ListTile(
                  leading: Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF0E4778),
                    ),
                  ),
                  title: Text('camera'.tr()),
                  subtitle: Text('take_new_photo'.tr()),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                SizedBox(height: 8.h),
                ListTile(
                  leading: Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  title: Text('gallery'.tr()),
                  subtitle: Text('choose_from_gallery'.tr()),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _photoFile = File(image.path);
            _photoUrl = image.path;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('photo_selection_error'.tr())));
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('Resident profile: stage=save-start');
    setState(() => _isSaving = true);

    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();

      // STEP 1: Prepare updates for Firestore
      debugPrint('Resident profile: stage=display-fields');
      final updates = <String, dynamic>{'name': newName, 'email': newEmail};

      // Ordinary profile fields do not depend on photo attestation. An empty
      // email explicitly clears the old display email, without changing Auth.
      debugPrint('Resident profile: stage=profile-write');
      final success = widget.profileSaver != null
          ? await widget.profileSaver!(updates)
          : await _userDataService!.updateUserData(updates);
      if (!success) {
        throw StateError('Profile update failed');
      }
      if (!mounted) return;

      // Only a pending private photo enters App Check verification.
      if (_photoFile != null) {
        final imageResult = widget.photoUploader != null
            ? await widget.photoUploader!(_photoFile!.path)
            : await ProfileImageService.instance.uploadProfileImage(
                imagePath: _photoFile!.path,
              );

        if (imageResult.success && imageResult.imageUrl != null) {
          _photoUrl = imageResult.imageUrl;
          _photoFile = null;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${'profile_details_saved'.tr()} '
                  '${(imageResult.errorCode == 'APP_CHECK_UNAVAILABLE' ? 'profile_device_verification_failed' : 'profile_photo_upload_failed').tr()}',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_updated_successfully'.tr()),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      logProfileFailure('profile-save', error);
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_update_failed'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
