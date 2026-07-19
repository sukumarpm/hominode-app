# Image Flow - Quick Reference Guide

## 🎯 Quick Start

### Upload Image
```dart
// Step 1: Import
import '../services/image_upload_flow_function.dart';

// Step 2: Upload
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: file.path,
  folder: 'marketplace',  // or 'profile_pictures', 'complaint_images', 'community_wall'
  publicId: 'unique_id',
);

// Step 3: Check result
if (result.success) {
  print('✅ Image uploaded: ${result.imageUrl}');
} else {
  print('❌ Error: ${result.message}');
}
```

### Display Image (One-time)
```dart
// Step 1: Import
import '../services/image_display_flow_function.dart';

// Step 2: Fetch
final result = await ImageDisplayFlowFunction.instance
    .getMarketplaceProductImage(listingId: listingId);

// Step 3: Display
if (result.success && result.imageUrl != null) {
  Image.network(result.imageUrl!);
} else {
  Icon(Icons.image_not_supported);
}
```

### Display Image (Real-time Stream)
```dart
// Step 1: Import
import '../services/image_display_flow_function.dart';

// Step 2: Stream
StreamBuilder<ImageDisplayResult>(
  stream: ImageDisplayFlowFunction.instance
      .streamMarketplaceProductImage(listingId: listingId),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.success) {
      return Image.network(snapshot.data!.imageUrl!);
    }
    return Icon(Icons.image_not_supported);
  },
)
```

---

## 📁 Folder Names

Use these folder names when uploading:
- `profile_pictures` - User profile images
- `marketplace` - Marketplace product images
- `complaint_images` - Complaint images
- `community_wall` - Community wall post images

---

## 🔍 Display Methods

### Marketplace
```dart
// Get single image
ImageDisplayFlowFunction.instance.getMarketplaceProductImage(listingId)

// Stream real-time updates
ImageDisplayFlowFunction.instance.streamMarketplaceProductImage(listingId)
```

### Profile
```dart
// Get single image
ImageDisplayFlowFunction.instance.getProfileImage(userId)

// Stream real-time updates
ImageDisplayFlowFunction.instance.streamProfileImage(userId)
```

### Complaints
```dart
// Get single image
ImageDisplayFlowFunction.instance.getComplaintImage(complaintId)
```

### Community Wall
```dart
// Get single image
ImageDisplayFlowFunction.instance.getCommunityWallImage(postId)
```

---

## 🔧 Firestore Field Names

### Marketplace (listings collection)
- Primary: `images` (array)
- Fallback: `imageUrl`, `image`, `productImage`

### Profile (users collection)
- Primary: `profileImage`
- Fallback: `profileImageUrl`, `photoURL`

### Complaints (complaints collection)
- Primary: `imageUrl`
- Fallback: `image`, `complaintImage`

### Community Wall (posts collection)
- Primary: `imageUrl`
- Fallback: `image`, `postImage`

---

## ✅ Implementation Checklist

### For New Image Upload Feature
- [ ] Import `ImageUploadFlowFunction`
- [ ] Call `uploadImage()` with correct folder
- [ ] Pass returned URL to Firestore
- [ ] Handle success/failure results
- [ ] Show user feedback

### For New Image Display Feature
- [ ] Import `ImageDisplayFlowFunction`
- [ ] Choose: one-time fetch or real-time stream
- [ ] Call appropriate method with correct ID
- [ ] Handle success/failure results
- [ ] Show loading state
- [ ] Show error icon if failed

---

## 🐛 Troubleshooting

### Image Not Uploading
1. Check file exists and is readable
2. Check file size < 10MB
3. Check file format (jpg, png, gif, webp)
4. Check user is authenticated
5. Check Cloudinary credentials

### Image Not Displaying
1. Check Firestore field name matches expected name
2. Check image URL is valid (not empty)
3. Check user has read permission
4. Check network connection
5. Check Firestore security rules

### Real-time Updates Not Working
1. Check stream is properly set up
2. Check Firestore security rules allow read
3. Check user is authenticated
4. Check document exists in Firestore

---

## 📊 Error Codes

### Upload Errors
- `NOT_AUTHENTICATED` - User not logged in
- `FILE_NOT_FOUND` - Image file doesn't exist
- `FILE_TOO_LARGE` - File > 10MB
- `INVALID_FORMAT` - Not jpg/png/gif/webp
- `CLOUDINARY_ERROR` - Cloudinary upload failed
- `FIRESTORE_ERROR` - Firestore save failed
- `UNEXPECTED_ERROR` - Unknown error

### Display Errors
- `LISTING_NOT_FOUND` - Listing doesn't exist
- `USER_NOT_FOUND` - User doesn't exist
- `COMPLAINT_NOT_FOUND` - Complaint doesn't exist
- `POST_NOT_FOUND` - Post doesn't exist
- `IMAGE_NOT_FOUND` - No image URL in document
- `FETCH_ERROR` - Error fetching from Firestore
- `STREAM_ERROR` - Error in real-time stream

---

## 🎨 UI Examples

### Upload Button
```dart
ElevatedButton(
  onPressed: () async {
    final result = await ImageUploadFlowFunction.instance.uploadImage(
      imagePath: _selectedFile.path,
      folder: 'marketplace',
    );
    
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image uploaded successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result.message}')),
      );
    }
  },
  child: Text('Upload Image'),
)
```

### Display Image
```dart
FutureBuilder<ImageDisplayResult>(
  future: ImageDisplayFlowFunction.instance
      .getMarketplaceProductImage(listingId: listingId),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    if (snapshot.hasData && snapshot.data!.success) {
      return Image.network(
        snapshot.data!.imageUrl!,
        fit: BoxFit.cover,
      );
    }
    
    return Icon(Icons.image_not_supported);
  },
)
```

### Stream Image
```dart
StreamBuilder<ImageDisplayResult>(
  stream: ImageDisplayFlowFunction.instance
      .streamProfileImage(userId: userId),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.success) {
      return CircleAvatar(
        backgroundImage: NetworkImage(snapshot.data!.imageUrl!),
      );
    }
    return CircleAvatar(child: Icon(Icons.person));
  },
)
```

---

## 📚 Related Files

- `lib/src/services/image_upload_flow_function.dart` - Upload implementation
- `lib/src/services/image_display_flow_function.dart` - Display implementation
- `lib/src/services/profile_image_service.dart` - Profile image streaming
- `lib/src/services/cloudinary_service.dart` - Cloudinary integration
- `lib/src/screens/marketplace_product_detail_screen.dart` - Example usage
- `lib/profile_screen.dart` - Example streaming usage

---

## 🚀 Performance Tips

1. **Use Streaming for Real-time Updates**
   - Profile images that change frequently
   - Community wall posts
   - Marketplace listings

2. **Use One-time Fetch for Static Images**
   - Complaint images (don't change)
   - Product details (rarely change)

3. **Add Image Caching**
   - Use `CachedNetworkImage` for better performance
   - Reduces network requests

4. **Optimize Image Size**
   - Compress before upload
   - Use appropriate dimensions
   - Cloudinary handles optimization

---

## ✨ Best Practices

1. **Always Handle Errors**
   - Check `result.success` before using URL
   - Show user-friendly error messages
   - Log errors for debugging

2. **Show Loading States**
   - Display spinner while uploading
   - Display skeleton while fetching
   - Improve user experience

3. **Validate Before Upload**
   - Check file exists
   - Check file size
   - Check file format

4. **Use Correct Folder Names**
   - Helps organize images in Cloudinary
   - Makes debugging easier
   - Improves maintainability

5. **Test with Real Data**
   - Test with actual Firestore documents
   - Test with various image sizes
   - Test with network errors

