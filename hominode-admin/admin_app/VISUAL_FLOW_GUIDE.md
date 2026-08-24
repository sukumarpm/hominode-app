# 🎨 Visual Flow Guide - Flat Management System

## Complete User Journey with Screenshots Reference

---

## 🏠 Main Entry Point

```
┌─────────────────────────────────────────┐
│     Your App / Demo Page                │
│                                         │
│  [Status Counts Display]                │
│   • Occupied: 3                         │
│   • Vacant: 15                          │
│   • Maintenance: 2                      │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   [Open Flat Grid] Button         │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
                    │
                    │ Tap
                    ▼
```

---

## 📊 Flat Occupancy Grid Modal

```
┌──────────────────────────────────────────────────────────┐
│  Tower A - Flat Occupancy Grid                      [X]  │
│  Visual representation of all flats...                   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┬──────────────┐                        │
│  │  Grid View   │  List View   │  ← Toggle              │
│  └──────────────┴──────────────┘                        │
│                                                          │
│  🟢 Occupied (3)  ⚪ Vacant (15)  🟡 Maintenance (2)    │
│                                                          │
│  [Search by flat or resident...] [Filter: All ▾]        │
│                                                          │
│  Floor 1                                                 │
│  ┌─────┬─────┬─────┬─────┐                             │
│  │ A101│ A102│ A103│ A104│                             │
│  │ 🟢  │ ⚪  │ ⚪  │ ⚪  │  ← Click any tile           │
│  │John │Vacant│Vacant│Vacant│                          │
│  └─────┴─────┴─────┴─────┘                             │
│                                                          │
│  Floor 2                                                 │
│  ┌─────┬─────┬─────┬─────┐                             │
│  │ A201│ A202│ A203│ A204│                             │
│  │ ⚪  │ 🟢  │ ⚪  │ ⚪  │                             │
│  │Vacant│Jane │Vacant│Vacant│                          │
│  └─────┴─────┴─────┴─────┘                             │
│                                                          │
│  Floor 3                                                 │
│  ┌─────┬─────┬─────┬─────┐                             │
│  │ A301│ A302│ A303│ A304│                             │
│  │ ⚪  │ ⚪  │ 🟡  │ ⚪  │                             │
│  │Vacant│Vacant│Maint.│Vacant│                         │
│  └─────┴─────┴─────┴─────┘                             │
└──────────────────────────────────────────────────────────┘
```

**Reference:** Your design file `Grid.png`

---

## 🔄 Flow 1: VACANT FLAT (Grey Tile)

### Step 1: Tap Grey Tile (e.g., A102)

```
┌──────────────────────────────────────────────────────────┐
│  A102                                                [X] │
│  View and manage flat details, resident information...  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Floors              Flats per Floor                     │
│  Floor 1             2BHK                                │
│                                                          │
│  Area                Status                              │
│  1200 Sqft           [Vacant]                           │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ℹ️ This flat is currently vacant. You can assign  │ │
│  │   a resident or change its status.                 │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │          [Assign Resident]                         │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Reference:** Your design file `View and manage flat details, resident information, and status..png`

### Step 2: Tap "Assign Resident"

```
┌──────────────────────────────────────────────────────────┐
│  Assign Resident to A102                            [X] │
│  Select an existing resident or add a new one...        │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┬──────────────────┐               │
│  │ Select Existing  │    Add New       │  ← Tabs       │
│  └──────────────────┴──────────────────┘               │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 👤 Alice Johnson                              ✓   │ │
│  │    ID: RES101                                      │ │
│  ├────────────────────────────────────────────────────┤ │
│  │ 👤 Bob Williams                                    │ │
│  │    ID: RES102                                      │ │
│  ├────────────────────────────────────────────────────┤ │
│  │ 👤 Carol Davis                                     │ │
│  │    ID: RES103                                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Ownership Type                                          │
│  [Owner ▾]                                              │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │          [Assign Resident]                         │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │              [Cancel]                              │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Reference:** Your design file `Select Existing.png`

### Step 2b: Or Switch to "Add New" Tab

```
┌──────────────────────────────────────────────────────────┐
│  Assign Resident to A102                            [X] │
│  Select an existing resident or add a new one...        │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┬──────────────────┐               │
│  │ Select Existing  │    Add New       │  ← Tabs       │
│  └──────────────────┴──────────────────┘               │
│                                                          │
│  Resident Name *                                         │
│  [Enter full name________________]                      │
│                                                          │
│  Phone Number *          Family Members                  │
│  [+91 1234567890___]     [1___]                         │
│                                                          │
│  Email Address                                           │
│  [resident@email.com_____________]                      │
│                                                          │
│  Ownership Type                                          │
│  [Owner ▾]                                              │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ✨ Login credentials will be auto-generated:       │ │
│  │    • Resident ID: RES4523                          │ │
│  │    • Password: Will be sent via SMS/Email          │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │          [Assign Resident]                         │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │              [Cancel]                              │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Reference:** Your design file `add new.png`

### Step 3: After Assignment

```
Grid updates automatically:
A102: ⚪ Vacant → 🟢 Occupied (Alice Johnson)

✅ Success message: "Resident Alice Johnson assigned to A102"
```

---

## 🔄 Flow 2: MAINTENANCE FLAT (Yellow Tile)

### Step 1: Tap Yellow Tile (e.g., A303)

```
┌──────────────────────────────────────────────────────────┐
│  A303                                                [X] │
│  View and manage flat details, resident information...  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Floors              Flats per Floor                     │
│  Floor 3             2BHK                                │
│                                                          │
│  Area                Status                              │
│  1200 Sqft           [Maintenance]                      │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ⚠️ This flat is under maintenance. Change status   │ │
│  │   when ready.                                       │ │
│  │                                                      │ │
│  │  [Keep in Maintenance ▾]                           │ │
│  │   • Keep in Maintenance                             │ │
│  │   • Mark as Vacant                                  │ │
│  │   • Mark as Occupied                                │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Reference:** Your design file `Keep in Maintenance.png`

### Step 2: Select Option

**Option A: Mark as Vacant**
```
A303: 🟡 Maintenance → ⚪ Vacant
✅ "Flat A303 marked as Vacant"
```

**Option B: Mark as Occupied**
```
If no resident: Opens "Assign Resident" modal
If has resident: A303: 🟡 Maintenance → 🟢 Occupied
```

---

## 🔄 Flow 3: OCCUPIED FLAT (Green Tile)

### Step 1: Tap Green Tile (e.g., A101)

```
┌──────────────────────────────────────────────────────────┐
│  A101                                                [X] │
│  View and manage flat details, resident information...  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Floors              Flats per Floor                     │
│  Floor 1             2BHK                                │
│                                                          │
│  Area                Status                              │
│  1200 Sqft           [Occupied]                         │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Resident Information                               │ │
│  │                                                      │ │
│  │  Name :                           John Doe          │ │
│  │  ID :                             RES001            │ │
│  │  Type :                           [Owner]           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌──────────────────┬──────────────────┐               │
│  │  🗑️ Remove      │  [Occupied ▾]    │               │
│  └──────────────────┴──────────────────┘               │
└──────────────────────────────────────────────────────────┘
```

**Reference:** Your design file `Occupied.jpg`

### Step 2a: Tap "Remove" Button

```
┌────────────────────────────────────┐
│  Remove Resident                   │
├────────────────────────────────────┤
│  Remove John Doe from A101?        │
│  This will mark the flat as        │
│  Vacant.                           │
│                                    │
│  [Cancel]  [Remove]                │
└────────────────────────────────────┘
```

**Result:**
```
A101: 🟢 Occupied (John Doe) → ⚪ Vacant
✅ "Resident removed from A101"
```

### Step 2b: Or Change Status via Dropdown

**Select "Vacant":**
```
A101: 🟢 Occupied → ⚪ Vacant
✅ "Flat A101 marked as Vacant"
```

**Select "Maintenance":**
```
A101: 🟢 Occupied → 🟡 Maintenance
(Resident data kept)
✅ "Flat A101 marked as Maintenance"
```

---

## 🔍 Search & Filter Features

### Search Example

```
Search: "john"

Results:
Floor 1
┌─────┐
│ A101│  ← Matches resident name "John Doe"
│ 🟢  │
│John │
└─────┘
```

### Filter Example

```
Filter: Occupied

Results:
Floor 1
┌─────┐
│ A101│
│ 🟢  │
│John │
└─────┘

Floor 2
┌─────┐
│ A202│
│ 🟢  │
│Jane │
└─────┘
```

---

## 📱 List View

```
┌──────────────────────────────────────────────────────────┐
│  Tower A - Flat Occupancy Grid                      [X] │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┬──────────────┐                        │
│  │  Grid View   │  List View   │  ← Toggle              │
│  └──────────────┴──────────────┘                        │
│                                                          │
│  Floor 1                                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 🟢 A101                          John Doe          │ │
│  │    2BHK • Occupied                                 │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ⚪ A102                                            │ │
│  │    2BHK • Vacant                                   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Floor 2                                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ⚪ A201                                            │ │
│  │    2BHK • Vacant                                   │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 🟢 A202                          Jane Smith        │ │
│  │    2BHK • Occupied                                 │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 🎯 Quick Reference: Tile Colors

| Color | Status      | Action on Tap                    |
|-------|-------------|----------------------------------|
| 🟢    | Occupied    | Show resident info + Remove/Status |
| ⚪    | Vacant      | Show details + Assign Resident   |
| 🟡    | Maintenance | Show details + Change Status     |

---

## 🔄 State Update Flow

```
User Action
    │
    ▼
Modal Action (Assign/Remove/Change Status)
    │
    ▼
FlatService Method Called
    │
    ├─> Update central data store
    │
    └─> notifyListeners()
            │
            ▼
    All Listening Widgets Rebuild
            │
            ├─> Grid View updates
            ├─> List View updates
            ├─> Legend counts update
            └─> Status displays update
```

---

## 💡 Tips for Testing

1. **Start with Demo Page:**
   - Run `FlatManagementDemo`
   - See all features working together

2. **Test Each Flow:**
   - Vacant → Assign → Occupied
   - Occupied → Remove → Vacant
   - Occupied → Maintenance → Vacant
   - Maintenance → Occupied (with/without resident)

3. **Test Search & Filter:**
   - Search by flat ID
   - Search by resident name
   - Filter by each status
   - Switch between grid/list

4. **Verify Real-time Updates:**
   - Watch legend counts change
   - See tile colors update
   - Check both grid and list views

---

**All flows are implemented and working! 🎉**
