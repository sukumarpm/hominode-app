import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'admin_service.dart';
import '../config/cloudinary_config.dart';

class PosterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _postersCollection = 'posters';

  // ==================== UPLOAD POSTER ====================
  /// Upload poster image to Cloudinary and save metadata to Firestore
  Future<String> uploadPoster({
    required File imageFile,
    required String buildingId,
    String? title,
  }) async {
    try {
      print('🔵 POSTER SERVICE: Starting poster upload...');

      // STEP 1: Validate Admin Authentication
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not authenticated');
      print('✅ STEP 1: Admin authenticated - $adminId');

      // STEP 2: Upload to Cloudinary
      print('📤 STEP 2: Uploading to Cloudinary...');
      final imageUrl = await _uploadToCloudinary(imageFile);
      print('✅ STEP 2: Image uploaded - $imageUrl');

      // STEP 3: Save to Firestore
      print('💾 STEP 3: Saving to Firestore...');
      final docRef = await _firestore.collection(_postersCollection).add({
        'imageUrl': imageUrl,
        'buildingId': buildingId,
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'title': title ?? 'Poster',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ STEP 3: Poster saved - ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to upload poster: $e');
    }
  }

  // ==================== DELETE POSTER ====================
  /// Delete poster from Firestore
  Future<void> deletePoster(String posterId) async {
    try {
      print('🗑️ POSTER SERVICE: Deleting poster - $posterId');

      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not authenticated');

      await _firestore.collection(_postersCollection).doc(posterId).delete();
      print('✅ Poster deleted successfully');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to delete poster: $e');
    }
  }

  // ==================== GET POSTERS ====================
  /// Get all posters for a building (real-time stream)
  Stream<List<PosterModel>> getPostersForBuilding(String buildingId) {
    try {
      print('🔵 POSTER SERVICE: Fetching posters for building - $buildingId');

      return _firestore
          .collection(_postersCollection)
          .where('buildingId', isEqualTo: buildingId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            print('✅ Received ${snapshot.docs.length} posters');
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return PosterModel.fromFirestore(doc.id, data);
            }).toList();
          })
          .handleError((error) {
            print('❌ ERROR: $error');
            throw Exception('Failed to fetch posters: $error');
          });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  /// Get all posters for admin
  Stream<List<PosterModel>> getAdminPosters() {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) return Stream.value([]);

      print('🔵 POSTER SERVICE: Fetching posters for admin - $adminId');

      return _firestore
          .collection(_postersCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            print('✅ Received ${snapshot.docs.length} posters');
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return PosterModel.fromFirestore(doc.id, data);
            }).toList();
          })
          .handleError((error) {
            print('❌ ERROR: $error');
            throw Exception('Failed to fetch posters: $error');
          });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  // ==================== HELPER METHODS ====================
  /// Upload image to Cloudinary
  Future<String> _uploadToCloudinary(File imageFile) async {
    try {
      print('📤 Uploading to Cloudinary...');

      // Validate file
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = imageFile.lengthSync();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      print('📤 File size: $fileSize bytes');
      print('📤 Cloud Name: ${CloudinaryConfig.cloudName}');
      print('📤 Upload Preset: ${CloudinaryConfig.uploadPreset}');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      // Add file (REQUIRED)
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Add upload preset (REQUIRED for unsigned uploads)
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['folder'] = 'posters';

      print('📤 Sending request to Cloudinary...');

      // Send request with timeout
      var response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Upload timeout - please try again');
        },
      );

      print('📤 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);

        print('📤 Response received: ${responseString.substring(0, 100)}...');

        // Parse JSON response
        final Map<String, dynamic> jsonResponse = _parseJsonResponse(
          responseString,
        );

        final imageUrl = jsonResponse['secure_url'] ?? jsonResponse['url'];

        if (imageUrl == null) {
          print('❌ No URL in response: $jsonResponse');
          throw Exception('No URL in Cloudinary response');
        }

        print('✅ Cloudinary URL: $imageUrl');
        return imageUrl;
      } else {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        print('❌ Cloudinary error response: $responseString');
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode} - $responseString',
        );
      }
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      throw Exception('Failed to upload to Cloudinary: $e');
    }
  }

  /// Parse JSON response (simple parser to avoid json dependency issues)
  Map<String, dynamic> _parseJsonResponse(String jsonString) {
    try {
      // Simple JSON parsing for Cloudinary response
      final Map<String, dynamic> result = {};

      // Extract secure_url
      final secureUrlMatch = RegExp(
        r'"secure_url":"([^"]+)"',
      ).firstMatch(jsonString);
      if (secureUrlMatch != null) {
        result['secure_url'] = secureUrlMatch.group(1);
      }

      // Extract url
      final urlMatch = RegExp(r'"url":"([^"]+)"').firstMatch(jsonString);
      if (urlMatch != null) {
        result['url'] = urlMatch.group(1);
      }

      // Extract public_id
      final publicIdMatch = RegExp(
        r'"public_id":"([^"]+)"',
      ).firstMatch(jsonString);
      if (publicIdMatch != null) {
        result['public_id'] = publicIdMatch.group(1);
      }

      return result;
    } catch (e) {
      print('❌ JSON parse error: $e');
      return {};
    }
  }
}

// ==================== POSTER MODEL ====================
class PosterModel {
  final String id;
  final String imageUrl;
  final String buildingId;
  final String adminId;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PosterModel({
    required this.id,
    required this.imageUrl,
    required this.buildingId,
    required this.adminId,
    required this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory PosterModel.fromFirestore(String id, Map<String, dynamic> data) {
    return PosterModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      buildingId: data['buildingId'] ?? '',
      adminId: data['adminId'] ?? '',
      title: data['title'] ?? 'Poster',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'buildingId': buildingId,
      'adminId': adminId,
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
