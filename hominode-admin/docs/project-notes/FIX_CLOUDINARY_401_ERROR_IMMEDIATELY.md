# FIX CLOUDINARY 401 ERROR - IMMEDIATELY

**Error**: `Cloudinary error: Unknown API key` (Status 401)  
**Status**: 🔴 BLOCKING UPLOADS  
**Time to Fix**: 2-3 minutes  
**Difficulty**: Very Easy

---

## THE PROBLEM

Your app is getting a 401 error when trying to upload images to Cloudinary. This means the upload preset `lyvo_upload` doesn't exist or isn't set to UNSIGNED mode.

---

## THE SOLUTION (9 STEPS)

### 1️⃣ Open Cloudinary Console
Go to: https://cloudinary.com/console

### 2️⃣ Click Settings
Look for gear icon in top right, click it

### 3️⃣ Click Upload Tab
In settings menu, click "Upload"

### 4️⃣ Scroll Down
Find "Upload presets" section

### 5️⃣ Click "Add upload preset"
Blue button to create new preset

### 6️⃣ Fill in the Form

**Name**: `lyvo_upload`
- Exact spelling
- No spaces
- Case-sensitive

**Unsigned**: Toggle to ON
- CRITICAL - must be enabled
- Shows as toggle switch

**Folder**: `apartment_images`
- Optional
- For organization

### 7️⃣ Click Save
Blue Save button

### 8️⃣ Verify
Go back to Upload tab:
- ✅ Preset name is `lyvo_upload`
- ✅ Unsigned is ON
- ✅ Status is Active

### 9️⃣ Test in App
1. Open Apartment Images screen
2. Click "Add Image"
3. Select image
4. Enter title
5. Select date and time
6. Click "Upload Image"
7. ✅ Should work!

---

## THAT'S IT!

After these 9 steps, your apartment images feature will work perfectly.

**Total time**: 2-3 minutes

---

## QUICK REFERENCE

```
Cloudinary Console
    ↓
Settings (gear icon)
    ↓
Upload tab
    ↓
Add upload preset
    ↓
Name: lyvo_upload
Unsigned: ON
    ↓
Save
    ↓
Test in app
    ↓
✅ DONE!
```

---

## WHAT YOU NEED TO KNOW

### Why This Error Happens
- Upload preset doesn't exist in Cloudinary
- OR preset exists but Unsigned mode is OFF
- Cloudinary requires explicit Unsigned mode for mobile apps

### What Unsigned Mode Does
- Allows uploads without API secret
- Required for mobile/web apps
- Must be explicitly enabled

### What Happens After
- Images upload to Cloudinary
- Metadata saved to Firestore
- Images appear in real-time list
- Feature works perfectly

---

## IF YOU GET STUCK

### Still getting 401 error?
1. Go back to Cloudinary Settings → Upload
2. Click on `lyvo_upload` preset
3. Verify Unsigned is ON (not OFF)
4. Click Save again
5. Wait 30 seconds
6. Try uploading again

### Can't find Upload Presets?
1. Go to Settings (gear icon)
2. Click Upload tab
3. Scroll down to bottom
4. Look for "Upload presets" heading

### Unsigned toggle won't turn ON?
1. Click the toggle switch
2. Wait for it to update
3. Scroll down and click Save
4. Refresh the page

---

## CREDENTIALS

Your Cloudinary account:
- Cloud Name: `dailyccofb` ✅
- API Key: `866472317169594` ✅
- Upload Preset: `lyvo_upload` (CREATE THIS)

---

## NEXT STEPS

1. **NOW**: Go to Cloudinary and create preset (2-3 min)
2. **AFTER**: Test upload in app (2 min)
3. **THEN**: Deploy to production
4. **FINALLY**: Start using apartment images

---

**Total time to fix**: 2-3 minutes

**Then**: Everything works!

**Go do it now!** 🚀

</content>
