# Flat Occupancy Grid - Complete UX & Flow Specification

## Overview
Complete interaction flow for the Flat Occupancy Grid module in the LYVO Admin app, covering all status-based flows, modals, and transitions.

---

## 1️⃣ Entry Point & Container

### Access Point
**From**: Manage Buildings screen
**Action**: Tap grid icon on any building/tower card
**Result**: Opens Flat Occupancy Grid modal

### Modal Container
```
┌─────────────────────────────────────────────────────────┐
│  Tower A – Flat Occupancy Grid                      [X] │
│  Visual representation of all flats. Click on any       │
│  flat to view or edit details.                          │
└─────────────────────────────────────────────────────────┘
```

**Specifications**:
- **Width**: 88-92% of screen width
- **Max Width**: 460px (mobile optimized)
- **Corner Radius**: 18px
- **Background**: Pure white (#FFFFFF)
- **Scrim**: rgba(0, 0, 0, 0.35)
- **Animation**: Fade + Scale (0.96 → 1.0, 220ms, ease-out)
- **Close Button**: 44×44px tap area, top-right

---

## 2️⃣ Main Grid Screen Layout

### Header Controls

#### View Toggle (Segmented Control)
```
┌─────────────────────────────────────┐
│ ┌──────────────┬──────────────────┐ │
│ │  Grid View   │   List View      │ │
│ └──────────────┴──────────────────┘ │
└─────────────────────────────────────┘
```

**Specifications**:
- **Background**: #F3F4F6 (light grey)
- **Active**: White background with shadow
- **Inactive**: Transparent
- **Radius**: 24px container, 20px segments
- **Padding**: 4px all around
- **Height**: 48-50px
- **Animation**: 200ms smooth transition

**Behavior**:
- **Grid View** (default): Shows floor-wise colored tiles
- **List View**: Shows vertical list with same colors

#### Legend / Status Indicators
```
🟩 Occupied    🩶 Vacant    🟨 Maintenance
```

**Colors**:
- **Occupied**: #10B981 (Green)
- **Vacant**: #E5E7EB (Light Grey)
- **Maintenance**: #FBBF24 (Yellow)

**Functionality**:
- Visual reference for status colors
- Optional: Tap to filter by status

#### Search & Filter Row
```
┌──────────────────────────────┬─────────┐
│ 🔍 Search by flat or resident│  All ▼  │
└──────────────────────────────┴─────────┘
```

**Search Field**:
- **Placeholder**: "Search by flat or resident"
- **Icon**: Search icon (left)
- **Clear**: X button when typing
- **Filters**: Flat ID, Resident name
- **Real-time**: Updates as you type

**Filter Dropdown**:
- **Options**: All, Vacant only, Occupied only, Under Maintenance
- **Width**: ~30% of row
- **Updates**: Grid/List immediately

---

## 3️⃣ Grid Content & Status Colors

### Floor Structure
```
┌─────────────────────────────────────┐
│  Floor 10                           │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌────┐ │
│  │ A101 │ │ A102 │ │ A103 │ │A104│ │
│  │ 3BHK │ │ 2BHK │ │ 3BHK │ │2BHK│ │
│  │Vacant│ │J.Doe │ │Maint.│ │... │ │
│  └──────┘ └──────┘ └──────┘ └────┘ │
└─────────────────────────────────────┘
```

### Tile Specifications

**Grid Layout**:
- **Columns**: 4 per row
- **Spacing**: 8px between tiles
- **Aspect Ratio**: 0.85 (slightly taller)
- **Padding**: 8px inside each tile

**Tile Content**:
1. **Flat ID**: 12px, bold, top
2. **Type**: 10px, semibold, middle
3. **Status/Name**: 9px, regular, bottom

**Color Mapping**:
```dart
Vacant:      #E5E7EB (Grey) + Dark text (#6B7280)
Occupied:    #10B981 (Green) + White text
Maintenance: #FBBF24 (Yellow) + White text
```

---

## 4️⃣ Status-Based Flows & Overlays

### A. VACANT FLAT FLOW 🩶

#### Step 1: Tap Vacant Tile (Grey)
```
User taps grey tile → Opens Flat Details Modal
```

#### Step 2: Vacant Flat Details Modal
```
┌─────────────────────────────────────┐
│  Flat A101                      [X] │
│  View and manage flat details...   │
├─────────────────────────────────────┤
│  Floors          Flats per Floor    │
│  Floor 10        3BHK               │
│                                     │
│  Area            Status             │
│  1500 Sqft       [Vacant]           │
├─────────────────────────────────────┤
│  ℹ This flat is currently vacant.  │
│    You can assign a resident or    │
│    change its status.               │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │    Assign Resident            │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Components**:
- **Status Badge**: Grey pill with "Vacant"
- **Info Banner**: Blue background (#EEF4FF)
- **Primary Button**: "Assign Resident" (blue)

#### Step 3: Assign Resident Modal Opens

**Tab 1: Select Existing**
```
┌─────────────────────────────────────┐
│  Assign Resident to A101        [X] │
│  Select an existing resident or...  │
├─────────────────────────────────────┤
│  ┌──────────────┬──────────────────┐│
│  │Select Existing│   Add New       ││
│  └──────────────┴──────────────────┘│
├─────────────────────────────────────┤
│  🔍 Search by name, ID, or flat...  │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │ JD  John Doe          ✓       │ │
│  │     ID: RES-001               │ │
│  │     • Available               │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ JS  Jane Smith                │ │
│  │     ID: RES-002               │ │
│  │     • Assigned to B205        │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│  Ownership Type                     │
│  ┌───────────────────────────────┐ │
│  │ Owner                      ▼  │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │    Assign Resident            │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │         Cancel                │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Features**:
- **Search**: Real-time filtering
- **Card List**: Avatar + Name + ID + Status
- **Selection**: Blue highlight + checkmark
- **Ownership**: Dropdown (Owner/Tenant/Lease)

**Tab 2: Add New**
```
┌─────────────────────────────────────┐
│  Assign Resident to A101        [X] │
│  Select an existing resident or...  │
├─────────────────────────────────────┤
│  ┌──────────────┬──────────────────┐│
│  │Select Existing│   Add New       ││
│  └──────────────┴──────────────────┘│
├─────────────────────────────────────┤
│  Resident Name *                    │
│  ┌───────────────────────────────┐ │
│  │ Enter full name               │ │
│  └───────────────────────────────┘ │
│                                     │
│  Phone Number *    Family Members   │
│  ┌──────────────┐ ┌──────────────┐ │
│  │+91 1234567890│ │      1       │ │
│  └──────────────┘ └──────────────┘ │
│                                     │
│  Email Address                      │
│  ┌───────────────────────────────┐ │
│  │ resident@email.com            │ │
│  └───────────────────────────────┘ │
│                                     │
│  Ownership Type                     │
│  ┌───────────────────────────────┐ │
│  │ Owner                      ▼  │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│  ✨ Login credentials will be       │
│     auto-generated:                 │
│     • Resident ID: RES5326          │
│     • Password: Will be sent via    │
│       SMS/Email                     │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │    Assign Resident            │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │         Cancel                │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Features**:
- **Required Fields**: Name*, Phone*
- **Optional**: Family Members, Email
- **Auto-Generated**: Resident ID + Password
- **Validation**: Real-time form validation
- **Info Card**: Blue background with credentials

#### Step 4: Assignment Success
```
✅ Resident assigned successfully
    ↓
Status: Vacant → Occupied
    ↓
Tile Color: Grey → Green
    ↓
Grid Updates Automatically
```

---

### B. MAINTENANCE FLAT FLOW 🟨

#### Step 1: Tap Maintenance Tile (Yellow)
```
User taps yellow tile → Opens Maintenance Modal
```

#### Step 2: Maintenance Flat Details Modal
```
┌─────────────────────────────────────┐
│  Flat A012                      [X] │
│  View and manage flat details...   │
├─────────────────────────────────────┤
│  Floors          Flats per Floor    │
│  Floor 1         2BHK               │
│                                     │
│  Area            Status             │
│  1200 Sqft       [Maintenance]      │
├─────────────────────────────────────┤
│  ⚠ This flat is under maintenance.  │
│    Change status when ready.        │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Keep in Maintenance        ▼  │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Components**:
- **Status Badge**: Yellow pill with "Maintenance"
- **Warning Box**: Soft yellow background (#FFF9E6)
- **Dropdown**: Status change options

**Dropdown Options**:
1. **Keep in Maintenance** (default)
2. **Mark as Vacant**
3. **Mark as Occupied**

#### Step 3: Status Transitions

**Option A: Mark as Vacant**
```
Select "Mark as Vacant"
    ↓
Status: Maintenance → Vacant
    ↓
Tile Color: Yellow → Grey
    ↓
Next tap opens Vacant flow
```

**Option B: Mark as Occupied**
```
Select "Mark as Occupied"
    ↓
Status: Maintenance → Occupied
    ↓
Tile Color: Yellow → Green
    ↓
Next tap opens Occupied flow
```

---

### C. OCCUPIED FLAT FLOW 🟩

#### Step 1: Tap Occupied Tile (Green)
```
User taps green tile → Opens Flat Details Modal
```

#### Step 2: Flat Details Modal (Initial)
```
┌─────────────────────────────────────┐
│  Flat A102                      [X] │
│  View and manage flat details...   │
├─────────────────────────────────────┤
│  Floors          Flats per Floor    │
│  Floor 10        2BHK               │
│                                     │
│  Area            Status             │
│  1200 Sqft       [Occupied]         │
├─────────────────────────────────────┤
│  ℹ This flat is currently occupied. │
│    View resident details or update  │
│    information.                     │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │      View Details             │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

#### Step 3: Occupied Flat Details Modal
```
┌─────────────────────────────────────┐
│  Flat A012                      [X] │
│  View and manage flat details...   │
├─────────────────────────────────────┤
│  Floors          Flats per Floor    │
│  Floor 1         2BHK               │
│                                     │
│  Area            Status             │
│  1200 Sqft       [Occupied]         │
├─────────────────────────────────────┤
│  Resident Information               │
│                                     │
│  Name :           Resident A011     │
│  ID :             RES5171           │
│  Type ;           [Tenant]          │
├─────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────┐ │
│  │ 🗑 Remove    │  │ Occupied  ▼ │ │
│  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────┘
```

**Components**:
- **Status Badge**: Green pill with "Occupied"
- **Resident Card**: Grey background (#F5F7FA)
- **Remove Button**: Outline with trash icon
- **Status Dropdown**: Change status options

#### Step 4: Action Options

**Option A: Remove Resident**
```
Click "Remove" button
    ↓
Confirmation Dialog:
"Remove this resident from flat A012?
This will mark the flat as Vacant."
    ↓
[Cancel] [Remove]
    ↓
If confirmed:
    ↓
Status: Occupied → Vacant
    ↓
Tile Color: Green → Grey
    ↓
Success message shown
```

**Option B: Change Status via Dropdown**
```
Open dropdown
    ↓
Options:
- Occupied (current)
- Vacant
- Maintenance
    ↓
Select new status
    ↓
Status updates immediately
    ↓
Tile color changes
    ↓
Modal closes
```

---

## 5️⃣ List View Behavior

### Layout
```
┌─────────────────────────────────────┐
│  Floor 10                           │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │ A101  3BHK • Vacant        → │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ A102  2BHK • Occupied      → │ │
│  │       John Doe                │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ A103  3BHK • Maintenance   → │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Features**:
- **Same Colors**: Green/Grey/Yellow backgrounds
- **Flat Info**: ID + Type + Status
- **Resident**: Name shown if occupied
- **Tap Action**: Opens same modals as Grid View
- **Search/Filter**: Works identically

---

## 6️⃣ Global Interaction Rules

### Modal Behavior
- **Centered**: Always centered on screen
- **Rounded**: 18px corner radius
- **Shadow**: Soft elevation
- **Scrollable**: If content > 80% screen height
- **Animation**: Fade + Scale on open/close
- **Dismissible**: Tap scrim or X to close

### Status Updates
- **Instant**: Grid updates immediately
- **Color Change**: Tile color reflects new status
- **No Reload**: Uses setState() for smooth updates
- **Persistent**: Changes saved to backend

### Search Behavior
- **Real-time**: Filters as you type
- **Case-insensitive**: Matches any case
- **Multi-field**: Searches ID and resident name
- **Clear**: X button to reset

### Filter Behavior
- **Immediate**: Updates grid/list instantly
- **Visual**: Shows only selected status
- **Counts**: Updates legend counts (optional)
- **Persistent**: Maintains filter during session

---

## 7️⃣ Complete User Journeys

### Journey 1: Assign Resident to Vacant Flat
```
1. Open Flat Occupancy Grid
2. See grey tile (A101 - Vacant)
3. Tap grey tile
4. Flat Details Modal opens
5. Click "Assign Resident"
6. Assign Resident Modal opens
7. Choose "Add New" tab
8. Fill form (Name, Phone, Email)
9. See auto-generated credentials
10. Click "Assign Resident"
11. Success! Modal closes
12. Tile turns green
13. Status: Occupied
```

### Journey 2: Change Maintenance to Vacant
```
1. Open Flat Occupancy Grid
2. See yellow tile (A103 - Maintenance)
3. Tap yellow tile
4. Maintenance Modal opens
5. Open status dropdown
6. Select "Mark as Vacant"
7. Status updates
8. Modal closes
9. Tile turns grey
10. Status: Vacant
```

### Journey 3: Remove Resident from Occupied Flat
```
1. Open Flat Occupancy Grid
2. See green tile (A102 - Occupied)
3. Tap green tile
4. Flat Details Modal opens
5. Click "View Details"
6. Occupied Modal opens
7. See resident info (John Doe)
8. Click "Remove" button
9. Confirmation dialog appears
10. Click "Remove" to confirm
11. Resident removed
12. Modal closes
13. Tile turns grey
14. Status: Vacant
```

---

## 8️⃣ Technical Implementation

### State Management
```dart
List<FloorOccupancy> _floorData = [];

void _updateFlatStatus(String flatId, FlatStatus newStatus) {
  setState(() {
    for (var floor in _floorData) {
      for (var flat in floor.flats) {
        if (flat.id == flatId) {
          flat.updateStatus(newStatus);
          break;
        }
      }
    }
  });
}
```

### Color Mapping
```dart
Color _getFlatColor(FlatStatus status) {
  switch (status) {
    case FlatStatus.occupied:
      return const Color(0xFF10B981); // Green
    case FlatStatus.vacant:
      return const Color(0xFFE5E7EB); // Grey
    case FlatStatus.maintenance:
      return const Color(0xFFFBBF24); // Yellow
  }
}
```

### Modal Flow
```dart
// Grid → Details → Action Modal
FlatOccupancyGrid
  → onFlatTap(unit)
    → FlatDetailsModal
      → if vacant: AssignResidentModal
      → if maintenance: MaintenanceModal
      → if occupied: OccupiedModal
        → onStatusChange(newStatus)
          → updateFlatStatus()
            → Grid refreshes
```

---

## 9️⃣ Summary

The Flat Occupancy Grid provides a complete, intuitive system for managing flats with:

✅ **Visual Status**: Color-coded tiles (Green/Grey/Yellow)
✅ **Grid/List Views**: Flexible viewing options
✅ **Search & Filter**: Quick flat finding
✅ **Status-Based Flows**: Different modals per status
✅ **Assign Residents**: Select existing or add new
✅ **Status Management**: Easy status transitions
✅ **Real-time Updates**: Instant grid refresh
✅ **Smooth Animations**: Professional UX
✅ **Complete Integration**: All modals work together

All components follow the LYVO admin design system with consistent colors, typography, spacing, and interactions!
