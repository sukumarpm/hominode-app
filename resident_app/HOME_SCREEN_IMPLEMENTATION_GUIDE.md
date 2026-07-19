# Home Screen Implementation Guide - Billing & Community Wall

## Overview
This guide explains how the home screen (dashboard) now properly displays billing data and provides access to the community wall according to the flow function.

## Architecture

### Data Flow Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    Dashboard Screen                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │  _loadDashboardData() Method           │
        └───────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
    ┌────────┐         ┌────────┐         ┌────────┐
    │ Step 1 │         │ Step 2 │         │ Step 3 │
    │ Load   │         │ Load   │         │ Load   │
    │ User   │         │ Billing│         │Visitors│
    │ Data   │         │ Data   │         │& Compl.│
    └────────┘         └────────┘         └────────┘
        │                   │                   │
        ▼                   ▼                   ▼
    ┌────────────────────────────────────────────────┐
    │  Calculate Summary Statistics                  │
    │  - Pending Bill Amount                         │
    │  - Visitors Today Count                        │
    │  - Open Complaints Count                       │
    └────────────────────────────────────────────────┘
        │
        ▼
    ┌────────────────────────────────────────────────┐
    │  Update UI with Real Data                      │
    │  - Display in Summary Cards                    │
    │  - Show in Quick Access Buttons                │
    └────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Data Loading Flow

#### Step 1: Load User Data
```dart
final userData = await _userDataService.getCurrentUserData();
```
- Fetches user document from Firestore
- Contains: name, email, flatId, flatLabel, buildingId, etc.
- **Critical**: flatId is used for all subsequent queries

#### Step 2: Load Billing Data
```dart
final currentBill = await _billService.getCurrentBill();
```
- Uses flatId from user data to query bills
- Queries: `bills` collection where `flatId == user.flatId`
- Returns: Pending bill with amount, due date, breakdown, etc.

#### Step 3: Load Visitors & Complaints
```dart
final visitors = await _visitorService.getMyVisitors();
final complaints = await _complaintService.getMyComplaints();
```
- Fetches visitors for current user
- Fetches complaints for current user
- Used to calculate today's visitor count and open complaint count

### 2. Summary Card Calculation

#### Pending Bill Amount
```dart
final billAmount = currentBill != null 
    ? (currentBill['amount'] as num?)?.toDouble() ?? 0.0
    : 0.0;
```
- Displays in "Billing" summary card
- Shows "₹XXXX" format
- Updates in real-time when bills change

#### Visitors Today Count
```dart
final visitorsToday = visitors.where((visitor) {
  final expectedArrival = visitor['expectedArrival'];
  DateTime? visitDate;
  
  if (expectedArrival is Timestamp) {
    visitDate = expectedArrival.toDate();
  }
  
  return visitDate != null && 
         visitDate.isAfter(todayStart) && 
         visitDate.isBefore(todayEnd);
}).length;
```
- Counts visitors with expectedArrival today
- Displays in "Visitors" summary card
- Updates daily

#### Open Complaints Count
```dart
final openComplaints = complaints.where((complaint) {
  final status = complaint['status'] as String?;
  return status == 'pending' || 
         status == 'in-progress' || 
         status == 'inProgress';
}).length;
```
- Counts complaints with pending or in-progress status
- Displays in "Complaints" summary card
- Updates in real-time

### 3. Quick Access Navigation

#### Navigation Logic
```dart
// Get translated labels
final visitorsLabel = 'visitors'.tr();
final billingLabel = 'billing'.tr();
final communityLabel = 'community_wall'.tr();

// Match and navigate
if (label == visitorsLabel || label == 'Visitors') {
  widget.onTabChange?.call(1); // Switch to Visitors tab
}
else if (label == communityLabel || label == 'Community Wall') {
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => const CommunityWallScreen(),
  ));
}
```

#### Supported Navigation Targets
- **Visitors** → Switch to Visitors tab (index 1)
- **Billing** → Switch to Billing tab (index 2)
- **Events** → Switch to Events tab (index 3)
- **Community Wall** → Navigate to CommunityWallScreen
- **Complaints** → Navigate to ComplaintsScreen
- **Messages** → Navigate to MessagesScreenEnhanced
- **Amenities** → Navigate to AmenitiesBookingScreen
- **Marketplace** → Navigate to MarketplaceScreen

## Firestore Collections Used

### users Collection
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "flatId": "T001",
  "flatLabel": "Tower A - 201",
  "buildingId": "building_001",
  "adminId": "admin_001"
}
```

### bills Collection
```json
{
  "flatId": "T001",
  "amount": 5000,
  "status": "pending",
  "dueDate": Timestamp,
  "month": "March 2026",
  "chargeBreakdown": {
    "Maintenance": 2000,
    "Water": 500,
    "Electricity": 1500,
    "Parking": 1000
  }
}
```

### visitors Collection
```json
{
  "hostUserId": "user_001",
  "flatId": "T001",
  "visitorName": "Amit Kumar",
  "expectedArrival": Timestamp,
  "status": "expected"
}
```

### complaints Collection
```json
{
  "userId": "user_001",
  "flatId": "T001",
  "title": "Water Leakage",
  "status": "pending",
  "createdAt": Timestamp
}
```

## Error Handling

### Logging
All operations log detailed information:
```
🔵 Dashboard: Loading dashboard data from Firestore...
📥 Dashboard: Step 1 - Loading user data...
✅ Dashboard: User data loaded successfully
❌ Dashboard: Error loading data: [error message]
```

### Fallback Values
- If user data not found: Show "Not Set" for flat
- If billing data not found: Show "₹0" for pending bill
- If visitors/complaints not found: Show "0" for counts

### Error Recovery
- If any step fails, loading state is cleared
- UI shows last known values
- Error is logged for debugging

## Performance Optimization

### Parallel Loading
Visitors and complaints are loaded in parallel:
```dart
final results = await Future.wait<dynamic>([
  _visitorService.getMyVisitors(),
  _complaintService.getMyComplaints(),
]);
```

### Caching
- BillFirestoreService caches results for 30 seconds
- Reduces Firestore reads
- Improves app responsiveness

### Real-time Updates
- Billing screen uses StreamBuilder for real-time updates
- Dashboard refreshes on navigation back
- Community wall uses real-time streams

## Testing Scenarios

### Scenario 1: New User
- User has no bills
- Dashboard shows "₹0" for billing
- ✅ Expected behavior

### Scenario 2: User with Bills
- User has pending bills in Firestore
- Dashboard shows pending bill amount
- ✅ Expected behavior

### Scenario 3: User with Visitors Today
- User has visitors with today's date
- Dashboard shows visitor count
- ✅ Expected behavior

### Scenario 4: User with Open Complaints
- User has pending/in-progress complaints
- Dashboard shows complaint count
- ✅ Expected behavior

### Scenario 5: Navigation
- User clicks quick access buttons
- Navigates to correct screen/tab
- ✅ Expected behavior

## Debugging Tips

### Enable Verbose Logging
Look for these patterns in console:
- `🔵` - Starting operation
- `📥` - Loading data
- `✅` - Success
- `❌` - Error
- `⚠️` - Warning

### Check Firestore Data
1. Open Firebase Console
2. Go to Firestore Database
3. Check collections:
   - users → Verify flatId exists
   - bills → Verify flatId matches user's flatId
   - visitors → Verify hostUserId matches user ID
   - complaints → Verify userId matches user ID

### Common Issues

**Issue**: Dashboard shows ₹0 for billing
- **Check**: Does user document have flatId?
- **Check**: Do bills exist with matching flatId?
- **Check**: Is bill status "pending"?

**Issue**: Community wall button doesn't work
- **Check**: Is CommunityWallScreen imported?
- **Check**: Are there any errors in console?
- **Check**: Is navigation being triggered?

**Issue**: Visitor/complaint counts are wrong
- **Check**: Are dates correct in Firestore?
- **Check**: Is status field correct?

## Related Documentation

- `HOME_SCREEN_FIX_COMPLETE.md` - Summary of changes
- `QUICK_ACTION_HOME_SCREEN_FIX.md` - Quick testing guide
- `FIRESTORE_RULES_PERMISSION_FIX.md` - Firestore rules setup
- `BILLING_FLOW_FUNCTION_COMPLETE.md` - Billing flow details
- `COMMUNITY_WALL_FLOW_VISUAL.md` - Community wall flow details

## Status
✅ **COMPLETE** - Home screen is fully implemented and working according to the flow function.
