# Complete Parking Management System

## Overview
A comprehensive parking management system built with Flutter and Firebase Firestore that handles vehicle registration, parking slot management, and violation tracking.

## Firestore Structure

### Collections

#### 1. **vehicles**
```
vehicleId (document ID)
├── vehicleNumber: string (e.g., "MH02AB1234")
├── vehicleType: string ("Car", "Bike", "Scooter")
├── userId: string (resident ID)
├── buildingId: string
├── color: string (optional)
├── registrationDate: timestamp
├── adminId: string (multi-tenancy)
├── buildingIds: array (multi-tenancy)
├── createdAt: timestamp
└── updatedAt: timestamp
```

#### 2. **parkingSlots**
```
slotId (document ID)
├── slotNumber: string (e.g., "A1", "B2")
├── slotType: string ("Car", "Bike", "Scooter")
├── buildingId: string
├── status: string ("vacant" or "occupied")
├── vehicleId: string (null if vacant)
├── userId: string (null if vacant)
├── notes: string (optional)
├── adminId: string (multi-tenancy)
├── buildingIds: array (multi-tenancy)
├── createdAt: timestamp
└── updatedAt: timestamp
```

#### 3. **parking_violations**
```
violationId (document ID)
├── slotId: string
├── vehicleNumber: string
├── violationType: string
├── buildingId: string
├── description: string
├── fineAmount: number
├── status: string ("pending" or "resolved")
├── reportedAt: timestamp
├── adminId: string (multi-tenancy)
├── buildingIds: array (multi-tenancy)
├── createdAt: timestamp
└── updatedAt: timestamp
```

## Core Features

### 1. Resident Features

#### Register Vehicle
- Residents can add vehicles (Car, Bike, Scooter)
- Store vehicle details: number, type, color
- Vehicles are linked to resident userId and buildingId
- Soft delete support (mark as inactive)

**File:** `lib/resident_vehicle_management_screen.dart`

```dart
// Register a vehicle
await parkingService.registerVehicle(
  vehicleNumber: 'MH02AB1234',
  vehicleType: 'Car',
  userId: userId,
  buildingId: buildingId,
  color: 'White',
);
```

#### View My Vehicles
- Stream of vehicles registered by the resident
- Delete vehicles
- Edit vehicle details

### 2. Admin Features

#### Create Parking Slots
- Admin creates parking slots with slot number and type
- Slots are building-specific
- Initial status: "vacant"

**File:** `lib/widgets/add_parking_slot_modal.dart`

```dart
// Create a parking slot
await parkingService.createParkingSlot(
  slotNumber: 'A1',
  slotType: 'Car',
  buildingId: buildingId,
);
```

#### Assign Vehicle to Slot
- Admin selects a vehicle and assigns it to a parking slot
- Updates slot with vehicleId and userId
- Sets slot status to "occupied"

**File:** `lib/widgets/assign_vehicle_to_slot_modal.dart`

```dart
// Assign vehicle to slot
await parkingService.assignVehicleToSlot(
  slotId: slotId,
  vehicleId: vehicleId,
  userId: userId,
);
```

#### Remove Vehicle from Slot
- Admin removes vehicle from slot
- Clears vehicleId and userId
- Sets status back to "vacant"

```dart
// Remove vehicle from slot
await parkingService.removeVehicleFromSlot(slotId);
```

#### View Parking Slots
- Real-time stream of all parking slots
- Shows slot status (vacant/occupied)
- If occupied: displays vehicle and owner details
- If vacant: shows assign button

#### Report Violations
- Admin can report parking violations
- Track violation type and fine amount
- Mark violations as resolved

```dart
// Report a violation
await parkingService.reportViolation(
  slotId: slotId,
  vehicleNumber: 'MH02AB1234',
  violationType: 'Unauthorized Parking',
  buildingId: buildingId,
  fineAmount: 500.0,
);
```

## UI Components

### 1. Parking Management Screen (Enhanced)
**File:** `lib/parking_management_screen_enhanced.dart`

Features:
- Three tabs: Slots, Vehicles, Violations
- Real-time statistics (Total, Occupied, Vacant)
- Search functionality
- Slot details with vehicle and owner information
- Quick actions (Remove Vehicle, Resolve Violation)

### 2. Resident Vehicle Management Screen
**File:** `lib/resident_vehicle_management_screen.dart`

Features:
- Register new vehicle form
- List of registered vehicles
- Delete vehicle option
- Vehicle type selection (Car, Bike, Scooter)

### 3. Assign Vehicle to Slot Modal
**File:** `lib/widgets/assign_vehicle_to_slot_modal.dart`

Features:
- Search vehicles by number
- Filter by building
- Quick assignment
- Real-time vehicle list

## Service Layer

### ParkingService
**File:** `lib/services/parking_service.dart`

#### Parking Slot Operations
```dart
// Create slot
Future<String> createParkingSlot({...})

// Get all slots (stream)
Stream<List<ParkingSlotModel>> getParkingSlots()

// Get slot details with vehicle and user info
Future<ParkingSlotDetailModel?> getParkingSlotDetails(String slotId)

// Update slot
Future<void> updateParkingSlot(String slotId, {...})

// Delete slot
Future<void> deleteParkingSlot(String slotId)
```

#### Vehicle Operations
```dart
// Register vehicle
Future<String> registerVehicle({...})

// Get all vehicles (stream)
Stream<List<VehicleModel>> getVehicles()

// Get user's vehicles (stream)
Stream<List<VehicleModel>> getUserVehicles(String userId)

// Update vehicle
Future<void> updateVehicle(String vehicleId, {...})

// Delete vehicle
Future<void> deleteVehicle(String vehicleId)
```

#### Assignment Operations
```dart
// Assign vehicle to slot
Future<void> assignVehicleToSlot({
  required String slotId,
  required String vehicleId,
  required String userId,
})

// Remove vehicle from slot
Future<void> removeVehicleFromSlot(String slotId)
```

#### Violation Operations
```dart
// Report violation
Future<String> reportViolation({...})

// Get violations (stream)
Stream<List<ParkingViolationModel>> getViolations()

// Resolve violation
Future<void> resolveViolation(String violationId)
```

## Data Models

### ParkingSlotModel
```dart
class ParkingSlotModel {
  final String id;
  final String slotNumber;
  final String slotType;
  final String buildingId;
  final String status; // 'vacant' or 'occupied'
  final String? vehicleId;
  final String? userId;
  final String notes;
  final DateTime? createdAt;
  
  bool get isOccupied => status == 'occupied';
}
```

### ParkingSlotDetailModel
```dart
class ParkingSlotDetailModel {
  final ParkingSlotModel slot;
  final VehicleModel? vehicle;
  final Map<String, dynamic>? userDetails;
  
  String get ownerName => userDetails?['name'] ?? 'Unknown';
  String get ownerPhone => userDetails?['phone'] ?? '';
  String get ownerEmail => userDetails?['email'] ?? '';
}
```

### VehicleModel
```dart
class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final String userId;
  final String buildingId;
  final String color;
  final DateTime? registrationDate;
}
```

### ParkingViolationModel
```dart
class ParkingViolationModel {
  final String id;
  final String slotId;
  final String vehicleNumber;
  final String violationType;
  final String buildingId;
  final String description;
  final double fineAmount;
  final String status;
  final DateTime? reportedAt;
}
```

## Flow Functions

### 1. Vehicle Registration Flow
```
Resident Input
    ↓
Validate Admin Auth
    ↓
Validate Vehicle Data
    ↓
Create Vehicle Document
    ↓
Store Multi-tenancy Fields
    ↓
Return Vehicle ID
```

### 2. Slot Assignment Flow
```
Admin Selection
    ↓
Validate Admin Auth
    ↓
Validate Slot & Vehicle Exist
    ↓
Update Slot with vehicleId & userId
    ↓
Set Status to "occupied"
    ↓
Fetch Vehicle & User Details
    ↓
Display in UI
```

### 3. Vehicle Removal Flow
```
Admin Action
    ↓
Validate Admin Auth
    ↓
Validate Slot Exists
    ↓
Clear vehicleId & userId
    ↓
Set Status to "vacant"
    ↓
Update Timestamp
    ↓
Refresh UI
```

## Fetch Logic

### Get Parking Slot with Details
```dart
// Fetch slot
final slotDoc = await firestore.collection('parkingSlots').doc(slotId).get();
final slot = ParkingSlotModel.fromFirestore(slotDoc);

// If occupied, fetch vehicle
if (slot.vehicleId != null) {
  final vehicleDoc = await firestore
      .collection('vehicles')
      .doc(slot.vehicleId!)
      .get();
  final vehicle = VehicleModel.fromFirestore(vehicleDoc);
}

// If userId available, fetch user details
if (slot.userId != null) {
  final userDoc = await firestore
      .collection('users')
      .doc(slot.userId!)
      .get();
  final userDetails = userDoc.data();
}
```

## UI Display Logic

### Parking Slot Card
```
┌─────────────────────────────────┐
│ [Icon] Slot A1 | Car | [Vacant] │
├─────────────────────────────────┤
│ If Occupied:                    │
│ ├─ Vehicle: MH02AB1234          │
│ ├─ Type: Car • Color: White     │
│ ├─ Owner: John Doe              │
│ ├─ Phone: 9876543210            │
│ └─ [Remove Vehicle Button]      │
│                                 │
│ If Vacant:                      │
│ └─ [Assign Vehicle Button]      │
└─────────────────────────────────┘
```

## Integration Points

### 1. Admin Dashboard
- Add Parking Management link to admin dashboard
- Show parking statistics widget

### 2. Resident App
- Add "My Vehicles" section
- Link to vehicle registration screen
- Show assigned parking slot

### 3. Multi-tenancy
- All operations filtered by adminId
- Building-specific slot management
- Resident data isolation

## Testing Checklist

- [ ] Register vehicle as resident
- [ ] Create parking slot as admin
- [ ] Assign vehicle to slot
- [ ] Verify slot shows vehicle and owner details
- [ ] Remove vehicle from slot
- [ ] Verify slot becomes vacant
- [ ] Report parking violation
- [ ] Resolve violation
- [ ] Search functionality works
- [ ] Real-time updates work
- [ ] Multi-tenancy isolation works

## Security Considerations

1. **Admin Validation**: All operations validate admin authentication
2. **Data Isolation**: Multi-tenancy fields ensure data separation
3. **Soft Deletes**: Vehicles support soft delete (mark inactive)
4. **Audit Trail**: All operations logged with timestamps
5. **User Verification**: Vehicle assignment verifies user exists

## Performance Optimizations

1. **Local Sorting**: Sort results locally to avoid Firestore indexes
2. **Stream Caching**: Use StreamBuilder for real-time updates
3. **Lazy Loading**: Load vehicle/user details on demand
4. **Search Filtering**: Filter on client side for better UX
5. **Batch Operations**: Support batch updates for efficiency

## Future Enhancements

1. **QR Code Integration**: Generate QR codes for parking slots
2. **Mobile App**: Resident app for vehicle management
3. **Notifications**: Alert residents of parking violations
4. **Analytics**: Parking usage statistics and reports
5. **Payment Integration**: Online fine payment system
6. **Reservation System**: Allow residents to reserve slots
7. **Mobile Patrol**: Security app for violation reporting
