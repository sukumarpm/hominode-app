# Flat Access Control - Quick Start Guide

## What Was Implemented

✅ **Access Control System** - Users without flatId cannot access app features
✅ **Real-Time Monitoring** - Automatic access updates when flatId changes
✅ **Clean UI** - Access blocked screen with clear messaging
✅ **Updated Services** - Bills now use flatId, amenities use buildingId

## How It Works

### User With Flat Assignment
```
User logs in → flatId exists → Access granted → Show app
```

### User Without Flat Assignment
```
User logs in → flatId is null → Access denied → Show blocked screen
```

### Real-Time Update
```
Admin assigns flat → Firestore updates → App detects change → Access granted automatically
```

## Testing

### Run Test Script
```bash
flutter run lib/test_flat_access_control.dart
```

### Test Scenarios

**1. Test User Without Flat**
- Create user in Firestore with `flatId: null`
- Log in with that user
- Should see: "Your account is not yet assigned to a flat"

**2. Test User With Flat**
- Create user in Firestore with `flatId: "A-101"`
- Log in with that user
- Should see: Dashboard and all features

**3. Test Real-Time Assignment**
- Log in as user without flat (blocked screen shown)
- In Firestore console, update user document: `flatId: "A-101"`
- App should automatically show dashboard (no refresh needed)

**4. Test Real-Time Removal**
- Log in as user with flat (dashboard shown)
- In Firestore console, update user document: `flatId: null`
- App should automatically show blocked screen (no refresh needed)

## Firestore Data Structure

### User Document (Required)
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "9876543210",
  "flatId": "A-101",           // ← REQUIRED for access
  "buildingId": "building_001", // ← REQUIRED for amenities
  "role": "resident",
  "status": "active"
}
```

### Bill Document (Updated)
```json
{
  "flatId": "A-101",      // ← Changed from residentId
  "amount": 5000,
  "month": "January 2024",
  "status": "pending",
  "dueDate": "2024-01-31"
}
```

### Amenity Document (Already Correct)
```json
{
  "name": "Swimming Pool",
  "buildingId": "building_001", // ← Used for filtering
  "isAvailable": true,          // ← Used for filtering
  "type": "Recreation",
  "isFree": false,
  "pricePerDay": 200
}
```

## Key Files

### Services
- `lib/src/services/flat_access_control_service.dart` - Access control logic
- `lib/src/services/bill_firestore_service.dart` - Updated to use flatId
- `lib/src/services/booking_firestore_service.dart` - Already uses buildingId

### UI
- `lib/src/screens/access_blocked_screen.dart` - Blocked screen
- `lib/src/widgets/flat_access_wrapper.dart` - Access wrapper widget
- `lib/main_navigation.dart` - Updated with wrapper

### Testing
- `lib/test_flat_access_control.dart` - Test script

## Quick Commands

### Run App
```bash
flutter run
```

### Run Test
```bash
flutter run lib/test_flat_access_control.dart
```

### Check Diagnostics
```bash
flutter analyze
```

## Common Issues

### Issue: User sees blocked screen but has flatId
**Solution:** Check that flatId is not empty string
```dart
// Good
flatId: "A-101"

// Bad (will block access)
flatId: ""
flatId: null
```

### Issue: Bills not showing
**Solution:** Ensure bills have flatId field matching user's flatId
```dart
// User document
flatId: "A-101"

// Bill document (must match)
flatId: "A-101"
```

### Issue: Amenities not showing
**Solution:** Ensure amenities have buildingId and isAvailable
```dart
// User document
buildingId: "building_001"

// Amenity document (must match)
buildingId: "building_001"
isAvailable: true
```

## Admin Workflow

### Assign Flat to User

1. Open Firestore Console
2. Navigate to `users` collection
3. Find user document
4. Add/Update fields:
   ```
   flatId: "A-101"
   buildingId: "building_001"
   ```
5. Save
6. User's app updates automatically (real-time)

### Remove Flat from User

1. Open Firestore Console
2. Navigate to `users` collection
3. Find user document
4. Update field:
   ```
   flatId: null
   ```
5. Save
6. User's app blocks access automatically (real-time)

## Data Queries

### Bills Query
```dart
// Before (residentId)
.where('residentId', isEqualTo: residentId)

// After (flatId)
.where('flatId', isEqualTo: flatId)
```

### Amenities Query
```dart
// Already correct
.where('isAvailable', isEqualTo: true)
.where('buildingId', isEqualTo: buildingId)
```

### Bookings Query
```dart
// Already correct
.where('userId', isEqualTo: userId)
```

## Real-Time Streams

All data uses StreamBuilder for automatic updates:

```dart
// Bills
StreamBuilder<List<Map<String, dynamic>>>(
  stream: billService.streamBills(),
  builder: (context, snapshot) { ... }
)

// Amenities
StreamBuilder<List<AmenityModel>>(
  stream: bookingService.streamAmenitiesRealtime(),
  builder: (context, snapshot) { ... }
)

// Access Control
StreamBuilder<AccessControlResult>(
  stream: accessService.streamFlatAccess(),
  builder: (context, snapshot) { ... }
)
```

## Performance

### Caching
- Access control result is cached
- Cache clears on user document changes
- Reduces Firestore reads

### Server-Side Filtering
- All queries use `.where()` for server-side filtering
- No client-side filtering needed
- Reduces data transfer

### Real-Time Updates
- Uses Firestore snapshots (not polling)
- Efficient real-time synchronization
- Automatic UI updates

## Security

### Firestore Rules (Recommended)
```javascript
// Users can only read their own document
match /users/{userId} {
  allow read: if request.auth.uid == userId;
}

// Bills - only for user's flat
match /bills/{billId} {
  allow read: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.flatId == resource.data.flatId;
}

// Amenities - only for user's building
match /amenities/{amenityId} {
  allow read: if request.auth != null && 
    resource.data.isAvailable == true &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.buildingId == resource.data.buildingId;
}
```

## Summary

✅ **Access Control** - Enforced based on flatId
✅ **Real-Time** - Automatic updates when data changes
✅ **Clean Code** - Production-ready implementation
✅ **Good UX** - Clear messaging and smooth transitions
✅ **Secure** - Server-side filtering and validation

The app now has comprehensive flat-based access control with real-time monitoring and a clean user experience.
