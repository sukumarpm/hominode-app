# Complaint Status Synchronization Issue

## Problem
Complaints marked as "Resolved" in the admin app are not moving to the History tab in the resident app. They remain in the Active tab with "Pending" status even after being resolved.

## Root Cause
The admin app and resident app are using different status values in Firestore:

### Resident App Expected Values
```dart
enum ComplaintStatus { 
  pending,      // "pending"
  inProgress,   // "inProgress"
  completed     // "completed"
}
```

### Admin App Likely Using
- "resolved" or "closed" instead of "completed"
- Different field name for status
- Additional status field (like "isResolved")

## Evidence from Screenshots
1. **Resident App**: Shows complaint as "Pending"
2. **Admin App**: Shows "Complaint Resolved" with completion date
3. **Firestore**: Status field is likely "resolved" not "completed"

## Solution Options

### Option 1: Update Resident App to Support Multiple Status Values (RECOMMENDED)
Update the resident app to recognize both "completed" and "resolved" as completed status.

### Option 2: Update Admin App
Change the admin app to use "completed" instead of "resolved" when marking complaints as done.

### Option 3: Add Status Mapping
Create a mapping layer that converts between admin and resident status values.

## Implementation - Option 1 (Recommended)

This solution makes the resident app more flexible by accepting multiple status values for completed complaints.

### Files to Modify

#### 1. `lib/src/models/complaint.dart`
Add support for "resolved" status by treating it as "completed":

```dart
enum ComplaintStatus { 
  pending, 
  inProgress, 
  completed,
  resolved  // Add this
}
```

Or better - keep the enum as is and handle the mapping in the service.

#### 2. `lib/src/services/complaint_firestore_service.dart`
Update the status parsing to handle multiple values:

```dart
// Parse status enum with support for "resolved" and "closed"
ComplaintStatus status;
try {
  final statusString = data['status'] as String?;
  print('📊 Status string: "$statusString"');
  
  // Map different status values to our enum
  if (statusString == 'resolved' || statusString == 'closed' || statusString == 'completed') {
    status = ComplaintStatus.completed;
  } else if (statusString == 'inProgress' || statusString == 'in_progress') {
    status = ComplaintStatus.inProgress;
  } else {
    status = ComplaintStatus.pending;
  }
  
  print('✅ Parsed status: $status');
} catch (e) {
  print('❌ Error parsing status: $e');
  status = ComplaintStatus.pending;
}
```

## Quick Fix for Testing

To verify this is the issue, check the Firestore console:

1. Open Firebase Console
2. Go to Firestore Database
3. Open the `complaints` collection
4. Find the resolved complaint
5. Check the `status` field value

**Expected**: Should be "completed"
**Actual**: Likely "resolved" or "closed"

## Firestore Status Field Values

The admin app should use these exact values:

| Admin Action | Firestore Value | Resident App Display |
|--------------|----------------|---------------------|
| Create complaint | `pending` | Active tab - Pending |
| Assign staff | `inProgress` | Active tab - In Progress |
| Mark resolved | `completed` | History tab - Completed |

## Testing After Fix

1. Create a new complaint in resident app
2. Assign staff from admin app → Should show "In Progress" in resident app
3. Mark as resolved in admin app → Should move to History tab in resident app
4. Verify timeline updates in real-time

## Alternative: Check for Additional Fields

The admin app might be using additional fields:

```javascript
// Admin app might be setting:
{
  status: "pending",  // Never changes
  isResolved: true,   // Additional field
  resolvedAt: timestamp,
  resolvedBy: "staff_id"
}
```

If this is the case, update the filtering logic in `complaints_screen.dart`:

```dart
// Get completed complaints (history)
List<Complaint> get _completedComplaints => _complaints
    .where((c) => 
      c.status == ComplaintStatus.completed || 
      c.isResolved == true  // Add this if admin uses isResolved field
    )
    .toList();
```

---
**Status**: ⚠️ Needs Investigation
**Priority**: High
**Impact**: Complaints don't move to history after resolution
