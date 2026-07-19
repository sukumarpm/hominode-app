# 🚀 CLOUDINARY INTEGRATION - QUICK REFERENCE

## 📋 ONE-PAGE GUIDE

### Import
```dart
import '../services/cloudinary_service.dart';
```

### Upload Image
```dart
final imageUrl = await CloudinaryService.uploadImage(
  imagePath: image.path,
  folder: 'marketplace',  // or 'community_posts', 'profile_pictures', 'staff', 'complaints'
);
```

### Upload with Metadata
```dart
final result = await CloudinaryService.uploadImageWithMetadata(
  imagePath: image.path,
  folder: 'profile_pictures',
  publicId: 'user_$userId',
);

// result contains:
// - url: HTTPS URL
// - publicId: for deletion
// - width, height: dimensions
// - size: file size in bytes
// - format: image format
// - uploadedAt: timestamp
```

### Save to Firestore
```dart
await FirebaseFirestore.instance
    .collection('marketplaces')
    .doc(productId)
    .update({
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
```

### Display Image
```dart
// Simple
Image.network(imageUrl)

// With loading state
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

### Delete Image
```dart
await CloudinaryService.deleteImage(publicId);
```

---

## 🎯 FOLDER NAMES

| Feature | Folder | Example |
|---------|--------|---------|
| Marketplace | `marketplace` | `marketplace/product_123.jpg` |
| Community | `community_posts` | `community_posts/post_456.jpg` |
| User Profile | `profile_pictures` | `profile_pictures/user_789.jpg` |
| Staff | `staff` | `staff/staff_123.jpg` |
| Complaints | `complaints` | `complaints/complaint_456.jpg` |

---

## 📊 FIRESTORE FIELDS

```dart
// Marketplace
'imageUrl': 'https://res.cloudinary.com/...'

// Community Posts
'imageUrl': 'https://res.cloudinary.com/...'

// User Profile
'profileImageUrl': 'https://res.cloudinary.com/...'
'profileImagePublicId': 'profile_pictures/user_123'

// Staff
'profileImageUrl': 'https://res.cloudinary.com/...'

// Complaints
'imageUrl': 'https://res.cloudinary.com/...'
'imageUploadedAt': Timestamp
'imageUploadedBy': 'user_123'
```

---

## ⚡ QUICK EXAMPLES

### Marketplace
```dart
// Pick image
final image = await ImagePicker().pickImage(source: ImageSource.gallery);

// Upload
final url = await CloudinaryService.uploadImage(
  imagePath: image!.path,
  folder: 'marketplace',
);

// Save
await FirebaseFirestore.instance.collection('marketplaces').add({
  'title': 'Product',
  'price': 100,
  'imageUrl': url,
  'createdAt': FieldValue.serverTimestamp(),
});
```

### Community Post
```dart
final url = await CloudinaryService.uploadImage(
  imagePath: image!.path,
  folder: 'community_posts',
);

await FirebaseFirestore.instance.collection('community_posts').add({
  'content': 'Post content',
  'imageUrl': url,
  'createdAt': FieldValue.serverTimestamp(),
});
```

### User Profile
```dart
final result = await CloudinaryService.uploadImageWithMetadata(
  imagePath: image!.path,
  folder: 'profile_pictures',
  publicId: 'user_$userId',
);

await FirebaseFirestore.instance.collection('users').doc(userId).update({
  'profileImageUrl': result['url'],
  'profileImagePublicId': result['publicId'],
});
```

---

## 🔧 ERROR HANDLING

```dart
try {
  final url = await CloudinaryService.uploadImage(
    imagePath: image.path,
    folder: 'marketplace',
  );
  // Success
} catch (e) {
  print('Error: $e');
  // Show error to user
}
```

---

## 📱 UI PATTERNS

### Image Picker Button
```dart
ElevatedButton(
  onPressed: () async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  },
  child: const Text('Pick Image'),
)
```

### Upload Button
```dart
ElevatedButton(
  onPressed: _isUploading ? null : _uploadImage,
  child: _isUploading
      ? const CircularProgressIndicator()
      : const Text('Upload'),
)
```

### Image Preview
```dart
if (_selectedImage != null)
  Image.file(_selectedImage!, width: 200, height: 200)
```

### Network Image Display
```dart
CachedNetworkImage(
  imageUrl: imageUrl,
  width: 200,
  height: 200,
  fit: BoxFit.cover,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

---

## 🔐 CREDENTIALS

```dart
Cloud Name: de8yccofb
API Key: 866472317169594
API Secret: bURO931bdHNXrqly6XPKaFK8eMA
Upload URL: https://api.cloudinary.com/v1_1/de8yccofb/image/upload
```

---

## ✅ CHECKLIST

- [ ] Import CloudinaryService
- [ ] Add image picker UI
- [ ] Call uploadImage() on selection
- [ ] Save URL to Firestore
- [ ] Display using Image.network() or CachedNetworkImage
- [ ] Add error handling
- [ ] Add loading states
- [ ] Test upload
- [ ] Test display
- [ ] Test deletion

---

## 🎯 COMMON TASKS

### Task 1: Upload and Save
```dart
final url = await CloudinaryService.uploadImage(
  imagePath: image.path,
  folder: 'marketplace',
);
await firestore.collection('marketplaces').doc(id).update({'imageUrl': url});
```

### Task 2: Display with Loading
```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
)
```

### Task 3: Delete
```dart
await CloudinaryService.deleteImage(publicId);
await firestore.collection('marketplaces').doc(id).update({'imageUrl': FieldValue.delete()});
```

### Task 4: Update Profile Photo
```dart
final result = await CloudinaryService.uploadImageWithMetadata(
  imagePath: image.path,
  folder: 'profile_pictures',
  publicId: 'user_$userId',
);
await firestore.collection('users').doc(userId).update({'profileImageUrl': result['url']});
```

---

## 📞 TROUBLESHOOTING

| Issue | Solution |
|-------|----------|
| Upload fails | Check API key, verify image file exists |
| Image not showing | Verify URL is HTTPS, check network |
| Timeout error | Image too large, try smaller file |
| 401 error | Check credentials in CloudinaryService |
| Deletion fails | Verify publicId is correct |

---

## 🚀 READY TO USE

All features are implemented and ready:
- ✅ Marketplace products
- ✅ Community wall posts
- ✅ User profile photos
- ✅ Staff profile photos
- ✅ Complaint images

Just import and use!

---

**Status**: ✅ COMPLETE

**Build**: ✅ NO ERRORS

**Ready**: ✅ YES
