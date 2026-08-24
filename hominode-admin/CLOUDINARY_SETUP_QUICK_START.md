# Cloudinary Setup - Quick Start Guide

## 🚀 3-Step Setup

### Step 1: Get Cloudinary Credentials (2 minutes)
1. Go to https://cloudinary.com/console
2. Sign up or log in
3. Copy your **Cloud Name** from the dashboard
4. Go to Settings → Upload → Add upload preset
5. Create preset named `apartment_images_preset` (set to "Unsigned")
6. Copy the preset name

### Step 2: Update Service Configuration (1 minute)
Edit `admin_app/lib/services/cloudinary_apartment_images_service.dart` lines 10-12:

```dart
static const String CLOUDINARY_CLOUD_NAME = 'YOUR_CLOUD_NAME';  // Replace with your cloud name
static const String CLOUDINARY_UPLOAD_PRESET = 'YOUR_UPLOAD_PRESET';  // Replace with preset name
```

**Example**:
```dart
static const String CLOUDINARY_CLOUD_NAME = 'dxyz1234';
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';
```

### Step 3: Update Firestore Rules (1 minute)
Go to Firebase Console → Firestore → Rules and add:

```firestore
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
}
```

---

## ✅ Done!

Run `flutter pub get` and test the upload feature.

---

## What Changed

- ✅ Screen now uses Cloudinary service
- ✅ Modal passes buildingId to upload function
- ✅ Images upload to Cloudinary (not Firebase Storage)
- ✅ Metadata stored in Firestore
- ✅ All flow functions with detailed logging
- ✅ Error handling with user feedback

---

## Testing

1. Open Apartment Images screen
2. Click "Add Image"
3. Select image, date, time
4. Click "Upload Image"
5. Check Firestore for new document
6. Verify image URL is from Cloudinary (starts with `https://res.cloudinary.com/`)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Upload fails with 401 | Check CLOUDINARY_UPLOAD_PRESET is correct |
| Firestore permission denied | Update Firestore rules |
| Building ID is null | Ensure admin profile has buildingId field |
| Image URL is empty | Check Cloudinary response in console logs |

---

## Console Logs

All operations log with emoji indicators:
- 🔵 Operation start
- 🔐 Authentication check
- 📋 Data validation
- 📤 Upload progress
- 💾 Database save
- ✅ Success
- ❌ Error

Check console to debug any issues.
