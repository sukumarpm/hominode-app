# Visitor Management Screen

## Overview
Pixel-perfect Flutter recreation of the Visitor Management screen with tab-based navigation and visitor approval workflow.

## Features Implemented
✅ Blue gradient header with back button
✅ Three-tab selector (Pending / Approved / Deliveries)
✅ Visitor cards with avatar, name, visit type, and time
✅ Status badges (Pending, Approved, Received)
✅ Green "Approve" button
✅ Red outlined "Reject" button
✅ Floating Action Button (+ icon) for adding visitors
✅ Bottom navigation bar with Visitor tab active
✅ Smooth tab switching functionality
✅ Exact color scheme and spacing

## Navigation
- Accessible from Dashboard via:
  - Quick Access "Visitors" button
  - Bottom navigation "Visitor" tab
- Back button returns to Dashboard

## Screen Sections

### 1. Header
- Blue gradient background (#2563EB to #1E40AF)
- Back arrow button (iOS style)
- "Visitor Management" title
- Rounded bottom corners

### 2. Tab Selector
- Three tabs: Pending, Approved, Deliveries
- Pill-style design with gray background (#F4F4F4)
- Active tab has white background with shadow
- Smooth tab switching

### 3. Visitor Cards
Each card includes:
- Circular avatar with initial letter
- Visitor name (16pt SemiBold)
- Visit type (13pt Regular)
- Time with clock icon
- Status badge (color-coded)
- Action buttons (for pending visitors)

### 4. Action Buttons
- **Approve Button**: Green (#00A84F) with white text
- **Reject Button**: White with red border and text (#D2002F)
- Both buttons have rounded corners and proper padding

### 5. Floating Action Button
- Positioned at top-right
- Blue gradient circle
- Plus icon for adding new visitors
- Shadow effect

### 6. Bottom Navigation
- 5 tabs: Home, Visitor (active), Bills, Events, Profile
- Visitor tab highlighted in blue
- Consistent with Dashboard navigation

## Color Palette
- Primary Blue: #2563EB
- Dark Blue: #1E40AF
- Tab Background: #F4F4F4
- Pending Badge: #FFDCE2 (text: #D2002F)
- Approved Badge: #D1FAE5 (text: #00A84F)
- Received Badge: #E6FBEE (text: #0DA85E)
- Approve Button: #00A84F
- Reject Border/Text: #D2002F
- Delivery Icon Background: #F6EDFF (purple tint)
- Delivery Icon Color: #8B5CF6 (purple)
- Background: #F8F9FA

## Tab Content

### Pending Tab
Shows visitors awaiting approval with:
- Pending status badge
- Approve and Reject buttons
- Sample visitors: Amit Kumar, Priya Sharma

### Approved Tab
Shows approved visitors with:
- Approved status badge (green background with green text)
- "View QR Pass" button (blue outlined with QR icon)
- Clicking button navigates to QR Pass screen
- Sample visitors: Amit Kumar, Rajesh Verma

### Deliveries Tab
Shows package deliveries with:
- Purple-tinted delivery icon (shopping bag)
- Delivery name and time/expected time
- Status chips (Received = green, Pending = pink)
- Simplified card layout (no action buttons)
- Sample deliveries: Amazon Delivery, Swiggy Delivery

## File Structure
```
lib/
├── visitor_management_screen.dart  # Main visitor screen
├── visitor_qr_screen.dart          # QR Pass display screen
├── dashboard_screen.dart           # Updated with navigation
└── main.dart                       # App entry point
```

## Usage
```dart
// Navigate to Visitor Management
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const VisitorManagementScreen(),
  ),
);
```

## Reusable Components
- `_buildHeader()` - Blue gradient header
- `_buildTabSelector()` - Three-tab switcher
- `_buildTabItem()` - Individual tab
- `_buildVisitorCard()` - Visitor card with all details (Pending/Approved tabs)
- `_buildDeliveryCard()` - Delivery card with icon and status (Deliveries tab)
- `_buildApproveButton()` - Green approve button
- `_buildRejectButton()` - Red reject button
- `_buildViewQRButton()` - Blue QR pass button
- `_buildFloatingActionButton()` - FAB with gradient
- `_buildBottomNavigationBar()` - Bottom nav bar
- `_buildNavItem()` - Individual nav item

## New Features

### QR Pass Screen
When clicking "View QR Pass" on approved visitors:
- Shows large QR code placeholder
- Displays visitor details (name, type, time, status)
- Shows pass ID
- Includes instructions for gate entry
- Blue gradient header with back button
- Clean, professional design

## Notes
- Fully responsive design
- Stateful widget for tab management
- Clean separation of UI components
- Production-ready code with proper styling
- Matches reference design pixel-perfectly
- QR Pass screen ready for integration with actual QR code generation
