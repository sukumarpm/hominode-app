# Admin App - Flow Functions Implementation Guide

## Overview

This document details all flow functions in the Admin App that follow the standardized pattern for consistency with the Resident App.

---

## 1. Complaint Management Flow Function

### Purpose
Handle complaint status updates, assignments, and notifications.

### Flow Steps

```
STEP 1: Validate Admin Authentication
├─ Check Firebase Auth UID
├─ Verify admin role in Firestore
├─ Check building access
└─ Return admin ID or error

STEP 2: Validate Complaint Data
├─ Check complaint exists
├─ Verify complaint belongs to building
├─ Check status transition is valid
└─ Return complaint data or error

STEP 3: Update Complaint Status
├─ Update Firestore document
├─ Create status history entry
├─ Assign to staff if needed
└─ Log the change

STEP 4: Notify Resident
├─ Create notification document
├─ Send push notification
├─ Update complaint count
└─ Log notification

STEP 5: Return Result
├─ Return success status
├─ Include complaint ID
├─ Provide timestamp
└─ Include operation ID
```

### Implementation

```dart
class ComplaintManagementFlowFunction {
  Future<OperationResult> updateComplaintStatus({
    required String complaintId,
    required String newStatus,
    required String notes,
    String? assignedStaffId,
  }) async {
    try {
      print('🔵 COMPLAINT MANAGEMENT FLOW: Starting...');
      
      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = await _validateAdminAuth();
      if (adminId == null) {
        return OperationResult.failure('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');
      
      // STEP 2: Validate Complaint Data
      print('📋 STEP 2: Validating complaint data...');
      final complaint = await _validateComplaint(complaintId);
      if (complaint == null) {
        return OperationResult.failure('Complaint not found');
      }
      print('✅ STEP 2 PASSED: Complaint validated');
      
      // STEP 3: Update Complaint Status
      print('📝 STEP 3: Updating complaint status...');
      await _updateComplaintStatus(complaintId, newStatus, notes, assignedStaffId);
      print('✅ STEP 3 PASSED: Status updated');
      
      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      await _notifyResident(complaint, newStatus);
      print('✅ STEP 4 PASSED: Resident notified');
      
      // STEP 5: Return Result
      print('✅ COMPLAINT MANAGEMENT FLOW: COMPLETE');
      return OperationResult.success(
        message: 'Complaint status updated',
        operationId: complaintId,
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return OperationResult.failure('Error updating complaint: $e');
    }
  }
}
```

---

## 2. Notification Broadcast Flow Function

### Purpose
Create and broadcast notifications to residents.

### Flow Steps

```
STEP 1: Validate Admin Authentication
├─ Check Firebase Auth UID
├─ Verify admin role
├─ Check building access
└─ Return admin ID or error

STEP 2: Validate Notification Data
├─ Check title and content
├─ Validate target flats
├─ Check priority level
└─ Return validation result

STEP 3: Create Notification Document
├─ Save to Firestore
├─ Set publish date
├─ Set expiry date
└─ Generate notification ID

STEP 4: Notify Target Residents
├─ Query target flats
├─ Get resident FCM tokens
├─ Send push notifications
└─ Update notification count

STEP 5: Return Result
├─ Return success status
├─ Include notification ID
├─ Provide delivery count
└─ Include operation ID
```

### Implementation

```dart
class NotificationBroadcastFlowFunction {
  Future<OperationResult> broadcastNotification({
    required String title,
    required String content,
    required List<String> targetFlats,
    required String priority,
    DateTime? expiryDate,
  }) async {
    try {
      print('🔵 NOTIFICATION BROADCAST FLOW: Starting...');
      
      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = await _validateAdminAuth();
      if (adminId == null) {
        return OperationResult.failure('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');
      
      // STEP 2: Validate Notification Data
      print('📋 STEP 2: Validating notification data...');
      final validationResult = _validateNotificationData(
        title, content, targetFlats, priority
      );
      if (!validationResult.success) {
        return OperationResult.failure(validationResult.message);
      }
      print('✅ STEP 2 PASSED: Data validated');
      
      // STEP 3: Create Notification Document
      print('📝 STEP 3: Creating notification document...');
      final notificationId = await _createNotificationDocument(
        title, content, targetFlats, priority, expiryDate
      );
      print('✅ STEP 3 PASSED: Document created');
      
      // STEP 4: Notify Target Residents
      print('🔔 STEP 4: Notifying target residents...');
      final deliveryCount = await _notifyTargetResidents(
        notificationId, targetFlats
      );
      print('✅ STEP 4 PASSED: $deliveryCount residents notified');
      
      // STEP 5: Return Result
      print('✅ NOTIFICATION BROADCAST FLOW: COMPLETE');
      return OperationResult.success(
        message: 'Notification broadcast complete',
        operationId: notificationId,
        metadata: {'deliveryCount': deliveryCount},
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return OperationResult.failure('Error broadcasting notification: $e');
    }
  }
}
```

---

## 3. Amenity Booking Management Flow Function

### Purpose
Approve or reject amenity bookings and manage availability.

### Flow Steps

```
STEP 1: Validate Admin Authentication
├─ Check Firebase Auth UID
├─ Verify admin role
├─ Check building access
└─ Return admin ID or error

STEP 2: Validate Booking Data
├─ Check booking exists
├─ Verify booking belongs to building
├─ Check capacity availability
└─ Return booking data or error

STEP 3: Approve/Reject Booking
├─ Update booking status
├─ Update amenity availability
├─ Create audit log
└─ Log the change

STEP 4: Notify Resident
├─ Create notification
├─ Send push notification
├─ Update booking count
└─ Log notification

STEP 5: Return Result
├─ Return success status
├─ Include booking ID
├─ Provide confirmation details
└─ Include operation ID
```

### Implementation

```dart
class AmenityBookingManagementFlowFunction {
  Future<OperationResult> approveBooking({
    required String bookingId,
    String? notes,
  }) async {
    try {
      print('🔵 AMENITY BOOKING MANAGEMENT FLOW: Starting...');
      
      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = await _validateAdminAuth();
      if (adminId == null) {
        return OperationResult.failure('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');
      
      // STEP 2: Validate Booking Data
      print('📋 STEP 2: Validating booking data...');
      final booking = await _validateBooking(bookingId);
      if (booking == null) {
        return OperationResult.failure('Booking not found');
      }
      print('✅ STEP 2 PASSED: Booking validated');
      
      // STEP 3: Approve Booking
      print('✅ STEP 3: Approving booking...');
      await _approveBooking(bookingId, notes);
      print('✅ STEP 3 PASSED: Booking approved');
      
      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      await _notifyResidentBookingApproved(booking);
      print('✅ STEP 4 PASSED: Resident notified');
      
      // STEP 5: Return Result
      print('✅ AMENITY BOOKING MANAGEMENT FLOW: COMPLETE');
      return OperationResult.success(
        message: 'Booking approved',
        operationId: bookingId,
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return OperationResult.failure('Error approving booking: $e');
    }
  }
}
```

---

## 4. Visitor Approval Flow Function

### Purpose
Approve or reject visitor requests and generate QR codes.

### Flow Steps

```
STEP 1: Validate Admin Authentication
├─ Check Firebase Auth UID
├─ Verify admin role
├─ Check building access
└─ Return admin ID or error

STEP 2: Validate Visitor Request
├─ Check visitor request exists
├─ Verify request belongs to building
├─ Check request is pending
└─ Return request data or error

STEP 3: Approve/Reject Visitor
├─ Update visitor status
├─ Generate QR code if approved
├─ Create audit log
└─ Log the change

STEP 4: Notify Resident
├─ Create notification
├─ Send push notification
├─ Include QR code if approved
└─ Log notification

STEP 5: Return Result
├─ Return success status
├─ Include visitor ID
├─ Provide QR code if approved
└─ Include operation ID
```

### Implementation

```dart
class VisitorApprovalFlowFunction {
  Future<OperationResult> approveVisitor({
    required String visitorId,
    String? notes,
  }) async {
    try {
      print('🔵 VISITOR APPROVAL FLOW: Starting...');
      
      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final adminId = await _validateAdminAuth();
      if (adminId == null) {
        return OperationResult.failure('Admin not authenticated');
      }
      print('✅ STEP 1 PASSED: Admin authenticated');
      
      // STEP 2: Validate Visitor Request
      print('📋 STEP 2: Validating visitor request...');
      final visitor = await _validateVisitorRequest(visitorId);
      if (visitor == null) {
        return OperationResult.failure('Visitor request not found');
      }
      print('✅ STEP 2 PASSED: Visitor request validated');
      
      // STEP 3: Approve Visitor
      print('✅ STEP 3: Approving visitor...');
      final qrCode = await _approveVisitor(visitorId, notes);
      print('✅ STEP 3 PASSED: Visitor approved');
      
      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      await _notifyResidentVisitorApproved(visitor, qrCode);
      print('✅ STEP 4 PASSED: Resident notified');
      
      // STEP 5: Return Result
      print('✅ VISITOR APPROVAL FLOW: COMPLETE');
      return OperationResult.success(
        message: 'Visitor approved',
        operationId: visitorId,
        metadata: {'qrCode': qrCode},
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return OperationResult.failure('Error approving visitor: $e');
    }
  }
}
```

---

## 5. Billing Management Flow Function

### Purpose
Generate invoices and track payment status.

### Flow Steps

```
STEP 1: Validate Admin Authentication
├─ Check Firebase Auth UID
├─ Verify admin role
├─ Check building access
└─ Return admin ID or error

STEP 2: Validate Billing Data
├─ Check resident exists
├─ Verify billing period
├─ Check for duplicate invoice
└─ Return validation result

STEP 3: Generate Invoice
├─ Calculate charges
├─ Create invoice document
├─ Save to Firestore
└─ Generate invoice ID

STEP 4: Notify Resident
├─ Create notification
├─ Send push notification
├─ Include invoice details
└─ Log notification

STEP 5: Return Result
├─ Return success status
├─ Include invoice ID
├─ Provide invoice details
└─ Include operation ID
```

---

## 6. Report Generation Flow Function

### Purpose
Generate analytics and reports for building management.

### Flow Steps

```
STEP 1: Validate Admin Authentication
├─ Check Firebase Auth UID
├─ Verify admin role
├─ Check building access
└─ Return admin ID or error

STEP 2: Validate Report Parameters
├─ Check report type
├─ Validate date range
├─ Check filters
└─ Return validation result

STEP 3: Fetch Data
├─ Query Firestore
├─ Aggregate data
├─ Calculate metrics
└─ Return data

STEP 4: Generate Report
├─ Format data
├─ Create visualizations
├─ Generate PDF if needed
└─ Save report

STEP 5: Return Result
├─ Return success status
├─ Include report ID
├─ Provide report data
└─ Include operation ID
```

---

## Error Handling

All flow functions return standardized error codes:

```dart
class OperationResult {
  final bool success;
  final String message;
  final String? operationId;
  final Map<String, dynamic>? metadata;
  final String? errorCode;
  
  // Error codes
  static const String NOT_AUTHENTICATED = 'NOT_AUTHENTICATED';
  static const String NOT_AUTHORIZED = 'NOT_AUTHORIZED';
  static const String INVALID_DATA = 'INVALID_DATA';
  static const String NOT_FOUND = 'NOT_FOUND';
  static const String OPERATION_FAILED = 'OPERATION_FAILED';
  static const String FIRESTORE_ERROR = 'FIRESTORE_ERROR';
}
```

---

## Logging

All flow functions include comprehensive logging:

```
🔵 FLOW_NAME: Starting...
🔐 STEP 1: Validating...
✅ STEP 1 PASSED: ...
📋 STEP 2: Validating...
✅ STEP 2 PASSED: ...
📝 STEP 3: Executing...
✅ STEP 3 PASSED: ...
🔔 STEP 4: Notifying...
✅ STEP 4 PASSED: ...
✅ FLOW_NAME: COMPLETE
```

---

## Testing

### Unit Tests
```dart
test('Complaint status update flow', () async {
  final result = await complaintFlow.updateComplaintStatus(
    complaintId: 'test_complaint',
    newStatus: 'in_progress',
    notes: 'Working on it',
  );
  
  expect(result.success, true);
  expect(result.operationId, 'test_complaint');
});
```

### Integration Tests
```dart
testWidgets('Complaint update triggers notification', (tester) async {
  // Create complaint
  // Update status
  // Verify notification in Resident App
});
```

---

## Performance Optimization

### Batch Operations
```dart
// Update multiple complaints at once
await _firestore.runTransaction((transaction) async {
  for (var complaintId in complaintIds) {
    transaction.update(
      _firestore.collection('complaints').doc(complaintId),
      {'status': 'resolved'},
    );
  }
});
```

### Caching
```dart
// Cache frequently accessed data
final cachedComplaints = <String, ComplaintModel>{};

Future<ComplaintModel?> getComplaint(String id) async {
  if (cachedComplaints.containsKey(id)) {
    return cachedComplaints[id];
  }
  
  final complaint = await _fetchFromFirestore(id);
  if (complaint != null) {
    cachedComplaints[id] = complaint;
  }
  return complaint;
}
```

---

## Summary

All Admin App flow functions follow the standardized pattern:

✅ **STEP 1**: Validate Authentication & Authorization
✅ **STEP 2**: Validate Input Data
✅ **STEP 3**: Execute Main Operation
✅ **STEP 4**: Notify Affected Users
✅ **STEP 5**: Return Result with Status

This ensures:
- Consistent behavior across all operations
- Reliable error handling
- Comprehensive logging
- Easy debugging
- Scalable architecture

**Status**: READY FOR IMPLEMENTATION ✅
