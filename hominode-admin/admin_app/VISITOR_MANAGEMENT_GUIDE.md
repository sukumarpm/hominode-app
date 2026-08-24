# Visitor Management Screen - Implementation Guide

## Overview
The Visitor Management screen allows admins to track, approve, and reject visitor entries. It includes real-time statistics, tab-based filtering, and QR gate system integration.

## Features Implemented

### 1. Header Section
- Blue gradient header matching app design
- Back button for navigation
- Title: "Visitor Management"

### 2. Statistics Dashboard (4 Cards)
- **Today**: 37 visitors (blue)
- **Inside Now**: 12 visitors (green)
- **Pending**: 5 requests (orange)
- **This Week**: 284 visitors (purple)
- Responsive grid layout with equal sizing

### 3. Tab Navigation
- **Pending (count)**: Shows pending approval requests
- **Active**: Shows currently visiting guests
- **History**: Shows past visitors
- Smooth tab switching with animations
- Dynamic count badge on Pending tab

### 4. Visitor Cards
Each card displays:
- **Avatar**: Light blue placeholder with person icon
- **Visitor Info**:
  - Name (bold, 16px)
  - Phone number (grey)
  - Requested time (grey)
- **Visit Details** (grey container):
  - Visiting: Resident name
  - Unit: Unit number
  - Purpose: Visit purpose
- **Action Buttons** (Pending only):
  - Approve: Green button
  - Reject: Red outlined button

### 5. QR Gate System Banner
- Blue gradient banner at bottom
- QR icon in white rounded square
- Title: "QR Gate System"
- Subtitle: "Scan visitor QR codes for quick entry"
- Tappable to open QR scanner screen

## Data Model

### VisitorEntry
```dart
- id: String
- visitorName: String
- phone: String
- residentName: String
- unit: String
- purpose: String
- requestedTime: DateTime
- status: VisitorStatus (pending/active/history)
```

## Action Handlers

### 1. Approve Visitor
```dart
void _onApprove(VisitorEntry visitor)
```
- Changes status from pending to active
- Shows success SnackBar
- TODO: POST /api/visitors/{id}/approve

### 2. Reject Visitor
```dart
void _onReject(VisitorEntry visitor)
```
- Shows confirmation dialog
- Removes from list on confirm
- Shows rejection SnackBar
- TODO: POST /api/visitors/{id}/reject

### 3. QR Gate System
```dart
void _onQRGateSystemTap()
```
- Navigates to QR scanner screen
- TODO: Integrate QR code scanner library

## UI Specifications

### Colors
- Primary Blue: #2563EB
- Dark Blue: #1E40AF
- Success Green: #10B981 / #16A34A
- Warning Orange: #F97316
- Error Red: #DC2626
- Purple: #8B5CF6
- Background: #F7F7F7
- Card Background: #FFFFFF
- Grey Text: #6B7280 / #9CA3AF

### Typography
- Header: 18px, w600, white
- Section title: 18px, w600, black
- Stat value: 20px, w600, colored
- Stat label: 13px, w500, grey
- Visitor name: 16px, w600, black
- Phone/time: 14px, grey
- Detail labels: 14px, w400, grey
- Detail values: 14px, w500, black
- Button text: 16px, w600

### Spacing
- Card padding: 16px
- Section spacing: 12-16px
- Button height: 44-48px
- Border radius: 8-12px for cards, 19-22px for tabs

## Integration

### From Quick Access
```dart
// In quick_access_page.dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const AdminVisitorManagementScreen(),
    ),
  );
}
```

### Add to Routes
```dart
// In main.dart
routes: {
  '/visitor-management': (context) => const AdminVisitorManagementScreen(),
}
```

## Mock Data

### Visitors (4 entries)
1. Rahul Verma - Pending - Visiting Rajesh Kumar (A-204)
2. Rahul Verma - Pending - Visiting Rajesh Kumar (A-204)
3. Priya Sharma - Active - Visiting Amit Patel (B-305)
4. Vikram Singh - History - Visiting Sneha Reddy (C-101)

### Statistics
- Today: 37
- Inside Now: 12
- Pending: 5
- This Week: 284

## Backend Integration TODOs

### API Endpoints Needed
1. **GET /api/visitors** - Fetch all visitors
2. **GET /api/visitors/stats** - Fetch statistics
3. **POST /api/visitors/{id}/approve** - Approve visitor
4. **POST /api/visitors/{id}/reject** - Reject visitor
5. **POST /api/visitors/qr-scan** - Process QR code scan

### QR Scanner Integration
1. Add package: `qr_code_scanner: ^1.0.1`
2. Request camera permissions
3. Implement QR scanning logic
4. Validate QR codes with backend
5. Auto-approve on successful scan

## Files Created
- `models/visitor_entry.dart` - Visitor data model
- `admin_visitor_management_screen.dart` - Main screen with QR placeholder

## Testing Checklist
- [ ] Tab switching works correctly
- [ ] Approve button changes status and shows message
- [ ] Reject button shows confirmation and removes visitor
- [ ] Statistics display correctly
- [ ] Empty states show when no visitors
- [ ] QR banner navigates to placeholder screen
- [ ] Responsive on different screen sizes
- [ ] Animations are smooth

## Next Steps
1. Integrate with backend API
2. Add QR code scanner functionality
3. Implement real-time updates (WebSocket/polling)
4. Add visitor search and filtering
5. Add visitor check-out functionality
6. Implement notification system for residents
7. Add visitor photo capture
8. Generate visitor passes/QR codes
