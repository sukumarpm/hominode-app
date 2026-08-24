# Shift Timing and Notifications Implementation

## Overview
Fixed the flow function to properly display shift timing and implement a comprehensive notification system according to the security app requirements.

## Changes Made

### 1. **SecurityUserModel** (`lib/models/security_user_model.dart`)
- Added `shiftTiming` field to store shift timing information
- Updated `fromFirestore()` to read `shiftTiming` from Firestore
- Updated `toMap()` to include `shiftTiming` in serialization
- Maintained backward compatibility with `gateAssignment` field for gate display

### 2. **NotificationService** (NEW - `lib/services/notification_service.dart`)
Created a comprehensive notification service with the following features:

#### Key Methods:
- **`isWithinShiftTiming()`**: Checks if current time is within user's shift hours
  - Supports multiple time formats: "HH:MM - HH:MM", "6 AM - 2 PM", etc.
  - Handles overnight shifts (e.g., 10 PM - 6 AM)
  
- **`getShiftStatusNotification()`**: Returns shift status notification
  - Shows "Shift Active" if within shift hours
  - Shows "Outside Shift Hours" if outside shift hours
  
- **`getGateAssignmentNotification()`**: Returns gate assignment notification
  - Shows "Gate Not Assigned" with high priority if no gate assigned
  - Shows assigned gate with success status if assigned
  
- **`getUserNotifications()`**: Returns all notifications sorted by priority
  - Priority order: high > medium > low
  - Combines shift and gate notifications
  
- **`logNotification()`**: Logs notifications to Firestore for audit trail
- **`getUnreadNotifications()`**: Streams unread notifications for user
- **`markNotificationAsRead()`**: Marks notifications as read

### 3. **SecurityDashboardScreen** (`lib/screens/security_dashboard_screen.dart`)

#### Added:
- Import for `NotificationService`
- `_notificationService` instance
- `_notifications` list to store current notifications
- Updated `_loadCurrentUser()` to load notifications based on user data

#### New UI Components:
- **`_buildNotificationsSection()`**: Displays alerts/notifications
  - Shows shift timing status
  - Shows gate assignment status
  - Color-coded by priority (red for error, orange for warning, green for success)
  - Icons for quick visual identification
  
- **`_getNotificationColor()`**: Maps notification type to color
- **`_getNotificationIcon()`**: Maps notification type to icon

#### Dashboard Updates:
- Added shift timing display next to gate assignment in header
  - Shows shift timing with schedule icon
  - Uses primary blue color for visibility
  - Falls back to "No Shift" if not assigned
  
- Added notifications section between header and attendance card
  - Displays all active notifications
  - Sorted by priority
  - Dismissible if no notifications

## Flow Function Integration

The implementation follows the security app flow:

```
User Login
    ↓
Load User Data (including gate & shiftTiming)
    ↓
Generate Notifications
    ├─ Check if within shift hours
    ├─ Check gate assignment status
    └─ Sort by priority
    ↓
Display on Dashboard
    ├─ Show shift timing in header
    ├─ Show gate assignment in header
    └─ Show alerts section with all notifications
    ↓
User Actions (Check In/Out, Scan QR, etc.)
```

## Notification Types

### 1. Gate Assignment Notification
- **Type**: `gate_assigned` or `gate_not_assigned`
- **Priority**: High (if not assigned), Low (if assigned)
- **Color**: Green (assigned), Red (not assigned)
- **Icon**: location_on

### 2. Shift Status Notification
- **Type**: `shift_active` or `shift_inactive`
- **Priority**: Low (active), Medium (inactive)
- **Color**: Green (active), Orange (inactive)
- **Icon**: schedule

## Data Flow

```
Firestore (staff collection)
    ↓
    ├─ gate / gateAssignment
    ├─ shiftTiming (e.g., "6 AM - 2 PM")
    └─ other user data
    ↓
SecurityUserModel
    ↓
NotificationService
    ├─ Parse shift timing
    ├─ Check current time
    └─ Generate notifications
    ↓
SecurityDashboardScreen
    ├─ Display in header (gate + shift)
    └─ Display in alerts section
```

## Testing

### Test Case 1: Gate Assignment
1. Admin assigns gate to user in Firestore
2. User logs in
3. Dashboard shows gate in header with green badge
4. Notification shows "Gate Assignment: You are assigned to: [gate name]"

### Test Case 2: Shift Timing
1. Admin sets shiftTiming to "6 AM - 2 PM"
2. User logs in during shift hours (e.g., 10 AM)
3. Dashboard shows shift timing in header
4. Notification shows "Shift Active: You are currently within your shift: 6 AM - 2 PM"

### Test Case 3: Outside Shift Hours
1. User logs in outside shift hours (e.g., 5 PM)
2. Dashboard shows shift timing in header
3. Notification shows "Outside Shift Hours: Your shift is: 6 AM - 2 PM" (orange warning)

### Test Case 4: No Gate Assignment
1. User has no gate assigned
2. Dashboard shows "Not Assigned" in header
3. Notification shows "Gate Not Assigned" with high priority (red)

## Firestore Structure

Expected staff document structure:
```javascript
{
  uid: "user_uid",
  name: "John Doe",
  email: "john@example.com",
  phone: "+91 98765 43210",
  gate: "Gate 2",  // or gateAssignment: "Gate 2"
  shiftTiming: "6 AM - 2 PM",  // or "06:00 - 14:00"
  shift: "Morning",
  // ... other fields
}
```

## Future Enhancements

1. **Push Notifications**: Integrate Firebase Cloud Messaging for real-time alerts
2. **Notification History**: Show past notifications in a separate screen
3. **Custom Alerts**: Allow admins to send custom notifications to specific guards
4. **Shift Reminders**: Notify users 15 minutes before shift starts/ends
5. **Late Arrival Alert**: Notify if user checks in after shift start time
6. **Early Departure Alert**: Notify if user checks out before shift end time

## Notes

- All times are parsed in 24-hour format internally
- Shift timing supports both 12-hour (with AM/PM) and 24-hour formats
- Overnight shifts are properly handled (e.g., 10 PM - 6 AM)
- Notifications are sorted by priority for better UX
- The system is extensible for adding more notification types
