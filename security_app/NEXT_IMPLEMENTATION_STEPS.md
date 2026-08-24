# Next Implementation Steps

## Current Status
✅ Core QR Scanner flow working
✅ Basic Dashboard implemented
✅ Basic Visitor Management (needs enhancement)
✅ Spec-compliant colors and components

## To Implement Next

### 1. Enhanced Visitor Management Screen

**Location:** `lib/screens/visitor_management_screen.dart`

**Required Updates:**
- Add page header with icon and subtitle
- Add 3 statistics cards at top
- Add search bar with clear button
- Enhance tab switcher UI
- Add Approve/Reject buttons in Pending tab
- Add Mark Exit button in Active tab
- Show duration in History tab

**Reference:** SECURITY_APP_COMPLETE_SPECIFICATION.md - Section "Visitor Management Screen Layout"

### 2. Staff Attendance Screen (NEW)

**Location:** `lib/screens/staff_attendance_screen.dart` (to be created)

**Required Components:**
- StandardHeader
- Page header with icon
- 4 statistics cards (Total, Present, Absent, On Leave)
- Quick broadcast card with percentage
- Search bar
- Attendance history list with date cards
- FAB for "Mark Attendance"

**Reference:** SECURITY_APP_COMPLETE_SPECIFICATION.md - Section "Staff Attendance Screen Layout"

### 3. Staff Model (NEW)

**Location:** `lib/models/staff_model.dart` (to be created)

**Fields:**
```dart
{
  name, role, phone, email, address,
  joiningDate, salary,
  status, lastCheckIn, lastCheckOut,
  adminId, buildingId,
  createdAt, updatedAt
}
```

### 4. Attendance Service (NEW)

**Location:** `lib/services/attendance_service.dart` (to be created)

**Methods:**
- `getTodayStats()` - Get today's attendance statistics
- `getAttendanceHistory()` - Get attendance history
- `markPresent(staffId)` - Mark staff present
- `markAbsent(staffId)` - Mark staff absent
- `markOnLeave(staffId)` - Mark staff on leave

## Implementation Priority

1. **High Priority** (Core functionality)
   - Enhanced Visitor Management with Approve/Reject
   - Staff Attendance Screen (basic view)

2. **Medium Priority** (Enhanced features)
   - Search functionality
   - Filter functionality
   - Attendance marking

3. **Low Priority** (Nice to have)
   - Complaint Tracking
   - Authentication/Login
   - Profile Screen

## Quick Implementation Guide

### For Visitor Management Enhancement:

1. Update the existing `visitor_management_screen.dart`
2. Add page header widget (similar to dashboard)
3. Add statistics cards row
4. Add search bar widget
5. Update visitor cards to include action buttons
6. Implement approve/reject/mark exit functions

### For Staff Attendance Screen:

1. Create `staff_model.dart`
2. Create `attendance_service.dart`
3. Create `staff_attendance_screen.dart`
4. Follow the spec layout exactly
5. Use StandardHeader and AppColors
6. Add to bottom navigation

## Code Templates

### Visitor Card with Actions (Pending Tab)
```dart
Widget _buildPendingVisitorCard(VisitorModel visitor) {
  return Container(
    // ... card styling
    child: Column(
      children: [
        // Visitor info
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _approveVisitor(visitor.visitorId),
              child: Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
              ),
            ),
            OutlinedButton(
              onPressed: () => _rejectVisitor(visitor.visitorId),
              child: Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorRed,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

### Statistics Card Template
```dart
Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: TextStyle(fontSize: 10, color: AppColors.textGray)),
      ],
    ),
  );
}
```

## Testing Checklist

After implementation:
- [ ] Visitor Management shows all tabs correctly
- [ ] Approve button works in Pending tab
- [ ] Reject button works in Pending tab
- [ ] Mark Exit button works in Active tab
- [ ] History tab shows duration
- [ ] Staff Attendance screen displays
- [ ] Statistics update in real-time
- [ ] Search functionality works
- [ ] All colors match spec

## Documentation

Update these files after implementation:
- `FINAL_STATUS.md` - Mark features as complete
- `BUILD_SUCCESS.md` - Update feature list
- `HOW_TO_TEST.md` - Add testing steps for new features

## Notes

- Follow the SECURITY_APP_COMPLETE_SPECIFICATION.md exactly
- Use AppColors for all colors
- Use StandardHeader for all screens
- Keep code minimal and focused
- Test after each major change

---

**Ready to implement these features!**
