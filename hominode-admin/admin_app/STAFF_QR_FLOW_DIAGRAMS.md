# Staff QR Entry Management - Flow Diagrams

## 1. ADMIN APP: Add Staff with QR Code

```
┌─────────────────────────────────────────────────────────────┐
│ Staff Management Screen                                     │
│                                                             │
│  [Add Staff Button]                                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ AddStaffWithQRModal                                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Form Fields:                                        │   │
│  │ • Staff Name (required)                             │   │
│  │ • Phone Number (required)                           │   │
│  │ • Role (required)                                   │   │
│  │ • Assigned Gate (dropdown)                          │   │
│  │ • Shift Timing (dropdown)                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [Add Staff & Generate QR Button]                          │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ StaffQRService.createStaffWithQRCode()                      │
│                                                             │
│  1. Generate unique staffId                                │
│  2. Create staff document in Firestore                     │
│  3. Generate QR code from staffId                          │
│  4. Save QR reference to Firestore                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Firestore: staff collection                                │
│                                                             │
│  {                                                          │
│    staffId: "unique_id",                                   │
│    name: "John Doe",                                       │
│    phone: "+91 98765 43210",                               │
│    role: "Security Guard",                                 │
│    buildingId: "building_123",                             │
│    gateName: "Gate A",                                     │
│    shiftTiming: "Morning (6 AM - 2 PM)",                   │
│    qrCodeUrl: "url_to_qr_image",                           │
│    status: "active",                                       │
│    createdAt: timestamp                                    │
│  }                                                          │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Success Message                                             │
│ "Staff member added successfully with QR code"             │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. ADMIN APP: View Staff Profile with QR

```
┌─────────────────────────────────────────────────────────────┐
│ Staff Management Screen                                     │
│                                                             │
│  [Staff Card - John Doe]                                   │
└────────────────┬────────────────────────────────────────────┘
                 │ (Click)
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ StaffProfileQRScreen                                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Staff Photo]                                       │   │
│  │                                                     │   │
│  │ John Doe                                            │   │
│  │ Security Guard                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Details:                                            │   │
│  │ Role: Security Guard                                │   │
│  │ Phone: +91 98765 43210                              │   │
│  │ Building: Building A                                │   │
│  │ Gate: Gate A                                        │   │
│  │ Shift: Morning (6 AM - 2 PM)                        │   │
│  │ Status: Active                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Staff QR Code                                       │   │
│  │                                                     │   │
│  │        ┌─────────────┐                              │   │
│  │        │ ▓▓▓▓▓▓▓▓▓▓▓ │                              │   │
│  │        │ ▓▓▓▓▓▓▓▓▓▓▓ │                              │   │
│  │        │ ▓▓ ▓▓▓ ▓▓▓▓ │                              │   │
│  │        │ ▓▓▓▓▓▓▓▓▓▓▓ │                              │   │
│  │        │ ▓▓▓▓▓▓▓▓▓▓▓ │                              │   │
│  │        └─────────────┘                              │   │
│  │                                                     │   │
│  │ ID: staff_123                                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [Share QR]  [Download ID]                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. SECURITY APP: QR Scanning & Entry/Exit

```
┌─────────────────────────────────────────────────────────────┐
│ Security Dashboard                                          │
│                                                             │
│  [Scan Staff QR Button]                                    │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ SecurityStaffQRScanner                                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Camera Feed]                                       │   │
│  │                                                     │   │
│  │        ┌──────────────────┐                         │   │
│  │        │                  │                         │   │
│  │        │  ◄─ Point QR ─►  │                         │   │
│  │        │                  │                         │   │
│  │        └──────────────────┘                         │   │
│  │                                                     │   │
│  │ "Point camera at Staff QR Code"                     │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────────┘
                 │ (QR Detected)
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ StaffQRService.getStaffDetails(staffId)                     │
│                                                             │
│  Fetch from Firestore: staff collection                    │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ StaffDetailsModal (Bottom Sheet)                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Staff Photo]                                       │   │
│  │                                                     │   │
│  │ John Doe                                            │   │
│  │ Security Guard                                      │   │
│  │                                                     │   │
│  │ Phone: +91 98765 43210                              │   │
│  │ Building: Building A                                │   │
│  │ Gate: Gate A                                        │   │
│  │ Shift: Morning (6 AM - 2 PM)                        │   │
│  │ Status: Outside                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [Mark Entry]  [Mark Exit]                                 │
└────────────────┬────────────────┬───────────────────────────┘
                 │                │
        ┌────────┘                └────────┐
        │                                  │
        ▼                                  ▼
┌──────────────────────┐      ┌──────────────────────┐
│ Mark Entry Clicked   │      │ Mark Exit Clicked    │
└──────────┬───────────┘      └──────────┬───────────┘
           │                             │
           ▼                             ▼
┌──────────────────────┐      ┌──────────────────────┐
│ markStaffEntry()     │      │ markStaffExit()      │
│                      │      │                      │
│ 1. Create record in  │      │ 1. Find today's      │
│    staffAttendance   │      │    attendance record │
│ 2. Set status:       │      │ 2. Update exitTime   │
│    "inside"          │      │ 3. Set status:       │
│ 3. Update staff      │      │    "exited"          │
│    lastCheckIn       │      │ 4. Update staff      │
│                      │      │    lastCheckOut      │
└──────────┬───────────┘      └──────────┬───────────┘
           │                             │
           ▼                             ▼
┌──────────────────────┐      ┌──────────────────────┐
│ Firestore Update     │      │ Firestore Update     │
│                      │      │                      │
│ staffAttendance:     │      │ staffAttendance:     │
│ {                    │      │ {                    │
│   staffId: "...",    │      │   staffId: "...",    │
│   entryTime: now,    │      │   exitTime: now,     │
│   status: "inside"   │      │   status: "exited"   │
│ }                    │      │ }                    │
│                      │      │                      │
│ staff:               │      │ staff:               │
│ {                    │      │ {                    │
│   status: "inside"   │      │   status: "outside"  │
│ }                    │      │ }                    │
└──────────┬───────────┘      └──────────┬───────────┘
           │                             │
           ▼                             ▼
┌──────────────────────┐      ┌──────────────────────┐
│ Success Message      │      │ Success Message      │
│ "Entry marked"       │      │ "Exit marked"        │
└──────────┬───────────┘      └──────────┬───────────┘
           │                             │
           └────────────┬────────────────┘
                        │
                        ▼
            ┌──────────────────────┐
            │ Modal Closes         │
            │ Scanner Ready        │
            └──────────────────────┘
```

---

## 4. ATTENDANCE TRACKING FLOW

```
┌─────────────────────────────────────────────────────────────┐
│ Staff Management Screen                                     │
│                                                             │
│  [Staff Card - John Doe]                                   │
│  [View Attendance]                                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ StaffAttendanceDetailsScreen                                │
│                                                             │
│  StaffQRService.getStaffAttendance(staffId)                 │
│  Fetch last 30 records from staffAttendance collection      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Attendance Records List                                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 15 Mar 2024                              [EXITED]   │   │
│  │ Entry: 15 Mar 2024, 06:00 AM                        │   │
│  │ Exit:  15 Mar 2024, 02:00 PM                        │   │
│  │ Duration: 8 h 0 m                                   │   │
│  │ Gate: Gate A | Building: Building A                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 14 Mar 2024                              [EXITED]   │   │
│  │ Entry: 14 Mar 2024, 06:15 AM                        │   │
│  │ Exit:  14 Mar 2024, 02:30 PM                        │   │
│  │ Duration: 8 h 15 m                                  │   │
│  │ Gate: Gate A | Building: Building A                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 13 Mar 2024                              [INSIDE]   │   │
│  │ Entry: 13 Mar 2024, 06:00 AM                        │   │
│  │ Exit:  -                                            │   │
│  │ Duration: -                                         │   │
│  │ Gate: Gate A | Building: Building A                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [Scroll for more records...]                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. DATA FLOW DIAGRAM

```
┌──────────────────────────────────────────────────────────────────┐
│                         ADMIN APP                                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Add Staff with QR                                          │ │
│  │ • Name, Phone, Role, Gate, Shift                           │ │
│  └────────────────┬─────────────────────────────────────────┘ │
│                   │                                            │
│                   ▼                                            │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ StaffQRService                                             │ │
│  │ • Generate staffId                                         │ │
│  │ • Generate QR code                                         │ │
│  │ • Create Firestore document                                │ │
│  └────────────────┬─────────────────────────────────────────┘ │
│                   │                                            │
└───────────────────┼────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────────┐
        │   FIRESTORE DATABASE      │
        │                           │
        │  ┌─────────────────────┐  │
        │  │ staff collection    │  │
        │  │ • staffId           │  │
        │  │ • name              │  │
        │  │ • phone             │  │
        │  │ • role              │  │
        │  │ • buildingId        │  │
        │  │ • gateName          │  │
        │  │ • shiftTiming       │  │
        │  │ • qrCodeUrl         │  │
        │  │ • status            │  │
        │  │ • lastCheckIn       │  │
        │  │ • lastCheckOut      │  │
        │  └─────────────────────┘  │
        │                           │
        │  ┌─────────────────────┐  │
        │  │ staffAttendance     │  │
        │  │ • staffId           │  │
        │  │ • staffName         │  │
        │  │ • buildingId        │  │
        │  │ • gateName          │  │
        │  │ • entryTime         │  │
        │  │ • exitTime          │  │
        │  │ • status            │  │
        │  └─────────────────────┘  │
        └───────────────────────────┘
                    ▲
                    │
┌───────────────────┼────────────────────────────────────────────┐
│                   │                                            │
│  ┌────────────────┴─────────────────────────────────────────┐ │
│  │ Scan QR Code                                             │ │
│  │ • Get staffId from QR                                    │ │
│  │ • Fetch staff details                                    │ │
│  │ • Show staff info modal                                  │ │
│  └────────────────┬─────────────────────────────────────────┘ │
│                   │                                            │
│  ┌────────────────┴─────────────────────────────────────────┐ │
│  │ Mark Entry/Exit                                          │ │
│  │ • Create/Update attendance record                        │ │
│  │ • Update staff status                                    │ │
│  │ • Record timestamps                                      │ │
│  └────────────────┬─────────────────────────────────────────┘ │
│                   │                                            │
│  ┌────────────────┴─────────────────────────────────────────┐ │
│  │ View Attendance                                          │ │
│  │ • Fetch attendance records                               │ │
│  │ • Calculate duration                                     │ │
│  │ • Display history                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                                │
│                      SECURITY APP                              │
└──────────────────────────────────────────────────────────────────┘
```

---

## 6. STATE TRANSITIONS

```
Staff Status Transitions:

    ┌─────────────┐
    │   ACTIVE    │ (Initial state when created)
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │   INSIDE    │ (After Mark Entry)
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │   OUTSIDE   │ (After Mark Exit)
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │   INSIDE    │ (Can mark entry again)
    └─────────────┘


Attendance Record Status:

    ┌─────────────┐
    │   INSIDE    │ (Entry marked, no exit yet)
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │   EXITED    │ (Exit marked, record complete)
    └─────────────┘
```

---

## 7. INTEGRATION POINTS

```
┌─────────────────────────────────────────────────────────────┐
│ Existing Admin App                                          │
│                                                             │
│ • Staff Management Screen                                  │
│   └─► Add Staff Button → AddStaffWithQRModal               │
│   └─► Staff Card → StaffProfileQRScreen                    │
│   └─► View Attendance → StaffAttendanceDetailsScreen       │
│                                                             │
│ • Staff Details Screen                                     │
│   └─► Show QR Code                                         │
│   └─► Share QR                                             │
│   └─► Download ID Card                                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Existing Security App                                       │
│                                                             │
│ • Security Dashboard                                       │
│   └─► Scan Staff QR Button → SecurityStaffQRScanner        │
│                                                             │
│ • QR Scanner                                               │
│   └─► Detect QR → Show Staff Details                       │
│   └─► Mark Entry/Exit → Update Firestore                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. SEQUENCE DIAGRAM: Complete Flow

```
Admin          AddStaffModal    StaffQRService    Firestore    Security
  │                 │                  │              │            │
  │─ Add Staff ────►│                  │              │            │
  │                 │─ Validate ──────►│              │            │
  │                 │                  │              │            │
  │                 │                  │─ Generate ──►│            │
  │                 │                  │  staffId     │            │
  │                 │                  │              │            │
  │                 │                  │─ Create ────►│            │
  │                 │                  │  document    │            │
  │                 │                  │              │            │
  │                 │◄─ Success ───────│              │            │
  │◄─ Success ──────│                  │              │            │
  │                 │                  │              │            │
  │─ View Profile ─────────────────────────────────────────────────►│
  │                 │                  │              │            │
  │                 │                  │              │◄─ Fetch ───│
  │                 │                  │              │  staff     │
  │                 │                  │              │            │
  │                 │                  │              │─ Return ──►│
  │                 │                  │              │  data      │
  │                 │                  │              │            │
  │◄─ Show QR ──────────────────────────────────────────────────────│
  │                 │                  │              │            │
  │─ Scan QR ──────────────────────────────────────────────────────►│
  │                 │                  │              │            │
  │                 │                  │              │◄─ Fetch ───│
  │                 │                  │              │  staff     │
  │                 │                  │              │            │
  │                 │                  │              │─ Return ──►│
  │                 │                  │              │  data      │
  │                 │                  │              │            │
  │                 │                  │              │            │
  │                 │                  │              │◄─ Mark ────│
  │                 │                  │              │  Entry     │
  │                 │                  │              │            │
  │                 │                  │              │─ Create ──►│
  │                 │                  │              │  attendance│
  │                 │                  │              │            │
  │◄─ Attendance ───────────────────────────────────────────────────│
```

---

## Notes

- All timestamps use Firestore server time for consistency
- QR codes are generated from staffId for uniqueness
- Attendance records are immutable once created
- Status field tracks current location (inside/outside)
- Duration is calculated from entry and exit times
- All operations are real-time with Firestore listeners
