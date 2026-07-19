# Complaint Delete Feature - Complete

## Overview
Added the ability for residents to delete their complaints with proper confirmation dialogs and restrictions. Only pending complaints can be deleted to prevent data loss for complaints already being processed.

## Implementation Details

### 1. Delete Restrictions
- **Only Pending Complaints**: Residents can only delete complaints with status "pending"
- **In Progress/Completed**: Cannot be deleted (already assigned to staff or resolved)
- **Confirmation Required**: Double confirmation before deletion

### 2. User Interface Options

#### Option 1: Long Press Menu (Implemented)
- Long press on complaint card
- Bottom sheet menu appears
- Options: "View Details" and "Delete Complaint" (if pending)

#### Option 2: Delete Button in Modal (Implemented)
- Open complaint detail modal
- Delete icon in header (red trash icon)
- Only visible for pending complaints
- Taps delete → closes modal → shows confirmation

#### Option 3: Swipe to Delete (Future Enhancement)
- Swipe left on complaint card
- Red delete background appears
- Swipe fully to delete with confirmation

### 3. Delete Flow

```
User Action → Confirmation Dialog → Firestore Delete → UI Update
```

**Step by Step:**
1. User long presses complaint card OR taps delete in modal
2. Confirmation dialog appears: "Are you sure you want to delete this complaint?"
3. User confirms deletion
4. App calls Firestore delete service
5. Complaint removed from Firestore
6. UI updates (complaint removed from list)
7. Success message shown

### 4. Code Changes

#### Complaints Screen (`lib/complaints_screen.dart`)
Added:
- `_showComplaintOptions()` - Bottom sheet menu for complaint actions
- Long press handler on complaint cards
- Delete callback passed to detail modal

#### Complaint Detail Modal (`lib/src/modals/complaint_detail_modal.dart`)
Added:
- `onDelete` callback parameter
- Delete button in header (red trash icon)
- Conditional visibility (only for pending complaints)

#### Complaints Service (`lib/src/services/complaints_service.dart`)
Already has:
- `deleteComplaint()` method
- Calls Firestore service
- Error handling

#### Complaint Firestore Service (`lib/src/services/complaint_firestore_service.dart`)
Already has:
- `deleteComplaint()` method
- Deletes from Firestore
- Returns success/failure result

## UI Components

### Long Press Menu (Bottom Sheet)
```
┌─────────────────────────────┐
│         ─────               │
│                             │
│ 👁️  View Details            │
│                             │
│ 🗑️  Delete Complaint        │ (red text, only if pending)
│                             │
└─────────────────────────────┘
```

### Delete Button in Modal Header
```
┌─────────────────────────────┐
│  Complaint Details  🗑️  ✕   │ (trash icon only if pending)
├─────────────────────────────┤
```

### Confirmation Dialog
```
┌─────────────────────────────┐
│     Delete Complaint        │
│                             │
│ Are you sure you want to    │
│ delete this complaint?      │
│                             │
│   [Cancel]  [Delete]        │
│              (red)          │
└─────────────────────────────┘
```

## Usage Examples

### Example 1: Delete via Long Press
```dart
// User long presses complaint card
onLongPress: () {
  _showComplaintOptions(complaint);
}

// Bottom sheet shows options
// User taps "Delete Complaint"
// Confirmation dialog appears
// User confirms → Complaint deleted
```

### Example 2: Delete via Modal
```dart
// User taps complaint card
// Modal opens
// User taps delete icon in header
// Modal closes
// Confirmation dialog appears
// User confirms → Complaint deleted
```

## Restrictions & Rules

### Can Delete:
✅ Complaints with status "pending"
✅ User's own complaints only
✅ After confirmation

### Cannot Delete:
❌ Complaints with status "inProgress"
❌ Complaints with status "completed"
❌ Other users' complaints
❌ Without confirmation

### Why These Restrictions?
1. **Pending Only**: Once staff is assigned, complaint is in the system workflow
2. **Own Complaints**: Privacy and security
3. **Confirmation**: Prevent accidental deletion
4. **In Progress**: Staff already working on it
5. **Completed**: Historical record needed

## Error Handling

### Scenarios Handled:
1. **Network Error**: Shows error message, complaint not deleted
2. **Permission Denied**: Shows error message
3. **Complaint Not Found**: Shows error message
4. **User Cancels**: No action taken, complaint remains

### Error Messages:
- Success: "Complaint deleted" (green snackbar)
- Failure: "Failed to delete complaint" (red snackbar)

## Testing Checklist

- [x] Long press shows bottom sheet menu
- [x] Delete option only for pending complaints
- [x] Delete button in modal only for pending
- [x] Confirmation dialog appears
- [x] Cancel works (complaint not deleted)
- [x] Confirm works (complaint deleted)
- [x] UI updates after deletion
- [x] Success message shown
- [x] Error handling works
- [x] Cannot delete in-progress complaints
- [x] Cannot delete completed complaints

## Testing Steps

### Test 1: Delete Pending Complaint
1. Create new complaint (status: pending)
2. Long press complaint card
3. Tap "Delete Complaint"
4. Confirm deletion
5. ✅ Complaint removed from list
6. ✅ Success message shown

### Test 2: Cannot Delete In-Progress
1. Find complaint with status "inProgress"
2. Long press complaint card
3. ✅ Delete option NOT shown in menu
4. Open detail modal
5. ✅ Delete button NOT shown in header

### Test 3: Cancel Deletion
1. Long press pending complaint
2. Tap "Delete Complaint"
3. Tap "Cancel" in confirmation
4. ✅ Complaint still in list
5. ✅ No changes made

### Test 4: Delete via Modal
1. Tap pending complaint
2. Modal opens
3. Tap delete icon (red trash) in header
4. Confirm deletion
5. ✅ Modal closes
6. ✅ Complaint deleted
7. ✅ Success message shown

### Test 5: Network Error
1. Turn off internet
2. Try to delete complaint
3. ✅ Error message shown
4. ✅ Complaint still in list

## Firestore Security Rules

Ensure users can only delete their own complaints:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /complaints/{complaintId} {
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid &&
                       resource.data.status == 'pending';
    }
  }
}
```

## Future Enhancements

### 1. Swipe to Delete
```dart
Dismissible(
  key: Key(complaint.id),
  direction: DismissDirection.endToStart,
  confirmDismiss: (direction) async {
    return await showDeleteConfirmation();
  },
  background: Container(
    color: Colors.red,
    alignment: Alignment.centerRight,
    padding: EdgeInsets.only(right: 20),
    child: Icon(Icons.delete, color: Colors.white),
  ),
  onDismissed: (direction) {
    _handleDeleteComplaint(complaint);
  },
  child: ComplaintCard(...),
)
```

### 2. Undo Delete
- Show snackbar with "Undo" button
- Keep complaint in memory for 5 seconds
- Allow restoration before permanent delete

### 3. Soft Delete
- Mark as deleted instead of removing
- Keep in database for admin review
- Auto-delete after 30 days

### 4. Bulk Delete
- Select multiple pending complaints
- Delete all at once
- Single confirmation for all

### 5. Delete Reasons
- Ask why user is deleting
- Options: "Resolved myself", "Created by mistake", "Other"
- Track deletion reasons for analytics

## Analytics Events

Track deletion for insights:
```dart
// Log deletion event
analytics.logEvent(
  name: 'complaint_deleted',
  parameters: {
    'complaint_id': complaint.id,
    'category': complaint.category.name,
    'status': complaint.status.name,
    'age_hours': complaint.createdDate.difference(DateTime.now()).inHours,
  },
);
```

## Summary

The complaint delete feature is now fully functional with:
- ✅ Long press menu option
- ✅ Delete button in modal
- ✅ Confirmation dialog
- ✅ Restrictions (pending only)
- ✅ Error handling
- ✅ UI updates
- ✅ Success/error messages
- ✅ Firestore integration

Users can now delete their pending complaints with proper safeguards and confirmation.
