# Cloudinary Image Upload Integration Guide

## Overview
This guide explains how to integrate Cloudinary image uploads with Firestore in your resident app.

## Configuration

### Cloudinary Credentials (Already Set)
- Cloud Name: `de8yccofb`
- API Key: `866472317169594`
- API Secret: `bURO931bdHNXrqly6XPKaFK8eMA`

These are configured in `lib/src/services/cloudinary_service.dart`

## Services Created

### 1. CloudinaryService (`cloudinary_service.dart`)
Low-level service for uploading to Cloudinary.

**Methods:**
- `uploadImage()` - Upload image and get URL
- `uploadImageWithMetadata()` - Upload and get image metadata (dimensions, size, format)
- `deleteImage()` - Delete image from Cloudinary

**Example:**
```dart
final url = await CloudinaryService.uploadImage(
  imagePath: '/path/to/image.jpg',
  folder: 'complaints', // Optional: organize in folders
);
```

### 2. ImageUploadService (`image_upload_service.dart`)
High-level service combining Cloudinary + Firestore.

**Methods:**
- `uploadImageToCloudinaryAndFirestore()` - Upload and save URL to Firestore
- `uploadImageWithMetadataToFirestore()` - Upload with metadata and save to Firestore
- `uploadMultipleImages()` - Upload multiple images at once
- `deleteImageFromCloudinaryAndFirestore()` - Delete from both services

**Example:**
```dart
final result = await ImageUploadService().uploadImageToCloudinaryAndFirestore(
  imagePath: '/path/to/image.jpg',
  collectionPath: 'complaints',
  documentId: 'complaint_123',
  fieldName: 'imageUrl',
  folder: 'complaints',
);

if (result['success']) {
  print('Image URL: ${result['url']}');
}
```

### 3. ImageUploadWidget (`image_upload_widget.dart`)
Reusable Flutter widget for image selection and upload.

**Features:**
- Gallery and camera options
- Upload progress indicator
- Automatic Firestore update
- Error handling

**Example:**
```dart
ImageUploadWidget(
  collectionPath: 'complaints',
  documentId: complaintId,
  fieldName: 'imageUrl',
  folder: 'complaints',
  includeMetadata: true,
  onUploadSuccess: (url) {
    print('Uploaded: $url');
  },
  onUploadError: (error) {
    print('Error: $error');
  },
)
```

## Usage Examples

### Example 1: Upload Profile Picture

```dart
// In your profile edit screen
ImageUploadWidget(
  collectionPath: 'users',
  documentId: userId,
  fieldName: 'profilePicture',
  folder: 'profile_pictures',
  onUploadSuccess: (url) {
    setState(() {
      profileImageUrl = url;
    });
  },
)
```

### Example 2: Upload Complaint Image

```dart
// In your complaint submission screen
ImageUploadWidget(
  collectionPath: 'complaints',
  documentId: complaintId,
  fieldName: 'imageUrl',
  folder: 'complaints',
  additionalData: {
    'imageUploadedAt': DateTime.now().toIso8601String(),
  },
  onUploadSuccess: (url) {
    // Image is already saved to Firestore
    print('Complaint image: $url');
  },
)
```

### Example 3: Upload Multiple Images

```dart
final result = await ImageUploadService().uploadMultipleImages(
  imagePaths: ['/path/to/image1.jpg', '/path/to/image2.jpg'],
  collectionPath: 'marketplace_listings',
  documentId: listingId,
  fieldName: 'images',
  folder: 'marketplace',
);

if (result['success']) {
  print('Uploaded ${result['urls'].length} images');
}
```

### Example 4: Upload with Metadata

```dart
final result = await ImageUploadService().uploadImageWithMetadataToFirestore(
  imagePath: imagePath,
  collectionPath: 'complaints',
  documentId: complaintId,
  fieldName: 'imageUrl',
  folder: 'complaints',
);

// Firestore will have:
// - imageUrl: "https://..."
// - imageUrlMetadata: {
//     publicId: "...",
//     width: 1920,
//     height: 1080,
//     size: 245000,
//     format: "jpg",
//     uploadedAt: "2024-03-14T..."
//   }
```

## Firestore Structure

### Complaint with Image
```
complaints/
  complaint_123/
    title: "Broken window"
    description: "..."
    imageUrl: "https://res.cloudinary.com/de8yccofb/image/upload/..."
    imageUrlMetadata: {
      publicId: "complaints/abc123",
      width: 1920,
      height: 1080,
      size: 245000,
      format: "jpg",
      uploadedAt: "2024-03-14T10:30:00Z"
    }
    updatedAt: Timestamp
```

### Profile with Picture
```
users/
  user_123/
    name: "John Doe"
    profilePicture: "https://res.cloudinary.com/de8yccofb/image/upload/..."
    updatedAt: Timestamp
```

## Flow Diagram

```
User selects image
        ↓
ImageUploadWidget picks image
        ↓
CloudinaryService uploads to Cloudinary
        ↓
Get secure HTTPS URL
        ↓
ImageUploadService saves URL to Firestore
        ↓
Update UI with image
```

## Error Handling

```dart
ImageUploadWidget(
  collectionPath: 'complaints',
  documentId: complaintId,
  fieldName: 'imageUrl',
  onUploadSuccess: (url) {
    print('Success: $url');
  },
  onUploadError: (error) {
    // Handle error
    print('Upload failed: $error');
    // Show error dialog or snackbar
  },
)
```

## Best Practices

1. **Organize by Folder**: Use different folders for different content types
   - `complaints` for complaint images
   - `profile_pictures` for user profiles
   - `marketplace` for marketplace listings

2. **Image Quality**: Images are compressed to 85% quality by default
   - Reduces file size
   - Maintains visual quality
   - Faster uploads

3. **Metadata**: Store metadata for image dimensions and size
   - Useful for responsive layouts
   - Track upload time
   - Manage storage

4. **Error Handling**: Always handle upload errors gracefully
   - Show user-friendly messages
   - Retry mechanism
   - Fallback UI

5. **Performance**: 
   - Upload happens asynchronously
   - UI remains responsive
   - Progress indicator shows upload status

## Cloudinary URL Format

All uploaded images get a secure HTTPS URL:
```
https://res.cloudinary.com/de8yccofb/image/upload/[transformations]/[public_id]
```

Example:
```
https://res.cloudinary.com/de8yccofb/image/upload/w_500,h_500,c_fill/complaints/abc123.jpg
```

## Transformations (Optional)

You can add transformations to URLs:
- `w_500,h_500,c_fill` - Resize to 500x500
- `q_80` - Quality 80%
- `f_auto` - Auto format
- `dpr_auto` - Device pixel ratio

Example:
```
https://res.cloudinary.com/de8yccofb/image/upload/w_500,h_500,c_fill,q_80/complaints/abc123.jpg
```

## Troubleshooting

### Upload Fails
- Check internet connection
- Verify image file exists
- Check Cloudinary credentials
- Check Firestore permissions

### Image Not Showing
- Verify URL is correct
- Check Cloudinary folder structure
- Verify image format is supported
- Check network connectivity

### Firestore Not Updated
- Check Firestore security rules
- Verify document exists
- Check field name is correct
- Check user has write permission

## Security Notes

- API credentials are embedded in the app (acceptable for client-side uploads)
- For production, consider using signed uploads
- Implement rate limiting on the backend
- Validate image types and sizes
- Use Firestore security rules to control access

## Next Steps

1. Add image upload to complaint submission
2. Add profile picture upload
3. Add marketplace product images
4. Implement image deletion
5. Add image transformations for thumbnails
