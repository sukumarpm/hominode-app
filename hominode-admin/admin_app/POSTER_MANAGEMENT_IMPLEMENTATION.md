# Poster Management Feature - Complete Implementation Guide

## Overview
Complete poster management system for admin and resident apps with real-time updates using Firebase and Cloudinary.

## Files Created

### 1. **Services**
- `lib/services/poster_service.dart` - Core service for poster operations

### 2. **Admin Screens**
- `lib/poster_management_screen.dart` - Admin poster upload and management

### 3. **Resident Widgets**
- `lib/widgets/poster_carousel.dart` - Carousel display for posters
- `lib/widgets/poster_list.dart` - List display for posters

---

## Firestore Structure

```
posters/
├── {posterId}
│   ├── imageUrl (string) - Cloudinary URL
│   ├── buildingId (string) - Building reference
│   ├── adminId (string) - Admin who uploaded
│   ├── title (string) - Poster title
│   ├── createdAt (timestamp)
│   └── updatedAt (timestamp)
```

---

## Firestore Rules

Add this to your Firestore security rules:

```
match /posters/{posterId} {
  allow read: if request.auth.uid != null;
  allow write: if request.auth.uid != null && (resource.data.adminId == request.auth.uid || request.resource.data.adminId == request.auth.uid);
  allow create: if request.auth.uid != null;
  allow delete: if request.auth.uid != null && resource.data.adminId == request.auth.uid;
}
```

---

## Integration Steps

### Step 1: Add Dependencies to pubspec.yaml

```yaml
dependencies:
  image_picker: ^1.0.0
  cloudinary_flutter: ^1.0.0  # For Cloudinary upload
  cloud_firestore: ^4.0.0
  firebase_auth: ^4.0.0
```

### Step 2: Admin App - Add to Navigation

In your admin app's main navigation/drawer:

```dart
ListTile(
  leading: const Icon(Icons.image),
  title: const Text('Poster Management'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PosterManagementScreen(),
      ),
    );
  },
),
```

### Step 3: Resident App - Display Posters on Home Screen

In your resident home screen:

```dart
// Option 1: Carousel Display
import 'package:admin_app/widgets/poster_carousel.dart';

// In your home screen build method:
PosterCarousel(
  buildingId: userBuildingId,
  height: 200,
),

// Option 2: List Display
import 'package:admin_app/widgets/poster_list.dart';

PosterList(
  buildingId: userBuildingId,
  showTitle: true,
),
```

---

## Feature Details

### Admin Features

#### 1. Upload Poster
- Select image from gallery
- Enter poster title
- Select target building
- Upload to Cloudinary
- Save metadata to Firestore
- Real-time list update

#### 2. View Posters
- Stream-based real-time updates
- Shows all uploaded posters
- Displays creation date
- Shows poster thumbnail

#### 3. Delete Poster
- Confirmation dialog
- Removes from Firestore
- UI updates automatically
- Only admin can delete own posters

### Resident Features

#### 1. Carousel Display
- Auto-scrolling carousel
- Page indicators
- Tap to view full size
- Smooth animations
- Responsive design

#### 2. List Display
- Vertical list of posters
- Thumbnail preview
- Creation date
- Tap to view details
- Infinite scroll support

#### 3. Real-time Updates
- StreamBuilder for live data
- Automatic UI refresh
- Error handling
- Loading states

---

## Cloudinary Integration

### Setup Cloudinary Upload

Replace the `_uploadToCloudinary` method in `poster_service.dart`:

```dart
Future<String> _uploadToCloudinary(File imageFile) async {
  try {
    final cloudinary = CloudinaryPublic(
      'YOUR_CLOUD_NAME',
      'YOUR_UPLOAD_PRESET',
      cache: false,
    );

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(imageFile.path),
      folder: 'posters',
      resourceType: CloudinaryResourceType.Image,
    );

    return response.secureUrl;
  } catch (e) {
    throw Exception('Cloudinary upload failed: $e');
  }
}
```

### Get Cloudinary Credentials

1. Go to https://cloudinary.com
2. Sign up/Login
3. Get your Cloud Name from dashboard
4. Create Upload Preset (Settings → Upload)
5. Use in code above

---

## Usage Examples

### Admin: Upload Poster

```dart
final posterService = PosterService();

await posterService.uploadPoster(
  imageFile: selectedImageFile,
  buildingId: 'building_123',
  title: 'Community Event',
);
```

### Admin: Delete Poster

```dart
await posterService.deletePoster('poster_id_123');
```

### Resident: Get Posters Stream

```dart
posterService.getPostersForBuilding('building_123').listen((posters) {
  print('Posters: ${posters.length}');
});
```

---

## Error Handling

All methods include:
- Try-catch blocks
- User-friendly error messages
- Console logging for debugging
- Graceful fallbacks

---

## Performance Optimization

1. **Image Compression**: ImagePicker set to 80% quality
2. **Lazy Loading**: Images load on demand
3. **Pagination**: Use orderBy with limit for large datasets
4. **Caching**: Firestore automatic caching
5. **Real-time**: StreamBuilder for efficient updates

---

## Testing Checklist

- [ ] Admin can upload poster
- [ ] Poster appears in Firestore
- [ ] Resident sees poster in carousel
- [ ] Resident sees poster in list
- [ ] Delete removes poster
- [ ] Real-time updates work
- [ ] Error handling works
- [ ] Images load correctly
- [ ] Carousel pagination works
- [ ] Tap to view detail works

---

## Troubleshooting

### Posters not showing
- Check buildingId matches
- Verify Firestore rules
- Check network connection
- Review console logs

### Upload fails
- Verify Cloudinary credentials
- Check image file exists
- Verify admin authentication
- Check Firestore permissions

### Real-time not updating
- Verify StreamBuilder is active
- Check Firestore listener
- Verify network connection
- Check for errors in console

---

## Next Steps

1. Implement Cloudinary upload
2. Add image compression
3. Add poster expiry feature
4. Add poster analytics
5. Add poster scheduling
6. Add poster categories
7. Add poster comments
8. Add poster sharing

---

## Support

For issues or questions, check:
- Console logs for errors
- Firestore rules
- Cloudinary configuration
- Network connectivity
- Authentication status
