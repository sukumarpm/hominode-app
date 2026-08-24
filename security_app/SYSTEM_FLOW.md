# LYVO Security System Flow

## Complete Visitor Management Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    LYVO VISITOR MANAGEMENT                       │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  RESIDENT    │      │    ADMIN     │      │   SECURITY   │
│     APP      │      │     APP      │      │     APP      │
└──────────────┘      └──────────────┘      └──────────────┘
       │                     │                     │
       │                     │                     │
       ▼                     │                     │
  [1] Create                 │                     │
   Visitor                   │                     │
   Request                   │                     │
       │                     │                     │
       ├─────────────────────┼─────────────────────┤
       │    Firestore        │                     │
       │    visitors         │                     │
       │    status:          │                     │
       │    "pending"        │                     │
       └─────────────────────┼─────────────────────┤
                             │                     │
                             ▼                     │
                        [2] Review                 │
                         Visitor                   │
                         Request                   │
                             │                     │
                             ▼                     │
                        [3] Approve                │
                         (Update                   │
                         status:                   │
                         "expected")               │
                             │                     │
       ┌─────────────────────┼─────────────────────┤
       │    Firestore        │                     │
       │    visitors         │                     │
       │    status:          │                     │
       │    "expected"       │                     │
       ├─────────────────────┼─────────────────────┤
       │                     │                     │
       ▼                     │                     │
  [4] Generate               │                     │
   QR Code                   │                     │
   (Document ID)             │                     │
       │                     │                     │
       ▼                     │                     │
  [5] Share QR               │                     │
   with Visitor              │                     │
   (SMS/WhatsApp)            │                     │
       │                     │                     │
       │                     │                     │
       │                     │         ┌───────────┤
       │                     │         │ Visitor   │
       │                     │         │ arrives   │
       │                     │         │ at gate   │
       │                     │         └───────────┤
       │                     │                     │
       │                     │                     ▼
       │                     │                [6] Scan
       │                     │                 QR Code
       │                     │                     │
       ├─────────────────────┼─────────────────────┤
       │    Firestore        │                     │
       │    Query by         │                     │
       │    Document ID      │                     │
       ├─────────────────────┼─────────────────────┤
       │                     │                     │
       │                     │                     ▼
       │                     │                [7] View
       │                     │                 Visitor
       │                     │                 Details
       │                     │                     │
       │                     │                     ▼
       │                     │                [8] Mark
       │                     │                 Entry
       │                     │                     │
       ├─────────────────────┼─────────────────────┤
       │    Firestore        │                     │
       │    Update:          │                     │
       │    status:          │                     │
       │    "inside"         │                     │
       │    actualArrival    │                     │
       ├─────────────────────┼─────────────────────┤
       │                     │                     │
       │                     │         ┌───────────┤
       │                     │         │ Visitor   │
       │                     │         │ leaves    │
       │                     │         └───────────┤
       │                     │                     │
       │                     │                     ▼
       │                     │                [9] Scan
       │                     │                 QR Code
       │                     │                 Again
       │                     │                     │
       │                     │                     ▼
       │                     │               [10] Mark
       │                     │                 Exit
       │                     │                     │
       ├─────────────────────┼─────────────────────┤
       │    Firestore        │                     │
       │    Update:          │                     │
       │    status:          │                     │
       │    "completed"      │                     │
       │    departure        │                     │
       └─────────────────────┴─────────────────────┘
```

## Status Flow

```
┌─────────┐     ┌──────────┐     ┌────────┐     ┌───────────┐
│ pending │ ──> │ expected │ ──> │ inside │ ──> │ completed │
└─────────┘     └──────────┘     └────────┘     └───────────┘
    │               │                │                │
    │               │                │                │
 Created        Approved         Entered          Exited
 by Resident    by Admin      by Security      by Security
```

## QR Code Content

```
┌─────────────────────────────────┐
│         QR CODE CONTENT         │
├─────────────────────────────────┤
│                                 │
│   0Au23BbeJsNqpO6GePJ22        │
│                                 │
│   (Firestore Document ID)       │
│                                 │
└─────────────────────────────────┘
```

## Firestore Document Structure

```javascript
visitors/{documentId}
{
  // Visitor Information
  visitorName: "Amit Sharma",
  phoneNumber: "+91 98765 43210",
  purpose: "Guest Visit",
  
  // Flat Information
  flatId: "flat_a301",
  flatLabel: "A-301",
  
  // Host Information
  hostName: "Rajesh Kumar",
  hostEmail: "rajesh@example.com",
  hostUserId: "user_123",
  
  // Additional Details
  vehicleNumber: "MH 01 AB 1234",
  
  // Status & Approval
  isApproved: true,
  status: "expected", // pending | expected | inside | completed
  
  // Timestamps
  expectedArrival: Timestamp,
  actualArrival: Timestamp | null,
  departure: Timestamp | null,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

## Security App Screens

```
┌─────────────────────────────────────────────────────────┐
│                    SECURITY APP                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   HOME      │  │  VISITORS   │  │    SCAN     │   │
│  │             │  │             │  │             │   │
│  │ Dashboard   │  │ Pending     │  │ QR Scanner  │   │
│  │ Statistics  │  │ Active      │  │ Camera      │   │
│  │ Quick       │  │ History     │  │ Flashlight  │   │
│  │ Actions     │  │             │  │             │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐                     │
│  │   STAFF     │  │  PROFILE    │                     │
│  │             │  │             │                     │
│  │ Staff List  │  │ Settings    │                     │
│  │ Attendance  │  │ Test Data   │                     │
│  │             │  │ Generator   │                     │
│  └─────────────┘  └─────────────┘                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Testing Flow (Current Implementation)

```
┌─────────────────────────────────────────────────────────┐
│                  TESTING WORKFLOW                       │
└─────────────────────────────────────────────────────────┘

1. Open Security App
   │
   ▼
2. Tap "Profile" Tab
   │
   ▼
3. Tap "Create Test Visitor"
   │
   ├─────────────────────────────────────┐
   │    Firestore creates document       │
   │    Returns Document ID              │
   └─────────────────────────────────────┘
   │
   ▼
4. Copy Document ID
   │
   ▼
5. Go to QR Code Generator Website
   │
   ▼
6. Paste Document ID
   │
   ▼
7. Generate & Download QR Code
   │
   ▼
8. Open Security App
   │
   ▼
9. Tap "Scan" Tab
   │
   ▼
10. Point Camera at QR Code
    │
    ├─────────────────────────────────────┐
    │    Scanner detects QR               │
    │    Extracts Document ID             │
    │    Queries Firestore                │
    │    Fetches visitor data             │
    └─────────────────────────────────────┘
    │
    ▼
11. View Visitor Details
    │
    ▼
12. Tap "Mark Entry"
    │
    ├─────────────────────────────────────┐
    │    Updates Firestore:               │
    │    status = "inside"                │
    │    actualArrival = now              │
    └─────────────────────────────────────┘
    │
    ▼
13. Scan Again (when visitor leaves)
    │
    ▼
14. Tap "Mark Exit"
    │
    ├─────────────────────────────────────┐
    │    Updates Firestore:               │
    │    status = "completed"             │
    │    departure = now                  │
    └─────────────────────────────────────┘
```

## Data Flow Diagram

```
┌──────────────┐
│   Resident   │
│     App      │
└──────┬───────┘
       │
       │ Creates visitor
       │ (status: pending)
       ▼
┌──────────────────────┐
│                      │
│   Firestore DB       │
│   Collection:        │
│   "visitors"         │
│                      │
└──────┬───────────────┘
       │
       │ Admin approves
       │ (status: expected)
       ▼
┌──────────────────────┐
│                      │
│   Firestore DB       │
│   (updated)          │
│                      │
└──────┬───────────────┘
       │
       │ Resident generates QR
       │ (contains doc ID)
       ▼
┌──────────────┐
│   Visitor    │
│  (has QR)    │
└──────┬───────┘
       │
       │ Shows QR at gate
       ▼
┌──────────────┐
│   Security   │
│     App      │
└──────┬───────┘
       │
       │ Scans QR
       │ Fetches from Firestore
       ▼
┌──────────────────────┐
│                      │
│   Visitor Details    │
│   Screen             │
│                      │
└──────┬───────────────┘
       │
       │ Mark Entry/Exit
       │ Updates Firestore
       ▼
┌──────────────────────┐
│                      │
│   Firestore DB       │
│   (status updated)   │
│                      │
└──────────────────────┘
```

## Key Points

1. **QR Code**: Contains ONLY the Firestore document ID
2. **Status Flow**: pending → expected → inside → completed
3. **Security Actions**: Mark Entry (expected→inside), Mark Exit (inside→completed)
4. **Real-time**: All apps can listen to Firestore changes
5. **Testing**: Use Test Data Generator in Profile tab
