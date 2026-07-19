# Profile Screen - Testing Guide

## Pre-Testing Checklist

Before testing, ensure:

- [ ] User document exists in Firestore `users` collection
- [ ] Document ID matches Firebase Auth UID
- [ ] User document has required fields: buildingId, flatId, role
- [ ] Firestore security rules are deployed
- [ ] App is built and running
- [ ] User is logged in

## Test 1: Profile Screen Load

### Steps
1. Login to the app
2. Navigate to the Profile tab (bottom navigation)
3. Wait for data to load

### Expected Results
- ✅ User name displays in header
- ✅ User phone displays in header
- ✅ Organization name displays in apartment card
- ✅ Flat number displays in apartment card
- ✅ Profile image displays (or default avatar)
- ✅ Stats cards display (Points, Events, Badges)
- ✅ Menu items display (Edit Profile, Family Members, etc.)

### Console Output
```
🔵 PROFILE SCREEN LOAD FLOW: Starting...
📥 STEP 1: Fetching user data from Firestore...
🔐 STEP 1: Validating user authentication...
✅ STEP 1 PASSED: User authenticated
💾 STEP 2: Checking cache...
✅ STEP 2 PASSED: Cache miss or refresh requested
📥 STEP 3: Fetching user data from Firestore...
✅ STEP 3 PASSED: Document fetched from Firestore
📋 STEP 4: Validating and enriching user data...
✅ STEP 4 PASSED: Data validated
💾 STEP 5: Caching user data...
✅ STEP 5 PASSED: Data cached

✅ USER DATA FETCH FLOW: COMPLETE
   ID: [user_id]
   Name: [user_name]
   Email: [user_email]
   Phone: [user_phone]
   Flat: [flat_number]
   Building ID: [building_id]
   Role: [user_role]

🔍 STEP 2: Getting user ID for organization lookup...
✅ STEP 2 PASSED: User ID: [user_id]
🏢 STEP 3: Fetching organization name...
✅ STEP 3 PASSED: Organization name: [org_name]
🎨 STEP 4: Updating UI with profile data...
✅ STEP 4 PASSED: UI updated with data

✅ PROFILE SCREEN LOAD FLOW: COMPLETE
```

### Troubleshooting
- **No data displays**: Check Firestore for user document
- **"User profile not found" error**: Create user document in Firestore
- **"Permission denied" error**: Deploy Firestore security rules

---

## Test 2: Edit Profile Screen Load

### Steps
1. From Profile screen, tap "Edit Profile"
2. Wait for form to load

### Expected Results
- ✅ Full Name field is populated
- ✅ Email field is populated (disabled)
- ✅ Phone field is populated
- ✅ Flat Number field is populated
- ✅ Profile photo displays (or default avatar)
- ✅ "Tap to change photo" text displays

### Console Output
```
🔵 EDIT PROFILE LOAD FLOW: Starting...
📥 STEP 1: Fetching user data from Firestore...
🔐 STEP 1: Validating user authentication...
✅ STEP 1 PASSED: User authenticated
💾 STEP 2: Checking cache...
✅ STEP 2 PASSED: Cache miss or refresh requested
📥 STEP 3: Fetching user data from Firestore...
✅ STEP 3 PASSED: Document fetched from Firestore
📋 STEP 4: Validating and enriching user data...
✅ STEP 4 PASSED: Data validated
💾 STEP 5: Caching user data...
✅ STEP 5 PASSED: Data cached

✅ USER DATA FETCH FLOW: COMPLETE

🎨 STEP 2: Populating form fields...
✅ STEP 2 PASSED: Form fields populated

✅ EDIT PROFILE LOAD FLOW: COMPLETE
```

### Troubleshooting
- **Form fields are empty**: Check Firestore user document
- **Loading spinner doesn't disappear**: Check console for errors

---

## Test 3: Edit Profile Data

### Steps
1. From Edit Profile screen, modify:
   - Full Name: Change to "Test User"
   - Phone: Change to "+1111111111"
   - Flat Number: Change to "B-202"
2. Tap "Save Changes"
3. Wait for success message

### Expected Results
- ✅ Success message displays: "Profile updated successfully"
- ✅ Screen returns to Profile screen
- ✅ Updated data displays in Profile screen header
- ✅ Data is saved in Firestore

### Console Output
```
🔵 EDIT PROFILE SAVE FLOW: Starting...
📋 STEP 1: Preparing profile updates...
✅ STEP 1 PASSED: Updates prepared
📸 STEP 2: Checking for image upload...
✅ STEP 2 PASSED: No image to upload
💾 STEP 3: Updating user data in Firestore...
   Updates: {name: Test User, phone: +1111111111, flatLabel: B-202}
✅ STEP 3 PASSED: User data updated in Firestore
✅ STEP 4: Returning to profile screen...

✅ EDIT PROFILE SAVE FLOW: COMPLETE
```

### Verification in Firestore
1. Go to Firebase Console
2. Open Firestore Database
3. Navigate to users/{authUid}
4. Verify fields are updated:
   - name: "Test User"
   - phone: "+1111111111"
   - flatLabel: "B-202"
   - updatedAt: Current timestamp

### Troubleshooting
- **Error message displays**: Check console for error details
- **Data not updating in Firestore**: Check Firestore permissions
- **Screen doesn't return to Profile**: Check for exceptions in console

---

## Test 4: Profile Image Upload

### Steps
1. From Edit Profile screen, tap profile photo
2. Select "Gallery" option
3. Choose an image from device
4. Tap "Save Changes"
5. Wait for success message

### Expected Results
- ✅ Image picker opens
- ✅ Selected image displays in profile photo area
- ✅ Success message displays: "Profile updated successfully"
- ✅ Image URL is saved in Firestore
- ✅ Image displays in Profile screen header

### Console Output
```
🔵 EDIT PROFILE SAVE FLOW: Starting...
📋 STEP 1: Preparing profile updates...
✅ STEP 1 PASSED: Updates prepared
📸 STEP 2: Checking for image upload...
   Image selected, uploading to Cloudinary...
✅ STEP 2 PASSED: Image uploaded successfully
   Image URL: https://res.cloudinary.com/...
💾 STEP 3: Updating user data in Firestore...
   Updates: {name: ..., phone: ..., flatLabel: ..., profileImage: https://...}
✅ STEP 3 PASSED: User data updated in Firestore
✅ STEP 4: Returning to profile screen...

✅ EDIT PROFILE SAVE FLOW: COMPLETE
```

### Verification in Firestore
1. Go to Firebase Console
2. Open Firestore Database
3. Navigate to users/{authUid}
4. Verify profileImage field contains URL

### Troubleshooting
- **Image picker doesn't open**: Check app permissions
- **Image upload fails**: Check Cloudinary configuration
- **Image doesn't display**: Check image URL is valid

---

## Test 5: Profile Image Streaming

### Steps
1. From Profile screen, observe profile photo
2. Wait for image to load
3. Go to Edit Profile and change image
4. Return to Profile screen
5. Observe if image updates in real-time

### Expected Results
- ✅ Profile image displays in header
- ✅ Image updates in real-time when changed
- ✅ Default avatar displays if no image

### Console Output
```
🔵 ProfileScreen: Image stream update
⏳ ProfileScreen: Image stream loading...
✅ ProfileScreen: Image URL received: https://res.cloudinary.com/...
```

### Troubleshooting
- **Image doesn't update**: Check StreamBuilder is working
- **Default avatar always shows**: Check profileImage field in Firestore

---

## Test 6: Organization Name Display

### Steps
1. From Profile screen, observe apartment card
2. Verify organization name displays

### Expected Results
- ✅ Organization name displays (e.g., "LYVO Property Management")
- ✅ Flat number displays below organization name

### Console Output
```
🏢 STEP 3: Fetching organization name...
✅ STEP 3 PASSED: Organization name: LYVO Property Management
```

### Troubleshooting
- **"Your Apartment" displays**: Organization service not fetching name
- **No organization name**: Check building data in Firestore

---

## Test 7: Error Handling

### Test 7a: Missing User Document
1. Delete user document from Firestore
2. Restart app and login
3. Navigate to Profile screen

### Expected Results
- ✅ Error message displays: "User profile not found"
- ✅ Console shows: "User document not found"
- ✅ Solution steps display in console

### Test 7b: Missing Required Fields
1. Edit user document in Firestore
2. Remove buildingId field
3. Restart app and navigate to Profile

### Expected Results
- ✅ Warning displays in console: "User document missing required fields"
- ✅ Data still displays but with warning
- ✅ Firestore permission errors may occur

### Test 7c: Permission Denied
1. Update Firestore security rules to deny access
2. Restart app and navigate to Profile

### Expected Results
- ✅ Error message displays: "Permission denied"
- ✅ Console shows troubleshooting steps
- ✅ Solution guidance displays

---

## Test 8: Cache Management

### Steps
1. Load Profile screen (data fetched from Firestore)
2. Navigate away and back to Profile screen
3. Observe console logs

### Expected Results
- ✅ First load: "Cache miss or refresh requested"
- ✅ Second load: "Returning cached user data"
- ✅ Data loads faster on second load

### Console Output
```
First Load:
💾 STEP 2: Checking cache...
✅ STEP 2 PASSED: Cache miss or refresh requested

Second Load:
💾 STEP 2: Checking cache...
✅ STEP 2 PASSED: Returning cached user data
```

---

## Test 9: Force Refresh

### Steps
1. Load Profile screen
2. Edit profile data
3. Return to Profile screen
4. Observe if data updates

### Expected Results
- ✅ Profile screen forces refresh on load
- ✅ Updated data displays immediately
- ✅ Console shows: "Cache miss or refresh requested"

---

## Test 10: Multi-Language Support

### Steps
1. From Profile screen, go to Settings
2. Change language to Spanish/Hindi/Arabic
3. Return to Profile screen
4. Verify text is translated

### Expected Results
- ✅ "Edit Profile" translates to target language
- ✅ "Family Members" translates
- ✅ "My Vehicles" translates
- ✅ All menu items translate

---

## Performance Testing

### Test 1: Load Time
1. Open Profile screen
2. Measure time to display data
3. Expected: < 2 seconds

### Test 2: Memory Usage
1. Open Profile screen
2. Check memory usage in Android Studio
3. Expected: < 50MB increase

### Test 3: Network Usage
1. Open Profile screen
2. Check network requests in DevTools
3. Expected: 1 Firestore read + 1 organization fetch

---

## Regression Testing

### Test 1: Other Screens Still Work
- [ ] Home screen displays correctly
- [ ] Billing screen displays correctly
- [ ] Complaints screen displays correctly
- [ ] Amenities screen displays correctly

### Test 2: Navigation Works
- [ ] Can navigate to Profile from other screens
- [ ] Can navigate from Profile to other screens
- [ ] Back button works correctly

### Test 3: Logout Works
- [ ] Logout button displays on Profile screen
- [ ] Logout clears user data
- [ ] Returns to login screen

---

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Profile Load | ✅/❌ | |
| Edit Profile Load | ✅/❌ | |
| Edit Profile Data | ✅/❌ | |
| Profile Image Upload | ✅/❌ | |
| Image Streaming | ✅/❌ | |
| Organization Name | ✅/❌ | |
| Error Handling | ✅/❌ | |
| Cache Management | ✅/❌ | |
| Force Refresh | ✅/❌ | |
| Multi-Language | ✅/❌ | |

---

## Known Issues

None at this time.

---

## Support

If you encounter issues:

1. Check console logs for error messages
2. Verify Firestore user document exists
3. Verify required fields are present
4. Check Firestore security rules are deployed
5. Review troubleshooting sections above

