# 🔍 Amenities Not Displaying - Diagnostic Guide

## Issue
Amenities are not fetching/displaying from Firestore on the Amenities Booking screen.

## Quick Test Command
```bash
flutter run lib/test_amenities_fetch.dart
```

This will run 3 diagnostic tests:
1. Check user data and adminId
2. Test amenities fetch via service
3. Direct Firestore query to check data

---

## Common Causes & Solutions

### 1. ❌ No Amenities in Firestore
**Symptom**: Test shows "Total documents in collection: 0"

**Solution**: Add amenities to Firestore
```
Collection: amenities
Document structure:
{
  "name": "Swimming Pool",
  "price": "₹500/hour",
  "adminId": "admin_user_id_here",
  "isActive": true,
  "iconName": "pool",
  "backgroundColor": "#D6EBFF",
  "iconColor": "#0A64FF",
  "openTime": "6:00 AM",
  "closeTime": "8:00 PM"
}
```

### 2. ❌ AdminId Mismatch
**Symptom**: Test shows "User has adminId: X" but "Amenities for this admin: 0"

**Solution**: 
- Check that amenities in Firestore have the correct `adminId` field
- The `adminId` in amenity documents must match the user's `adminId`
- For testing, you can temporarily remove the adminId filter (see below)

### 3. ❌ User Has No AdminId
**Symptom**: Test shows "User has no adminId assigned"

**Solution**: 
- Add `adminId` field to user document in Firestore
- Or use the fallback logic (service will fetch all active amenities)

### 4. ❌ All Amenities Have isActive = false
**Symptom**: Test shows amenities exist but none are active

**Solution**: Set `isActive: true` in amenity documents

### 5. ❌ Firestore Security Rules Blocking Access
**Symptom**: Test shows "Security rules might be blocking access"

**Solution**: Update Firestore security rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read amenities
    match /amenities/{amenityId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## Temporary Fix: Remove AdminId Filter

If you want to test without adminId filtering, update `booking_firestore_service.dart`:

**Find this code** (around line 60):
```dart
// Query amenities where adminId matches user's admin
final snapshot = await _firestore
    .collection(amenitiesCollection)
    .where('adminId', isEqualTo: adminId)
    .where('isActive', isEqualTo: true)
    .get();
```

**Replace with**:
```dart
// TEMPORARY: Fetch all active amenities (no adminId filter)
final snapshot = await _firestore
    .collection(amenitiesCollection)
    .where('isActive', isEqualTo: true)
    .get();
```

---

## Step-by-Step Debugging

### Step 1: Run the diagnostic test
```bash
cd resident_app
flutter run lib/test_amenities_fetch.dart
```

### Step 2: Check the output

**If you see**:
```
✅ User logged in: abc123
✅ User has adminId: admin_xyz
```
→ Good! User is authenticated and has adminId

**If you see**:
```
❌ No user logged in
```
→ You need to log in first through the app

### Step 3: Check amenities count

**If you see**:
```
Total documents in collection: 0
```
→ Add amenities to Firestore (see structure above)

**If you see**:
```
Total documents in collection: 5
Active amenities: 5
Amenities for this admin: 0
```
→ AdminId mismatch - update amenity documents with correct adminId

**If you see**:
```
Total documents in collection: 5
Active amenities: 0
```
→ Set `isActive: true` in amenity documents

### Step 4: Check Firestore Console

1. Open Firebase Console → Firestore Database
2. Navigate to `amenities` collection
3. Verify documents exist
4. Check each document has:
   - `name` (string)
   - `price` (string)
   - `adminId` (string) - must match user's adminId
   - `isActive` (boolean) - must be true
   - `iconName` (string)
   - `backgroundColor` (string)
   - `iconColor` (string)

### Step 5: Check User Document

1. Open Firebase Console → Firestore Database
2. Navigate to `users` collection
3. Find your user document (by email or uid)
4. Verify it has:
   - `adminId` (string) - must match amenities' adminId
   - `role` (string) - "resident" or "admin"
   - `flatId` (string)
   - `flatLabel` (string)

---

## Expected Behavior

### For Residents:
- See only amenities where `amenity.adminId == user.adminId`
- Can book amenities
- Can view their own bookings

### For Admins:
- See only amenities where `amenity.adminId == user.uid` (admin's own ID)
- Can book amenities
- Can view all bookings for their managed flats

---

## Sample Amenity Data for Testing

Add these to Firestore → `amenities` collection:

```javascript
// Document 1: Swimming Pool
{
  "name": "Swimming Pool",
  "price": "₹500/hour",
  "adminId": "YOUR_ADMIN_ID_HERE",  // ← Replace with actual adminId
  "isActive": true,
  "iconName": "pool",
  "backgroundColor": "#D6EBFF",
  "iconColor": "#0A64FF",
  "openTime": "6:00 AM",
  "closeTime": "8:00 PM"
}

// Document 2: Gym
{
  "name": "Gym",
  "price": "Free",
  "adminId": "YOUR_ADMIN_ID_HERE",  // ← Replace with actual adminId
  "isActive": true,
  "iconName": "gym",
  "backgroundColor": "#FFE5E5",
  "iconColor": "#FF5757",
  "openTime": "5:00 AM",
  "closeTime": "10:00 PM"
}

// Document 3: Community Hall
{
  "name": "Community Hall",
  "price": "₹2000/day",
  "adminId": "YOUR_ADMIN_ID_HERE",  // ← Replace with actual adminId
  "isActive": true,
  "iconName": "hall",
  "backgroundColor": "#FFF4E6",
  "iconColor": "#FF9800",
  "openTime": "9:00 AM",
  "closeTime": "11:00 PM"
}

// Document 4: Party Lawn
{
  "name": "Party Lawn",
  "price": "₹3000/day",
  "adminId": "YOUR_ADMIN_ID_HERE",  // ← Replace with actual adminId
  "isActive": true,
  "iconName": "lawn",
  "backgroundColor": "#E5F6E9",
  "iconColor": "#0AA03C",
  "openTime": "10:00 AM",
  "closeTime": "10:00 PM"
}
```

---

## Quick Checklist

- [ ] User is logged in
- [ ] User document has `adminId` field
- [ ] Amenities collection exists in Firestore
- [ ] Amenity documents have `adminId` field
- [ ] Amenity `adminId` matches user's `adminId`
- [ ] Amenities have `isActive: true`
- [ ] Firestore security rules allow reading amenities
- [ ] App has been restarted after adding data

---

## Still Not Working?

If amenities still don't show after checking everything:

1. **Check console logs** in the app:
   - Look for "📥 Fetching amenities from Firestore..."
   - Look for "✅ Fetched X amenities"
   - Look for any error messages

2. **Try the temporary fix** (remove adminId filter) to isolate the issue

3. **Verify network connection** - ensure device can reach Firebase

4. **Check Firebase project** - ensure you're using the correct Firebase project

5. **Restart the app** - sometimes cached data needs to be cleared

---

## Files Modified

- `lib/src/services/booking_firestore_service.dart` - Added `getAmenities()` and `streamAmenities()`
- `lib/src/screens/amenities_booking_screen.dart` - Added `_loadAmenities()` and dynamic grid
- `lib/test_amenities_fetch.dart` - Diagnostic test script

---

## Next Steps

Once amenities are displaying:
1. Test booking creation
2. Verify bookings are saved with flatId, flatLabel, adminId
3. Test admin view (if applicable)
4. Test booking cancellation
