# Admin Dashboard - Quick Reference Guide

## Real-Time Statistics Display

### Top Row Statistics
1. **Total Residents** - Shows count of all active residents
2. **Total Flats** - Shows count of all flats in all buildings
3. **Pending Visitors** - Shows visitors awaiting approval (tap to view)

### Alert Cards
1. **Pending Complaints** - Shows unresolved complaints (tap to view)
2. **This Month Collection** - Shows total paid bills for current month (tap to view)

## Quick Actions (Primary)

### Row 1
- **Add Building** → Navigate to building management to add new building
- **Add Bill** → Navigate to billing screen to create new bill
- **Approve Visitor** → Navigate to visitor management to approve pending visitors
- **View Complaints** → Navigate to complaint management to handle complaints

### Row 2
- **Residents** → Manage resident accounts
- **Events** → Create and manage events/announcements
- **Parking** → Manage parking slots and vehicles
- **Security** → Security management (coming soon)

## How It Works

### Real-Time Updates
- All statistics update automatically when data changes in Firestore
- No manual refresh needed
- Changes reflect within seconds

### Data Sources
```
Total Residents    → users collection (role == "resident")
Total Flats        → flats collection (all documents)
Pending Visitors   → visitors collection (status == "pending")
Pending Complaints → complaints collection (status != "resolved")
Monthly Collection → bills collection (status == "paid", current month)
```

### Navigation Flow
```
Dashboard
├── Add Building → Manage Buildings Page
├── Add Bill → Billing Screen
├── Approve Visitor → Visitor Management Screen
├── View Complaints → Complaint Management Screen
├── Residents → Admin Residents Page
├── Events → Events & Announcements Screen
├── Parking → Parking Management Screen
└── Security → (Coming Soon)
```

## Usage Examples

### Scenario 1: Approve Pending Visitors
1. Check "Pending Visitors" card on dashboard
2. Tap on the card OR tap "Approve Visitor" quick action
3. Review and approve/reject visitors
4. Dashboard updates automatically

### Scenario 2: Handle Complaints
1. Check "Pending Complaints" alert card
2. Tap on the card OR tap "View Complaints" quick action
3. Assign staff and update status
4. Dashboard reflects new count immediately

### Scenario 3: Add New Building
1. Tap "Add Building" quick action
2. Fill in building details (name, floors, flats per floor)
3. Submit to create building and auto-generate flats
4. "Total Flats" statistic updates automatically

### Scenario 4: Create Bill
1. Tap "Add Bill" quick action
2. Select flat and resident
3. Enter amount and bill details
4. Submit to create bill
5. When paid, "Monthly Collection" updates automatically

## Service Methods Available

### DashboardService
```dart
_dashboardService.getDashboardStats() // Get all stats
_dashboardService.getTotalResidentsCount() // Get resident count
_dashboardService.getTotalFlatsCount() // Get flat count
_dashboardService.getPendingVisitorsCount() // Get pending visitor count
_dashboardService.getPendingComplaintsCount() // Get pending complaint count
_dashboardService.getThisMonthCollection() // Get monthly collection
```

### VisitorService
```dart
_visitorService.getVisitors() // Get all visitors
_visitorService.getPendingVisitors() // Get pending visitors
_visitorService.approveVisitor(id) // Approve visitor
_visitorService.rejectVisitor(id) // Reject visitor
```

### ComplaintService
```dart
_complaintService.getComplaints() // Get all complaints
_complaintService.getPendingComplaints() // Get pending complaints
_complaintService.updateComplaintStatus(id, status) // Update status
```

### BillingService
```dart
_billingService.getBills() // Get all bills
_billingService.getThisMonthCollection() // Get monthly collection
_billingService.addBill(...) // Add new bill
_billingService.markBillAsPaid(id) // Mark as paid
```

## Tips

1. **Real-Time Monitoring**: Keep dashboard open to monitor activity in real-time
2. **Quick Navigation**: Use quick actions for faster access to common tasks
3. **Tap Statistics**: Most statistic cards are tappable for detailed view
4. **Loading States**: Gray skeleton cards appear while loading data
5. **Auto-Refresh**: No need to manually refresh - data updates automatically

## Troubleshooting

### Statistics Not Updating
- Check internet connection
- Verify Firestore rules allow read access
- Check Firebase console for data

### Zero Values Displayed
- Verify collections exist in Firestore
- Check if data has correct field names
- Ensure status fields match expected values

### Navigation Not Working
- Verify all screen imports are correct
- Check routes are defined in main.dart
- Ensure screens are properly implemented

## Color Coding

- **Blue** (#2563EB) - Primary actions (Buildings, Residents)
- **Green** (#10B981) - Financial (Bills, Collection)
- **Orange** (#F4A100) - Visitors
- **Red** (#EF4444) - Complaints, Alerts
- **Purple** (#8B5CF6) - Events
- **Indigo** (#6366F1) - Parking, Security

## Performance Notes

- Dashboard uses StreamBuilder for efficient real-time updates
- Queries are optimized with proper Firestore indexes
- Loading states prevent UI blocking
- Streams are properly disposed to prevent memory leaks
