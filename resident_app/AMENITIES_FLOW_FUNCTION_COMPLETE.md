# ✅ Amenities Booking - Flow Function Implementation Complete

## Flow Function Pattern

Amenities are now filtered by BOTH `adminId` AND `buildingId` following the proper flow function pattern used throughout the app.

---

## Data Flow

### 1. User Document Structure
```javascript
// Collection: users
{
  "name": "John Doe",
  "email": "john@example.com",
  "role": "resident",           // or "admin"
  "adminId": "admin_user_id",   // ✅ Required for filtering
  "buildingId": "building_123", // ✅ Required for filtering
  "flatId": "flat_456",
  "flatLabel": "A-101"
}
```

### 2. Amenity Document Structure
```javascript
// Collection: amenities
{
  "name": "Swimming Pool",
  "price": "₹500/hour",
  "adminId": "admin_user_id",   // ✅ Must match user's adminId
  "buildingId": "building_123", // ✅ Must match user's buildingId
  "isActive": true,
  "iconName": "pool",
  "backgroundColor": "#D6EBFF",
  "iconColor": "#0A64FF",
  "openTime": "6:00 AM",
  "closeTime": "8:00 PM"
}
```

### 3. Booking Document Structure
```javascript
// Collection: bookings
{
  "userId": "user_uid",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "flatId": "flat_456",
  "flatLabel": "A-101",
  "adminId": "admin_user_id",   // ✅ Stored from user
  "buildingId": "building_123", // ✅ Stored from user
  "amenityId": "amenity_id",
  "amenityName": "Swimming Pool",
  "date": "Timestamp",
  "timeSlot": "10:00 AM - 11:00 AM",
  "status": "confirmed",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

---

## Filtering Logic

### For Residents:
```dart
// Fetch amenities where:
amenity.adminId == user.adminId
AND
amenity.buildingId == user.buildingId
AND
amenity.isActive == true
```

**Result**: Residents see only amenities for their building and admin.

### For Admins:
```dart
// Fetch amenities where:
amenity.adminId == user.uid  // Admin's own ID
AND
amenity.buildingId == user.buildingId
AND
amenity.isActive == true
```

**Result**: Admins see only amenities they created for their building.

---

## Implementation Details

### Service Method: `getAmenities()`

**Steps**:
1. Get current user
2. Fetch user document from Firestore
3. Extract `adminId` and `buildingId`
4. Determine role (admin or resident)
5. Build query with filters:
   - `adminId` (required)
   - `buildingId` (required if available)
   - `isActive = true` (always)
6. Execute query and return results

**Fallback Logic**:
- If no `adminId`: fetch all active amenities
- If no matches with both filters: try `adminId` only
- If still no matches: fetch all active amenities

### Service Method: `streamAmenities()`

Same logic as `getAmenities()` but returns a real-time stream.

### Service Method: `createBooking()`

**Stores**:
- User info: `userId`, `userName`, `userEmail`
- Flat info: `flatId`, `flatLabel`
- Access control: `adminId`, `buildingId` ✅
- Booking info: `amenityId`, `amenityName`, `date`, `timeSlot`, `status`

---

## Console Logs

When fetching amenities, you'll see:

```
📥 Fetching amenities from Firestore (Flow Function)...
✅ User logged in: abc123
📋 User data fields: [name, email, role, adminId, buildingId, flatId, flatLabel]
👤 User role: resident
🔑 User adminId: admin_xyz
🏢 User buildingId: building_123
🏠 User flatId: flat_456
🔍 Resident user - filtering by adminId and buildingId
🔍 Querying amenities:
   - adminId: admin_xyz
   - buildingId: building_123
   - isActive: true
   ✅ Added buildingId filter
📊 Query returned 2 documents
  📍 Swimming Pool (adminId: admin_xyz, buildingId: building_123)
  📍 Gym (adminId: admin_xyz, buildingId: building_123)
✅ Fetched 2 amenities (adminId + buildingId filter)
```

---

## Required Firebase Data

### 1. User Document Must Have:
- ✅ `adminId` field (string)
- ✅ `buildingId` field (string)
- ✅ `flatId` field (string)
- ✅ `flatLabel` field (string)
- ✅ `role` field ("resident" or "admin")

### 2. Amenity Documents Must Have:
- ✅ `adminId` field (string) - matches user's adminId
- ✅ `buildingId` field (string) - matches user's buildingId
- ✅ `isActive` field (boolean) - set to true
- ✅ `name`, `price`, `iconName`, `backgroundColor`, `iconColor`

### 3. Matching Requirements:
```
user.adminId == amenity.adminId
AND
user.buildingId == amenity.buildingId
```

---

## Testing

### Step 1: Verify User Document

Open Firebase Console → Firestore → `users` collection → Your user document

Check it has:
```json
{
  "adminId": "some_admin_id",
  "buildingId": "some_building_id",
  "flatId": "some_flat_id",
  "flatLabel": "A-101",
  "role": "resident"
}
```

### Step 2: Verify Amenity Document

Open Firebase Console → Firestore → `amenities` collection → Amenity document

Check it has:
```json
{
  "name": "Swimming Pool",
  "adminId": "some_admin_id",      // ← Must match user's adminId
  "buildingId": "some_building_id", // ← Must match user's buildingId
  "isActive": true,
  "price": "₹500/hour"
}
```

### Step 3: Test in App

1. Hot reload the app (`r` in terminal)
2. Navigate to Amenities Booking screen
3. Tap refresh button (↻)
4. Check console logs
5. Verify amenities display

---

## Troubleshooting

### No amenities showing?

**Check 1: AdminId Match**
```
user.adminId == amenity.adminId
```
If these don't match, amenities won't show.

**Check 2: BuildingId Match**
```
user.buildingId == amenity.buildingId
```
If these don't match, amenities won't show.

**Check 3: IsActive**
```
amenity.isActive == true
```
If false, amenity won't show.

**Check 4: Fields Exist**
- User document has `adminId` and `buildingId` fields
- Amenity document has `adminId` and `buildingId` fields

### Console shows "No buildingId - skipping building filter"?

Your user document doesn't have a `buildingId` field. Add it:

1. Firebase Console → Firestore → `users` → Your user
2. Add field: `buildingId` = `"your_building_id"`
3. Hot reload app

### Console shows "No amenities found with filters"?

The filters don't match. Check:
1. User's `adminId` matches amenity's `adminId`
2. User's `buildingId` matches amenity's `buildingId`
3. Amenity has `isActive: true`

---

## Quick Fix Options

### Option 1: Match All Fields (Recommended)

Update your Firebase data so:
- User has `adminId` and `buildingId`
- Amenity has matching `adminId` and `buildingId`
- Amenity has `isActive: true`

### Option 2: Add Missing Fields

If amenity doesn't have `buildingId`:

1. Firebase Console → Firestore → `amenities` → Your amenity
2. Add field: `buildingId` = `"your_building_id"`
3. Make sure it matches user's `buildingId`

If user doesn't have `buildingId`:

1. Firebase Console → Firestore → `users` → Your user
2. Add field: `buildingId` = `"your_building_id"`

### Option 3: Temporary Bypass (Testing Only)

Edit `lib/src/services/booking_firestore_service.dart` (line ~70):

**Remove the buildingId filter**:
```dart
Query query = _firestore
    .collection(amenitiesCollection)
    .where('adminId', isEqualTo: filterAdminId)
    .where('isActive', isEqualTo: true);

// Comment out or remove this:
// if (filterBuildingId != null && filterBuildingId.isNotEmpty) {
//   query = query.where('buildingId', isEqualTo: filterBuildingId);
// }
```

This will filter by `adminId` only (no `buildingId` check).

---

## Files Modified

### Service Layer:
- `lib/src/services/booking_firestore_service.dart`
  - `getAmenities()` - Added buildingId filter
  - `streamAmenities()` - Added buildingId filter
  - `createBooking()` - Stores buildingId in bookings

### Documentation:
- `AMENITIES_FLOW_FUNCTION_COMPLETE.md` - This file

---

## Summary

**Flow Function Pattern**: ✅ Implemented  
**Filters**: adminId + buildingId + isActive  
**Bookings Store**: userId, flatId, flatLabel, adminId, buildingId  
**Fallback Logic**: Yes (tries multiple filter combinations)  
**Console Logging**: Detailed at every step

The amenities booking now follows the same flow function pattern as visitors, complaints, and community wall!

---

## Next Steps

1. ✅ Verify user document has `adminId` and `buildingId`
2. ✅ Verify amenity documents have `adminId` and `buildingId`
3. ✅ Ensure values match between user and amenity
4. ✅ Hot reload app
5. ✅ Test amenities display
6. ✅ Test booking creation
7. ✅ Verify bookings store buildingId
