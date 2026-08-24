# Parking Management System - Flow Functions & Architecture

## Overview
Complete parking management system with real-time Firestore integration, multi-tenancy support, and flow function compliance.

## Firestore Collections

### 1. vehicles
```
vehicleId (document ID)
├── vehicleNumber: string (e.g., "MH02AB1234")
├── vehicleType: string ("Car", "Bike", "Scooter")
├── userId: string (resident ID)
├── buildingId: string
├── color: string
├── registrationDate: timestamp
├── adminId: string (multi-tenancy)
├── buildingIds: array (multi-tenancy)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### 2. parkingSlots
```
slotId (document ID)
├── slotNumber: string (e.g., "A1", "B2")
├── slotType: string ("Car", "Bike", "Scooter")
├── buildingId: string
├── status: string ("vacant" or "occupied")
├── vehicleId: string (null if vacant)
├── userId: string (null if vacant)
├── notes: string
├── adminId: string (multi-tenancy)
├── buildingIds: array (multi-tenancy)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### 3. parking_violations
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

## Flow Functions

### FLOW 1: Register Vehicle (Resident)
```
START: Resident opens "My Vehicles" screen
  ↓
INPUT: Vehicle number, type (Car/Bike/Scooter), color
  ↓
VALIDATE: 
  - Check vehicle number not empty
  - Check vehicle type selected
  - Validate admin auth
  ↓
CREATE: Add to vehicles collection
  - vehicleNumber: user input
  - vehicleType: user selection
  - userId: current resident ID
  - buildingId: resident's building
  - color: user input
  - adminId: current admin
  - buildingIds: admin's buildings
  - createdAt: server timestamp
  ↓
RESPONSE: Show success message
  ↓
UPDATE UI: Refresh vehicle list
  ↓
END
```

### FLOW 2: Create Parking Slot (Admin)
```
START: Admin clicks "Add Parking Slot"
  ↓
INPUT: Slot number, slot type (Car/Bike/Scooter), building
  ↓
VALIDATE:
  - Check slot number not empty
  - Check slot type selected
  - Validate admin auth
  ↓
CREATE: Add to parkingSlots collection
  - slotNumber: user input
  - slotType: user selection
  - buildingId: selected building
  - status: "vacant"
  - vehicleId: null
  - userId: null
  - adminId: current admin
  - buildingIds: admin's buildings
  - createdAt: server timestamp
  ↓
RESPONSE: Show success message
  ↓
UPDATE UI: Refresh slots list
  ↓
END
```

### FLOW 3: Assign Vehicle to Slot (Admin)
```
START: Admin clicks "Assign Vehicle" on vacant slot
  ↓
FETCH: Get all vehicles for building
  ↓
DISPLAY: Show vehicle selection modal
  ↓
INPUT: Admin selects vehicle
  ↓
VALIDATE:
  - Check vehicle exists
  - Check slot exists
  - Validate admin auth
  ↓
UPDATE SLOT:
  - vehicleId: selected vehicle ID
  - userId: vehicle owner ID
  - status: "occupied"
  - updatedAt: server timestamp
  ↓
FETCH DETAILS:
  - Get vehicle info
  - Get user/resident info
  ↓
RESPONSE: Show success message
  ↓
UPDATE UI: 
  - Show vehicle details in slot
  - Show owner information
  - Show "Remove Vehicle" button
  ↓
TRIGGER NOTIFICATION:
  - Type: parking
  - Message: "Vehicle assigned to slot X"
  ↓
END
```

### FLOW 4: Remove Vehicle from Slot (Admin)
```
START: Admin clicks "Remove Vehicle" on occupied slot
  ↓
CONFIRM: Show confirmation dialog
  ↓
INPUT: Admin confirms removal
  ↓
VALIDATE:
  - Check slot exists
  - Check slot is occupied
  - Validate admin auth
  ↓
UPDATE SLOT:
  - vehicleId: null
  - userId: null
  - status: "vacant"
  - updatedAt: server timestamp
  ↓
RESPONSE: Show success message
  ↓
UPDATE UI:
  - Show "Assign Vehicle" button
  - Clear vehicle details
  ↓
TRIGGER NOTIFICATION:
  - Type: parking
  - Message: "Vehicle removed from slot X"
  ↓
END
```

### FLOW 5: View Parking Slots (Admin)
```
START: Admin opens Parking Management screen
  ↓
FETCH: Get all parking slots for admin's buildings
  - Query: parkingSlots where adminId == currentAdminId
  - Sort: by slotNumber
  ↓
FOR EACH SLOT:
  ├─ IF status == "occupied":
  │  ├─ FETCH vehicle details from vehicles collection
  │  ├─ FETCH user details from users collection
  │  └─ DISPLAY: Slot with vehicle + owner info + Remove button
  │
  └─ IF status == "vacant":
     └─ DISPLAY: Slot with Assign Vehicle button
  ↓
DISPLAY: Real-time statistics
  - Total slots
  - Occupied slots
  - Vacant slots
  ↓
ENABLE: Search/filter by slot number or type
  ↓
END
```

### FLOW 6: Report Parking Violation (Admin)
```
START: Admin reports violation
  ↓
INPUT:
  - Vehicle number
  - Violation type
  - Description (optional)
  - Fine amount (optional)
  ↓
VALIDATE:
  - Check vehicle number not empty
  - Check violation type selected
  - Validate admin auth
  ↓
CREATE: Add to parking_violations collection
  - vehicleNumber: user input
  - violationType: user selection
  - description: user input
  - fineAmount: user input
  - status: "pending"
  - adminId: current admin
  - buildingIds: admin's buildings
  - reportedAt: server timestamp
  ↓
RESPONSE: Show success message
  ↓
UPDATE UI: Show in violations tab
  ↓
TRIGGER NOTIFICATION:
  - Type: parking_violation
  - Message: "Parking violation reported for vehicle X"
  ↓
END
```

### FLOW 7: Resolve Parking Violation (Admin)
```
START: Admin clicks "Resolve" on violation
  ↓
CONFIRM: Show confirmation dialog
  ↓
INPUT: Admin confirms resolution
  ↓
VALIDATE:
  - Check violation exists
  - Validate admin auth
  ↓
UPDATE VIOLATION:
  - status: "resolved"
  - updatedAt: server timestamp
  ↓
RESPONSE: Show success message
  ↓
UPDATE UI: Remove from pending violations
  ↓
END
```

## UI Components

### Parking Management Screen
**File:** `lib/parking_management_screen.dart`

**Tabs:**
1. **Slots Tab**
   - Real-time list of all parking slots
   - Search by slot number or type
   - Status badge (Vacant/Occupied)
   - If occupied: Show vehicle + owner details + Remove button
   - If vacant: Show Assign Vehicle button
   - Add Parking Slot button

2. **Vehicles Tab**
   - Real-time list of all registered vehicles
   - Search by vehicle number or type
   - Show vehicle type and color
   - Delete vehicle option

3. **Violations Tab**
   - Real-time list of pending violations
   - Show vehicle number, violation type, fine amount
   - Resolve button for each violation
   - Status badge (Pending/Resolved)

**Statistics:**
- Total Slots
- Occupied Slots
- Vacant Slots

### Resident Vehicle Management Screen
**File:** `lib/resident_vehicle_management_screen.dart`

**Features:**
- Register new vehicle form
- Vehicle type dropdown (Car, Bike, Scooter)
- Color input (optional)
- Real-time list of registered vehicles
- Delete vehicle option

### Modals

**Add Parking Slot Modal**
- Slot number input
- Slot type dropdown
- Building selection
- Notes (optional)

**Assign Vehicle to Slot Modal**
- Search vehicles by number
- Filter by building
- Quick assignment
- Real-time vehicle list

## Service Layer

### ParkingService
**File:** `lib/services/parking_service.dart`

**Parking Slot Operations:**
- `createParkingSlot()` - Create new slot
- `getParkingSlots()` - Stream all slots
- `getParkingSlotDetails()` - Get slot with vehicle + user info
- `updateParkingSlot()` - Update slot
- `deleteParkingSlot()` - Delete slot

**Vehicle Operations:**
- `registerVehicle()` - Register new vehicle
- `getVehicles()` - Stream all vehicles
- `getUserVehicles()` - Stream user's vehicles
- `updateVehicle()` - Update vehicle
- `deleteVehicle()` - Delete vehicle

**Assignment Operations:**
- `assignVehicleToSlot()` - Assign vehicle to slot
- `removeVehicleFromSlot()` - Remove vehicle from slot

**Violation Operations:**
- `reportViolation()` - Report violation
- `getViolations()` - Stream pending violations
- `resolveViolation()` - Resolve violation

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

## Notifications

### Parking-Related Notifications
**File:** `lib/services/notification_firestore_service.dart`

**Trigger Points:**
1. Vehicle Registered
   - Type: general
   - Message: "Vehicle registered successfully"

2. Vehicle Assigned to Slot
   - Type: parking
   - Message: "Vehicle assigned to slot X"

3. Vehicle Removed from Slot
   - Type: parking
   - Message: "Vehicle removed from slot X"

4. Parking Violation Reported
   - Type: parking_violation
   - Message: "Parking violation reported for vehicle X"

5. Violation Resolved
   - Type: parking_violation
   - Message: "Parking violation resolved"

**All notifications:**
- Stored in Firestore `notifications` collection
- Real data only (no demo data)
- Multi-tenancy support (adminId, buildingIds)
- Timestamps for audit trail

## Multi-Tenancy Implementation

All operations include:
- `adminId`: Current admin's ID
- `buildingIds`: Admin's building IDs
- `adminName`, `adminEmail`, `adminPhone`: Admin details
- `organization`: Admin's organization

**Query Filtering:**
All queries filter by `adminId` to ensure data isolation:
```dart
.where('adminId', isEqualTo: adminId)
```

## Real Data Flow

1. **No Demo Data**: All data comes from Firestore
2. **Real-Time Updates**: StreamBuilder for live data
3. **Proper Validation**: All inputs validated before Firestore operations
4. **Audit Trail**: All operations logged with timestamps
5. **Error Handling**: Comprehensive error messages

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
- [ ] Notifications show real data only
- [ ] Statistics update correctly
