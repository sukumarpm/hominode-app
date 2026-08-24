# How to Add Test Visitors (Proper Way)

## Overview
The Security App now only works with real Firebase data. Test data generation has been removed. This guide shows you how to add test visitors properly.

## Method 1: Using Firebase Console (Recommended for Testing)

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to Firestore Database
4. Click on the `visitors` collection

### Step 2: Add a Document
Click "Add document" and use this structure:

**Document ID:** Auto-generate

**Fields:**
```
visitorName (string): "John Doe"
phone (string): "+91 98765 43210"
residentId (string): "resident_123"
residentName (string): "Amit Kumar"
flatId (string): "flat_a301"
flatLabel (string): "A-301"
purpose (string): "Personal Visit"
expectedTime (timestamp): [Current time]
isApproved (boolean): false
actualArrival (timestamp): null
departure (timestamp): null
adminId (string): "admin_test"
approvedBy (string): null
createdAt (timestamp): [Current time]
approvedAt (timestamp): null
rejectedAt (timestamp): null
updatedAt (timestamp): [Current time]
```

### Step 3: Verify in App
1. Open Security App
2. Go to Visitor Management
3. Check Pending tab
4. You should see "John Doe"

## Method 2: Using Resident App (Production Way)

### Step 1: Open Resident App
1. Login as a resident
2. Navigate to "Request Visitor"

### Step 2: Fill Visitor Details
- Visitor Name: John Doe
- Phone Number: +91 98765 43210
- Purpose: Personal Visit
- Expected Time: Select date/time

### Step 3: Submit Request
- Tap "Submit Request"
- Visitor request is created in Firestore

### Step 4: Check Security App
- Open Security App
- Go to Visitor Management
- Visitor appears in Pending tab

## Method 3: Using Admin App

### Step 1: Open Admin App
1. Login as admin
2. Navigate to "Visitor Management"

### Step 2: Create Pre-Approved Visitor
- Add visitor details
- Set approval status
- Visitor is created in Firestore

### Step 3: Check Security App
- Visitor appears in appropriate tab based on status

## Quick Test Data Examples

### Example 1: Pending Visitor
```json
{
  "visitorName": "Rahul Sharma",
  "phone": "+91 98765 11111",
  "residentName": "Priya Patel",
  "flatLabel": "B-205",
  "purpose": "Delivery",
  "expectedTime": "2026-03-08T10:00:00Z",
  "isApproved": false,
  "actualArrival": null,
  "departure": null,
  "createdAt": "2026-03-08T09:00:00Z"
}
```
**Will appear in:** Pending Tab

### Example 2: Active Visitor (Already Inside)
```json
{
  "visitorName": "Amit Kumar",
  "phone": "+91 98765 22222",
  "residentName": "Rajesh Singh",
  "flatLabel": "C-102",
  "purpose": "Personal Visit",
  "expectedTime": "2026-03-08T11:00:00Z",
  "isApproved": true,
  "actualArrival": "2026-03-08T11:15:00Z",
  "departure": null,
  "approvedAt": "2026-03-08T11:10:00Z",
  "createdAt": "2026-03-08T10:00:00Z"
}
```
**Will appear in:** Active Tab

### Example 3: Completed Visit
```json
{
  "visitorName": "Sneha Reddy",
  "phone": "+91 98765 33333",
  "residentName": "Vikram Mehta",
  "flatLabel": "A-401",
  "purpose": "Meeting",
  "expectedTime": "2026-03-07T14:00:00Z",
  "isApproved": true,
  "actualArrival": "2026-03-07T14:05:00Z",
  "departure": "2026-03-07T16:30:00Z",
  "approvedAt": "2026-03-07T14:00:00Z",
  "createdAt": "2026-03-07T13:00:00Z"
}
```
**Will appear in:** History Tab

## Testing the Complete Flow

### Test 1: Approve Flow
1. Add a pending visitor (isApproved: false, actualArrival: null)
2. Open Security App → Visitor Management → Pending tab
3. Tap "Approve" on the visitor
4. Visitor moves to Active tab automatically
5. Check Firebase - actualArrival timestamp is set

### Test 2: Exit Flow
1. With visitor in Active tab
2. Tap "Mark Exit"
3. Visitor moves to History tab automatically
4. Check Firebase - departure timestamp is set

### Test 3: Reject Flow
1. Add a pending visitor
2. Tap "Reject"
3. Visitor disappears from all tabs
4. Check Firebase - rejectedAt timestamp is set

### Test 4: QR Scanner Flow
1. Add a pending visitor and note the document ID
2. Generate QR code with the document ID
3. Open Security App → Scan QR
4. Scan the QR code
5. Visitor is checked in (moves to Active)
6. Scan again to check out (moves to History)

## Bulk Test Data Script

If you need multiple test visitors, use this Firebase Admin SDK script:

```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

const testVisitors = [
  {
    visitorName: "John Doe",
    phone: "+91 98765 11111",
    residentName: "Amit Kumar",
    flatLabel: "A-101",
    purpose: "Personal Visit",
    isApproved: false,
    actualArrival: null,
    departure: null
  },
  {
    visitorName: "Jane Smith",
    phone: "+91 98765 22222",
    residentName: "Priya Patel",
    flatLabel: "B-205",
    purpose: "Delivery",
    isApproved: true,
    actualArrival: admin.firestore.Timestamp.now(),
    departure: null
  },
  // Add more as needed
];

async function addTestVisitors() {
  for (const visitor of testVisitors) {
    await db.collection('visitors').add({
      ...visitor,
      adminId: "admin_test",
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    });
  }
  console.log('Test visitors added!');
}

addTestVisitors();
```

## Important Notes

1. **No Status Field**: The app determines status automatically based on timestamps:
   - Pending: `actualArrival == null`
   - Active: `actualArrival != null && departure == null`
   - History: `departure != null`

2. **Required Fields**: Always include:
   - visitorName, phone, residentName, flatLabel, purpose
   - isApproved, actualArrival, departure
   - createdAt, updatedAt

3. **Timestamps**: Use Firestore Timestamp format, not strings

4. **Real-time Updates**: Changes in Firebase appear instantly in the app

5. **Search**: All fields are searchable (name, phone, flat, resident, purpose)

## Troubleshooting

**Visitor not appearing:**
- Check isApproved and timestamp fields match the tab logic
- Verify adminId matches (if filtering by admin)
- Check Firestore rules allow read access

**Visitor in wrong tab:**
- Verify timestamp fields (actualArrival, departure)
- Check isApproved boolean value

**Real-time updates not working:**
- Check internet connection
- Verify Firestore listeners are active
- Check Firebase console for errors

## Status
✅ Test data generation removed
✅ Only real Firebase data supported
✅ Multiple methods to add test data
✅ Complete flow testing possible

**Last Updated:** March 8, 2026
