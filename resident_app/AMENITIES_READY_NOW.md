# ✅ Amenities Booking - Ready to Test

## What's Fixed

The code now matches how the admin app stores amenities - filtering by `adminId` ONLY (no buildingId required).

---

## Flow Function

### Admin Creates Amenity:
```javascript
// Admin app stores in Firestore:
{
  "name": "swimming pool",
  "adminId": "UCKG15KKNIeORvJZGQwZEILFTZqy/2",  // Admin's UID
  "adminEmail": "admin@lyvo.com",
  "adminName": "lyvo home's",
  "isActive": true,
  "isFree": true,
  "price": 0
}
```

### Resident App Fetches:
```dart
// Query: WHERE adminId == user.adminId AND isActive == true
amenities.where('adminId', isEqualTo: user.adminId)
         .where('isActive', isEqualTo: true)
```

---

## Required Data Structure

### 1. User Document (Resident)
```javascript
// Collection: users
{
  "name": "John Doe",
  "email": "john@example.com",
  "role": "resident",
  "adminId": "UCKG15KKNIeORvJZGQwZEILFTZqy/2",  // ← Must match amenity's adminId
  "flatId": "flat_123",
  "flatLabel": "A-101"
}
```

### 2. Amenity Document (Created by Admin)
```javascript
// Collection: amenities
{
  "name": "swimming pool",
  "adminId": "UCKG15KKNIeORvJZGQwZEILFTZqy/2",  // ← Must match user's adminId
  "isActive": true,
  "price": 0,
  "isFree": true
}
```

### 3. Matching Rule
```
user.adminId == amenity.adminId
```

If these match, amenities will display!

---

## How to Test

### Step 1: Check Your User Document

1. Firebase Console → Firestore → `users` collection
2. Find your user document (the one you're logged in with)
3. Check the `adminId` field value
4. Copy it (e.g., `UCKG15KKNIeORvJZGQwZEILFTZqy/2`)

### Step 2: Check Amenity Document

1. Firebase Console → Firestore → `amenities` collection
2. Open the swimming pool document
3. Check the `adminId` field value
4. It should match your user's `adminId` EXACTLY

### Step 3: Fix If Needed

If they don't match:

**Option A**: Update user's adminId to match amenity
```
User document → adminId = "UCKG15KKNIeORvJZGQwZEILFTZqy/2"
```

**Option B**: Update amenity's adminId to match user
```
Amenity document → adminId = "your_user_adminId"
```

### Step 4: Hot Reload

```bash
# In terminal where flutter run is active:
r
```

### Step 5: Check Console

You should see:
```
📥 Fetching amenities from Firestore (Flow Function)...
✅ User logged in: abc123
👤 User role: resident
🔑 User adminId: UCKG15KKNIeORvJZGQwZEILFTZqy/2
🔍 Resident user - filtering by adminId: UCKG15KKNIeORvJZGQwZEILFTZqy/2
🔍 Querying amenities where adminId = UCKG15KKNIeORvJZGQwZEILFTZqy/2
📊 Query returned 1 documents
  📍 swimming pool (adminId: UCKG15KKNIeORvJZGQwZEILFTZqy/2)
✅ Fetched 1 amenities for adminId: UCKG15KKNIeORvJZGQwZEILFTZqy/2
```

---

## What the Code Does

### For Residents:
1. Gets user's `adminId` from their document
2. Queries amenities where `amenity.adminId == user.adminId`
3. Only shows active amenities (`isActive: true`)
4. Displays them in a grid

### For Admins:
1. Uses admin's own UID as the filter
2. Shows amenities they created
3. Same display logic

### Fallback:
If no `adminId` or no matches found, shows all active amenities.

---

## Console Logs Explained

**Good (Working)**:
```
✅ Fetched 1 amenities for adminId: UCKG15KKNIeORvJZGQwZEILFTZqy/2
🔵 AmenitiesBookingScreen: Received 1 amenities
📋 Amenities list:
  - swimming pool (0)
```
→ Amenities will display!

**Bad (Not Working)**:
```
⚠️ No amenities found for adminId: xyz123
💡 Trying fallback: all active amenities
✅ Fetched 0 amenities (all active - fallback)
```
→ AdminId mismatch or no amenities in database

---

## Quick Commands

```bash
# Hot reload (in flutter run terminal)
r

# Hot restart
R

# Run app
flutter run
```

---

## Still Not Working?

### Check 1: User has adminId
```
Firebase → users → your_user → adminId field exists
```

### Check 2: Amenity has adminId
```
Firebase → amenities → swimming_pool → adminId field exists
```

### Check 3: Values Match
```
user.adminId == amenity.adminId
```

### Check 4: Amenity is Active
```
amenity.isActive == true
```

### Check 5: Console Logs
Look for error messages or "No amenities found"

---

## Files Modified

- `lib/src/services/booking_firestore_service.dart`
  - Simplified to filter by `adminId` only
  - Removed `buildingId` filter (not stored by admin app)
  - Added comprehensive logging
  - Added fallback logic

---

## Summary

**Filter**: adminId only (matches admin app behavior)  
**Required**: user.adminId == amenity.adminId  
**Fallback**: Shows all active amenities if no match  
**Logging**: Detailed console output at every step

Hot reload and check the console - it will tell you exactly what's happening!
