# Flat Management Flow Restrictions

## Overview
Updated the flat management system to restrict "Assign Resident" functionality to ONLY vacant flats, as per the correct workflow.

## Flow Rules

### ✅ VACANT Flats (Grey)
**Status**: No resident assigned
**Action**: "Assign Resident" button
**Flow**:
```
Click Vacant Flat
    ↓
Flat Details Modal opens
    ↓
Shows "Assign Resident" button
    ↓
Click button
    ↓
Assign Resident Modal opens
    ↓
User assigns resident
    ↓
Status updates: Vacant → Occupied
    ↓
Tile color changes: Grey → Green
```

### ✅ MAINTENANCE Flats (Yellow)
**Status**: Under maintenance/repair
**Action**: "Update Status" button
**Flow**:
```
Click Maintenance Flat
    ↓
Flat Details Modal opens
    ↓
Shows "Update Status" button
    ↓
Click button
    ↓
Maintenance Modal opens
    ↓
User selects new status (Vacant/Occupied)
    ↓
Status updates accordingly
    ↓
Tile color changes: Yellow → Grey/Green
```

### ❌ OCCUPIED Flats (Green)
**Status**: Resident already living
**Action**: NO button - Info message only
**Flow**:
```
Click Occupied Flat
    ↓
Flat Details Modal opens
    ↓
Shows info message:
"This flat is currently occupied by [Resident Name]."
    ↓
NO assign resident option
    ↓
User can only view information
    ↓
Close modal
```

## UI Changes

### Vacant Flat Details
```
┌─────────────────────────────────────┐
│  Flat A101                      [X] │
│  View and manage flat details...   │
│                                     │
│  Floors          Flats per Floor    │
│  Floor 10        3BHK               │
│                                     │
│  Area            Status             │
│  1500 Sqft       [Vacant]           │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ This flat is currently vacant │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │    Assign Resident            │ │ ← Button
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Occupied Flat Details
```
┌─────────────────────────────────────┐
│  Flat A102                      [X] │
│  View and manage flat details...   │
│                                     │
│  Floors          Flats per Floor    │
│  Floor 10        2BHK               │
│                                     │
│  Area            Status             │
│  1200 Sqft       [Occupied]         │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ This flat is currently        │ │
│  │ occupied. View resident       │ │
│  │ details or update information.│ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ ✓ This flat is currently      │ │ ← Info message
│  │   occupied by John Doe.       │ │    (NO button)
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Maintenance Flat Details
```
┌─────────────────────────────────────┐
│  Flat A103                      [X] │
│  View and manage flat details...   │
│                                     │
│  Floors          Flats per Floor    │
│  Floor 1         2BHK               │
│                                     │
│  Area            Status             │
│  1200 Sqft       [Maintenance]      │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ This flat is under            │ │
│  │ maintenance. Update status    │ │
│  │ when work is complete.        │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │    Update Status              │ │ ← Button
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

## Code Implementation

### Button Logic
```dart
Widget _buildPrimaryButton() {
  if (widget.unit.status == FlatStatus.occupied) {
    // Show info message, NO button
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5), // Light green
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF10B981)),
          Text('This flat is currently occupied by ${residentName}.'),
        ],
      ),
    );
  }
  
  // Show button for vacant and maintenance
  return ElevatedButton(
    onPressed: _handlePrimaryAction,
    child: Text(_getButtonLabel(widget.unit.status)),
  );
}
```

### Action Handler
```dart
Future<void> _handlePrimaryAction() async {
  if (widget.unit.status == FlatStatus.vacant) {
    // ONLY vacant flats can assign residents
    await AssignResidentModal.show(...);
  } else if (widget.unit.status == FlatStatus.maintenance) {
    // Maintenance flats can change status
    await FlatMaintenanceModal.show(...);
  }
  // Occupied flats: No action
}
```

## Status Transitions

### Allowed Transitions
```
VACANT ──────────────→ OCCUPIED
  ↑                        
  │                        
  └──── MAINTENANCE ───────┘
       (via dropdown)
```

### Restricted Transitions
```
OCCUPIED ──X──→ Cannot directly assign new resident
OCCUPIED ──X──→ Must first mark as vacant/maintenance
```

## User Experience

### Vacant Flat Journey
1. User sees grey tile
2. Clicks tile
3. Modal shows "Assign Resident" button
4. Clicks button
5. Assign Resident Modal opens
6. User assigns resident
7. Tile turns green
8. Status: Occupied

### Occupied Flat Journey
1. User sees green tile
2. Clicks tile
3. Modal shows info message
4. NO assign button available
5. User can only view information
6. Close modal

### Maintenance Flat Journey
1. User sees yellow tile
2. Clicks tile
3. Modal shows "Update Status" button
4. Clicks button
5. Maintenance Modal opens
6. User changes status
7. Tile color updates
8. Status: Vacant or Occupied

## Benefits

✅ **Clear Workflow**: Only vacant flats can be assigned
✅ **Prevents Errors**: Cannot accidentally reassign occupied flats
✅ **Better UX**: Clear visual feedback for each status
✅ **Logical Flow**: Matches real-world property management
✅ **Data Integrity**: Protects existing resident assignments

## Summary

The system now correctly restricts the "Assign Resident" functionality to ONLY vacant flats. Occupied flats show an informational message instead of an action button, preventing accidental reassignments and maintaining data integrity.
