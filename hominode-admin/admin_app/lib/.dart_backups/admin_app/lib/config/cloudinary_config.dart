/// Cloudinary Configuration
class CloudinaryConfig {
  // Your Cloudinary credentials
  static const String cloudName = 'de8yccofb';
  static const String apiKey = 'REDACTED_CLOUDINARY_PRIVATE_CREDENTIAL';
  static const String apiSecret = 'REDACTED_CLOUDINARY_PRIVATE_CREDENTIAL';
  
  // Upload preset - Use the existing working preset
  static const String uploadPreset = 'lyvo_upload'; // Using existing preset that works
  
  // Cloudinary upload URL
  static String get uploadUrl => 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
