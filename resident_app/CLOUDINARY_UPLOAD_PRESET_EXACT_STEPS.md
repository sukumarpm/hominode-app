# Create Cloudinary Upload Preset - Exact Steps

## CURRENT STATUS

You're logged into Cloudinary console. Now create the upload preset.

---

## NAVIGATION PATH

```
Cloudinary Console
  ↓
Settings (gear icon or left sidebar)
  ↓
Upload
  ↓
Upload presets
  ↓
Add upload preset
```

---

## EXACT STEPS

### Step 1: Go to Upload Settings
- **URL:** https://cloudinary.com/console/settings/upload
- Or click **Settings** → **Upload** in sidebar

### Step 2: Find Upload Presets Section
- Scroll down to find **"Upload presets"**
- Or look for **"Add upload preset"** button

### Step 3: Click "Add upload preset"
- Button should be blue or prominent
- Creates new preset form

### Step 4: Fill in Preset Details

**Preset Name:**
```
resident_app_upload
```

**Signing Mode:**
```
Select: Unsigned ✅
```

**Folder (optional):**
```
Leave empty
```

**Resource Type:**
```
Image
```

**Format:**
```
Auto
```

### Step 5: Save
- Click **"Save"** button
- Wait for confirmation

### Step 6: Verify
- You should see preset in list
- Name: `resident_app_upload`
- Status: Active

---

## WHAT YOU'LL SEE

### Before Creating:
```
No upload presets yet
[Add upload preset] button
```

### After Creating:
```
Upload Presets
├─ resident_app_upload
│  ├─ Signing Mode: Unsigned
│  ├─ Status: Active
│  └─ Created: [date]
```

---

## IMPORTANT NOTES

⚠️ **MUST BE UNSIGNED**
- Signing Mode must be: **Unsigned**
- NOT "Signed"
- NOT "Authenticated"

✅ **EXACT NAME**
- Name must be: `resident_app_upload`
- Case sensitive
- No spaces
- No special characters

---

## AFTER CREATING PRESET

1. Close Cloudinary console
2. Go back to app
3. Open Edit Profile
4. Try uploading image
5. Should work now! ✅

---

## EXPECTED RESULT

**Console Output:**
```
✅ Image uploaded to Cloudinary
🔗 URL: https://res.cloudinary.com/de8yccofb/image/upload/...
✅ URL saved to Firestore
```

**Profile Screen:**
- Avatar shows image
- Image displays correctly
- No error messages

---

## TROUBLESHOOTING

### Q: Where is "Upload presets"?
**A:** Go to https://cloudinary.com/console/settings/upload

### Q: What if I don't see "Add upload preset"?
**A:** 
1. Scroll down on the page
2. Look for "Upload presets" section
3. Click the button to add new preset

### Q: Should it be "Signed" or "Unsigned"?
**A:** Must be **Unsigned** for mobile app

### Q: Upload still fails after creating preset?
**A:**
1. Verify preset name: `resident_app_upload`
2. Verify Signing Mode: Unsigned
3. Verify preset is saved
4. Try uploading again

---

## QUICK CHECKLIST

- [ ] Go to https://cloudinary.com/console/settings/upload
- [ ] Find "Upload presets" section
- [ ] Click "Add upload preset"
- [ ] Name: `resident_app_upload`
- [ ] Signing Mode: Unsigned
- [ ] Click Save
- [ ] Verify preset appears in list
- [ ] Go back to app
- [ ] Test upload

---

## DONE! ✅

Once preset is created, image uploads will work!

**Time to complete:** ~2 minutes
**Difficulty:** Very Easy
**Status:** REQUIRED
