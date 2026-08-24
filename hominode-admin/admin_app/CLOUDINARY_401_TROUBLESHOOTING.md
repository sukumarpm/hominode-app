# Cloudinary 401 Error - Complete Troubleshooting Guide

## Error Message
```
Failed to upload image to Cloudinary: Cloudinary upload failed: 401
```

## What This Means
HTTP 401 = Unauthorized. Cloudinary is rejecting your upload request.

## Root Causes & Solutions

### 1. Admin Not Authenticated ⚠️ MOST COMMON
**Symptom**: Error appears immediately when trying to upload

**Check**:
- Make sure you're logged in as an admin
- Check console logs for: `Admin not authenticated or ID is empty`

**Fix**:
- Log out and log back in
- Verify admin credentials are correct
- Check that Firebase Auth is working

---

### 2. Upload Preset Mismatch
**Symptom**: 401 error with "invalid upload preset"

**Your Setup**:
- Cloud Name: `dailyccofb` ✅
- Upload Preset: `apartment_images_preset` ✅
- Mode: Unsigned ✅

**Verify in Cloudinary**:
1. Go to https://console.cloudinary.com/
2. Click Settings → Upload
3. Find "apartment_images_preset"
4. Confirm it exists and Mode = "Unsigned"

**If Missing**:
1. Click "Add upload preset"
2. Name: `apartment_images_preset`
3. Mode: Unsigned
4. Save

---

### 3. Cloud Name Mismatch
**Check**:
```dart
static const String CLOUDINARY_CLOUD_NAME = 'dailyccofb';
```

**Verify**:
- Go to Cloudinary Dashboard
- Top-left corner shows your cloud name
- Must match exactly (case-sensitive)

---

### 4. File Issues
**Symptoms**:
- File doesn't exist
- File is empty
- File is too large

**Check Console Logs**:
- Look for: `File size: X bytes`
- Look for: `Image file does not exist`
- Look for: `Image file is too large`

**Limits**:
- Max file size: 10MB
- Supported formats: JPG, PNG, GIF, WebP

---

### 5. Network/CORS Issues
**Symptom**: 401 error but everything looks correct

**Check**:
1. Internet connection is working
2. Cloudinary API is accessible
3. No firewall blocking uploads

**Test**:
- Try uploading directly to Cloudinary: https://cloudinary.com/console/c-dailyccofb/media_library/upload
- If that works, issue is with app code
- If that fails, issue is with Cloudinary account

---

## Debugging Steps

### Step 1: Check Console Logs
When you try to upload, look for these logs:

```
🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Starting image upload...
🔐 STEP 1: Validating admin authentication...
✅ STEP 1 PASSED: Admin authenticated - [ADMIN_ID]
📋 STEP 2: Validating input data...
✅ STEP 2 PASSED: Input data validated - File size: X bytes
📤 STEP 3: Uploading image to Cloudinary...
📤 STEP 3.1: Preparing upload request...
📤 STEP 3.1d: Cloud Name: dailyccofb
📤 STEP 3.1e: Upload Preset: apartment_images_preset
📤 STEP 3.2: Sending upload request to Cloudinary...
📤 STEP 3.2b: Response status: 200
✅ STEP 3 PASSED: Image uploaded - [URL]
```

### Step 2: Identify Where It Fails
- If fails at STEP 1: Admin not authenticated
- If fails at STEP 2: File issue
- If fails at STEP 3: Cloudinary issue

### Step 3: Check Error Details
Look for error messages like:
```
❌ STEP 3 FAILED: Upload failed with status 401
   Response body: {"error":{"message":"Invalid upload preset"}}
```

---

## Quick Fixes

### Fix 1: Re-authenticate
```
1. Go to Profile
2. Click Sign Out
3. Log back in
4. Try uploading again
```

### Fix 2: Verify Preset Exists
```
1. Go to Cloudinary Dashboard
2. Settings → Upload → Upload presets
3. Search for "apartment_images_preset"
4. If not found, create it (Mode: Unsigned)
```

### Fix 3: Clear App Cache
```
Android: Settings → Apps → [App Name] → Storage → Clear Cache
iOS: Settings → General → iPhone Storage → [App Name] → Offload App → Reinstall
```

### Fix 4: Test with Simple Image
```
1. Use a small image (< 1MB)
2. Try uploading
3. If it works, original image might be corrupted
```

---

## If Still Not Working

### Option 1: Create New Preset
1. Go to Cloudinary Settings → Upload
2. Click "Add upload preset"
3. Name: `test_upload`
4. Mode: Unsigned
5. Save
6. Update code:
```dart
static const String CLOUDINARY_UPLOAD_PRESET = 'test_upload';
```

### Option 2: Check Cloudinary Status
- Visit https://status.cloudinary.com/
- Verify API is operational
- Check for any ongoing incidents

### Option 3: Contact Cloudinary Support
- Go to https://support.cloudinary.com/
- Provide error details and cloud name
- They can check account restrictions

---

## Success Indicators

When upload works, you should see:
1. ✅ Image appears in modal preview
2. ✅ "Image uploaded successfully" message
3. ✅ Image appears in Apartment Images list
4. ✅ Console shows: `✅ STEP 3 PASSED: Image uploaded`

---

## Prevention Tips

1. **Always check admin is logged in** before uploading
2. **Use small test images first** (< 1MB)
3. **Keep upload preset in Unsigned mode**
4. **Monitor console logs** for detailed error info
5. **Test directly in Cloudinary** if app upload fails

---

## Related Files
- Service: `admin_app/lib/services/cloudinary_apartment_images_service.dart`
- UI: `admin_app/lib/apartment_images_management_screen.dart`
- Config: Cloudinary Dashboard Settings → Upload
