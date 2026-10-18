// Legacy call-site guard. Existing remote image references are not altered.
// Phase 2 replaces URL-only callers with FirebaseImageUploadService.
class CloudinaryService {
  static const String cloudName = 'de8yccofb';
  static const String apiKey = '866472317169594';
  static const String uploadPreset = 'resident_app_upload';
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/de8yccofb/image/upload';
  static const String profilePicturesFolder = 'profile_pictures';

  static Never _unavailable() => throw StateError(
    'Photo uploads are temporarily unavailable while secure storage is enabled.',
  );

  static Future<String> uploadImage({
    required String imagePath,
    String? folder,
    String? publicId,
  }) async => _unavailable();

  static Future<Map<String, dynamic>> uploadImageWithMetadata({
    required String imagePath,
    String? folder,
    String? publicId,
  }) async => _unavailable();

  // Never claim an external deletion succeeded or issue provider requests.
  static Future<bool> deleteImage(String publicId) async => _unavailable();
}
