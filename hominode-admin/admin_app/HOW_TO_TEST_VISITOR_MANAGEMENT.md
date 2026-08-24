# How to Test Visitor Management

## Quick Test Guide

The Visitor Management screen is working correctly. Here's how to test it:

## Option 1: Add Test Data via Firebase Console (Fastest)

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project: `lyvo-app-9f0ca`
3. Click "Firestore Database" in left menu

### Step 2: Create Visitor Document
1. Find or create collection named: `visitors`
2. Click "Add Document"
3. Use "Auto-ID" or enter custom ID
4. Add these fields:

| Field | Type | Value |
|-------|------|-------|
| visitorName | string | John Doe |
| phone | string | +91 98765 43210 |
| residentId | string | res001 |
| residentName | string | Amit Kumar |
| flatId | string | flat001 |
| flatLabel | string | A-101 |
| purpose | string | Personal Visit |
| status | string | pending |
| createdAt | timestamp | (Click "Set to current time") |
| updatedAt | timestamp | (Click "Set to current time") |

5. Click "Save"

### Step 3: Check App
1. Open Visitor Management screen in app
2. Go to "Pending" tab
3. **Result**: You should see "John Doe" visitor immediately!

### Step 4: Test Actions
1. Tap "Approve" button
2. **Result**: Visitor moves to "Active" tab
3. Go back to Firebase Console
4. **Result**: Document status changed to "active"

## Option 2: Test with Multiple Visitors

Add 3 visitors with different statuses:

### Visitor 1 - Pending
```json
{
  "visitorName": "Sarah Smith",
  "phone": "+91 98765 43211",
  "residentId": "res002",
  "residentName": "Priya Sharma",
  "flatId": "flat002",
  "flatLabel": "A-102",
  "purpose": "Delivery",
  "status": "pending",
  "createdAt": [Current Timestamp],
  "updatedAt": [Current Timestamp]
}
```

### Visitor 2 - Active
```json
{
  "visitorName": "Mike Johnson",
  "phone": "+91 98765 43212",
  "residentId": "res003",
  "residentName": "Rahul Verma",
  "flatId": "flat003",
  "flatLabel": "B-201",
  "purpose": "Guest",
  "status": "active",
  "createdAt": [1 hour ago],
  "checkInTime": [30 minutes ago],
  "updatedAt": [Current Timestamp]
}
```

### Visitor 3 - History
```json
{
  "visitorName": "Emma Wilson",
  "phone": "+91 98765 43213",
  "residentId": "res004",
  "residentName": "Sneha Patel",
  "flatId": "flat004",
  "flatLabel": "B-202",
  "purpose": "Maintenance",
  "status": "checked-out",
  "createdAt": [Yesterday],
  "checkInTime": [Yesterday 10 AM],
  "checkOutTime": [Yesterday 11 AM],
  "updatedAt": [Current Timestamp]
}
```

**Result**: 
- Pending tab: 1 visitor (Sarah)
- Active tab: 1 visitor (Mike)
- History tab: 1 visitor (Emma)

## Option 3: Test Real-Time Updates

### Test A: Auto-Refresh
1. Open app on Pending tab
2. Keep app open
3. In Firebase Console, add a new visitor with status "pending"
4. **Result**: New visitor appears in app WITHOUT refreshing!

### Test B: Status Change
1. Open app on Pending tab
2. In Firebase Console, change a visitor's status from "pending" to "active"
3. **Result**: Visitor disappears from Pending and appears in Active!

### Test C: Multiple Devices
1. Open app on Device A
2. Open app on Device B
3. On Device A, approve a visitor
4. **Result**: Device B sees the change immediately!

## Option 4: Test Search

1. Add 5+ visitors with different names
2. In app, type in search bar:
   - Type "John" → Shows only John Doe
   - Type "A-101" → Shows visitors for flat A-101
   - Type "9876" → Shows visitors with that phone number
3. **Result**: Search filters work instantly

## Option 5: Test Actions

### Test Approve
1. Add visitor with status "pending"
2. In app, tap "Approve"
3. Check Firebase Console
4. **Result**: 
   - Status changed to "active"
   - `approvedAt` timestamp added
   - `checkInTime` timestamp added
   - Visitor moved to Active tab

### Test Reject
1. Add visitor with status "pending"
2. In app, tap "Reject"
3. Check Firebase Console
4. **Result**:
   - Status changed to "rejected"
   - `rejectedAt` timestamp added
   - Visitor removed from Pending tab

### Test Mark Exit
1. Add visitor with status "active"
2. In app, tap "Mark Exit"
3. Check Firebase Console
4. **Result**:
   - Status changed to "checked-out"
   - `checkOutTime` timestamp added
   - Visitor moved to History tab

## Expected Console Logs

When you open Visitor Management screen:
```
I/flutter: VisitorService: Fetching pending visitors
I/flutter: VisitorService: Received 1 pending visitors
I/flutter: VisitorService: Fetching active visitors
I/flutter: VisitorService: Received 1 active visitors
I/flutter: VisitorService: Fetching history visitors
I/flutter: VisitorService: Received 1 history visitors
```

When you approve a visitor:
```
I/flutter: VisitorService: Approving visitor - [document_id]
I/flutter: VisitorService: Visitor approved successfully
I/flutter: VisitorService: Checking in visitor - [document_id]
I/flutter: VisitorService: Visitor checked in successfully
I/flutter: VisitorService: Received 0 pending visitors  // Moved out
I/flutter: VisitorService: Received 2 active visitors   // Moved in
```

## Verification Checklist

After testing, verify:

- [ ] Pending tab shows visitors with status "pending"
- [ ] Active tab shows visitors with status "active"
- [ ] History tab shows visitors with status "checked-out"
- [ ] Approve button moves visitor from Pending to Active
- [ ] Reject button removes visitor from Pending
- [ ] Mark Exit button moves visitor from Active to History
- [ ] Search filters work across all fields
- [ ] Real-time updates work (no refresh needed)
- [ ] Empty states show when no data exists
- [ ] Firebase Console shows same document ID was updated

## Common Issues

### Issue: "I added data but nothing appears"
**Check**:
1. Is the collection named exactly `visitors`? (lowercase, plural)
2. Does the document have a `status` field?
3. Is the status value exactly "pending", "active", or "checked-out"?
4. Is the app connected to internet?
5. Check console logs for errors

### Issue: "Actions don't work"
**Check**:
1. Firestore rules allow write access
2. Internet connection is active
3. Check console logs for error messages

### Issue: "Real-time updates don't work"
**Check**:
1. App is still running (not closed)
2. Internet connection is stable
3. Firestore rules allow read access

## Quick Firebase Console Access

1. **URL**: https://console.firebase.google.com/project/lyvo-app-9f0ca/firestore
2. **Collection**: `visitors`
3. **Action**: Click "Add Document"
4. **Fields**: Copy from examples above

## Summary

The Visitor Management screen is **fully functional**. It:
- ✅ Fetches from Firestore `visitors` collection
- ✅ Updates same document ID
- ✅ Shows real-time updates
- ✅ Handles all status transitions correctly

Just add data to Firestore and it will work immediately!
