# Complaint Status Update Fix

## Problem
When admin assigns staff to a complaint, the status remains "pending" instead of changing to "inProgress". The resident app shows "Pending" badge even though staff is assigned.

## Root Cause
The admin panel is updating the complaint document but not setting the `status` field to "inProgress" when assigning staff.

## Solution

### Option 1: Fix Admin Panel (Recommended)
Update the admin panel to set status when assigning staff:

```dart
// In admin panel - when assigning staff
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

### Option 2: Use Firestore Trigger (Cloud Function)
Create a Cloud Function that automatically updates status when staff is assigned:

```javascript
exports.updateComplaintStatus = functions.firestore
  .document('complaints/{complaintId}')
  .onUpdate((change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    // If staff was just assigned
    if (newData.assignedStaffId && !oldData.assignedStaffId) {
      // Update status to inProgress
      return change.after.ref.update({
        status: 'inProgress',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    return null;
  });
```

### Option 3: Real-time Updates in Resident App
Use StreamBuilder to listen for real-time changes:

```dart
// In complaints_screen.dart
StreamBuilder<List<Complaint>>(
  stream: ComplaintsService().streamComplaints(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return _buildComplaintsList(snapshot.data!);
    }
    return CircularProgressIndicator();
  },
)
```

## Quick Fix for Testing

### Manual Firestore Update
1. Go to Firebase Console
2. Open Firestore Database
3. Find the complaint document
4. Update the `status` field:
   - Change from: `"pending"`
   - Change to: `"inProgress"`
5. Save
6. Pull to refresh in app

### Expected Firestore Document
```json
{
  "id": "complaint123",
  "title": "work work",
  "description": "qqqqqqqqqqqq",
  "category": "plumbing",
  "status": "inProgress",  // ← Should be this, not "pending"
  "assignedTo": "preetham",
  "technicianPhone": "+91 1234567890",
  "assignedStaffId": "staff123",
  "assignedStaffRole": "electrician",
  "userId": "user123",
  "createdAt": "2024-02-20T07:23:00Z",
  "updatedAt": "2024-02-20T07:24:00Z"
}
```

## Verification Steps

### 1. Check Firestore Document
```
complaints/{complaintId}
  ├─ assignedTo: "preetham"
  ├─ assignedStaffId: "staff123"
  └─ status: "inProgress"  ← Must be this
```

### 2. Check Admin Panel Code
Look for where staff is assigned and ensure status is updated:

```dart
// WRONG - Missing status update
await firestore.collection('complaints').doc(id).update({
  'assignedTo': staffName,
  'assignedStaffId': staffId,
});

// CORRECT - Includes status update
await firestore.collection('complaints').doc(id).update({
  'assignedTo': staffName,
  'assignedStaffId': staffId,
  'status': 'inProgress',  // ← This is required
});
```

### 3. Test in Resident App
1. Pull to refresh complaints list
2. Complaint should show:
   - Orange "In Progress" badge
   - Staff details card
   - Timeline with 4 steps
   - "Chat With Technician" button

## Status Values Reference

```dart
enum ComplaintStatus {
  pending,      // "pending" in Firestore
  inProgress,   // "inProgress" in Firestore
  completed     // "completed" in Firestore
}
```

## Admin Panel Update Example

```dart
// In admin panel - Update complaint dialog/modal
Future<void> assignStaffToComplaint({
  required String complaintId,
  required String staffId,
  required String staffName,
  required String staffPhone,
  required String staffRole,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('complaints')
        .doc(complaintId)
        .update({
      'assignedTo': staffName,
      'technicianPhone': staffPhone,
      'assignedStaffId': staffId,
      'assignedStaffRole': staffRole,
      'status': 'inProgress',  // ← CRITICAL: Update status
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ Staff assigned and status updated to inProgress');
  } catch (e) {
    print('❌ Error assigning staff: $e');
    rethrow;
  }
}
```

## Debugging

### Check Current Status
```dart
// In resident app - Add debug logging
print('Complaint ID: ${complaint.id}');
print('Status: ${complaint.status}');
print('Assigned To: ${complaint.assignedTo}');
print('Staff ID: ${complaint.assignedStaffId}');
```

### Expected Console Output
```
🔵 Fetching complaints...
✅ Fetched 1 complaints
Complaint ID: dAONdk0i0cHokqz8w3ma
Status: ComplaintStatus.inProgress  ← Should be this
Assigned To: preetham
Staff ID: staff123
```

### If Status is Still Pending
```
Complaint ID: dAONdk0i0cHokqz8w3ma
Status: ComplaintStatus.pending  ← Problem!
Assigned To: preetham
Staff ID: staff123
```

This means Firestore document has `status: "pending"` even though staff is assigned.

## Immediate Fix Steps

### Step 1: Update Firestore Manually
```
1. Firebase Console → Firestore
2. Find complaint: dAONdk0i0cHokqz8w3ma
3. Edit document
4. Change status: "pending" → "inProgress"
5. Save
```

### Step 2: Pull to Refresh in App
```
1. Open Complaints screen
2. Pull down to refresh
3. Status should now show "In Progress"
4. Staff details should appear
```

### Step 3: Fix Admin Panel
```
1. Find staff assignment code in admin panel
2. Add status update line
3. Test by assigning staff to new complaint
4. Verify status changes automatically
```

## Testing Checklist

- [ ] Firestore document has correct status
- [ ] Admin panel updates status when assigning
- [ ] Resident app shows "In Progress" badge
- [ ] Staff details appear in list
- [ ] Staff details appear in modal
- [ ] Timeline shows 4 steps
- [ ] "Chat With Technician" button shows
- [ ] Cannot delete in-progress complaint

## Status Flow Diagram

```
CREATE COMPLAINT
      ↓
status: "pending"
assignedStaffId: null
      ↓
ADMIN ASSIGNS STAFF
      ↓
status: "inProgress"  ← MUST UPDATE THIS
assignedStaffId: "staff123"
assignedTo: "preetham"
      ↓
STAFF COMPLETES WORK
      ↓
status: "completed"
```

## Common Mistakes

### ❌ Wrong: Only updating staff fields
```dart
update({
  'assignedTo': staffName,
  'assignedStaffId': staffId,
  // Missing status update!
});
```

### ✅ Correct: Updating staff AND status
```dart
update({
  'assignedTo': staffName,
  'assignedStaffId': staffId,
  'status': 'inProgress',  // ← Required
});
```

## Summary

The issue is that the admin panel is not updating the `status` field when assigning staff. The fix is simple:

1. **Immediate**: Manually update status in Firestore to "inProgress"
2. **Permanent**: Update admin panel code to set status when assigning staff
3. **Optional**: Add Cloud Function to auto-update status
4. **Enhancement**: Use real-time updates in resident app

Once the status field is correctly set to "inProgress", the resident app will automatically show the correct UI with staff details and timeline.
