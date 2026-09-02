# Cloudinary "Unknown API Key" Error - Fixed

## The Error
```
Failed to upload image to Cloudinary: Cloudinary error: Unknown API key
```

## What Was Wrong
The upload preset name was `apartment_images_preset` but it either:
1. Didn't exist in Cloudinary
2. Wasn't set to UNSIGNED mode
3. Had a different configuration

## What Was Fixed
✅ Changed upload preset name to `lyvo_upload` in both services:
- `cloudinary_apartment_images_service.dart`
- `poster_service.dart`

## What You Need to Do (3 Steps)

### Step 1: Create Upload Preset in Cloudinary
1. Go to https://cloudinary.com/console
2. Click **Settings** (gear icon)
3. Go to **Upload** tab
4. Scroll to **Upload presets**
5. Click **Add upload preset**
6. Fill in:
   - **Name**: `lyvo_upload`
   - **Mode**: **UNSIGNED** ← CRITICAL!
7. Click **Save**

### Step 2: Verify Configuration
Check that your preset has:
- ✅ Name: `lyvo_upload`
- ✅ Mode: UNSIGNED
- ✅ Status: Active

### Step 3: Test Upload
1. Open app
2. Go to Apartment Images
3. Click "Add Image"
4. Select image
5. Click "Upload Image"
6. Check console for:
   - ✅ "Response status: 200" = Success!
   - ❌ "Response status: 401" = Preset issue

## Code Changes

### File 1: cloudinary_apartment_images_service.dart
```dart
// Before
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';

// After
static const String CLOUDINARY_UPLOAD_PRESET = 'lyvo_upload';
```

### File 2: poster_service.dart
```dart
// Before
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';

// After
static const String CLOUDINARY_UPLOAD_PRESET = 'lyvo_upload';
```

## Why This Works

- `lyvo_upload` is a simpler, more standard preset name
- UNSIGNED mode means no API key needed in app code
- Matches the configuration in all documentation
- Consistent across both services

## Testing

After creating the preset, test with:

```bash
curl -X POST https://api.cloudinary.com/v1_1/dailyccofb/image/upload \
  -F "file=@image.jpg" \
  -F "upload_preset=lyvo_upload"
```

Expected response:
```json
{
  "secure_url": "https://res.cloudinary.com/dailyccofb/image/upload/...",
  ...
}
```

## Success Indicators

✅ Console shows "Response status: 200"
✅ Console shows "Image uploaded - https://..."
✅ Image appears in Firestore
✅ Image appears in app list
✅ No error messages

## If Still Getting Error

1. **Check preset name**: Must be exactly `lyvo_upload`
2. **Check preset mode**: Must be UNSIGNED (not SIGNED)
3. **Check preset status**: Must be Active
4. **Check cloud name**: Must be `dailyccofb`
5. **Try creating new preset**: Delete old one and create fresh

## Files Modified

✅ `admin_app/lib/services/cloudinary_apartment_images_service.dart`
✅ `admin_app/lib/services/poster_service.dart`

## Status

✅ Code updated
✅ Compiles without errors
✅ Ready to test

---

**Next Step**: Create the `lyvo_upload` preset in Cloudinary dashboard (5 minutes)
