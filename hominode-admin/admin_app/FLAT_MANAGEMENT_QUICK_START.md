# Flat Management System - Quick Start Guide

## 🚀 Quick Implementation

### Step 1: Initialize Flat Data
```dart
List<FloorOccupancy> _floorData = [];

void _loadFloorData() {
  setState(() {
    _floorData = [
      FloorOccupancy(
        floorNumber: 10,
        flats: [
          FlatUnit(
            id: 'A101',
            type: '3BHK',
            status: FlatStatus.vacant,
            floor: 10,
            area: '1500 Sqft',
          ),
        ],
      ),
    ];
  });
}
```

### Step 2: Open Occupancy Grid
```dart
FlatOccupancyGridModal.show(
  context,
  towerName: 'Tower A',
  data: _floorData,
  onFlatTap: _handleFlatTap,
);
```

### Step 3: Handle Flat Tap
```dart
void _handleFlatTap(FlatUnit unit) {
  FlatDetailsModal.show(
    context,
    unit: unit,
    onStatusChange: (newStatus) {
      _updateFlatStatus(unit.id, newStatus);
    },
  );
}
```

### Step 4: Update Status
```dart
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

## 📋 Status Colors

| Status      | Color  | Hex     |
|-------------|--------|---------|
| Vacant      | Grey   | #D1D5DB |
| Occupied    | Green  | #10B981 |
| Maintenance | Yellow | #FBBF24 |

## 🔄 Status Transitions

```
Vacant ──────────────→ Occupied
  ↑                        ↓
  └────── Maintenance ─────┘
```

## 🎯 Modal Flow

```
Grid → Details → Action Modal → Status Update → Grid Refresh
```

## ⚡ Key Features

1. **Color-Coded Grid**: Visual status at a glance
2. **Search & Filter**: Find flats quickly
3. **Grid/List Toggle**: Flexible viewing
4. **Auto-Update**: Real-time status changes
5. **Smooth Animations**: Professional UX

## 📱 Modals

### 1. Flat Occupancy Grid
- Shows all flats
- Color-coded by status
- Search and filter
- Grid/List view

### 2. Flat Details
- Shows flat information
- Dynamic button based on status
- Opens appropriate action modal

### 3. Assign Resident
- Select existing resident
- Add new resident
- Auto-generated credentials
- Updates status to Occupied

### 4. Maintenance Status
- Warning message
- Status dropdown
- Change to Vacant/Occupied
- Updates status immediately

## 🔧 Customization

### Change Colors
```dart
// In flat_occupancy_grid_modal.dart
Color _getFlatColor(FlatStatus status) {
  switch (status) {
    case FlatStatus.occupied:
      return const Color(0xFF10B981); // Your color
    // ...
  }
}
```

### Add Custom Fields
```dart
class FlatUnit {
  final String id;
  final String type;
  // Add your fields here
  final String? customField;
}
```

## 🐛 Troubleshooting

### Grid not updating?
- Ensure `setState()` is called
- Check callback is passed correctly
- Verify flat ID matches

### Modal not opening?
- Check context is valid
- Ensure imports are correct
- Verify modal is called with `await`

### Status not changing?
- Check `onStatusChange` callback
- Verify `updateStatus()` is called
- Ensure API call succeeds

## 📚 See Also

- `COMPLETE_FLAT_MANAGEMENT_FLOW.md` - Detailed flow
- `flat_status_update_example.dart` - Working example
- `FLAT_STATUS_UPDATE_FEATURE.md` - Status updates
- `MAINTENANCE_MODAL_FEATURE.md` - Maintenance modal
- `ADD_NEW_RESIDENT_FEATURE.md` - Resident assignment
