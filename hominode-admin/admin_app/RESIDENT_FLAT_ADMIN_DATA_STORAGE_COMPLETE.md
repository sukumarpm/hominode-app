# Resident and Flat Admin Data Storage - Complete

## Overview
When a new resident is added or assigned to a flat, the system stores comprehensive admin details in both the `users` collection and the `flats` collection according to the flow function requirements.

## Data Storage Flow

### 1. When Creating a New Resident

**Location**: `lib/services/user_service.dart` → `createUser()` method

**Data Stored in `users` collection**:
```dart
{
  // Resident Basic Info
  'name': name,
  'phone': phone,
  'email': email ?? authEmail,
  'authEmail': authEmail,
  'password': password,
  'residentId': residentId, // e.g., "RES1234"
  'role': 'resident',
  
  // Flat Assignment (null initially if not assigned)
  'flatId': null,
  'flatLabel': null,
  'ownershipType': null,
  'familyMembers': familyMembers,
  'status': 'active',
  
  // Building Info (from admin profile or provided)
  'buildingId': buildingId,
  'buildingName': buildingName,
  
  // Admin Details (automatically added)
  'adminId': adminId,
  'adminName': adminProfile['name'],
  'adminEmail': adminProfile['email'],
  'adminPhone': adminProfile['phone'],
  'organization': adminProfile['organization'],
  
  // Timestamps
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  
  // Auth tracking
  'authAccountCreated': false,
}
```

**Key Points**:
- ✅ Admin details are automatically fetched from the logged-in admin's profile
- ✅ Building details can be provided or fetched from admin profile
- ✅ Resident is created in "unassigned" state (flatId = null)
- ✅ All admin contact information is stored for reference

### 2. When Assigning Resident to Flat

**Location**: `lib/services/user_service.dart` → `assignUserToFlat()` method

**Step 1: Update User Document**
```dart
// Update in users/{userId}
{
  'flatId': flatId,
  'flatLabel': flatLabel,
  'buildingId': buildingId, // Added if not already present
  'buildingName': buildingName, // Added if not already present
  'ownershipType': ownershipType,
  'updatedAt': FieldValue.serverTimestamp(),
}
```

**Step 2: Update Flat Document**
```dart
// Update in flats/{flatId}
{
  'residentId': residentId, // e.g., "RES1234"
  'residentName': residentName,
  'residentUserId': userId, // Firebase Auth UID
  'status': 'occupied',
  'ownershipType': ownershipType,
  'updatedAt': FieldValue.serverTimestamp(),
}
```

**Key Points**:
- ✅ Bidirectional sync: User gets flatId, Flat gets residentId
- ✅ Resident information stored in flat document
- ✅ Building details added to user if not already present
- ✅ Flat status automatically updated to 'occupied'

### 3. When Creating Flats for Building

**Location**: `lib/services/flat_service.dart` → `generateFlatsForBuilding()` method

**Data Stored in `flats` collection**:
```dart
{
  'id': docRef.id,
  'flatId': flatId, // e.g., "A101"
  'flatLabel': flatLabel,
  'buildingId': buildingId,
  'buildingName': buildingName,
  'floor': floor,
  'flatNumber': flatNum,
  'type': bhkType, // e.g., "2BHK"
  'bhkType': bhkType,
  'area': area, // e.g., "1200 Sqft"
  'status': 'vacant',
  'residentName': null,
  'residentId': null,
  
  // Admin Details (automatically added)
  'adminId': adminId,
  'adminName': adminData['name'],
  'adminEmail': adminData['email'],
  'adminPhone': adminData['phone'],
  'organization': adminData['organization'],
  
  // Timestamps
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}
```

**Key Points**:
- ✅ Admin details stored when flats are created
- ✅ Links flat to the admin who created it
- ✅ Flats start in 'vacant' status
- ✅ Resident fields are null until assignment

## Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ADMIN CREATES RESIDENT                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  1. Fetch Admin Profile (adminId, name, email, phone, org)  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Generate Resident ID (e.g., RES1234)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Create Document in users/{userId}                       │
│     - Resident basic info                                   │
│     - Admin details (adminId, adminName, adminEmail, etc.)  │
│     - Building details (buildingId, buildingName)           │
│     - flatId: null (unassigned)                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              ADMIN ASSIGNS RESIDENT TO FLAT                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Update users/{userId}                                   │
│     - flatId: flatId                                        │
│     - flatLabel: flatLabel                                  │
│     - buildingId: buildingId (if not present)               │
│     - buildingName: buildingName (if not present)           │
│     - ownershipType: ownershipType                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Update flats/{flatId}                                   │
│     - residentId: residentId                                │
│     - residentName: residentName                            │
│     - residentUserId: userId                                │
│     - status: 'occupied'                                    │
│     - ownershipType: ownershipType                          │
└─────────────────────────────────────────────────────────────┘
```

## Firestore Collections Structure

### users Collection
```
users/{userId}
  ├─ name: string
  ├─ phone: string
  ├─ email: string
  ├─ password: string
  ├─ residentId: string (e.g., "RES1234")
  ├─ role: "resident"
  ├─ flatId: string | null
  ├─ flatLabel: string | null
  ├─ buildingId: string | null
  ├─ buildingName: string | null
  ├─ ownershipType: string | null
  ├─ familyMembers: number
  ├─ status: "active" | "inactive"
  ├─ adminId: string ✅
  ├─ adminName: string ✅
  ├─ adminEmail: string ✅
  ├─ adminPhone: string ✅
  ├─ organization: string ✅
  ├─ createdAt: timestamp
  └─ updatedAt: timestamp
```

### flats Collection
```
flats/{flatId}
  ├─ id: string
  ├─ flatId: string (e.g., "A101")
  ├─ flatLabel: string
  ├─ buildingId: string
  ├─ buildingName: string
  ├─ floor: number
  ├─ flatNumber: number
  ├─ type: string (e.g., "2BHK")
  ├─ bhkType: string
  ├─ area: string
  ├─ status: "vacant" | "occupied" | "maintenance"
  ├─ residentId: string | null ✅
  ├─ residentName: string | null ✅
  ├─ residentUserId: string | null ✅
  ├─ ownershipType: string | null
  ├─ adminId: string ✅
  ├─ adminName: string ✅
  ├─ adminEmail: string ✅
  ├─ adminPhone: string ✅
  ├─ organization: string ✅
  ├─ createdAt: timestamp
  └─ updatedAt: timestamp
```

## Implementation Details

### UserService.createUser()
```dart
// Automatically fetches and stores admin details
final adminId = _adminService.getCurrentAdminId();
final adminProfile = await _adminService.getAdminProfile();

final firestoreData = {
  // ... resident data ...
  'adminId': adminId,
  'adminName': adminProfile?['name'] ?? '',
  'adminEmail': adminProfile?['email'] ?? '',
  'adminPhone': adminProfile?['phone'] ?? '',
  'organization': adminProfile?['organization'] ?? '',
  // ... timestamps ...
};
```

### UserService.assignUserToFlat()
```dart
// Updates user document
await _firestore.collection('users').doc(userId).update({
  'flatId': flatId,
  'flatLabel': flatLabel,
  'buildingId': finalBuildingId,
  'buildingName': finalBuildingName,
  'ownershipType': ownershipType,
  'updatedAt': FieldValue.serverTimestamp(),
});

// Updates flat document with resident info
await _firestore.collection('flats').doc(flatId).update({
  'residentId': residentId,
  'residentName': residentName,
  'residentUserId': userId,
  'status': 'occupied',
  'ownershipType': ownershipType,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### FlatService.generateFlatsForBuilding()
```dart
// Fetches admin details
final adminDoc = await _firestore.collection('admins').doc(adminId).get();
final adminData = adminDoc.data();

// Stores admin details with each flat
final flatData = {
  // ... flat data ...
  'adminId': adminId,
  'adminName': adminData['name'] ?? '',
  'adminEmail': adminData['email'] ?? '',
  'adminPhone': adminData['phone'] ?? '',
  'organization': adminData['organization'] ?? '',
  // ... timestamps ...
};
```

## Verification Steps

### 1. Verify Resident Creation
```dart
// After creating resident, check Firestore
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

print('Admin ID: ${userDoc.data()?['adminId']}');
print('Admin Name: ${userDoc.data()?['adminName']}');
print('Admin Email: ${userDoc.data()?['adminEmail']}');
print('Admin Phone: ${userDoc.data()?['adminPhone']}');
print('Organization: ${userDoc.data()?['organization']}');
print('Building ID: ${userDoc.data()?['buildingId']}');
print('Building Name: ${userDoc.data()?['buildingName']}');
```

### 2. Verify Flat Assignment
```dart
// After assigning resident to flat, check both documents
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

final flatDoc = await FirebaseFirestore.instance
    .collection('flats')
    .doc(flatId)
    .get();

// Check user document
print('User flatId: ${userDoc.data()?['flatId']}');
print('User flatLabel: ${userDoc.data()?['flatLabel']}');

// Check flat document
print('Flat residentId: ${flatDoc.data()?['residentId']}');
print('Flat residentName: ${flatDoc.data()?['residentName']}');
print('Flat status: ${flatDoc.data()?['status']}');
```

### 3. Verify Flat Creation
```dart
// After creating flats, check Firestore
final flatDoc = await FirebaseFirestore.instance
    .collection('flats')
    .doc(flatId)
    .get();

print('Admin ID: ${flatDoc.data()?['adminId']}');
print('Admin Name: ${flatDoc.data()?['adminName']}');
print('Admin Email: ${flatDoc.data()?['adminEmail']}');
print('Admin Phone: ${flatDoc.data()?['adminPhone']}');
print('Organization: ${flatDoc.data()?['organization']}');
```

## Summary

✅ **Resident Creation**: Stores adminId, adminName, adminEmail, adminPhone, organization, buildingId, buildingName
✅ **Flat Assignment**: Updates user with flatId/flatLabel, updates flat with residentId/residentName
✅ **Flat Creation**: Stores adminId, adminName, adminEmail, adminPhone, organization with each flat
✅ **Bidirectional Sync**: User and Flat documents are kept in sync
✅ **Complete Traceability**: Every resident and flat is linked to the admin who created it
✅ **Flow Function Compliance**: All required data is stored according to specifications

The system now properly stores all admin details and maintains complete data relationships between admins, residents, and flats!
