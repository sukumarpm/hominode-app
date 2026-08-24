# Poster Management - Action Items Checklist

## 🔴 CRITICAL - Do These First

### 1. Create Cloudinary Upload Preset (5 minutes)
**Status**: ⏳ PENDING

Steps:
1. Open https://console.cloudinary.com
2. Click **Settings** (gear icon)
3. Go to **Upload** tab
4. Scroll to **Upload presets** section
5. Click **Add upload preset**
6. Fill in:
   - **Name**: `poster_upload`
   - **Unsigned**: Toggle ON (blue)
   - **Folder**: `posters`
   - **Resource type**: Image
7. Click **Save**

**Verification**: You should see `poster_upload` in the presets list

---

### 2. Add HTTP Package (1 minute)
**Status**: ⏳ PENDING

Run in terminal:
```bash
cd admin_app
flutter pub add http
```

**Verification**: Check `pubspec.yaml` has `http: ^1.1.0`

---

### 3. Verify Firestore Rules (2 minutes)
**Status**: ⏳ PENDING

1. Go to Firebase Console
2. Firestore Database → Rules
3. Check for this rule:
```
match /posters/{posterId} {
  allow read: if request.auth.uid != null;
  allow write: if request.auth.uid != null && (resource.data.adminId == request.auth.uid || request.resource.data.adminId == request.auth.uid);
  allow create: if request.auth.uid != null;
}
```

**If missing**: Copy from `FIRESTORE_RULES_WORKING_COPY_PASTE.txt` and publish

---

## 🟡 TESTING - Do These Next

### 4. Test Poster Upload
**Status**: ⏳ PENDING

1. Run app: `flutter run`
2. Login as admin
3. Go to Poster Management screen
4. Select image from gallery
5. Enter title: "Test Poster"
6. Select building
7. Click "Upload Poster"

**Expected Console Output**:
```
✅ STEP 1: Admin authenticated - [adminId]
✅ STEP 2: Input data validated
📤 STEP 3: Uploading to Cloudinary...
✅ STEP 3 PASSED: Image uploaded - https://res.cloudinary.com/...
💾 STEP 4: Saving to Firestore...
✅ STEP 4 PASSED: Poster saved - [docId]
```

**Success**: Poster appears in list immediately

---

### 5. Test Real-time Updates
**Status**: ⏳ PENDING

1. Upload a poster (from Step 4)
2. Check it appears in admin list
3. Open resident app
4. Go to home screen
5. Check poster appears in carousel/list

**Success**: Poster visible in both apps

---

### 6. Test Delete
**Status**: ⏳ PENDING

1. In admin app, click delete on a poster
2. Confirm deletion
3. Check poster removed from admin list
4. Check resident app updates automatically

**Success**: Poster removed from both apps

---

## 🟢 VERIFICATION - Final Checks

### 7. Verify All Flow Function Steps
**Status**: ⏳ PENDING

Check each step in console:
- [ ] Step 1: Admin authentication ✅
- [ ] Step 2: Input validation ✅
- [ ] Step 3: Cloudinary upload ✅
- [ ] Step 4: Firestore save ✅
- [ ] Step 5: Real-time fetch ✅
- [ ] Step 6: Delete operation ✅

---

## 📋 Quick Reference

### Cloudinary Credentials (Already Set)
- Cloud Name: `dailyccofb`
- API Key: `866472317169594`
- Upload Preset: `poster_upload` (you create this)

### Firestore Collection
- Collection: `posters`
- Fields: `imageUrl`, `buildingId`, `adminId`, `title`, `createdAt`, `updatedAt`

### Files Modified
- `admin_app/lib/services/poster_service.dart` - Real Cloudinary upload
- `admin_app/lib/config/cloudinary_config.dart` - Configuration
- `admin_app/lib/poster_management_screen.dart` - Admin UI

---

## 🆘 Troubleshooting

### Upload fails with 401
→ Check upload preset is "Unsigned"

### Upload fails with 400
→ Check upload preset name is `poster_upload`

### Permission denied error
→ Check Firestore rules are published

### Poster not appearing
→ Check console for Cloudinary upload success
→ Check Firestore has document with correct buildingId

### Real-time not updating
→ Check Firestore rule allows read
→ Check StreamBuilder is connected

---

## ✅ Completion Checklist

When all items are done:
- [ ] Upload preset created
- [ ] HTTP package added
- [ ] Firestore rules verified
- [ ] Upload test passed
- [ ] Real-time test passed
- [ ] Delete test passed
- [ ] All flow function steps verified
- [ ] No console errors

**Status**: Ready for production ✅
