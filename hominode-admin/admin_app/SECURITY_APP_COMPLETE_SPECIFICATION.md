# Security Guard App - Complete Specification

## Overview
This document provides a complete specification for the Security Guard App module extracted from the Admin App. The Security App reuses the exact same UI design, colors, layout structure, and functionality from the Admin App, but limits access to only security-related features.

## Application Context
**Gated Community Management System** with three applications:
- **Admin App**: Full property management
- **Resident App**: Resident services and requests
- **Security App**: Gate security and visitor management

## Security App Purpose
The Security App is designed for gate security personnel to:
- Scan visitor QR codes for entry/exit
- Approve/reject visitor requests
- Track active visitors inside the property
- Mark staff attendance
- View and track complaints assigned to them
- Handle emergency situations

---

## FEATURE LIST

### 1. Security Dashboard
- Real-time visitor statistics
- Active visitors count
- Today's entry/exit summary
- Quick access to QR scanner
- Pending approvals count
- Staff attendance summary

### 2. Visitor Management
- **Pending Requests Tab**: Approve/reject visitor requests
- **Active Visitors Tab**: Track visitors currently inside
- **History Tab**: View completed visitor records
- Real-time updates from Firestore
- Search functionality
- Visitor details display

### 3. QR Scanner
- Real camera scanning using mobile_scanner
- Check-in visitors (sets actualArrival timestamp)
- Check-out visitors (sets departure timestamp)
- Visitor validation and approval check
- Success/error dialogs with visitor details
- Flashlight toggle

### 4. Staff Attendance
- View today's attendance statistics
- Mark staff present/absent/on leave
- View attendance history
- Real-time attendance tracking
- Staff check-in/check-out times

### 5. Complaint Tracking
- View complaints assigned to security
- Update complaint status
- Track complaint resolution
- Filter by status (pending, in-progress, resolved)

---

## SCREEN LIST


### 1. Security Dashboard Screen
**Purpose**: Central hub for security operations  
**Route**: `/security-dashboard`  
**Access**: Security role only

### 2. Visitor Management Screen
**Purpose**: Manage visitor entry, tracking, and exit  
**Route**: `/visitor-management`  
**Tabs**: Pending, Active, History  
**Access**: Security role only

### 3. QR Gate Scanner Screen
**Purpose**: Scan visitor QR codes for check-in/check-out  
**Route**: `/qr-scanner`  
**Camera**: Real camera with mobile_scanner package  
**Access**: Security role only

### 4. Staff Attendance Screen
**Purpose**: Mark and track staff attendance  
**Route**: `/staff-attendance`  
**Access**: Security role only

### 5. Complaint Tracking Screen
**Purpose**: View and update security-related complaints  
**Route**: `/complaint-tracking`  
**Access**: Security role only

---

## UI DESIGN SYSTEM

### Color Palette (Reused from Admin App)
```dart
// Primary Colors
Primary Blue: Color(0xFF2563EB)
Dark Blue: Color(0xFF1E40AF)

// Status Colors
Success Green: Color(0xFF16A34A)
Warning Orange: Color(0xFFF59E0B)
Error Red: Color(0xFFEF4444)
Purple: Color(0xFF9333EA)

// Neutral Colors
Background: Color(0xFFF7F7F7)
Card White: Colors.white
Text Dark: Color(0xFF111827)
Text Gray: Color(0xFF6B7280)
Border Gray: Color(0xFFE5E7EB)
Light Gray: Color(0xFFF3F4F6)
```

### Typography
```dart
// Headers
Page Title: fontSize: 20, fontWeight: w700
Section Title: fontSize: 18, fontWeight: w700
Card Title: fontSize: 16, fontWeight: w600

// Body Text
Body: fontSize: 14, fontWeight: w400
Label: fontSize: 12, fontWeight: w500
Caption: fontSize: 11, fontWeight: w400
```

### Spacing System
```dart
// Padding
Screen Horizontal: 16px
Card Padding: 16px
Section Spacing: 20px
Element Spacing: 12px

// Border Radius
Cards: 12px
Buttons: 12px
Input Fields: 12px
Icons: 12px
```

---

## SCREEN LAYOUTS


### 1. Security Dashboard Layout

```
┌─────────────────────────────────────────┐
│ StandardHeader                          │
│ "Security Dashboard"                    │
├─────────────────────────────────────────┤
│                                         │
│ [Icon] Security Dashboard               │
│        Gate operations & monitoring     │
│                                         │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│ │ 12  │ │  8  │ │  4  │ │  3  │       │
│ │Total│ │Active│ │Pend.│ │Exit │       │
│ └─────┘ └─────┘ └─────┘ └─────┘       │
│                                         │
│ Quick Actions                           │
│ ┌──────────────┐ ┌──────────────┐     │
│ │ Scan QR Code │ │ View Visitors│     │
│ └──────────────┘ └──────────────┘     │
│                                         │
│ Recent Activity                         │
│ ┌─────────────────────────────────┐   │
│ │ John Doe checked in             │   │
│ │ Flat A-101 • 10:30 AM          │   │
│ └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

**Components**:
- StandardHeader widget (reused)
- Page header with icon and subtitle
- 4 metric cards (Total, Active, Pending, Exits)
- Quick action buttons
- Recent activity list
- Floating Action Button: "Scan QR"

---

### 2. Visitor Management Screen Layout

```
┌─────────────────────────────────────────┐
│ StandardHeader                          │
│ "Visitor Management"                    │
├─────────────────────────────────────────┤
│                                         │
│ [Icon] Visitor Management               │
│        Approve pending requests         │
│                                         │
│ ┌─────┐ ┌─────┐ ┌─────┐               │
│ │  5  │ │ 12  │ │ -   │               │
│ │Pend.│ │Today│ │Avg  │               │
│ └─────┘ └─────┘ └─────┘               │
│                                         │
│ [Search visitors...]                    │
│                                         │
│ ┌─────────┬─────────┬─────────┐       │
│ │ Pending │ Active  │ History │       │
│ └─────────┴─────────┴─────────┘       │
│                                         │
│ ┌─────────────────────────────────┐   │
│ │ [👤] John Doe                   │   │
│ │      +91 98765 43210            │   │
│ │      Flat A-101 • Amit Kumar    │   │
│ │      Purpose: Personal Visit    │   │
│ │      [Approve] [Reject]         │   │
│ └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
     [Scan QR] FAB
```

**Components**:
- StandardHeader widget
- Page header with icon
- 3 summary metric cards
- Search bar with clear button
- Tab switcher (Pending/Active/History)
- Visitor cards with action buttons
- Floating Action Button: "Scan QR"

**Tab Content**:
- **Pending**: Visitor cards with Approve/Reject buttons
- **Active**: Visitor cards with Mark Exit button
- **History**: Visitor cards with duration display

---

### 3. QR Scanner Screen Layout

```
┌─────────────────────────────────────────┐
│ [<] QR Gate Scanner                     │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────┐   │
│ │                                 │   │
│ │     CAMERA PREVIEW              │   │
│ │                                 │   │
│ │     ┌─────────────┐            │   │
│ │     │             │            │   │
│ │     │  SCAN AREA  │            │   │
│ │     │             │            │   │
│ │     └─────────────┘            │   │
│ │                                 │   │
│ │     Scanning line animation     │   │
│ │                                 │   │
│ └─────────────────────────────────┘   │
│                                         │
│ Point camera at visitor's QR code       │
│                                         │
│              [Flash 💡]                 │
│                                         │
└─────────────────────────────────────────┘
```

**Components**:
- Back button header
- Full-screen camera preview (MobileScanner)
- Scanning frame overlay with rounded corners
- Animated scan line
- Instruction text
- Flash toggle button
- Permission handling dialogs
- Success/Error dialogs

**Success Dialog** (Entry):
```
┌─────────────────────────────────────┐
│                                     │
│         [✓] Entry Granted           │
│     Visitor has been checked in     │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [👤] Visitor Name: John Doe     │ │
│ │                                 │ │
│ │ Visiting Details                │ │
│ │ [🏠] Flat Number: A-101         │ │
│ │ [👤] Resident: Amit Kumar       │ │
│ │                                 │ │
│ │ [📞] Phone: +91 98765 43210     │ │
│ │ [📝] Purpose: Personal Visit    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [🕐] Entry Time: 10:30 AM           │
│                                     │
│          [Done]                     │
│                                     │
└─────────────────────────────────────┘
```

---

### 4. Staff Attendance Screen Layout

```
┌─────────────────────────────────────────┐
│ StandardHeader                          │
│ "Staff Attendance"                      │
├─────────────────────────────────────────┤
│                                         │
│ [Icon] Staff Attendance                 │
│        Track and manage attendance      │
│                                         │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│ │ 25  │ │ 22  │ │  2  │ │  1  │       │
│ │Total│ │Pres.│ │Abs. │ │Leave│       │
│ └─────┘ └─────┘ └─────┘ └─────┘       │
│                                         │
│ Quick Broadcast                         │
│ ┌─────────────────────────────────┐   │
│ │ Send instant notification       │   │
│ │ to all staff          22 / 25   │   │
│ │                          88%    │   │
│ └─────────────────────────────────┘   │
│                                         │
│ [Search attendance by date...]          │
│                                         │
│ Attendance History                      │
│ ┌─────────────────────────────────┐   │
│ │ [📅] 6 Mar, 2026      22/25 ✓  │   │
│ │                                 │   │
│ │ ┌─────┐ ┌─────┐ ┌─────┐       │   │
│ │ │ 22  │ │  2  │ │  1  │       │   │
│ │ │Pres.│ │Abs. │ │Leave│       │   │
│ │ └─────┘ └─────┘ └─────┘       │   │
│ └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
     [Mark Attendance] FAB
```

**Components**:
- StandardHeader widget
- Page header with icon
- 4 metric cards (Total, Present, Absent, On Leave)
- Quick broadcast card with percentage
- Search bar
- Attendance history list with date cards
- Floating Action Button: "Mark Attendance"

---

## FIRESTORE DATABASE STRUCTURE


### Collection: `visitors`

**Purpose**: Store all visitor records  
**Document ID**: Auto-generated by Firestore

**Fields**:
```dart
{
  visitorName: String,           // Visitor's full name
  phone: String,                 // Phone number with country code
  residentId: String,            // Reference to resident who requested
  residentName: String,          // Resident's name for display
  flatId: String,                // Reference to flat document
  flatLabel: String,             // Flat number (e.g., "A-101")
  purpose: String,               // Visit purpose
  expectedTime: Timestamp?,      // Expected arrival time
  
  // Status tracking
  isApproved: Boolean,           // Approval status
  actualArrival: Timestamp?,     // Check-in timestamp (null = not checked in)
  departure: Timestamp?,         // Check-out timestamp (null = still inside)
  
  // Metadata
  adminId: String,               // Property/building admin ID
  approvedBy: String?,           // Security guard who approved
  createdAt: Timestamp,          // Request creation time
  approvedAt: Timestamp?,        // Approval timestamp
  rejectedAt: Timestamp?,        // Rejection timestamp
  updatedAt: Timestamp           // Last update time
}
```

**Indexes Required**:
- `adminId` + `isApproved` (for pending visitors)
- `adminId` + `actualArrival` + `departure` (for active visitors)
- `adminId` + `departure` (for history)

**Status Logic**:
```
Pending:    isApproved = false, actualArrival = null
Approved:   isApproved = true, actualArrival = null
Active:     isApproved = true, actualArrival != null, departure = null
Completed:  isApproved = true, actualArrival != null, departure != null
```

---

### Collection: `staff`

**Purpose**: Store staff member information  
**Document ID**: Auto-generated by Firestore

**Fields**:
```dart
{
  name: String,                  // Staff member name
  role: String,                  // Job role (Security, Cleaner, etc.)
  phone: String,                 // Contact number
  email: String?,                // Email address
  address: String?,              // Residential address
  
  // Employment details
  joiningDate: Timestamp,        // Date of joining
  salary: Number,                // Monthly salary
  
  // Attendance status
  status: String,                // present, absent, onLeave, offDuty, pending
  lastCheckIn: Timestamp?,       // Last check-in time
  lastCheckOut: Timestamp?,      // Last check-out time
  
  // Metadata
  adminId: String,               // Property/building admin ID
  buildingId: String,            // Building reference
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**Status Values**:
- `present`: Currently on duty
- `absent`: Marked absent for the day
- `onLeave`: On approved leave
- `offDuty`: Checked out for the day
- `pending`: Attendance not marked yet

---

### Collection: `attendance`

**Purpose**: Store daily attendance records  
**Document ID**: `{staffId}_{date}` (e.g., "staff123_2026-03-06")

**Fields**:
```dart
{
  staffId: String,               // Reference to staff document
  date: String,                  // Date in YYYY-MM-DD format
  status: String,                // present, absent, onLeave
  
  // Time tracking
  checkInTime: Timestamp?,       // Check-in timestamp
  checkOutTime: Timestamp?,      // Check-out timestamp
  
  // Metadata
  adminId: String,               // Property/building admin ID
  buildingId: String,            // Building reference
  markedBy: String?,             // Security guard who marked
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

### Collection: `complaints`

**Purpose**: Store complaint/issue records  
**Document ID**: Auto-generated by Firestore

**Fields**:
```dart
{
  title: String,                 // Complaint title
  description: String,           // Detailed description
  category: String,              // plumbing, electrical, security, etc.
  priority: String,              // high, medium, low
  status: String,                // pending, in-progress, resolved
  
  // Reporter details
  residentId: String,            // Who reported
  residentName: String,          // Resident name
  flatId: String?,               // Flat reference
  flatLabel: String?,            // Flat number
  
  // Assignment
  assignedTo: String?,           // Staff member ID
  assignedToName: String?,       // Staff member name
  
  // Metadata
  adminId: String,               // Property/building admin ID
  buildingId: String,            // Building reference
  createdAt: Timestamp,
  updatedAt: Timestamp,
  resolvedAt: Timestamp?         // Resolution timestamp
}
```

**Category Values**:
- `security`: Security-related issues
- `maintenance`: General maintenance
- `plumbing`: Plumbing issues
- `electrical`: Electrical issues
- `cleaning`: Cleaning requests
- `noise`: Noise complaints

---

### Collection: `users`

**Purpose**: Store user authentication and profile data  
**Document ID**: Firebase Auth UID

**Fields** (Security Guard):
```dart
{
  name: String,                  // Guard name
  email: String,                 // Login email
  phone: String,                 // Contact number
  role: String,                  // "security"
  
  // Assignment
  adminId: String,               // Property admin ID
  buildingId: String,            // Assigned building
  buildingName: String,          // Building name
  
  // Status
  isActive: Boolean,             // Account active status
  
  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

### Collection: `flats`

**Purpose**: Store flat/unit information  
**Document ID**: Auto-generated by Firestore

**Fields** (Read-only for Security):
```dart
{
  flatNumber: String,            // Flat number (e.g., "A-101")
  floor: Number,                 // Floor number
  bhk: String,                   // BHK configuration
  
  // Occupancy
  isOccupied: Boolean,           // Occupancy status
  residentId: String?,           // Current resident ID
  residentName: String?,         // Current resident name
  
  // Metadata
  adminId: String,
  buildingId: String,
  buildingName: String,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## DATA FLOW DIAGRAMS


### 1. Visitor QR Check-In Flow

```
┌─────────────────────────────────────────────────────────────┐
│ RESIDENT APP                                                │
├─────────────────────────────────────────────────────────────┤
│ 1. Resident creates visitor request                        │
│    → POST to Firestore: visitors collection                │
│    → Fields: visitorName, phone, residentId, flatId        │
│    → Status: isApproved = false                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - Visitor Management (Pending Tab)            │
├─────────────────────────────────────────────────────────────┤
│ 2. Security guard sees pending request                     │
│    → StreamBuilder: getPendingVisitors()                   │
│    → Query: where('isApproved', '==', false)              │
│                                                             │
│ 3. Guard reviews visitor details                           │
│    → Display: name, phone, flat, resident, purpose        │
│                                                             │
│ 4. Guard approves request                                  │
│    → UPDATE Firestore: visitors/{visitorId}                │
│    → Set: isApproved = true, approvedAt = now()           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ RESIDENT APP                                                │
├─────────────────────────────────────────────────────────────┤
│ 5. Resident receives approval notification                 │
│    → Display QR code with visitor document ID              │
│    → QR Data: visitorId (document ID)                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - QR Scanner                                   │
├─────────────────────────────────────────────────────────────┤
│ 6. Visitor arrives at gate with QR code                    │
│    → Guard opens QR scanner                                │
│    → Camera scans QR code                                  │
│                                                             │
│ 7. Extract visitor ID from QR                              │
│    → Parse QR data (JSON or plain ID)                      │
│    → visitorId = extracted ID                              │
│                                                             │
│ 8. Fetch visitor from Firestore                            │
│    → GET: visitors/{visitorId}                             │
│    → Validate: isApproved == true                          │
│                                                             │
│ 9. Check-in visitor                                        │
│    → UPDATE: visitors/{visitorId}                          │
│    → Set: actualArrival = now()                            │
│    → Status becomes: Active                                │
│                                                             │
│ 10. Show success dialog                                    │
│     → Display: visitor details, entry time                 │
│     → Visitor can now enter                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - Visitor Management (Active Tab)             │
├─────────────────────────────────────────────────────────────┤
│ 11. Visitor appears in Active tab                          │
│     → StreamBuilder: getActiveVisitors()                   │
│     → Query: where('actualArrival', '!=', null)           │
│              .where('departure', '==', null)               │
└─────────────────────────────────────────────────────────────┘
```

---

### 2. Visitor QR Check-Out Flow

```
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - QR Scanner                                   │
├─────────────────────────────────────────────────────────────┤
│ 1. Visitor leaves and shows QR code                        │
│    → Guard scans same QR code                              │
│    → Extract visitorId                                     │
│                                                             │
│ 2. Fetch visitor from Firestore                            │
│    → GET: visitors/{visitorId}                             │
│    → Check: actualArrival != null (already checked in)     │
│    → Check: departure == null (not checked out yet)        │
│                                                             │
│ 3. Check-out visitor                                       │
│    → UPDATE: visitors/{visitorId}                          │
│    → Set: departure = now()                                │
│    → Status becomes: Completed                             │
│                                                             │
│ 4. Calculate duration                                      │
│    → duration = departure - actualArrival                  │
│                                                             │
│ 5. Show success dialog                                     │
│    → Display: visitor details, exit time, duration         │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - Visitor Management (History Tab)            │
├─────────────────────────────────────────────────────────────┤
│ 6. Visitor moves to History tab                            │
│    → StreamBuilder: getHistoryVisitors()                   │
│    → Query: where('departure', '!=', null)                 │
│    → Display: entry time, exit time, duration              │
└─────────────────────────────────────────────────────────────┘
```

---

### 3. Staff Attendance Marking Flow

```
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - Staff Attendance Screen                      │
├─────────────────────────────────────────────────────────────┤
│ 1. Guard opens attendance screen                           │
│    → Display today's statistics                            │
│    → StreamBuilder: getTodayStats()                        │
│                                                             │
│ 2. Guard clicks "Mark Attendance" FAB                      │
│    → Navigate to Attendance Marking Screen                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - Attendance Marking Screen                    │
├─────────────────────────────────────────────────────────────┤
│ 3. Display list of all staff members                       │
│    → StreamBuilder: getStaffMembers()                      │
│    → Show current status for each                          │
│                                                             │
│ 4. Guard marks staff as Present                            │
│    → CALL: markPresent(staffId)                            │
│                                                             │
│ 5. Update Firestore (2 operations)                         │
│    a) CREATE/UPDATE: attendance/{staffId}_{today}          │
│       → Set: status = 'present'                            │
│       → Set: checkInTime = now()                           │
│                                                             │
│    b) UPDATE: staff/{staffId}                              │
│       → Set: status = 'present'                            │
│       → Set: lastCheckIn = now()                           │
│                                                             │
│ 6. Real-time update propagates                             │
│    → Staff Attendance Screen updates statistics            │
│    → Staff card shows green "Present" badge                │
└─────────────────────────────────────────────────────────────┘
```

---

### 4. Complaint Tracking Flow

```
┌─────────────────────────────────────────────────────────────┐
│ RESIDENT APP                                                │
├─────────────────────────────────────────────────────────────┤
│ 1. Resident creates complaint                              │
│    → POST to Firestore: complaints collection              │
│    → Fields: title, description, category, priority        │
│    → Status: pending                                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ ADMIN APP                                                   │
├─────────────────────────────────────────────────────────────┤
│ 2. Admin assigns complaint to security                     │
│    → UPDATE: complaints/{complaintId}                      │
│    → Set: assignedTo = securityStaffId                     │
│    → Set: status = 'in-progress'                           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ SECURITY APP - Complaint Tracking Screen                    │
├─────────────────────────────────────────────────────────────┤
│ 3. Security guard sees assigned complaint                  │
│    → StreamBuilder: getComplaints()                        │
│    → Filter: where('assignedTo', '==', securityId)        │
│                                                             │
│ 4. Guard reviews complaint details                         │
│    → Display: title, description, category, priority       │
│    → Display: resident name, flat number                   │
│                                                             │
│ 5. Guard updates status to "Resolved"                      │
│    → UPDATE: complaints/{complaintId}                      │
│    → Set: status = 'resolved'                              │
│    → Set: resolvedAt = now()                               │
│                                                             │
│ 6. Real-time update                                        │
│    → Complaint moves to Resolved filter                    │
│    → Admin and Resident receive notification               │
└─────────────────────────────────────────────────────────────┘
```

---

## USER ACTIONS & INTERACTIONS


### Visitor Management Actions

#### Approve Visitor (Pending Tab)
```dart
// User Action
1. Guard taps "Approve" button on visitor card

// System Response
2. Show loading indicator
3. Call: _visitorService.approveVisitor(visitorId)
4. Call: _visitorService.checkInVisitor(visitorId)
5. Update Firestore:
   - isApproved = true
   - approvedAt = now()
   - actualArrival = now()
6. Show success snackbar: "{name} approved and checked in"
7. Visitor moves to Active tab automatically (StreamBuilder)
8. Haptic feedback: mediumImpact()
```

#### Reject Visitor (Pending Tab)
```dart
// User Action
1. Guard taps "Reject" button on visitor card

// System Response
2. Show loading indicator
3. Call: _visitorService.rejectVisitor(visitorId)
4. Update Firestore:
   - isApproved = false
   - rejectedAt = now()
5. Show error snackbar: "{name} request rejected"
6. Visitor removed from Pending tab
7. Haptic feedback: mediumImpact()
```

#### Mark Exit (Active Tab)
```dart
// User Action
1. Guard taps "Mark Exit" button on visitor card

// System Response
2. Show loading indicator
3. Call: _visitorService.checkOutVisitor(visitorId)
4. Update Firestore:
   - departure = now()
5. Calculate duration: departure - actualArrival
6. Show success snackbar: "{name} marked as exited"
7. Visitor moves to History tab automatically
8. Haptic feedback: mediumImpact()
```

#### Search Visitors
```dart
// User Action
1. Guard types in search bar

// System Response
2. Filter visitors in real-time by:
   - Visitor name
   - Resident name
   - Flat number
   - Phone number
   - Purpose
3. Update list dynamically
4. Show "No visitors found" if empty
```

---

### QR Scanner Actions

#### Scan QR Code
```dart
// User Action
1. Guard opens QR scanner
2. Points camera at QR code

// System Response
3. Request camera permission (if not granted)
4. Initialize MobileScannerController
5. Start camera preview
6. Detect QR code barcode
7. Extract visitor ID from QR data
8. Fetch visitor from Firestore
9. Validate approval status
10. Determine check-in or check-out
11. Update Firestore with timestamp
12. Show success dialog with visitor details
13. Haptic feedback: mediumImpact()
```

#### Toggle Flash
```dart
// User Action
1. Guard taps flash button

// System Response
2. Toggle torch on/off
3. Update button icon state
4. Haptic feedback: lightImpact()
```

#### Handle Errors
```dart
// Invalid QR Code
- Show error dialog: "Visitor not found in the system"
- Allow retry

// Not Approved
- Show warning dialog: "Visitor request is still pending approval"
- Suggest approving from Visitor Management

// Already Checked Out
- Show error dialog: "Visitor has already checked out"
- Display last exit time
```

---

### Staff Attendance Actions

#### Mark Present
```dart
// User Action
1. Guard taps "Present" for staff member

// System Response
2. Call: _attendanceService.markPresent(staffId)
3. Update Firestore:
   a) attendance/{staffId}_{today}:
      - status = 'present'
      - checkInTime = now()
   b) staff/{staffId}:
      - status = 'present'
      - lastCheckIn = now()
4. Update statistics in real-time
5. Show green "Present" badge
6. Haptic feedback: lightImpact()
```

#### Mark Absent
```dart
// User Action
1. Guard taps "Absent" for staff member

// System Response
2. Call: _attendanceService.markAbsent(staffId)
3. Update Firestore:
   a) attendance/{staffId}_{today}:
      - status = 'absent'
   b) staff/{staffId}:
      - status = 'absent'
4. Update statistics in real-time
5. Show red "Absent" badge
6. Haptic feedback: lightImpact()
```

#### Mark On Leave
```dart
// User Action
1. Guard taps "On Leave" for staff member

// System Response
2. Call: _attendanceService.markOnLeave(staffId)
3. Update Firestore:
   a) attendance/{staffId}_{today}:
      - status = 'onLeave'
   b) staff/{staffId}:
      - status = 'onLeave'
4. Update statistics in real-time
5. Show purple "On Leave" badge
6. Haptic feedback: lightImpact()
```

#### View Attendance History
```dart
// User Action
1. Guard taps on date card

// System Response
2. Navigate to Attendance Details Screen
3. Fetch attendance records for that date
4. Display staff list with status badges
5. Show present/absent/on leave counts
```

---

### Complaint Tracking Actions

#### View Assigned Complaints
```dart
// User Action
1. Guard opens Complaint Tracking screen

// System Response
2. StreamBuilder: getComplaints()
3. Filter: where('assignedTo', '==', securityId)
4. Display complaints with status badges
5. Real-time updates when new complaints assigned
```

#### Update Complaint Status
```dart
// User Action
1. Guard taps on complaint card
2. Selects new status (In Progress / Resolved)

// System Response
3. Show confirmation dialog
4. Update Firestore:
   - status = newStatus
   - updatedAt = now()
   - resolvedAt = now() (if resolved)
5. Show success snackbar
6. Update status badge color
7. Haptic feedback: mediumImpact()
```

#### Filter Complaints
```dart
// User Action
1. Guard selects filter (All / Pending / In Progress / Resolved)

// System Response
2. Filter complaints by status
3. Update list dynamically
4. Show count badge on filter tabs
```

---

## FLUTTER WIDGETS & COMPONENTS


### Reusable Widgets from Admin App

#### 1. StandardHeader
**File**: `lib/widgets/standard_header.dart`  
**Purpose**: Consistent header across all screens  
**Usage**:
```dart
StandardHeader(
  title: 'Visitor Management',
  showBackButton: true,
)
```

**Properties**:
- `title`: Screen title
- `showBackButton`: Show/hide back button
- Gradient background
- Automatic safe area handling

---

#### 2. Visitor Card Components

**Pending Visitor Card**:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(...)],
  ),
  child: Column(
    children: [
      // Profile icon + name + phone
      Row(
        children: [
          Container(48x48, yellow background, person icon),
          Column(name, phone),
        ],
      ),
      
      // Flat and resident info
      Row(
        children: [
          Icon(home), Text(flatLabel),
          Icon(person), Text(residentName),
        ],
      ),
      
      // Purpose
      Row(
        children: [Icon(description), Text(purpose)],
      ),
      
      // Action buttons
      Row(
        children: [
          ElevatedButton("Approve", green),
          OutlinedButton("Reject", red),
        ],
      ),
    ],
  ),
)
```

**Active Visitor Card**:
```dart
Container(
  decoration: BoxDecoration(...),
  child: Column(
    children: [
      // Same header as pending
      // Same info rows
      
      // Entry time badge
      Container(
        decoration: BoxDecoration(green background),
        child: Row(
          children: [
            Icon(login), 
            Text("Entered at: 10:30 AM"),
          ],
        ),
      ),
      
      // Mark Exit button
      ElevatedButton("Mark Exit", orange),
    ],
  ),
)
```

**History Visitor Card**:
```dart
Container(
  decoration: BoxDecoration(...),
  child: Column(
    children: [
      // Same header
      // Same info rows
      
      // Time badges
      Row(
        children: [
          Container(green, "Entry: 10:30 AM"),
          Container(orange, "Exit: 12:45 PM"),
        ],
      ),
      
      // Duration badge
      Container(
        purple background,
        "Duration: 2h 15m",
      ),
    ],
  ),
)
```

---

#### 3. Metric Card
**Purpose**: Display statistics  
**Usage**:
```dart
Container(
  padding: EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [...],
  ),
  child: Column(
    children: [
      Container(40x40, circular, colored background, icon),
      SizedBox(height: 8),
      Text(value, fontSize: 18, fontWeight: w700, color),
      Text(label, fontSize: 11, fontWeight: w600),
      Text(subtitle, fontSize: 9, color),
    ],
  ),
)
```

---

#### 4. Search Bar
**Purpose**: Filter lists  
**Usage**:
```dart
Container(
  height: 48,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(Color(0xFFE5E7EB)),
    boxShadow: [...],
  ),
  child: TextField(
    decoration: InputDecoration(
      hintText: 'Search visitors...',
      prefixIcon: Icon(Icons.search),
      suffixIcon: IconButton(Icons.clear),
      border: InputBorder.none,
    ),
  ),
)
```

---

#### 5. Tab Switcher
**Purpose**: Switch between content tabs  
**Usage**:
```dart
Container(
  height: 48,
  decoration: BoxDecoration(
    color: Color(0xFFF3F4F6),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Expanded(child: TabButton('Pending', 0)),
      Expanded(child: TabButton('Active', 1)),
      Expanded(child: TabButton('History', 2)),
    ],
  ),
)

// TabButton widget
GestureDetector(
  onTap: () => onTabChanged(index),
  child: Container(
    margin: EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: isSelected ? Colors.white : transparent,
      borderRadius: BorderRadius.circular(8),
      boxShadow: isSelected ? [...] : null,
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: w600,
          color: isSelected ? dark : gray,
        ),
      ),
    ),
  ),
)
```

---

#### 6. Status Badge
**Purpose**: Display status with color coding  
**Usage**:
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: statusColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: statusColor.withOpacity(0.3)),
  ),
  child: Row(
    children: [
      Container(6x6, circular, statusColor),
      SizedBox(width: 6),
      Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: w600,
          color: statusColor,
        ),
      ),
    ],
  ),
)
```

**Status Colors**:
- Present/Active: `Color(0xFF16A34A)` (Green)
- Pending: `Color(0xFFF59E0B)` (Orange)
- Absent/Rejected: `Color(0xFFEF4444)` (Red)
- On Leave: `Color(0xFF9333EA)` (Purple)
- Completed: `Color(0xFF6B7280)` (Gray)

---

#### 7. Empty State
**Purpose**: Show when no data available  
**Usage**:
```dart
Center(
  child: Padding(
    padding: EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 64,
          color: Color(0xFFE5E7EB),
        ),
        SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: w600,
            color: Color(0xFF6B7280),
          ),
        ),
        SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  ),
)
```

---

#### 8. Floating Action Button
**Purpose**: Primary action on screen  
**Usage**:
```dart
FloatingActionButton.extended(
  onPressed: onPressed,
  backgroundColor: Color(0xFF2563EB),
  elevation: 4,
  icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
  label: Text(
    'Scan QR',
    style: TextStyle(
      color: Colors.white,
      fontWeight: w600,
      fontSize: 14,
    ),
  ),
)
```

---

#### 9. Success/Error Dialog
**Purpose**: Show operation result  
**Usage**:
```dart
Dialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  child: Container(
    padding: EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status icon with colored background
        Container(80x80, circular, colored background, icon),
        SizedBox(height: 20),
        
        // Title
        Text(title, fontSize: 24, fontWeight: w700, color),
        SizedBox(height: 8),
        
        // Subtitle
        Text(subtitle, fontSize: 14, color: gray),
        SizedBox(height: 24),
        
        // Information card
        Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              // Info rows with icons
            ],
          ),
        ),
        
        SizedBox(height: 20),
        
        // Time badge
        Container(colored background, time info),
        
        SizedBox(height: 24),
        
        // Action button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text('Done'),
          ),
        ),
      ],
    ),
  ),
)
```

---

#### 10. SnackBar
**Purpose**: Show brief feedback  
**Usage**:
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

---

## NAVIGATION STRUCTURE


### App Navigation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     LOGIN SCREEN                            │
│                                                             │
│  Email: security@property.com                               │
│  Password: ********                                         │
│                                                             │
│              [Login Button]                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
                  (Authentication)
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                  SECURITY DASHBOARD                         │
│                   (Home Screen)                             │
│                                                             │
│  - Today's visitor statistics                               │
│  - Quick action buttons                                     │
│  - Recent activity feed                                     │
│                                                             │
│  Bottom Navigation:                                         │
│  [Dashboard] [Visitors] [Attendance] [Profile]             │
└─────────────────────────────────────────────────────────────┘
         ↓              ↓              ↓              ↓
    Dashboard      Visitors       Attendance      Profile
         │              │              │              │
         │              ├─ Pending    ├─ Today       ├─ Edit Profile
         │              ├─ Active     ├─ History     ├─ Settings
         │              └─ History    └─ Mark        └─ Logout
         │                   │
         │                   └─ QR Scanner
         │                        │
         │                        ├─ Check-In
         │                        └─ Check-Out
         │
         └─ Complaint Tracking
              │
              ├─ Pending
              ├─ In Progress
              └─ Resolved
```

---

### Route Definitions

```dart
// Main routes
const String loginRoute = '/login';
const String dashboardRoute = '/dashboard';
const String visitorManagementRoute = '/visitors';
const String qrScannerRoute = '/qr-scanner';
const String staffAttendanceRoute = '/attendance';
const String attendanceMarkingRoute = '/attendance/mark';
const String attendanceDetailsRoute = '/attendance/details';
const String complaintTrackingRoute = '/complaints';
const String profileRoute = '/profile';

// Navigation method
void navigateToScreen(BuildContext context, String route, {Object? arguments}) {
  Navigator.pushNamed(context, route, arguments: arguments);
}

// Navigation with replacement (no back)
void navigateAndReplace(BuildContext context, String route) {
  Navigator.pushReplacementNamed(context, route);
}

// Go back
void goBack(BuildContext context) {
  Navigator.pop(context);
}
```

---

### Bottom Navigation Bar

```dart
BottomNavigationBar(
  currentIndex: _currentIndex,
  onTap: (index) {
    setState(() => _currentIndex = index);
    _navigateToPage(index);
  },
  type: BottomNavigationBarType.fixed,
  selectedItemColor: Color(0xFF2563EB),
  unselectedItemColor: Color(0xFF9CA3AF),
  items: [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people),
      label: 'Visitors',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.access_time),
      label: 'Attendance',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
)
```

---

### Screen Transitions

**Push Navigation** (with back button):
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => QrGateScannerScreen(),
  ),
);
```

**Replace Navigation** (no back):
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => SecurityDashboard(),
  ),
);
```

**Pop Navigation** (go back):
```dart
Navigator.pop(context);
```

**Pop with Result**:
```dart
// Return result
Navigator.pop(context, true);

// Receive result
final result = await Navigator.push(...);
if (result == true) {
  // Handle success
}
```

---

## FIRESTORE QUERIES

### Visitor Queries

**Get Pending Visitors**:
```dart
Stream<List<VisitorModel>> getPendingVisitors() {
  return _firestore
    .collection('visitors')
    .where('adminId', isEqualTo: adminId)
    .where('isApproved', isEqualTo: false)
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => 
      VisitorModel.fromFirestore(doc.id, doc.data())
    ).toList());
}
```

**Get Active Visitors**:
```dart
Stream<List<VisitorModel>> getActiveVisitors() {
  return _firestore
    .collection('visitors')
    .where('adminId', isEqualTo: adminId)
    .where('isApproved', isEqualTo: true)
    .where('actualArrival', isNotEqualTo: null)
    .where('departure', isEqualTo: null)
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => 
      VisitorModel.fromFirestore(doc.id, doc.data())
    ).toList());
}
```

**Get History Visitors**:
```dart
Stream<List<VisitorModel>> getHistoryVisitors() {
  return _firestore
    .collection('visitors')
    .where('adminId', isEqualTo: adminId)
    .where('departure', isNotEqualTo: null)
    .snapshots()
    .map((snapshot) {
      final visitors = snapshot.docs.map((doc) => 
        VisitorModel.fromFirestore(doc.id, doc.data())
      ).toList();
      
      // Sort by checkout time
      visitors.sort((a, b) => 
        b.checkOutTime!.compareTo(a.checkOutTime!)
      );
      
      return visitors.take(50).toList();
    });
}
```

**Get Visitor by ID**:
```dart
Future<VisitorModel?> getVisitorById(String visitorId) async {
  final doc = await _firestore
    .collection('visitors')
    .doc(visitorId)
    .get();
  
  if (doc.exists) {
    return VisitorModel.fromFirestore(doc.id, doc.data()!);
  }
  return null;
}
```

---

### Staff Attendance Queries

**Get Today's Stats**:
```dart
Future<AttendanceStats> getTodayStats() async {
  final staffSnapshot = await _firestore
    .collection('staff')
    .where('adminId', isEqualTo: adminId)
    .get();
  
  int total = staffSnapshot.docs.length;
  int present = 0;
  int absent = 0;
  int onLeave = 0;
  
  for (var doc in staffSnapshot.docs) {
    final status = doc.data()['status'] as String?;
    if (status == 'present') present++;
    else if (status == 'absent') absent++;
    else if (status == 'onLeave') onLeave++;
  }
  
  return AttendanceStats(
    totalStaff: total,
    present: present,
    absent: absent,
    onLeave: onLeave,
    pending: total - (present + absent + onLeave),
  );
}
```

**Get Attendance History**:
```dart
Stream<List<DailyAttendanceSummary>> getAttendanceHistory({int days = 30}) {
  final startDate = DateTime.now().subtract(Duration(days: days));
  final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
  
  return _firestore
    .collection('attendance')
    .where('adminId', isEqualTo: adminId)
    .where('date', isGreaterThanOrEqualTo: startDateStr)
    .snapshots()
    .map((snapshot) {
      // Group by date
      Map<String, DailyAttendanceSummary> summaries = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String;
        final status = data['status'] as String;
        
        if (!summaries.containsKey(date)) {
          summaries[date] = DailyAttendanceSummary(
            date: date,
            present: 0,
            absent: 0,
            onLeave: 0,
            totalStaff: 0,
          );
        }
        
        if (status == 'present') summaries[date]!.present++;
        else if (status == 'absent') summaries[date]!.absent++;
        else if (status == 'onLeave') summaries[date]!.onLeave++;
      }
      
      return summaries.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
}
```

**Mark Attendance**:
```dart
Future<void> markPresent(String staffId) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final attendanceId = '${staffId}_$today';
  
  // Update attendance record
  await _firestore
    .collection('attendance')
    .doc(attendanceId)
    .set({
      'staffId': staffId,
      'date': today,
      'status': 'present',
      'checkInTime': FieldValue.serverTimestamp(),
      'adminId': adminId,
      'buildingId': buildingId,
      'markedBy': securityId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  
  // Update staff record
  await _firestore
    .collection('staff')
    .doc(staffId)
    .update({
      'status': 'present',
      'lastCheckIn': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
}
```

---

### Complaint Queries

**Get Assigned Complaints**:
```dart
Stream<List<ComplaintModel>> getAssignedComplaints(String securityId) {
  return _firestore
    .collection('complaints')
    .where('adminId', isEqualTo: adminId)
    .where('assignedTo', isEqualTo: securityId)
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => 
      ComplaintModel.fromFirestore(doc.id, doc.data())
    ).toList());
}
```

**Update Complaint Status**:
```dart
Future<void> updateComplaintStatus(
  String complaintId, 
  String newStatus
) async {
  final updateData = {
    'status': newStatus,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  
  if (newStatus == 'resolved') {
    updateData['resolvedAt'] = FieldValue.serverTimestamp();
  }
  
  await _firestore
    .collection('complaints')
    .doc(complaintId)
    .update(updateData);
}
```

---

## REQUIRED PACKAGES


### pubspec.yaml Dependencies

```yaml
name: security_app
description: Security Guard App for Gated Community Management

dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^3.8.1
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.0
  
  # QR Scanner
  mobile_scanner: ^5.2.3
  permission_handler: ^11.3.1
  
  # UI Components
  cupertino_icons: ^1.0.8
  
  # Utilities
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/icons/
```

---

### Package Usage

#### 1. firebase_core
**Purpose**: Initialize Firebase  
**Usage**:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(SecurityApp());
}
```

#### 2. firebase_auth
**Purpose**: User authentication  
**Usage**:
```dart
final FirebaseAuth _auth = FirebaseAuth.instance;

// Sign in
Future<UserCredential> signIn(String email, String password) async {
  return await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
}

// Get current user
User? getCurrentUser() {
  return _auth.currentUser;
}

// Sign out
Future<void> signOut() async {
  await _auth.signOut();
}
```

#### 3. cloud_firestore
**Purpose**: Database operations  
**Usage**:
```dart
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Get collection
CollectionReference visitors = _firestore.collection('visitors');

// Stream data
Stream<QuerySnapshot> getVisitors() {
  return visitors.snapshots();
}

// Add document
Future<void> addVisitor(Map<String, dynamic> data) {
  return visitors.add(data);
}

// Update document
Future<void> updateVisitor(String id, Map<String, dynamic> data) {
  return visitors.doc(id).update(data);
}
```

#### 4. mobile_scanner
**Purpose**: QR code scanning  
**Usage**:
```dart
MobileScannerController _controller = MobileScannerController(
  detectionSpeed: DetectionSpeed.noDuplicates,
  facing: CameraFacing.back,
);

MobileScanner(
  controller: _controller,
  onDetect: (BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      print('QR Code: ${barcode.rawValue}');
    }
  },
)
```

#### 5. permission_handler
**Purpose**: Request camera permissions  
**Usage**:
```dart
Future<void> requestCameraPermission() async {
  final status = await Permission.camera.request();
  
  if (status.isGranted) {
    // Permission granted
  } else if (status.isDenied) {
    // Permission denied
  } else if (status.isPermanentlyDenied) {
    // Open app settings
    await openAppSettings();
  }
}
```

#### 6. intl
**Purpose**: Date/time formatting  
**Usage**:
```dart
import 'package:intl/intl.dart';

// Format date
String formatDate(DateTime date) {
  return DateFormat('dd MMM, yyyy').format(date);
}

// Format time
String formatTime(DateTime time) {
  return DateFormat('hh:mm a').format(time);
}

// Format duration
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}
```

---

## PERMISSIONS & CONFIGURATION

### Android Configuration

**android/app/src/main/AndroidManifest.xml**:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Camera permission for QR scanning -->
    <uses-permission android:name="android.permission.CAMERA"/>
    
    <!-- Internet permission for Firestore -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:label="Security App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

**android/app/build.gradle**:
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.property.security_app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-analytics'
}
```

---

### iOS Configuration

**ios/Runner/Info.plist**:
```xml
<dict>
    <!-- Camera permission -->
    <key>NSCameraUsageDescription</key>
    <string>Camera access is required to scan visitor QR codes</string>
    
    <!-- App name -->
    <key>CFBundleName</key>
    <string>Security App</string>
    
    <!-- App display name -->
    <key>CFBundleDisplayName</key>
    <string>Security App</string>
</dict>
```

**ios/Podfile**:
```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

---

## AUTHENTICATION & SECURITY

### User Roles

**Security Guard Role**:
```dart
{
  role: "security",
  permissions: [
    "visitor.view",
    "visitor.approve",
    "visitor.reject",
    "visitor.checkin",
    "visitor.checkout",
    "staff.view",
    "attendance.mark",
    "attendance.view",
    "complaint.view",
    "complaint.update",
  ]
}
```

### Login Flow

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Verify role
      final userDoc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();
      
      final role = userDoc.data()?['role'] as String?;
      
      if (role != 'security') {
        await _auth.signOut();
        throw Exception('Unauthorized: Security role required');
      }
      
      return credential.user;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }
  
  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Auth state stream
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
```

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is security
    function isSecurity() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'security';
    }
    
    // Helper function to check admin match
    function matchesAdmin() {
      return request.auth != null && 
             resource.data.adminId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.adminId;
    }
    
    // Visitors collection
    match /visitors/{visitorId} {
      // Security can read visitors for their property
      allow read: if isSecurity() && matchesAdmin();
      
      // Security can update approval status and timestamps
      allow update: if isSecurity() && 
                       matchesAdmin() &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['isApproved', 'approvedAt', 'actualArrival', 
                                   'departure', 'updatedAt', 'approvedBy']);
    }
    
    // Staff collection
    match /staff/{staffId} {
      // Security can read staff for their property
      allow read: if isSecurity() && matchesAdmin();
      
      // Security can update attendance status
      allow update: if isSecurity() && 
                       matchesAdmin() &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['status', 'lastCheckIn', 'lastCheckOut', 'updatedAt']);
    }
    
    // Attendance collection
    match /attendance/{attendanceId} {
      // Security can read attendance for their property
      allow read: if isSecurity() && matchesAdmin();
      
      // Security can create/update attendance records
      allow create, update: if isSecurity() && 
                               request.resource.data.adminId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.adminId;
    }
    
    // Complaints collection
    match /complaints/{complaintId} {
      // Security can read complaints assigned to them
      allow read: if isSecurity() && 
                     (matchesAdmin() || resource.data.assignedTo == request.auth.uid);
      
      // Security can update status of assigned complaints
      allow update: if isSecurity() && 
                       resource.data.assignedTo == request.auth.uid &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['status', 'updatedAt', 'resolvedAt']);
    }
    
    // Users collection (read-only for security)
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
    }
    
    // Flats collection (read-only for security)
    match /flats/{flatId} {
      allow read: if isSecurity() && matchesAdmin();
    }
  }
}
```

---

## TESTING GUIDE


### Test Scenarios

#### 1. Visitor Management Testing

**Test Case: Approve Visitor**
```
Prerequisites:
- Security guard logged in
- Visitor request exists in Firestore (isApproved = false)

Steps:
1. Open Visitor Management screen
2. Navigate to Pending tab
3. Verify visitor card displays:
   - Visitor name
   - Phone number
   - Flat number
   - Resident name
   - Purpose
4. Tap "Approve" button
5. Verify loading indicator appears
6. Verify success snackbar shows
7. Verify visitor moves to Active tab
8. Check Firestore:
   - isApproved = true
   - approvedAt = timestamp
   - actualArrival = timestamp

Expected Result:
✓ Visitor approved and checked in
✓ Appears in Active tab
✓ Firestore updated correctly
```

**Test Case: Reject Visitor**
```
Steps:
1. Open Visitor Management screen
2. Navigate to Pending tab
3. Tap "Reject" button on visitor card
4. Verify error snackbar shows
5. Verify visitor removed from Pending tab
6. Check Firestore:
   - isApproved = false
   - rejectedAt = timestamp

Expected Result:
✓ Visitor rejected
✓ Removed from Pending tab
✓ Firestore updated correctly
```

**Test Case: Mark Exit**
```
Prerequisites:
- Visitor is checked in (actualArrival != null, departure = null)

Steps:
1. Open Visitor Management screen
2. Navigate to Active tab
3. Verify visitor card shows entry time
4. Tap "Mark Exit" button
5. Verify success snackbar shows
6. Verify visitor moves to History tab
7. Check Firestore:
   - departure = timestamp
8. Verify History tab shows:
   - Entry time
   - Exit time
   - Duration

Expected Result:
✓ Visitor checked out
✓ Appears in History tab with duration
✓ Firestore updated correctly
```

---

#### 2. QR Scanner Testing

**Test Case: Check-In via QR**
```
Prerequisites:
- Visitor approved (isApproved = true, actualArrival = null)
- QR code generated with visitor document ID

Steps:
1. Open QR Scanner
2. Grant camera permission
3. Point camera at QR code
4. Verify QR code scanned
5. Verify success dialog shows:
   - "Entry Granted ✓"
   - Visitor name
   - Flat number
   - Resident name
   - Phone
   - Purpose
   - Entry time
6. Tap "Done"
7. Check Firestore:
   - actualArrival = timestamp
8. Verify visitor in Active tab

Expected Result:
✓ QR code scanned successfully
✓ Visitor checked in
✓ Success dialog displayed
✓ Firestore updated
```

**Test Case: Check-Out via QR**
```
Prerequisites:
- Visitor checked in (actualArrival != null, departure = null)

Steps:
1. Open QR Scanner
2. Scan same QR code
3. Verify success dialog shows:
   - "Exit Recorded ✓"
   - Visitor details
   - Exit time
4. Check Firestore:
   - departure = timestamp
5. Verify visitor in History tab with duration

Expected Result:
✓ Visitor checked out
✓ Duration calculated
✓ Moved to History
```

**Test Case: Invalid QR Code**
```
Steps:
1. Open QR Scanner
2. Scan invalid/unknown QR code
3. Verify error dialog shows:
   - "Invalid QR Code"
   - "Visitor not found in the system"

Expected Result:
✓ Error handled gracefully
✓ User can retry
```

**Test Case: Not Approved Visitor**
```
Prerequisites:
- Visitor not approved (isApproved = false)

Steps:
1. Scan visitor QR code
2. Verify warning dialog shows:
   - "Visitor Not Approved"
   - "Request is still pending approval"

Expected Result:
✓ Check-in prevented
✓ Clear error message
```

---

#### 3. Staff Attendance Testing

**Test Case: Mark Present**
```
Steps:
1. Open Staff Attendance screen
2. Verify today's statistics displayed
3. Tap "Mark Attendance" FAB
4. Select staff member
5. Tap "Present" button
6. Verify:
   - Green "Present" badge appears
   - Statistics update (Present count +1)
7. Check Firestore:
   - attendance/{staffId}_{today}: status = 'present', checkInTime = timestamp
   - staff/{staffId}: status = 'present', lastCheckIn = timestamp

Expected Result:
✓ Staff marked present
✓ Statistics updated
✓ Firestore updated
```

**Test Case: Mark Absent**
```
Steps:
1. Mark staff as absent
2. Verify red "Absent" badge
3. Verify statistics update (Absent count +1)
4. Check Firestore updated

Expected Result:
✓ Staff marked absent
✓ UI and database updated
```

**Test Case: View Attendance History**
```
Steps:
1. Open Staff Attendance screen
2. Scroll to attendance history
3. Verify date cards show:
   - Date
   - Present/Absent/On Leave counts
   - Attendance percentage
   - Color-coded badge
4. Tap on date card
5. Verify Attendance Details screen opens
6. Verify staff list with status badges

Expected Result:
✓ History displayed correctly
✓ Details screen accessible
```

---

#### 4. Search & Filter Testing

**Test Case: Search Visitors**
```
Steps:
1. Open Visitor Management
2. Type visitor name in search bar
3. Verify filtered results
4. Clear search
5. Search by phone number
6. Verify filtered results
7. Search by flat number
8. Verify filtered results

Expected Result:
✓ Search works for all fields
✓ Results update in real-time
✓ Clear button works
```

**Test Case: Tab Switching**
```
Steps:
1. Open Visitor Management
2. Tap "Pending" tab
3. Verify pending visitors displayed
4. Tap "Active" tab
5. Verify active visitors displayed
6. Tap "History" tab
7. Verify history visitors displayed
8. Verify statistics update for each tab

Expected Result:
✓ Tabs switch smoothly
✓ Correct data displayed
✓ Statistics match tab content
```

---

#### 5. Real-Time Updates Testing

**Test Case: Real-Time Visitor Updates**
```
Setup:
- Two devices: Admin App and Security App

Steps:
1. Admin App: Create new visitor request
2. Security App: Verify visitor appears in Pending tab immediately
3. Security App: Approve visitor
4. Admin App: Verify visitor status updated
5. Security App: Check-in visitor via QR
6. Admin App: Verify visitor in Active tab

Expected Result:
✓ Changes propagate in real-time
✓ No manual refresh needed
✓ StreamBuilder updates automatically
```

---

#### 6. Error Handling Testing

**Test Case: Network Error**
```
Steps:
1. Disable internet connection
2. Try to approve visitor
3. Verify error message displayed
4. Enable internet
5. Retry operation
6. Verify success

Expected Result:
✓ Error handled gracefully
✓ User informed of issue
✓ Retry works after reconnection
```

**Test Case: Permission Denied**
```
Steps:
1. Deny camera permission
2. Open QR Scanner
3. Verify permission dialog shows
4. Tap "Settings"
5. Grant permission
6. Return to app
7. Verify camera works

Expected Result:
✓ Permission request handled
✓ Settings link works
✓ Camera initializes after grant
```

---

## DEPLOYMENT CHECKLIST

### Pre-Deployment

- [ ] All features tested on Android
- [ ] All features tested on iOS
- [ ] QR scanner works with real camera
- [ ] Firestore rules configured
- [ ] Firebase project created
- [ ] google-services.json added (Android)
- [ ] GoogleService-Info.plist added (iOS)
- [ ] App icons configured
- [ ] Splash screen configured
- [ ] App name set correctly
- [ ] Package name/Bundle ID set

### Firebase Setup

- [ ] Create Firebase project
- [ ] Enable Authentication (Email/Password)
- [ ] Create Firestore database
- [ ] Deploy Firestore security rules
- [ ] Create composite indexes:
  - `visitors`: adminId + isApproved
  - `visitors`: adminId + actualArrival + departure
  - `visitors`: adminId + departure
  - `staff`: adminId + status
  - `attendance`: adminId + date
  - `complaints`: adminId + assignedTo

### User Setup

- [ ] Create security guard user accounts
- [ ] Set role = "security" in users collection
- [ ] Assign adminId and buildingId
- [ ] Test login with security credentials
- [ ] Verify role-based access works

### Testing

- [ ] End-to-end visitor flow
- [ ] QR check-in/check-out
- [ ] Staff attendance marking
- [ ] Real-time updates
- [ ] Search and filters
- [ ] Error handling
- [ ] Permission handling
- [ ] Network error recovery

### Build & Release

- [ ] Update version number
- [ ] Build release APK (Android)
- [ ] Build release IPA (iOS)
- [ ] Test release builds
- [ ] Upload to Play Store (Android)
- [ ] Upload to App Store (iOS)

---

## SUMMARY

This Security App specification provides a complete blueprint for building a security guard application that:

1. **Reuses Admin App UI**: Exact same design system, colors, layouts, and components
2. **Focused Features**: Only security-relevant features (visitors, QR scanning, attendance, complaints)
3. **Real-Time Data**: Firestore integration with StreamBuilder for live updates
4. **Production Ready**: Complete with authentication, permissions, error handling
5. **Well Documented**: Detailed screens, flows, queries, and testing procedures

### Key Features Extracted:
- ✅ Visitor Management (Pending/Active/History)
- ✅ QR Gate Scanner (Check-in/Check-out)
- ✅ Staff Attendance Tracking
- ✅ Complaint Tracking
- ✅ Real-time Firestore Integration
- ✅ Role-based Access Control

### Implementation Approach:
1. Copy UI components from Admin App
2. Implement security-specific screens
3. Configure Firestore with security rules
4. Add QR scanning functionality
5. Test all flows end-to-end
6. Deploy to production

This document serves as a complete prompt for generating the Security App Flutter code while maintaining consistency with the existing Admin App design system.

---

**Document Version**: 1.0  
**Last Updated**: March 6, 2026  
**Status**: Complete & Ready for Implementation

