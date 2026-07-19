// lib/src/modals/add_post_modal.dart
// Centered modal overlay for creating new posts with image upload

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/image_upload_flow_function.dart';

const Color kPrimary = Color(0xFF2563EB);
const Color kModalBackground = Color(0xFFFFFFFF);
const Color kOverlayDim = Color(0x5C000000);
const Color kInputBorder = Color(0xFFE6E6E6);
const Color kPlaceholderText = Color(0xFFBDBDBD);
const Color kHeaderText = Color(0xFF111111);
const Color kCloseIcon = Color(0xFF8C8C8C);
const double kModalRadius = 18.0;
const double kInputRadius = 12.0;

void showAddPostModal(BuildContext context, {required Function(String, String?) onSubmit}) {
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
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class AddPostModal extends StatefulWidget {
  final Function(String, String?) onSubmit;

  const AddPostModal({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<AddPostModal> createState() => _AddPostModalState();
}

class _AddPostModalState extends State<AddPostModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  File? _selectedImage;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      _showError('Failed to pick image');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    setState(() => _isUploadingImage = true);

    try {
      print('📤 Starting image upload for community wall...');
      final result = await ImageUploadFlowFunction().uploadImage(
        imagePath: _selectedImage!.path,
        folder: 'community_wall',
        publicId: 'post_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result.success && result.imageUrl != null) {
        print('✅ Image uploaded successfully: ${result.imageUrl}');
        setState(() {
          _uploadedImageUrl = result.imageUrl;
          _selectedImage = null;
        });
        _showSuccess('Image uploaded successfully');
      } else {
        print('❌ Upload failed: ${result.message}');
        _showError(result.message ?? 'Failed to upload image');
      }
    } catch (e) {
      print('❌ Error uploading image: $e');
      _showError('Failed to upload image');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_controller.text.trim().isEmpty && _uploadedImageUrl == null) return;
    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(_controller.text.trim(), _uploadedImageUrl);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('❌ Error submitting post: $e');
      _showError('Failed to create post');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        margin: EdgeInsets.only(top: 40, bottom: keyboardPadding > 0 ? keyboardPadding + 20 : 40),
        decoration: BoxDecoration(
          color: kModalBackground,
          borderRadius: BorderRadius.circular(kModalRadius),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Create your post', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kHeaderText)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      minLines: 6,
                      autofocus: true,
                      style: const TextStyle(fontSize: 15, color: kHeaderText),
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        hintStyle: const TextStyle(color: kPlaceholderText, fontSize: 15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kInputRadius), borderSide: const BorderSide(color: kInputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kInputRadius), borderSide: const BorderSide(color: kInputBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kInputRadius), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (_uploadedImageUrl != null) _buildImagePreview() else if (_selectedImage != null) _buildSelectedImagePreview() else _buildImageUploadButtons(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_controller.text.trim().isEmpty && _uploadedImageUrl == null) || _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          disabledBackgroundColor: kPrimary.withOpacity(0.5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text('Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kInputBorder, width: 1))),
      child: Row(
        children: [
          const Expanded(child: Text('Create Post', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: kHeaderText))),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kCloseIcon, size: 26), padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: kInputBorder), borderRadius: BorderRadius.circular(kInputRadius), color: const Color(0xFFFAFAFA)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildImageButton(icon: Icons.camera_alt, label: 'Camera', onPressed: () => _pickImage(ImageSource.camera)),
          Container(width: 1, height: 40, color: kInputBorder),
          _buildImageButton(icon: Icons.image, label: 'Gallery', onPressed: () => _pickImage(ImageSource.gallery)),
        ],
      ),
    );
  }

  Widget _buildImageButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: kPrimary, size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500))]),
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
          height: 150,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(kInputRadius), border: Border.all(color: kInputBorder)),
          child: Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(kInputRadius - 1), child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedImage = null),
                  child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _isUploadingImage ? null : _uploadImage,
            icon: _isUploadingImage ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.cloud_upload, size: 18),
            label: Text(_isUploadingImage ? 'Uploading...' : 'Upload Image'),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, disabledBackgroundColor: kPrimary.withOpacity(0.5), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
          height: 150,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(kInputRadius), border: Border.all(color: kInputBorder)),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kInputRadius - 1),
                child: Image.network(_uploadedImageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFF0F0F0), child: const Icon(Icons.image_not_supported, color: kPlaceholderText))),
              ),
              Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => setState(() => _uploadedImageUrl = null), child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
              Positioned(bottom: 8, right: 8, child: Container(decoration: BoxDecoration(color: Colors.green.withOpacity(0.8), shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.check, color: Colors.white, size: 16))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Image uploaded successfully', style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w500))),
            TextButton(onPressed: () => setState(() => _uploadedImageUrl = null), style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)), child: const Text('Remove', style: TextStyle(fontSize: 12))),
          ],
        ),
      ],
    );
  }
}
