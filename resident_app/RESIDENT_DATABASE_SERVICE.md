# ResidentDatabaseService - Read-Only Access Guide

## Overview
`ResidentDatabaseService` is a specialized service that provides **read-only access** to resident-specific data. It automatically fetches data for the currently authenticated user's flat and profile.

## Key Features

### ✅ Read-Only Access
- No create, update, or delete operations
- Safe for resident users
- Prevents accidental data modification

### ✅ User-Scoped Data
- Automatically filters data by current user
- Fetches only relevant flat data
- No need to pass user/flat IDs manually

### ✅ Clean Architecture
- Separated from general DatabaseService
- Single responsibility principle
- Easy to maintain and test

### ✅ Real-Time Streaming
- Live updates for all data types
- Efficient Firebase listeners
- Automatic cleanup

## Usage

### Initialize Service
```dart
final residentDb = ResidentDatabaseService();
```

## API Reference

### Profile Data

#### Get My Profile
```dart
final result = await residentDb.getMyProfile();

if (result.success && result.data != null) {
  final user = result.data!;
  print('Name: ${user.fullName}');
  print('Email: ${user.email}');
  print('Phone: ${user.phoneNumber}');
  print('Role: ${user.role}');
}
```

#### Stream My Profile (Real-time)
```dart
residentDb.streamMyProfile().listen((user) {
  if (user != null) {
    print('Profile updated: ${user.fullName}');
  }
});
```

### Flat Details

#### Get My Flat
```dart
final result = await residentDb.getMyFlat();

if (result.success && result.data != null) {
  final flat = result.data!;
  print('Flat: ${flat.block}-${flat.flatNumber}');
  print('Floor: ${flat.floor}');
  print('Area: ${flat.area} sq ft');
  print('Status: ${flat.status}');
}
```

#### Stream My Flat (Real-time)
```dart
residentDb.streamMyFlat().listen((flat) {
  if (flat != null) {
    print('Flat updated: ${flat.flatNumber}');
  }
});
```

### Bills

#### Get All My Bills
```dart
final result = await residentDb.getMyBills();

if (result.success) {
  for (var bill in result.data!) {
    print('Bill: ${bill.type} - ₹${bill.amount}');
    print('Due: ${bill.dueDate}');
    print('Status: ${bill.status}');
  }
}
```

#### Get Pending Bills Only
```dart
final result = await residentDb.getMyPendingBills();

if (result.success) {
  print('Pending bills: ${result.data!.length}');
  for (var bill in result.data!) {
    print('${bill.type}: ₹${bill.amount}');
  }
}
```

#### Get Paid Bills
```dart
final result = await residentDb.getMyPaidBills(limit: 10);

if (result.success) {
  print('Recent paid bills: ${result.data!.length}');
}
```

#### Get Total Pending Amount
```dart
final result = await residentDb.getMyTotalPendingAmount();

if (result.success) {
  print('Total pending: ₹${result.data}');
}
```

#### Stream Bills (Real-time)
```dart
// All bills
residentDb.streamMyBills().listen((bills) {
  print('Total bills: ${bills.length}');
});

// Pending bills only
residentDb.streamMyBills(status: 'pending').listen((bills) {
  print('Pending bills: ${bills.length}');
});
```

### Payments

#### Get All My Payments
```dart
final result = await residentDb.getMyPayments();

if (result.success) {
  for (var payment in result.data!) {
    print('Payment: ₹${payment.amount}');
    print('Method: ${payment.method}');
    print('Date: ${payment.paymentDate}');
    print('Status: ${payment.status}');
  }
}
```

#### Get Recent Payments (Last 10)
```dart
final result = await residentDb.getMyRecentPayments();

if (result.success) {
  print('Recent payments: ${result.data!.length}');
}
```

#### Get Payments for Specific Bill
```dart
final result = await residentDb.getPaymentsForBill('bill123');

if (result.success) {
  print('Payments for this bill: ${result.data!.length}');
}
```

#### Stream Payments (Real-time)
```dart
residentDb.streamMyPayments().listen((payments) {
  print('Total payments: ${payments.length}');
  final total = payments.fold<double>(
    0,
    (sum, payment) => sum + payment.amount,
  );
  print('Total paid: ₹$total');
});
```

### Visitors

#### Get All My Visitors
```dart
final result = await residentDb.getMyVisitors();

if (result.success) {
  for (var visitor in result.data!) {
    print('Visitor: ${visitor.visitorName}');
    print('Purpose: ${visitor.purpose}');
    print('Expected: ${visitor.expectedArrival}');
    print('Status: ${visitor.status}');
  }
}
```

#### Get Expected Visitors
```dart
final result = await residentDb.getMyExpectedVisitors();

if (result.success) {
  print('Expected visitors: ${result.data!.length}');
  for (var visitor in result.data!) {
    print('${visitor.visitorName} - ${visitor.expectedArrival}');
  }
}
```

#### Get Recent Visitors (Last 20)
```dart
final result = await residentDb.getMyRecentVisitors();

if (result.success) {
  print('Recent visitors: ${result.data!.length}');
}
```

#### Stream Visitors (Real-time)
```dart
// All visitors
residentDb.streamMyVisitors().listen((visitors) {
  print('Total visitors: ${visitors.length}');
});

// Expected visitors only
residentDb.streamMyVisitors(status: 'expected').listen((visitors) {
  print('Expected visitors: ${visitors.length}');
});
```

### Notices

#### Get Active Notices
```dart
final result = await residentDb.getActiveNotices();

if (result.success) {
  for (var notice in result.data!) {
    print('Notice: ${notice.title}');
    print('Category: ${notice.category}');
    print('Priority: ${notice.priority}');
    print('Published: ${notice.publishDate}');
  }
}
```

#### Get Recent Notices (Last 10)
```dart
final result = await residentDb.getRecentNotices();

if (result.success) {
  print('Recent notices: ${result.data!.length}');
}
```

#### Get Urgent Notices
```dart
final result = await residentDb.getUrgentNotices();

if (result.success) {
  print('Urgent notices: ${result.data!.length}');
  for (var notice in result.data!) {
    print('⚠️ ${notice.title}');
  }
}
```

#### Stream Notices (Real-time)
```dart
residentDb.streamActiveNotices().listen((notices) {
  print('Active notices: ${notices.length}');
  final urgent = notices.where((n) => n.priority == 'high').length;
  print('Urgent: $urgent');
});
```

### Complaints

#### Get All My Complaints
```dart
final result = await residentDb.getMyComplaints();

if (result.success) {
  for (var complaint in result.data!) {
    print('Complaint: ${complaint.title}');
    print('Category: ${complaint.category}');
    print('Priority: ${complaint.priority}');
    print('Status: ${complaint.status}');
  }
}
```

#### Get Open Complaints
```dart
final result = await residentDb.getMyOpenComplaints();

if (result.success) {
  print('Open complaints: ${result.data!.length}');
}
```

#### Get Resolved Complaints
```dart
final result = await residentDb.getMyResolvedComplaints(limit: 10);

if (result.success) {
  print('Recent resolved: ${result.data!.length}');
}
```

#### Stream Complaints (Real-time)
```dart
// All complaints
residentDb.streamMyComplaints().listen((complaints) {
  print('Total complaints: ${complaints.length}');
});

// Open complaints only
residentDb.streamMyComplaints(status: 'open').listen((complaints) {
  print('Open complaints: ${complaints.length}');
});
```

### Dashboard Summary

#### Get Complete Dashboard Data
```dart
final result = await residentDb.getDashboardSummary();

if (result.success && result.data != null) {
  final summary = result.data!;
  
  print('Pending Bills: ${summary.pendingBillsCount}');
  print('Total Pending: ₹${summary.totalPendingAmount}');
  print('Expected Visitors: ${summary.expectedVisitorsCount}');
  print('Open Complaints: ${summary.openComplaintsCount}');
  print('Unread Notices: ${summary.unreadNoticesCount}');
  print('Has Alerts: ${summary.hasAlerts}');
}
```

## UI Integration Examples

### Profile Screen
```dart
class ProfileScreen extends StatelessWidget {
  final residentDb = ResidentDatabaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: residentDb.streamMyProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final user = snapshot.data!;
        return Column(
          children: [
            CircleAvatar(
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(user.fullName[0])
                  : null,
            ),
            Text(user.fullName),
            Text(user.email),
            Text(user.phoneNumber ?? 'No phone'),
          ],
        );
      },
    );
  }
}
```

### Bills Screen
```dart
class BillsScreen extends StatelessWidget {
  final residentDb = ResidentDatabaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BillModel>>(
      stream: residentDb.streamMyBills(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final bills = snapshot.data!;
        final pending = bills.where((b) => b.status == 'pending').toList();
        final paid = bills.where((b) => b.status == 'paid').toList();
        
        return Column(
          children: [
            Text('Pending: ${pending.length}'),
            Text('Paid: ${paid.length}'),
            Expanded(
              child: ListView.builder(
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return ListTile(
                    title: Text(bill.type),
                    subtitle: Text('Due: ${bill.dueDate}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${bill.amount}'),
                        Text(
                          bill.status,
                          style: TextStyle(
                            color: bill.status == 'paid'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
```

### Dashboard Screen
```dart
class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final residentDb = ResidentDatabaseService();
  DashboardSummary? summary;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final result = await residentDb.getDashboardSummary();
    
    if (result.success && mounted) {
      setState(() {
        summary = result.data;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return GridView.count(
      crossAxisCount: 2,
      children: [
        _buildCard(
          'Pending Bills',
          '${summary!.pendingBillsCount}',
          '₹${summary!.totalPendingAmount}',
          Icons.receipt,
          Colors.orange,
        ),
        _buildCard(
          'Expected Visitors',
          '${summary!.expectedVisitorsCount}',
          'Today',
          Icons.people,
          Colors.blue,
        ),
        _buildCard(
          'Open Complaints',
          '${summary!.openComplaintsCount}',
          'Pending',
          Icons.report_problem,
          Colors.red,
        ),
        _buildCard(
          'New Notices',
          '${summary!.unreadNoticesCount}',
          'Unread',
          Icons.notifications,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildCard(
    String title,
    String count,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Visitors Screen
```dart
class VisitorsScreen extends StatelessWidget {
  final residentDb = ResidentDatabaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VisitorModel>>(
      stream: residentDb.streamMyVisitors(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final visitors = snapshot.data!;
        final expected = visitors.where((v) => v.status == 'expected').toList();
        final arrived = visitors.where((v) => v.status == 'arrived').toList();
        
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: 'Expected (${expected.length})'),
                  Tab(text: 'Arrived (${arrived.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildVisitorList(expected),
                    _buildVisitorList(arrived),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitorList(List<VisitorModel> visitors) {
    return ListView.builder(
      itemCount: visitors.length,
      itemBuilder: (context, index) {
        final visitor = visitors[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(visitor.visitorName[0]),
          ),
          title: Text(visitor.visitorName),
          subtitle: Text(visitor.purpose),
          trailing: Text(
            '${visitor.expectedArrival.hour}:${visitor.expectedArrival.minute}',
          ),
        );
      },
    );
  }
}
```

## Error Handling

### Standard Pattern
```dart
final result = await residentDb.getMyBills();

if (result.success) {
  // Success - use result.data
  final bills = result.data!;
  print('Fetched ${bills.length} bills');
} else {
  // Error - show message
  print('Error: ${result.message}');
  print('Code: ${result.errorCode}');
  
  // Handle specific errors
  if (result.errorCode == 'not-authenticated') {
    // Navigate to login
  } else if (result.errorCode == 'not-found') {
    // Show "no data" message
  }
}
```

### With SnackBar
```dart
final result = await residentDb.getMyProfile();

if (result.success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Profile loaded')),
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message ?? 'Failed to load profile'),
      backgroundColor: Colors.red,
    ),
  );
}
```

## Best Practices

### 1. Use Streams for Real-time Data
```dart
// ✅ Good - Real-time updates
StreamBuilder<List<BillModel>>(
  stream: residentDb.streamMyBills(),
  builder: (context, snapshot) {
    // Build UI
  },
)

// ❌ Avoid - Manual polling
Timer.periodic(Duration(seconds: 5), (_) {
  residentDb.getMyBills();
});
```

### 2. Handle Loading States
```dart
StreamBuilder<List<BillModel>>(
  stream: residentDb.streamMyBills(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Text('No bills found');
    }
    
    return ListView(/* ... */);
  },
)
```

### 3. Cache Dashboard Summary
```dart
class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final residentDb = ResidentDatabaseService();
  DashboardSummary? _cachedSummary;
  DateTime? _lastFetch;

  Future<void> _loadSummary({bool force = false}) async {
    // Cache for 5 minutes
    if (!force &&
        _cachedSummary != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < Duration(minutes: 5)) {
      return;
    }

    final result = await residentDb.getDashboardSummary();
    
    if (result.success && mounted) {
      setState(() {
        _cachedSummary = result.data;
        _lastFetch = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadSummary(force: true),
      child: /* ... */,
    );
  }
}
```

### 4. Dispose Streams Properly
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final residentDb = ResidentDatabaseService();
  StreamSubscription<List<BillModel>>? _billsSubscription;

  @override
  void initState() {
    super.initState();
    _billsSubscription = residentDb.streamMyBills().listen((bills) {
      // Handle bills
    });
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

## Common Error Codes

- `not-authenticated` - User not signed in
- `not-found` - Data not found (e.g., no flat assigned)
- `permission-denied` - Insufficient permissions
- `unavailable` - Service unavailable
- `deadline-exceeded` - Request timeout

## Performance Tips

1. **Use Limits**: Fetch only what you need
   ```dart
   await residentDb.getMyBills(limit: 10);
   ```

2. **Filter on Server**: Use status filters
   ```dart
   await residentDb.getMyBills(status: 'pending');
   ```

3. **Stream Only Active Data**: Don't stream everything
   ```dart
   residentDb.streamMyBills(status: 'pending');
   ```

4. **Cache Summary Data**: Avoid frequent dashboard calls
   ```dart
   // Cache for 5 minutes
   ```

## Comparison with DatabaseService

| Feature | ResidentDatabaseService | DatabaseService |
|---------|------------------------|-----------------|
| Access | Read-only | Full CRUD |
| Scope | Current user only | All data |
| User ID | Automatic | Manual |
| Flat ID | Automatic | Manual |
| Use Case | Resident app | Admin app |
| Safety | High | Medium |

## Next Steps

1. **Implement UI Screens** using the service
2. **Add Pull-to-Refresh** for manual updates
3. **Implement Caching** for offline support
4. **Add Analytics** to track usage
5. **Create Widgets** for common patterns

## Support

For issues or questions:
- Check `FIRESTORE_INTEGRATION.md` for general database info
- Review `FIREBASE_QUICK_START.md` for quick reference
- See example implementations above

---

**ResidentDatabaseService is production-ready and optimized for resident users!** 🚀
