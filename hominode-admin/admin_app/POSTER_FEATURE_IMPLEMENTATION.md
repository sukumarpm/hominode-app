# Poster Feature Implementation Guide

## Overview
Complete poster management system with Cloudinary unsigned upload and Firestore storage.

## Files Created

### 1. Service Layer
**File**: `lib/services/poster_service.dart`
- `uploadPoster()` - Upload to Cloudinary + save to Firestore
- `getPostersForBuilding()` - Real-time stream for residents
- `getAdminPosters()` - Real-time stream for admin management
- `deletePoster()` - Delete from Firestore
- `PosterModel` - Data model

### 2. Admin UI
**File**: `lib/poster_management_screen.dart`
- Grid view of all posters
- Add poster modal with image picker
- Delete poster with confirmation
- Real-time updates

### 3. Resident UI
**File**: `lib/widgets/poster_carousel.dart`
- PageView carousel for posters
- Dot indicators
- Real-time updates
- Error handling

## Firestore Structure

```
posters/
├── {posterId}
│   ├── title: string
│   ├── imageUrl: string (Cloudinary URL)
│   ├── buildingId: string
│   ├── adminId: string
│   └── createdAt: timestamp
```

## Firestore Rules

Add these rules to your Firestore:

```
match /posters/{document=**} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update: if request.auth != null && resource.data.adminId == request.auth.uid;
  allow delete: if request.auth != null && resource.data.adminId == request.auth.uid;
}
```

## Integration Steps

### Step 1: Add to Admin Dashboard
In your admin dashboard, add a button to navigate to poster management:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PosterManagementScreen(
          buildingId: buildingId,
          buildingName: buildingName,
        ),
      ),
    );
  },
  child: const Text('Manage Posters'),
)
```

### Step 2: Add to Resident Home Screen
In your resident home screen, add the poster carousel:

```dart
import 'widgets/poster_carousel.dart';

// In your build method:
PosterCarousel(buildingId: residentBuildingId),
```

### Step 3: Update pubspec.yaml
Ensure you have these dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^4.0.0
  firebase_auth: ^4.0.0
  image_picker: ^0.8.0
  http: ^0.13.0
```

## Features

### Admin Features
✅ Upload poster image using ImagePicker
✅ Upload to Cloudinary (unsigned)
✅ Save metadata to Firestore
✅ View all posters in grid
✅ Delete posters
✅ Real-time updates

### Resident Features
✅ View posters in carousel
✅ Swipe between posters
✅ Dot indicators
✅ Real-time updates
✅ Error handling

## Upload Flow

```
1. Admin picks image
2. Validate image (size, format)
3. Upload to Cloudinary
4. Get secure_url
5. Save to Firestore with metadata
6. Return to UI
```

## Fetch Flow

```
1. Resident opens home screen
2. PosterCarousel queries Firestore
3. Filter by buildingId
4. Real-time stream updates
5. Display in PageView
```

## Delete Flow

```
1. Admin clicks delete
2. Show confirmation dialog
3. Delete from Firestore
4. UI updates automatically
```

## Error Handling

- File validation (size, format)
- Cloudinary upload errors
- Firestore write errors
- Network timeouts
- User feedback via SnackBar

## Testing

### Test Upload
1. Go to Poster Management
2. Click "Add Poster"
3. Select image
4. Enter title
5. Click "Upload Poster"
6. Verify in Firestore

### Test Display
1. Open resident home screen
2. Verify posters appear
3. Swipe between posters
4. Check real-time updates

### Test Delete
1. Go to Poster Management
2. Click delete on a poster
3. Confirm deletion
4. Verify removed from list

## Troubleshooting

### Upload Fails with 401
- Check Cloudinary upload preset exists
- Verify preset is set to "Unsigned"
- Check admin is authenticated

### Posters Not Showing
- Verify buildingId matches
- Check Firestore rules allow read
- Check network connection

### Real-time Updates Not Working
- Verify Firestore connection
- Check stream is active
- Verify buildingId is correct

## Performance Tips

1. Limit poster count per building
2. Use image compression (80% quality)
3. Implement pagination if many posters
4. Cache images on device
5. Use CDN for image delivery

## Security

✅ No API secret in code
✅ Unsigned upload only
✅ Firestore rules enforce ownership
✅ Admin-only delete
✅ Real-time access control

## Next Steps

1. Integrate into admin dashboard
2. Integrate into resident home screen
3. Add poster expiry feature
4. Add poster scheduling
5. Add analytics tracking
