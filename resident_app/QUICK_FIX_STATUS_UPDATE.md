# Quick Fix - Complaint Status Not Updating

## Problem
Staff is assigned but status still shows "Pending" instead of "In Progress".

## Root Cause
Admin panel is not updating the `status` field when assigning staff.

## Immediate Fix (2 minutes)

### Step 1: Update Firestore Manually
1. Open Firebase Console
2. Go to Firestore Database
3. Find collection: `complaints`
4. Find document: `dAONdk0i0cHokqz8w3ma` (or your complaint ID)
5. Click Edit
6. Find field: `status`
7. Change value from: `"pending"` to: `"inProgress"`
8. Click Save

### Step 2: Refresh App
1. Open resident app
2. Go to Complaints screen
3. Pull down to refresh
4. ✅ Status should now show "In Progress" (orange)
5. ✅ Staff details should appear
6. ✅ Timeline should show 4 steps

## Permanent Fix - Update Admin Panel

### Find the Staff Assignment Code
Look for where admin assigns staff (probably in admin panel):

```dart
// Current code (WRONG - missing status)
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'assignedTo': staffName,
  'technicianPhone': staffPhone,
  'assignedStaffId': staffId,
  'assignedStaffRole': staffRole,
  // Missing status update!
});
```

### Add Status Update
```dart
// Fixed code (CORRECT - includes status)
await FirebaseFirestore.instance
    .collection('complaints')
    .doc(complaintId)
    .update({
  'assignedTo': staffName,
  'technicianPhone': staffPhone,
  'assignedStaffId': staffId,
  'assignedStaffRole': staffRole,
  'status': 'inProgress',  // ← ADD THIS LINE
  'updatedAt': FieldValue.serverTimestamp(),
});
```

## Real-time Updates (Bonus)

I've added real-time updates to the resident app. Now when admin changes status, the app will automatically update without needing to refresh!

### How It Works
```dart
// Old way - manual refresh needed
_loadComplaints(); // Only loads once

// New way - automatic updates
_service.streamComplaints().listen((complaints) {
  // Updates automatically when Firestore changes!
  setState(() => _complaints = complaints);
});
```

## Verification

### Check Firestore Document
```json
{
  "id": "dAONdk0i0cHokqz8w3ma",
  "title": "work work",
  "status": "inProgress",  // ← Must be this
  "assignedTo": "preetham",
  "assignedStaffId": "staff123"
}
```

### Check Resident App
Should show:
- 🟠 Orange "In Progress" badge
- Staff card with name and phone
- Timeline with 4 steps (3 done, 1 pending)
- "Chat With Technician" button

## Status Values

```
"pending"     → Red badge, no staff
"inProgress"  → Orange badge, staff details shown
"completed"   → Green badge, success message
```

## Testing

### Test 1: Manual Update
1. Update status in Firestore to "inProgress"
2. Pull to refresh in app
3. ✅ Should show orange badge and staff details

### Test 2: Admin Assignment
1. Create new complaint (status: "pending")
2. Admin assigns staff
3. Admin panel should update status to "inProgress"
4. Resident app auto-updates (no refresh needed!)
5. ✅ Should show orange badge and staff details

### Test 3: Mark as Resolved
1. Admin marks complaint as resolved
2. Status changes to "completed"
3. Resident app auto-updates
4. ✅ Should show green badge and success message

## Common Issues

### Issue: Status still shows "Pending"
**Solution**: Check Firestore - status field must be "inProgress" not "pending"

### Issue: Staff details not showing
**Solution**: Check that `assignedStaffId` field exists and matches a staff document

### Issue: App doesn't auto-update
**Solution**: Pull to refresh, or restart app

## Summary

1. **Quick Fix**: Manually update status in Firestore to "inProgress"
2. **Permanent Fix**: Update admin panel to set status when assigning
3. **Bonus**: Real-time updates now enabled in resident app

Once status is correctly set, everything will work automatically!
