# Cloudinary 401 Error Fix Guide

## Problem
Getting "Failed to upload image to Cloudinary: Cloudinary upload failed: 401" error

## Root Cause
The 401 Unauthorized error from Cloudinary typically means:
1. Upload preset doesn't exist or is misconfigured
2. Cloud name doesn't match the preset
3. Request format issue

## Solution

### Step 1: Verify Upload Preset Configuration
✅ Your preset `apartment_images_preset` exists and is set to "Unsigned"

### Step 2: Verify Cloud Name
Your cloud name is: `dailyccofb`

### Step 3: Test Upload Manually
Go to: https://cloudinary.com/console/c-dailyccofb/media_library/upload

Try uploading an image directly to verify the preset works.

### Step 4: Check Firestore Rules
Make sure your Firestore rules allow the admin to write to `apartmentImages` collection:

```
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
}
```

### Step 5: Verify Admin Authentication
The error might occur if:
- Admin is not properly authenticated
- Admin ID is null or empty
- Admin profile doesn't exist in Firestore

### Step 6: Enable Detailed Logging
The updated code now logs:
- Cloud name being used
- Upload preset being used
- Full response from Cloudinary
- Error details if upload fails

Check the console logs for more details about what's being sent to Cloudinary.

## If Still Getting 401

Try these steps:

1. **Create a new unsigned upload preset** in Cloudinary:
   - Go to Settings → Upload
   - Click "Add upload preset"
   - Name: `test_upload`
   - Mode: Unsigned
   - Save

2. **Update the code** to use the new preset:
   ```dart
   static const String CLOUDINARY_UPLOAD_PRESET = 'test_upload';
   ```

3. **Test again** with a simple image

4. **Check Cloudinary API Status**:
   - Visit https://status.cloudinary.com/
   - Verify API is operational

## Common Issues

### Issue: "Invalid upload preset"
- Solution: Verify preset name matches exactly (case-sensitive)
- Verify preset is set to "Unsigned" mode

### Issue: "Cloud name mismatch"
- Solution: Verify `CLOUDINARY_CLOUD_NAME = 'dailyccofb'` matches your account

### Issue: "Admin not authenticated"
- Solution: Make sure admin is logged in before uploading
- Check AdminService.getCurrentAdminId() returns a valid ID

### Issue: "Firestore write failed"
- Solution: Check Firestore rules allow writes to `apartmentImages` collection
- Verify admin has permission to write

## Next Steps

1. Check console logs for detailed error messages
2. Verify all credentials are correct
3. Test with a simple image first
4. If still failing, check Cloudinary dashboard for any account restrictions
