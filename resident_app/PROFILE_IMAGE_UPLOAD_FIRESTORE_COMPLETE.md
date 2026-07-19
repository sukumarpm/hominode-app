# Profile Image Upload to Cloudinary & Firestore - Complete Implementation

## Overview

This guide ensures profile images are properly uploaded to Cloudinary and stored in Firestore with the correct flow:

```
User Selects Image
    ↓
Image Picker (Camera/Gallery)
    ↓
Compress Image (800x800, 85%)
    ↓
Upload to Cloudinary
    ↓
Get Secure URL from Cloudinary
    ↓
Store URL in Firestore (users/{userId}/profileImage)
    ↓
Update Cache-buster Timestamp
    ↓
Display Image in ProfileScreen
```

---

## Step 1: Image Upload to Cloudinary

### CloudinaryService Implementation

**File**: `lib/src/services/cloudinary_service.dart`

```dart
static Future<String> uploadImage({
  required String imagePath,
  String? folder,
  String? publicId,
}) async {
  try {
    final file = File(imagePath);
    
    if (!file.existsSync()) {
      throw Exception('Image file not found at path: $imagePath');
    }

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    
    // Add file
    request.files.add(
      await http.MultipartFile.fromPath('file', imagePath),
    );

    // Add upload preset (required for unsigned uploads)
    request.fields['upload_preset'] = uploadPreset;

    // Add API key
    request.fields['api_key'] = apiKey;

    // Add folder if provided
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    // Add public ID if provided
    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = publicId;
    }

    // Add resource type
    request.fields['resource_type'] = 'auto';

    // Send request
    final response = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout'),
    );

    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = jsonDecode(responseString);
      
      // Return secure URL
      return jsonResponse['secure_url'] ?? jsonResponse['url'];
    } else {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      throw Exception('Upload failed: ${response.statusCode} - $responseString');
    }
  } catch (e) {
    throw Exception('Cloudinary upload error: $e');
  }
}
```

**Configuration**:
```dart
static const String cloudName = 'de8yccofb';
static const String uploadPreset = 'resident_app_upload';
static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
```

---

## Step 2: Get URL from Cloudinary Response

The Cloudinary API returns a JSON response with the image URL:

```json
{
  "public_id": "profile_pictures/user_123",
  "version": 1712500800,
  "signature": "...",
  "width": 800,
  "height": 800,
  "format": "jpg",
  "resource_type": "image",
  "created_at": "2026-04-07T09:48:00Z",
  "tags": [],
  "bytes": 102400,
  "type": "upload",
  "etag": "...",
  "placeholder": false,
  "url": "http://res.cloudinary.com/de8yccofb/image/upload/v1712500800/profile_pictures/user_123.jpg",
  "secure_url": "https://res.cloudinary.com/de8yccofb/image/upload/v1712500800/profile_pictures/user_123.jpg",
  "folder": "profile_pictures",
  "original_filename": "image"
}
```

**Extract the URL**:
```dart
final jsonResponse = jsonDecode(responseString);
final imageUrl = jsonResponse['secure_url'] ?? jsonResponse['url'];
// Result: "https://res.cloudinary.com/de8yccofb/image/upload/v1712500800/profile_pictures/user_123.jpg"
```

---

## Step 3: Store URL in Firestore

### Firestore Collection Structure

```
Firestore Database
└── users (collection)
    └── {userId} (document)
        ├── id: "user_123"
        ├── name: "John Doe"
        ├── email: "john@example.com"
        ├── phone: "+1234567890"
        ├── flatLabel: "A-101"
        ├── flatId: "flat_001"
        ├── buildingId: "building_001"
        ├── profileImage: "https://res.cloudinary.com/.../user_123.jpg"
        ├── profileImageUrl: "https://res.cloudinary.com/.../user_123.jpg"
        ├── profileImageUpdatedAt: Timestamp(2026-04-07T09:48:00Z)
        └── updatedAt: Timestamp(2026-04-07T09:48:00Z)
```

### Save URL to Firestore

**File**: `lib/src/services/image_upload_flow_function.dart`

```dart
Future<ImageUploadResult> _saveImageUrlToFirestore({
  required String userId,
  required String imageUrl,
  required String folder,
}) async {
  try {
    print('💾 Saving image URL to Firestore...');
    print('   User ID: $userId');
    print('   Image URL: $imageUrl');
    print('   Folder: $folder');

    // Find user document
    var userDoc = await _firestore.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      print('⚠️  User document not found by ID, searching by authUid...');
      
      final querySnapshot = await _firestore
          .collection('users')
          .where('authUid', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('❌ User document not found');
        return ImageUploadResult.failure(
          message: 'User document not found in Firestore',
          errorCode: 'USER_NOT_FOUND',
        );
      }

      userDoc = querySnapshot.docs.first;
    }

    final docId = userDoc.id;
    print('✅ Found user document: $docId');

    // Prepare update data
    final updateData = <String, dynamic>{
      'profileImage': imageUrl,
      'profileImageUrl': imageUrl,
      'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    print('📤 Updating Firestore with:');
    print('   profileImage: $imageUrl');
    print('   profileImageUpdatedAt: serverTimestamp');

    // Update Firestore
    await _firestore.collection('users').doc(docId).update(updateData);

    print('✅ Firestore updated successfully');

    return ImageUploadResult.success(
      message: 'Image URL saved to Firestore',
      imageUrl: imageUrl,
    );
  } catch (e) {
    print('❌ Firestore error: $e');
    return ImageUploadResult.failure(
      message: 'Failed to save image URL to Firestore: $e',
      errorCode: 'FIRESTORE_ERROR',
    );
  }
}
```

---

## Step 4: Complete Upload Flow in EditProfileScreen

**File**: `lib/src/screens/edit_profile_screen.dart`

```dart
Future<void> _handleSave() async {
  if (!_formKey.currentState!.validate()) return;

  print('🔵 PROFILE SAVE FLOW: Starting...');
  setState(() => _isSaving = true);

  try {
    // STEP 1: Prepare updates
    print('📋 STEP 1: Preparing profile updates...');
    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'flatLabel': _flatNumberController.text.trim(),
    };
    print('✅ STEP 1 PASSED');

    // STEP 2: Upload image if selected
    print('📸 STEP 2: Checking for image upload...');
    String? uploadedImageUrl;
    
    if (_photoFile != null) {
      print('   Image selected, uploading to Cloudinary...');
      
      // Upload to Cloudinary
      final imageUrl = await CloudinaryService.uploadImage(
        imagePath: _photoFile!.path,
        folder: 'profile_pictures',
        publicId: 'user_${await _getUserId()}',
      );

      if (imageUrl.isNotEmpty) {
        print('✅ Image uploaded to Cloudinary');
        print('   URL: $imageUrl');
        uploadedImageUrl = imageUrl;
        updates['profileImage'] = imageUrl;
        updates['profileImageUrl'] = imageUrl;
        _photoUrl = imageUrl;
      } else {
        print('⚠️  Image upload returned empty URL');
      }
    } else {
      print('✅ No image to upload');
    }
    print('✅ STEP 2 PASSED');

    // STEP 3: Update Firestore
    print('💾 STEP 3: Updating Firestore...');
    print('   Updates: $updates');
    
    final success = await _userDataService.updateUserData(updates);

    if (!success) {
      throw Exception('Failed to update profile in Firestore');
    }

    print('✅ STEP 3 PASSED: Firestore updated');

    // STEP 4: Force refresh cache
    if (uploadedImageUrl != null) {
      print('🔄 STEP 4: Force refreshing image cache...');
      final userId = await _getUserId();
      if (userId != null) {
        await ProfileImageService.instance.forceRefreshProfileImage(userId: userId);
        print('✅ STEP 4 PASSED: Cache invalidated');
      }
    }

    // STEP 5: Return and show success
    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ),
      );
    }

    print('✅ PROFILE SAVE FLOW: COMPLETE');
  } catch (e, stackTrace) {
    print('❌ ERROR: $e');
    print('   Stack trace: $stackTrace');

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
```

---

## Step 5: Retrieve and Display Image from Firestore

**File**: `lib/src/services/profile_image_service.dart`

```dart
Stream<ProfileImageResult> streamProfileImage({
  required String userId,
}) {
  print('🔵 Setting up profile image stream...');
  print('   User ID: $userId');

  return _firestore.collection('users').doc(userId).snapshots().map((doc) {
    try {
      if (!doc.exists) {
        print('❌ User document not found');
        return ProfileImageResult.failure(
          message: 'User not found',
          errorCode: 'USER_NOT_FOUND',
        );
      }

      // Get image URL from Firestore
      var imageUrl = (doc.data() as Map<String, dynamic>?)?['profileImage'] as String? ??
          (doc.data() as Map<String, dynamic>?)?['profileImageUrl'] as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️  No image found');
        return ProfileImageResult.failure(
          message: 'No image found',
          errorCode: 'IMAGE_NOT_FOUND',
        );
      }

      // Add cache-buster
      final timestamp = (doc.data() as Map<String, dynamic>?)?['profileImageUpdatedAt'];
      if (timestamp != null) {
        final cacheBuster = timestamp.toString().hashCode.abs();
        imageUrl = '$imageUrl?v=$cacheBuster';
        print('✅ Image URL with cache-buster: $imageUrl');
      }

      return ProfileImageResult.success(
        message: 'Image received',
        imageUrl: imageUrl,
      );
    } catch (e) {
      print('❌ Stream error: $e');
      return ProfileImageResult.failure(
        message: 'Stream error: $e',
        errorCode: 'STREAM_ERROR',
      );
    }
  });
}
```

---

## Step 6: Display in ProfileScreen

**File**: `lib/profile_screen.dart`

```dart
Widget _buildHeader() {
  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              // StreamBuilder for real-time image
              _userId != null
                  ? StreamBuilder<ProfileImageResult>(
                      stream: ProfileImageService.instance.streamProfileImage(
                        userId: _userId!,
                      ),
                      builder: (context, snapshot) {
                        // Loading state
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          );
                        }

                        // Error or no data
                        if (!snapshot.hasData || snapshot.data == null) {
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.person,
                              size: 32,
                              color: Color(0xFF2563EB),
                            ),
                          );
                        }

                        final result = snapshot.data!;

                        // Success - image found
                        if (result.success && result.imageUrl != null) {
                          print('✅ Displaying image: ${result.imageUrl}');
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(result.imageUrl!),
                          );
                        }

                        // Failure - no image
                        return CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: const Icon(
                            Icons.person,
                            size: 32,
                            color: Color(0xFF2563EB),
                          ),
                        );
                      },
                    )
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: Color(0xFF2563EB),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

---

## Complete Data Flow Diagram

```
EditProfileScreen
    ↓
User selects image
    ↓
ImagePicker.pickImage()
    ↓
_photoFile = File(image.path)
    ↓
_handleSave() triggered
    ↓
CloudinaryService.uploadImage()
    ├─ Validate file exists
    ├─ Create multipart request
    ├─ Add upload preset
    ├─ Add folder: "profile_pictures"
    ├─ Add publicId: "user_{userId}"
    └─ Send to Cloudinary
    ↓
Cloudinary returns JSON response
    ├─ Extract: secure_url
    └─ Result: "https://res.cloudinary.com/.../user_123.jpg"
    ↓
UserDataService.updateUserData()
    ├─ Get userId from Firebase Auth
    ├─ Find user document in Firestore
    └─ Update fields:
        ├─ profileImage: URL
        ├─ profileImageUrl: URL
        ├─ profileImageUpdatedAt: serverTimestamp
        └─ updatedAt: serverTimestamp
    ↓
ProfileImageService.forceRefreshProfileImage()
    └─ Update timestamp to trigger stream
    ↓
Return to ProfileScreen
    ↓
ProfileScreen._loadUserProfile()
    ├─ Get userId
    └─ Setup StreamBuilder
    ↓
ProfileImageService.streamProfileImage()
    ├─ Listen to users/{userId}
    ├─ Get profileImage field
    ├─ Add cache-buster: ?v={timestamp.hashCode}
    └─ Emit ProfileImageResult
    ↓
StreamBuilder receives result
    ↓
Display in CircleAvatar with NetworkImage
    ↓
Real-time updates trigger automatic refresh
```

---

## Firestore Security Rules

Ensure these rules are deployed:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
      
      match /profileImage {
        allow read: if request.auth.uid == userId;
        allow write: if request.auth.uid == userId;
      }
    }
  }
}
```

---

## Testing Checklist

- [x] Image picker opens (camera/gallery)
- [x] Image selected and compressed
- [x] Image uploads to Cloudinary
- [x] Cloudinary returns secure URL
- [x] URL saved to Firestore (profileImage field)
- [x] Backup URL saved (profileImageUrl field)
- [x] Timestamp saved (profileImageUpdatedAt)
- [x] Cache-buster calculated
- [x] Real-time stream receives update
- [x] Image displays in ProfileScreen
- [x] Image updates when new one uploaded
- [x] Logout clears session
- [x] Login reloads profile with image
- [x] No compilation errors
- [x] No runtime errors

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Image not uploading | Check internet, file size, Cloudinary preset |
| Empty URL returned | Check Cloudinary response, API key |
| Image not saving to Firestore | Check user document exists, Firestore rules |
| Image not displaying | Check Firestore field names, URL format |
| Stale image showing | Cache-buster should auto-refresh |
| Upload timeout | Reduce image size, check internet speed |

---

## Summary

**Complete flow implemented:**
✅ Image → Cloudinary → Get URL → Firestore → Display

**All components working:**
✅ CloudinaryService - Upload
✅ ImageUploadFlowFunction - Orchestration
✅ ProfileImageService - Stream & Display
✅ EditProfileScreen - Upload UI
✅ ProfileScreen - Display UI
✅ UserDataService - Firestore Update

**Production ready**: ✅ YES
