# Apartment Images - Quick Action Guide

## What Changed

✅ **UI Improvements**:
- Banner now shows "No images available" instead of blank
- Loading spinner while images fetch
- Error message if image fails to load
- Better visual feedback

✅ **Enhanced Logging**:
- Console shows detailed progress
- Easy to identify where issue is
- Logs show building ID, image count, URLs

✅ **Better Error Handling**:
- Empty state when no images
- Loading state while fetching
- Error state if image fails

---

## To Get Images Showing

### Step 1: Verify Firestore Data

Go to Firebase Console → Firestore → apartmentImages collection

**You need documents like this**:
```
Document 1:
  buildingId: "FUW27AslVObmyMMTDOX"
  imageUrl: "https://res.cloudinary.com/..."
  order: 1

Document 2:
  buildingId: "FUW27AslVObmyMMTDOX"
  imageUrl: "https://res.cloudinary.com/..."
  order: 2
```

### Step 2: Verify User Document

Go to Firebase Console → Firestore → users → [your user]

**Must have**:
```
buildingId: "FUW27AslVObmyMMTDOX"
```

### Step 3: Check Console Logs

Open app and go to home screen. Look for:

**Success** (images will show):
```
✅ Dashboard: Service returned 1 images
✅ Dashboard: Apartment images loaded and UI updated
```

**Problem** (images won't show):
```
❌ ApartmentImages: Building ID not found
⚠️ ApartmentImages: No images found for building
```

### Step 4: Restart App

```bash
flutter run
```

Images should now appear in the banner!

---

## If Images Still Don't Show

### Check 1: Building ID Match
```
User buildingId: FUW27AslVObmyMMTDOX
apartmentImages buildingId: FUW27AslVObmyMMTDOX
```
Must be EXACTLY the same!

### Check 2: Image URLs
Open URL in browser:
```
https://res.cloudinary.com/...
```
Should display image, not error

### Check 3: Firestore Rules
Go to Firebase Console → Firestore → Rules

Add this if missing:
```javascript
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
}
```

### Check 4: Run Test
```bash
flutter run lib/test_apartment_images.dart
```

Shows exactly what's in Firestore and what service returns

---

## Expected Result

When working correctly:

1. **Home screen loads**
2. **Banner shows loading spinner** (2-3 seconds)
3. **Images appear** with carousel
4. **Page indicators** (dots) show below
5. **Auto-scroll** every 5 seconds
6. **Manual swipe** changes images

---

## Files Updated

- `resident_app/lib/dashboard_screen.dart` - Better UI and logging
- `resident_app/lib/src/services/apartment_images_service.dart` - Enhanced service
- `resident_app/lib/test_apartment_images.dart` - Test script

---

## Next Steps

1. Verify Firestore data structure
2. Ensure building IDs match
3. Restart app
4. Check console logs
5. Images should appear!

