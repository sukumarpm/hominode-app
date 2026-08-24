import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_service.dart';

class CloudinaryApartmentImagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _imagesCollection = 'apartmentImages';

  // Cloudinary configuration
  static const String CLOUDINARY_CLOUD_NAME = 'de8yccofb';
  static const String CLOUDINARY_UPLOAD_PRESET = 'lyvo_upload';
  static const String CLOUDINARY_API_KEY = 'bURO931bdHNXrqly6XPKaFK8eMA';
  static const String CLOUDINARY_API_URL =
      'https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload';

  // ==================== FLOW FUNCTION: Upload Image ====================
  /// Upload apartment image to Cloudinary and save metadata to Firestore
  Future<String> uploadImage({
    required String title,
    required String description,
    required String type,
    required File imageFile,
    required String buildingId,
    String? uploadDate,
    String? uploadTime,
  }) async {
    try {
      print('🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Starting image upload...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null || adminId.isEmpty) {
        print('❌ STEP 1 FAILED: Admin not authenticated or ID is empty');
        throw Exception('Admin not authenticated. Please log in again.');
      }
      print('✅ STEP 1 PASSED: Admin authenticated - $adminId');

      // STEP 2: Validate Input Data
      print('📋 STEP 2: Validating input data...');
      if (title.isEmpty) {
        print('❌ STEP 2 FAILED: Title is empty');
        throw Exception('Title cannot be empty');
      }
      if (!imageFile.existsSync()) {
        print(
          '❌ STEP 2 FAILED: Image file does not exist at ${imageFile.path}',
        );
        throw Exception('Image file does not exist');
      }
      final fileSize = imageFile.lengthSync();
      if (fileSize == 0) {
        print('❌ STEP 2 FAILED: Image file is empty');
        throw Exception('Image file is empty');
      }
      if (fileSize > 10 * 1024 * 1024) {
        print('❌ STEP 2 FAILED: Image file too large ($fileSize bytes)');
        throw Exception('Image file is too large (max 10MB)');
      }
      if (buildingId.isEmpty) {
        print('❌ STEP 2 FAILED: Building ID is empty');
        throw Exception('Building ID cannot be empty');
      }
      print(
        '✅ STEP 2 PASSED: Input data validated - File size: $fileSize bytes',
      );

      // STEP 3: Upload Image to Cloudinary
      print('📤 STEP 3: Uploading image to Cloudinary...');
      String imageUrl = '';
      try {
        print('📤 STEP 3.1: Preparing upload request...');
        print('📤 STEP 3.1a: File size: $fileSize bytes');
        print('📤 STEP 3.1b: Admin ID: $adminId');
        print('📤 STEP 3.1c: Building ID: $buildingId');
        print('📤 STEP 3.1d: Cloud Name: $CLOUDINARY_CLOUD_NAME');
        print('📤 STEP 3.1e: Upload Preset: $CLOUDINARY_UPLOAD_PRESET');

        // Create multipart request
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(CLOUDINARY_API_URL),
        );

        // Add file (REQUIRED)
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

        // Add upload preset (REQUIRED for unsigned uploads)
        request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;

        // Add folder for organization
        request.fields['folder'] = 'apartment_images';

        // Add tags for better organization
        request.fields['tags'] = 'apartment,admin,$adminId';

        // Add public ID for better organization
        request.fields['public_id'] =
            'apartment_${DateTime.now().millisecondsSinceEpoch}';

        print('📤 STEP 3.2: Sending upload request to Cloudinary...');
        print('📤 STEP 3.2a: URL: $CLOUDINARY_API_URL');

        var response = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Upload timeout - please try again');
          },
        );

        print('📤 STEP 3.2b: Response status: ${response.statusCode}');

        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);

        if (response.statusCode == 200) {
          print('📤 STEP 3.2c: Response received successfully');

          final jsonResponse = json.decode(responseString);

          imageUrl = jsonResponse['secure_url'] ?? '';

          if (imageUrl.isEmpty) {
            print('❌ STEP 3 FAILED: No secure_url in response');
            print('   Full response: $jsonResponse');
            throw Exception('Failed to get image URL from Cloudinary');
          }

          print('✅ STEP 3 PASSED: Image uploaded - $imageUrl');
        } else if (response.statusCode == 401) {
          print(
            '❌ STEP 3 FAILED: Upload failed with status 401 (Unauthorized)',
          );
          print('   Response body: $responseString');

          // 401 means preset doesn't exist or isn't unsigned
          String errorMessage =
              'Cloudinary error: Upload preset not configured\n\n';
          errorMessage += 'SOLUTION:\n';
          errorMessage += '1. Go to https://cloudinary.com/console\n';
          errorMessage += '2. Click Settings (gear icon)\n';
          errorMessage += '3. Click Upload tab\n';
          errorMessage += '4. Click "Add upload preset"\n';
          errorMessage += '5. Name: lyvo_upload\n';
          errorMessage += '6. Toggle Unsigned: ON\n';
          errorMessage += '7. Click Save\n';
          errorMessage += '8. Try uploading again';

          throw Exception(errorMessage);
        } else {
          print(
            '❌ STEP 3 FAILED: Upload failed with status ${response.statusCode}',
          );
          print('   Response body: $responseString');

          // Parse error details
          String errorMessage =
              'Cloudinary upload failed: ${response.statusCode}';
          try {
            final errorJson = json.decode(responseString);
            final error = errorJson['error'];
            if (error != null) {
              if (error is Map) {
                errorMessage =
                    'Cloudinary error: ${error['message'] ?? error.toString()}';
              } else {
                errorMessage = 'Cloudinary error: $error';
              }
              print('   Error details: $errorMessage');
            }
          } catch (e) {
            print('   Could not parse error response: $e');
          }

          // Provide specific guidance for common errors
          if (response.statusCode == 400) {
            errorMessage +=
                '\n\nFix: Check request format - upload_preset field may be missing or incorrect.';
          }

          throw Exception(errorMessage);
        }
      } catch (uploadError) {
        print('❌ STEP 3 FAILED: Cloudinary upload error');
        print('   Error type: ${uploadError.runtimeType}');
        print('   Error message: $uploadError');
        throw Exception('Failed to upload image to Cloudinary: $uploadError');
      }

      // STEP 4: Save Image Metadata to Firestore
      print('💾 STEP 4: Saving image metadata to Firestore...');
      String docId = '';
      try {
        print('💾 STEP 4.1: Fetching admin profile...');
        final adminProfile = await _adminService.getAdminProfile();

        String adminName = 'Admin';
        if (adminProfile != null) {
          adminName = adminProfile['name'] ?? 'Admin';
          print('💾 STEP 4.1a: Admin profile found - Name: $adminName');
        } else {
          print('⚠️ WARNING: Admin profile not found, using defaults');
        }

        print('💾 STEP 4.2: Creating Firestore document...');
        print('💾 STEP 4.2a: Collection: $_imagesCollection');
        print('💾 STEP 4.2b: Admin ID: $adminId');
        print('💾 STEP 4.2c: Building ID: $buildingId');

        final docRef = await _firestore.collection(_imagesCollection).add({
          'title': title,
          'description': description,
          'type': type,
          'imageUrl': imageUrl,
          'adminId': adminId,
          'communityId': _adminService.requireCurrentCommunityId(),
          'adminName': adminName,
          'buildingId': buildingId,
          'uploadDate': uploadDate ?? '',
          'uploadTime': uploadTime ?? '',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        docId = docRef.id;
        print('✅ STEP 4 PASSED: Image metadata saved - $docId');
      } catch (firestoreError) {
        print('❌ STEP 4 FAILED: Firestore save error - $firestoreError');
        throw Exception('Failed to save image metadata: $firestoreError');
      }

      // STEP 5: Log Completion
      print('🔔 STEP 5: Logging completion...');
      print('✅ CLOUDINARY APARTMENT IMAGES SERVICE: Image upload COMPLETE');
      return docId;
    } catch (e) {
      print('❌ ERROR: $e');
      rethrow;
    }
  }

  // ==================== FLOW FUNCTION: Get Images ====================
  /// Get all images for admin (real-time stream)
  Stream<List<ApartmentImageModel>> getImages() {
    try {
      print('🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Fetching images...');

      // STEP 1: Validate Admin Authentication
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        print('❌ STEP 1 FAILED: Admin not authenticated');
        return Stream.value([]);
      }
      print('✅ STEP 1 PASSED: Admin authenticated - $adminId');

      // STEP 2: Fetch Images from Firestore
      print('📋 STEP 2: Fetching images from Firestore...');
      return _firestore
          .collection(_imagesCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .snapshots()
          .map((snapshot) {
            print('✅ STEP 2 PASSED: Received ${snapshot.docs.length} images');

            // STEP 3: Transform Data
            final images = snapshot.docs.map((doc) {
              final data = doc.data();
              return ApartmentImageModel.fromFirestore(doc.id, data);
            }).toList();

            // Sort by creation date (newest first)
            images.sort((a, b) {
              final dateA = a.createdAt ?? DateTime.now();
              final dateB = b.createdAt ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            print(
              '✅ STEP 3 PASSED: Data transformed and sorted - Total: ${images.length} images',
            );
            return images;
          })
          .handleError((error) {
            print('❌ ERROR: $error');
            throw Exception('Failed to fetch images: $error');
          });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  // ==================== FLOW FUNCTION: Get Images for Building ====================
  /// Get active images for specific building (for resident app)
  Stream<List<ApartmentImageModel>> getImagesForBuilding(String buildingId) {
    try {
      print(
        '🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Fetching images for building - $buildingId',
      );

      // STEP 1: Validate Building ID
      if (buildingId.isEmpty) {
        print('❌ STEP 1 FAILED: Building ID is empty');
        return Stream.value([]);
      }
      print('✅ STEP 1 PASSED: Building ID validated');

      // STEP 2: Fetch Active Images
      print('📋 STEP 2: Fetching active images...');
      return _firestore
          .collection(_imagesCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('buildingId', isEqualTo: buildingId)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) {
            print('✅ STEP 2 PASSED: Received ${snapshot.docs.length} images');

            // STEP 3: Transform Data
            final images = snapshot.docs.map((doc) {
              final data = doc.data();
              return ApartmentImageModel.fromFirestore(doc.id, data);
            }).toList();

            // Sort by creation date (newest first)
            images.sort((a, b) {
              final dateA = a.createdAt ?? DateTime.now();
              final dateB = b.createdAt ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            print(
              '✅ STEP 3 PASSED: Filtered ${images.length} images for building',
            );
            return images;
          })
          .handleError((error) {
            print('❌ ERROR: $error');
            throw Exception('Failed to fetch images: $error');
          });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  // ==================== FLOW FUNCTION: Delete Image ====================
  /// Delete image and its metadata
  Future<void> deleteImage(String imageId) async {
    try {
      print(
        '🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Deleting image - $imageId',
      );

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        print('❌ STEP 1 FAILED: Admin not authenticated');
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Delete Image Metadata from Firestore
      print('💾 STEP 2: Deleting image metadata from Firestore...');
      await _firestore.collection(_imagesCollection).doc(imageId).delete();
      print('✅ STEP 2 PASSED: Image metadata deleted');

      // Note: Cloudinary image deletion can be done via API if needed
      // For now, we just delete the Firestore record

      print('✅ CLOUDINARY APARTMENT IMAGES SERVICE: Deletion COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to delete image: $e');
    }
  }
}

// ==================== Apartment Image Model ====================
class ApartmentImageModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final String imageUrl;
  final String adminId;
  final String adminName;
  final String buildingId;
  final String status;
  final String uploadDate;
  final String uploadTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ApartmentImageModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.adminId,
    required this.adminName,
    required this.buildingId,
    required this.status,
    required this.uploadDate,
    required this.uploadTime,
    this.createdAt,
    this.updatedAt,
  });

  factory ApartmentImageModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ApartmentImageModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'Common Area',
      imageUrl: data['imageUrl'] ?? '',
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? 'Admin',
      buildingId: data['buildingId'] ?? '',
      status: data['status'] ?? 'active',
      uploadDate: data['uploadDate'] ?? '',
      uploadTime: data['uploadTime'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
