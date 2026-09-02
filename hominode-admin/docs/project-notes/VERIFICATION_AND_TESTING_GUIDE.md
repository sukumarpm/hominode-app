# Verification and Testing Guide

## Pre-Testing Checklist

Before testing, make sure:
- [ ] App is compiled without errors
- [ ] You have a Firebase project set up
- [ ] You have admin credentials ready
- [ ] You have Cloudinary credentials configured

---

## Test 1: Admin Login

### Steps
1. Open the admin app
2. Enter admin credentials:
   - Email: `admin@lyvo.com`
   - Password: `test@123`
3. Click Login

### Expected Result
- ✅ Login succeeds
- ✅ Dashboard appears
- ✅ No error messages

### If It Fails
- Check Firebase Auth configuration
- Verify admin account exists in Firebase Auth
- Check Firebase Console logs

---

## Test 2: Create Building with Flats

### Steps
1. Login as admin
2. Go to Building Management
3. Click "Add Building"
4. Enter building details:
   - Building Name: "Test Building"
   - Floors: 2
   - Flats per Floor: 3
5. Click Create

### Expected Result
- ✅ Building created successfully
- ✅ 6 flats generated (2 floors × 3 flats)
- ✅ Flat IDs: T001, T002, T003, T004, T005, T006
- ✅ No error messages

### If It Fails
- Check Firestore permissions
- Verify building collection exists
- Check Firebase Console logs

---

## Test 3: Create Resident

### Steps
1. Login as admin
2. Go to Resident Management
3. Click "Add Resident"
4. Enter resident details:
   - Name: "John Doe"
   - Phone: "9876543210"
   - Email: "john@example.com"
   - Password: "Test@123"
5. Click Create

### Expected Result
- ✅ Resident created successfully
- ✅ Resident ID generated (e.g., "RES1234")
- ✅ No error messages
- ✅ Resident appears in resident list

### If It Fails
- Check Firestore permissions
- Verify users collection exists
- Check Firebase Console logs

---

## Test 4: Assign Resident to Flat (CRITICAL TEST)

### Steps
1. Login as admin
2. Go to Flat Management
3. Click on a flat (e.g., "T001")
4. Click "Assign Resident"
5. Select the resident you created
6. Click Assign

### Expected Result
- ✅ Resident assigned successfully
- ✅ Flat status changes to "Occupied"
- ✅ **NO "not-found" error** ← This is the critical fix
- ✅ Occupancy rate updates

### If It Fails
- ❌ "not-found" error: Firestore rules issue or query problem
- Check `admin_app/lib/services/user_service.dart` assignUserToFlat method
- Verify flat document has `flatId` field
- Check Firebase Console logs

---

## Test 5: Update Flat Status (CRITICAL TEST)

### Steps
1. Login as admin
2. Go to Flat Management
3. Click on an occupied flat
4. Change status from "Occupied" to "Vacant"
5. Click Update

### Expected Result
- ✅ Flat status updated successfully
- ✅ **NO "not-found" error** ← This is the critical fix
- ✅ Occupancy rate updates

### If It Fails
- ❌ "not-found" error: Query problem
- Check `admin_app/lib/services/flat_service.dart` updateFlatStatus method
- Verify flat document has `flatId` field
- Check Firebase Console logs

---

## Test 6: Upload Apartment Images (CRITICAL TEST)

### Steps
1. Login as admin
2. Go to Apartment Images Management
3. Click "Add Image"
4. Select a building and flat
5. Upload an image file
6. Click Upload

### Expected Result
- ✅ Image uploaded successfully
- ✅ **NO 401 error** ← This is the critical fix
- ✅ Image appears in the list
- ✅ Image URL is displayed

### If It Fails
- ❌ 401 error: Cloudinary configuration issue
- Verify upload preset exists in Cloudinary
- Verify upload preset is set to UNSIGNED mode
- Check Cloudinary credentials in code
- Check Firebase Console logs

---

## Test 7: Upload Posters (CRITICAL TEST)

### Steps
1. Login as admin
2. Go to Poster Management
3. Click "Add Poster"
4. Enter poster details
5. Upload a poster image
6. Click Create

### Expected Result
- ✅ Poster created successfully
- ✅ **NO 401 error** ← This is the critical fix
- ✅ Poster appears in the list
- ✅ Poster image is displayed

### If It Fails
- ❌ 401 error: Cloudinary configuration issue
- Same troubleshooting as Test 6

---

## Test 8: Resident Login (REQUIRES FIRESTORE RULES)

### Prerequisites
- ✅ Firestore rules must be applied to Firebase Console
- ✅ Resident must be created with email and password

### Steps
1. Logout from admin account
2. Go to resident login screen
3. Enter resident credentials:
   - Email: (the email you used when creating resident)
   - Password: (the password you used when creating resident)
4. Click Login

### Expected Result
- ✅ Login succeeds
- ✅ Resident dashboard appears
- ✅ **NO "Permission denied" error** ← This requires Firestore rules
- ✅ Resident can see their profile

### If It Fails
- ❌ "Permission denied" error: Firestore rules not applied
  - Go to Firebase Console → Firestore Database → Rules
  - Apply rules from `FIRESTORE_RULES_COPY_PASTE.md`
  - Publish and wait 1-2 minutes
  - Try login again
- ❌ "No account found" error: Resident not created properly
  - Verify resident exists in Firestore users collection
  - Check that resident has `authEmail` field
- ❌ "Invalid credentials" error: Wrong email or password
  - Verify email and password are correct
  - Check resident document in Firestore

---

## Test 9: Resident Profile Access (REQUIRES FIRESTORE RULES)

### Prerequisites
- ✅ Resident must be logged in
- ✅ Firestore rules must be applied

### Steps
1. Login as resident (see Test 8)
2. Go to Profile screen
3. View resident details

### Expected Result
- ✅ Profile loads successfully
- ✅ Resident details are displayed
- ✅ **NO "Permission denied" error** ← This requires Firestore rules

### If It Fails
- ❌ "Permission denied" error: Firestore rules not applied
  - Apply rules from `FIRESTORE_RULES_COPY_PASTE.md`
  - Publish and wait 1-2 minutes
  - Try again

---

## Test 10: Resident View Flat Details (REQUIRES FIRESTORE RULES)

### Prerequisites
- ✅ Resident must be logged in
- ✅ Resident must be assigned to a flat
- ✅ Firestore rules must be applied

### Steps
1. Login as resident
2. Go to Flat Details screen
3. View flat information

### Expected Result
- ✅ Flat details load successfully
- ✅ Flat information is displayed
- ✅ **NO "Permission denied" error** ← This requires Firestore rules

### If It Fails
- ❌ "Permission denied" error: Firestore rules not applied
  - Apply rules from `FIRESTORE_RULES_COPY_PASTE.md`
  - Publish and wait 1-2 minutes
  - Try again

---

## Verification Checklist

### Admin App Tests
- [ ] Test 1: Admin Login ✅
- [ ] Test 2: Create Building with Flats ✅
- [ ] Test 3: Create Resident ✅
- [ ] Test 4: Assign Resident to Flat (NO "not-found" error) ✅
- [ ] Test 5: Update Flat Status (NO "not-found" error) ✅
- [ ] Test 6: Upload Apartment Images (NO 401 error) ✅
- [ ] Test 7: Upload Posters (NO 401 error) ✅

### Resident App Tests (After Firestore Rules Applied)
- [ ] Test 8: Resident Login (NO "Permission denied" error) ✅
- [ ] Test 9: Resident Profile Access (NO "Permission denied" error) ✅
- [ ] Test 10: Resident View Flat Details (NO "Permission denied" error) ✅

---

## Troubleshooting

### Error: "not-found" in Flat Assignment or Status Update

**Cause:** Firestore query not finding the flat document

**Solution:**
1. Check that flat document has `flatId` field
2. Verify the `flatId` value matches what you're querying
3. Check Firebase Console logs for query errors
4. Verify Firestore permissions allow reads

**Debug Steps:**
1. Go to Firebase Console → Firestore Database → Data
2. Click on "flats" collection
3. Click on a flat document
4. Verify it has a `flatId` field with value like "T001"
5. If missing, the flat wasn't created properly

---

### Error: "401 Unauthorized" in Cloudinary Upload

**Cause:** Cloudinary upload preset not configured correctly

**Solution:**
1. Verify upload preset exists in Cloudinary dashboard
2. Verify upload preset is set to UNSIGNED mode
3. Verify upload preset name matches code
4. Verify Cloudinary cloud name is correct

**Debug Steps:**
1. Go to Cloudinary dashboard
2. Go to Settings → Upload
3. Look for "Upload presets" section
4. Verify preset `lyvo_upload` exists
5. Verify it's set to UNSIGNED mode
6. Verify cloud name in code matches Cloudinary account

---

### Error: "Permission denied" in Resident Login

**Cause:** Firestore rules not applied to Firebase Console

**Solution:**
1. Go to Firebase Console → Firestore Database → Rules
2. Replace all rules with content from `FIRESTORE_RULES_COPY_PASTE.md`
3. Click Publish
4. Wait 1-2 minutes for deployment
5. Try login again

**Debug Steps:**
1. Go to Firebase Console
2. Go to Firestore Database → Rules
3. Look for the rule: `allow read: if request.auth.uid == resource.data.authUid;`
4. If you see `allow read: if request.auth.uid == userId;` instead, rules are old
5. Apply new rules

---

### Error: "No account found" in Resident Login

**Cause:** Resident not created properly or doesn't exist

**Solution:**
1. Verify resident exists in Firestore
2. Verify resident has `authEmail` field
3. Verify resident has `password` field
4. Recreate resident if necessary

**Debug Steps:**
1. Go to Firebase Console → Firestore Database → Data
2. Click on "users" collection
3. Look for the resident document
4. Verify it has:
   - `authEmail` field
   - `password` field
   - `residentId` field
   - `role` field with value "resident"

---

### Error: "Invalid credentials" in Resident Login

**Cause:** Wrong email or password

**Solution:**
1. Verify email is correct (should be the `authEmail` field)
2. Verify password is correct (should be the password you set)
3. Check for typos
4. Try again

**Debug Steps:**
1. Go to Firebase Console → Firestore Database → Data
2. Click on "users" collection
3. Click on the resident document
4. Check the `authEmail` field
5. Use that email for login
6. Use the password you set when creating resident

---

## Performance Expectations

### Admin App
- Login: < 2 seconds
- Create building: < 3 seconds
- Create resident: < 2 seconds
- Assign resident: < 2 seconds
- Update flat status: < 2 seconds
- Upload image: 5-10 seconds (depends on image size)

### Resident App
- Login: < 3 seconds (first time) / < 2 seconds (subsequent)
- View profile: < 1 second
- View flat details: < 1 second

---

## Success Criteria

### All Tests Pass ✅
- [ ] Admin can login
- [ ] Admin can create buildings and flats
- [ ] Admin can create residents
- [ ] Admin can assign residents to flats (NO "not-found" error)
- [ ] Admin can update flat status (NO "not-found" error)
- [ ] Admin can upload images (NO 401 error)
- [ ] Admin can upload posters (NO 401 error)
- [ ] Resident can login (after Firestore rules applied)
- [ ] Resident can view profile
- [ ] Resident can view flat details

### All Errors Fixed ✅
- [ ] Cloudinary 401 error: FIXED
- [ ] Resident assignment "not-found" error: FIXED
- [ ] Flat status update "not-found" error: FIXED
- [ ] Resident login "Permission denied" error: FIXED (after rules applied)

---

## Next Steps

1. **Run Tests 1-7** (Admin App)
   - Should all pass without errors
   - If any fail, check troubleshooting section

2. **Apply Firestore Rules**
   - Go to Firebase Console → Firestore Database → Rules
   - Replace with rules from `FIRESTORE_RULES_COPY_PASTE.md`
   - Publish and wait 1-2 minutes

3. **Run Tests 8-10** (Resident App)
   - Should all pass without errors
   - If any fail, check troubleshooting section

4. **Celebrate! 🎉**
   - All errors fixed
   - All features working
   - App ready for production

---

## Questions?

If you have any questions or issues:
1. Check the troubleshooting section above
2. Review the detailed documentation in `admin_app/RESIDENT_LOGIN_AND_FLAT_STATUS_FIX_COMPLETE.md`
3. Look at the error message in Firebase Console logs
4. Check the code changes in `CODE_CHANGES_EXPLAINED.md`

Good luck! 🚀
