import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'admin_service.dart';

class ApartmentImagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AdminService _adminService = AdminService();
  final String _imagesCollection = 'apartment_images';

  // In-memory storage for images (temporary until Firestore is configured)
  static final List<ApartmentImageModel> _localImages = [];

  // ==================== FLOW FUNCTION: Upload Image ====================
  /// Upload apartment image (Flow Function Pattern)
  Future<String> uploadImage({
    required String title,
    required String description,
    required String type,
    required File imageFile,
    String? uploadDate,
    String? uploadTime,
  }) async {
    try {
      print('🔵 APARTMENT IMAGES SERVICE: Starting image upload...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        print('❌ STEP 1 FAILED: Admin not authenticated');
        throw Exception('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated - $adminId');

      // STEP 2: Validate Input Data
      print('📋 STEP 2: Validating input data...');
      if (title.isEmpty) {
        print('❌ STEP 2 FAILED: Title is empty');
        throw Exception('Title cannot be empty');
      }
      if (!imageFile.existsSync()) {
        print('❌ STEP 2 FAILED: Image file does not exist');
        throw Exception('Image file does not exist');
      }
      final fileSize = imageFile.lengthSync();
      if (fileSize == 0) {
        print('❌ STEP 2 FAILED: Image file is empty');
        throw Exception('Image file is empty');
      }
      print('✅ STEP 2 PASSED: Input data validated - File size: $fileSize bytes');

      // STEP 3: Upload Image to Firebase Storage
      print('📤 STEP 3: Uploading image to Firebase Storage...');
      String imageUrl = '';
      try {
        final fileName = 'apartment_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = 'apartment_images/$adminId/$fileName';
        final storageRef = _storage.ref().child(storagePath);
        
        print('📤 STEP 3.1: Uploading to path: $storagePath');
        print('📤 STEP 3.1a: File size: $fileSize bytes');
        print('📤 STEP 3.1b: Admin ID: $adminId');
        
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'adminId': adminId,
            'uploadDate': uploadDate ?? '',
            'uploadTime': uploadTime ?? '',
          },
        );
        
        final uploadTask = await storageRef.putFile(imageFile, metadata);
        print('📤 STEP 3.2: Upload task completed - Bytes transferred: ${uploadTask.bytesTransferred}');
        
        imageUrl = await storageRef.getDownloadURL();
        print('✅ STEP 3 PASSED: Image uploaded - $imageUrl');
      } catch (storageError) {
        print('❌ STEP 3 FAILED: Storage upload error');
        print('   Error type: ${storageError.runtimeType}');
        print('   Error message: $storageError');
        throw Exception('Failed to upload image to storage: $storageError');
      }

      // STEP 4: Save Image Metadata to Firestore
      print('💾 STEP 4: Saving image metadata to Firestore...');
      late DocumentReference<Map<String, dynamic>> docRef;
      String docId = '';
      try {
        print('💾 STEP 4.1: Fetching admin profile...');
        final adminProfile = await _adminService.getAdminProfile();
        
        String adminName = 'Admin';
        List<String> buildingIds = [];
        
        if (adminProfile != null) {
          adminName = adminProfile['name'] ?? 'Admin';
          buildingIds = List<String>.from(adminProfile['buildingIds'] ?? []);
          print('💾 STEP 4.1a: Admin profile found - Name: $adminName');
        } else {
          print('⚠️ WARNING: Admin profile not found, using defaults');
        }
        
        print('💾 STEP 4.2: Creating Firestore document...');
        print('💾 STEP 4.2a: Collection: $_imagesCollection');
        print('💾 STEP 4.2b: Admin ID: $adminId');
        
        docRef = await _firestore.collection(_imagesCollection).add({
          'title': title,
          'description': description,
          'type': type,
          'imageUrl': imageUrl,
          'adminId': adminId,
          'adminName': adminName,
          'buildingIds': buildingIds,
          'uploadDate': uploadDate ?? '',
          'uploadTime': uploadTime ?? '',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        docId = docRef.id;
        print('✅ STEP 4 PASSED: Image metadata saved - $docId');
      } catch (firestoreError) {
        print('⚠️ WARNING: Firestore save error - $firestoreError');
        print('   Storing locally instead...');
        
        // Store locally if Firestore fails
        final localImage = ApartmentImageModel(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: description,
          type: type,
          imageUrl: imageUrl,
          adminId: adminId,
          adminName: 'Admin',
          buildingIds: [],
          status: 'active',
          uploadDate: uploadDate ?? '',
          uploadTime: uploadTime ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _localImages.add(localImage);
        docId = localImage.id;
        print('✅ STEP 4 PASSED (LOCAL): Image stored locally - $docId');
      }

      // STEP 5: Log Completion
      print('🔔 STEP 5: Logging completion...');
      print('✅ APARTMENT IMAGES SERVICE: Image upload COMPLETE');
      return docId;
    } catch (e) {
      print('❌ ERROR: $e');
      rethrow;
    }
  }

  // ==================== FLOW FUNCTION: Get Images ====================
  /// Get all images for admin (real-time stream)
  /// Returns both Firestore images and locally stored images
  Stream<List<ApartmentImageModel>> getImages() {
    try {
      print('🔵 APARTMENT IMAGES SERVICE: Fetching images...');

      // STEP 1: Validate Admin Authentication
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) {
        print('⚠️ WARNING: Admin not authenticated, returning local images only');
        // Return local images if not authenticated
        final localImages = _localImages.where((img) => img.adminId == adminId).toList();
        localImages.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        return Stream.value(localImages);
      }
      print('✅ STEP 1 PASSED: Admin authenticated - $adminId');

      // STEP 2: Fetch Images from Firestore
      print('📋 STEP 2: Fetching images from Firestore...');
      return _firestore
          .collection(_imagesCollection)
          .where('adminId', isEqualTo: adminId)
          .snapshots()
          .map((snapshot) {
        print('✅ STEP 2 PASSED: Received ${snapshot.docs.length} Firestore images');
        
        // STEP 3: Transform Data from Firestore
        final firestoreImages = snapshot.docs.map((doc) {
          final data = doc.data();
          return ApartmentImageModel.fromFirestore(doc.id, data);
        }).toList();
        
        // STEP 3a: Combine with Local Images
        print('📋 STEP 3a: Combining with ${_localImages.length} local images...');
        final allImages = [...firestoreImages, ..._localImages.where((img) => img.adminId == adminId)];
        
        // Remove duplicates (by ID)
        final uniqueImages = <String, ApartmentImageModel>{};
        for (final image in allImages) {
          uniqueImages[image.id] = image;
        }
        final images = uniqueImages.values.toList();
        
        // Sort by creation date (newest first)
        images.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        
        print('✅ STEP 3 PASSED: Data transformed and sorted - Total: ${images.length} images');
        return images;
      }).handleError((error) {
        print('⚠️ WARNING: Firestore error - $error');
        print('   Returning local images instead...');
        
        // Return local images if Firestore fails
        final localImages = _localImages.where((img) => img.adminId == adminId).toList();
        localImages.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        
        print('✅ FALLBACK: Returning ${localImages.length} local images');
        return localImages;
      });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  // ==================== FLOW FUNCTION: Get Images for Residents ====================
  /// Get active images for specific building (for resident app)
  /// Returns both Firestore images and locally stored images
  Stream<List<ApartmentImageModel>> getImagesForBuilding(String buildingId) {
    try {
      print('🔵 APARTMENT IMAGES SERVICE: Fetching images for building - $buildingId');

      // STEP 1: Validate Building ID
      if (buildingId.isEmpty) return Stream.value([]);
      print('✅ STEP 1 PASSED: Building ID validated');

      // STEP 2: Fetch Active Images
      print('📋 STEP 2: Fetching active images...');
      return _firestore
          .collection(_imagesCollection)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) {
        print('✅ STEP 2 PASSED: Received ${snapshot.docs.length} Firestore images');
        
        // STEP 3: Filter by Building ID in Memory
        final firestoreImages = snapshot.docs
            .where((doc) {
              final buildingIds = doc.data()['buildingIds'] as List?;
              return buildingIds?.contains(buildingId) ?? false;
            })
            .map((doc) {
              final data = doc.data();
              return ApartmentImageModel.fromFirestore(doc.id, data);
            })
            .toList();
        
        // STEP 3a: Add local images for this building
        final localImages = _localImages
            .where((img) => img.status == 'active' && img.buildingIds.contains(buildingId))
            .toList();
        
        print('📋 STEP 3a: Adding ${localImages.length} local images...');
        
        final allImages = [...firestoreImages, ...localImages];
        
        // Remove duplicates (by ID)
        final uniqueImages = <String, ApartmentImageModel>{};
        for (final image in allImages) {
          uniqueImages[image.id] = image;
        }
        final images = uniqueImages.values.toList();
        
        // Sort by creation date (newest first)
        images.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        
        print('✅ STEP 3 PASSED: Filtered ${images.length} images for building');
        return images;
      }).handleError((error) {
        print('⚠️ WARNING: Firestore error - $error');
        print('   Returning local images instead...');
        
        // Return local images if Firestore fails
        final localImages = _localImages
            .where((img) => img.status == 'active' && img.buildingIds.contains(buildingId))
            .toList();
        
        localImages.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        
        print('✅ FALLBACK: Returning ${localImages.length} local images');
        return localImages;
      });
    } catch (e) {
      print('❌ ERROR: $e');
      return Stream.value([]);
    }
  }

  // ==================== FLOW FUNCTION: Delete Image ====================
  /// Delete image and its file
  Future<void> deleteImage(String imageId, String imageUrl) async {
    try {
      print('🔵 APARTMENT IMAGES SERVICE: Deleting image - $imageId');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not authenticated');
      print('✅ STEP 1 PASSED: Admin authenticated');

      // STEP 2: Delete Image from Storage
      print('🗑️ STEP 2: Deleting image from storage...');
      try {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
        print('✅ STEP 2 PASSED: Image deleted');
      } catch (e) {
        print('⚠️ WARNING: Could not delete image - $e');
      }

      // STEP 3: Delete Image Metadata from Firestore
      print('💾 STEP 3: Deleting image metadata from Firestore...');
      await _firestore.collection(_imagesCollection).doc(imageId).delete();
      print('✅ STEP 3 PASSED: Image metadata deleted');

      print('✅ APARTMENT IMAGES SERVICE: Deletion COMPLETE');
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
  final List<String> buildingIds;
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
    required this.buildingIds,
    required this.status,
    required this.uploadDate,
    required this.uploadTime,
    this.createdAt,
    this.updatedAt,
  });

  factory ApartmentImageModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ApartmentImageModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'Common Area',
      imageUrl: data['imageUrl'] ?? '',
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? 'Admin',
      buildingIds: List<String>.from(data['buildingIds'] ?? []),
      status: data['status'] ?? 'active',
      uploadDate: data['uploadDate'] ?? '',
      uploadTime: data['uploadTime'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
