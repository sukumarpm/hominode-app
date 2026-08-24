# Flat Management System - Visual Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PARENT COMPONENT                            │
│                  (Building Management Page)                     │
│                                                                 │
│  State: List<FloorOccupancy> _floorData                        │
│                                                                 │
│  Methods:                                                       │
│  - _loadFloorData()                                            │
│  - _handleFlatTap(unit)                                        │
│  - _updateFlatStatus(flatId, newStatus)                        │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                    Opens Grid Modal
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│              FLAT OCCUPANCY GRID MODAL                          │
│                                                                 │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                          │
│  │ A101 │ │ A102 │ │ A103 │ │ A104 │  ← Floor 10              │
│  │ 3BHK │ │ 2BHK │ │ 3BHK │ │ 2BHK │                          │
│  │ Grey │ │Green │ │Yellow│ │ Grey │                          │
│  └──────┘ └──────┘ └──────┘ └──────┘                          │
│                                                                 │
│  Features:                                                      │
│  - Grid/List toggle                                            │
│  - Search by flat/resident                                     │
│  - Filter by status                                            │
│  - Color-coded tiles                                           │
│                                                                 │
│  onFlatTap(unit) → Opens Flat Details                         │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                    User clicks flat
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                  FLAT DETAILS MODAL                             │
│                                                                 │
│  Flat A101                                              [X]     │
│  View and manage flat details...                               │
│                                                                 │
│  Floors          Flats per Floor                               │
│  Floor 10        3BHK                                          │
│                                                                 │
│  Area            Status                                        │
│  1500 Sqft       [Vacant/Occupied/Maintenance]                │
│                                                                 │
│  ┌────────────────────────────────────────────────┐           │
│  │ Info Banner (status-specific message)         │           │
│  └────────────────────────────────────────────────┘           │
│                                                                 │
│  ┌────────────────────────────────────────────────┐           │
│  │ [Assign Resident / Update Status / View]      │           │
│  └────────────────────────────────────────────────┘           │
│                                                                 │
│  Button logic:                                                 │
│  - Vacant → "Assign Resident" → AssignResidentModal           │
│  - Maintenance → "Update Status" → MaintenanceModal           │
│  - Occupied → "View Resident Details" → ResidentModal         │
└─────────────────────────────────────────────────────────────────┘
              ↓                           ↓
    If VACANT                    If MAINTENANCE
              ↓                           ↓
┌──────────────────────────┐  ┌──────────────────────────┐
│ ASSIGN RESIDENT MODAL    │  │ MAINTENANCE MODAL        │
│                          │  │                          │
│ ┌──────────────────────┐ │  │ Flat A103          [X]   │
│ │ Select Existing      │ │  │                          │
│ │ Add New              │ │  │ Floors    Flats per Floor│
│ └──────────────────────┘ │  │ Floor 1   2BHK           │
│                          │  │                          │
│ SELECT EXISTING:         │  │ Area      Status         │
│ ┌──────────────────────┐ │  │ 1200 Sqft [Maintenance]  │
│ │ Search...            │ │  │                          │
│ └──────────────────────┘ │  │ ┌──────────────────────┐ │
│                          │  │ │ ⚠ This flat is under │ │
│ ┌──────────────────────┐ │  │ │   maintenance...     │ │
│ │ JD John Doe      ✓   │ │  │ │                      │ │
│ │ ID: RES-001          │ │  │ │ ┌──────────────────┐ │ │
│ │ • Available          │ │  │ │ │ Keep in Maint. ▼ │ │ │
│ └──────────────────────┘ │  │ │ └──────────────────┘ │ │
│                          │  │ └──────────────────────┘ │
│ Ownership Type           │  │                          │
│ ┌──────────────────────┐ │  │ Options:                 │
│ │ Owner            ▼   │ │  │ - Keep in Maintenance    │
│ └──────────────────────┘ │  │ - Mark as Vacant         │
│                          │  │ - Mark as Occupied       │
│ ADD NEW:                 │  └──────────────────────────┘
│ - Name*                  │              ↓
│ - Phone*                 │    onStatusChange(newStatus)
│ - Family Members         │              ↓
│ - Email                  │    Updates flat status
│ - Ownership Type         │              ↓
│ - Auto-generated ID      │    Grid refreshes
│                          │
│ [Assign Resident]        │
└──────────────────────────┘
              ↓
    onAssign(request)
              ↓
    onStatusChange(Occupied)
              ↓
    Updates flat status
              ↓
    Grid refreshes
```

## Status Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    STATUS TRANSITIONS                       │
└─────────────────────────────────────────────────────────────┘

    VACANT (Grey)
         │
         │ Assign Resident
         │ via AssignResidentModal
         ↓
    OCCUPIED (Green)
         ↑
         │
         │ Mark as Occupied
         │ via MaintenanceModal
         │
    MAINTENANCE (Yellow)
         │
         │ Mark as Vacant
         │ via MaintenanceModal
         ↓
    VACANT (Grey)
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      DATA FLOW                              │
└─────────────────────────────────────────────────────────────┘

1. Parent Component
   └─> List<FloorOccupancy> _floorData
       └─> Contains all flat data

2. User Action
   └─> Clicks flat in grid
       └─> onFlatTap(unit) called

3. Modal Opens
   └─> FlatDetailsModal.show()
       └─> Displays flat information

4. User Takes Action
   └─> Assigns resident OR changes status
       └─> onStatusChange(newStatus) callback

5. Parent Updates
   └─> _updateFlatStatus(flatId, newStatus)
       └─> setState() called
           └─> flat.updateStatus(newStatus)

6. UI Refreshes
   └─> Grid rebuilds automatically
       └─> Tile color updates
           └─> Status reflects change
```

## Callback Chain

```
┌─────────────────────────────────────────────────────────────┐
│                    CALLBACK CHAIN                           │
└─────────────────────────────────────────────────────────────┘

FlatOccupancyGridModal
    │
    └─> onFlatTap: (unit) {
            FlatDetailsModal.show(
                unit: unit,
                onStatusChange: (newStatus) {
                    _updateFlatStatus(unit.id, newStatus)
                }
            )
        }

FlatDetailsModal
    │
    ├─> If Vacant:
    │   └─> AssignResidentModal.show(
    │           onAssign: (request) {
    │               onStatusChange(FlatStatus.occupied)
    │           }
    │       )
    │
    └─> If Maintenance:
        └─> FlatMaintenanceModal.show(
                onStatusChange: (newStatus) {
                    onStatusChange(newStatus)
                }
            )
```

## Color Coding System

```
┌─────────────────────────────────────────────────────────────┐
│                    COLOR SYSTEM                             │
└─────────────────────────────────────────────────────────────┘

Status: VACANT
Color:  Grey (#D1D5DB)
Tile:   ┌──────┐
        │ A101 │
        │ 3BHK │
        │Vacant│
        └──────┘

Status: OCCUPIED
Color:  Green (#10B981)
Tile:   ┌──────┐
        │ A102 │
        │ 2BHK │
        │J.Doe │
        └──────┘

Status: MAINTENANCE
Color:  Yellow (#FBBF24)
Tile:   ┌──────┐
        │ A103 │
        │ 3BHK │
        │Maint.│
        └──────┘
```

## Complete User Journey

```
┌─────────────────────────────────────────────────────────────┐
│              COMPLETE USER JOURNEY                          │
└─────────────────────────────────────────────────────────────┘

START: User wants to assign resident to vacant flat

1. Open Building Management Page
   └─> Click "View Flat Occupancy Grid"

2. Flat Occupancy Grid Opens
   └─> Shows all flats with colors
   └─> User sees A101 is vacant (grey)

3. Click Flat A101
   └─> Flat Details Modal opens
   └─> Shows "Vacant" status
   └─> Button says "Assign Resident"

4. Click "Assign Resident"
   └─> Assign Resident Modal opens
   └─> Two tabs: Select Existing / Add New

5. User selects "Add New" tab
   └─> Form appears with fields
   └─> Credentials auto-generated
   └─> User fills: Name, Phone, Email

6. Click "Assign Resident" button
   └─> Form validates
   └─> API call simulated
   └─> Success!

7. Status Updates
   └─> onStatusChange(FlatStatus.occupied) called
   └─> Parent updates flat.status = occupied
   └─> setState() triggers rebuild

8. UI Refreshes
   └─> Both modals close
   └─> Grid refreshes automatically
   └─> Tile A101 turns green
   └─> Resident name appears

END: Flat A101 is now occupied with resident assigned!
```

## Summary

The flat management system provides a complete, integrated solution for:

✅ Viewing all flats in a color-coded grid
✅ Searching and filtering flats
✅ Assigning residents to vacant flats
✅ Managing maintenance status
✅ Real-time status updates
✅ Smooth animations and transitions
✅ Professional UI/UX
✅ Error handling
✅ API integration ready

All components work together seamlessly with proper state management and callback chains!
