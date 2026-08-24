# Security Work Assignment - Quick Reference

## 🎯 Core Requirements (Flow Function)

### When Work is Assigned
```
✅ Date stored in gates collection (assignedAt field)
✅ Security details stored in gate document
✅ Status changes to "on-duty"
```

### When Security is Absent
```
✅ Status shows "absent"
✅ Work assignment data remains
✅ Attendance system controls status
```

## 📊 Data Flow

### 1. Assign Work
```
Admin → Assign Security Work Modal
  ↓
Security Service: assignWork()
  - Updates staff document
  - Sets status = "on-duty"
  - Stores lastWorkAssignment timestamp
  ↓
Gate Service: assignSecurityToGate()
  - Updates gate document
  - Stores assignedAt timestamp
  - Links security to gate
```

### 2. Mark Attendance
```
Admin → Attendance Screen
  ↓
Attendance Service: markAbsent()
  - Creates attendance record
  - Sets staff.status = "absent"
  - Work assignment remains intact
  ↓
OR
  ↓
Attendance Service: markPresent()
  - Creates attendance record
  - Checks if has work assignment
  - Sets status = "on-duty" (if assigned) or "present"
```

## 🗄️ Firestore Structure

### Staff Document
```json
{
  "status": "on-duty",
  "gateAssignment": "Main Gate",
  "shiftTiming": "Morning Shift (6 AM - 2 PM)",
  "workStatus": "On Duty",
  "lastWorkAssignment": "2024-03-08T10:30:00Z" ← Assignment date
}
```

### Gate Document
```json
{
  "assignedSecurityId": "staff_123",
  "assignedSecurityName": "John Doe",
  "assignedShiftTiming": "Morning Shift (6 AM - 2 PM)",
  "assignedAt": "2024-03-08T10:30:00Z" ← Assignment date stored here
}
```

### Attendance Document
```json
{
  "staffId": "staff_123",
  "date": "2024-03-08",
  "status": "absent",
  "checkInTime": null
}
```

## 🔄 Status Flow

```
┌─────────────────────────────────────────────────┐
│ Work Assignment                                 │
│ status: "pending" → "on-duty"                   │
│ lastWorkAssignment: timestamp                   │
│ gates.assignedAt: timestamp                     │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Mark Absent                                     │
│ status: "on-duty" → "absent"                    │
│ Work assignment data: REMAINS                   │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Mark Present (with work assignment)             │
│ status: "absent" → "on-duty"                    │
│ Work automatically reactivates                  │
└─────────────────────────────────────────────────┘
```

## 🎨 Status Colors

| Status    | Color  | Hex       | Meaning                    |
|-----------|--------|-----------|----------------------------|
| On Duty   | 🟢 Green | #10B981   | Working at assigned gate   |
| Absent    | 🔴 Red   | #EF4444   | Not present today          |
| Off Duty  | ⚫ Gray  | #6B7280   | Shift ended                |
| On Leave  | 🟠 Orange| #F59E0B   | Approved leave             |
| Pending   | ⚪ Light | #9CA3AF   | Not yet assigned           |

## 🔍 Key Fields

### Staff Collection
- `status`: Current duty status (on-duty, absent, off-duty, on-leave)
- `workStatus`: Work type (On Duty, Off Duty, Break)
- `gateAssignment`: Assigned gate name
- `shiftTiming`: Assigned shift
- `lastWorkAssignment`: **Assignment date timestamp** ⭐

### Gates Collection
- `assignedSecurityId`: Linked security staff ID
- `assignedSecurityName`: Security staff name
- `assignedShiftTiming`: Shift for this assignment
- `assignedAt`: **Assignment date timestamp** ⭐

### Attendance Collection
- `status`: Attendance status (present, absent, onLeave)
- `checkInTime`: When they checked in
- `date`: Date of attendance record

## ✅ Implementation Checklist

- [x] Assignment date stored in gates collection
- [x] Security details stored in gate document
- [x] Status changes to "on-duty" on assignment
- [x] Status shows "absent" when marked absent
- [x] Work assignment persists when absent
- [x] Status returns to "on-duty" when present (if assigned)
- [x] Real-time updates across all screens
- [x] Proper flow function compliance

## 🚀 Usage Example

```dart
// 1. Assign work
await securityService.assignWork(
  staffId: 'staff_123',
  shiftTiming: 'Morning Shift (6 AM - 2 PM)',
  gateAssignment: 'Main Gate',
  workStatus: 'On Duty',
);
// Result: status = "on-duty", lastWorkAssignment = now

// 2. Update gate
await gateService.assignSecurityToGate(
  gateId: 'gate_456',
  securityId: 'staff_123',
  securityName: 'John Doe',
  shiftTiming: 'Morning Shift (6 AM - 2 PM)',
);
// Result: assignedAt = now, assignedSecurityId = 'staff_123'

// 3. Mark absent
await attendanceService.markAbsent('staff_123');
// Result: status = "absent", work assignment remains

// 4. Mark present
await attendanceService.markPresent('staff_123');
// Result: status = "on-duty" (because has gateAssignment)
```

## 📝 Notes

- Assignment dates are stored as Firestore Timestamps
- Status updates happen automatically based on attendance
- Work assignments persist across status changes
- Real-time listeners keep UI synchronized
- All changes follow the flow function requirements

## 🔗 Related Files

- `lib/services/security_service.dart` - Work assignment logic
- `lib/services/gate_service.dart` - Gate assignment with date
- `lib/services/attendance_service.dart` - Attendance status management
- `lib/widgets/assign_security_work_modal.dart` - Assignment UI
- `SECURITY_WORK_ASSIGNMENT_DATE_STATUS_FLOW_COMPLETE.md` - Full documentation
