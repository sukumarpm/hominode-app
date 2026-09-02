# Your Cloudinary Credentials

## ✅ Cloud Name (Found)
```
CLOUDINARY_CLOUD_NAME = dailyccofb
```

---

## ⏳ Upload Preset (Need to Create)

### Steps to Create Upload Preset:

1. **Go to Settings**
   - Click the gear icon (⚙️) in top right of Cloudinary console
   - Click **Upload** tab

2. **Create Upload Preset**
   - Scroll down to "Upload presets" section
   - Click **Add upload preset**
   - Fill in:
     - **Preset name**: `apartment_images_preset`
     - **Signing Mode**: Select **Unsigned** (important!)
     - Leave other settings as default
   - Click **Save**

3. **Copy the Preset Name**
   - After saving, you'll see your preset listed
   - Copy the preset name exactly as shown

---

## Configuration Template

Once you have the upload preset name, update this file:

**File**: `admin_app/lib/services/cloudinary_apartment_images_service.dart`

**Lines 10-12**:
```dart
static const String CLOUDINARY_CLOUD_NAME = 'dailyccofb';
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';  // Replace with your preset name
```

---

## Quick Reference

| Value | Your Value |
|-------|-----------|
| Cloud Name | `dailyccofb` |
| Upload Preset | `apartment_images_preset` (create this) |
| Signing Mode | Unsigned |

---

## Next Steps

1. Create the upload preset in Cloudinary
2. Update the service configuration
3. Update Firestore rules
4. Run `flutter pub get`
5. Test the feature

---

## Firestore Rules

Add this to your Firestore rules:

```firestore
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
}
```

---

## Status

- ✅ Cloud Name: `dailyccofb`
- ⏳ Upload Preset: Pending (create in Cloudinary)
- ⏳ Service Configuration: Pending
- ⏳ Firestore Rules: Pending
- ⏳ Testing: Pending
