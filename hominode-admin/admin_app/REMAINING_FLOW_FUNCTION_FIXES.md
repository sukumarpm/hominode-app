# Remaining Flow Function Fixes - Quick Reference

## Status Summary

✅ **COMPLETED**: Parking Service (3 methods)
⏳ **TODO**: 4 Services (12+ methods)

---

## Quick Fix Checklist

### 1. Billing Service - 3 Methods

**File**: `lib/services/billing_service.dart`

**Method 1: addBill()**
- [ ] Add notification service import
- [ ] Add notification service instance
- [ ] Add Step 4 after bill creation
- [ ] Notify resident with bill amount and due date

**Method 2: markBillAsPaid()**
- [ ] Add Step 4 after marking paid
- [ ] Notify resident with payment confirmation
- [ ] Include receipt details

**Method 3: generateMonthlyBills()**
- [ ] Add Step 4 after bulk creation
- [ ] Notify all residents with bill details
- [ ] Include payment deadline

---

### 2. Complaint Service - 2 Methods

**File**: `lib/services/complaint_service.dart`

**Method 1: updateComplaintStatus()**
- [ ] Add notification service import
- [ ] Add notification service instance
- [ ] Add Step 4 after status update
- [ ] Notify resident with new status
- [ ] Include staff assignment if applicable

**Method 2: updateComplaintAssignment()**
- [ ] Add Step 4 after assignment
- [ ] Notify resident about staff assignment
- [ ] Notify assigned staff member

---

### 3. Visitor Service - 2 Methods

**File**: `lib/services/visitor_service.dart`

**Method 1: approveVisitor()**
- [ ] Add notification service import
- [ ] Add notification service instance
- [ ] Add Step 4 after approval
- [ ] Notify resident with approval
- [ ] Include visitor details and entry time

**Method 2: rejectVisitor()**
- [ ] Add Step 4 after rejection
- [ ] Notify resident with rejection reason
- [ ] Include appeal instructions if applicable

---

### 4. Amenity Service - 3 Methods

**File**: `lib/services/amenity_service.dart`

**Method 1: approveBooking()**
- [ ] Add notification service import
- [ ] Add notification service instance
- [ ] Add Step 4 after approval
- [ ] Notify resident with booking confirmation
- [ ] Include booking details and time slot

**Method 2: rejectBooking()**
- [ ] Add Step 4 after rejection
- [ ] Notify resident with rejection reason
- [ ] Include alternative time slots if available

**Method 3: cancelBooking()**
- [ ] Add Step 4 after cancellation
- [ ] Notify resident with cancellation confirmation
- [ ] Include refund details if applicable

---

## Multi-Tenancy Fixes Required

### Issue: adminId not stored in resident-created documents

**Affected Services:**
1. Visitor Service - `createVisitorRequest()`
2. Complaint Service - `createComplaint()`
3. Amenity Service - Booking creation

**Fix Pattern:**
```dart
// Get admin from building
final buildingDoc = await _firestore
    .collection('buildings')
    .doc(buildingId)
    .get();
final adminId = buildingDoc.data()?['adminId'];

// Store in document
await _firestore.collection('collection_name').add({
  'field': value,
  'adminId': adminId,  // ✅ ADD THIS
  'buildingIds': [buildingId],  // ✅ ADD THIS
  'createdAt': FieldValue.serverTimestamp(),
});
```

---

## Notification Types Available

```dart
enum NotificationType {
  general,
  parking,
  parking_violation,
  complaint,
  visitor,
  amenity,
  billing,
  maintenance,
  event,
  announcement,
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}
```

---

## Standard Notification Pattern

```dart
// STEP 4: Notify Residents
print('🔔 STEP 4: Notifying residents...');
try {
  await _notificationService.createNotification(
    title: 'Action Title',
    message: 'Detailed message with relevant info',
    type: NotificationType.parking,  // Change based on action
    priority: NotificationPriority.high,  // Adjust based on urgency
    recipientId: userId,
    metadata: {
      'actionId': documentId,
      'relatedData': value,
    },
  );
  print('✅ STEP 4 PASSED: Residents notified');
} catch (notificationError) {
  print('⚠️ STEP 4 WARNING: Failed to send notification: $notificationError');
  // Don't throw - notification failure shouldn't block the operation
}
```

---

## Testing Each Fix

### After Billing Service Fix:
```
1. Create bill → Check notification in Firestore
2. Mark bill as paid → Check payment notification
3. Generate monthly bills → Check bulk notifications
```

### After Complaint Service Fix:
```
1. Update complaint status → Check status notification
2. Assign to staff → Check assignment notification
```

### After Visitor Service Fix:
```
1. Approve visitor → Check approval notification
2. Reject visitor → Check rejection notification
```

### After Amenity Service Fix:
```
1. Approve booking → Check approval notification
2. Reject booking → Check rejection notification
3. Cancel booking → Check cancellation notification
```

---

## Compilation Check Command

After each fix:
```bash
flutter analyze lib/services/[service_name].dart
```

---

## Priority Order

1. **CRITICAL**: Billing Service (affects revenue tracking)
2. **CRITICAL**: Complaint Service (affects resident satisfaction)
3. **HIGH**: Visitor Service (affects security)
4. **HIGH**: Amenity Service (affects bookings)
5. **HIGH**: Multi-tenancy fixes (affects data isolation)

---

## Expected Outcome

After all fixes:
✅ All 5-step flow functions complete
✅ All residents notified of important events
✅ Multi-tenancy data isolation working
✅ Real data only (no demo data)
✅ App flow working properly

---

## Files to Update

```
lib/services/
├── parking_service.dart ✅ DONE
├── billing_service.dart ⏳ TODO
├── complaint_service.dart ⏳ TODO
├── visitor_service.dart ⏳ TODO
└── amenity_service.dart ⏳ TODO
```

---

## Estimated Time

- Billing Service: 30 minutes
- Complaint Service: 30 minutes
- Visitor Service: 20 minutes
- Amenity Service: 30 minutes
- Multi-tenancy fixes: 30 minutes
- Testing: 30 minutes

**Total**: ~3 hours

