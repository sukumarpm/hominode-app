# Image Upload - Quick Test Guide

## 🚀 QUICK START TESTING

### Test 1: Create Complaint with Image (5 minutes)

**Steps**:
1. Open app and login
2. Go to Complaints screen
3. Click FAB (floating action button)
4. Fill form:
   - Category: Select any (e.g., "Plumbing")
   - Title: "Test complaint with image"
   - Description: "This is a test complaint to verify image upload works correctly"
   - Photo: Click "Upload photo" → Select from Gallery
5. Click "Submit Complaint"

**Expected Results**:
- ✅ Success message appears: "Complaint submitted successfully!"
- ✅ Modal closes
- ✅ Complaint appears in list
- ✅ Console shows logs:
  ```
  🔵 Submitting complaint with image...
  📝 Creating complaint...
  ✅ Complaint created: complaint_abc123
  📸 Image attached, uploading to Cloudinary...
  📤 Uploading to Cloudinary...
  ✅ Image uploaded to Cloudinary
  🔗 URL: https://res.cloudinary.com/de8yccofb/image/upload/...
  💾 Saving URL to Firestore...
  ✅ URL saved to Firestore
  ```

**Verify in Firestore**:
1. Open Firebase Console
2. Go to Firestore → complaints collection
3. Find your complaint document
4. Check fields:
   - `imageUrl`: Should contain Cloudinary URL
   - `imageUploadedAt`: Should have timestamp
   - `imageUploadedBy`: Should have your user ID

---

### Test 2: View Image in Complaint Detail (3 minutes)

**Steps**:
1. From complaints list, click on the complaint you just created
2. Scroll down to see "Attached Image" section
3. Verify image displays correctly

**Expected Results**:
- ✅ "Attached Image" section appears
- ✅ Image displays from Cloudinary
- ✅ Image loads smoothly
- ✅ Console shows:
  ```
  🔵 Setting up complaint image stream...
  📁 Complaint ID: complaint_abc123
  ✅ Image URL received from stream
  🔗 URL: https://res.cloudinary.com/de8yccofb/image/upload/...
  ```

---

### Test 3: Create Complaint WITHOUT Image (2 minutes)

**Steps**:
1. Click FAB again
2. Fill form WITHOUT selecting image:
   - Category: Select any
   - Title: "Test without image"
   - Description: "This complaint has no image"
3. Click "Submit Complaint"

**Expected Results**:
- ✅ Complaint created successfully
- ✅ No image section shown in detail modal
- ✅ Firestore document has NO `imageUrl` field

---

### Test 4: Real-time Updates (5 minutes)

**Steps**:
1. Open complaint detail modal on your device
2. On another device/browser, update the complaint (if admin)
3. Watch the image section on first device

**Expected Results**:
- ✅ Image updates automatically without refresh
- ✅ StreamBuilder detects changes
- ✅ No manual refresh needed

---

## 🔍 DEBUGGING TIPS

### Check Console Logs
```
// Look for these patterns:
🔵 = Starting operation
📤 = Uploading
💾 = Saving
✅ = Success
❌ = Error
```

### Check Firestore
```
Path: complaints/{complaintId}
Fields to verify:
- imageUrl: "https://res.cloudinary.com/..."
- imageUploadedAt: Timestamp
- imageUploadedBy: "user_id"
```

### Check Cloudinary
```
1. Go to https://cloudinary.com/console
2. Login with credentials
3. Go to Media Library
4. Look for "complaints" folder
5. Verify image uploaded
```

### Common Issues

**Issue**: Image not showing in detail modal
- [ ] Check Firestore: Is `imageUrl` field populated?
- [ ] Check Cloudinary: Is image uploaded?
- [ ] Check URL: Is it valid HTTPS?
- [ ] Check network: Is device connected?

**Issue**: Upload fails silently
- [ ] Check console for error logs
- [ ] Verify Cloudinary credentials
- [ ] Check file size (should be < 5MB)
- [ ] Check file format (should be image)

**Issue**: Firestore not updating
- [ ] Check Firestore rules (should allow write)
- [ ] Check user authentication (should be logged in)
- [ ] Check complaint ID (should be valid)

---

## 📊 EXPECTED BEHAVIOR

### Upload Flow
```
User picks image
    ↓ (1-2 seconds)
Image compresses to 800x800, 85% quality
    ↓ (2-5 seconds)
Uploads to Cloudinary
    ↓ (1-2 seconds)
Stores URL in Firestore
    ↓
Success message shown
```

### Display Flow
```
User opens complaint detail
    ↓
StreamBuilder connects to Firestore
    ↓ (instant)
Checks for imageUrl field
    ↓
If URL exists:
  - Shows "Attached Image" label
  - Displays loading spinner
  - Fetches image from Cloudinary
  - Shows image (1-3 seconds)
```

---

## ✅ FINAL CHECKLIST

- [ ] Test 1: Create with image ✅
- [ ] Test 2: View image ✅
- [ ] Test 3: Create without image ✅
- [ ] Test 4: Real-time updates ✅
- [ ] Console logs show correct flow ✅
- [ ] Firestore has imageUrl field ✅
- [ ] Cloudinary has image uploaded ✅
- [ ] No build errors ✅
- [ ] No runtime errors ✅

**All tests passing? Feature is ready!** 🎉
