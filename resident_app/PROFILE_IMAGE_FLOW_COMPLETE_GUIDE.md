# Profile Image Upload & Display - Complete Implementation Guide

## Overview

The profile image system is fully implemented and working according to the flow function pattern. This guide explains how the complete flow works from upload to display.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROFILE IMAGE SYSTEM                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  UPLOAD FLOW                                                    │
│  ───────────                                                    │
│  EditProfileScreen                                              │
│    ↓                                                             │
│  ImagePicker (Camera/Gallery)                                   │
│    ↓                                                             │
│  ProfileImageService.uploadProfileImage()                       │
│    ↓                                                             │
│  ImageUploadFlowFunction.uploadImage()                          │
│    ├─ Validate User Auth                                        │
│    ├─ Validate Image File                                       │
│    ├─ Upload to Cloudinary                                      │
│    ├─ Save URL to Firestore                                     │
│    └─ Return Result                                             │
│    ↓                                                             │
│  Update Firestore: profileImage = URL                           │
│    ↓                                                             │
│  Force Refresh: profileImageUpdatedAt = serverTimestamp         │
│    ↓                                                             │
│  Return to ProfileScreen                                        │
│                                                                 │
│  DISPLAY FLOW                                                   │
│  ────────────                                                   │
│  ProfileScreen._loadUserProfile()                               │
│    ↓                                                             │
│  Get userId from SharedPreferences/Firebase Auth                │
│    ↓                                                             │
│  ProfileImageService.streamProfileImage(userId)                 │
│    ├─ Stream Firestore: users/{userId}                          │
│    ├─ Get profileImage field                                    │
│    ├─ Add cache-buster: ?v={timestamp.hashCode}                 │
│    └─ Emit ProfileImageResult                                   │
│    ↓                                                             │
│  StreamBuilder receives result                                  │
│    ↓                                                             │
│  Display in CircleAvatar with NetworkImage                      │
│    ↓                                                             │
│  Real-time updates trigger automatic refresh                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. CloudinaryService
**File**: `lib/src/services/cloudinary_service.dart`

**Responsibilities**:
- Upload images to Cloudinary
- Delete images from Cloudinary
- Extract image metadata

**Key Methods**:
```dart
// Upload image and return URL
static Future<String> uploadImage({
  required String imagePath,
  String? folder,
  String? publicId,
}) async

// Upload with metadata
static Future<Map<String, dynamic>> uploadImageWithMetadata({
  required String imagePath,
  String? folder,
  String? publicId,
}) async

// Delete image
static Future<bool> deleteImage(String publicId) async
```

**Configuration**:
```dart
static const String cloudName = 'de8yccofb';
static const String uploadPreset = 'resident_app_upload';
static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
```

---

### 2. ImageUploadFlowFunction
**File**: `lib/src/services/image_upload_flow_function.dart`

**Responsibilities**:
- Orchestrate complete upload flow
- Validate user authentication
- Validate image file (size, format, MIME type)
- Upload to Cloudinary
- Save URL to Firestore
- Handle errors gracefully

**Upload Flow (5 Steps)**:
```
STEP 1: Validate User Authentication
  ├─ Check Firebase Auth UID
  ├─ Fallback to Firestore query
  └─ Return user ID or error

STEP 2: Validate Image File
  ├─ Check file exists
  ├─ Check file size (max 10MB)
  ├─ Check file extension
  └─ Verify MIME type

STEP 3: Upload to Cloudinary
  ├─ Prepare multipart request
  ├─ Add upload preset
  ├─ Add folder and public ID
  └─ Return secure URL

STEP 4: Save URL to Firestore
  ├─ Find user document
  ├─ Prepare update data based on folder
  ├─ Update Firestore
  └─ Return result

STEP 5: Return Success Result
  └─ Return ImageUploadResult with URL
```

**Key Methods**:
```dart
// Main upload flow
Future<ImageUploadResult> uploadImage({
  required String imagePath,
  required String folder,
  String? publicId,
}) async

// Fetch image URL
Future<ImageUploadResult> fetchImageUrl({
  required String userId,
  required String folder,
}) async

// Delete image
Future<ImageUploadResult> deleteImage({
  required String userId,
  required String publicId,
  required String folder,
}) async
```

---

### 3. ProfileImageService
**File**: `lib/src/services/profile_image_service.dart`

**Responsibilities**:
- Upload profile images via flow function
- Fetch profile images from Firestore
- Stream profile images in real-time
- Delete profile images
- Force refresh cache

**Key Methods**:
```dart
// Upload profile image
Future<ProfileImageResult> uploadProfileImage({
  required String imagePath,
}) async

// Fetch profile image
Future<ProfileImageResult> fetchProfileImage({
  required String userId,
}) async

// Stream profile image (real-time)
Stream<ProfileImageResult> streamProfileImage({
  required String userId,
})

// Delete profile image
Future<ProfileImageResult> deleteProfileImage({
  required String userId,
  required String publicId,
}) async

// Force refresh cache
Future<ProfileImageResult> forceRefreshProfileImage({
  required String userId,
}) async
```

**Cache-Busting Strategy**:
- Uses `profileImageUpdatedAt` timestamp from Firestore
- Appends `?v={timestamp.hashCode}` to URL
- Forces browser/app to fetch fresh image
- Triggered on upload via `forceRefreshProfileImage()`

---

### 4. EditProfileScreen
**File**: `lib/src/screens/edit_profile_screen.dart`

**Responsibilities**:
- Load user profile data
- Display image picker
- Handle image selection
- Upload image to Cloudinary
- Update user data in Firestore
- Show success/error feedback

**Upload Flow in _handleSave()**:
```
STEP 1: Prepare profile updates
  └─ name, phone, flatLabel

STEP 2: Check for image upload
  ├─ If image selected:
  │  ├─ Call ProfileImageService.uploadProfileImage()
  │  ├─ Get image URL from result
  │  └─ Add to updates: profileImage = URL
  └─ If no image: skip

STEP 3: Update Firestore
  ├─ Call UserDataService.updateUserData(updates)
  └─ Sync with Firebase Auth profile

STEP 4: Force refresh image cache
  ├─ Get user ID
  └─ Call ProfileImageService.forceRefreshProfileImage()

STEP 5: Return to ProfileScreen
  ├─ Pop with result = true
  └─ Show success message
```

---

### 5. ProfileScreen
**File**: `lib/profile_screen.dart`

**Responsibilities**:
- Load user profile data
- Display user information
- Stream profile image in real-time
- Show organization name
- Navigate to edit profile
- Handle logout

**Image Display Flow**:
```
_buildHeader()
  ├─ Get userId from SharedPreferences/Firebase Auth
  └─ StreamBuilder<ProfileImageResult>
      ├─ Call ProfileImageService.streamProfileImage(userId)
      ├─ Handle loading state
      ├─ Handle error state
      ├─ Display image with cache-buster
      └─ Show default avatar if no image
```

---

## Firestore Structure

```
users/{userId}
├── id: string (user ID)
├── authUid: string (Firebase Auth UID)
├── name: string (user name)
├── email: string (user email)
├── phone: string (user phone)
├── flatLabel: string (flat number, e.g., "A-101")
├── flatId: string (flat ID)
├── buildingId: string (building ID)
├── role: string (user role: "resident", "admin")
├── profileImage: string (Cloudinary URL)
├── profileImageUrl: string (backup field)
├── profileImageUpdatedAt: timestamp (for cache-busting)
├── updatedAt: timestamp (last update time)
└── ... (other fields)
```

---

## Complete Upload Example

```dart
// 1. User selects image in EditProfileScreen
final XFile? image = await _picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 800,
  maxHeight: 800,
  imageQuality: 85,
);

// 2. Store in _photoFile
_photoFile = File(image.path);

// 3. User clicks Save
// 4. _handleSave() is called
// 5. Upload image
final imageResult = await ProfileImageService.instance.uploadProfileImage(
  imagePath: _photoFile!.path,
);

// 6. Get URL from result
if (imageResult.success && imageResult.imageUrl != null) {
  uploadedImageUrl = imageResult.imageUrl;
  updates['profileImage'] = imageResult.imageUrl;
}

// 7. Update Firestore
await _userDataService.updateUserData(updates);

// 8. Force refresh cache
await ProfileImageService.instance.forceRefreshProfileImage(userId: userId);

// 9. Return to ProfileScreen
Navigator.pop(context, true);
```

---

## Complete Display Example

```dart
// 1. ProfileScreen loads
_loadUserProfile()

// 2. Get user ID
String? userId = prefs.getString('user_id');

// 3. Build StreamBuilder
StreamBuilder<ProfileImageResult>(
  stream: ProfileImageService.instance.streamProfileImage(userId: userId),
  builder: (context, snapshot) {
    // 4. Handle loading
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    // 5. Handle error
    if (!snapshot.hasData || snapshot.data == null) {
      return Icon(Icons.person);
    }
    
    // 6. Get result
    final result = snapshot.data!;
    
    // 7. Display image
    if (result.success && result.imageUrl != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(result.imageUrl!),
      );
    }
    
    // 8. Show default
    return Icon(Icons.person);
  },
)
```

---

## Error Handling

### Upload Errors

| Error | Cause | Solution |
|-------|-------|----------|
| NOT_AUTHENTICATED | User not logged in | Login first |
| FILE_NOT_FOUND | Image file doesn't exist | Select valid image |
| FILE_TOO_LARGE | Image > 10MB | Compress image |
| INVALID_FORMAT | Wrong file type | Use JPG/PNG/GIF/WebP |
| CLOUDINARY_ERROR | Upload failed | Check internet connection |
| USER_NOT_FOUND | User doc missing | Create user in Firestore |
| FIRESTORE_ERROR | Save failed | Check Firestore rules |

### Display Errors

| Error | Cause | Solution |
|-------|-------|----------|
| USER_NOT_FOUND | User doc missing | Create user in Firestore |
| IMAGE_NOT_FOUND | No image uploaded | Upload image first |
| STREAM_ERROR | Stream failed | Check Firestore connection |

---

## Testing Checklist

- [x] Image picker opens (camera/gallery)
- [x] Image selected and displayed in preview
- [x] Image uploads to Cloudinary
- [x] URL saved to Firestore (profileImage field)
- [x] Cache-busting timestamp set
- [x] Real-time stream receives update
- [x] Image displays in profile screen
- [x] Image updates when new one uploaded
- [x] Logout clears session
- [x] Login reloads profile with image
- [x] No compilation errors
- [x] No runtime errors
- [x] Error messages display correctly
- [x] Loading states show properly
- [x] Default avatar shows when no image

---

## Performance Optimization

1. **Image Compression**: 
   - maxWidth: 800, maxHeight: 800
   - imageQuality: 85
   - Reduces file size before upload

2. **Cache-Busting**:
   - Uses timestamp hash as cache-buster
   - Forces fresh image load
   - Prevents stale image display

3. **Real-time Streaming**:
   - StreamBuilder for automatic updates
   - No manual refresh needed
   - Efficient Firestore queries

4. **Error Recovery**:
   - Graceful fallback to default avatar
   - Proper error messages
   - No app crashes

---

## Summary

The profile image upload and display system is **fully functional** and follows the **flow function pattern** correctly:

✅ **Upload Flow**: Image → Cloudinary → Firestore → Cache Invalidation
✅ **Display Flow**: Firestore Stream → Cache-busting → NetworkImage
✅ **Integration**: Edit Profile → ProfileImageService → ImageUploadFlowFunction
✅ **Real-time Updates**: StreamBuilder with automatic refresh
✅ **Error Handling**: Proper validation and error messages
✅ **Cache Management**: Timestamp-based cache-busting
✅ **No Compilation Errors**: All files compile successfully
✅ **No Runtime Errors**: Proper error handling throughout

**The system is production-ready and requires no fixes.**
