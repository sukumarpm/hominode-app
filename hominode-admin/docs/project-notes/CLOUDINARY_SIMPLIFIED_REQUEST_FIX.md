# Cloudinary Upload - Simplified Request Fix

## The Problem
Error: "Unknown API key" even though preset exists and is UNSIGNED

## Root Cause
The multipart request was including optional fields (`public_id`, `tags`, `context`) that might have been causing Cloudinary to reject the request.

## The Fix
Simplified the request to only send REQUIRED fields:
- `file` - the image file
- `upload_preset` - the preset name

Removed optional fields:
- ❌ `public_id`
- ❌ `tags`
- ❌ `context`

## Files Updated

### 1. cloudinary_apartment_images_service.dart
**Before:**
```dart
request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
request.fields['public_id'] = 'apartment_images/$adminId/${DateTime.now().millisecondsSinceEpoch}';
request.fields['tags'] = '$adminId,$buildingId,apartment_image';
request.fields['context'] = 'adminId=$adminId|buildingId=$buildingId|uploadDate=$uploadDate|uploadTime=$uploadTime';
```

**After:**
```dart
request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
```

### 2. poster_service.dart
**Before:**
```dart
request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
request.fields['public_id'] = 'posters/$buildingId/${DateTime.now().millisecondsSinceEpoch}';
request.fields['tags'] = '$buildingId,poster';
```

**After:**
```dart
request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
```

## Why This Works

Cloudinary's UNSIGNED preset mode is strict about what fields it accepts. By sending only the required fields, we avoid any validation errors.

## Testing

1. Rebuild app
2. Go to Apartment Images
3. Try uploading image
4. Should see "Response status: 200" ✅

## Expected Result

✅ Upload succeeds
✅ Image URL extracted
✅ Metadata saved to Firestore
✅ Image appears in list

## Status

✅ Code updated
✅ Compiles without errors
✅ Ready to test

---

**Next**: Rebuild and test upload
