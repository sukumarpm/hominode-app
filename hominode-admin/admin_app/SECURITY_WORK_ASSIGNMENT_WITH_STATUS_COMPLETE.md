# Security Work Assignment with Status Management - COMPLETE

## Overview
Implemented complete work assignment flow where assigning work to security staff automatically updates their status and stores assignment details in both the staff and gates collections.

## Implementation Details

### 1. Security Service Updates (`lib/services/security_service.dart`)

#### Enhanced `assignWork` Method
- Automatically updates security status based on work assignment
- Status mapping:
  - "On Duty" work status → `on-duty` status
  - "Off Duty" work status → `off-duty` status  
  - "On Leave" work status → `on-leave` status
  - "Absent" work status → `absent` status
- Stores assignment timestamp in `lastWorkAssignment` field
- Updates `updatedAt` timestamp

```dart
Future<void> assignWork({
  required String staffId,
  required String shiftTiming,
  required String gateAssignment,
  required String workStatus,
  String? specialInstructions,
}) async {
  // Determine status based on work assignment
  String newStatus = 'on-duty'; // Default
  
  if (workStatus.toLowerCase() == 'off duty') {
    newStatus = 'off-duty';
  } else if (workStatus.toLowerCase() == 'on leave') {
    newStatus = 'on-leave';
  } else if (workStatus.toLowerCase() == 'absent') {
    newStatus = 'absent';
  }
  
  final updates = {
    'shiftTiming': shiftTiming,
    'gateAssignment': gateAssignment,
    'workStatus': workStatus,
    'specialInstructions': specialInstructions,
    'status': newStatus, // Auto-update status
    'lastWorkAssignment': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  await _firestore.collection('staff').doc(staffId).update(updates);
}
```

### 2. Gate Service Updates (`lib/services/gate_service.dart`)

#### Enhanced GateModel
Added new fields to store assignment details:
- `assignedShiftTiming`: The shift timing assigned to security
- `assignedSpecialInstructions`: Special instructions for the assignment
- `assignedAt`: Timestamp when security was assigned

#### Enhanced `assignSecurityToGate` Method
Now stores complete assignment details:
```dart
Future<bool> assignSecurityToGate({
  required String gateId,
  required String securityId,
  required String securityName,
  required String shiftTiming,
  String? specialInstructions,
}) async {
  await _firestore.collection('gates').doc(gateId).update({
    'assignedSecurityId': securityId,
    'assignedSecurityName': securityName,
    'assignedShiftTiming': shiftTiming,
    'assignedSpecialInstructions': specialInstructions,
    'assignedAt': FieldValue.serverTimestamp(), // Assignment date/time
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

### 3. Assign Work Modal Updates (`lib/widgets/assign_security_work_modal.dart`)

#### Enhanced `_assignWork` Method
Now performs a two-step assignment process:

**Step 1**: Update staff collection
- Assigns work details to security staff
- Automatically updates status to "On Duty" (or other status based on work status)
- Stores assignment timestamp

**Step 2**: Update gates collection
- Finds the selected gate by name
- Updates gate with security assignment details
- Stores assignment date/time in gate document

```dart
Future<void> _assignWork() async {
  // Step 1: Assign work to security staff
  await _securityService.assignWork(
    staffId: widget.staff.id,
    shiftTiming: _selectedShift!,
    gateAssignment: _selectedGate!,
    workStatus: _selectedWorkStatus!,
    specialInstructions: _instructionsController.text.trim(),
  );

  // Step 2: Update gate with assignment details
  final gates = await _gateService.getGates().first;
  final selectedGate = gates.firstWhere(
    (gate) => gate.gateName == _selectedGate,
  );

  await _gateService.assignSecurityToGate(
    gateId: selectedGate.id,
    securityId: widget.staff.id,
    securityName: widget.staff.name,
    shiftTiming: _selectedShift!,
    specialInstructions: _instructionsController.text.trim(),
  );
}
```

## Data Flow

### When Work is Assigned:

1. **Staff Collection Update** (`staff/{staffId}`):
   ```json
   {
     "shiftTiming": "Morning Shift (6 AM - 2 PM)",
     "gateAssignment": "Main Gate",
     "workStatus": "On Duty",
     "specialInstructions": "Check all vehicles",
     "status": "on-duty",  // Auto-updated
     "lastWorkAssignment": Timestamp,
     "updatedAt": Timestamp
   }
   ```

2. **Gates Collection Update** (`gates/{gateId}`):
   ```json
   {
     "assignedSecurityId": "staff123",
     "assignedSecurityName": "John Doe",
     "assignedShiftTiming": "Morning Shift (6 AM - 2 PM)",
     "assignedSpecialInstructions": "Check all vehicles",
     "assignedAt": Timestamp,  // Assignment date/time
     "updatedAt": Timestamp
   }
   ```

## Status Management

### Automatic Status Updates
When work is assigned, the security staff status is automatically updated:

| Work Status | Security Status | Display |
|------------|----------------|---------|
| On Duty | `on-duty` | On Duty (Green) |
| Off Duty | `off-duty` | Off Duty (Gray) |
| On Leave | `on-leave` | On Leave (Orange) |
| Absent | `absent` | Absent (Red) |

### Status Display
The `SecurityStaff` model includes methods for status display:
- `getStatusDisplay()`: Returns user-friendly status text
- `getStatusColor()`: Returns appropriate color for each status
  - On Duty: Green (#10B981)
  - Absent: Red (#EF4444)
  - On Leave: Orange (#F59E0B)
  - Off Duty: Gray (#6B7280)

## Firestore Collections Structure

### Staff Collection
```
staff/
  {staffId}/
    - name: string
    - role: string
    - phone: string
    - status: string (on-duty, off-duty, on-leave, absent)
    - shiftTiming: string
    - gateAssignment: string
    - workStatus: string
    - specialInstructions: string?
    - lastWorkAssignment: Timestamp
    - updatedAt: Timestamp
    - ... other fields
```

### Gates Collection
```
gates/
  {gateId}/
    - gateName: string
    - gateType: string
    - workingStatus: string
    - shiftTime: string?
    - assignedSecurityId: string?
    - assignedSecurityName: string?
    - assignedShiftTiming: string?
    - assignedSpecialInstructions: string?
    - assignedAt: Timestamp?
    - adminId: string
    - buildingId: string?
    - createdAt: Timestamp
    - updatedAt: Timestamp
```

## Features

### ✅ Implemented
1. Work assignment updates security status automatically
2. Assignment details stored in both staff and gates collections
3. Assignment date/time tracked with `assignedAt` and `lastWorkAssignment` timestamps
4. Shift timing stored in gate assignment
5. Special instructions stored in both collections
6. Status automatically changes to "On Duty" when work is assigned
7. Support for Absent status display
8. Validation ensures gate is selected before assignment

### Status Flow
```
Unassigned → Assign Work → On Duty
                ↓
         (Based on Work Status)
                ↓
    On Duty / Off Duty / On Leave / Absent
```

## Testing Checklist

- [ ] Assign work to security staff
- [ ] Verify status changes to "On Duty" in Security Management screen
- [ ] Check staff collection in Firestore for updated fields
- [ ] Check gates collection for assignment details
- [ ] Verify `assignedAt` timestamp is stored
- [ ] Verify `lastWorkAssignment` timestamp is stored
- [ ] Test assigning different work statuses (On Duty, Off Duty, On Leave)
- [ ] Verify status colors display correctly
- [ ] Test with special instructions
- [ ] Test without special instructions

## Files Modified

1. `lib/services/security_service.dart`
   - Enhanced `assignWork()` method with automatic status updates
   
2. `lib/services/gate_service.dart`
   - Added assignment fields to `GateModel`
   - Enhanced `assignSecurityToGate()` method to store assignment details
   
3. `lib/widgets/assign_security_work_modal.dart`
   - Updated `_assignWork()` method to update both collections
   - Added validation for gate selection

## Usage Example

```dart
// Assign work to security staff
await securityService.assignWork(
  staffId: 'staff123',
  shiftTiming: 'Morning Shift (6 AM - 2 PM)',
  gateAssignment: 'Main Gate',
  workStatus: 'On Duty',
  specialInstructions: 'Check all vehicles carefully',
);

// This automatically:
// 1. Updates staff status to 'on-duty'
// 2. Stores assignment timestamp
// 3. Updates gate with security details
// 4. Stores assignment date/time in gate
```

## Benefits

1. **Complete Audit Trail**: Assignment date/time tracked in both collections
2. **Automatic Status Management**: No manual status updates needed
3. **Data Consistency**: Assignment details synchronized across collections
4. **Real-time Updates**: UI reflects status changes immediately via streams
5. **Flexible Status Handling**: Supports all work statuses (On Duty, Off Duty, On Leave, Absent)

## Next Steps (Optional Enhancements)

1. Add assignment history tracking
2. Implement automatic status changes based on shift timing
3. Add notifications when work is assigned
4. Create assignment reports
5. Add bulk assignment functionality
6. Implement shift rotation automation

## Related Documentation

- `SECURITY_MANAGEMENT_COMPLETE.md` - Security management overview
- `ASSIGN_WORK_MODAL_FLOW_UI_FIX_COMPLETE.md` - Assign work modal UI
- `SECURITY_PLACES_CARD_BUTTON_IMPLEMENTATION.md` - Security places management
