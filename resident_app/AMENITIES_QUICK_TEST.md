# 🚀 Quick Test Guide - Amenities Fetch Fix

## What Was Fixed

The amenities booking screen now properly fetches data from Firestore following the flow function pattern with field validation.

---

## Quick Test (3 Steps)

### Step 1: Run Diagnostic Test
```bash
flutter run lib/test_amenities_fix.dart
```

This will show:
- ✅ Your user data (adminId, buildingId)
- ✅ Amenities fetched from Firestore
- ✅ Field validation results
- ⚠️ Any missing data or mismatches

### Step 2: Hot Reload App
```bash
# In your running app terminal, press:
r
```

### Step 3: Test in App
1. Navigate to "Amenities Booking" screen
2. Tap the refresh button (↻) in the top right
3. Check console logs for detailed output
4. Verify amenities display in the grid

---

## Expected Console Output

When amenities load successfully:

```
📥 Fetching amenities from Firestore (Flow Function)...
✅ User logged in: abc123
📋 User data fields: [name, email, role, adminId, buildingId, flatId, flatLabel]
👤 User role: resident
🔑 User adminId: admin_xyz
🏢 User buildingId: building_123
🔍 Querying amenities:
   adminId: admin_xyz
   buildingId: building_123
   isActive: true
   ✅ Added buildingId filter
📊 Query returned 2 documents
  📍 Swimming Pool (adminId: admin_xyz, buildingId: building_123)
  📍 Gym (adminId: admin_xyz, buildingId: building_123)
✅ Fetched 2 amenities (adminId + buildingId filter)
```

---

## If No Amenities Show

### Check 1: Verify User Data
```
Firebase Console → Firestore → users → [your_user_id]
```

Required fields:
- ✅ `adminId`: "some_admin_id"
- ✅ `buildingId`: "some_building_id"
- ✅ `role`: "resident" or "admin"

### Check 2: Verify Amenity Data
```
Firebase Console → Firestore → amenities → [amenity_id]
```

Required fields:
- ✅ `name`: "Swimming Pool"
- ✅ `adminId`: "some_admin_id" (must match user's adminId)
- ✅ `buildingId`: "some_building_id" (must match user's buildingId)
- ✅ `isActive`: true

### Check 3: Match Values
```
user.adminId == amenity.adminId
AND
user.buildingId == amenity.buildingId
```

If these don't match, amenities won't show!

---

## Quick Fix Options

### Option 1: Add Missing Fields to User
```
Firebase Console → Firestore → users → [user_id]
Click "Add field"
- Field: adminId
- Value: "your_admin_id"

Click "Add field"
- Field: buildingId
- Value: "your_building_id"
```

### Option 2: Add Missing Fields to Amenity
```
Firebase Console → Firestore → amenities → [amenity_id]
Click "Add field"
- Field: adminId
- Value: "your_admin_id" (same as user's adminId)

Click "Add field"
- Field: buildingId
- Value: "your_building_id" (same as user's buildingId)

Click "Add field"
- Field: isActive
- Value: true
```

### Option 3: Create Test Amenity
```
Firebase Console → Firestore → amenities → Add document

Document ID: (auto-generate)

Fields:
- name: "Swimming Pool"
- price: "₹500/hour"
- adminId: "your_admin_id" (copy from user document)
- buildingId: "your_building_id" (copy from user document)
- isActive: true
- iconName: "pool"
- backgroundColor: "#D6EBFF"
- iconColor: "#0A64FF"
- openTime: "6:00 AM"
- closeTime: "8:00 PM"
```

---

## Console Log Meanings

| Log Message | Meaning |
|-------------|---------|
| ✅ User logged in | Authentication successful |
| 🔑 User adminId: xyz | User's admin ID found |
| 🏢 User buildingId: 123 | User's building ID found |
| 📊 Query returned X documents | Found X amenities matching filters |
| ✅ Fetched X amenities | Successfully loaded amenities |
| ⚠️ No amenities found | No matches with current filters |
| ❌ Error fetching amenities | Technical error occurred |

---

## Fallback Logic

The service tries 3 levels:

1. **Level 1**: adminId + buildingId + isActive
2. **Level 2**: adminId + isActive (if Level 1 fails)
3. **Level 3**: isActive only (if Level 2 fails)

This ensures you see amenities if they exist!

---

## Field Defaults

If Firestore data is missing fields, the service provides defaults:

| Field | Default Value |
|-------|---------------|
| name | "Unknown Amenity" |
| price | "Free" |
| isAvailable | true |
| iconName | "apartment" |
| backgroundColor | "#D6EBFF" |
| iconColor | "#0A64FF" |
| openTime | "6:00 AM" |
| closeTime | "8:00 PM" |

---

## Test Booking Flow

After amenities display:

1. Tap an amenity card (e.g., "Swimming Pool")
2. Select a date from the calendar
3. Select a time slot
4. Click "Confirm Booking"
5. Verify booking appears in "My Bookings" section
6. Test "Cancel Booking" button

---

## Files Changed

1. ✅ `lib/src/services/booking_firestore_service.dart`
   - Added field validation
   - Ensures all required fields exist

2. ✅ `lib/test_amenities_fix.dart`
   - Diagnostic test script

3. ✅ `AMENITIES_FETCH_FIX_COMPLETE.md`
   - Detailed documentation

4. ✅ `AMENITIES_QUICK_TEST.md`
   - This quick guide

---

## Summary

The fix ensures:
- ✅ Proper flow function filtering (adminId + buildingId)
- ✅ All required fields have defaults
- ✅ Graceful fallback logic
- ✅ Detailed console logging
- ✅ Error handling

Run the diagnostic test, check the console logs, and verify your Firestore data matches the expected structure!
