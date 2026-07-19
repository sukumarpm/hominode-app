# Cloudinary Upload Preset - Visual Setup Guide

## THE ERROR & THE FIX

**Error Message:**
```
Image uploaded failed: Failed to upload image: Exception
Cloudinary upload error: Exception: Upload failed: 400 - 
('error' ('message' 'Upload preset must be specified when using unsigned upload'))
```

**What was wrong:**
- Code was trying to upload without specifying an upload preset
- Cloudinary requires a preset for unsigned uploads

**What we fixed:**
- ✅ Added `uploadPreset = 'resident_app_upload'` to code
- ✅ Updated upload methods to include preset

**What you need to do:**
- Create the upload preset in Cloudinary (2 minutes)

---

## STEP-BY-STEP SETUP

### Step 1: Open Cloudinary Console
```
Go to: https://cloudinary.com/console/settings/upload
```

### Step 2: Find Upload Presets Section
Look for "Upload presets" or "Add upload preset" button

### Step 3: Create New Preset
Click "Add upload preset"

### Step 4: Configure Preset

| Field | Value |
|-------|-------|
| **Preset Name** | `resident_app_upload` |
| **Signing Mode** | Unsigned ✅ |
| **Folder** | (leave empty) |
| **Resource Type** | Image |
| **Format** | Auto |

### Step 5: Save
Click "Save" button

---

## VERIFICATION CHECKLIST

After creating preset:

- [ ] Preset name is: `resident_app_upload`
- [ ] Signing mode is: Unsigned
- [ ] Preset is saved in Cloudinary
- [ ] You can see it in the presets list

---

## TEST THE UPLOAD

1. Open app
2. Go to Profile
3. Tap "Edit Profile"
4. Tap camera icon on avatar
5. Select image from gallery
6. Tap "Save Changes"
7. Should see success message ✅

---

## EXPECTED CONSOLE OUTPUT

### Before (Error):
```
❌ Cloudinary upload error: Exception: Upload failed: 400
```

### After (Success):
```
🔵 EditProfile: Starting to save profile...
📸 Image selected, uploading to Cloudinary...
📤 Uploading to Cloudinary...
✅ Image uploaded to Cloudinary
🔗 URL: https://res.cloudinary.com/de8yccofb/image/upload/...
💾 Saving URL to Firestore...
✅ URL saved to Firestore
✅ EditProfile: Profile updated successfully
```

---

## WHAT HAPPENS AFTER SETUP

```
User uploads image
    ↓
App sends to Cloudinary with preset
    ↓
Cloudinary accepts upload (preset validates it)
    ↓
Returns secure_url
    ↓
URL saved to Firestore
    ↓
Profile screen displays image
    ↓
Real-time updates work
```

---

## CLOUDINARY ACCOUNT DETAILS

**Your Account:**
- Cloud Name: `de8yccofb`
- API Key: `866472317169594`
- Upload Preset: `resident_app_upload` (create this)

**Upload Endpoint:**
```
https://api.cloudinary.com/v1_1/de8yccofb/image/upload
```

---

## QUICK REFERENCE

| Item | Value |
|------|-------|
| Cloudinary URL | https://cloudinary.com/console/settings/upload |
| Preset Name | `resident_app_upload` |
| Signing Mode | Unsigned |
| Time to Setup | ~2 minutes |
| Status | REQUIRED ⚠️ |

---

## TROUBLESHOOTING

### Q: Where do I find upload presets?
**A:** https://cloudinary.com/console/settings/upload

### Q: What if I can't find "Add upload preset"?
**A:** Look for "Upload presets" section or scroll down on settings page

### Q: Should signing mode be "Signed" or "Unsigned"?
**A:** Must be "Unsigned" for mobile app uploads

### Q: What if upload still fails after creating preset?
**A:** 
1. Verify preset name is exactly: `resident_app_upload`
2. Verify it's set to "Unsigned"
3. Verify it's saved
4. Try uploading again

---

## DONE! ✅

Once preset is created:
1. Image uploads will work
2. Profile screen will display images
3. Real-time updates will work
4. Everything is ready for production

**Time to complete:** ~2 minutes
**Difficulty:** Very Easy
**Status:** REQUIRED
