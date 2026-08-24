# Flat and Resident Data Synchronization - Complete

## Overview
Updated the system to ensure that when a resident is assigned to a flat, the flat document in the `flats` collection also stores the resident's information (`residentId` and `residentName`). This maintains data consistency across collections.

## Changes Made

### User Service (`lib/services/user_service.dart`)

#### 1. Updated `assignUserToFlat` Method

**Before:**
```dart
Future<void> assignUserToFlat({
  required String userId,
  required String flatId,
  required String flatLabel,
  required String ownershipType,
}) async {
  // Only updated user document
  await _firestore.collection('users').doc(userId).update({
    'flatId': flatId,
    'flatLabel': flatLabel,
    'ownershipType': ownershipType,
  });
}
```

**After:**
```dart
Future<void> assignUserToFlat({
  required String userId,
  required String flatId,
  required String flatLabel,
  required String ownershipType,
}) async {
  // Get user data first
  final userDoc = await _firestore.collection('users').doc(userId).get();
  final userData = userDoc.data()!;
  final residentId = userData['residentId'];
  final residentName = userData['name'];
  
  // Update user document
  await _firestore.collection('users').doc(userId).update({
    'flatId': flatId,
    'flatLabel': flatLabel,
    'ownershipType': ownershipType,
  });
  
  // Update flat document with resident information
  await _firestore.collection('flats').doc(flatId).update({
    'residentId': residentId,
    'residentName': residentName,
    'residentUserId': userId,
    'status': 'occupied',
    'ownershipType': ownershipType,
  });
}
```

#### 2. Updated `removeUserFromFlat` Method

**Before:**
```dart
Future<void> removeUserFromFlat(String userId) async {
  // Only updated user document
  await _firestore.collection('users').doc(userId).update({
    'flatId': null,
    'flatLabel': null,
    'ownershipType': null,
  });
}
```

**After:**
```dart
Future<void> removeUserFromFlat(String userId) async {
  // Get user data to find the flat
  final userDoc = await _firestore.collection('users').doc(userId).get();
  final flatId = userDoc.data()?['flatId'];
  
  // Update user document
  await _firestore.collection('users').doc(userId).update({
    'flatId': null,
    'flatLabel': null,
    'ownershipType': null,
  });
  
  // Update flat document to remove resident information
  if (flatId != null) {
    await _firestore.collection('flats').doc(flatId).update({
      'residentId': null,
      'residentName': null,
      'residentUserId': null,
      'status': 'vacant',
      'ownershipType': null,
    });
  }
}
```

## Data Flow

### Assign Resident to Flat
```
1. Admin assigns resident to flat
   ↓
2. System fetches resident data from 'users' collection
   - Gets residentId (e.g., "RES1234")
   - Gets residentName (e.g., "John Doe")
   ↓
3. Update 'users' collection
   - Set flatId
   - Set flatLabel
   - Set ownershipType
   ↓
4. Update 'flats' collection
   - Set residentId
   - Set residentName
   - Set residentUserId
   - Set status: 'occupied'
   - Set ownershipType
   ↓
5. Both collections now in sync ✅
```

### Remove Resident from Flat
```
1. Admin removes resident from flat
   ↓
2. System fetches user data to find flatId
   ↓
3. Update 'users' collection
   - Clear flatId
   - Clear flatLabel
   - Clear ownershipType
   ↓
4. Update 'flats' collection
   - Clear residentId
   - Clear residentName
   - Clear residentUserId
   - Set status: 'vacant'
   - Clear ownershipType
   ↓
5. Both collections now in sync ✅
```

## Firestore Structure

### Users Collection (Residents)
```
users/
  {userId}/
    name: "John Doe"
    residentId: "RES1234"
    phone: "+91 9876543210"
    email: "john@example.com"
    role: "resident"
    flatId: "flat123"  ← Links to flat
    flatLabel: "A-101"
    ownershipType: "owner"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    adminId: "{adminUid}"
    createdAt: Timestamp
    updatedAt: Timestamp
```

### Flats Collection
```
flats/
  {flatId}/
    label: "A-101"
    floor: 1
    flatNumber: "101"
    bhk: "2BHK"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    status: "occupied"  ← Updated when resident assigned
    residentId: "RES1234"  ← NEW: From resident
    residentName: "John Doe"  ← NEW: From resident
    residentUserId: "{userId}"  ← NEW: User document ID
    ownershipType: "owner"  ← NEW: From assignment
    createdAt: Timestamp
    updatedAt: Timestamp
```

## Benefits

1. **Data Consistency**: Flat and resident data always in sync
2. **Easy Queries**: Can query flats by residentId or residentName
3. **Quick Lookups**: No need to join collections to find resident info
4. **Status Tracking**: Flat status automatically updated (occupied/vacant)
5. **Audit Trail**: Both collections have updatedAt timestamps

## Testing

### Test 1: Assign Resident to Flat
1. Login as admin
2. Navigate to Flat Management
3. Select a vacant flat
4. Click "Assign Resident"
5. Select a resident
6. Choose ownership type (Owner/Tenant)
7. Submit
8. ✅ Verify in Firestore:
   - `users/{userId}` has flatId, flatLabel, ownershipType
   - `flats/{flatId}` has residentId, residentName, residentUserId, status='occupied'

### Test 2: Remove Resident from Flat
1. Login as admin
2. Navigate to Flat Management
3. Select an occupied flat
4. Click "Remove Resident"
5. Confirm
6. ✅ Verify in Firestore:
   - `users/{userId}` has flatId=null, flatLabel=null, ownershipType=null
   - `flats/{flatId}` has residentId=null, residentName=null, status='vacant'

### Test 3: View Flat Details
1. Login as admin
2. Navigate to Flat Management
3. Click on an occupied flat
4. ✅ Verify: Resident name and ID displayed correctly
5. ✅ Verify: Data matches what's in Firestore

## Fields Stored in Flats Collection

When a resident is assigned to a flat, the following fields are added/updated:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `residentId` | String | Unique resident identifier | "RES1234" |
| `residentName` | String | Full name of resident | "John Doe" |
| `residentUserId` | String | User document ID | "abc123xyz" |
| `status` | String | Occupancy status | "occupied" or "vacant" |
| `ownershipType` | String | Type of occupancy | "owner" or "tenant" |
| `updatedAt` | Timestamp | Last update time | Timestamp |

## Important Notes

- **Bidirectional Sync**: Both `users` and `flats` collections are updated
- **Atomic Operations**: Each assignment/removal updates both collections
- **Error Handling**: If one update fails, the error is thrown and logged
- **Data Integrity**: Always fetch latest user data before updating flat
- **Status Management**: Flat status automatically set based on assignment

## Future Enhancements

Consider adding:
1. Transaction support for atomic updates across collections
2. History tracking for resident assignments
3. Notification system when resident is assigned/removed
4. Validation to prevent double-assignment
5. Bulk assignment operations
