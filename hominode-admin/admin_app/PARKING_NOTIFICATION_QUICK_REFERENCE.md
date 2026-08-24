# Parking & Notification - Quick Reference ✅

## Services Created

### 1. Parking Service
**File**: `lib/services/parking_service.dart`

**Main Methods**:
```dart
// Parking Slots
Future<String> createParkingSlot(...)
Stream<List<ParkingSlotModel>> getParkingSlots()
Future<void> updateParkingSlot(...)
Future<void> deleteParkingSlot(...)

// Vehicles
Future<String> registerVehicle(...)
Stream<List<VehicleModel>> getVehicles()
Future<void> updateVehicle(...)
Future<void> deleteVehicle(...)

// Assignments
Future<String> assignVehicleToSlot(...)
Stream<List<ParkingAssignmentModel>> getActiveAssignments()
Future<void> markVehicleExit(...)

// Violations
Future<String> reportViolation(...)
Stream<List<ParkingViolationModel>> getViolations()
Future<void> resolveViolation(...)
```

### 2. Notification Service
**File**: `lib/services/notification_firestore_service.dart`

**Main Methods**:
```dart
// Create
Future<String> createNotification(...)

// Retrieve
Stream<List<NotificationFirestoreModel>> getNotifications()
Stream<int> getUnreadCount()
Stream<List<NotificationFirestoreModel>> getNotificationsByType(...)
Stream<List<NotificationFirestoreModel>> getNotificationsByPriority(...)

// Update
Future<void> markAsRead(...)
Future<void> markAllAsRead(...)

// Delete
Future<void> deleteNotification(...)
Future<void> clearAllNotifications(...)

// Triggers
Future<void> notifyVisitorApproved(...)
Future<void> notifyComplaintUpdate(...)
Future<void> notifyPaymentReceived(...)
Future<void> notifyMaintenanceScheduled(...)
Future<void> notifySecurityAlert(...)
Future<void> notifyParkingViolation(...)
```

---

## Firestore Collections

### parking_slots
```
{
  slotNumber: string,
  vehicleType: string,
  buildingId: string,
  isOccupied: boolean,
  assignedVehicleId: string,
  notes: string,
  adminId: string,
  buildingIds: array,
  createdAt: timestamp,
}
```

### vehicles
```
{
  vehicleNumber: string,
  vehicleType: string,
  ownerName: string,
  flatNumber: string,
  buildingId: string,
  model: string,
  color: string,
  isActive: boolean,
  registrationDate: timestamp,
  adminId: string,
  buildingIds: array,
  createdAt: timestamp,
}
```

### parking_assignments
```
{
  slotId: string,
  vehicleId: string,
  residentId: string,
  buildingId: string,
  isActive: boolean,
  assignmentDate: timestamp,
  exitDate: timestamp,
  adminId: string,
  buildingIds: array,
  createdAt: timestamp,
}
```

### parking_violations
```
{
  slotId: string,
  vehicleNumber: string,
  violationType: string,
  buildingId: string,
  description: string,
  fineAmount: number,
  status: string,
  reportedAt: timestamp,
  adminId: string,
  buildingIds: array,
  createdAt: timestamp,
}
```

### notifications
```
{
  title: string,
  message: string,
  type: string,
  priority: string,
  recipientId: string,
  isRead: boolean,
  actionUrl: string,
  metadata: object,
  adminId: string,
  buildingIds: array,
  createdAt: timestamp,
}
```

---

## Usage Examples

### Create Parking Slot
```dart
final parkingService = ParkingService();
final slotId = await parkingService.createParkingSlot(
  slotNumber: 'A-01',
  vehicleType: 'Car',
  buildingId: 'building_123',
);
```

### Register Vehicle
```dart
final vehicleId = await parkingService.registerVehicle(
  vehicleNumber: 'UP 16 AB 1234',
  vehicleType: 'Car',
  ownerName: 'John Doe',
  flatNumber: 'A-204',
  buildingId: 'building_123',
);
```

### Assign Vehicle
```dart
final assignmentId = await parkingService.assignVehicleToSlot(
  slotId: slotId,
  vehicleId: vehicleId,
  residentId: 'resident_123',
  buildingId: 'building_123',
);
```

### Mark Exit
```dart
await parkingService.markVehicleExit(assignmentId);
```

### Report Violation
```dart
final violationId = await parkingService.reportViolation(
  slotId: slotId,
  vehicleNumber: 'UP 16 AB 1234',
  violationType: 'Unauthorized Parking',
  buildingId: 'building_123',
  fineAmount: 500.0,
);
```

### Create Notification
```dart
final notificationService = NotificationFirestoreService();
final notificationId = await notificationService.createNotification(
  title: 'Visitor Approved',
  message: 'John has been approved.',
  type: NotificationType.visitor,
  priority: NotificationPriority.medium,
  recipientId: 'resident_123',
);
```

### Get Notifications
```dart
notificationService.getNotifications().listen((notifications) {
  print('Notifications: ${notifications.length}');
});
```

### Mark as Read
```dart
await notificationService.markAsRead(notificationId);
```

### Notify Visitor Approved
```dart
await notificationService.notifyVisitorApproved(
  visitorName: 'John Doe',
  residentId: 'resident_123',
);
```

### Notify Parking Violation
```dart
await notificationService.notifyParkingViolation(
  vehicleNumber: 'UP 16 AB 1234',
  violationType: 'Unauthorized Parking',
  residentId: 'resident_123',
);
```

---

## Flow Function Pattern

All operations follow 5-step pattern:

```
🔵 OPERATION: Starting...
🔐 STEP 1: Validating admin...
✅ STEP 1 PASSED
📋 STEP 2: Validating data...
✅ STEP 2 PASSED
📝 STEP 3: Executing operation...
✅ STEP 3 PASSED
🔔 STEP 4: Notifying...
✅ STEP 4 PASSED
✅ OPERATION: COMPLETE
```

---

## Multi-Tenancy

All data isolated by adminId:

```dart
// Admin A creates parking slot
// Admin B cannot see it

// Admin A creates notification
// Admin B cannot see it

// Each admin only sees their own data
```

---

## Error Handling

```dart
try {
  await parkingService.createParkingSlot(...);
} catch (e) {
  if (e.toString().contains('Admin not logged in')) {
    // Show login screen
  } else {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## Firestore Indexes

Create these indexes:

1. `parking_slots`: adminId (Asc), slotNumber (Asc)
2. `vehicles`: adminId (Asc), isActive (Asc)
3. `parking_assignments`: adminId (Asc), isActive (Asc)
4. `parking_violations`: adminId (Asc), status (Asc)
5. `notifications`: adminId (Asc), createdAt (Desc)
6. `notifications`: adminId (Asc), isRead (Asc)
7. `notifications`: adminId (Asc), type (Asc)
8. `notifications`: adminId (Asc), priority (Asc)

---

## Notification Types

- `visitor` - Visitor related
- `complaint` - Complaint related
- `payment` - Payment related
- `maintenance` - Maintenance related
- `announcement` - Announcement related
- `event` - Event related
- `security` - Security related
- `general` - General notification

---

## Notification Priorities

- `low` - Low priority
- `medium` - Medium priority
- `high` - High priority
- `urgent` - Urgent priority

---

## Status

✅ Parking Management - Complete
✅ Notification System - Complete
✅ Multi-tenancy - Complete
✅ Flow Function Pattern - Complete
✅ No Compilation Errors - Complete
✅ Production Ready - Complete

---

**Date**: March 25, 2026
**Version**: 1.0.0

