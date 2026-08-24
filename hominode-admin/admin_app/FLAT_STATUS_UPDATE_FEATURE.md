# Flat Status Auto-Update Feature

## Overview
Implemented automatic flat status updates when residents are assigned. When a resident is assigned to a vacant flat, the flat status automatically changes from "Vacant" to "Occupied" and the UI updates in real-time.

## Status Flow

### Status Types
1. **Vacant** (Grey) - No resident assigned
2. **Occupied** (Green) - Resident assigned and living
3. **Maintenance** (Yellow) - Under repair/renovation

### Automatic Status Changes
- **Vacant → Occupied**: When resident is assigned
- **Occupied → Vacant**: When resident moves out (manual)
- **Any → Maintenance**: When maintenance work starts (manual)
- **Maintenance → Vacant**: When maintenance completes (manual)

## Implementation

### 1. FlatUnit Class Updates
Made status and residentName mutable:
```dart
class FlatUnit {
  String? residentName;  // Changed from final
  FlatStatus status;      // Changed from final
  
  void updateStatus(FlatStatus newStatus, {String? newResidentName}) {
    status = newStatus;
    if (newResidentName != null) {
      residentName = newResidentName;
    }
  }
}
```

### 2. FlatDetailsModal Updates
Added status change callback:
```dart
final Function(FlatStatus newStatus)? onStatusChange;
```

### 3. Status Update Trigger
When resident is assigned:
```dart
onAssign: (request) async {
  await Future.delayed(const Duration(milliseconds: 800));
  widget.onStatusChange?.call(FlatStatus.occupied);
  Navigator.of(context).pop();
},
```

## Complete Flow

1. User opens Flat Occupancy Grid
2. Clicks vacant flat (grey tile)
3. Flat Details Modal shows "Vacant" status
4. Clicks "Assign Resident"
5. Fills form and submits
6. Status automatically updates to "Occupied"
7. Flat tile color changes grey → green
8. Resident name appears on tile
9. UI refreshes immediately

## Usage Example

See `flat_status_update_example.dart` for complete implementation.

## API Integration

Backend should update flat status when resident is assigned.


## Visual Status Flow

```
┌─────────────────────────────────────────────────────────┐
│                   FLAT STATUS FLOW                      │
└─────────────────────────────────────────────────────────┘

Initial State: VACANT (Grey)
┌──────────┐
│  A101    │  ← Flat tile is grey
│  3BHK    │
│  Vacant  │
└──────────┘

User Action: Assign Resident
↓
┌─────────────────────────────────────┐
│  Assign Resident to A101            │
│                                     │
│  Name: John Doe                     │
│  Phone: +91 9876543210              │
│  Email: john@example.com            │
│                                     │
│  [Assign Resident]                  │
└─────────────────────────────────────┘

System Action: Auto-Update Status
↓
Final State: OCCUPIED (Green)
┌──────────┐
│  A101    │  ← Flat tile is now green
│  3BHK    │
│ John Doe │  ← Resident name appears
└──────────┘

Status Updated: Vacant → Occupied ✅
```

## Color Coding

| Status      | Color  | Hex Code  | Use Case                    |
|-------------|--------|-----------|----------------------------|
| Vacant      | Grey   | #D1D5DB   | No resident assigned       |
| Occupied    | Green  | #10B981   | Resident living in flat    |
| Maintenance | Yellow | #FBBF24   | Under repair/renovation    |

## Callback Chain

```dart
FlatOccupancyGrid
  └─> onFlatTap(unit)
      └─> FlatDetailsModal.show(
            onStatusChange: (newStatus) {
              updateFlatStatus(unit.id, newStatus)
            }
          )
          └─> AssignResidentModal.show(
                onAssign: (request) {
                  // Assign resident
                  onStatusChange(FlatStatus.occupied) ✅
                }
              )
```

## State Management

The flat status is managed at the parent component level:

1. **Parent Component** holds the list of FloorOccupancy
2. **Callback** propagates status change up
3. **setState()** triggers UI rebuild
4. **Grid refreshes** with new status
5. **Colors update** automatically

## Backend Sync

When status changes, sync with backend:

```dart
void _updateFlatStatus(String flatId, FlatStatus newStatus) {
  setState(() {
    // Update local state
    flat.updateStatus(newStatus);
  });
  
  // Sync with backend
  api.updateFlatStatus(flatId, newStatus).then((_) {
    print('✅ Status synced with backend');
  }).catchError((error) {
    print('❌ Failed to sync status');
    // Revert local change if API fails
  });
}
```

## Testing Checklist

- [ ] Assign resident to vacant flat
- [ ] Verify status changes to occupied
- [ ] Verify tile color changes grey → green
- [ ] Verify resident name appears on tile
- [ ] Verify grid refreshes immediately
- [ ] Test with multiple flats
- [ ] Test error handling
- [ ] Test backend sync
