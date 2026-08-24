import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String cloudName = 'de8yccofb';
  static const String apiKey = '866472317169594';
  static const String apiSecret = 'bURO931bdHNXrqly6XPKaFK8eMA';
  static const String uploadPreset = 'resident_app_upload';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/de8yccofb/image/upload';
  static const String profilePicturesFolder = 'profile_pictures';

  /// Upload image to Cloudinary and return the secure URL
  /// Stores in profile_pictures folder by default
  static Future<String> uploadImage({
    required String imagePath,
    String? folder,
    String? publicId,
  }) async {
    try {
      print('🔵 CloudinaryService: Starting upload...');
      print('   Cloud Name: $cloudName');
      print('   Upload URL: $uploadUrl');
      print('   Image Path: $imagePath');
      
      // Use profile_pictures folder by default
      final finalFolder = folder ?? profilePicturesFolder;
      print('   Folder: $finalFolder');
      print('   Public ID: $publicId');

      final file = File(imagePath);
      
      if (!file.existsSync()) {
        print('❌ CloudinaryService: File not found: $imagePath');
        throw Exception('Image file not found at path: $imagePath');
      }

      print('✅ CloudinaryService: File exists');
      print('   File size: ${file.lengthSync()} bytes');

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      // Add file
      print('📤 CloudinaryService: Adding file to request...');
      request.files.add(
        await http.MultipartFile.fromPath('file', imagePath),
      );

      // Add upload preset (REQUIRED for unsigned uploads)
      request.fields['upload_preset'] = uploadPreset;
      print('   ✅ Upload preset: $uploadPreset');

      // Add API key
      request.fields['api_key'] = apiKey;
      print('   ✅ API key: $apiKey');

      // Add folder (REQUIRED for organization)
      request.fields['folder'] = finalFolder;
      print('   ✅ Folder: $finalFolder');

      // Add public ID if provided
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
        print('   ✅ Public ID: $publicId');
      }

      // Add resource type
      request.fields['resource_type'] = 'auto';
      print('   ✅ Resource type: auto');

      // Send request
      print('📡 CloudinaryService: Sending request to Cloudinary...');
      print('   URL: $uploadUrl');
      print('   Fields: upload_preset=$uploadPreset, api_key=$apiKey, folder=$finalFolder');
      
      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ CloudinaryService: Upload timeout');
          throw Exception('Upload timeout - image took too long to upload');
        },
      );

      print('📥 CloudinaryService: Response received');
      print('   Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        print('   Response body: $responseString');
        
        final jsonResponse = jsonDecode(responseString);
        
        // Verify response has required fields
        if (jsonResponse['secure_url'] == null && jsonResponse['url'] == null) {
          print('❌ CloudinaryService: No URL in response');
          throw Exception('Cloudinary response missing URL');
        }
        
        // Return secure URL
        final secureUrl = jsonResponse['secure_url'] ?? jsonResponse['url'];
        final publicIdResponse = jsonResponse['public_id'];
        
        print('✅ CloudinaryService: Upload successful');
        print('   Secure URL: $secureUrl');
        print('   Public ID: $publicIdResponse');
        print('   Folder: ${jsonResponse['folder']}');
        print('   Version: ${jsonResponse['version']}');
        
        return secureUrl;
      } else {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        print('❌ CloudinaryService: Upload failed');
        print('   Status: ${response.statusCode}');
        print('   Response: $responseString');
        throw Exception('Upload failed: ${response.statusCode} - $responseString');
      }
    } catch (e, stackTrace) {
      print('❌ CloudinaryService: Error: $e');
      print('   Stack trace: $stackTrace');
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Upload image and get metadata
  static Future<Map<String, dynamic>> uploadImageWithMetadata({
    required String imagePath,
    String? folder,
    String? publicId,
  }) async {
    try {
      print('🔵 CloudinaryService: Uploading with metadata...');
      
      final file = File(imagePath);
      
      if (!file.existsSync()) {
        print('❌ CloudinaryService: File not found');
        throw Exception('Image file not found at path: $imagePath');
      }

      // Use profile_pictures folder by default
      final finalFolder = folder ?? profilePicturesFolder;

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      request.files.add(
        await http.MultipartFile.fromPath('file', imagePath),
      );

      // Add upload preset (REQUIRED)
      request.fields['upload_preset'] = uploadPreset;

      request.fields['api_key'] = apiKey;

      // Add folder (REQUIRED)
      request.fields['folder'] = finalFolder;

      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }

      request.fields['resource_type'] = 'auto';

      print('📡 CloudinaryService: Sending metadata upload request...');
      print('   Folder: $finalFolder');
      
      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ CloudinaryService: Metadata upload timeout');
          throw Exception('Upload timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonResponse = jsonDecode(responseString);
        
        print('✅ CloudinaryService: Metadata upload successful');
        print('   Folder: ${jsonResponse['folder']}');
        
        return {
          'url': jsonResponse['secure_url'] ?? jsonResponse['url'],
          'publicId': jsonResponse['public_id'],
          'width': jsonResponse['width'],
          'height': jsonResponse['height'],
          'size': jsonResponse['bytes'],
          'format': jsonResponse['format'],
          'folder': jsonResponse['folder'],
          'uploadedAt': DateTime.now().toIso8601String(),
        };
      } else {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        print('❌ CloudinaryService: Metadata upload failed: ${response.statusCode}');
        throw Exception('Upload failed: ${response.statusCode} - $responseString');
      }
    } catch (e, stackTrace) {
      print('❌ CloudinaryService: Metadata upload error: $e');
      print('   Stack trace: $stackTrace');
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Delete image from Cloudinary
  static Future<bool> deleteImage(String publicId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy'),
      );

      request.fields['public_id'] = publicId;
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp.toString();

      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Cloudinary delete error: $e');
    }
  }
}
