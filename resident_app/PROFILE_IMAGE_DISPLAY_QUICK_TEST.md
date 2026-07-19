# Profile Image Display - Quick Test Guide

## QUICK TEST (5 minutes)

### Test 1: Upload Image
1. Open app and login
2. Go to Profile Screen
3. Tap "Edit Profile"
4. Tap camera icon on avatar
5. Select "Gallery" or "Camera"
6. Choose/take a photo
7. Tap "Save Changes"
8. Wait for success message

**Expected Output in Console:**
```
🔵 EditProfile: Starting to save profile...
📸 Image selected, uploading to Cloudinary...
📤 Uploading to Cloudinary...
✅ Image uploaded to Cloudinary
🔗 URL: https://res.cloudinary.com/de8yccofb/image/upload/...
💾 Saving URL to Firestore...
✅ URL saved to Firestore
📍 Path: users/{userId}/profileImage
✅ EditProfile: Profile updated successfully
```

### Test 2: Display Image on Profile Screen
1. After upload, Edit Profile closes automatically
2. You're back on Profile Screen
3. Look at the avatar in the header

**Expected Result:**
- Avatar shows the uploaded image
- Image loads from Cloudinary URL
- No placeholder icon visible

**Expected Output in Console:**
```
🔵 ProfileScreen: Image stream update
⏳ ProfileScreen: Image stream loading...

🔵 ProfileScreen: Image stream update
✅ ProfileScreen: Image URL received: https://res.cloudinary.com/de8yccofb/image/upload/...
```

### Test 3: Real-Time Update
1. Go back to Edit Profile
2. Upload a different image
3. Save changes
4. Watch Profile Screen avatar update automatically

**Expected Result:**
- Avatar updates without manual refresh
- New image displays immediately
- Old image replaced

---

## WHAT TO CHECK

### ✅ Image Upload
- [ ] Image uploads without errors
- [ ] Cloudinary URL appears in console
- [ ] Success message shows

### ✅ Image Display
- [ ] Avatar shows image (not placeholder icon)
- [ ] Image loads from Cloudinary
- [ ] Image displays in circular avatar

### ✅ Real-Time Updates
- [ ] Upload new image in Edit Profile
- [ ] Profile Screen updates automatically
- [ ] No manual refresh needed

### ✅ Error Handling
- [ ] If upload fails, error message shows
- [ ] If no image, placeholder icon shows
- [ ] If network error, graceful fallback

### ✅ Console Logging
- [ ] All logs have emoji indicators (🔵 ✅ ❌ ⏳)
- [ ] Flow function pattern visible in logs
- [ ] No error messages

---

## FIRESTORE VERIFICATION

1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to: `users/{your_user_id}`
4. Check fields:
   - `profileImage`: Should have Cloudinary URL
   - `profileImageUrl`: Should have Cloudinary URL
   - `profileImageUpdatedAt`: Should have timestamp

**Expected Data:**
```
profileImage: "https://res.cloudinary.com/de8yccofb/image/upload/v1234567890/profile_pictures/user_abc123.jpg"
profileImageUrl: "https://res.cloudinary.com/de8yccofb/image/upload/v1234567890/profile_pictures/user_abc123.jpg"
profileImageUpdatedAt: Timestamp(seconds=1234567890, nanoseconds=0)
```

---

## TROUBLESHOOTING

### Image Not Displaying
1. Check console for error logs
2. Verify Firestore has profileImage field
3. Verify URL is valid Cloudinary URL
4. Check network connection

### Upload Fails
1. Check Cloudinary credentials in cloudinary_service.dart
2. Verify image file is valid
3. Check file size (should be < 5MB)
4. Check network connection

### Real-Time Update Not Working
1. Verify StreamBuilder is active
2. Check Firestore security rules allow read
3. Verify userId is captured correctly
4. Check console for stream errors

---

## CONSOLE LOG REFERENCE

### Successful Flow
```
🔵 ProfileScreen: Loading user profile from Firestore...
✅ ProfileScreen: User data loaded successfully
🔵 ProfileScreen: Image stream update
⏳ ProfileScreen: Image stream loading...
✅ ProfileScreen: Image URL received: https://...
```

### Error Flow
```
❌ ProfileScreen: No image data in stream
❌ ProfileScreen: {error message}
⚠️ ProfileScreen: No image found for this user
```

---

## QUICK COMMANDS

### View Firestore Data
```
Firebase Console → Firestore Database → users → {userId}
```

### View Cloudinary Images
```
https://res.cloudinary.com/de8yccofb/image/upload/
```

### Check Logs
```
Flutter DevTools → Logging tab
Search for: "ProfileScreen" or "EditProfile"
```

---

## EXPECTED BEHAVIOR

| Action | Expected Result | Console Log |
|--------|-----------------|-------------|
| Open Profile | Avatar shows image or placeholder | 🔵 Image stream update |
| Upload image | Image displays after save | ✅ Image URL received |
| Update image | Avatar updates automatically | 🔵 Image stream update |
| No image | Shows person icon | ⚠️ No image found |
| Network error | Shows person icon | ❌ Stream error |

---

## DONE ✅

Profile image display is complete and ready for testing!
