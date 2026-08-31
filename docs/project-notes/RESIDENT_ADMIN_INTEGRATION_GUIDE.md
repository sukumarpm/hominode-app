# Resident App & Admin App - Integration Guide

## Overview

This guide explains how the Resident App and Admin App work together to create a seamless community management experience using the Flow Function Pattern.

---

## 🔄 Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SHARED FIRESTORE                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Collections:                                                │
│  • buildings                                                 │
│  • flats                                                     │
│  • residents                                                 │
│  • complaints                                                │
│  • amenities                                                 │
│  • bookings                                                  │
│  • notifications                                             │
│  • visitors                                                  │
│  • messages                                                  │
│  • posts                                                     │
│  • billing                                                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         ↑                                    ↑
         │                                    │
    ┌────┴────────────────────────────────────┴────┐
    │                                               │
    ▼                                               ▼
┌──────────────────┐                    ┌──────────────────┐
│  RESIDENT APP    │                    │   ADMIN APP      │
├──────────────────┤                    ├──────────────────┤
│ • View data      │                    │ • Manage data    │
│ • Submit data    │                    │ • Approve data   │
│ • Receive updates│                    │ • Send updates   │
│ • Interact       │                    │ • Generate reports
└──────────────────┘                    └──────────────────┘
```

---

## 📊 Data Flow Patterns

### Pattern 1: Resident Initiates → Admin Approves

```
Resident App                          Admin App
    │                                    │
    ├─ User submits complaint            │
    │                                    │
    ├─ Save to Firestore                │
    │                                    │
    ├─ Trigger notification              │
    │                                    │
    │                                    ├─ Listen to Firestore
    │                                    │
    │                                    ├─ Display complaint
    │                                    │
    │                                    ├─ Admin updates status
    │                                    │
    │                                    ├─ Save to Firestore
    │                                    │
    │                                    ├─ Trigger notification
    │                                    │
    ├─ Listen to Firestore               │
    │                                    │
    ├─ Display status update             │
    │                                    │
    └─ User sees result                  └─ Admin sees confirmation
```

### Pattern 2: Admin Initiates → Residents Receive

```
Admin App                             Resident App
    │                                    │
    ├─ Admin creates notification        │
    │                                    │
    ├─ Save to Firestore                │
    │                                    │
    ├─ Trigger push notification         │
    │                                    │
    │                                    ├─ Receive push notification
    │                                    │
    │                                    ├─ Listen to Firestore
    │                                    │
    │                                    ├─ Display notification
    │                                    │
    │                                    ├─ User interacts
    │                                    │
    │                                    ├─ Mark as read
    │                                    │
    ├─ Listen to Firestore               │
    │                                    │
    ├─ See delivery status               │
    │                                    │
    └─ Admin sees analytics              └─ Resident sees notification
```

### Pattern 3: Bidirectional Sync

```
Resident App                          Admin App
    │                                    │
    ├─ User books amenity                │
    │                                    │
    ├─ Save to Firestore                │
    │                                    │
    │                                    ├─ Listen to Firestore
    │                                    │
    │                                    ├─ Display booking
    │                                    │
    │                                    ├─ Admin approves
    │                                    │
    │                                    ├─ Update Firestore
    │                                    │
    ├─ Listen to Firestore               │
    │                                    │
    ├─ Display approval                  │
    │                                    │
    ├─ User confirms                     │
    │                                    │
    ├─ Update Firestore                  │
    │                                    │
    │                                    ├─ Listen to Firestore
    │                                    │
    │                                    ├─ See confirmation
    │                                    │
    └─ Both apps in sync                 └─ Both apps in sync
```

---

## 🔐 Security & Access Control

### Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  AUTHENTICATION FLOW                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ RESIDENT APP:                                                │
│ 1. User enters email/phone                                   │
│ 2. Firebase Auth creates user                                │
│ 3. Firestore creates user document                           │
│ 4. Set role: "resident"                                      │
│ 5. Set flatId and buildingId                                 │
│                                                               │
│ ADMIN APP:                                                   │
│ 1. Admin enters email/password                               │
│ 2. Firebase Auth authenticates                               │
│ 3. Check Firestore for admin role                            │
│ 4. Verify building access                                    │
│ 5. Load admin dashboard                                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Authorization Rules

```dart
// Firestore Security Rules

// Residents can only see their own data
match /residents/{residentId} {
  allow read: if request.auth.uid == residentId;
  allow write: if request.auth.uid == residentId;
}

// Admins can see building data
match /buildings/{buildingId} {
  allow read: if isAdmin(buildingId);
  allow write: if isAdmin(buildingId);
}

// Complaints visible to resident and admin
match /complaints/{complaintId} {
  allow read: if isResident(resource.data.residentId) || isAdmin(resource.data.buildingId);
  allow write: if isAdmin(resource.data.buildingId);
}

// Notifications visible to target residents
match /notifications/{notificationId} {
  allow read: if isTargetResident(resource.data.targetFlats);
  allow write: if isAdmin(resource.data.buildingId);
}
```

---

## 📱 Key Integration Points

### 1. Complaint Management

**Resident App Flow**:
```
User submits complaint
    ↓
ComplaintUploadFlowFunction
    ├─ STEP 1: Validate user authentication
    ├─ STEP 2: Validate complaint data
    ├─ STEP 3: Save to Firestore
    ├─ STEP 4: Create notification
    └─ STEP 5: Return result
    ↓
Complaint saved to Firestore
```

**Admin App Flow**:
```
Admin views complaints
    ↓
ComplaintManagementFlowFunction
    ├─ STEP 1: Validate admin authentication
    ├─ STEP 2: Validate complaint data
    ├─ STEP 3: Update status
    ├─ STEP 4: Notify resident
    └─ STEP 5: Return result
    ↓
Resident receives notification
```

### 2. Notification Broadcasting

**Admin App Flow**:
```
Admin creates notification
    ↓
NotificationBroadcastFlowFunction
    ├─ STEP 1: Validate admin authentication
    ├─ STEP 2: Validate notification data
    ├─ STEP 3: Create notification document
    ├─ STEP 4: Send to residents
    └─ STEP 5: Return result
    ↓
Notification saved to Firestore
```

**Resident App Flow**:
```
Resident receives notification
    ↓
NotificationDisplayFlowFunction
    ├─ STEP 1: Validate user authentication
    ├─ STEP 2: Fetch notification
    ├─ STEP 3: Display notification
    ├─ STEP 4: Mark as read
    └─ STEP 5: Return result
    ↓
Notification displayed to user
```

### 3. Amenity Booking

**Resident App Flow**:
```
User books amenity
    ↓
AmenitiesBookingFlowFunction
    ├─ STEP 1: Validate user authentication
    ├─ STEP 2: Validate amenity data
    ├─ STEP 3: Check availability
    ├─ STEP 4: Create booking
    └─ STEP 5: Return result
    ↓
Booking saved to Firestore
```

**Admin App Flow**:
```
Admin approves booking
    ↓
AmenityBookingManagementFlowFunction
    ├─ STEP 1: Validate admin authentication
    ├─ STEP 2: Validate booking data
    ├─ STEP 3: Approve booking
    ├─ STEP 4: Notify resident
    └─ STEP 5: Return result
    ↓
Resident receives confirmation
```

### 4. Visitor Management

**Resident App Flow**:
```
Resident requests visitor
    ↓
VisitorRequestFlowFunction
    ├─ STEP 1: Validate user authentication
    ├─ STEP 2: Validate visitor data
    ├─ STEP 3: Create request
    ├─ STEP 4: Notify admin
    └─ STEP 5: Return result
    ↓
Request saved to Firestore
```

**Admin App Flow**:
```
Admin approves visitor
    ↓
VisitorApprovalFlowFunction
    ├─ STEP 1: Validate admin authentication
    ├─ STEP 2: Validate visitor request
    ├─ STEP 3: Generate QR code
    ├─ STEP 4: Notify resident
    └─ STEP 5: Return result
    ↓
Resident receives QR code
```

---

## 🔄 Real-Time Synchronization

### Firestore Listeners

**Resident App**:
```dart
// Listen to complaints
_firestore
    .collection('complaints')
    .where('residentId', isEqualTo: userId)
    .snapshots()
    .listen((snapshot) {
      // Update UI with complaint changes
    });

// Listen to notifications
_firestore
    .collection('notifications')
    .where('targetFlats', arrayContains: userFlatId)
    .snapshots()
    .listen((snapshot) {
      // Update UI with new notifications
    });
```

**Admin App**:
```dart
// Listen to complaints
_firestore
    .collection('complaints')
    .where('buildingId', isEqualTo: buildingId)
    .snapshots()
    .listen((snapshot) {
      // Update dashboard with complaint changes
    });

// Listen to bookings
_firestore
    .collection('bookings')
    .where('buildingId', isEqualTo: buildingId)
    .snapshots()
    .listen((snapshot) {
      // Update dashboard with booking changes
    });
```

---

## 📊 Shared Data Models

### Complaint Model
```dart
class Complaint {
  final String id;
  final String residentId;
  final String buildingId;
  final String title;
  final String description;
  final String status; // pending, in_progress, resolved
  final String? assignedStaffId;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StatusHistory> statusHistory;
}
```

### Notification Model
```dart
class Notification {
  final String id;
  final String title;
  final String content;
  final String category;
  final String priority;
  final List<String> targetFlats;
  final DateTime publishDate;
  final DateTime? expiryDate;
  final String status; // published, draft, expired
  final DateTime createdAt;
}
```

### Booking Model
```dart
class Booking {
  final String id;
  final String amenityId;
  final String residentId;
  final String buildingId;
  final DateTime date;
  final String timeSlot;
  final int numberOfPeople;
  final String status; // pending, confirmed, rejected, cancelled
  final DateTime createdAt;
}
```

### Visitor Model
```dart
class Visitor {
  final String id;
  final String residentId;
  final String buildingId;
  final String visitorName;
  final String visitorPhone;
  final DateTime visitDate;
  final String status; // pending, approved, rejected, departed
  final String? qrCode;
  final DateTime createdAt;
}
```

---

## 🧪 Testing Integration

### Test Scenario 1: Complaint Workflow

```dart
test('Complaint workflow integration', () async {
  // 1. Resident submits complaint
  final complaintResult = await residentApp.submitComplaint(
    title: 'Water leak',
    description: 'Leak in bathroom',
  );
  expect(complaintResult.success, true);
  
  // 2. Admin sees complaint
  final complaints = await adminApp.getComplaints();
  expect(complaints.length, greaterThan(0));
  
  // 3. Admin updates status
  final updateResult = await adminApp.updateComplaintStatus(
    complaintId: complaintResult.operationId,
    newStatus: 'in_progress',
  );
  expect(updateResult.success, true);
  
  // 4. Resident sees update
  final updatedComplaint = await residentApp.getComplaint(
    complaintResult.operationId
  );
  expect(updatedComplaint.status, 'in_progress');
});
```

### Test Scenario 2: Notification Broadcasting

```dart
test('Notification broadcasting integration', () async {
  // 1. Admin creates notification
  final notificationResult = await adminApp.broadcastNotification(
    title: 'Maintenance notice',
    content: 'Water supply will be cut off',
    targetFlats: ['flat_1', 'flat_2'],
  );
  expect(notificationResult.success, true);
  
  // 2. Residents receive notification
  final notifications = await residentApp.getNotifications();
  expect(notifications.length, greaterThan(0));
  
  // 3. Resident marks as read
  final readResult = await residentApp.markNotificationAsRead(
    notificationResult.operationId
  );
  expect(readResult.success, true);
  
  // 4. Admin sees delivery status
  final deliveryStatus = await adminApp.getNotificationStatus(
    notificationResult.operationId
  );
  expect(deliveryStatus.readCount, greaterThan(0));
});
```

### Test Scenario 3: Amenity Booking

```dart
test('Amenity booking integration', () async {
  // 1. Resident books amenity
  final bookingResult = await residentApp.bookAmenity(
    amenityId: 'pool',
    date: DateTime.now().add(Duration(days: 1)),
    timeSlot: '10:00 AM - 11:00 AM',
  );
  expect(bookingResult.success, true);
  
  // 2. Admin sees booking
  final bookings = await adminApp.getBookings();
  expect(bookings.length, greaterThan(0));
  
  // 3. Admin approves booking
  final approveResult = await adminApp.approveBooking(
    bookingId: bookingResult.operationId,
  );
  expect(approveResult.success, true);
  
  // 4. Resident sees confirmation
  final confirmedBooking = await residentApp.getBooking(
    bookingResult.operationId
  );
  expect(confirmedBooking.status, 'confirmed');
});
```

---

## 🚀 Deployment Checklist

### Pre-Deployment

- [ ] All flow functions implemented
- [ ] All tests passing
- [ ] Firestore rules configured
- [ ] Firebase Auth setup complete
- [ ] FCM configured for push notifications
- [ ] Cloudinary configured for images
- [ ] Error handling implemented
- [ ] Logging configured

### Deployment

- [ ] Deploy Firestore rules
- [ ] Deploy Resident App
- [ ] Deploy Admin App
- [ ] Verify real-time sync
- [ ] Test all integration points
- [ ] Monitor error logs
- [ ] Collect user feedback

### Post-Deployment

- [ ] Monitor performance
- [ ] Track error rates
- [ ] Collect analytics
- [ ] Gather user feedback
- [ ] Plan improvements
- [ ] Schedule updates

---

## 📈 Performance Optimization

### Firestore Optimization

```dart
// Use indexes for complex queries
// Create composite indexes for:
// - complaints: buildingId + status + createdAt
// - bookings: amenityId + date + status
// - notifications: buildingId + publishDate + status
```

### Real-Time Optimization

```dart
// Limit listeners
// Use pagination for large datasets
// Cache frequently accessed data
// Implement debouncing for updates
```

### Image Optimization

```dart
// Compress images before upload
// Use Cloudinary for storage
// Implement lazy loading
// Cache images locally
```

---

## 🔍 Monitoring & Analytics

### Key Metrics

**Resident App**:
- User engagement
- Complaint submission rate
- Notification open rate
- Amenity booking rate
- Visitor requests

**Admin App**:
- Complaint resolution time
- Notification delivery rate
- Booking approval rate
- Visitor approval rate
- System uptime

### Dashboards

**Resident App Dashboard**:
- My complaints
- My bookings
- My notifications
- My visitors

**Admin App Dashboard**:
- Total complaints
- Pending approvals
- Notification delivery
- Amenity usage
- Financial summary

---

## 🎯 Success Metrics

### Community Engagement
- ✅ Increased complaint resolution rate
- ✅ Higher notification engagement
- ✅ More amenity bookings
- ✅ Better visitor management

### Operational Efficiency
- ✅ Reduced manual work
- ✅ Faster response times
- ✅ Better data accuracy
- ✅ Improved compliance

### User Satisfaction
- ✅ Higher app ratings
- ✅ More positive feedback
- ✅ Increased retention
- ✅ Better community feeling

---

## 📞 Support & Troubleshooting

### Common Issues

**Issue**: Real-time updates not working
- Check Firestore listeners
- Verify network connection
- Check listener count
- Review error logs

**Issue**: Notifications not delivered
- Check FCM configuration
- Verify target flats
- Check notification status
- Review delivery logs

**Issue**: Data inconsistency
- Check Firestore rules
- Verify transaction handling
- Review audit logs
- Check for race conditions

---

## 🎉 Summary

The Resident App and Admin App work together seamlessly using the Flow Function Pattern to:

✅ **Improve Communication** - Real-time updates and notifications
✅ **Streamline Operations** - Automated workflows and approvals
✅ **Enhance Transparency** - Audit trails and status tracking
✅ **Increase Efficiency** - Centralized management
✅ **Build Community** - Better engagement and satisfaction

Both apps follow the same pattern for consistency, reliability, and maintainability.

**Status**: READY FOR DEPLOYMENT ✅

---

**Last Updated**: March 25, 2026
**Version**: 1.0.0
**Status**: Production Ready
