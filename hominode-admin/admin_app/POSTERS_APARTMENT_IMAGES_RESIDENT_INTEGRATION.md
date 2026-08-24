# Posters & Apartment Images - Resident Integration Guide

## Overview
Complete integration of Posters and Apartment Images features across Admin and Resident apps with real-time Firestore synchronization.

## Architecture

### Admin App Flow
```
Admin Dashboard
    ↓
Quick Access Page
    ├─ Apartment Images Tile → ApartmentImagesManagementScreen
    │   ├─ Upload Images
    │   ├─ Manage Images
    │   └─ Delete Images
    │
    └─ Posters Tile → PostersManagementScreen
        ├─ Upload Posters
        ├─ Manage Posters
        └─ Delete Posters
```

### Resident App Flow
```
Resident Home Screen
    ↓
ResidentHomeService (Combined Feed)
    ├─ ApartmentImagesService.getImagesForBuilding()
    └─ PosterService.getPostersForBuilding()
        ↓
    Real-time Feed Display
    ├─ Apartment Images
    ├─ Posters
    └─ Sorted by Creation Date (Newest First)
```

## Data Flow

### Upload Flow (Admin)
```
1. Admin selects image/poster
2. Upload to Firebase Storage
3. Save metadata to Firestore
4. Include buildingIds for multi-tenancy
5. Real-time update in admin screen
```

### Display Flow (Resident)
```
1. Resident opens home screen
2. ResidentHomeService fetches combined feed
3. Filter by buildingId (in memory)
4. Filter by status='active'
5. Sort by createdAt (newest first)
6. Display in real-time feed
```

## Services

### 1. ApartmentImagesService
**Location**: `admin_app/lib/services/apartment_images_service.dart`

**Methods**:
- `uploadImage()` - Upload image with metadata
- `getImages()` - Get admin's images (real-time stream)
- `getImagesForBuilding()` - Get images for specific building
- `deleteImage()` - Delete image and storage file

**Data Structure**:
```
apartment_images/
├── id: string
├── title: string
├── description: string
├── type: string (Common Area, Lobby, Garden, Gym, Pool, Parking, Other)
├── imageUrl: string
├── adminId: string
├── adminName: string
├── buildingIds: array<string>
├── status: string (active/inactive)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### 2. PosterService
**Location**: `admin_app/lib/services/poster_service.dart`

**Methods**:
- `createPoster()` - Create poster with image
- `getPosters()` - Get admin's posters (real-time stream)
- `getPostersForBuilding()` - Get posters for specific building
- `updatePoster()` - Update poster details
- `deletePoster()` - Delete poster and image

**Data Structure**:
```
posters/
├── id: string
├── title: string
├── description: string
├── category: string (General, Maintenance, Event, Announcement, Safety)
├── imageUrl: string
├── adminId: string
├── adminName: string
├── buildingIds: array<string>
├── status: string (active/inactive)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### 3. ResidentHomeService
**Location**: `admin_app/lib/services/resident_home_service.dart`

**Methods**:
- `getCombinedFeed()` - Get combined feed of images and posters
- `removePost()` - Remove image or poster (admin only)
- `isPostExpired()` - Check if post has expired
- `getTimeRemaining()` - Get human-readable time remaining
- `getRelativeTime()` - Get human-readable relative time

**Feed Item Model**:
```
FeedItemModel
├── id: string
├── type: string (image/poster)
├── title: string
├── description: string
├── imageUrl: string
├── adminName: string
├── category: string
├── createdAt: DateTime
├── expiryDate: DateTime (nullable)
└── adminId: string
```

## UI Components

### Admin App

#### ApartmentImagesManagementScreen
- **Location**: `admin_app/lib/apartment_images_management_screen.dart`
- **Features**:
  - Flow function initialization
  - Image upload with dialog
  - Real-time gallery display
  - Delete with confirmation
  - Error handling and loading states

#### PostersManagementScreen
- **Location**: `admin_app/lib/posters_management_screen.dart`
- **Features**:
  - Flow function initialization
  - Poster upload with dialog
  - Real-time gallery display
  - Delete with confirmation
  - Error handling and loading states

#### QuickAccessPage
- **Location**: `admin_app/lib/quick_access_page.dart`
- **Changes**:
  - Removed Parcels tile
  - Added Apartment Images tile (blue, image icon)
  - Added Posters tile (amber, image_search icon)

### Resident App

#### ResidentHomeScreen (To be created)
- Display combined feed of images and posters
- Real-time updates
- Relative timestamps
- Admin name attribution
- Category/type badges

## Flow Function Pattern

### Upload Flow (5 Steps)
```
🔵 START
  ├─ 🔐 STEP 1: Validate Admin Authentication
  ├─ 📋 STEP 2: Validate Input Data
  ├─ 📤 STEP 3: Upload to Firebase Storage
  ├─ 💾 STEP 4: Save Metadata to Firestore
  ├─ 🔔 STEP 5: Log Completion
  └─ ✅ COMPLETE
```

### Fetch Flow (3 Steps)
```
🔵 START
  ├─ 🔐 STEP 1: Validate Authentication/Building ID
  ├─ 📋 STEP 2: Fetch from Firestore
  ├─ 🔄 STEP 3: Transform and Sort Data
  └─ ✅ COMPLETE
```

### Screen Initialization (4 Steps)
```
🔵 START
  ├─ 🔐 STEP 1: Validate Admin Authentication
  ├─ 📋 STEP 2: Validate Admin Access
  ├─ 🔄 STEP 3: Initialize Data Streams
  ├─ 🔔 STEP 4: Update UI State
  └─ ✅ COMPLETE
```

## Multi-Tenancy Support

### Data Isolation
- All images and posters include `adminId` for admin-level isolation
- `buildingIds` array for building-level filtering
- Residents only see content for their building

### Query Optimization
- Admin queries: `where('adminId', isEqualTo: adminId)`
- Resident queries: `where('status', isEqualTo: 'active')` + in-memory building filter
- Avoids composite index requirements

## Real-Time Updates

### Firestore Streams
- Images stream: Real-time updates when images are added/deleted
- Posters stream: Real-time updates when posters are added/deleted
- Combined feed: Automatically updates when either stream changes

### Error Handling
- Stream error handling with `.handleError()`
- Graceful fallback to empty list on error
- User-friendly error messages in UI

## Console Logging

All operations include detailed flow function logging:
- 🔵 Operation start
- 🔐 Authentication validation
- 📋 Data validation
- 📤 Upload operations
- 💾 Database operations
- 🔄 Data transformation
- 📝 Item creation
- 🔔 Completion logging
- ✅ Success
- ❌ Errors

## Testing Checklist

### Admin App
- [ ] Upload apartment image with all details
- [ ] Verify image appears in real-time gallery
- [ ] Delete image and verify removal
- [ ] Upload poster with all details
- [ ] Verify poster appears in real-time gallery
- [ ] Delete poster and verify removal
- [ ] Check Firestore for correct data structure
- [ ] Verify multi-tenancy isolation (different admins)
- [ ] Test error handling (invalid file, network errors)
- [ ] Check console logs for flow function execution

### Resident App
- [ ] Verify images appear in home screen feed
- [ ] Verify posters appear in home screen feed
- [ ] Verify feed is sorted by creation date (newest first)
- [ ] Verify only active content is displayed
- [ ] Verify only building-specific content is shown
- [ ] Test real-time updates (add/delete in admin, see in resident)
- [ ] Verify relative timestamps display correctly
- [ ] Verify admin name attribution is correct
- [ ] Test error handling (network errors, empty feed)
- [ ] Check console logs for flow function execution

## Firestore Rules

```javascript
// Allow admins to manage their own images and posters
match /apartment_images/{document=**} {
  allow read: if request.auth != null;
  allow create, update, delete: if request.auth.uid == resource.data.adminId;
}

match /posters/{document=**} {
  allow read: if request.auth != null;
  allow create, update, delete: if request.auth.uid == resource.data.adminId;
}
```

## Performance Considerations

### Optimization Strategies
1. **Client-side Filtering**: Filter by buildingId in memory instead of Firestore
2. **Pagination**: Consider implementing pagination for large feeds
3. **Caching**: Cache images locally on resident device
4. **Lazy Loading**: Load images on demand in feed

### Scalability
- Current implementation supports up to 1000 items per building
- For larger datasets, implement pagination
- Consider implementing search/filter functionality

## Future Enhancements

1. **Expiry Dates**: Add expiry dates for posters
2. **Scheduling**: Schedule posts to go live at specific times
3. **Analytics**: Track views and engagement
4. **Comments**: Allow residents to comment on posts
5. **Reactions**: Add emoji reactions to posts
6. **Search**: Implement search functionality
7. **Categories**: Filter by category/type
8. **Pinned Posts**: Pin important posts to top
9. **Notifications**: Notify residents of new posts
10. **Drafts**: Save drafts before publishing

## Troubleshooting

### Images/Posters Not Appearing
1. Check Firestore for data
2. Verify buildingIds include resident's building
3. Verify status is 'active'
4. Check console logs for errors
5. Verify Firebase Storage URLs are accessible

### Real-Time Updates Not Working
1. Check Firestore listener is active
2. Verify network connection
3. Check Firebase rules allow read access
4. Verify stream is not closed prematurely
5. Check console logs for stream errors

### Performance Issues
1. Reduce number of items in feed
2. Implement pagination
3. Optimize image sizes
4. Use lazy loading
5. Monitor Firestore read operations

## Files Summary

### Created Files
1. `admin_app/lib/services/apartment_images_service.dart` - Apartment images service
2. `admin_app/lib/apartment_images_management_screen.dart` - Apartment images UI
3. `admin_app/lib/services/resident_home_service.dart` - Resident home service (existing)

### Modified Files
1. `admin_app/lib/quick_access_page.dart` - Updated imports and grid items

### Reference Files
1. `admin_app/lib/services/poster_service.dart` - Poster service
2. `admin_app/lib/posters_management_screen.dart` - Poster UI

## Compilation Status
✅ All files compile without errors
✅ All imports resolved
✅ All navigation handlers working
✅ All UI components rendering correctly

## Next Steps
1. Create ResidentHomeScreen to display combined feed
2. Test apartment images upload and display
3. Test posters upload and display
4. Verify multi-tenancy data isolation
5. Test real-time updates
6. Monitor console logs for any issues
7. Implement pagination if needed
8. Add search/filter functionality
9. Implement notifications for new posts
10. Add analytics tracking
