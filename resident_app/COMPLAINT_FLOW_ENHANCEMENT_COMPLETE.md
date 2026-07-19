# Complaint Flow Enhancement - Complete

## Overview
Enhanced the complaint detail modal with dynamic status-based flow, staff contact actions (call/chat), and real-time timeline that reflects the actual complaint status progression.

## Key Enhancements

### 1. Dynamic Status Display
- Status badge changes color and text based on actual complaint status
- **Pending**: Red badge with "Pending" text
- **In Progress**: Orange badge with "In Progress" text
- **Completed**: Green badge with "Completed" text

### 2. Staff Contact Actions
- **Call Button**: Tap to call staff member directly
- **Chat Button**: Quick access to chat with technician
- **Email Display**: Shows staff email if available
- Confirmation dialog before making calls

### 3. Dynamic Timeline
Timeline automatically adjusts based on complaint status:

#### Pending Status
```
✅ Complaint Submitted - [Date/Time]
⏳ Waiting for Staff Assignment - Pending
```

#### In Progress Status
```
✅ Complaint Submitted - [Date/Time]
✅ Assigned to [Staff Name] - [Date/Time]
🔄 Work in Progress - [Date/Time]
⏳ Work Completion - In Progress
```

#### Completed Status
```
✅ Complaint Submitted - [Date/Time]
✅ Assigned to [Staff Name] - [Date/Time]
✅ Work in Progress - [Date/Time]
✅ Work Completed - [Date/Time]
```

### 4. Dynamic CTA (Call-to-Action)

#### Pending Status
Shows info box:
```
ℹ️ Waiting for staff assignment
```

#### In Progress Status
Shows action button:
```
[Chat With Technician]
```

#### Completed Status
Shows success message:
```
✅ Work completed successfully
```

## Implementation Details

### Staff Contact Section

#### Before
```
📞 +91 98765 43210
✉️ ramesh@example.com
```

#### After
```
┌─────────────────────────────────┐
│ 📞 +91 98765 43210      [Call] →│ (Tappable)
│ 💬 Chat with Ramesh     [Chat] →│ (Tappable)
│ ✉️ ramesh@example.com           │ (Info only)
└─────────────────────────────────┘
```

### Call Functionality
```dart
void _handleCallStaff(String phoneNumber) {
  // 1. Show confirmation dialog
  // 2. User confirms
  // 3. Launch phone dialer
  // 4. Or show "Calling..." message
}
```

### Chat Functionality
```dart
void _handleChatPressed() {
  // 1. Check if staff assigned
  // 2. Close modal
  // 3. Navigate to chat screen
  // 4. Pass staff details
}
```

## Status Flow Diagram

```
┌─────────────┐
│   PENDING   │ → Waiting for admin to assign staff
└──────┬──────┘
       │ Admin assigns staff
       ↓
┌─────────────┐
│ IN PROGRESS │ → Staff working on complaint
└──────┬──────┘
       │ Staff completes work
       ↓
┌─────────────┐
│  COMPLETED  │ → Work finished
└─────────────┘
```

## UI Components

### Status Badge (Dynamic)
```dart
// Pending
Container(
  color: #FEE2E2,
  child: Text('Pending', color: #DC2626),
)

// In Progress
Container(
  color: #FFF3E8,
  child: Text('In Progress', color: #FF7A00),
)

// Completed
Container(
  color: #E8FDEB,
  child: Text('Completed', color: #10B981),
)
```

### Staff Action Buttons
```dart
InkWell(
  onTap: () => _handleCallStaff(phone),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: kPrimary),
    ),
    child: Row(
      Icon(phone),
      Text(phoneNumber),
      Text('Call', color: kPrimary),
      Icon(arrow_forward),
    ),
  ),
)
```

### Timeline Events
```dart
// Done (Green dot)
Container(
  width: 12,
  height: 12,
  decoration: BoxDecoration(
    color: #1DB954,
    shape: circle,
  ),
)

// In Progress (Orange dot)
Container(
  width: 12,
  height: 12,
  decoration: BoxDecoration(
    color: #FF7A00,
    shape: circle,
  ),
)

// Pending (Gray dot)
Container(
  width: 12,
  height: 12,
  decoration: BoxDecoration(
    color: #C4C4C4,
    shape: circle,
  ),
)
```

## Code Changes

### File: `lib/src/modals/complaint_detail_modal.dart`

#### Added Methods:
1. `_buildStaffActionRow()` - Tappable action buttons for call/chat
2. `_handleCallStaff()` - Call staff with confirmation
3. `_buildDynamicStatusBadge()` - Status-based badge
4. `_formatDate()` - Format dates for timeline
5. Dynamic `_timeline` getter - Status-based timeline

#### Updated Methods:
1. `_buildStaffDetailsSection()` - Added call/chat buttons
2. `_buildTitleSection()` - Dynamic status badge
3. `_buildCTAButton()` - Status-based CTA
4. `_buildStaffInfoRow()` - Styled info display

## Features by Status

### Pending Complaints
- ✅ Red "Pending" badge
- ✅ Timeline shows "Waiting for Staff Assignment"
- ✅ Info box: "Waiting for staff assignment"
- ✅ No staff details shown
- ✅ Can delete complaint

### In Progress Complaints
- ✅ Orange "In Progress" badge
- ✅ Timeline shows all steps up to "Work in Progress"
- ✅ Staff details with call/chat buttons
- ✅ "Chat With Technician" button
- ✅ Cannot delete complaint

### Completed Complaints
- ✅ Green "Completed" badge
- ✅ Timeline shows all steps including "Work Completed"
- ✅ Staff details (read-only)
- ✅ Success message: "Work completed successfully"
- ✅ Cannot delete complaint

## User Interactions

### Call Staff
1. User taps phone number row
2. Confirmation dialog: "Do you want to call [number]?"
3. User confirms
4. Phone dialer opens (or shows message)

### Chat with Staff
1. User taps chat row OR "Chat With Technician" button
2. Modal closes
3. Navigate to chat screen
4. Chat opens with staff member

### View Timeline
1. User opens complaint detail
2. Timeline automatically shows based on status
3. Green dots = completed steps
4. Orange dot = current step
5. Gray dots = pending steps

## Timeline Logic

```dart
List<TimelineEvent> get _timeline {
  events = [];
  
  // Always show submission
  events.add(submitted);
  
  if (hasStaff) {
    events.add(assigned);
  } else if (isPending) {
    events.add(waitingForAssignment);
    return events; // Stop here
  }
  
  if (isInProgress) {
    events.add(workInProgress);
    events.add(workCompletionPending);
  } else if (isCompleted) {
    events.add(workInProgress);
    events.add(workCompleted);
  }
  
  return events;
}
```

## Call Confirmation Dialog

```
┌─────────────────────────────────┐
│     Call Staff Member           │
│                                 │
│ Do you want to call             │
│ +91 98765 43210?                │
│                                 │
│   [Cancel]        [Call]        │
└─────────────────────────────────┘
```

## Testing Scenarios

### Test 1: Pending Complaint
1. Create new complaint
2. Open detail modal
3. ✅ Red "Pending" badge
4. ✅ Timeline shows "Waiting for Staff Assignment"
5. ✅ Info box shown
6. ✅ No staff details
7. ✅ No chat button

### Test 2: In Progress Complaint
1. Admin assigns staff
2. Open detail modal
3. ✅ Orange "In Progress" badge
4. ✅ Timeline shows assignment and progress
5. ✅ Staff details with call/chat buttons
6. ✅ "Chat With Technician" button shown
7. ✅ Tap phone → confirmation dialog
8. ✅ Tap chat → navigate to chat

### Test 3: Completed Complaint
1. Staff completes work
2. Open detail modal
3. ✅ Green "Completed" badge
4. ✅ Timeline shows all steps completed
5. ✅ Staff details shown (read-only)
6. ✅ Success message shown
7. ✅ No chat button

### Test 4: Call Staff
1. Open in-progress complaint
2. Tap phone number row
3. ✅ Confirmation dialog appears
4. ✅ Shows phone number
5. Tap "Call"
6. ✅ Phone dialer opens (or message shown)

### Test 5: Chat with Staff
1. Open in-progress complaint
2. Tap "Chat with [Name]" row
3. ✅ Modal closes
4. ✅ Navigate to chat screen
5. ✅ Staff details passed

## Future Enhancements

### 1. Real-time Status Updates
```dart
StreamBuilder<Complaint>(
  stream: ComplaintFirestoreService.streamComplaint(id),
  builder: (context, snapshot) {
    // Auto-update UI when status changes
  },
)
```

### 2. Push Notifications
- Notify when staff assigned
- Notify when work starts
- Notify when work completed

### 3. Rating System
- Rate staff after completion
- Provide feedback
- Track satisfaction

### 4. Photo Updates
- Staff uploads progress photos
- Show in timeline
- Before/after comparison

### 5. Estimated Completion Time
- Show ETA when work starts
- Update based on progress
- Notify if delayed

### 6. Video Call Option
- Video call with staff
- Screen sharing for guidance
- Record for reference

## Analytics Events

Track user interactions:
```dart
// Call staff
analytics.logEvent('complaint_call_staff', {
  'complaint_id': id,
  'staff_id': staffId,
  'status': status,
});

// Chat with staff
analytics.logEvent('complaint_chat_opened', {
  'complaint_id': id,
  'staff_id': staffId,
});

// View timeline
analytics.logEvent('complaint_timeline_viewed', {
  'complaint_id': id,
  'status': status,
  'has_staff': hasStaff,
});
```

## Summary

The complaint flow is now fully dynamic with:
- ✅ Status-based UI changes
- ✅ Call staff functionality
- ✅ Chat with staff
- ✅ Dynamic timeline
- ✅ Status-appropriate CTAs
- ✅ Professional, intuitive design

Users can now track their complaint progress, contact assigned staff, and understand the current status at a glance.
