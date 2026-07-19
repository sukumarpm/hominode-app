# ⚡ AMENITIES FIX - DO THIS NOW

## The Problem
I can see from your Firebase screenshot that the amenity has:
```
adminId: "UCKG15KKNIeORvJZGQwZEILFTZqy/2"
```

But your user document probably has a DIFFERENT adminId value, so they don't match!

## The Solution

### Option 1: Update User Document (Recommended)

1. Open Firebase Console → Firestore → `users` collection
2. Find YOUR user document (the one you're logged in with)
3. Look at the `adminId` field
4. Copy the exact value

5. Go to `amenities` collection
6. Open the "swimming pool" document
7. Update the `adminId` field to match your user's adminId
8. Make sure it's EXACTLY the same (copy-paste)

### Option 2: Update Amenity Document

OR do it the other way:

1. Open Firebase Console → Firestore → `amenities` collection
2. Open the "swimming pool" document  
3. Copy the `adminId` value: `UCKG15KKNIeORvJZGQwZEILFTZqy/2`

4. Go to `users` collection
5. Find YOUR user document
6. Update the `adminId` field to: `UCKG15KKNIeORvJZGQwZEILFTZqy/2`

### Option 3: Quick Test (No AdminId Filter)

To test if everything else works, temporarily remove the filter:

**Edit**: `lib/src/services/booking_firestore_service.dart`

**Find** (around line 90):
```dart
// Query amenities where adminId matches
final snapshot = await _firestore
    .collection(amenitiesCollection)
    .where('adminId', isEqualTo: filterAdminId)
    .where('isActive', isEqualTo: true)
    .get();
```

**Replace with**:
```dart
// TEMPORARY: Show all amenities
final snapshot = await _firestore
    .collection(amenitiesCollection)
    .where('isActive', isEqualTo: true)
    .get();
```

Save and hot reload (press `r` in terminal).

---

## After Fixing

1. **Hot reload** the app (press `r` in the terminal where flutter run is running)
2. **Or restart** the app completely
3. Go to Amenities Booking screen
4. Tap the refresh icon (↻) in the top right
5. Check the console logs - you should see:
   ```
   ✅ Fetched 1 amenities for admin UCKG15KKNIeORvJZGQwZEILFTZqy/2
   ```

---

## Check Console Logs

When you open the Amenities screen, look for these logs:

**Good**:
```
📥 Fetching amenities from Firestore...
✅ User logged in: abc123
🔍 Filtering amenities by adminId: UCKG15KKNIeORvJZGQwZEILFTZqy/2
✅ Fetched 1 amenities
```

**Bad** (adminId mismatch):
```
📥 Fetching amenities from Firestore...
✅ User logged in: abc123
🔍 Filtering amenities by adminId: DIFFERENT_ID_HERE
⚠️ No amenities found for adminId: DIFFERENT_ID_HERE
```

---

## The Root Cause

The code filters amenities by matching:
```
amenity.adminId == user.adminId
```

If these don't match EXACTLY, no amenities will show.

From your screenshot, the amenity has:
- `adminId: "UCKG15KKNIeORvJZGQwZEILFTZqy/2"`

Your user document must have the SAME value in its `adminId` field.

---

## Quick Commands

```bash
# Run the app
cd resident_app
flutter run

# When app is running, press:
r  # Hot reload
R  # Hot restart
```

---

## Still Not Working?

1. Check that `isActive: true` in the amenity document
2. Check that `isAvailable: true` in the amenity document  
3. Make sure you're logged in
4. Check console logs for errors
5. Try the "Option 3" temporary fix above

---

## What I Changed

I updated the service to:
1. Add better logging (you'll see exactly what's happening)
2. Add fallback logic (if no match, show all amenities)
3. Handle admin vs resident roles properly
4. Try to find admin by email if adminId doesn't work

The code is now more robust, but you still need to make sure the adminId values match in Firebase!
