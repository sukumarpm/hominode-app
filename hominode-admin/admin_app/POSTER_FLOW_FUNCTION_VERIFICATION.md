# Poster Management - Flow Function Verification

## Flow Function Pattern Compliance Check

### STEP 1: Admin Authentication ✅
**Status**: IMPLEMENTED
```dart
final adminId = _adminService.getCurrentAdminId();
if (adminId == null) throw Exception('Admin not authenticated');
```
**Verification**:
- ✅ Checks if admin is logged in
- ✅ Throws exception if not authenticated
- ✅ Uses adminId for all operations

---

### STEP 2: Input Validation ✅
**Status**: IMPLEMENTED
```dart
if (imageFile == null) throw Exception('Image file required');
if (buildingId.isEmpty) throw Exception('Building ID required');
```
**Verification**:
- ✅ Validates image file exists
- ✅ Validates building ID is provided
- ✅ Validates title is not empty

---

### STEP 3: Cloudinary Upload ⚠️
**Status**: NEEDS VERIFICATION
```dart
final imageUrl = await _uploadToCloudinary(imageFile);
```
**Checklist**:
- [ ] Upload preset created in Cloudinary (name: `poster_upload`)
- [ ] Upload preset set to "Unsigned"
- [ ] HTTP package added to pubspec.yaml
- [ ] Cloudinary credentials correct:
  - Cloud Name: `dailyccofb`
  - API Key: `866472317169594`
  - Upload Preset: `poster_upload`

**What to Check**:
1. Go to Cloudinary Console → Settings → Upload
2. Verify upload preset `poster_upload` exists
3. Verify it's set to "Unsigned"
4. Test upload by running app and checking console logs

---

### STEP 4: Firestore Save ⚠️
**Status**: NEEDS VERIFICATION
```dart
final docRef = await _firestore.collection('posters').add({
  'imageUrl': imageUrl,
  'buildingId': buildingId,
  'adminId': adminId,
  'title': title,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```
**Checklist**:
- [ ] Firestore rules allow write to `posters` collection
- [ ] Document has `adminId` field
- [ ] Document has `buildingId` field
- [ ] Timestamps are server-generated

**Firestore Rule Check**:
```
match /posters/{posterId} {
  allow read: if request.auth.uid != null;
  allow write: if request.auth.uid != null && 
    (resource.data.adminId == request.auth.uid || 
     request.resource.data.adminId == request.auth.uid);
  allow create: if request.auth.uid != null;
}
```

---

### STEP 5: Real-time Fetch ⚠️
**Status**: NEEDS VERIFICATION
```dart
Stream<List<PosterModel>> getPostersForBuilding(String buildingId) {
  return _firestore
    .collection('posters')
    .where('buildingId', isEqualTo: buildingId)
    .snapshots()
    .map((snapshot) => snapshot.docs.map(...).toList());
}
```
**Checklist**:
- [ ] StreamBuilder used in UI
- [ ] Real-time updates working
- [ ] Filtering by buildingId correct
- [ ] Error handling in place

---

### STEP 6: Delete Operation ⚠️
**Status**: NEEDS VERIFICATION
```dart
Future<void> deletePoster(String posterId) async {
  final adminId = _adminService.getCurrentAdminId();
  if (adminId == null) throw Exception('Admin not authenticated');
  
  await _firestore.collection('posters').doc(posterId).delete();
}
```
**Checklist**:
- [ ] Admin authentication checked
- [ ] Document deleted from Firestore
- [ ] UI updates in real-time
- [ ] Cloudinary image cleanup (optional)

---

## Testing Checklist

### 1. Cloudinary Setup (5 min)
```
[ ] Create upload preset in Cloudinary
[ ] Name: poster_upload
[ ] Set to Unsigned
[ ] Folder: posters
[ ] Save
```

### 2. Firebase Setup (5 min)
```
[ ] Verify Firestore rules are published
[ ] Check posters collection rule
[ ] Verify adminId check in rule
```

### 3. Code Setup (2 min)
```
[ ] Add http package: flutter pub add http
[ ] Verify cloudinary_config.dart has correct credentials
[ ] Check poster_service.dart imports http
```

### 4. Test Upload Flow
```
[ ] Open Poster Management screen
[ ] Select image from gallery
[ ] Enter title
[ ] Select building
[ ] Click Upload
[ ] Check console for:
    - "✅ STEP 1: Admin authenticated"
    - "✅ STEP 2: Input data validated"
    - "📤 STEP 3: Uploading to Cloudinary"
    - "✅ STEP 3 PASSED: Image uploaded"
    - "💾 STEP 4: Saving to Firestore"
    - "✅ STEP 4 PASSED: Poster saved"
```

### 5. Test Real-time Fetch
```
[ ] Poster appears in list immediately
[ ] Refresh page - poster still there
[ ] Open resident app - poster visible
[ ] Filter by building - correct posters shown
```

### 6. Test Delete
```
[ ] Click delete on poster
[ ] Confirm deletion
[ ] Poster removed from list immediately
[ ] Resident app updates in real-time
```

---

## Common Issues & Fixes

### Issue 1: Upload fails with 401 error
**Cause**: Upload preset not created or not unsigned
**Fix**:
1. Go to Cloudinary Console
2. Settings → Upload → Add upload preset
3. Name: `poster_upload`
4. Toggle "Unsigned" ON
5. Save

### Issue 2: Firestore permission denied
**Cause**: Firestore rules not updated
**Fix**:
1. Go to Firebase Console
2. Firestore → Rules
3. Update posters rule to check both `resource.data.adminId` and `request.resource.data.adminId`
4. Publish

### Issue 3: Image not appearing in Firestore
**Cause**: Cloudinary upload failed silently
**Fix**:
1. Check console logs for Cloudinary errors
2. Verify image file is readable
3. Check internet connection
4. Verify upload preset name matches config

### Issue 4: Real-time updates not working
**Cause**: StreamBuilder not listening or Firestore rules blocking read
**Fix**:
1. Verify Firestore rule allows read: `allow read: if request.auth.uid != null;`
2. Check StreamBuilder is properly connected
3. Verify buildingId filter is correct

---

## Flow Function Compliance Summary

| Step | Component | Status | Notes |
|------|-----------|--------|-------|
| 1 | Admin Auth | ✅ | Implemented |
| 2 | Input Validation | ✅ | Implemented |
| 3 | Cloudinary Upload | ⚠️ | Needs setup |
| 4 | Firestore Save | ⚠️ | Needs verification |
| 5 | Real-time Fetch | ⚠️ | Needs testing |
| 6 | Delete Operation | ⚠️ | Needs testing |

---

## Next Steps

1. **Create Cloudinary Upload Preset** (Required)
   - Go to Cloudinary Console
   - Create preset named `poster_upload`
   - Set to Unsigned

2. **Verify Firestore Rules** (Required)
   - Check rules are published
   - Verify posters collection rule

3. **Add HTTP Package** (Required)
   - Run: `flutter pub add http`

4. **Test Upload Flow** (Required)
   - Run app
   - Try uploading a poster
   - Check console logs

5. **Test Real-time Updates** (Required)
   - Upload poster
   - Check appears immediately
   - Delete poster
   - Check disappears immediately

---

## Debug Commands

### Check Admin Authentication
```dart
final adminId = _adminService.getCurrentAdminId();
print('Admin ID: $adminId');
```

### Check Cloudinary Upload
```dart
// Check console logs for:
// 📤 Uploading to Cloudinary...
// 📤 Response status: 200
// ✅ Cloudinary URL: https://...
```

### Check Firestore Save
```dart
// Check console logs for:
// 💾 STEP 4: Saving to Firestore...
// ✅ STEP 4 PASSED: Poster saved - [docId]
```

### Check Real-time Fetch
```dart
// Check console logs for:
// 🔵 POSTER SERVICE: Fetching posters for building
// ✅ Received X posters
```

---

## Success Criteria

✅ All steps complete when:
1. Poster uploads successfully to Cloudinary
2. URL saved to Firestore
3. Poster appears in admin list immediately
4. Poster appears in resident app immediately
5. Delete removes poster from both apps immediately
6. No permission-denied errors
7. No console errors
