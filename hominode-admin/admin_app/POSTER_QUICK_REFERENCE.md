# Poster Management - Quick Reference

## Files Overview

| File | Purpose |
|------|---------|
| `poster_service.dart` | Core service - upload, delete, fetch posters |
| `poster_management_screen.dart` | Admin UI - upload and manage posters |
| `poster_carousel.dart` | Resident widget - carousel display |
| `poster_list.dart` | Resident widget - list display |

---

## Quick Start

### 1. Admin: Add to Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const PosterManagementScreen()),
);
```

### 2. Resident: Add Carousel to Home
```dart
PosterCarousel(buildingId: buildingId, height: 200)
```

### 3. Resident: Add List to Home
```dart
PosterList(buildingId: buildingId, showTitle: true)
```

---

## Key Features

✅ **Admin Upload**
- Image picker integration
- Cloudinary upload
- Firestore storage
- Real-time list

✅ **Admin Delete**
- Confirmation dialog
- Firestore deletion
- Auto UI update

✅ **Resident View**
- Real-time stream
- Carousel display
- List display
- Detail modal

✅ **Real-time Updates**
- StreamBuilder
- Auto refresh
- Error handling
- Loading states

---

## Firestore Rules

```
match /posters/{posterId} {
  allow read: if request.auth.uid != null;
  allow write: if request.auth.uid != null && 
    (resource.data.adminId == request.auth.uid || 
     request.resource.data.adminId == request.auth.uid);
  allow create: if request.auth.uid != null;
  allow delete: if request.auth.uid != null && 
    resource.data.adminId == request.auth.uid;
}
```

---

## Data Model

```dart
class PosterModel {
  final String id;
  final String imageUrl;        // Cloudinary URL
  final String buildingId;      // Building reference
  final String adminId;         // Admin who uploaded
  final String title;           // Poster title
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

---

## Service Methods

### Upload
```dart
await posterService.uploadPoster(
  imageFile: file,
  buildingId: 'building_123',
  title: 'Event Poster',
);
```

### Delete
```dart
await posterService.deletePoster('poster_id');
```

### Get for Building
```dart
posterService.getPostersForBuilding('building_123')
```

### Get Admin Posters
```dart
posterService.getAdminPosters()
```

---

## UI Components

### Carousel
- Auto-scrolling
- Page indicators
- Tap to detail
- Responsive

### List
- Vertical layout
- Thumbnail preview
- Creation date
- Tap to detail

### Detail Modal
- Full image
- Title
- Date
- Close button

---

## Error Handling

All operations include:
- Try-catch blocks
- User-friendly messages
- Console logging
- Graceful fallbacks

---

## Next: Cloudinary Setup

1. Sign up at cloudinary.com
2. Get Cloud Name
3. Create Upload Preset
4. Update `_uploadToCloudinary()` method
5. Test upload

---

## Testing

```dart
// Test upload
final id = await posterService.uploadPoster(
  imageFile: testFile,
  buildingId: 'test_building',
  title: 'Test Poster',
);

// Test fetch
final posters = await posterService
  .getPostersForBuilding('test_building')
  .first;

// Test delete
await posterService.deletePoster(id);
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Posters not showing | Check buildingId, Firestore rules |
| Upload fails | Verify Cloudinary credentials |
| Real-time not working | Check StreamBuilder, network |
| Images not loading | Verify Cloudinary URL, permissions |

---

## Performance Tips

- Images compressed to 80% quality
- Lazy loading on demand
- Firestore automatic caching
- Real-time updates via streams
- Pagination ready for large datasets

---

## Security

- Only authenticated users can view
- Only admins can upload/delete own posters
- Firestore rules enforce access control
- Image URLs from Cloudinary (CDN)

---

## Customization

### Change Carousel Height
```dart
PosterCarousel(buildingId: id, height: 300)
```

### Change Image Quality
In `poster_service.dart`:
```dart
imageQuality: 90,  // 0-100
```

### Add Poster Expiry
Add `expiryDate` field to model and filter in queries

### Add Categories
Add `category` field and filter by category

---

## Support Resources

- Firestore docs: https://firebase.google.com/docs/firestore
- Cloudinary docs: https://cloudinary.com/documentation
- Flutter docs: https://flutter.dev/docs
- Image picker: https://pub.dev/packages/image_picker

---

## Version Info

- Flutter: 3.0+
- Dart: 2.17+
- Firebase: 4.0+
- Cloudinary: 1.0+
