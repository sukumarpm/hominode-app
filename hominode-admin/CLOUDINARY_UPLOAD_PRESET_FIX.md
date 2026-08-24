# CLOUDINARY UPLOAD PRESET FIX - IMMEDIATE ACTION

**Error**: "Cloudinary error: Unknown API key"

**Root Cause**: Upload preset `lyvo_upload` doesn't exist or isn't configured correctly in Cloudinary

---

## IMMEDIATE FIX - 3 STEPS

### STEP 1: Go to Cloudinary Dashboard

1. Open https://cloudinary.com/console
2. Login with your account
3. Go to **Settings** (gear icon)
4. Click **Upload** tab

### STEP 2: Create Upload Preset

1. Scroll to **Upload presets** section
2. Click **Add upload preset**
3. Fill in:
   - **Name**: `lyvo_upload`
   - **Unsigned**: Toggle ON (very important!)
   - **Folder**: `apartment_images` (optional)
4. Click **Save**

### STEP 3: Verify Configuration

1. Go back to **Upload** tab
2. Find `lyvo_upload` in the list
3. Verify **Unsigned** is enabled
4. Copy the preset name exactly: `lyvo_upload`

---

## VERIFY YOUR CLOUDINARY CREDENTIALS

Your current config:
```dart
cloudName = 'dailyccofb'
apiKey = '866472317169594'
uploadPreset = 'lyvo_upload'
```

**Check**:
- ✅ Cloud name: `dailyccofb` (correct)
- ✅ API key: `866472317169594` (correct)
- ⚠️ Upload preset: `lyvo_upload` (MUST exist and be UNSIGNED)

---

## AFTER CREATING PRESET

Once you create the preset in Cloudinary:

1. Go back to your app
2. Click "Add Image" again
3. Select image
4. Click "Upload Image"
5. Should work now!

---

## IF STILL NOT WORKING

Try this alternative approach:

### Option A: Use Different Preset Name

If `lyvo_upload` doesn't work, create a new preset:

1. In Cloudinary, create preset named: `apartment_images_unsigned`
2. Make sure **Unsigned** is ON
3. Update your code:

```dart
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_unsigned';
```

### Option B: Check Cloudinary Account

1. Verify you're in the right Cloudinary account
2. Check cloud name matches: `dailyccofb`
3. Verify API key: `866472317169594`
4. Create new preset if needed

---

## COMPLETE CLOUDINARY SETUP GUIDE

### 1. Login to Cloudinary
- URL: https://cloudinary.com/console
- Use your email and password

### 2. Navigate to Upload Settings
- Click **Settings** (gear icon)
- Click **Upload** tab

### 3. Create Upload Preset
- Click **Add upload preset**
- **Name**: `lyvo_upload`
- **Unsigned**: Toggle ON (CRITICAL!)
- **Folder**: `apartment_images` (optional)
- Click **Save**

### 4. Verify in Your App
- Cloud name: `dailyccofb`
- Upload preset: `lyvo_upload`
- Unsigned mode: ON

### 5. Test Upload
- Open app
- Go to Apartment Images
- Click "Add Image"
- Select image
- Click "Upload"
- Should succeed!

---

## TROUBLESHOOTING

### Error: "Unknown API key"
**Cause**: Upload preset doesn't exist or isn't unsigned
**Fix**: Create preset with Unsigned mode ON

### Error: "Invalid upload preset"
**Cause**: Preset name is wrong
**Fix**: Check exact preset name in Cloudinary

### Error: "Unauthorized"
**Cause**: Cloud name or API key is wrong
**Fix**: Verify credentials match Cloudinary account

### Error: "File too large"
**Cause**: Image > 10MB
**Fix**: Compress image before upload

---

## QUICK CHECKLIST

- [ ] Go to Cloudinary console
- [ ] Go to Settings → Upload
- [ ] Create upload preset named `lyvo_upload`
- [ ] Toggle **Unsigned** ON
- [ ] Click Save
- [ ] Go back to app
- [ ] Try uploading image again
- [ ] Should work!

---

## EXPECTED RESULT

After creating the preset:

✅ Image uploads to Cloudinary  
✅ URL stored in Firestore  
✅ Image appears in list  
✅ No more "Unknown API key" error  

---

**Time to Fix**: 2-3 minutes

**Difficulty**: Very Easy

**Status**: Follow these steps and it will work!
