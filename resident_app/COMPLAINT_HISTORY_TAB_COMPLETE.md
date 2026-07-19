# Complaint History Tab - Complete Implementation

## Overview
Added a tabbed interface to separate active complaints from completed ones, providing a clear history view for residents to track all their past complaints.

## Features Implemented

### 1. Two-Tab Interface

#### Active Tab
- Shows pending and in-progress complaints
- Displays status summary cards (Pending/In Progress/Completed counts)
- Users can create new complaints
- Users can delete pending complaints
- Users can contact staff for in-progress complaints

#### History Tab
- Shows only completed complaints
- Clean historical record
- Read-only view
- No status summary cards (not needed for history)
- Shows completion date and staff who handled it

### 2. Tab Design

```
┌─────────────────────────────────┐
│  [Active]    [History]          │
│   (icon)      (icon)            │
│   Active      History           │
│     3           5               │
└─────────────────────────────────┘
```

- Selected tab: Blue background with white text
- Unselected tab: Gray text
- Shows count of complaints in each tab
- Icons for visual clarity

### 3. Status Flow

```
CREATE → PENDING → IN PROGRESS → COMPLETED
         ↓          ↓             ↓
      Active Tab  Active Tab   History Tab
```

### 4. Empty States

#### Active Tab (No Complaints)
```
┌─────────────────────────────────┐
│                                 │
│         ✓ (icon)                │
│                                 │
│    No active complaints         │
│                                 │
│  Create a new complaint to      │
│  get started                    │
│                                 │
└─────────────────────────────────┘
```

#### History Tab (No History)
```
┌─────────────────────────────────┐
│                                 │
│         ⟲ (icon)                │
│                                 │
│    No complaint history         │
│                                 │
│  Completed complaints will      │
│  appear here                    │
│                                 │
└─────────────────────────────────┘
```

## Implementation Details

### State Management

```dart
class _ComplaintsScreenState extends State<ComplaintsScreen> {
  List<Complaint> _complaints = [];  // All complaints
  int _selectedTabIndex = 0;          // 0 = Active, 1 = History
  
  // Computed properties
  List<Complaint> get _activeComplaints => _complaints
      .where((c) => c.status == ComplaintStatus.pending || 
                    c.status == ComplaintStatus.inProgress)
      .toList();
  
  List<Complaint> get _completedComplaints => _complaints
      .where((c) => c.status == ComplaintStatus.completed)
      .toList();
}
```

### Tab Switching

```dart
void _onTabTapped(int index) {
  setState(() {
    _selectedTabIndex = index;
  });
}
```

### Real-time Updates

- Both tabs update automatically when Firestore changes
- Completed complaints automatically move to History tab
- Active complaints stay in Active tab until completed

## User Experience

### Scenario 1: New Complaint

1. User creates complaint
2. Appears in Active tab with "Pending" status
3. Count updates: Active (1), History (0)

### Scenario 2: Staff Assigned

1. Admin assigns staff
2. Status changes to "In Progress"
3. Still in Active tab
4. Staff details appear
5. User can call/chat with staff

### Scenario 3: Complaint Resolved

1. Admin marks as resolved
2. Status changes to "Completed"
3. Complaint moves to History tab
4. Count updates: Active (0), History (1)
5. Shows green "Completed" badge
6. Read-only view

### Scenario 4: Viewing History

1. User taps History tab
2. Sees all completed complaints
3. Can view details
4. Can see who handled it
5. Can see completion date
6. Cannot delete (historical record)

## UI Components

### Tab Selector

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [shadow],
  ),
  child: Row(
    children: [
      _buildTab(0, 'Active', activeCount, Icons.pending_actions),
      _buildTab(1, 'History', historyCount, Icons.history),
    ],
  ),
)
```

### Tab Button

```dart
GestureDetector(
  onTap: () => setState(() => _selectedTabIndex = index),
  child: Container(
    padding: EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: isSelected ? kPrimaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, color: isSelected ? white : gray),
        Text(label, color: isSelected ? white : gray),
        Text('$count', color: isSelected ? white : gray),
      ],
    ),
  ),
)
```

### Complaint List

```dart
// Active Tab
if (_selectedTabIndex == 0) {
  _buildStatusSummary();  // Show summary cards
  _buildComplaintsList(_activeComplaints);
}

// History Tab
if (_selectedTabIndex == 1) {
  _buildComplaintsList(_completedComplaints);
}
```

## Status Summary Cards

Only shown in Active tab:

```
┌──────────┐  ┌──────────────┐  ┌───────────┐
│    1     │  │      0       │  │     0     │
│ Pending  │  │ In Progress  │  │ Completed │
└──────────┘  └──────────────┘  └───────────┘
   Red            Orange            Green
```

## Benefits

### For Users
1. **Clear Separation** - Active vs completed complaints
2. **Easy Navigation** - Simple tab interface
3. **Historical Record** - Can review past complaints
4. **Status Tracking** - See progress at a glance
5. **Clean Interface** - Not cluttered with old complaints

### For Workflow
1. **Automatic Organization** - Complaints move to history when completed
2. **Real-time Updates** - Tabs update automatically
3. **Proper Lifecycle** - Clear flow from creation to completion
4. **Data Retention** - History preserved for reference

## Testing Scenarios

### Test 1: Create and Complete Flow
1. Create new complaint
2. ✅ Appears in Active tab
3. Admin assigns staff
4. ✅ Still in Active tab, status "In Progress"
5. Admin marks resolved
6. ✅ Moves to History tab automatically
7. ✅ Shows "Completed" badge

### Test 2: Tab Switching
1. Open Complaints screen
2. ✅ Active tab selected by default
3. Tap History tab
4. ✅ Shows completed complaints
5. Tap Active tab
6. ✅ Shows active complaints

### Test 3: Empty States
1. No active complaints
2. ✅ Shows "No active complaints" message
3. Switch to History tab
4. ✅ Shows "No complaint history" message

### Test 4: Counts
1. Create 3 complaints
2. ✅ Active tab shows (3)
3. Admin completes 1
4. ✅ Active tab shows (2)
5. ✅ History tab shows (1)

### Test 5: Real-time Updates
1. Open app on Active tab
2. Admin completes a complaint
3. ✅ Complaint disappears from Active
4. Switch to History tab
5. ✅ Complaint appears in History

## Code Changes

### Files Modified
- `lib/complaints_screen.dart` - Added tab interface

### New Methods
- `_buildTabSelector()` - Tab UI
- `_buildTab()` - Individual tab button
- `_buildEmptyState()` - Empty state messages
- `_activeComplaints` getter - Filter active
- `_completedComplaints` getter - Filter completed

### Updated Methods
- `build()` - Added tab selector and conditional rendering
- Status summary only shows in Active tab

## Visual Design

### Active Tab (Selected)
```
Background: #2563EB (Blue)
Text: #FFFFFF (White)
Icon: #FFFFFF (White)
```

### History Tab (Unselected)
```
Background: Transparent
Text: #9CA3AF (Gray)
Icon: #9CA3AF (Gray)
```

### Tab Container
```
Background: #FFFFFF (White)
Border Radius: 12px
Shadow: 0 2px 8px rgba(0,0,0,0.06)
Margin: 16px
```

## Future Enhancements

### 1. Filter by Date Range
```dart
// In History tab
DateRangePicker(
  onSelected: (start, end) {
    // Filter complaints by date
  },
)
```

### 2. Search in History
```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Search complaints...',
    prefixIcon: Icon(Icons.search),
  ),
  onChanged: (query) {
    // Filter complaints by query
  },
)
```

### 3. Export History
```dart
IconButton(
  icon: Icon(Icons.download),
  onPressed: () {
    // Export complaints to PDF/CSV
  },
)
```

### 4. Statistics
```dart
// In History tab
Container(
  child: Column(
    children: [
      Text('Total Resolved: ${completedCount}'),
      Text('Average Resolution Time: ${avgTime}'),
      Text('Most Common Category: ${topCategory}'),
    ],
  ),
)
```

### 5. Rating System
```dart
// After completion
RatingDialog(
  onRated: (rating, feedback) {
    // Save rating for staff/service
  },
)
```

## Analytics Events

Track tab usage:

```dart
// Tab switched
analytics.logEvent('complaint_tab_switched', {
  'tab': tabName,  // 'active' or 'history'
  'active_count': activeCount,
  'history_count': historyCount,
});

// Complaint completed
analytics.logEvent('complaint_completed', {
  'complaint_id': id,
  'resolution_time_hours': hours,
  'staff_id': staffId,
});
```

## Summary

The complaint system now has:
- ✅ Two-tab interface (Active/History)
- ✅ Automatic organization by status
- ✅ Real-time updates
- ✅ Clear empty states
- ✅ Proper status flow
- ✅ Historical record keeping

Users can now easily track active complaints and review their history, with complaints automatically moving to the appropriate tab based on their status!
