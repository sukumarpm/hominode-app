# Cloudinary 401 Unauthorized Fix - Complete Guide

## Problem
Getting 401 Unauthorized error when uploading images to Cloudinary from Flutter app.

## Root Causes
1. Upload preset not created in Cloudinary dashboard
2. Upload preset not set to UNSIGNED mode
3. Incorrect endpoint URL
4. Missing or incorrect upload_preset field in request

## Solution Steps

### Step 1: Create Upload Preset in Cloudinary

1. Go to [Cloudinary Dashboard](https://cloudinary.com/console)
2. Navigate to **Settings** → **Upload**
3. Scroll to **Upload presets** section
4. Click **Add upload preset**
5. Configure:
   - **Name**: `lyvo_upload` (or `apartment_images_preset`)
   - **Mode**: Select **UNSIGNED** (critical!)
   - **Signing Mode**: Leave as default
   - Click **Save**

### Step 2: Verify Configuration

Your upload preset should have:
- ✅ Mode: UNSIGNED
- ✅ Name: `lyvo_upload` or `apartment_images_preset`
- ✅ No API Key or Secret required

### Step 3: Update Flutter Code

The services are already configured correctly:
- Endpoint: `https://api.cloudinary.com/v1_1/<cloud_name>/image/upload`
- Upload preset: Passed in request body
- No API key/secret used

### Step 4: Verify Request Format

The multipart request includes:
```
POST https://api.cloudinary.com/v1_1/dailyccofb/image/upload

Fields:
- file: [image file]
- upload_preset: lyvo_upload (or apartment_images_preset)
- public_id: [optional, for organization]
- tags: [optional, for filtering]
- context: [optional, for metadata]
```

## Testing

1. Open the app and navigate to apartment images upload
2. Select an image
3. Click upload
4. Check console logs for:
   - ✅ "Response status: 200" = Success
   - ❌ "Response status: 401" = Preset issue
   - ❌ "Response status: 400" = Request format issue

## Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Preset not UNSIGNED | Set preset to UNSIGNED mode |
| 401 Unauthorized | Preset doesn't exist | Create preset in dashboard |
| 400 Bad Request | Missing upload_preset | Already included in code |
| 400 Bad Request | Wrong field name | Use `upload_preset` (not `preset`) |
| 422 Unprocessable | File too large | Max 10MB (already validated) |

## Files Updated

1. `cloudinary_apartment_images_service.dart` - Apartment images upload
2. `poster_service.dart` - Poster upload

Both services use the same upload preset and endpoint.

## Next Steps

1. Create the upload preset in Cloudinary dashboard
2. Test upload with a small image
3. Check console logs for success/error messages
4. If still failing, verify:
   - Cloud name is correct: `dailyccofb`
   - Upload preset name matches exactly
   - Preset is set to UNSIGNED mode

## Firestore Integration

After successful Cloudinary upload:
1. Image URL is extracted from response (`secure_url`)
2. Metadata is saved to Firestore `apartmentImages` collection
3. Image is immediately available in the app

## Security Notes

- ✅ Using UNSIGNED preset (no API key exposed)
- ✅ File size validated (max 10MB)
- ✅ Admin authentication required
- ✅ Metadata stored in Firestore with admin/building IDs
