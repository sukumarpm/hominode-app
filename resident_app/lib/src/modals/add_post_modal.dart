// lib/src/modals/add_post_modal.dart
// Centered modal overlay for creating new posts with image upload

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/resident_image_operations.dart';
import '../services/resident_private_images.dart';

const Color kPrimary = Color(0xFF172B4D);
const Color kModalBackground = Color(0xFFFCFDFE);
const Color kOverlayDim = Color(0x5C000000);
const Color kInputBorder = Color(0xFFDCE5EF);
const Color kPlaceholderText = Color(0xFFBDBDBD);
const Color kHeaderText = Color(0xFF111111);
const Color kCloseIcon = Color(0xFF8C8C8C);
const double kModalRadius = 22.0;
const double kInputRadius = 12.0;

void showAddPostModal(
  BuildContext context, {
  required Future<bool> Function(String, String?, String?) onSubmit,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Create Post',
    barrierColor: kOverlayDim,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return AddPostModal(onSubmit: onSubmit);
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.9,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

class AddPostModal extends StatefulWidget {
  final Future<bool> Function(String, String?, String?) onSubmit;

  final ResidentImageOperations? images;
  final Future<File?> Function(ImageSource)? pickImage;
  const AddPostModal({
    super.key,
    required this.onSubmit,
    this.images,
    this.pickImage,
  });

  @override
  State<AddPostModal> createState() => _AddPostModalState();
}

class _AddPostModalState extends State<AddPostModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  File? _selectedImage;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;
  late final _images = widget.images ?? ResidentImageOperations();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final File? selected;
      if (widget.pickImage != null) {
        selected = await widget.pickImage!(source);
      } else {
        final image = await ImagePicker().pickImage(
          source: source,
          maxWidth: 4096,
          maxHeight: 4096,
          imageQuality: 85,
        );
        selected = image == null ? null : File(image.path);
      }
      if (selected != null && mounted) {
        setState(() => _selectedImage = selected);
      }
    } catch (e) {
      _showError('Failed to pick image');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    setState(() => _isUploadingImage = true);

    try {
      final draft = await _images.createDraft('community_wall');
      final reference = await _images.upload(
        feature: 'community_wall',
        resourceId: draft,
        imagePath: _selectedImage!.path,
      );
      if (!mounted) return;
      {
        setState(() {
          _uploadedImageUrl = reference;
          _selectedImage = null;
        });
        _showSuccess('Image uploaded successfully');
      }
    } catch (e) {
      _showError('Failed to upload image');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_controller.text.trim().isEmpty && _uploadedImageUrl == null) return;
    setState(() => _isSubmitting = true);

    try {
      final draft = await _images.createDraft('community_wall');
      final saved = await widget.onSubmit(
        _controller.text.trim(),
        _uploadedImageUrl,
        draft,
      );
      if (mounted && saved) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to create post');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxWidth: 500.w),
        margin: EdgeInsets.only(
          top: 40.h,
          bottom: keyboardPadding > 0 ? keyboardPadding + 20 : 40,
        ),
        decoration: BoxDecoration(
          color: kModalBackground.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(kModalRadius),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF172B4D).withValues(alpha: .14),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create your post',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: kHeaderText,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      minLines: 6,
                      autofocus: true,
                      style: TextStyle(fontSize: 15.sp, color: kHeaderText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .92),
                        hintText: 'What\'s on your mind?',
                        hintStyle: TextStyle(
                          color: kPlaceholderText,
                          fontSize: 15.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kInputRadius),
                          borderSide: const BorderSide(color: kInputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kInputRadius),
                          borderSide: const BorderSide(color: kInputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kInputRadius),
                          borderSide: const BorderSide(
                            color: kPrimary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.all(16.w),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    SizedBox(height: 16.h),
                    if (_uploadedImageUrl != null)
                      _buildImagePreview()
                    else if (_selectedImage != null)
                      _buildSelectedImagePreview()
                    else
                      _buildImageUploadButtons(),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed:
                            (_controller.text.trim().isEmpty &&
                                    _uploadedImageUrl == null) ||
                                _isSubmitting ||
                                _isUploadingImage
                            ? null
                            : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          disabledBackgroundColor: kPrimary.withOpacity(0.5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 22.w,
                                height: 22.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Post',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
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
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 16.w, 20.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kInputBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Create Post',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21.sp,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 44.w,
            height: 44.h,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: kCloseIcon, size: 26.w),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadButtons() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        border: Border.all(color: kInputBorder),
        borderRadius: BorderRadius.circular(kInputRadius),
        color: const Color(0xFFFAFAFA),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildImageButton(
            icon: Icons.camera_alt,
            label: 'Camera',
            onPressed: () => _pickImage(ImageSource.camera),
          ),
          Container(width: 1.w, height: 40.h, color: kInputBorder),
          _buildImageButton(
            icon: Icons.image,
            label: 'Gallery',
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Widget _buildImageButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: kPrimary, size: 24.w),
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: kPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 150.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kInputRadius),
            border: Border.all(color: kInputBorder),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kInputRadius - 1),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedImage = null),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(4.w),
                    child: Icon(Icons.close, color: Colors.white, size: 16.w),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          height: 40.h,
          child: ElevatedButton.icon(
            onPressed: _isUploadingImage ? null : _uploadImage,
            icon: _isUploadingImage
                ? SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.cloud_upload, size: 18.w),
            label: Text(_isUploadingImage ? 'Uploading...' : 'Upload Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              disabledBackgroundColor: kPrimary.withOpacity(0.5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 150.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kInputRadius),
            border: Border.all(color: kInputBorder),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kInputRadius - 1),
                child: Image(
                  image: residentImageProvider(_uploadedImageUrl!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFF0F0F0),
                    child: const Icon(
                      Icons.image_not_supported,
                      color: kPlaceholderText,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _uploadedImageUrl = null),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(4.w),
                    child: Icon(Icons.close, color: Colors.white, size: 16.w),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(4.w),
                  child: Icon(Icons.check, color: Colors.white, size: 16.w),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Text(
                'Image uploaded successfully',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _uploadedImageUrl = null),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
              child: Text('Remove', style: TextStyle(fontSize: 12.sp)),
            ),
          ],
        ),
      ],
    );
  }
}
