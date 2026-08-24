# Parking & Notification Integration Guide

## Quick Start - How to Use the New Services

### 1. Import the Services

```dart
import 'services/parking_service.dart';
import 'services/notification_firestore_service.dart';
```

### 2. Initialize Services

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late final ParkingService _parkingService;
  late final NotificationFirestoreService _notificationService;

  @override
  void initState() {
    super.initState();
    _parkingService = ParkingService();
    _notificationService = NotificationFirestoreService();
  }
}
```

---

## Parking Management Integration

### Display Parking Slots

```dart
// In parking_management_screen.dart
StreamBuilder<List<ParkingSlotModel>>(
  stream: _parkingService.getParkingSlots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(child: Text('No parking slots'));
    }
    
    final slots = snapshot.data!;
    return ListView.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return ListTile(
          title: Text('Slot ${slot.slotNumber}'),
          subtitle: Text('${slot.vehicleType} - ${slot.isOccupied ? 'Occupied' : 'Vacant'}'),
        );
      },
    );
  },
)
```

### Add Parking Slot

```dart
// In add_parking_slot_modal.dart
Future<void> _addParkingSlot() async {
  try {
    final slotId = await _parkingService.createParkingSlot(
      slotNumber: _slotNumberController.text,
      vehicleType: _selectedVehicleType,
      buildingId: _selectedBuildingId,
      notes: _notesController.text,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parking slot added successfully')),
    );
    
    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Register Vehicle

```dart
// In vehicle registration modal
Future<void> _registerVehicle() async {
  try {
    final vehicleId = await _parkingService.registerVehicle(
      vehicleNumber: _vehicleNumberController.text,
      vehicleType: _selectedVehicleType,
      ownerName: _ownerNameController.text,
      flatNumber: _flatNumberController.text,
      buildingId: _selectedBuildingId,
      model: _modelController.text,
      color: _colorController.text,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle registered successfully')),
    );
    
    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Assign Vehicle to Slot

```dart
// In parking assignment modal
Future<void> _assignVehicle() async {
  try {
    final assignmentId = await _parkingService.assignVehicleToSlot(
      slotId: _selectedSlotId,
      vehicleId: _selectedVehicleId,
      residentId: _selectedResidentId,
      buildingId: _selectedBuildingId,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle assigned successfully')),
    );
    
    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Mark Vehicle Exit

```dart
// In parking management screen
Future<void> _markExit(String assignmentId) async {
  try {
    await _parkingService.markVehicleExit(assignmentId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle exit marked')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Report Parking Violation

```dart
// In violation reporting modal
Future<void> _reportViolation() async {
  try {
    final violationId = await _parkingService.reportViolation(
      slotId: _selectedSlotId,
      vehicleNumber: _vehicleNumberController.text,
      violationType: _selectedViolationType,
      buildingId: _selectedBuildingId,
      description: _descriptionController.text,
      fineAmount: double.parse(_fineAmountController.text),
    );
    
    // Create notification
    await _notificationService.notifyParkingViolation(
      vehicleNumber: _vehicleNumberController.text,
      violationType: _selectedViolationType,
      residentId: _residentId,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Violation reported')),
    );
    
    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## Notification Integration

### Display Notifications

```dart
// In notifications_screen.dart
StreamBuilder<List<NotificationFirestoreModel>>(
  stream: _notificationService.getNotifications(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(child: Text('No notifications'));
    }
    
    final notifications = snapshot.data!;
    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return ListTile(
          title: Text(notification.title),
          subtitle: Text(notification.message),
          trailing: notification.isRead ? null : const Icon(Icons.circle, size: 8),
          onTap: () => _markAsRead(notification.id),
        );
      },
    );
  },
)
```

### Display Unread Count

```dart
// In app bar or notification badge
StreamBuilder<int>(
  stream: _notificationService.getUnreadCount(),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    return Badge(
      label: Text(count.toString()),
      child: const Icon(Icons.notifications),
    );
  },
)
```

### Mark Notification as Read

```dart
Future<void> _markAsRead(String notificationId) async {
  try {
    await _notificationService.markAsRead(notificationId);
  } catch (e) {
    print('Error marking as read: $e');
  }
}
```

### Mark All as Read

```dart
Future<void> _markAllAsRead() async {
  try {
    await _notificationService.markAllAsRead();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All marked as read')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Delete Notification

```dart
Future<void> _deleteNotification(String notificationId) async {
  try {
    await _notificationService.deleteNotification(notificationId);
  } catch (e) {
    print('Error deleting notification: $e');
  }
}
```

---

## Integration with Existing Services

### Visitor Service - Notify on Approval

```dart
// In visitor_service.dart - approveVisitor() method
Future<void> approveVisitor(String visitorId) async {
  try {
    // ... existing approval logic ...
    
    // Create notification
    final notificationService = NotificationFirestoreService();
    await notificationService.notifyVisitorApproved(
      visitorName: visitor['name'],
      residentId: visitor['residentId'],
    );
  } catch (e) {
    print('Error: $e');
  }
}
```

### Complaint Service - Notify on Status Update

```dart
// In complaint_service.dart - updateComplaintStatus() method
Future<void> updateComplaintStatus(String complaintId, String newStatus) async {
  try {
    // ... existing update logic ...
    
    // Create notification
    final notificationService = NotificationFirestoreService();
    await notificationService.notifyComplaintUpdate(
      complaintTitle: complaint['title'],
      newStatus: newStatus,
      residentId: complaint['residentId'],
    );
  } catch (e) {
    print('Error: $e');
  }
}
```

### Billing Service - Notify on Payment

```dart
// In billing_service.dart - markPaymentReceived() method
Future<void> markPaymentReceived(String billId, double amount) async {
  try {
    // ... existing payment logic ...
    
    // Create notification
    final notificationService = NotificationFirestoreService();
    await notificationService.notifyPaymentReceived(
      amount: amount,
      residentId: bill['residentId'],
    );
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## Error Handling

All services throw exceptions with descriptive messages:

```dart
try {
  await _parkingService.createParkingSlot(
    slotNumber: 'A-01',
    vehicleType: 'Car',
    buildingId: 'building_123',
  );
} on Exception catch (e) {
  // Handle specific errors
  if (e.toString().contains('Admin not logged in')) {
    // Show login screen
  } else if (e.toString().contains('validation')) {
    // Show validation error
  } else {
    // Show generic error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## Logging

All operations include comprehensive logging:

```
🔵 PARKING SLOT CREATION: Starting...
🔐 STEP 1: Validating admin authentication...
✅ STEP 1 PASSED: Admin authenticated
📋 STEP 2: Validating parking slot data...
✅ STEP 2 PASSED: Data validated
📝 STEP 3: Creating parking slot...
✅ STEP 3 PASSED: Parking slot created
🔔 STEP 4: Logging completion...
✅ PARKING SLOT CREATION: COMPLETE
```

Check the console/debug output to see detailed operation logs.

---

## Multi-Tenancy Verification

To verify multi-tenancy is working:

1. Login as Admin A
2. Create parking slot
3. Logout
4. Login as Admin B
5. Verify Admin B cannot see Admin A's parking slot
6. Create parking slot as Admin B
7. Verify Admin B only sees their own parking slot

Same process for notifications.

---

## Performance Tips

1. **Use Streams** - Use StreamBuilder for real-time updates
2. **Pagination** - For large datasets, implement pagination
3. **Caching** - Cache frequently accessed data
4. **Batch Operations** - Use batch writes for multiple operations
5. **Indexes** - Create Firestore indexes for filtered queries

---

## Troubleshooting

### Issue: "Admin not logged in"
**Solution**: Ensure user is logged in before accessing services

### Issue: "Parking slot not found"
**Solution**: Verify slot ID exists in Firestore

### Issue: "No data displayed"
**Solution**: Check Firestore indexes are created

### Issue: "Multi-tenancy not working"
**Solution**: Verify adminId is stored in documents

### Issue: "Notifications not appearing"
**Solution**: Check notification service is initialized and Firestore collection exists

---

## Summary

✅ Parking Management - Complete with CRUD operations
✅ Notification System - Firestore-backed with real-time updates
✅ Multi-tenancy - All data isolated by adminId
✅ Flow Function Pattern - All operations follow 5-step pattern
✅ Error Handling - Comprehensive error handling
✅ Logging - Detailed operation logging

---

**Status**: ✅ READY FOR INTEGRATION
**Date**: March 25, 2026
**Version**: 1.0.0

