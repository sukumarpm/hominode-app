# Marketplace Phone Request - Error Fix ✅

## Error Message
```
User is not a member of this building
```

## Root Cause
The `requestPhoneNumber()` method was trying to fetch requester details from the **building members subcollection** (`buildings/{buildingId}/members/{userId}`), but:
- Not all users have a record in the building members subcollection
- Users are primarily stored in the `users` collection
- The building membership validation should check if the user's `buildingId` matches the listing's `buildingId`

## Solution Implemented

### Changed Data Source
**Before:**
```dart
// Tried to fetch from building members subcollection
final buildingMembersSnapshot = await _firestore
    .collection('buildings')
    .doc(buildingId)
    .collection('members')
    .doc(currentUserId)
    .get();

if (!buildingMembersSnapshot.exists) {
  return ServiceResult(
    success: false,
    message: 'User is not a member of this building',
  );
}
```

**After:**
```dart
// Fetch from users collection
final userDoc = await _usersCollection.doc(currentUserId).get();
final userData = userDoc.data() as Map<String, dynamic>?;

// Validate building membership by comparing buildingId
final requesterBuildingId = userData['buildingId'];
if (requesterBuildingId != buildingId) {
  return ServiceResult(
    success: false,
    message: 'You must be a member of this building to request phone number',
  );
}
```

## Updated Flow Function

### Step 1: Buyer Requests Phone
```dart
// Buyer clicks "Request Phone Number"
await _listingService.requestPhoneNumber(listingId);

// Service now:
// 1. Gets listing details (buildingId)
// 2. Gets buyer's user data from users collection
// 3. Validates buyer's buildingId == listing's buildingId
// 4. Creates request in: marketplaces/{productId}/requests
```

### Step 2: Validation Logic
- ✅ User must be authenticated
- ✅ Listing must exist
- ✅ User's `buildingId` must match listing's `buildingId`
- ✅ User must not have already requested from this listing

### Step 3: Request Creation
Request document contains:
```json
{
  "requesterId": "user123",
  "requesterName": "John Doe",
  "requesterFlat": "A-101",
  "requesterPhone": "+91-9876543210",
  "status": "pending",
  "createdAt": "2026-03-13T09:45:00Z"
}
```

## Data Sources Used

| Data | Source | Field |
|------|--------|-------|
| Requester Name | `users/{userId}` | `name` |
| Requester Flat | `users/{userId}` | `flatLabel` |
| Requester Phone | `users/{userId}` | `phone` |
| Building Validation | `users/{userId}` | `buildingId` |

## Error Scenarios Handled

### ✅ User Not Authenticated
```
Message: "User not authenticated"
```

### ✅ Listing Not Found
```
Message: "Listing not found"
```

### ✅ User Not in Same Building
```
Message: "You must be a member of this building to request phone number"
```

### ✅ Already Requested
```
Message: "You have already requested the phone number"
```

## Testing Checklist

- [ ] Buyer from same building can request phone
- [ ] Buyer from different building gets error
- [ ] Buyer cannot request twice from same listing
- [ ] Request shows buyer's name, flat, phone
- [ ] Seller can accept/reject request
- [ ] Buyer sees seller phone when accepted

## Files Modified

### `lib/src/services/listing_firestore_service.dart`
- Updated `requestPhoneNumber()` method
- Changed data source from building members to users collection
- Updated validation logic to check `buildingId` match

## Build Status
✅ No compilation errors
✅ All diagnostics passed
✅ Ready for testing

## Next Steps
1. Test with buyer from same building
2. Test with buyer from different building
3. Verify error message displays correctly
4. Test complete phone request flow
