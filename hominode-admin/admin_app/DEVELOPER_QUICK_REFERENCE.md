# Developer Quick Reference Card

## Core Services Overview

### AdminService
**Purpose**: Manage admin authentication and data access
**Key Methods**:
- `getCurrentAdminId()` - Get logged-in admin's UID
- `getAdminProfile()` - Fetch admin profile from Firestore
- `getAdminBuildingIds()` - Get list of building IDs for admin
- `getAdminBuildings()` - Get full building documents

**Collection**: `admins`
**Document ID**: Firebase Auth UID

---

### BuildingService
**Purpose**: Manage buildings and occupancy
**Key Methods**:
- `addBuilding()` - Create new building with flats
- `updateBuilding()` - Update building details
- `deleteBuilding()` - Delete building and cascade
- `updateOccupancy()` - Update occupancy stats
- `syncOccupancyFromFlats()` - Sync occupancy from flats

**Collection**: `buildings`
**Document ID**: Auto-generated
**Key Fields**: `adminId`, `buildingId`, `buildingName`, `occupied`, `vacant`

---

### FlatService
**Purpose**: Manage flats and resident assignments
**Key Methods**:
- `generateFlatsForBuilding()` - Generate flats for building
- `updateFlatStatus()` - Update flat status (vacant/occupied)
- `assignResident()` - Assign resident to flat
- `removeResident()` - Remove resident from flat
- `getOccupancyStats()` - Get occupancy statistics

**Collection**: `flats`
**Document ID**: Auto-generated
**Key Fields**: `flatId` (sequential), `buildingId`, `status`, `residentId`

---

### ResidentService
**Purpose**: Manage residents and assignments
**Key Methods**:
- `createResident()` - Create new resident with Firebase Auth
- `assignResidentToFlat()` - Assign resident to flat
- `getResidents()` - Get all residents for admin (stream)
- `getResidentByUid()` - Get resident by UID
- `generateResidentId()` - Generate unique resident ID

**Collection**: `users`
**Document ID**: Firebase Auth UID
**Key Fields**: `uid`, `residentId`, `adminId`, `flatId`, `buildingId`

---

## Data Flow Diagrams

### Admin Login Flow
```
Admin Login Screen
    ↓
Firebase Auth.signInWithEmailAndPassword()
    ↓
Firebase Auth UID obtained
    ↓
AdminService.getAdminProfile()
    ↓
Fetch from admins/{uid}
    ↓
Dashboard loads with admin's buildings
```

### Building Creation Flow
```
Add Building Modal
    ↓
BuildingService.addBuilding()
    ↓
Create document in buildings collection
    ↓
Update document with buildingId and buildingName
    ↓
Add building to admin's document in admins collection
    ↓
FlatService.generateFlatsForBuilding()
    ↓
Create flats in batch operation
    ↓
Verify all flats created
    ↓
Return to dashboard
```

### Resident Creation Flow
```
Add Resident Modal
    ↓
ResidentService.createResident()
    ↓
Get admin details from AdminService
    ↓
Create Firebase Auth user
    ↓
Get UID from Firebase
    ↓
Create Firestore document in users/{uid}
    ↓
Verify document created
    ↓
Sign out new user
    ↓
Admin re-authenticates
    ↓
Return to residents list
```

### Resident Assignment Flow
```
Flat Management Screen
    ↓
Select resident and flat
    ↓
ResidentService.assignResidentToFlat()
    ↓
Update users/{uid} with flatId
    ↓
Update flats/{flatId} with residentId
    ↓
Verify both updates
    ↓
BuildingService.updateOccupancy()
    ↓
Update building occupancy stats
    ↓
Return to flat management
```

---

## Firestore Collections Reference

### admins Collection
```
admins/{uid}
├── uid: string
├── name: string
├── email: string
├── phone: string
├── role: "admin"
├── organization: string
├── buildingIds: array
├── buildings: array
├── buildingNames: array
├── createdAt: timestamp
└── updatedAt: timestamp
```

### buildings Collection
```
buildings/{buildingId}
├── buildingId: string
├── buildingName: string
├── name: string
├── floors: number
├── flatsPerFloor: number
├── totalFlats: number
├── occupied: number
├── vacant: number
├── occupancyRate: number
├── adminId: string
├── adminName: string
├── adminEmail: string
├── adminPhone: string
├── organization: string
├── createdAt: timestamp
└── updatedAt: timestamp
```

### flats Collection
```
flats/{flatDocId}
├── id: string
├── flatId: string (sequential: A001, A002)
├── flatLabel: string
├── buildingId: string
├── buildingName: string
├── floor: number
├── flatNumber: number
├── type: string (BHK)
├── bhkType: string
├── area: string
├── status: string (vacant/occupied/maintenance)
├── residentName: string
├── residentId: string
├── residentUserId: string
├── adminId: string
├── adminName: string
├── adminEmail: string
├── adminPhone: string
├── organization: string
├── createdAt: timestamp
└── updatedAt: timestamp
```

### users Collection
```
users/{uid}
├── uid: string
├── residentId: string (RES1234)
├── name: string
├── email: string
├── phone: string
├── role: "resident"
├── flatId: string (null if unassigned)
├── flatLabel: string (null if unassigned)
├── buildingId: string
├── buildingName: string
├── ownershipType: string
├── familyMembers: number
├── status: string (active/inactive)
├── organization: string
├── adminEmail: string
├── adminName: string
├── adminPhone: string
├── adminId: string
├── createdAt: timestamp
└── updatedAt: timestamp
```

---

## Common Code Patterns

### Get Current Admin ID
```dart
final adminService = AdminService();
final adminId = adminService.getCurrentAdminId();
if (adminId == null) {
  print('Admin not logged in');
  return;
}
```

### Fetch Admin Profile
```dart
final adminService = AdminService();
final profile = await adminService.getAdminProfile();
if (profile != null) {
  print('Admin: ${profile['name']}');
  print('Email: ${profile['email']}');
}
```

### Create Building
```dart
final buildingService = BuildingService();
try {
  final buildingId = await buildingService.addBuilding(
    name: 'Tower A',
    floors: 5,
    flatsPerFloor: 4,
    totalFlats: 20,
    flatBhkConfig: {
      'A001': '2BHK',
      'A002': '2BHK',
      // ... more flats
    },
  );
  print('Building created: $buildingId');
} catch (e) {
  print('Error: $e');
}
```

### Create Resident
```dart
final residentService = ResidentService();
try {
  final uid = await residentService.createResident(
    name: 'John Doe',
    email: 'john@example.com',
    phone: '9876543210',
    password: 'password123',
    buildingId: 'building123',
    buildingName: 'Tower A',
  );
  print('Resident created: $uid');
} catch (e) {
  print('Error: $e');
}
```

### Assign Resident to Flat
```dart
final residentService = ResidentService();
try {
  await residentService.assignResidentToFlat(
    residentUid: 'uid123',
    flatId: 'flat123',
    flatLabel: 'A001',
    buildingId: 'building123',
    buildingName: 'Tower A',
  );
  print('Resident assigned successfully');
} catch (e) {
  print('Error: $e');
}
```

### Get Buildings Stream
```dart
final buildingService = BuildingService();
buildingService.getBuildings().listen((buildings) {
  print('Buildings: ${buildings.length}');
  for (var building in buildings) {
    print('- ${building.name} (${building.occupied}/${building.totalFlats})');
  }
});
```

### Get Residents Stream
```dart
final residentService = ResidentService();
residentService.getResidents().listen((residents) {
  print('Residents: ${residents.length}');
  for (var resident in residents) {
    print('- ${resident.name} (${resident.flatLabel ?? "Unassigned"})');
  }
});
```

---

## Error Handling Patterns

### Try-Catch with Rollback
```dart
try {
  // Step 1: Do something
  await operation1();
  
  // Step 2: Do something else
  await operation2();
  
  // Step 3: Verify
  await verify();
  
} catch (e) {
  print('Error: $e');
  
  // Rollback
  try {
    await rollback();
  } catch (rollbackError) {
    print('Rollback failed: $rollbackError');
  }
  
  rethrow;
}
```

### Stream Error Handling
```dart
stream
  .handleError((error) {
    print('Stream error: $error');
    return [];
  })
  .listen((data) {
    print('Data: $data');
  });
```

---

## Debugging Tips

### Enable Console Logging
All services print detailed logs to console. Check console output for:
- Flow function steps
- Data being saved
- Verification results
- Error messages

### Check Firestore Console
1. Go to Firebase Console
2. Click "Firestore Database"
3. Check collections for data
4. Verify document structure
5. Check timestamps

### Verify Data Consistency
1. Check that `adminId` is set correctly
2. Verify `buildingId` matches between collections
3. Verify `residentId` matches between collections
4. Check timestamps are consistent

### Common Issues
1. **"Permission denied"**: Check Firestore rules and adminId
2. **"Document not found"**: Check collection name and document ID
3. **"Null pointer exception"**: Check null safety in code
4. **"Batch size exceeded"**: Reduce batch size or split into multiple batches

---

## Performance Tips

### Optimize Queries
- Use `where` clauses to filter data
- Use `limit` to reduce data transfer
- Use `orderBy` for sorting (requires index)
- Avoid fetching all documents

### Optimize Writes
- Use batch operations for multiple writes
- Use `FieldValue.arrayUnion()` for array updates
- Use `FieldValue.arrayRemove()` for array removals
- Avoid unnecessary updates

### Optimize Reads
- Use streams for real-time updates
- Cache frequently accessed data
- Use pagination for large lists
- Avoid repeated queries

---

## Testing Checklist

- [ ] Admin can login
- [ ] Admin can create building
- [ ] Flats are generated for building
- [ ] Admin can create resident
- [ ] Admin can assign resident to flat
- [ ] Flat status changes to occupied
- [ ] Building occupancy updates
- [ ] Admin can unassign resident
- [ ] Flat status changes to vacant
- [ ] Building occupancy updates again
- [ ] Data is consistent in Firestore
- [ ] No orphaned documents
- [ ] Error handling works
- [ ] Rollback works on failures

---

## Useful Links

- [Firebase Console](https://console.firebase.google.com)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Flutter Firebase Plugin](https://pub.dev/packages/firebase_core)
- [Cloud Firestore Plugin](https://pub.dev/packages/cloud_firestore)

---

**Last Updated**: 2026-03-27
**Status**: ✅ READY FOR USE
