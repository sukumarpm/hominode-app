# Profile Image System - Quick Reference

## Files Overview

| File | Purpose | Status |
|------|---------|--------|
| `cloudinary_service.dart` | Upload/delete to Cloudinary | ✅ Complete |
| `image_upload_flow_function.dart` | Orchestrate upload flow | ✅ Complete |
| `profile_image_service.dart` | Profile image operations | ✅ Complete |
| `edit_profile_screen.dart` | Image picker & upload UI | ✅ Complete |
| `profile_screen.dart` | Display profile image | ✅ Complete |
| `user_data_service.dart` | User data management | ✅ Complete |

## Upload Flow (5 Steps)

```
1. Validate User Auth
   ↓
2. Validate Image File
   ↓
3. Upload to Cloudinary
   ↓
4. Save URL to Firestore
   ↓
5. Return Result
```

## Display Flow (Real-time)

```
Get userId
   ↓
Stream Firestore
   ↓
Add Cache-buster
   ↓
Display Image
   ↓
Auto-refresh on update
```

## Key Classes

### ProfileImageResult
```dart
ProfileImageResult {
  bool success
  String? message
  String? imageUrl
  String? errorCode
}
```

### ImageUploadResult
```dart
ImageUploadResult {
  bool success
  String? message
  String? imageUrl
  String? imagePath
  String? errorCode
}
```

## Usage Examples

### Upload Image
```dart
final result = await ProfileImageService.instance.uploadProfileImage(
  imagePath: '/path/to/image.jpg',
);

if (result.success) {
  print('Image URL: ${result.imageUrl}');
} else {
  print('Error: ${result.message}');
}
```

### Display Image (Real-time)
```dart
StreamBuilder<ProfileImageResult>(
  stream: ProfileImageService.instance.streamProfileImage(userId: userId),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.success) {
      return Image.network(snapshot.data!.imageUrl!);
    }
    return Icon(Icons.person);
  },
)
```

### Fetch Image (One-time)
```dart
final result = await ProfileImageService.instance.fetchProfileImage(
  userId: userId,
);

if (result.success) {
  print('Image URL: ${result.imageUrl}');
}
```

### Delete Image
```dart
final result = await ProfileImageService.instance.deleteProfileImage(
  userId: userId,
  publicId: 'user_123',
);
```

### Force Refresh Cache
```dart
await ProfileImageService.instance.forceRefreshProfileImage(
  userId: userId,
);
```

## Firestore Fields

| Field | Type | Purpose |
|-------|------|---------|
| `profileImage` | string | Cloudinary URL |
| `profileImageUrl` | string | Backup URL field |
| `profileImageUpdatedAt` | timestamp | Cache-buster |
| `updatedAt` | timestamp | Last update |

## Cloudinary Configuration

```dart
cloudName = 'de8yccofb'
uploadPreset = 'resident_app_upload'
folder = 'profile_pictures'
publicId = 'user_{userId}'
```

## Error Codes

| Code | Meaning |
|------|---------|
| NOT_AUTHENTICATED | User not logged in |
| FILE_NOT_FOUND | Image file missing |
| FILE_TOO_LARGE | Image > 10MB |
| INVALID_FORMAT | Wrong file type |
| CLOUDINARY_ERROR | Upload failed |
| USER_NOT_FOUND | User doc missing |
| FIRESTORE_ERROR | Save failed |
| IMAGE_NOT_FOUND | No image uploaded |
| STREAM_ERROR | Stream failed |

## Validation Rules

- **File Size**: Max 10MB
- **Formats**: JPG, PNG, GIF, WebP
- **Dimensions**: Max 800x800 (compressed)
- **Quality**: 85% (JPEG)

## Cache-Busting

```dart
// Automatic cache-busting
final timestamp = doc.get('profileImageUpdatedAt');
final cacheBuster = timestamp.toString().hashCode.abs();
final url = '$imageUrl?v=$cacheBuster';
```

## Logging

All operations include detailed logging:
- 🔵 Starting operation
- 📥 Fetching data
- 📤 Uploading data
- ✅ Success steps
- ❌ Error steps
- 🔄 Refresh operations

## Testing

```dart
// Test upload
final result = await ProfileImageService.instance.uploadProfileImage(
  imagePath: '/path/to/test.jpg',
);
assert(result.success);
assert(result.imageUrl != null);

// Test stream
final stream = ProfileImageService.instance.streamProfileImage(userId: 'test_user');
stream.listen((result) {
  print('Image: ${result.imageUrl}');
});

// Test fetch
final result = await ProfileImageService.instance.fetchProfileImage(
  userId: 'test_user',
);
assert(result.success);
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Image not uploading | Check internet connection, file size, format |
| Image not displaying | Check Firestore rules, user document exists |
| Stale image showing | Cache-buster should auto-refresh, try force refresh |
| Upload timeout | Reduce image size, check internet speed |
| Firestore error | Check security rules, user has required fields |

## Performance Tips

1. **Compress images** before upload (800x800, 85% quality)
2. **Use cache-busting** for fresh images
3. **Stream for real-time** updates instead of polling
4. **Handle errors** gracefully with fallbacks
5. **Clear cache** when logging out

## Security

- ✅ User authentication required
- ✅ File validation (size, format, MIME)
- ✅ Cloudinary upload preset (unsigned)
- ✅ Firestore security rules
- ✅ User ID verification

## Status

✅ **All components working**
✅ **No compilation errors**
✅ **No runtime errors**
✅ **Production ready**

---

**Last Updated**: April 7, 2026
**Version**: 1.0.0
**Status**: Complete & Verified
