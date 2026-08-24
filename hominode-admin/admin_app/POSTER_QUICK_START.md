# Poster Feature - Quick Start Guide

## What's Included

### Service: `PosterService`
```dart
// Upload poster
await posterService.uploadPoster(
  title: 'Summer Sale',
  imageFile: imageFile,
  buildingId: buildingId,
);

// Get posters for building (real-time)
posterService.getPostersForBuilding(buildingId)

// Get admin's posters (real-time)
posterService.getAdminPosters()

// Delete poster
await posterService.deletePoster(posterId)
```

### Admin Screen: `PosterManagementScreen`
```dart
PosterManagementScreen(
  buildingId: 'building123',
  buildingName: 'Tower A',
)
```

Features:
- Grid view of posters
- Add poster button
- Delete with confirmation
- Real-time updates

### Resident Widget: `PosterCarousel`
```dart
PosterCarousel(buildingId: 'building123')
```

Features:
- PageView carousel
- Dot indicators
- Swipe navigation
- Real-time updates

## Setup Steps

### 1. Firestore Rules
```
match /posters/{document=**} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update: if request.auth != null && resource.data.adminId == request.auth.uid;
  allow delete: if request.auth != null && resource.data.adminId == request.auth.uid;
}
```

### 2. Admin Dashboard Integration
```dart
import 'poster_management_screen.dart';

// Add button to navigate
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

### 3. Resident Home Integration
```dart
import 'widgets/poster_carousel.dart';

// Add to home screen
Column(
  children: [
    PosterCarousel(buildingId: residentBuildingId),
    // Other widgets...
  ],
)
```

## Data Flow

### Upload
```
ImagePicker → Validate → Cloudinary Upload → Get URL → Firestore Save
```

### Display
```
Firestore Query → Filter by buildingId → Real-time Stream → UI Update
```

### Delete
```
Delete Button → Confirmation → Firestore Delete → UI Update
```

## Firestore Structure
```
posters/
├── {posterId}
│   ├── title: "Summer Sale"
│   ├── imageUrl: "https://res.cloudinary.com/..."
│   ├── buildingId: "building123"
│   ├── adminId: "admin_uid"
│   └── createdAt: timestamp
```

## Key Features

✅ **Cloudinary Integration**
- Unsigned upload (no API secret)
- Automatic image optimization
- Secure URLs

✅ **Real-time Updates**
- StreamBuilder for live data
- Automatic UI refresh
- No manual refresh needed

✅ **Error Handling**
- File validation
- Upload error messages
- User-friendly feedback

✅ **Security**
- Admin-only delete
- Firestore rules enforcement
- No sensitive data exposed

## Testing Checklist

- [ ] Upload poster successfully
- [ ] Poster appears in admin grid
- [ ] Poster appears in resident carousel
- [ ] Delete poster works
- [ ] Real-time updates work
- [ ] Error messages display correctly
- [ ] Images load from Cloudinary
- [ ] Carousel swipe works

## Common Issues

### Upload Fails
- Check Cloudinary preset exists
- Verify admin is logged in
- Check image file size < 10MB

### Posters Not Showing
- Verify buildingId matches
- Check Firestore rules
- Verify network connection

### Delete Not Working
- Check admin authentication
- Verify Firestore rules
- Check poster ownership

## Performance

- Images compressed to 80% quality
- Lazy loading in carousel
- Real-time updates optimized
- No unnecessary rebuilds

## Next Steps

1. ✅ Service created
2. ✅ Admin UI created
3. ✅ Resident UI created
4. ⏳ Integrate into dashboard
5. ⏳ Integrate into home screen
6. ⏳ Test end-to-end
7. ⏳ Deploy to production

## Files

- `lib/services/poster_service.dart` - Service layer
- `lib/poster_management_screen.dart` - Admin UI
- `lib/widgets/poster_carousel.dart` - Resident UI
- `POSTER_FEATURE_IMPLEMENTATION.md` - Full guide
- `POSTER_QUICK_START.md` - This file
