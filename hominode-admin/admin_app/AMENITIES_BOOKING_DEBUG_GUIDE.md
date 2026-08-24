# Amenities Booking Debug Guide

## Current Issue
Bookings exist in Firestore but not displaying in the app.

## Debug Changes Applied

### 1. Removed Query Filters (Temporary)
Changed from filtered query to fetch ALL bookings:
```dart
// Fetches ALL bookings without filters
final snapshot = await _firestore.collection(_bookingsCollection).get();
```

### 2. Added Comprehensive Logging
Every step now logs to console:
- Current admin ID
- Total bookings found
- Each booking's adminId, date, and amenity name
- Date parsing results
- Filtering results
- Final grouped bookings count

### 3. Manual Filtering
Filters applied in code (not in query) to see what's being filtered out:
```dart
if (adminId != null && data['adminId'] != adminId) {
  print('Skipping booking - adminId mismatch');
  continue;
}
```

## How to Debug

### Step 1: Run the App
Open Amenities Management → Bookings tab

### Step 2: Check Console Output
Look for these log messages:

```
AmenityService: Current admin ID: [your-admin-id]
AmenityService: Total bookings in Firestore: X
AmenityService: Booking [id] - adminId: [id], date: [date], amenity: [name]
```

### Step 3: Identify the Issue

#### Issue A: No Bookings Found
```
AmenityService: Total bookings in Firestore: 0
```
**Solution**: Check Firestore rules, collection name, or Firebase connection

#### Issue B: AdminId Mismatch
```
AmenityService: Skipping booking - adminId mismatch (abc != xyz)
```
**Solution**: The booking's adminId doesn't match logged-in admin

#### Issue C: Date Parsing Error
```
AmenityService ERROR: Error parsing date string
```
**Solution**: Date format issue in Firestore

#### Issue D: Date Out of Range
```
AmenityService: Booking date X is outside range Y to Z
```
**Solution**: Calendar showing wrong month or date range issue

### Step 4: Verify AdminId

Check what adminId is in the booking vs what admin is logged in:

**From Console**:
```
AmenityService: Current admin ID: gMt4eleC7EjwcDakSTjf
AmenityService: Booking xaz... - adminId: DIFFERENT_ID
```

If they don't match, the booking won't show.

### Step 5: Verify Date Field

Check if Firestore has `date` field as Timestamp:
```
AmenityService: Parsed date from Timestamp: 2026-02-26
```

If you see errors, the date field might be missing or wrong type.

## Expected Console Output (Working)

```
AmenityService: Current admin ID: gMt4eleC7EjwcDakSTjf
AmenityService: Date range: 2026-02-01 to 2026-02-28
AmenityService: Fetching ALL bookings from collection...
AmenityService: Total bookings in Firestore: 1
AmenityService: Booking xazFgNh5jyEuG28oWr3 - adminId: gMt4eleC7EjwcDakSTjf, date: Timestamp(...), amenity: swimming pool
AmenityService: Processing booking xazFgNh5jyEuG28oWr3
AmenityBookingModel.fromFirestore - ID: xazFgNh5jyEuG28oWr3
AmenityBookingModel.fromFirestore - Data keys: [amenityId, amenityName, buildingId, date, flatId, flatLabel, status, timeSlot, updatedAt, userEmail, userId, userName, adminId]
AmenityBookingModel: Parsed date from Timestamp: 2026-02-26
AmenityService: Parsed date from Timestamp: 2026-02-26 00:00:00.000
AmenityService: Normalized date: 2026-02-26 00:00:00.000
AmenityService: Grouped bookings by 1 dates
AmenityService: 2026-02-26 00:00:00.000: 1 bookings
```

## Common Issues & Solutions

### Issue: AdminId is null
```
AmenityService: Current admin ID: null
```
**Solution**: Admin not logged in or AdminService not working

### Issue: Wrong AdminId
Booking has different adminId than logged-in admin
**Solution**: 
1. Check if booking was created with correct adminId
2. Verify admin login is working
3. Check if using correct admin account

### Issue: Collection Empty
```
AmenityService: Total bookings in Firestore: 0
```
**Solution**:
1. Verify collection name is "bookings"
2. Check Firestore rules allow read access
3. Verify bookings exist in Firebase Console

### Issue: Date Field Missing
```
AmenityService ERROR: Could not determine date for booking
```
**Solution**: Booking document missing `date` field in Firestore

## Next Steps After Debug

Once you identify the issue from console logs:

1. **If adminId mismatch**: Update booking documents with correct adminId
2. **If date parsing fails**: Fix date field format in Firestore
3. **If no bookings found**: Check Firestore rules and collection name
4. **If everything logs correctly but still not showing**: Check UI rendering logic

## Restore Production Query

After debugging, restore the optimized query:
```dart
final snapshot = await _firestore
    .collection(_bookingsCollection)
    .where('adminId', isEqualTo: adminId)
    .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
    .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
    .get();
```
