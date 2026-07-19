# Image Upload - Quick Start Guide

## What's New

Complete image upload flow function that works properly according to the flow function pattern.

## How It Works

### 5-Step Flow

1. **Validate User** - Check if user is authenticated
2. **Validate File** - Check file exists, size, and format
3. **Upload to Cloudinary** - Upload image to cloud storage
4. **Save to Firestore** - Store image URL in database
5. **Return Result** - Return success with image URL

## Usage

### Upload Profile Image

```dart
import 'package:resident_app/src/services/image_upload_flow_function.dart';

// Upload image
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: '/path/to/image.jpg',
  folder: 'profile_pictures',
);

if (result.success) {
  print('✅ Image uploaded: ${result.imageUrl}');
} else {
  print('❌ Error: ${result.message}');
}
```

### Upload Complaint Image

```dart
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: '/path/to/complaint.jpg',
  folder: 'complaint_images',
);
```

### Upload Marketplace Image

```dart
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: '/path/to/listing.jpg',
  folder: 'marketplace',
);
```

## Supported Folders

- `profile_pictures` - User profile images
- `complaint_images` - Complaint attachments
- `community_wall` - Community wall posts
- `marketplace` - Marketplace listings

## File Requirements

- **Formats**: JPG, PNG, GIF, WebP
- **Max Size**: 10 MB
- **Recommended**: < 5 MB

## Error Handling

```dart
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: imagePath,
  folder: 'profile_pictures',
);

if (!result.success) {
  switch (result.errorCode) {
    case 'NOT_AUTHENTICATED':
      print('User not logged in');
      break;
    case 'FILE_NOT_FOUND':
      print('Image file not found');
      break;
    case 'FILE_TOO_LARGE':
      print('Image is too large');
      break;
    case 'INVALID_FORMAT':
      print('Invalid image format');
      break;
    case 'CLOUDINARY_UPLOAD_FAILED':
      print('Cloudinary upload failed');
      break;
    case 'USER_NOT_FOUND':
      print('User not found in Firestore');
      break;
    default:
      print('Error: ${result.message}');
  }
}
```

## Console Output

When uploading, you'll see detailed logs:

```
🔵 IMAGE UPLOAD FLOW: Starting image upload...
🔐 STEP 1: Validating user authentication...
✅ STEP 1 PASSED: User authenticated
🔐 STEP 2: Validating image file...
✅ STEP 2 PASSED: Image file is valid
🔐 STEP 3: Uploading to Cloudinary...
✅ STEP 3 PASSED: Image uploaded to Cloudinary
🔐 STEP 4: Saving URL to Firestore...
✅ STEP 4 PASSED: URL saved to Firestore
✅ IMAGE UPLOAD FLOW: SUCCESS
```

## In Edit Profile Screen

```dart
// In _handleSave() method
if (_photoFile != null) {
  final imageResult = await ImageUploadFlowFunction.instance.uploadImage(
    imagePath: _photoFile!.path,
    folder: 'profile_pictures',
  );

  if (imageResult.success) {
    updates['profileImage'] = imageResult.imageUrl;
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image upload failed: ${imageResult.message}')),
    );
  }
}
```

## Fetch Image

```dart
final result = await ImageUploadFlowFunction.instance.fetchImageUrl(
  userId: userId,
  folder: 'profile_pictures',
);

if (result.success) {
  print('Image URL: ${result.imageUrl}');
}
```

## Delete Image

```dart
final result = await ImageUploadFlowFunction.instance.deleteImage(
  userId: userId,
  publicId: 'user_abc123xyz',
  folder: 'profile_pictures',
);

if (result.success) {
  print('Image deleted');
}
```

## Firestore Fields

Images are stored in these Firestore fields:

| Folder | Field |
|--------|-------|
| profile_pictures | profileImage |
| complaint_images | lastComplaintImageUrl |
| community_wall | lastPostImageUrl |
| marketplace | lastListingImageUrl |

## Testing

### Test Upload
```dart
// Test with a real image file
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: '/storage/emulated/0/Pictures/test.jpg',
  folder: 'profile_pictures',
);

print('Success: ${result.success}');
print('URL: ${result.imageUrl}');
print('Message: ${result.message}');
```

## Troubleshooting

### "User not authenticated"
- Make sure user is logged in
- Check Firebase Auth is initialized
- Verify Firestore user document exists

### "Image file not found"
- Check file path is correct
- Verify file exists on device
- Check file permissions

### "Image file is too large"
- Reduce image size to < 10 MB
- Compress image before uploading
- Use image picker with quality settings

### "Invalid image format"
- Use JPG, PNG, GIF, or WebP
- Check file extension
- Verify file is actually an image

### "Cloudinary upload failed"
- Check Cloudinary credentials
- Verify upload preset is configured
- Check internet connection

### "User not found in Firestore"
- Verify user document exists
- Check authUid field is set
- Ensure user is properly registered

## Files

- **Service**: `lib/src/services/image_upload_flow_function.dart`
- **Profile Service**: `lib/src/services/profile_image_service.dart`
- **Documentation**: `IMAGE_UPLOAD_FLOW_FUNCTION_COMPLETE.md`

## Status

✅ **READY TO USE**

The image upload flow function is fully implemented and tested. All images will now upload properly according to the flow function pattern.

---

**Quick Links**:
- [Full Documentation](IMAGE_UPLOAD_FLOW_FUNCTION_COMPLETE.md)
- [Flow Diagram](IMAGE_UPLOAD_FLOW_DIAGRAM.md)
- [Cloudinary Setup](CLOUDINARY_UPLOAD_PRESET_SETUP.md)
