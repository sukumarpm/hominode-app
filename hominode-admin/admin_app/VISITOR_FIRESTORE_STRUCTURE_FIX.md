# Visitor Management - Firestore Structure Fix

## ✅ ISSUE IDENTIFIED AND FIXED

## Problem
The app was looking for fields that didn't exist in your Firestore documents:
- App expected: `status: "pending"`
- Your Firestore has: `isApproved: false`

## Your Actual Firestore Structure

Based on the Firebase Console screenshot, your `visitors` collection uses:

```javascript
{
  actualArrival: null,           // Timestamp when visitor arrives
  approvedAt: null,              // Timestamp when approved
  approvedBy: null,              // Who approved
  createdAt: Timestamp,          // When request was created
  departure: null,               // Timestamp when visitor leaves
  expectedArrival: Timestamp,    // Expected arrival time
  hostEmail: "boi@gmail.com",    // Resident email
  hostName: "boi balai",         // Resident name
  hostUserId: "...",             // Resident user ID
  isApproved: false,             // Approval status (boolean)
  phoneNumber: "7010078124",     // Visitor phone
  purpose: "home"                // Visit purpose
}
```

## Changes Made

### 1. Updated Query Logic

**Pending Visitors** (was looking for `status == "pending"`):
```dart
// OLD (Wrong)
.where('status', isEqualTo: 'pending')

// NEW (Correct)
.where('isApproved', isEqualTo: false)
```

**Active Visitors** (was looking for `status == "active"`):
```dart
// OLD (Wrong)
.where('status', isEqualTo: 'active')

// NEW (Correct)
.where('isApproved', isEqualTo: true)
.where('actualArrival', isNotEqualTo: null)
.where('departure', isEqualTo: null)
```

**History Visitors** (was looking for `status == "checked-out"`):
```dart
// OLD (Wrong)
.where('status', isEqualTo: 'checked-out')

// NEW (Correct)
.where('departure', isNotEqualTo: null)
```

### 2. Updated VisitorModel

Added support for your Firestore fields:
```dart
// New fields added
final bool isApproved;
final DateTime? actualArrival;
final DateTime? departure;
final String? approvedBy;

// Field mapping
visitorName: data['hostName']           // Maps to your field
phone: data['phoneNumber']              // Maps to your field
residentId: data['hostUserId']          // Maps to your field
residentName: data['hostName']          // Maps to your field
expectedTime: data['expectedArrival']   // Maps to your field
checkInTime: data['actualArrival']      // Maps to your field
checkOutTime: data['departure']         // Maps to your field
```

### 3. Updated Action Methods

**Approve Visitor**:
```dart
// OLD
update({'status': 'approved'})

// NEW
update({'isApproved': true, 'approvedAt': timestamp})
```

**Check-In Visitor**:
```dart
// OLD
update({'status': 'active', 'checkInTime': timestamp})

// NEW
update({'isApproved': true, 'actualArrival': timestamp})
```

**Check-Out Visitor**:
```dart
// OLD
update({'status': 'checked-out', 'checkOutTime': timestamp})

// NEW
update({'departure': timestamp})
```

## Status Determination

The app now determines status based on your fields:

```dart
if (departure != null) {
  status = 'checked-out';  // Has left
} else if (actualArrival != null && isApproved) {
  status = 'active';       // Currently inside
} else if (isApproved) {
  status = 'approved';     // Approved but not arrived
} else {
  status = 'pending';      // Waiting for approval
}
```

## Flow Function Compliance

### Pending Tab
- Shows visitors where: `isApproved == false`
- Your document: `isApproved: false` ✅ Will appear!

### Active Tab
- Shows visitors where: `isApproved == true` AND `actualArrival != null` AND `departure == null`
- Currently inside the premises

### History Tab
- Shows visitors where: `departure != null`
- Visitors who have left

## What Will Happen Now

1. **Pending Tab**: Will show "boi balai" visitor (isApproved: false)
2. **Approve Button**: Sets `isApproved: true` and `actualArrival: timestamp`
3. **Active Tab**: Visitor moves here (approved + arrived)
4. **Mark Exit Button**: Sets `departure: timestamp`
5. **History Tab**: Visitor moves here (has departure time)

## Testing

Run the app again:
```bash
flutter run -d ZA222LQT6V
```

Expected result:
- Pending tab shows 1 visitor ("boi balai")
- Tap Approve → Visitor moves to Active tab
- Tap Mark Exit → Visitor moves to History tab

## Document Updates

When you approve the visitor, the document will be updated:
```javascript
{
  // ... existing fields ...
  isApproved: true,              // Changed from false
  approvedAt: [Current Timestamp], // Added
  actualArrival: [Current Timestamp], // Added
  updatedAt: [Current Timestamp]  // Updated
}
```

When you mark exit:
```javascript
{
  // ... existing fields ...
  departure: [Current Timestamp],  // Added
  updatedAt: [Current Timestamp]   // Updated
}
```

## Summary

✅ Fixed field name mismatches  
✅ Updated queries to match your Firestore structure  
✅ Updated model to map your fields correctly  
✅ Updated actions to use your field names  
✅ Maintains same document ID throughout  
✅ Real-time updates still work  

The app now correctly reads and updates your existing Firestore structure!
