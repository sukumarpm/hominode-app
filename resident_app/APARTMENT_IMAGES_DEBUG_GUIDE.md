# Apartment Images - Complete Debug Guide

## Issue: Banner Section is Empty

The banner shows "No images available" when it should display apartment images from Firestore.

---

## Step 1: Verify Firestore Data

### Check apartmentImages Collection

1. Go to Firebase Console → Firestore Database
2. Look for `apartmentImages` collection
3. Verify documents exist with these fields:
   - `buildingId` - Must match user's building ID
   - `imageUrl` - Valid Cloudinary URL
   - `order` - Number for sorting (1, 2, 3, etc.)

**Example Document**:
```json
{
  "buildingId": "FUW27AslVObmyMMTDOX",
  "imageUrl": "https://res.cloudinary.com/...",
  "order": 1,
  "title": "Lobby"
}
```

### Check User Document

1. Go to Firebase Console → Firestore Database
2. Open `users` collection
3. Find your user document
4. Verify it has `buildingId` field matching the apartmentImages documents

---

## Step 2: Check Console Logs

When you open the home screen, look for these logs in the console:

### Expected Logs (Success)
```
🔵 Dashboard: Loading apartment images...
🔵 ApartmentImages: Fetching apartment images...
✅ ApartmentImages: Building ID: FUW27AslVObmyMMTDOX
✅ ApartmentImages: Found 1 images for building FUW27AslVObmyMMTDOX
✅ ApartmentImages: Extracted 1 image URLs
   - https://res.cloudinary.com/...
✅ Dashboard: Service returned 1 images
✅ Dashboard: Apartment images loaded and UI updated
   Images: [https://res.cloudinary.com/...]
🖼️ Loading image 0: https://res.cloudinary.com/...
```

### Error Logs (Troubleshooting)

**If you see**:
```
❌ ApartmentImages: Building ID not found in SharedPreferences or user document
```
**Fix**: Ensure user document has `buildingId` field

**If you see**:
```
⚠️ ApartmentImages: No images found for building FUW27AslVObmyMMTDOX
```
**Fix**: Verify apartmentImages documents have matching `buildingId`

**If you see**:
```
❌ Error loading image 0: ...
```
**Fix**: Check if Cloudinary URL is valid and accessible

---

## Step 3: Run Diagnostic Test

Create a test to verify everything is connected:

```dart
// In your terminal:
flutter run lib/test_apartment_images.dart
```

This will show:
- Current user info
- Building ID from SharedPreferences
- User document data
- All apartmentImages documents
- Service test results

---

## Step 4: Manual Testing

### Test 1: Check Building ID
```dart
// Add this to dashboard_screen.dart temporarily
final prefs = await SharedPreferences.getInstance();
final buildingId = prefs.getString('building_id');
print('Building ID: $buildingId');
```

### Test 2: Check Firestore Query
```dart
// Add this to apartment_images_service.dart temporarily
final allDocs = await _firestore.collection('apartmentImages').get();
print('Total docs: ${allDocs.docs.length}');
for (var doc in allDocs.docs) {
  print('Doc: ${doc.id} - ${doc.data()}');
}
```

### Test 3: Check Image URLs
```dart
// Verify URLs are valid by opening in browser
// https://res.cloudinary.com/...
```

---

## Step 5: Fix Common Issues

### Issue 1: Building ID Mismatch
**Problem**: Building ID in user document doesn't match apartmentImages documents

**Solution**:
1. Get user's building ID from Firebase Console
2. Update all apartmentImages documents to use same buildingId
3. Restart app

### Issue 2: Invalid Cloudinary URLs
**Problem**: Images fail to load from Cloudinary

**Solution**:
1. Verify URL format: `https://res.cloudinary.com/...`
2. Test URL in browser - should display image
3. Check Cloudinary account has images uploaded
4. Verify upload preset is correct

### Issue 3: Firestore Rules Blocking Access
**Problem**: Permission denied when fetching images

**Solution**:
1. Go to Firebase Console → Firestore → Rules
2. Ensure authenticated users can read `apartmentImages`:
```javascript
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
}
```

### Issue 4: Images Not Showing in UI
**Problem**: Service returns images but UI shows empty

**Solution**:
1. Check console logs for "🖼️ Loading image" messages
2. Verify `_bannerImages` list is being updated
3. Check if images are loading (progress indicator should show)
4. Wait for images to load (may take 2-3 seconds)

---

## Step 6: Verify UI Updates

### Check if Images Load
1. Open home screen
2. Look for loading spinner in banner area
3. Wait 2-3 seconds for images to load
4. Images should appear with carousel

### Check if Carousel Works
1. Images should auto-scroll every 5 seconds
2. Page indicators (dots) should update
3. Manual swipe should change images

### Check if Empty State Shows
1. If no images found, should show "No images available"
2. Should NOT show blank gray box

---

## Complete Checklist

- [ ] apartmentImages collection exists in Firestore
- [ ] Documents have buildingId, imageUrl, order fields
- [ ] User document has buildingId field
- [ ] Building IDs match between user and apartmentImages
- [ ] Cloudinary URLs are valid and accessible
- [ ] Firestore rules allow read access
- [ ] Console shows "✅ Dashboard: Apartment images loaded"
- [ ] Images appear in banner with carousel
- [ ] Page indicators show and update
- [ ] Auto-scroll works every 5 seconds

---

## Quick Fix Checklist

If images still not showing:

1. **Check Firestore Console**:
   - apartmentImages collection exists? ✓
   - Documents have correct buildingId? ✓
   - imageUrl fields have valid URLs? ✓

2. **Check User Document**:
   - Has buildingId field? ✓
   - Value matches apartmentImages documents? ✓

3. **Check Console Logs**:
   - Any "❌" error messages? ✓
   - Building ID being found? ✓
   - Images being extracted? ✓

4. **Check Image URLs**:
   - Can open in browser? ✓
   - Cloudinary URLs valid? ✓

5. **Restart App**:
   - Hot reload may not work
   - Full restart: `flutter run`

---

## Support

If still having issues:

1. Run test script: `flutter run lib/test_apartment_images.dart`
2. Share console output
3. Check Firestore data structure
4. Verify building IDs match exactly

