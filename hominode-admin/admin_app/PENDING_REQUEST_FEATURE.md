# Pending Request Feature - Implementation Guide

## Overview
The Pending Request feature allows admins to review and approve/reject new resident registration requests. It's integrated into the existing Resident Management screen as a tab.

## Visual Design

### Screen Layout
- **Background**: Light grey (#F7F7F7)
- **Header**: Blue gradient (#2563EB → #1E40AF) with back button and "Resident" title
- **Section Title**: "Resident Management" with "+ Add" button
- **Segmented Control**: Two tabs - "All Residents" and "Pending Request (count)"

### Pending Request Card
Each card displays:
- **Avatar**: 64×64 circular placeholder with light blue background (#E5F0FF)
- **Resident Info**:
  - Name (bold, 18sp, #111111)
  - Unit number with home icon (#6B7280)
  - Phone number with phone icon (#6B7280)
  - "Requested on 2025-10-30" (grey text)
- **Action Buttons**:
  - **Approve**: Green (#16A34A) solid button
  - **Reject**: Red (#DC2626) outlined button

## Features

### 1. Tab Navigation
```dart
// Toggle between All Residents and Pending Request
int _selectedTab = 0; // 0 = All, 1 = Pending
```

### 2. Approve Request
- Simulates async API call (700ms delay)
- Moves resident from pending to active list
- Shows green success SnackBar
- Updates pending count automatically

### 3. Reject Request
- Shows confirmation dialog
- Removes request from list on confirm
- Shows red SnackBar
- Updates pending count automatically

### 4. Empty State
When no pending requests exist:
- Shows icon and message: "No pending requests"

## Usage

### Accessing Pending Requests
1. Navigate to Residents screen from bottom navigation
2. Tap "Pending Request (count)" tab
3. View list of pending requests
4. Tap Approve or Reject for each request

### Approve Flow
```dart
void _onApproveRequest(ResidentModel resident) async {
  await Future.delayed(const Duration(milliseconds: 700));
  // Move to active residents
  // Show success message
  // TODO: Integrate with API
}
```

### Reject Flow
```dart
void _onRejectRequest(ResidentModel resident) {
  // Show confirmation dialog
  // Remove from list on confirm
  // Show rejection message
  // TODO: Integrate with API
}
```

## Data Model

```dart
class ResidentModel {
  final String id;
  final String name;
  final String unit;
  final int members;
  final String phone;
  final bool hasDues;
  final double? duesAmount;
  final bool isPending; // true for pending requests
}
```

## Integration Points

### TODO: Backend Integration
1. **Fetch Pending Requests**
   ```
   GET /api/residents/pending
   ```

2. **Approve Request**
   ```
   POST /api/residents/approve/{id}
   - Move to active residents
   - Send welcome notification
   ```

3. **Reject Request**
   ```
   POST /api/residents/reject/{id}
   - Send rejection notification
   ```

## Accessibility

All interactive elements include semantic labels:
- Card: "Pending resident request for [name], unit [unit]"
- Approve button: "Approve resident request"
- Reject button: "Reject resident request"

## Responsive Design

- Works on iPhone 13 and other devices
- Bouncing scroll physics
- Touch targets minimum 44×44
- Proper SafeArea handling

## Testing

### Manual Test Cases
1. ✓ Tab switches between All Residents and Pending Request
2. ✓ Pending count updates dynamically
3. ✓ Approve button moves request to active list
4. ✓ Reject button shows confirmation dialog
5. ✓ Empty state shows when no pending requests
6. ✓ SnackBars display appropriate messages
7. ✓ Search works on pending requests
8. ✓ Scroll physics work correctly

## Files Modified
- `admin_app/lib/admin_residents_page.dart` - Added pending request card and handlers

## Next Steps
1. Integrate with real backend API
2. Add request details view (tap card to see full application)
3. Add bulk approve/reject functionality
4. Add filtering by date/unit
5. Add notification system for new requests
