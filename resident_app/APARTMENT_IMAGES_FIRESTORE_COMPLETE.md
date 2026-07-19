# Apartment Images from Firestore - Complete Implementation

## Overview
Replaced demo images in the home screen banner with real apartment/building images fetched from Firestore `apartmentImages` collection.

---

## Changes Made

### 1. Updated Apartment Images Service
**File**: `resident_app/lib/src/services/apartment_images_service.dart`

**Key Improvements**:
- Fetches images from `apartmentImages` collection filtered by building ID
- Automatically retrieves building ID from SharedPreferences or user document
- Comprehensive debugging logs to identify issues
- Client-side filtering for better reliability
- Supports both one-time fetch and real-time streaming

**Methods**:
```dart
// One-time fetch
Future<List<String>> getApartmentImages()

// Real-time stream
Stream<List<String>> streamApartmentImages()
```

### 2. Dashboard Screen Integration
**File**: `resident_app/lib/dashboard_screen.dart`

**Changes**:
- Removed hardcoded demo image URLs
- Added `ApartmentImagesService` import
- Changed `_bannerImages` from final list to dynamic list
- Added `_loadApartmentImages()` method called in `initState()`
- Images now load from Firestore on dashboard initialization

---

## How It Works

### Data Flow

```
Dashboard Screen
    ↓
initState() calls _loadApartmentImages()
    ↓
ApartmentImagesService.getApartmentImages()
    ↓
1. Get buildingId from SharedPreferences
2. If not found, fetch from user document
3. Query apartmentImages collection
4. Filter by buildingId (client-side)
5. Sort by order field
6. Extract imageUrl values
    ↓
setState() updates _bannerImages list
    ↓
PageView carousel displays real images
```

### Building ID Resolution

The service tries multiple approaches to get the building ID:

1. **SharedPreferences** - Fastest, cached locally
2. **User Document** - Fallback if not in SharedPreferences
3. **Automatic Caching** - Saves to SharedPreferences for future use

---

## Firestore Collection Structure

**Collection**: `apartmentImages`

**Document Fields**:
```json
{
  "buildingId": "FUW27AslVObmyMMTDOX",
  "imageUrl": "https://res.cloudinary.com/...",
  "order": 1,
  "title": "Lobby",
  "description": "Main lobby area",
  "type": "Common Area",
  "status": "active",
  "created": "2026-03-27T23:30:40Z",
  "updated": "2026-03-27T23:30:40Z"
}
```

---

## Testing & Debugging

### Run the Test Script

```bash
# In your terminal, run:
flutter run lib/test_apartment_images.dart
```

This will:
1. Check if user is logged in
2. Display building ID from SharedPreferences
3. Show user document data
4. List all documents in apartmentImages collection
5. Test the service and show fetched images

### Console Output Example

```
🔵 Starting apartment images test...

📱 Current User: abc123xyz
📧 Email: user@example.com

💾 Building ID in SharedPreferences: FUW27AslVObmyMMTDOX

🔍 Checking user document...
✅ User document found
   Data: {buildingId: FUW27AslVObmyMMTDOX, name: preetham, ...}

🔍 Checking apartmentImages collection...
✅ Total documents in apartmentImages: 1

   Document ID: S8Q1isujTDjCpyNHAXAL
   Data: {buildingId: FUW27AslVObmyMMTDOX, imageUrl: https://..., ...}

🧪 Testing ApartmentImagesService...

✅ Service returned 1 images:
   - https://res.cloudinary.com/...
```

---

## Troubleshooting

### Images Not Showing

**Check 1: Building ID**
- Verify `buildingId` is stored in user document
- Check SharedPreferences has `building_id` key
- Run test script to see actual values

**Check 2: Collection Data**
- Verify `apartmentImages` collection exists
- Check documents have `buildingId` field matching user's building
- Ensure `imageUrl` field contains valid URLs

**Check 3: Firestore Rules**
- Verify user has read permission on `apartmentImages` collection
- Check rules allow authenticated users to read

**Check 4: Console Logs**
- Look for "🔵 ApartmentImages:" messages
- Check for "❌" error messages
- Run test script for detailed debugging

---

## Files Modified

1. `resident_app/lib/src/services/apartment_images_service.dart` - Enhanced service
2. `resident_app/lib/dashboard_screen.dart` - Integration
3. `resident_app/lib/test_apartment_images.dart` - New test file

---

## Status

✅ **Implementation Complete**
✅ **No Demo Images**
✅ **Real Firestore Data Only**
✅ **Flow Function Pattern Applied**
✅ **Enhanced Error Handling**
✅ **Debugging Support Added**

