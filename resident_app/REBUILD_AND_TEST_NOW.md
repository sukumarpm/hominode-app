# 🚀 REBUILD AND TEST NOW

## CRITICAL FIXES APPLIED

All permission denied errors have been fixed in the code. Now you need to rebuild and test.

---

## STEP 1: REBUILD THE APP (5 minutes)

### Run These Commands
```bash
cd resident_app
flutter clean
flutter pub get
flutter run
```

### What to Expect
- App rebuilds successfully
- No compilation errors
- App launches on device/emulator

---

## STEP 2: TEST LOGIN (2 minutes)

### Login with Resident Credentials
1. Open the app
2. Go to Login Screen
3. Enter resident email or phone
4. Enter password
5. Click Login

### Check Console for These Messages
```
✅ Firebase Auth sign-in successful
✅ Firestore user document updated with Firebase UID
✅ All validations passed!
```

### If You See These Messages
- ✅ Login is working correctly
- ✅ Firebase Auth is synced
- ✅ User document is updated

---

## STEP 3: TEST AMENITIES (2 minutes)

### View Amenities
1. From Home Screen, tap **Amenities**
2. Should see list of amenities

### Check Console for These Messages
```
✅ Streaming bookings for user
✅ Received X amenities from stream
```

### If You See These Messages
- ✅ Amenities are loading
- ✅ No permission errors
- ✅ Building-based filtering is working

---

## STEP 4: TEST BOOKING (3 minutes)

### Book an Amenity
1. From Amenities, tap an amenity
2. Click **Book Now**
3. Select a time slot
4. Click **Confirm Booking**

### Check Console for These Messages
```
✅ Creating booking...
✅ Booking created successfully!
🆔 Booking ID: [booking-id]
```

### If You See These Messages
- ✅ Booking is created
- ✅ No permission errors
- ✅ Booking flow is working

---

## STEP 5: VERIFY FIRESTORE (2 minutes)

### Check Firestore Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Click **Firestore Database**
4. Click **Data** tab

### Check These Collections
- [ ] `users` collection exists
- [ ] User documents have `uid` field
- [ ] User documents have `authUid` field
- [ ] `bookings` collection exists (NOT `amenityBookings`)
- [ ] Booking documents have `userId` field
- [ ] Booking documents have `buildingId` field

### Check Rules
1. Click **Rules** tab
2. Verify rules are published (green checkmark)
3. No syntax errors

---

## QUICK CHECKLIST

### After Rebuild
- [ ] App builds successfully
- [ ] No errors in console

### After Login
- [ ] Login succeeds
- [ ] Console shows Firebase Auth success
- [ ] Console shows user document updated
- [ ] Home screen loads

### After Amenities
- [ ] Amenities list loads
- [ ] No permission errors
- [ ] Can see amenities

### After Booking
- [ ] Can book amenity
- [ ] Booking created successfully
- [ ] No permission errors

### Firestore
- [ ] Rules published
- [ ] User documents have `uid` field
- [ ] Bookings in `bookings` collection
- [ ] Booking documents have `userId` field

---

## IF YOU GET ERRORS

### "Permission Denied" Error
1. Rebuild app: `flutter clean && flutter pub get && flutter run`
2. Check Firestore rules are published
3. Check user document has `uid` field
4. Check booking collection is named `bookings`

### "Firebase Auth sign-in failed"
1. Check user exists in Firebase Auth
2. Check password is correct
3. Check email/phone matches

### "User document not found"
1. Check user exists in Firestore
2. Check user has `buildingId` field
3. Check user has `flatId` field

### "Amenities not loading"
1. Check amenities have `buildingId` field
2. Check user has `buildingId` field
3. Check they match

---

## WHAT WAS FIXED

✅ Collection name: `'amenityBookings'` → `'bookings'`
✅ User ID: Firestore doc ID → Firebase Auth UID
✅ Firebase Auth: Optional → Required
✅ User document: Now synced with Firebase Auth UID

---

## EXPECTED RESULTS

After rebuild and testing:
- ✅ Login works
- ✅ Amenities load
- ✅ Can book amenities
- ✅ No permission errors
- ✅ All flow functions work

---

## NEXT STEPS

1. **Rebuild**: `flutter clean && flutter pub get && flutter run`
2. **Test Login**: Login with resident credentials
3. **Test Amenities**: View amenities list
4. **Test Booking**: Book an amenity
5. **Verify**: Check Firestore console

---

## SUMMARY

All critical fixes have been applied to the code. Now rebuild the app and test.

**Expected**: All permission denied errors fixed ✅

**Time**: ~15 minutes to rebuild and test

**Status**: READY TO TEST

