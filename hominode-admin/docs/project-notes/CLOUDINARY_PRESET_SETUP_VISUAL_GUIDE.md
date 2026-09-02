# CLOUDINARY UPLOAD PRESET - VISUAL STEP-BY-STEP GUIDE

**Objective**: Create upload preset `lyvo_upload` with Unsigned mode enabled

**Time**: 2-3 minutes

---

## STEP 1: Open Cloudinary Console

**Action**: Go to https://cloudinary.com/console

**What You'll See**:
```
┌─────────────────────────────────────────┐
│  Cloudinary Console                     │
│  ┌─────────────────────────────────────┐│
│  │ Cloud Name: dailyccofb              ││
│  │ API Key: 866472317169594            ││
│  │ API Secret: ••••••••••••••••••••••  ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**Verify**: Your cloud name should be `dailyccofb`

---

## STEP 2: Click Settings (Gear Icon)

**Action**: Look for gear icon in top right corner, click it

**What You'll See**:
```
┌─────────────────────────────────────────┐
│  Settings Menu                          │
│  ├─ Account                             │
│  ├─ Upload                    ← CLICK   │
│  ├─ Security                            │
│  ├─ Notifications                       │
│  └─ ...                                 │
└─────────────────────────────────────────┘
```

**Action**: Click **Upload** tab

---

## STEP 3: Find Upload Presets Section

**Action**: Scroll down in the Upload settings page

**What You'll See**:
```
┌─────────────────────────────────────────┐
│  Upload Settings                        │
│                                         │
│  Upload presets                         │
│  ┌─────────────────────────────────────┐│
│  │ Add upload preset                   ││
│  │ [+ Add upload preset] button        ││
│  │                                     ││
│  │ Existing presets:                   ││
│  │ (if any)                            ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**Action**: Click **[+ Add upload preset]** button

---

## STEP 4: Fill in Preset Form

**Action**: A form will appear. Fill it in:

```
┌─────────────────────────────────────────┐
│  Create Upload Preset                   │
│                                         │
│  Name: [lyvo_upload____________]        │
│        ↑ IMPORTANT: Exact name!         │
│                                         │
│  Unsigned: [OFF] ← CLICK TO TURN ON     │
│            ↓                            │
│            [ON] ← Should look like this │
│                                         │
│  Folder: [apartment_images____]         │
│          (optional)                     │
│                                         │
│  [Save] [Cancel]                        │
└─────────────────────────────────────────┘
```

**Critical Steps**:

1. **Name Field**:
   - Type: `lyvo_upload`
   - No spaces
   - Exact spelling
   - Case-sensitive

2. **Unsigned Toggle**:
   - Find the toggle switch
   - Click it to turn ON
   - Should show as enabled/blue

3. **Folder Field** (Optional):
   - Type: `apartment_images`
   - This organizes uploads

---

## STEP 5: Save the Preset

**Action**: Click **[Save]** button

**What Happens**:
```
✅ Preset created successfully
   Name: lyvo_upload
   Unsigned: ON
   Status: Active
```

---

## STEP 6: Verify Preset Was Created

**Action**: Go back to Upload settings

**What You'll See**:
```
┌─────────────────────────────────────────┐
│  Upload Presets                         │
│                                         │
│  ✅ lyvo_upload                         │
│     Unsigned: ON                        │
│     Folder: apartment_images            │
│     Status: Active                      │
│                                         │
│  [Edit] [Delete]                        │
└─────────────────────────────────────────┘
```

**Verify**:
- ✅ Preset name is `lyvo_upload`
- ✅ Unsigned is ON
- ✅ Status is Active

---

## STEP 7: Test in Your App

**Action**: Go back to your Flutter app

**Steps**:
1. Navigate to **Apartment Images** screen
2. Click **Add Image** button
3. Select an image from gallery
4. Enter title: "Test Image"
5. Select date and time
6. Click **Upload Image**

**Expected Result**:
```
✅ Image uploads successfully
✅ No "Unknown API key" error
✅ Success notification appears
✅ Image appears in list
```

---

## TROUBLESHOOTING

### Problem: Can't find Upload Presets section

**Solution**:
1. Go to Settings (gear icon)
2. Click **Upload** tab
3. Scroll down to bottom
4. Look for "Upload presets" heading

### Problem: Unsigned toggle won't turn ON

**Solution**:
1. Click the toggle switch
2. Wait for it to update
3. Scroll down and click Save
4. Refresh the page

### Problem: Preset created but upload still fails

**Solution**:
1. Go back to Upload settings
2. Click on `lyvo_upload` preset
3. Verify Unsigned is ON
4. Click Save again
5. Wait 30 seconds
6. Try uploading again

### Problem: Can't find the Save button

**Solution**:
1. Scroll down in the form
2. Look for blue [Save] button
3. Click it
4. Wait for confirmation

---

## QUICK CHECKLIST

Before testing upload:

- [ ] Opened https://cloudinary.com/console
- [ ] Clicked Settings (gear icon)
- [ ] Clicked Upload tab
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

## EXPECTED RESULT

After completing these steps:

✅ Upload preset `lyvo_upload` exists  
✅ Unsigned mode is enabled  
✅ App can upload images to Cloudinary  
✅ Images appear in apartment images list  
✅ No more "Unknown API key" error  

---

## NEXT STEPS

1. ✅ Create upload preset (you are here)
2. Test upload in app
3. Verify images appear
4. Start using apartment images feature
5. Deploy to production

---

**Time to Complete**: 2-3 minutes  
**Difficulty**: Very Easy  
**Status**: Ready to start!

</content>
