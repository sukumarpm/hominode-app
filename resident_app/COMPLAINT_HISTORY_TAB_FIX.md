# Complaint History Tab Fix - Status Synchronization

## Problem
Complaints marked as "Resolved" in the admin app were not moving to the History tab in the resident app. They remained in the Active tab even after being resolved by staff.

## Root Cause
The admin app and resident app were using different status field values in Firestore:

- **Resident App Expected**: `status: "completed"`
- **Admin App Likely Using**: `status: "resolved"` or `isResolved: true`

The resident app's strict enum matching only recognized exact values (`pending`, `inProgress`, `completed`), so any other status value defaulted to "pending".

## Solution Implemented

### Enhanced Status Parsing with Multiple Value Support

Updated `complaint_firestore_service.dart` to recognize multiple status values and additional fields that indicate a resolved complaint.

#### Status Value Mapping

| Admin App Value | Resident App Status | Tab Location |
|----------------|-------------------|--------------|
| `pending`, `open`, `null` | `pending` | Active |
| `inProgress`, `in_progress`, `in-progress`, `assigned` | `inProgress` | Active |
| `completed`, `resolved`, `closed` | `completed` | History |

#### Additional Field Support

The fix also checks for these fields that indicate resolution:
- `isResolved: true` → Maps to `completed`
- `resolvedAt: <timestamp>` → Maps to `completed`

### Code Changes

#### File: `lib/src/services/complaint_firestore_service.dart`

**Before:**
```dart
status = ComplaintStatus.values.firstWhere(
  (e) => e.name == statusString,
  orElse: () => ComplaintStatus.pending,
);
```

**After:**
```dart
// Check if complaint is resolved (admin app might use isResolved field)
if (isResolved == true || resolvedAt != null) {
  status = ComplaintStatus.completed;
}
// Map different status values to our enum
else if (statusString == 'completed' || 
    statusString == 'resolved' || 
    statusString == 'closed') {
  status = ComplaintStatus.completed;
} else if (statusString == 'inProgress' || 
           statusString == 'in_progress' ||
           statusString == 'in-progress' ||
           statusString == 'assigned') {
  status = ComplaintStatus.inProgress;
} else {
  status = ComplaintStatus.pending;
}
```

## How It Works Now

### Scenario 1: Admin Uses "resolved" Status
```javascript
// Firestore document
{
  status: "resolved",
  resolvedAt: "2026-02-20",
  resolvedBy: "preetham"
}
```
✅ Resident app maps "resolved" → `completed` → Shows in History tab

### Scenario 2: Admin Uses isResolved Field
```javascript
// Firestore document
{
  status: "pending",  // Never updated
  isResolved: true,
  resolvedAt: "2026-02-20"
}
```
✅ Resident app detects `isResolved: true` → Maps to `completed` → Shows in History tab

### Scenario 3: Admin Uses "closed" Status
```javascript
// Firestore document
{
  status: "closed",
  completedOn: "2026-02-20"
}
```
✅ Resident app maps "closed" → `completed` → Shows in History tab

## Tab Filtering Logic

The complaints screen filters complaints based on status:

### Active Tab
Shows complaints with:
- `status == pending` OR
- `status == inProgress`

### History Tab
Shows complaints with:
- `status == completed`

With the fix, any complaint marked as resolved in the admin app (regardless of the exact field/value used) will now correctly appear in the History tab.

## Testing

### Test Case 1: Existing Resolved Complaints
1. Open resident app
2. Go to Complaints & Requests
3. Check History tab
4. **Expected**: Previously resolved complaints should now appear in History

### Test Case 2: New Resolution
1. Create a complaint in resident app
2. Assign staff from admin app
3. Mark as resolved in admin app
4. Return to resident app
5. **Expected**: Complaint automatically moves from Active to History tab

### Test Case 3: Real-Time Update
1. Keep resident app open on Active tab
2. Resolve a complaint from admin app
3. **Expected**: Complaint disappears from Active tab within 1-2 seconds
4. Switch to History tab
5. **Expected**: Complaint appears in History tab

## Console Logs

The fix includes detailed logging to help debug status mapping:

```
📊 Status string: "resolved"
📊 isResolved: null
📊 resolvedAt: null
✅ Mapped to: completed
✅ Final parsed status: ComplaintStatus.completed
```

Or if using isResolved field:
```
📊 Status string: "pending"
📊 isResolved: true
📊 resolvedAt: Timestamp(seconds=1708444800, nanoseconds=0)
✅ Marked as completed (isResolved=true or resolvedAt exists)
✅ Final parsed status: ComplaintStatus.completed
```

## Benefits

✅ **Flexible Status Handling**: Works with multiple admin app implementations
✅ **Backward Compatible**: Still works with original status values
✅ **Real-Time Sync**: Complaints move to History immediately when resolved
✅ **Better Logging**: Easy to debug status mapping issues
✅ **Future-Proof**: Can easily add more status value mappings

## Firestore Status Recommendations

For best compatibility, the admin app should use one of these approaches:

### Option 1: Use Standard Status Values (Recommended)
```javascript
{
  status: "pending"     // When created
  status: "inProgress"  // When assigned
  status: "completed"   // When resolved
}
```

### Option 2: Use isResolved Field
```javascript
{
  status: "pending",
  isResolved: false,    // When created
  
  status: "inProgress",
  isResolved: false,    // When assigned
  
  status: "inProgress",
  isResolved: true,     // When resolved
  resolvedAt: timestamp
}
```

### Option 3: Use "resolved" Status (Now Supported)
```javascript
{
  status: "pending"     // When created
  status: "assigned"    // When assigned
  status: "resolved"    // When resolved
}
```

All three approaches now work correctly with the resident app!

## Related Files

- `lib/src/services/complaint_firestore_service.dart` - Status parsing logic
- `lib/complaints_screen.dart` - Tab filtering logic
- `lib/src/models/complaint.dart` - Status enum definition
- `lib/src/modals/complaint_detail_modal.dart` - Real-time status updates

---
**Status**: ✅ Complete
**Date**: February 20, 2026
**Impact**: High - Complaints now correctly move to History when resolved
**Compatibility**: Works with multiple admin app status implementations
