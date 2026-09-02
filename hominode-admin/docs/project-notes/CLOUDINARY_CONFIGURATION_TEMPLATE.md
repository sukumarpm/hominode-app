# Cloudinary Configuration Template

## Step-by-Step Configuration

### 1. Get Your Cloudinary Credentials

#### Get Cloud Name:
1. Go to https://cloudinary.com/console
2. Log in to your account
3. Look at the top of the dashboard
4. You'll see: **Cloud name: `dxyz1234`** (example)
5. Copy this value

#### Create Upload Preset:
1. In Cloudinary Console, go to **Settings** (gear icon)
2. Click **Upload** tab
3. Scroll to **Upload presets** section
4. Click **Add upload preset**
5. Fill in:
   - **Name**: `apartment_images_preset`
   - **Unsigned**: Toggle ON (important!)
   - **Folder**: `apartment_images` (optional)
6. Click **Save**
7. Copy the preset name

---

### 2. Update Service Configuration

**File**: `admin_app/lib/services/cloudinary_apartment_images_service.dart`

**Lines 10-12** - Replace with your values:

```dart
// BEFORE:
static const String CLOUDINARY_CLOUD_NAME = 'YOUR_CLOUD_NAME';
static const String CLOUDINARY_UPLOAD_PRESET = 'YOUR_UPLOAD_PRESET';

// AFTER (example):
static const String CLOUDINARY_CLOUD_NAME = 'dxyz1234';
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';
```

---

### 3. Update Firestore Security Rules

**Go to**: Firebase Console → Firestore Database → Rules

**Replace the entire rules with**:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Apartment Images Collection
    match /apartmentImages/{document=**} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
    }

    // Keep your existing rules for other collections below...
    // (Don't delete your existing rules, just add the apartmentImages rule above)
  }
}
```

**Click Publish** to save the rules.

---

### 4. Install Dependencies

Run in terminal:

```bash
cd admin_app
flutter pub get
```

---

## Configuration Checklist

- [ ] Created Cloudinary account
- [ ] Copied Cloud Name
- [ ] Created upload preset (unsigned)
- [ ] Updated CLOUDINARY_CLOUD_NAME in service
- [ ] Updated CLOUDINARY_UPLOAD_PRESET in service
- [ ] Updated Firestore security rules
- [ ] Ran `flutter pub get`

---

## Verification

### Verify Cloudinary Configuration:
1. Open `admin_app/lib/services/cloudinary_apartment_images_service.dart`
2. Check lines 10-12 have your actual values (not placeholders)
3. Verify CLOUDINARY_UPLOAD_PRESET is set to "Unsigned" in Cloudinary

### Verify Firestore Rules:
1. Go to Firebase Console → Firestore → Rules
2. Verify `apartmentImages` collection rule is present
3. Click Publish if not already published

### Verify Dependencies:
1. Open `admin_app/pubspec.yaml`
2. Verify `http: ^1.1.0` is in dependencies
3. Run `flutter pub get` if not already done

---

## Testing the Configuration

### Test Upload:
1. Run the app
2. Go to Apartment Images screen
3. Click "Add Image"
4. Select an image
5. Set date and time
6. Click "Upload Image"

### Check Console Logs:
Look for these logs indicating success:
```
🔵 CLOUDINARY APARTMENT IMAGES SERVICE: Starting image upload...
🔐 STEP 1: Validating admin authentication...
✅ STEP 1 PASSED: Admin authenticated
📋 STEP 2: Validating input data...
✅ STEP 2 PASSED: Input data validated
📤 STEP 3: Uploading image to Cloudinary...
✅ STEP 3 PASSED: Image uploaded - https://res.cloudinary.com/...
💾 STEP 4: Saving image metadata to Firestore...
✅ STEP 4 PASSED: Image metadata saved
✅ CLOUDINARY APARTMENT IMAGES SERVICE: Image upload COMPLETE
```

### Check Firestore:
1. Go to Firebase Console → Firestore
2. Look for `apartmentImages` collection
3. Verify new document with your image URL

### Check Image URL:
1. Click on the document in Firestore
2. Look at `imageUrl` field
3. Should start with: `https://res.cloudinary.com/`

---

## Troubleshooting

### Error: "Cloudinary upload failed: 401"
**Cause**: Invalid upload preset or not set to "Unsigned"
**Fix**: 
1. Go to Cloudinary Settings → Upload
2. Check upload preset name matches exactly
3. Verify preset is set to "Unsigned"
4. Update service configuration

### Error: "permission-denied" in Firestore
**Cause**: Security rules not updated
**Fix**:
1. Go to Firebase Console → Firestore → Rules
2. Add the apartmentImages rule
3. Click Publish

### Error: "Admin not authenticated"
**Cause**: User not logged in
**Fix**: Log in to the app first

### Error: "Building ID cannot be empty"
**Cause**: Admin profile doesn't have buildingId
**Fix**: Ensure admin profile is created with buildingId field

### Image URL is empty
**Cause**: Cloudinary response missing secure_url
**Fix**: Check console logs for Cloudinary response details

---

## Configuration Values Reference

| Value | Where to Find | Example |
|-------|---------------|---------|
| CLOUDINARY_CLOUD_NAME | Cloudinary Console (top) | `dxyz1234` |
| CLOUDINARY_UPLOAD_PRESET | Cloudinary Settings → Upload | `apartment_images_preset` |
| Upload Preset Type | Cloudinary Settings → Upload | Unsigned (toggle ON) |

---

## Quick Copy-Paste Template

### For Service File:
```dart
static const String CLOUDINARY_CLOUD_NAME = 'YOUR_CLOUD_NAME_HERE';
static const String CLOUDINARY_UPLOAD_PRESET = 'apartment_images_preset';
```

### For Firestore Rules:
```firestore
match /apartmentImages/{document=**} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow update: if request.auth != null && request.auth.uid == resource.data.adminId;
  allow delete: if request.auth != null && request.auth.uid == resource.data.adminId;
}
```

---

## Done!

Once you've completed all steps, the apartment images feature will be fully functional with Cloudinary API integration.
