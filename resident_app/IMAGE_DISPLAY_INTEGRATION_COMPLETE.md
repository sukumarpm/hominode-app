# Image Display Integration - Complete Flow Function Implementation

## Overview
Images must work according to the flow function pattern across ALL screens:
- **STORE** (upload) → **FETCH** (retrieve from Firestore) → **SHOW** (display in UI)

## Current Status

### ✅ Completed
1. **ImageUploadFlowFunction** - Complete upload flow with validation, Cloudinary upload, and Firestore storage
2. **ImageDisplayFlowFunction** - Complete display flow with methods for all image types
3. **ProfileImageService** - Real-time streaming for profile images
4. **MarketplaceProductDetailScreen** - Updated to use ImageDisplayFlowFunction with fallback

### 🔄 In Progress
- Integrating image display across all screens

---

## Image Flow Architecture

### Upload Flow (ImageUploadFlowFunction)
```
User selects image
    ↓
Step 1: Validate authentication (Firebase Auth + Firestore fallback)
    ↓
Step 2: Validate image file (exists, size <10MB, valid format)
    ↓
Step 3: Upload to Cloudinary
    ↓
Step 4: Save URL to Firestore (users collection)
    ↓
Step 5: Return success with image URL
```

### Display Flow (ImageDisplayFlowFunction)
```
Screen needs to display image
    ↓
Query Firestore for document (listings, users, complaints, posts)
    ↓
Extract image URL from document
    ↓
Display image in UI with error handling
    ↓
Optional: Stream for real-time updates
```

---

## Firestore Field Names

### Profile Images (users collection)
- Primary: `profileImage`
- Fallback: `profileImageUrl`, `photoURL`

### Marketplace Images (listings collection)
- Primary: `images` (array of URLs)
- Fallback: `imageUrl`, `image`, `productImage`

### Complaint Images (complaints collection)
- Primary: `imageUrl`
- Fallback: `image`, `complaintImage`

### Community Wall Images (posts collection)
- Primary: `imageUrl`
- Fallback: `image`, `postImage`

---

## Integration Guide

### 1. Marketplace Product Detail Screen ✅
**File**: `lib/src/screens/marketplace_product_detail_screen.dart`

**Status**: UPDATED
- Uses `widget.listing.images` for primary display
- Falls back to `ImageDisplayFlowFunction.getMarketplaceProductImage()` if no images
- Handles loading and error states

**Code**:
```dart
// Primary: Use listing.images array
if (widget.listing.images.isNotEmpty) {
  PageView.builder(
    itemCount: widget.listing.images.length,
    itemBuilder: (context, index) {
      return Image.network(widget.listing.images[index]);
    },
  )
}

// Fallback: Use ImageDisplayFlowFunction
else {
  FutureBuilder<ImageDisplayResult>(
    future: ImageDisplayFlowFunction.instance
        .getMarketplaceProductImage(listingId: widget.listing.id ?? ''),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.success) {
        return Image.network(snapshot.data!.imageUrl!);
      }
      return Icon(Icons.image_not_supported);
    },
  )
}
```

---

### 2. Profile Screen ✅
**File**: `lib/profile_screen.dart`

**Status**: ALREADY USING STREAM
- Uses `ProfileImageService.instance.streamProfileImage(userId: _userId!)`
- Real-time image updates
- Proper error handling with fallback icon

---

### 3. Edit Profile Screen
**File**: `lib/src/screens/edit_profile_screen.dart`

**Status**: NEEDS VERIFICATION
- Should use `ImageUploadFlowFunction` for uploading profile images
- Should display current image using `ProfileImageService.streamProfileImage()`

---

### 4. Marketplace Screen (Browse Tab)
**File**: `lib/src/screens/marketplace_screen.dart`

**Status**: NEEDS UPDATE
- Display listing thumbnails using `listing.images[0]` or fallback to ImageDisplayFlowFunction
- Show loading skeleton while fetching

---

### 5. Marketplace Your Products Screen
**File**: `lib/src/screens/marketplace_your_products_screen.dart`

**Status**: NEEDS UPDATE
- Display seller's own product images
- Use `listing.images` with fallback to ImageDisplayFlowFunction

---

### 6. Community Wall Screen
**File**: `lib/community_wall_screen.dart`

**Status**: NEEDS UPDATE
- Display post images using `ImageDisplayFlowFunction.getCommunityWallImage(postId)`
- Stream for real-time updates: `streamCommunityWallImage(postId)`

---

### 7. Complaints Screen
**File**: `lib/complaints_screen.dart`

**Status**: NEEDS UPDATE
- Display complaint images using `ImageDisplayFlowFunction.getComplaintImage(complaintId)`
- Show in complaint detail modal

---

## Implementation Checklist

### Phase 1: Core Screens (DONE)
- [x] Marketplace Product Detail Screen
- [x] Profile Screen (already streaming)

### Phase 2: Upload Screens (VERIFY)
- [ ] Edit Profile Screen - verify image upload uses ImageUploadFlowFunction
- [ ] Marketplace Create Listing Screen - verify images array is populated
- [ ] Complaint Submission - verify image upload

### Phase 3: Display Screens (TODO)
- [ ] Marketplace Browse Tab - show thumbnails
- [ ] Marketplace Your Products - show seller's products
- [ ] Community Wall - show post images
- [ ] Complaints - show complaint images

### Phase 4: Optimization (TODO)
- [ ] Add image caching
- [ ] Add image compression
- [ ] Add loading skeletons
- [ ] Add error recovery

---

## Testing Checklist

### Marketplace Images
- [ ] Upload image when creating listing
- [ ] Image displays in product detail screen
- [ ] Image displays in browse tab
- [ ] Image displays in your products tab
- [ ] Multiple images work in PageView

### Profile Images
- [ ] Upload profile image in edit profile
- [ ] Image displays in profile screen
- [ ] Real-time update when image changes
- [ ] Fallback icon shows if no image

### Community Wall Images
- [ ] Upload image with post
- [ ] Image displays in community wall
- [ ] Real-time update when image changes

### Complaint Images
- [ ] Upload image with complaint
- [ ] Image displays in complaint detail
- [ ] Image displays in complaint history

---

## Troubleshooting

### Images Not Showing
1. Check Firestore field names match expected names
2. Verify image URLs are valid (not empty, proper format)
3. Check Cloudinary upload was successful
4. Verify user has permission to access image

### Images Uploading But Not Displaying
1. Check Firestore document has correct field name
2. Verify ImageDisplayFlowFunction is querying correct collection
3. Check image URL is accessible from client

### Real-time Updates Not Working
1. Verify stream is properly set up
2. Check Firestore security rules allow read access
3. Verify user is authenticated

---

## Code Examples

### Upload Image (Profile)
```dart
final result = await ImageUploadFlowFunction.instance.uploadImage(
  imagePath: _photoFile!.path,
  folder: 'profile_pictures',
  publicId: 'user_$userId',
);

if (result.success) {
  print('✅ Image uploaded: ${result.imageUrl}');
} else {
  print('❌ Upload failed: ${result.message}');
}
```

### Display Image (Marketplace)
```dart
final result = await ImageDisplayFlowFunction.instance
    .getMarketplaceProductImage(listingId: listingId);

if (result.success && result.imageUrl != null) {
  Image.network(result.imageUrl!);
} else {
  Icon(Icons.image_not_supported);
}
```

### Stream Image (Profile)
```dart
StreamBuilder<ImageDisplayResult>(
  stream: ProfileImageService.instance.streamProfileImage(userId: userId),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.success) {
      return Image.network(snapshot.data!.imageUrl!);
    }
    return Icon(Icons.person);
  },
)
```

---

## Next Steps

1. **Verify Edit Profile Screen** - Ensure it uses ImageUploadFlowFunction
2. **Update Marketplace Browse Tab** - Show image thumbnails
3. **Update Community Wall** - Display post images
4. **Update Complaints** - Display complaint images
5. **Add Image Caching** - Improve performance
6. **Test All Screens** - Verify images display correctly

---

## Related Files

- `lib/src/services/image_upload_flow_function.dart` - Upload flow
- `lib/src/services/image_display_flow_function.dart` - Display flow
- `lib/src/services/profile_image_service.dart` - Profile image streaming
- `lib/src/services/cloudinary_service.dart` - Cloudinary integration
- `lib/src/screens/marketplace_product_detail_screen.dart` - Updated
- `lib/profile_screen.dart` - Already using stream

