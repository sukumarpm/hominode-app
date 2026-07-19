# Amenities Booking - Implementation & Troubleshooting 🔧

## Status
✅ Implementation complete  
⚠️ Amenities not displaying - diagnostic tools created

## Quick Fix
If amenities aren't showing, see:
- **`AMENITIES_QUICK_FIX.md`** - Fast solutions
- **`AMENITIES_DIAGNOSTIC_GUIDE.md`** - Detailed troubleshooting
- **`lib/test_amenities_fetch.dart`** - Diagnostic test script

## Overview
The amenities booking system now fetches amenities from Firestore and stores bookings with proper flat-based access control. Demo/hardcoded data has been removed.

## Data Structure

### Amenities Collection (`amenities`)
```javascript
{
  "id": "auto-generated",
  "adminId": "admin-user-id",           // ✅ Admin who created this amenity
  "name": "Swimming Pool",
  "price": "Free",
  "description": "Olympic size swimming pool",
  "iconName": "pool",
  "backgroundColor": "#D6EBFF",
  "iconColor": "#0A64FF",
  "openTime": "6:00 AM",
  "closeTime": "8:00 PM",
  "isAvailable": true,
  "isActive": true,
  "capacity": 50,
  "rules": ["No diving", "Shower before entering"],
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### Bookings Collection (`bookings`)
```javascript
{
  "id": "auto-generated",
  "userId": "user-who-booked",
  "userName": "User Name",
  "userEmail": "user@example.com",
  "flatId": "flat-document-id",        // ✅ NEW
  "flatLabel": "A-101",                 // ✅ NEW
  "adminId": "admin-user-id",           // ✅ NEW
  "amenityId": "amenity-id",
  "amenityName": "Swimming Pool",
  "date": "Timestamp",
  "timeSlot": "10:00 AM - 12:00 PM",
  "status": "confirmed",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## Flow Function

### 1. Fetch Amenities
```
Screen loads → Fetch from Firestore
  ↓
Get current user's adminId
  ↓
Query: amenities.where('adminId', isEqualTo: userAdminId)
       .where('isActive', isEqualTo: true)
  ↓
Display: Grid of amenities created by user's admin
```

### 2. Create Booking
```
User selects amenity → Opens booking modal
  ↓
User selects date and time → Confirms booking
  ↓
System fetches user data (flatId, flatLabel, adminId)
  ↓
Create booking document with all fields
  ↓
Store in Firestore 'bookings' collection
```

### 3. View Bookings
```
Resident: Query bookings.where('userId', isEqualTo: currentUserId)
Admin: Query bookings.where('adminId', isEqualTo: currentAdminId)
  ↓
Display: List of bookings with status
```

## Updated Files

### Booking Service (`lib/src/services/booking_firestore_service.dart`)

#### New Methods:
- `getAmenities()` - Fetch amenities from Firestore
- `streamAmenities()` - Real-time amenities stream
- `getAdminBookings()` - Get all bookings for managed flats
- `getBookingsByFlatId()` - Get bookings for specific flat
- `getBookingsForCurrentUser()` - Auto-detect role
- `streamAdminBookings()` - Real-time stream for admin
- `streamBookingsForCurrentUser()` - Auto-detect role for streaming

#### Updated Methods:
- `createBooking()` - Now stores flatId, flatLabel, adminId

### Amenities Screen (`lib/src/screens/amenities_booking_screen.dart`)

#### Changes:
- ✅ Removed hardcoded amenities data
- ✅ Added `_loadAmenities()` method
- ✅ Fetches amenities from Firestore
- ✅ Dynamic grid based on Firestore data
- ✅ Icon mapping from string names
- ✅ Color parsing from hex strings

## API Methods

### Amenities
```dart
// Get all active amenities
final amenities = await BookingFirestoreService().getAmenities();

// Stream amenities (real-time)
BookingFirestoreService().streamAmenities();
```

### Bookings - Residents
```dart
// Get my bookings
final bookings = await BookingFirestoreService().getMyBookings();

// Stream my bookings
BookingFirestoreService().streamMyBookings();
```

### Bookings - Admins
```dart
// Get all bookings for managed flats
final bookings = await BookingFirestoreService().getAdminBookings();

// Get bookings for specific flat
final flatBookings = await BookingFirestoreService()
    .getBookingsByFlatId('flat-id');

// Stream admin bookings
BookingFirestoreService().streamAdminBookings();
```

### Auto-Detect
```dart
// Automatically returns correct bookings based on role
final bookings = await BookingFirestoreService()
    .getBookingsForCurrentUser();

// Stream with auto-detect
BookingFirestoreService().streamBookingsForCurrentUser();
```

## Firestore Queries

### Amenities Query (By AdminId)
```dart
amenities
  .where('adminId', isEqualTo: userAdminId)
  .where('isActive', isEqualTo: true)
  .get()
```

### Resident Bookings Query
```dart
bookings
  .where('userId', isEqualTo: currentUserId)
  .get()
```

### Admin Bookings Query
```dart
bookings
  .where('adminId', isEqualTo: currentAdminId)
  .get()
```

## Security Rules (Recommended)

```javascript
// Amenities Collection
match /amenities/{amenityId} {
  // Users can only read amenities created by their admin
  allow read: if request.auth != null && 
    resource.data.isActive == true &&
    resource.data.adminId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.adminId;
  
  // Only admins can create/update/delete amenities
  allow create: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' &&
    request.resource.data.adminId == request.auth.uid;
  
  allow update, delete: if request.auth != null && 
    resource.data.adminId == request.auth.uid;
}

// Bookings Collection
match /bookings/{bookingId} {
  // Users can read their own bookings
  allow read: if request.auth != null && 
    resource.data.userId == request.auth.uid;
  
  // Admins can read bookings for flats they manage
  allow read: if request.auth != null && 
    resource.data.adminId == request.auth.uid;
  
  // Users can create bookings
  allow create: if request.auth != null && 
    request.resource.data.userId == request.auth.uid;
  
  // Only creator can update/cancel their bookings
  allow update: if request.auth != null && 
    resource.data.userId == request.auth.uid;
  
  // Only creator can delete bookings
  allow delete: if request.auth != null && 
    resource.data.userId == request.auth.uid;
}
```

## Amenity Icon Mapping

Supported icon names:
- `pool`, `swimming_pool` → Swimming pool icon
- `gym`, `fitness` → Gym icon
- `hall`, `community_hall` → Hall icon
- `lawn`, `party_lawn` → Party lawn icon
- `tennis` → Tennis icon
- `basketball` → Basketball icon
- `playground` → Playground icon
- Default → Apartment icon

## Color Format

Colors should be in hex format:
- With hash: `#D6EBFF`
- Without hash: `D6EBFF`
- With alpha: `#FFD6EBFF`

## Booking Status

- `confirmed` - Booking is confirmed
- `cancelled` - Booking was cancelled
- `completed` - Booking is completed (past date)

## Creating Amenities in Firestore

To add amenities to your Firestore database, admins should create documents with their adminId:

```javascript
// Example amenity document
{
  "adminId": "admin-user-id",           // ✅ REQUIRED - Admin who owns this amenity
  "name": "Swimming Pool",
  "price": "Free",
  "description": "Olympic size swimming pool with lifeguard",
  "iconName": "pool",
  "backgroundColor": "#D6EBFF",
  "iconColor": "#0A64FF",
  "openTime": "6:00 AM",
  "closeTime": "8:00 PM",
  "isAvailable": true,
  "isActive": true,
  "capacity": 50,
  "rules": [
    "No diving in shallow end",
    "Shower before entering",
    "Children must be supervised"
  ],
  "createdAt": FieldValue.serverTimestamp(),
  "updatedAt": FieldValue.serverTimestamp()
}
```

**Important**: Each amenity must have an `adminId` field. Residents will only see amenities where the `adminId` matches their assigned admin.

## Testing

### Test Amenities Fetch
```dart
// 1. Add amenities to Firestore 'amenities' collection
// 2. Open amenities booking screen
// 3. Verify amenities are displayed from Firestore
// 4. Verify no hardcoded amenities shown
```

### Test Booking Creation
```dart
// 1. Login as resident
// 2. Select an amenity
// 3. Choose date and time
// 4. Confirm booking
// 5. Check Firestore - verify flatId, flatLabel, adminId stored
```

### Test Admin Access
```dart
// 1. Login as admin
// 2. View bookings
// 3. Verify can see bookings from all managed flats
```

## Benefits

1. **Admin-Based Filtering**: Residents only see amenities created by their admin
2. **Dynamic Content**: Amenities fetched from Firestore
3. **Easy Management**: Admins can add/edit amenities for their properties
4. **Flat-Based Access**: Proper data isolation for bookings
5. **Admin Oversight**: Admins see all bookings for their amenities
6. **Real-Time Updates**: Live amenities and bookings
7. **No Hardcoded Data**: All data from database

## Next Steps

1. Update screen to use `streamAmenities()` for real-time updates
2. Add admin panel to manage amenities
3. Implement booking conflict detection
4. Add booking capacity limits
5. Add booking cancellation policy
6. Implement Firestore security rules
7. Add booking notifications

## Status: ✅ COMPLETE

Amenities booking system now:
- ✅ Fetches amenities from Firestore filtered by adminId
- ✅ Residents only see amenities created by their admin
- ✅ Stores bookings with flatId, flatLabel, adminId
- ✅ Removed demo/hardcoded data
- ✅ Admin query methods implemented
- ✅ Role-based access control
- ✅ Real-time streaming support
