# CLOUDINARY 401 ERROR - FIX NOW

**Error**: `Cloudinary error: Unknown API key` (Status 401)

**Status**: 🔴 CRITICAL - Blocking uploads

**Time to Fix**: 2-3 minutes

---

## WHAT'S HAPPENING

Your app is trying to upload images to Cloudinary, but the upload preset `lyvo_upload` doesn't exist in your Cloudinary account OR it's not set to UNSIGNED mode.

**Error Details**:
```
Status: 401 (Unauthorized)
Message: Unknown API key
Cause: Upload preset not found or not unsigned
```

---

## THE FIX (2-3 MINUTES)

### STEP 1: Go to Cloudinary Console
Open: https://cloudinary.com/console

**Verify**: You see your cloud name `dailyccofb`

### STEP 2: Click Settings
Look for gear icon in top right corner, click it

### STEP 3: Click Upload Tab
In settings menu, click "Upload"

### STEP 4: Scroll Down
Find "Upload presets" section

### STEP 5: Click "Add upload preset"
Blue button to create new preset

### STEP 6: Fill in the Form

**CRITICAL - Exact values**:

```
Name: lyvo_upload
(No spaces, no typos, case-sensitive)

Unsigned: Toggle to ON
(This is CRITICAL - must be enabled)

Folder: apartment_images
(Optional - for organization)
```

### STEP 7: Click Save
Blue Save button at bottom

### STEP 8: Verify
Go back to Upload tab and verify:
- ✅ Preset name is `lyvo_upload`
- ✅ Unsigned is ON (enabled)
- ✅ Status is Active

### STEP 9: Test in App
1. Go back to your Flutter app
2. Open Apartment Images screen
3. Click "Add Image"
4. Select image
5. Enter title
6. Select date and time
7. Click "Upload Image"
8. ✅ Should work now!

---

## VISUAL GUIDE

```
Step 1: https://cloudinary.com/console
        ↓
Step 2: Click Settings (gear icon)
        ↓
Step 3: Click Upload tab
        ↓
Step 4: Scroll to "Upload presets"
        ↓
Step 5: Click "Add upload preset"
        ↓
Step 6: Fill form:
        Name: lyvo_upload
        Unsigned: ON
        ↓
Step 7: Click Save
        ↓
Step 8: Verify preset created
        ↓
Step 9: Test in app
        ↓
✅ DONE!
```

---

## QUICK CHECKLIST

Before testing:

- [ ] Opened https://cloudinary.com/console
- [ ] Clicked Settings (gear icon)
- [ ] Clicked Upload tab
- [ ] Scrolled to "Upload presets"
- [ ] Clicked "Add upload preset"
- [ ] Entered name: `lyvo_upload`
- [ ] Toggled Unsigned to ON
- [ ] Clicked Save
- [ ] Verified preset appears in list
- [ ] Verified Unsigned is ON
- [ ] Went back to app
- [ ] Clicked Add Image
- [ ] Selected image
- [ ] Clicked Upload

---

## WHAT EACH FIELD MEANS

### Name: `lyvo_upload`
- This is the preset identifier
- Must be exactly `lyvo_upload`
- No spaces, no typos
- Case-sensitive

### Unsigned: ON
- Allows uploads without API secret
- CRITICAL for mobile apps
- Must be explicitly enabled
- Shows as toggle switch

### Folder: `apartment_images`
- Organizes uploads in Cloudinary
- Optional but recommended
- Helps keep files organized

---

## EXPECTED RESULT

After completing these steps:

✅ Upload preset `lyvo_upload` exists  
✅ Unsigned mode is enabled  
✅ App can upload images to Cloudinary  
✅ Images appear in apartment images list  
✅ No more 401 error  

---

## IF STILL NOT WORKING

### Problem: Preset created but still getting 401 error

**Solution**:
1. Go back to Cloudinary Settings → Upload
2. Click on `lyvo_upload` preset
3. Verify Unsigned toggle is ON (not OFF)
4. Click Save again
5. Wait 30 seconds
6. Try uploading again

### Problem: Can't find Upload Presets section

**Solution**:
1. Go to Settings (gear icon)
2. Click Upload tab
3. Scroll down to bottom
4. Look for "Upload presets" heading

### Problem: Unsigned toggle won't turn ON

**Solution**:
1. Click the toggle switch
2. Wait for it to update
3. Scroll down and click Save
4. Refresh the page
5. Try again

### Problem: Preset name shows different

**Solution**:
1. Delete the old preset
2. Create new one with exact name: `lyvo_upload`
3. Make sure Unsigned is ON
4. Save and test

---

## CREDENTIALS TO VERIFY

Your Cloudinary account:
- Cloud Name: `dailyccofb` ✅
- API Key: `866472317169594` ✅
- Upload Preset: `lyvo_upload` (TO CREATE)

These are already in your code. You just need to create the preset.

---

## WHAT HAPPENS AFTER

Once you create the preset:

1. **Upload Images**
   - Click "Add Image"
   - Select image
   - Enter details
   - Click Upload
   - ✅ Image uploads to Cloudinary
   - ✅ Metadata saved to Firestore
   - ✅ Image appears in list

2. **View Images**
   - All images display in grid
   - Real-time updates
   - Shows title, type, date, time
   - Sorted by newest first

3. **Delete Images**
   - Click delete button
   - Confirm deletion
   - Image removed from list
   - Real-time update

4. **Share with Residents**
   - Residents can see building images
   - Images appear in resident app
   - Real-time updates

---

## IMPORTANT NOTES

⚠️ **UNSIGNED MODE IS CRITICAL**
- Without Unsigned mode ON, uploads will fail with 401
- This is a security feature in Cloudinary
- Must be explicitly enabled for unsigned uploads

⚠️ **EXACT PRESET NAME**
- Preset name must be exactly `lyvo_upload`
- No spaces, no typos
- Case-sensitive

⚠️ **REAL DATA ONLY**
- No demo data in production
- All images stored with adminId
- Multi-tenancy enforced

---

## TIMELINE

**Time to Fix**: 2-3 minutes  
**Difficulty**: Very Easy  
**Steps**: 9 simple steps  

---

## NEXT STEPS

1. **NOW**: Go to Cloudinary and create upload preset
2. **AFTER**: Test upload in app
3. **THEN**: Deploy to production
4. **FINALLY**: Start using apartment images feature

---

## SUPPORT

If you get stuck:
1. Check the troubleshooting section above
2. Verify all 9 steps completed
3. Check Cloudinary dashboard for preset
4. Verify Unsigned mode is ON
5. Try creating a new preset

---

**Status**: 🟡 WAITING FOR USER ACTION

Once you create the upload preset in Cloudinary, the apartment images feature will work perfectly!

**Time to complete**: 2-3 minutes

**Then**: Everything works!

</content>
