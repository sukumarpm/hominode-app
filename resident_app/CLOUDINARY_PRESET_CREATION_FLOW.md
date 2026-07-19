# Cloudinary Upload Preset Creation - Step by Step

## YOU ARE HERE ✅

You're in the Cloudinary console. Now follow these steps to create the upload preset.

---

## STEP 1: Navigate to Upload Settings

1. In the left sidebar, find **"Upload"** section
2. Click on **"Upload"** (not "Upload" under Product environment settings)
3. Look for **"Upload presets"** or similar option

**Alternative Direct Link:**
```
https://cloudinary.com/console/settings/upload
```

---

## STEP 2: Create New Upload Preset

1. Click **"Add upload preset"** button
2. Or look for **"Create preset"** button

---

## STEP 3: Configure the Preset

Fill in these exact values:

| Field | Value |
|-------|-------|
| **Preset Name** | `resident_app_upload` |
| **Signing Mode** | Unsigned ✅ |
| **Folder** | (leave empty) |
| **Resource Type** | Image |
| **Format** | Auto |
| **Quality** | Auto |

---

## STEP 4: Save the Preset

1. Click **"Save"** button
2. You should see success message
3. Preset appears in the list

---

## VERIFICATION

After creating, you should see:

```
Preset Name: resident_app_upload
Signing Mode: Unsigned
Status: Active
```

---

## WHAT HAPPENS NEXT

Once preset is created:

1. ✅ Code will recognize the preset
2. ✅ Image uploads will work
3. ✅ Profile screen will display images
4. ✅ Real-time updates will work

---

## QUICK REFERENCE

**Preset Details:**
- Name: `resident_app_upload`
- Signing Mode: **Unsigned** (IMPORTANT!)
- Resource Type: Image

**Your Cloud Name:** `de8yccofb`

---

## DONE! ✅

After creating the preset:
1. Go back to app
2. Open Edit Profile
3. Upload image
4. Should work now!

---

## TROUBLESHOOTING

### Can't find "Upload presets"?
- Go to: https://cloudinary.com/console/settings/upload
- Look for "Upload presets" section

### Preset created but upload still fails?
- Verify preset name is exactly: `resident_app_upload`
- Verify Signing Mode is: **Unsigned**
- Try uploading again

### Still getting error?
- Check internet connection
- Verify image file is valid
- Check Cloudinary account is active
