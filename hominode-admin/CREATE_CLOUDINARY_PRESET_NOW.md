# CREATE CLOUDINARY PRESET NOW - Step by Step

## The Problem
```
❌ Cloudinary error: Unknown API key
```

This means the upload preset `lyvo_upload` does NOT exist in your Cloudinary account.

## Solution: Create It Now (5 Minutes)

### Step 1: Go to Cloudinary Dashboard
1. Open browser
2. Go to: https://cloudinary.com/console
3. Log in with your account

### Step 2: Navigate to Upload Presets
1. Look for **Settings** (gear icon) in top right
2. Click it
3. In left sidebar, find **Upload** tab
4. Click **Upload** tab
5. Scroll down to **Upload presets** section

### Step 3: Create New Preset
1. Click **Add upload preset** button
2. A form will appear

### Step 4: Fill the Form
```
Name: lyvo_upload
Mode: UNSIGNED ← VERY IMPORTANT!
```

**Important**: 
- Name MUST be exactly: `lyvo_upload`
- Mode MUST be: UNSIGNED (not SIGNED)
- Leave other fields as default

### Step 5: Save
1. Click **Save** button
2. You should see success message
3. Preset appears in list

### Step 6: Verify
Check that you see:
```
✅ Name: lyvo_upload
✅ Mode: UNSIGNED
✅ Status: Active
```

## After Creating Preset

1. Close Cloudinary dashboard
2. Go back to Flutter app
3. Try uploading image again
4. Should work now!

## If You Can't Find Settings

Alternative path:
1. Go to https://cloudinary.com/console/settings/upload
2. This goes directly to Upload settings
3. Scroll to "Upload presets"
4. Click "Add upload preset"

## Visual Checklist

```
Cloudinary Console
    ↓
Settings (gear icon)
    ↓
Upload tab
    ↓
Upload presets section
    ↓
[Add upload preset] button
    ↓
Form appears:
  Name: lyvo_upload
  Mode: UNSIGNED
    ↓
[Save] button
    ↓
✅ Preset created!
```

## Troubleshooting

### Can't find Settings?
- Look for gear icon in top right corner
- Or go directly to: https://cloudinary.com/console/settings/upload

### Can't find Upload tab?
- In Settings, look at left sidebar
- Should see: Upload, Security, Account, etc.
- Click Upload

### Can't find Upload presets?
- In Upload tab, scroll down
- Should see "Upload presets" section
- If not, you're in wrong tab

### Mode dropdown shows different options?
- Select: UNSIGNED (not SIGNED)
- UNSIGNED is what we need

## After Preset is Created

The app will work because:
1. Preset name matches: `lyvo_upload`
2. Mode is UNSIGNED: No API key needed
3. Cloudinary recognizes the preset
4. Upload succeeds

## Test Upload

After creating preset:
1. Open Flutter app
2. Go to Apartment Images
3. Click "Add Image"
4. Select image
5. Click "Upload Image"
6. Should see: "Response status: 200" ✅

## Still Getting Error?

If still getting "Unknown API key":
1. Check preset name is EXACTLY: `lyvo_upload`
2. Check Mode is UNSIGNED (not SIGNED)
3. Check Status is Active
4. Try creating new preset with different name
5. Restart app after creating preset

---

**CRITICAL**: You MUST create this preset in Cloudinary dashboard for uploads to work.

**Time needed**: 5 minutes
**Difficulty**: Very Easy
**Status**: Required before testing
