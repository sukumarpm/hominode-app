# Cloudinary Upload Preset Setup - REQUIRED

## ERROR FIXED ✅

The error "Upload preset must be specified when using unsigned upload" has been fixed by adding the upload preset to the code.

**Error was:**
```
Cloudinary upload error: Exception: Upload failed: 400 - 
{'error': {'message': 'Upload preset must be specified when using unsigned upload'}}
```

**Fix applied:**
- Added `uploadPreset = 'resident_app_upload'` to CloudinaryService
- Updated both upload methods to include the preset

---

## NEXT STEP: CREATE UPLOAD PRESET IN CLOUDINARY

You must create an unsigned upload preset in your Cloudinary account for this to work.

### Steps to Create Upload Preset

1. **Go to Cloudinary Dashboard**
   - URL: https://cloudinary.com/console/settings/upload

2. **Click "Add upload preset"**
   - Or find "Upload presets" section

3. **Configure the Preset**
   - **Name:** `resident_app_upload`
   - **Signing Mode:** Unsigned ✅
   - **Folder:** (leave empty or set to default)
   - **Resource type:** Image
   - **Format:** Auto

4. **Save the Preset**

---

## VERIFICATION

After creating the preset, test the upload:

1. Open Edit Profile
2. Tap camera icon
3. Select image
4. Tap "Save Changes"
5. Should upload successfully now

---

## WHAT THE CODE DOES NOW

```dart
// CloudinaryService now includes:
static const String uploadPreset = 'resident_app_upload';

// In upload methods:
request.fields['upload_preset'] = uploadPreset;
```

This tells Cloudinary to use the unsigned preset you created, allowing uploads without authentication.

---

## CLOUDINARY ACCOUNT INFO

- **Cloud Name:** `de8yccofb`
- **Upload Preset:** `resident_app_upload` (create this)
- **Upload URL:** `https://api.cloudinary.com/v1_1/de8yccofb/image/upload`

---

## TROUBLESHOOTING

### Still getting "Upload preset must be specified" error?
- Verify preset name is exactly: `resident_app_upload`
- Verify preset is set to "Unsigned"
- Verify preset is saved in Cloudinary

### Upload still fails?
- Check internet connection
- Verify image file is valid
- Check file size (should be < 5MB)
- Check Cloudinary account is active

---

## AFTER SETUP

Once the preset is created:
1. Image uploads will work ✅
2. URL will be saved to Firestore ✅
3. Profile screen will display image ✅
4. Real-time updates will work ✅

---

## STATUS

**Code Fix:** ✅ COMPLETE
**Next Action:** Create upload preset in Cloudinary
**Estimated Time:** 2 minutes

Go to: https://cloudinary.com/console/settings/upload
