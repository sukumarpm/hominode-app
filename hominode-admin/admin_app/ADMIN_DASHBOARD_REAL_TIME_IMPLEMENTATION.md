# Admin Dashboard Real-Time Implementation

## Overview
The Admin Dashboard now displays real-time statistics from Firestore using StreamBuilder for automatic updates.

## Features Implemented

### 1. Real-Time Statistics
The dashboard fetches and displays the following statistics in real-time:

- **Total Residents**: Count of users where `role == "resident"` from `users` collection
- **Total Flats**: Count of all documents in `flats` collection
- **Pending Visitors**: Count of visitors where `status == "pending"` from `visitors` collection
- **Pending Complaints**: Count of complaints where `status` is either "pending" or "in-progress" from `complaints` collection
- **This Month Collection**: Sum of all paid bills (`status == "paid"`) for the current month from `bills` collection

### 2. Quick Actions
Four primary quick action buttons are prominently displayed:

1. **Add Building** - Navigate to building management
2. **Add Bill** - Navigate to billing screen
3. **Approve Visitor** - Navigate to visitor management
4. **View Complaints** - Navigate to complaint management

### 3. Services Created

#### DashboardService (`lib/services/dashboard_service.dart`)
- `getTotalResidentsCount()` - Stream of resident count
- `getTotalFlatsCount()` - Stream of flat count
- `getPendingVisitorsCount()` - Stream of pending visitor count
- `getPendingComplaintsCount()` - Stream of pending complaint count
- `getThisMonthCollection()` - Stream of monthly collection amount
- `getDashboardStats()` - Combined stream of all statistics

#### VisitorService (`lib/services/visitor_service.dart`)
- `getVisitors()` - Stream of all visitors
- `getPendingVisitors()` - Stream of pending visitors
- `getPendingVisitorsCount()` - Stream of pending visitor count
- `approveVisitor(id)` - Approve a visitor
- `rejectVisitor(id)` - Reject a visitor

#### ComplaintService (`lib/services/complaint_service.dart`)
- `getComplaints()` - Stream of all complaints
- `getPendingComplaints()` - Stream of pending complaints
- `getPendingComplaintsCount()` - Stream of pending complaint count
- `updateComplaintStatus(id, status)` - Update complaint status

#### BillingService (`lib/services/billing_service.dart`)
- `getBills()` - Stream of all bills
- `getThisMonthCollection()` - Stream of monthly collection
- `addBill(...)` - Add a new bill
- `markBillAsPaid(id)` - Mark bill as paid

## Technical Implementation

### StreamBuilder Usage
The dashboard uses `StreamBuilder` widgets to listen to Firestore changes in real-time:

```dart
StreamBuilder<DashboardStats>(
  stream: _dashboardService.getDashboardStats(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingCard();
    }
    
    if (!snapshot.hasData) {
      return const SizedBox.shrink();
    }
    
    final stats = snapshot.data!;
    // Display statistics
  },
)
```

### Loading States
- Loading skeleton cards are displayed while data is being fetched
- Smooth transition from loading to data display
- Graceful handling of empty states

### Data Models

#### DashboardStats
```dart
class DashboardStats {
  final int totalResidents;
  final int totalFlats;
  final int pendingVisitors;
  final int pendingComplaints;
  final double monthlyCollection;
  
  String get formattedCollection; // Returns formatted currency (₹8.4L)
}
```

#### VisitorModel
```dart
class VisitorModel {
  final String id;
  final String name;
  final String phone;
  final String flatId;
  final String purpose;
  final String status; // pending, approved, rejected, checked-in, checked-out
}
```

#### ComplaintModel
```dart
class ComplaintModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status; // pending, in-progress, resolved
}
```

#### BillModel
```dart
class BillModel {
  final String id;
  final String flatId;
  final String flatLabel;
  final String residentId;
  final String residentName;
  final double amount;
  final String month;
  final String year;
  final String type;
  final String status; // pending, paid, overdue
}
```

## Firestore Collections Structure

### users
```
{
  name: string,
  phone: string,
  email: string,
  residentId: string,
  role: string, // "resident" or "admin"
  flatId: string,
  status: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### flats
```
{
  id: string,
  buildingId: string,
  buildingName: string,
  floor: number,
  flatNumber: number,
  type: string,
  area: string,
  status: string, // vacant, occupied, maintenance
  residentName: string,
  residentId: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### visitors
```
{
  name: string,
  phone: string,
  flatId: string,
  purpose: string,
  status: string, // pending, approved, rejected, checked-in, checked-out
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### complaints
```
{
  title: string,
  description: string,
  category: string,
  priority: string, // low, medium, high
  status: string, // pending, in-progress, resolved
  residentId: string,
  residentName: string,
  flatId: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### bills
```
{
  flatId: string,
  flatLabel: string,
  residentId: string,
  residentName: string,
  amount: number,
  month: string,
  year: string,
  type: string, // maintenance, water, electricity
  status: string, // pending, paid, overdue
  paidAt: timestamp,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## UI Components

### Statistics Cards
- Three cards in the top row showing key metrics
- Real-time updates via StreamBuilder
- Loading skeleton during data fetch
- Tap-to-navigate functionality

### Alert Cards
- Two cards showing pending complaints and monthly collection
- Color-coded for quick visual identification
- Clickable to navigate to respective screens

### Quick Actions
- Eight action buttons arranged in two rows
- Primary actions: Add Building, Add Bill, Approve Visitor, View Complaints
- Secondary actions: Residents, Events, Parking, Security

## Performance Considerations

1. **Efficient Queries**: Uses Firestore compound queries with proper indexing
2. **Stream Management**: Streams are properly disposed when widget is destroyed
3. **Loading States**: Prevents UI jank with skeleton loaders
4. **Error Handling**: Graceful fallbacks for missing data

## Future Enhancements

1. Add caching for frequently accessed data
2. Implement pagination for large datasets
3. Add filters and date range selectors
4. Include trend charts and analytics
5. Add export functionality for reports

## Testing

To test the real-time functionality:

1. Open the dashboard
2. In another device/browser, add a new resident, visitor, or complaint
3. Observe the dashboard statistics update automatically
4. No page refresh required

## Dependencies

- `cloud_firestore`: For Firestore database access
- `firebase_core`: For Firebase initialization
- Flutter's built-in `StreamBuilder` for reactive UI

## Notes

- All statistics update in real-time without manual refresh
- The dashboard automatically reflects changes made anywhere in the system
- Loading states ensure smooth user experience
- Error states are handled gracefully
