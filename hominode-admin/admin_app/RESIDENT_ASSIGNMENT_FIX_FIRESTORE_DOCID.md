# Resident Assignment Error Fix - Firestore Document ID Issue

## Problem
When assigning a resident to a flat, the app was throwing:
```
Failed to assign resident: [cloud_firestore/not-found] Some requested document was not found
```

## Root Cause
The code was using the **sequential flat ID** (e.g., "T001", "A101") as the Firestore document ID when updating the flat document. However, flats are stored with **auto-generated Firestore document IDs**, and the sequential ID is just a field within the document.

### Data Structure
```
Firestore Collection: flats
├── Document ID: "abc123xyz" (auto-generated)
│   ├── flatId: "T001" (sequential ID)
│   ├── flatLabel: "T001"
│   ├── buildingId: "..."
│   └── ...
```

## Solution
Added the Firestore document ID (`docId`) to the `FlatUnit` model and passed it through the assignment flow:

### Changes Made

#### 1. Updated FlatUnit Model (flat_occupancy_grid_modal.dart)
```dart
class FlatUnit {
  final String id;        // Sequential ID (T001, A101, etc.)
  final String docId;     // Firestore document ID (NEW)
  final String type;
  // ...
}
```

#### 2. Updated FlatUnit Model (flat_models.dart)
```dart
class FlatUnit {
  final String id;        // Sequential ID (e.g., "A101")
  final String docId;     // Firestore document ID (NEW)
  final int floor;
  // ...
}
```

#### 3. Updated FlatUnit Creation (manage_buildings_page.dart)
```dart
FlatUnit(
  id: flat.flatId ?? flat.id,      // Sequential ID
  docId: flat.id,                  // Firestore document ID
  type: flat.type,
  // ...
)
```

#### 4. Updated Assignment Flow (flat_details_modal.dart)
```dart
// Assign user to flat (uses sequential ID)
await widget.userService!.assignUserToFlat(
  userId: user.id,
  flatId: request.flatId,          // Sequential ID (T001)
  flatLabel: widget.unit.id,
  // ...
);

// Update flat document (uses Firestore document ID)
await widget.flatService!.assignResident(
  flatId: widget.unit.docId,       // Firestore document ID
  residentName: user.name,
  residentId: user.id,
);
```

#### 5. Updated assignUserToFlat (user_service.dart)
Now queries for the flat using the sequential ID field:
```dart
// Query for the flat document using flatId field
final flatQuery = await _firestore
    .collection('flats')
    .where('flatId', isEqualTo: flatId)
    .limit(1)
    .get();

if (flatQuery.docs.isEmpty) {
  throw Exception('Flat not found. Please ensure the flat exists in the system.');
}

final flatDocRef = flatQuery.docs.first.reference;
// Use flatDocRef for updates
```

## Flow Function: Assign Resident to Flat

### STEP 1: Get User Data
- Fetch user document from `users` collection using userId

### STEP 2: Query for Flat Document
- Query `flats` collection where `flatId` field equals the sequential ID
- Get the Firestore document reference

### STEP 3: Update User Document
- Update user with `flatId`, `flatLabel`, `buildingId`, `buildingName`, `ownershipType`

### STEP 4: Update Flat Document
- Update flat with `residentId`, `residentName`, `residentUserId`, `status: 'occupied'`
- Uses the Firestore document reference from STEP 2

### STEP 5: Sync Building Occupancy
- Update building occupancy stats

## Testing
1. Create a building with flats
2. Create a resident
3. Click "Assign Resident" on a vacant flat
4. Select a resident and click "Assign Resident"
5. Verify the resident is assigned successfully

## Key Takeaway
Always distinguish between:
- **Sequential ID** (flatId): User-friendly identifier like "T001", "A101"
- **Firestore Document ID**: Auto-generated unique identifier for the document

When updating Firestore documents, use the actual document ID, not the sequential ID.
