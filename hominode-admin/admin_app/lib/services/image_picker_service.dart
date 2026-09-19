import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  static const int maxFacilityImages = 6;
  static const double maxFacilityImageSizeMB = 5.0;

  /// Shows a source chooser without the previous double-pop behavior.
  ///
  /// This legacy method still returns File? so existing callers remain intact.
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how you want to select an image',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),
                _buildSourceOption(
                  context: sheetContext,
                  icon: Icons.camera_alt,
                  title: 'Camera',
                  subtitle: 'Take a new photo',
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                const SizedBox(height: 12),
                _buildSourceOption(
                  context: sheetContext,
                  icon: Icons.photo_library,
                  title: 'Gallery',
                  subtitle: 'Choose from existing photos',
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return null;

    final image = source == ImageSource.camera
        ? await pickXFileFromCamera()
        : await pickXFileFromGallery();

    return image == null ? null : File(image.path);
  }

  static Widget _buildSourceOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  /// New facility-image API. Uses XFile so the caller can upload bytes through
  /// Firebase Storage and is not tied to putFile().
  static Future<XFile?> pickXFileFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (error) {
      debugPrint('Error picking image from camera: $error');
      return null;
    }
  }

  static Future<XFile?> pickXFileFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (error) {
      debugPrint('Error picking image from gallery: $error');
      return null;
    }
  }

  /// Selects multiple gallery photos. image_picker 1.0.x does not expose a
  /// portable hard selection limit, so we cap the returned list to maxImages.
  static Future<List<XFile>> pickMultipleFromGallery({
    int maxImages = maxFacilityImages,
  }) async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (maxImages <= 0) return const [];
      return images.take(maxImages).toList(growable: false);
    } catch (error) {
      debugPrint('Error picking multiple images from gallery: $error');
      return const [];
    }
  }

  /// Legacy direct camera access.
  static Future<File?> pickFromCamera() async {
    final image = await pickXFileFromCamera();
    return image == null ? null : File(image.path);
  }

  /// Legacy direct gallery access.
  static Future<File?> pickFromGallery() async {
    final image = await pickXFileFromGallery();
    return image == null ? null : File(image.path);
  }

  /// Legacy File validation retained for existing callers.
  static bool isValidImageFile(File file) {
    return isSupportedFacilityImageName(file.path);
  }

  static bool isSupportedFacilityImageName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static Future<String?> facilityImageValidationError(XFile file) async {
    if (!isSupportedFacilityImageName(
      file.name.isNotEmpty ? file.name : file.path,
    )) {
      return 'Facility photos must be JPG, PNG, or WebP.';
    }

    final size = await file.length();
    if (size > maxFacilityImageSizeMB * 1024 * 1024) {
      return 'Each facility photo must be 5 MB or smaller.';
    }

    return null;
  }

  /// Get image file size in MB.
  static double getImageSizeInMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  static bool isImageSizeValid(
    File file, {
    double maxSizeMB = maxFacilityImageSizeMB,
  }) {
    return getImageSizeInMB(file) <= maxSizeMB;
  }
}
