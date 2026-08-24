# Create Cloudinary Upload Preset - Step by Step

## Your Cloud Name: `dailyccofb` ✅

---

## Step 1: Go to Settings

1. In your Cloudinary console, click the **gear icon** (⚙️) in the top right
2. You should see a dropdown menu

---

## Step 2: Click Upload Tab

1. In the settings menu, look for the **Upload** tab
2. Click it
3. You'll see various upload settings

---

## Step 3: Find Upload Presets Section

1. Scroll down on the Upload settings page
2. Look for **"Upload presets"** section
3. You should see existing presets or an option to add one

---

## Step 4: Add New Upload Preset

1. Click **"Add upload preset"** button
2. A form will appear with fields to fill

---

## Step 5: Fill in the Form

Fill in these fields:

| Field | Value |
|-------|-------|
| **Preset name** | `apartment_images_preset` |
| **Signing Mode** | **Unsigned** (select this!) |
| **Folder** | (optional - leave blank) |
| Other fields | Leave as default |

**Important**: Make sure **Signing Mode** is set to **Unsigned**

---

## Step 6: Save the Preset

1. Click **Save** button
2. You'll see a success message
3. The preset will appear in your presets list

---

## Step 7: Verify the Preset

1. Look for your preset in the list
2. Verify:
   - Name: `apartment_images_preset`
   - Signing Mode: Unsigned
   - Status: Active

---

## Step 8: Update Service Configuration

Once the preset is created, the service is already configured with:

```dart
static const String CLOUDINARY_CLOUD_NAME = 'dailyccofb';
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';
```

✅ **No changes needed!** The service is ready to use.

---

## Step 9: Update Firestore Rules

Go to Firebase Console → Firestore → Rules and add:

```firestore
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
}
```

Click **Publish**

---

## Step 10: Install Dependencies

Run in terminal:
```bash
cd admin_app
flutter pub get
```

---

## Step 11: Test the Feature

1. Run the app
2. Go to **Apartment Images** screen
3. Click **Add Image**
4. Select an image
5. Set date and time
6. Click **Upload Image**

---

## Troubleshooting

### Issue: "Upload preset must be in whitelist"
**Solution**: Make sure Signing Mode is set to **Unsigned**

### Issue: "Invalid upload preset"
**Solution**: Verify preset name matches exactly: `apartment_images_preset`

### Issue: Upload fails with 401
**Solution**: Check that preset is active and unsigned

---

## Checklist

- [ ] Clicked gear icon (Settings)
- [ ] Clicked Upload tab
- [ ] Found Upload presets section
- [ ] Clicked "Add upload preset"
- [ ] Entered preset name: `apartment_images_preset`
- [ ] Set Signing Mode to: Unsigned
- [ ] Clicked Save
- [ ] Verified preset is active
- [ ] Updated Firestore rules
- [ ] Ran `flutter pub get`
- [ ] Tested image upload

---

## Done!

Once you complete these steps, the apartment images feature will be fully functional.

**Total time**: ~5 minutes
