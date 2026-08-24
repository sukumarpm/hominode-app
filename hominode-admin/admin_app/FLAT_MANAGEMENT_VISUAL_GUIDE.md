# Flat Management - Visual Guide

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLAT MANAGEMENT SYSTEM                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │      Building Management Screen         │
        │                                         │
        │  ┌──────────────────────────────────┐  │
        │  │  Tower A                    ⚙️📝🗑️│  │
        │  │  10 Floors • 4 Flats/Floor       │  │
        │  │  Total: 40  Occupied: 25  Vacant:15│  │
        │  │  Occupancy: 62% ████████░░░      │  │
        │  └──────────────────────────────────┘  │
        └─────────────────────────────────────────┘
                              │
                              │ Click Grid Icon (⚙️)
                              ▼
        ┌─────────────────────────────────────────┐
        │    Flat Occupancy Grid Modal            │
        │                                         │
        │  [Grid View] [List View]  🔍 Search    │
        │  Filter: [All ▼]                       │
        │                                         │
        │  Legend: 🟦 Occupied  ⚪ Vacant  🟧 Maint│
        │                                         │
        │  Floor 10                              │
        │  ┌────┐ ┌────┐ ┌────┐ ┌────┐         │
        │  │A1001│ │A1002│ │A1003│ │A1004│         │
        │  │John │ │     │ │Mary │ │     │         │
        │  │🟦   │ │⚪   │ │🟦   │ │⚪   │         │
        │  └────┘ └────┘ └────┘ └────┘         │
        │                                         │
        │  Floor 9                               │
        │  ┌────┐ ┌────┐ ┌────┐ ┌────┐         │
        │  │A901 │ │A902 │ │A903 │ │A904 │         │
        │  │     │ │Bob  │ │     │ │🔧   │         │
        │  │⚪   │ │🟦   │ │⚪   │ │🟧   │         │
        │  └────┘ └────┘ └────┘ └────┘         │
        └─────────────────────────────────────────┘
```

## Flat Status Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    FLAT STATUS LIFECYCLE                      │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────┐
    │   VACANT    │  ⚪ Grey
    │  (Initial)  │
    └──────┬──────┘
           │
           │ Assign Resident
           ▼
    ┌─────────────┐
    │  OCCUPIED   │  🟦 Blue
    │ (Resident)  │
    └──────┬──────┘
           │
           ├─────────────────┐
           │                 │
           │ Remove          │ Mark as
           │ Resident        │ Maintenance
           │                 │
           ▼                 ▼
    ┌─────────────┐   ┌─────────────┐
    │   VACANT    │   │ MAINTENANCE │  🟧 Orange
    │             │   │             │
    └─────────────┘   └──────┬──────┘
           ▲                 │
           │                 │
           └─────────────────┘
              Mark as Vacant
```

## Assign Resident Flow

```
┌──────────────────────────────────────────────────────────────┐
│              ASSIGN RESIDENT TO FLAT FLOW                     │
└──────────────────────────────────────────────────────────────┘

User clicks vacant flat (⚪)
         │
         ▼
┌─────────────────────┐
│ Flat Details Modal  │
│                     │
│ Flat: A101          │
│ Floor: 1            │
│ Type: 3BHK          │
│ Area: 1500 Sqft     │
│ Status: Vacant      │
│                     │
│ [Assign Resident]   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│         Assign Resident Modal                                │
│                                                              │
│  [Select Existing] [Add New]                                │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ SELECT EXISTING TAB                                  │   │
│  │                                                       │   │
│  │ 🔍 Search residents...                               │   │
│  │                                                       │   │
│  │ ┌─────────────────────────────────────────────────┐ │   │
│  │ │ ☑️ John Doe (RES1234) - Available              │ │   │
│  │ │ ☐ Jane Smith (RES5678) - Assigned to B202      │ │   │
│  │ │ ☑️ Bob Wilson (RES9012) - Available            │ │   │
│  │ └─────────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │ Ownership Type: [Owner ▼]                            │   │
│  │                                                       │   │
│  │ [Assign Resident]                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ADD NEW TAB                                          │   │
│  │                                                       │   │
│  │ Name*: [________________]                            │   │
│  │ Phone*: [________________]                           │   │
│  │ Email: [________________]                            │   │
│  │ Family Members: [4]                                  │   │
│  │                                                       │   │
│  │ Auto-Generated Credentials:                          │   │
│  │ ┌─────────────────────────────────────────────────┐ │   │
│  │ │ Resident ID: RES1234                            │ │   │
│  │ │ Password: abc123XY                              │ │   │
│  │ │ Auth Email: RES1234@lyvo.com                    │ │   │
│  │ └─────────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  │ Ownership Type: [Owner ▼]                            │   │
│  │                                                       │   │
│  │ [Assign Resident]                                    │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA UPDATES                              │
│                                                              │
│  1. Update users collection:                                │
│     users/{userId}                                          │
│     ├── flatId: "A101"                                      │
│     ├── flatLabel: "A101"                                   │
│     └── ownershipType: "Owner"                              │
│                                                              │
│  2. Update flats collection:                                │
│     flats/A101                                              │
│     ├── status: "occupied"                                  │
│     ├── residentName: "John Doe"                            │
│     └── residentId: "user_doc_id"                           │
│                                                              │
│  3. Update buildings collection:                            │
│     buildings/{buildingId}                                  │
│     ├── occupied: +1                                        │
│     ├── vacant: -1                                          │
│     └── occupancyRate: recalculated                         │
└─────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│              SUCCESS NOTIFICATION                            │
│                                                              │
│  ✅ John Doe assigned to A101 successfully                  │
│                                                              │
│  Flat A101 turns blue (🟦) in grid                          │
│  Grid updates in real-time                                  │
└─────────────────────────────────────────────────────────────┘
```

## Remove Resident Flow

```
┌──────────────────────────────────────────────────────────────┐
│              REMOVE RESIDENT FROM FLAT FLOW                   │
└──────────────────────────────────────────────────────────────┘

User clicks occupied flat (🟦)
         │
         ▼
┌─────────────────────┐
│ Flat Occupied Modal │
│                     │
│ Flat: A101          │
│ Resident: John Doe  │
│ Floor: 1            │
│ Type: 3BHK          │
│ Area: 1500 Sqft     │
│ Status: Occupied    │
│                     │
│ [Remove]            │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Confirmation Dialog │
│                     │
│ Remove John Doe     │
│ from flat A101?     │
│                     │
│ This action will    │
│ mark the flat as    │
│ vacant.             │
│                     │
│ [Cancel] [Confirm]  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA UPDATES                              │
│                                                              │
│  1. Update users collection:                                │
│     users/{userId}                                          │
│     ├── flatId: null                                        │
│     ├── flatLabel: null                                     │
│     └── ownershipType: null                                 │
│                                                              │
│  2. Update flats collection:                                │
│     flats/A101                                              │
│     ├── status: "vacant"                                    │
│     ├── residentName: null                                  │
│     └── residentId: null                                    │
│                                                              │
│  3. Update buildings collection:                            │
│     buildings/{buildingId}                                  │
│     ├── occupied: -1                                        │
│     ├── vacant: +1                                          │
│     └── occupancyRate: recalculated                         │
└─────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│              SUCCESS NOTIFICATION                            │
│                                                              │
│  ✅ John Doe removed from A101 successfully                 │
│                                                              │
│  Flat A101 turns grey (⚪) in grid                           │
│  Grid updates in real-time                                  │
└─────────────────────────────────────────────────────────────┘
```

## Grid View Modes

### Grid View
```
┌─────────────────────────────────────────────────────────────┐
│  Floor 10                                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │  A1001   │ │  A1002   │ │  A1003   │ │  A1004   │      │
│  │          │ │          │ │          │ │          │      │
│  │  John    │ │          │ │  Mary    │ │          │      │
│  │  Doe     │ │  Vacant  │ │  Smith   │ │  Vacant  │      │
│  │          │ │          │ │          │ │          │      │
│  │  3BHK    │ │  2BHK    │ │  3BHK    │ │  2BHK    │      │
│  │  1500 Sqft│ │  1200 Sqft│ │  1500 Sqft│ │  1200 Sqft│      │
│  │          │ │          │ │          │ │          │      │
│  │    🟦    │ │    ⚪    │ │    🟦    │ │    ⚪    │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### List View
```
┌─────────────────────────────────────────────────────────────┐
│  Floor 10                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🟦 A1001 • John Doe • 3BHK • 1500 Sqft • Occupied  │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ⚪ A1002 • Vacant • 2BHK • 1200 Sqft               │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🟦 A1003 • Mary Smith • 3BHK • 1500 Sqft • Occupied│   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ⚪ A1004 • Vacant • 2BHK • 1200 Sqft               │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Search and Filter

```
┌─────────────────────────────────────────────────────────────┐
│  🔍 Search: "John"                                          │
│  Filter: [Occupied ▼]                                       │
│                                                              │
│  Results: 1 flat found                                      │
│                                                              │
│  Floor 10                                                    │
│  ┌──────────┐                                               │
│  │  A1001   │                                               │
│  │  John    │                                               │
│  │  Doe     │                                               │
│  │  3BHK    │                                               │
│  │    🟦    │                                               │
│  └──────────┘                                               │
└─────────────────────────────────────────────────────────────┘
```

## Color Legend

```
┌─────────────────────────────────────────────────────────────┐
│                      STATUS COLORS                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  🟦 OCCUPIED (#2563EB - Blue)                               │
│     Resident is assigned to this flat                       │
│     Shows resident name                                     │
│     Can remove resident or change status                    │
│                                                              │
│  ⚪ VACANT (#E5E7EB - Grey)                                 │
│     No resident assigned                                    │
│     Available for assignment                                │
│     Can assign resident or mark as maintenance              │
│                                                              │
│  🟧 MAINTENANCE (#F97316 - Orange)                          │
│     Flat is under maintenance                               │
│     May or may not have resident                            │
│     Can change status when maintenance complete             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Resident Credentials

```
┌─────────────────────────────────────────────────────────────┐
│              AUTO-GENERATED CREDENTIALS                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  When creating a new resident:                              │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Resident ID:  RES1234                              │    │
│  │               (RES + 4 random digits)              │    │
│  │                                                     │    │
│  │ Password:     abc123XY                             │    │
│  │               (8 random alphanumeric chars)        │    │
│  │                                                     │    │
│  │ Auth Email:   RES1234@lyvo.com                     │    │
│  │               (Resident ID + @lyvo.com)            │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Resident can login with:                                   │
│  • Phone + Password                                         │
│  • Resident ID + Password                                   │
│  • Auth Email + Password                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Building Occupancy Sync

```
┌─────────────────────────────────────────────────────────────┐
│              BUILDING OCCUPANCY SYNCHRONIZATION              │
└─────────────────────────────────────────────────────────────┘

Flat Status Change
         │
         ▼
┌─────────────────────┐
│ Count Flat Statuses │
│                     │
│ Occupied: 25        │
│ Vacant: 15          │
│ Maintenance: 0      │
│ Total: 40           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Calculate Stats     │
│                     │
│ Occupancy Rate:     │
│ (25 / 40) × 100     │
│ = 62%               │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Update Building Doc │
│                     │
│ occupied: 25        │
│ vacant: 15          │
│ occupancyRate: 62   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Building Card       │
│ Updates in UI       │
│                     │
│ Total: 40           │
│ Occupied: 25        │
│ Vacant: 15          │
│ Rate: 62%           │
│ ████████░░░         │
└─────────────────────┘
```

## Real-Time Updates

```
┌─────────────────────────────────────────────────────────────┐
│                  REAL-TIME UPDATE FLOW                       │
└─────────────────────────────────────────────────────────────┘

Device A                    Firestore                  Device B
   │                           │                          │
   │ Assign Resident           │                          │
   │ to Flat A101              │                          │
   │──────────────────────────>│                          │
   │                           │                          │
   │                           │ Update flat document     │
   │                           │ Update user document     │
   │                           │                          │
   │                           │ Stream Update            │
   │                           │─────────────────────────>│
   │                           │                          │
   │ Flat A101 turns blue      │      Flat A101 turns blue│
   │ (Occupied)                │                (Occupied)│
   │                           │                          │
   │ Success notification      │      Grid auto-refreshes │
   │                           │                          │
```

## Flat Naming Convention

```
┌─────────────────────────────────────────────────────────────┐
│              FLAT ID NAMING CONVENTION                       │
└─────────────────────────────────────────────────────────────┘

Building: "Tower A"
First Letter: A

Floor 1, Flat 1  →  A + 1 + 01  →  A101
Floor 1, Flat 2  →  A + 1 + 02  →  A102
Floor 10, Flat 1 →  A + 10 + 01 →  A1001
Floor 10, Flat 4 →  A + 10 + 04 →  A1004

Building: "Block B"
First Letter: B

Floor 5, Flat 3  →  B + 5 + 03  →  B503
Floor 12, Flat 2 →  B + 12 + 02 →  B1202

Format: {BuildingInitial}{Floor}{FlatNumber(padded)}
```

## Complete System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTEM ARCHITECTURE                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                         UI LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  • ManageBuildingsPage                                      │
│  • FlatOccupancyGridModal                                   │
│  • FlatDetailsModal                                         │
│  • FlatOccupiedModal                                        │
│  • AssignResidentModal                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      SERVICE LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  • FlatService (CRUD operations)                            │
│  • UserService (Resident management)                        │
│  • BuildingService (Occupancy sync)                         │
│  • AuthService (Firebase Auth)                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
├─────────────────────────────────────────────────────────────┤
│  Firestore Collections:                                     │
│  • flats (Flat documents)                                   │
│  • users (Resident documents)                               │
│  • buildings (Building documents)                           │
│                                                              │
│  Firebase Authentication:                                   │
│  • Admin accounts                                           │
│  • Resident accounts                                        │
└─────────────────────────────────────────────────────────────┘
```

---

**Visual Guide Complete**: Use this guide for quick visual reference of the Flat Management system!
