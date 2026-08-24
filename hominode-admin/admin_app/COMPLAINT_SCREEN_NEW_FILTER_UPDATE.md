# Complaint Management Screen - New Filter Update

## Summary
Updated the complaint management screen to show only "New" complaints by default and simplified the filter system to focus on the complaint workflow stages.

## Changes Made

### 1. Default Filter Changed
- **Before**: Default filter was "All" (showing both pending and in-progress complaints)
- **After**: Default filter is now "New" (showing only pending complaints)

### 2. Filter Tabs Simplified
- **Before**: 4 tabs - "All", "Pending", "In Progress", "Resolved"
- **After**: 3 tabs - "New", "In Progress", "Resolved"
- Removed the "All" tab to focus on specific workflow stages

### 3. Filter Logic Updated
The filtering logic now works as follows:
- **New**: Shows only complaints with `status = pending`
- **In Progress**: Shows only complaints with `status = in-progress`
- **Resolved**: Shows only complaints with `status = resolved`

### 4. UI Text Updates
- Changed "Pending Review" to "New Complaints" in the statistics card
- Updated filter options in the bottom sheet modal
- Changed "View All" button to "View New" button

## Status Flow Function
The status flow remains intact and works according to the existing flow:

1. **New (Pending)** → Complaint is created and awaiting assignment
2. **In Progress** → Staff assigned and actively working on the complaint
3. **Resolved** → Complaint has been completed and resolved

### Status Change Triggers
- **New → In Progress**: When staff is assigned via "Assign & Start Work" button
- **In Progress → Resolved**: When "Mark as Resolved" button is clicked
- **Resolved → New**: When "Reopen Complaint" button is clicked (if needed)

## Firestore Integration
All status changes are properly saved to Firestore using:
```dart
await _complaintService.updateComplaintStatusAndAssignment(
  complaintId,
  status, // 'pending', 'in-progress', or 'resolved'
  assignedTo,
);
```

## Testing Checklist
- [ ] Default screen shows only "New" complaints
- [ ] Switching to "In Progress" tab shows only in-progress complaints
- [ ] Switching to "Resolved" tab shows only resolved complaints
- [ ] Assigning staff and starting work moves complaint from "New" to "In Progress"
- [ ] Marking as resolved moves complaint from "In Progress" to "Resolved"
- [ ] Resolved complaints disappear from "New" and "In Progress" tabs
- [ ] Search functionality works across all filter tabs
- [ ] Statistics cards show correct counts

## Files Modified
- `admin_app/lib/complaint_management_screen.dart`

## No Breaking Changes
- All existing functionality preserved
- Firestore integration unchanged
- Status flow logic unchanged
- Only UI filter presentation modified
