# Correct Flat Management Flow

## Current Issue
There's an intermediary "Flat Details Modal" that shouldn't exist. The flow should be direct from grid to the appropriate status modal.

## ❌ INCORRECT FLOW (Current)
```
Grid Tile Click
    ↓
Flat Details Modal (intermediary)
    ↓
Click button
    ↓
Status-specific modal
```

## ✅ CORRECT FLOW (Should Be)
```
Grid Tile Click
    ↓
DIRECTLY opens status-specific modal:
- Vacant → Assign Resident Modal
- Maintenance → Maintenance Status Modal
- Occupied → Occupied Details Modal
```

## Implementation Fix

### Remove Intermediary Modal
The `flat_details_modal.dart` should be removed or only used for initial vacant state.

### Direct Modal Opening
```dart
void _handleFlatTap(FlatUnit unit) {
  if (unit.status == FlatStatus.vacant) {
    // DIRECT to Assign Resident
    AssignResidentModal.show(context, ...);
  } else if (unit.status == FlatStatus.maintenance) {
    // DIRECT to Maintenance Modal
    FlatMaintenanceModal.show(context, ...);
  } else if (unit.status == FlatStatus.occupied) {
    // DIRECT to Occupied Details
    FlatOccupiedModal.show(context, ...);
  }
}
```

## Correct Flow by Status

### VACANT (Grey Tile)
```
Click Grey Tile
    ↓
Assign Resident Modal Opens DIRECTLY
    ↓
Two tabs: Select Existing / Add New
    ↓
User assigns resident
    ↓
Status: Vacant → Occupied
    ↓
Tile: Grey → Green
```

### MAINTENANCE (Yellow Tile)
```
Click Yellow Tile
    ↓
Maintenance Modal Opens DIRECTLY
    ↓
Shows warning + status dropdown
    ↓
User changes status
    ↓
Status updates
    ↓
Tile color changes
```

### OCCUPIED (Green Tile)
```
Click Green Tile
    ↓
Occupied Details Modal Opens DIRECTLY
    ↓
Shows resident info + actions
    ↓
User removes resident OR changes status
    ↓
Status updates
    ↓
Tile color changes
```

## Files to Update

1. **flat_occupancy_grid_stateful.dart** - Update `_handleFlatTap` to open correct modal directly
2. **flat_details_modal.dart** - Remove or deprecate (not needed in flow)
3. All status updates should work through callbacks

## Status Update Flow

```dart
// In Grid Stateful Widget
void _handleFlatTap(FlatUnit unit) {
  switch (unit.status) {
    case FlatStatus.vacant:
      AssignResidentModal.show(
        context,
        flatId: unit.id,
        flatLabel: unit.id,
        onAssign: (request) async {
          // Update status to occupied
          setState(() {
            unit.updateStatus(FlatStatus.occupied);
          });
        },
      );
      break;
      
    case FlatStatus.maintenance:
      FlatMaintenanceModal.show(
        context,
        unit: unit,
        onStatusChange: (newStatus) {
          setState(() {
            unit.updateStatus(newStatus);
          });
        },
      );
      break;
      
    case FlatStatus.occupied:
      FlatOccupiedModal.show(
        context,
        unit: unit,
        onStatusChange: (newStatus) {
          setState(() {
            unit.updateStatus(newStatus);
          });
        },
      );
      break;
  }
}
```

## Summary

✅ Remove intermediary Flat Details Modal
✅ Direct modal opening based on status
✅ Status updates work through callbacks
✅ Grid refreshes automatically with setState()
✅ Colors update immediately
