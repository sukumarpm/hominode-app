# Cloud Firestore Integration Guide

## Overview
Cloud Firestore has been integrated into the app with a comprehensive DatabaseService class following clean architecture principles.

## Features Implemented

### Collections
- ✅ **users** - User profiles and authentication data
- ✅ **buildings** - Building/society information
- ✅ **flats** - Individual flat/apartment details
- ✅ **residents** - Resident-flat relationships
- ✅ **bills** - Billing information
- ✅ **payments** - Payment records
- ✅ **visitors** - Visitor management
- ✅ **notices** - Announcements and notices
- ✅ **complaints** - Complaint tracking

### CRUD Operations
Each collection supports:
- ✅ Create - Add new documents
- ✅ Read - Get single or multiple documents
- ✅ Update - Modify existing documents
- ✅ Delete - Remove documents
- ✅ Stream - Real-time updates
- ✅ Query - Filter and sort data

## Architecture

### Clean Architecture Layers
```
lib/src/
├── models/          # Data models
│   ├── user_model.dart
│   ├── building_model.dart
│   ├── flat_model.dart
│   ├── resident_model.dart
│   ├── bill_model.dart
│   ├── payment_model.dart
│   ├── visitor_model.dart
│   ├── notice_model.dart
│   └── complaint_model.dart
└── services/        # Business logic
    └── database_service.dart
```

### Data Models
All models include:
- Type-safe properties
- `toMap()` - Convert to Firestore format
- `fromMap()` - Create from Firestore data
- `fromSnapshot()` - Create from DocumentSnapshot
- `copyWith()` - Immutable updates
- Timestamp handling

### DatabaseService
- Singleton pattern for global access
- Generic `DatabaseResult<T>` for type-safe responses
- Comprehensive error handling
- User-friendly error messages
- Real-time streaming support

## Usage Examples

### Initialize Service
```dart
final db = DatabaseService();
```

### Users

#### Create User
```dart
final user = UserModel(
  id: 'user123',
  fullName: 'John Doe',
  email: 'john@example.com',
  phoneNumber: '+919876543210',
  role: 'resident',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createUser(user);
if (result.success) {
  print('User created: ${result.data?.fullName}');
} else {
  print('Error: ${result.message}');
}
```

#### Get User
```dart
final result = await db.getUser('user123');
if (result.success) {
  final user = result.data!;
  print('User: ${user.fullName}');
}
```

#### Update User
```dart
final result = await db.updateUser('user123', {
  'fullName': 'John Smith',
  'photoURL': 'https://example.com/photo.jpg',
});
```

#### Delete User
```dart
final result = await db.deleteUser('user123');
```

#### Stream Users (Real-time)
```dart
db.streamUsers().listen((users) {
  print('Total users: ${users.length}');
  for (var user in users) {
    print('- ${user.fullName}');
  }
});
```

### Buildings

#### Create Building
```dart
final building = BuildingModel(
  id: '',
  name: 'Sunrise Apartments',
  address: '123 Main Street, City',
  totalFloors: 10,
  totalFlats: 80,
  amenities: ['Gym', 'Pool', 'Parking'],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createBuilding(building);
```

#### Get All Buildings
```dart
final result = await db.getAllBuildings();
if (result.success) {
  for (var building in result.data!) {
    print('Building: ${building.name}');
  }
}
```

### Flats

#### Create Flat
```dart
final flat = FlatModel(
  id: '',
  buildingId: 'building123',
  flatNumber: '101',
  block: 'A',
  floor: 1,
  area: 1200,
  bedrooms: 3,
  bathrooms: 2,
  status: 'occupied',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createFlat(flat);
```

#### Get Flats by Building
```dart
final result = await db.getFlatsByBuilding('building123');
if (result.success) {
  print('Total flats: ${result.data!.length}');
}
```

#### Stream Flats (Real-time)
```dart
db.streamFlatsByBuilding('building123').listen((flats) {
  print('Flats updated: ${flats.length}');
});
```

### Bills

#### Create Bill
```dart
final bill = BillModel(
  id: '',
  flatId: 'flat123',
  type: 'maintenance',
  amount: 5000,
  dueDate: DateTime.now().add(Duration(days: 30)),
  billingPeriodStart: DateTime.now(),
  billingPeriodEnd: DateTime.now().add(Duration(days: 30)),
  status: 'pending',
  description: 'Monthly maintenance charges',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createBill(bill);
```

#### Get Bills by Flat
```dart
final result = await db.getBillsByFlat('flat123');
if (result.success) {
  for (var bill in result.data!) {
    print('Bill: ${bill.type} - ₹${bill.amount}');
  }
}
```

#### Update Bill Status
```dart
final result = await db.updateBill('bill123', {
  'status': 'paid',
});
```

#### Stream Bills (Real-time)
```dart
db.streamBillsByFlat('flat123').listen((bills) {
  final pending = bills.where((b) => b.status == 'pending').length;
  print('Pending bills: $pending');
});
```

### Payments

#### Create Payment
```dart
final payment = PaymentModel(
  id: '',
  billId: 'bill123',
  flatId: 'flat123',
  userId: 'user123',
  amount: 5000,
  method: 'upi',
  status: 'completed',
  transactionId: 'TXN123456',
  paymentDate: DateTime.now(),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createPayment(payment);
```

#### Get Payments by Flat
```dart
final result = await db.getPaymentsByFlat('flat123');
if (result.success) {
  double total = 0;
  for (var payment in result.data!) {
    total += payment.amount;
  }
  print('Total paid: ₹$total');
}
```

### Visitors

#### Create Visitor
```dart
final visitor = VisitorModel(
  id: '',
  flatId: 'flat123',
  hostUserId: 'user123',
  visitorName: 'Jane Smith',
  visitorPhone: '+919876543210',
  purpose: 'Personal visit',
  expectedArrival: DateTime.now().add(Duration(hours: 2)),
  status: 'expected',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createVisitor(visitor);
```

#### Update Visitor Status
```dart
final result = await db.updateVisitor('visitor123', {
  'status': 'arrived',
  'actualArrival': Timestamp.now(),
});
```

#### Stream Visitors (Real-time)
```dart
db.streamVisitorsByFlat('flat123').listen((visitors) {
  final expected = visitors.where((v) => v.status == 'expected').length;
  print('Expected visitors: $expected');
});
```

### Notices

#### Create Notice
```dart
final notice = NoticeModel(
  id: '',
  title: 'Water Supply Maintenance',
  content: 'Water supply will be interrupted tomorrow from 10 AM to 2 PM',
  category: 'maintenance',
  priority: 'high',
  authorId: 'admin123',
  authorName: 'Admin',
  publishDate: DateTime.now(),
  expiryDate: DateTime.now().add(Duration(days: 7)),
  isActive: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createNotice(notice);
```

#### Get Active Notices
```dart
final result = await db.getActiveNotices();
if (result.success) {
  for (var notice in result.data!) {
    print('Notice: ${notice.title}');
  }
}
```

#### Stream Active Notices (Real-time)
```dart
db.streamActiveNotices().listen((notices) {
  print('Active notices: ${notices.length}');
});
```

### Complaints

#### Create Complaint
```dart
final complaint = ComplaintModel(
  id: '',
  flatId: 'flat123',
  userId: 'user123',
  title: 'Elevator not working',
  description: 'The elevator in Block A has been out of service since morning',
  category: 'maintenance',
  priority: 'high',
  status: 'open',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await db.createComplaint(complaint);
```

#### Update Complaint Status
```dart
final result = await db.updateComplaint('complaint123', {
  'status': 'resolved',
  'resolution': 'Elevator has been repaired',
  'resolvedAt': Timestamp.now(),
});
```

#### Stream Complaints (Real-time)
```dart
db.streamComplaintsByFlat('flat123').listen((complaints) {
  final open = complaints.where((c) => c.status == 'open').length;
  print('Open complaints: $open');
});
```

## Error Handling

All methods return `DatabaseResult<T>` with:
- `success`: Boolean indicating operation success
- `message`: User-friendly message
- `data`: Result data (when applicable)
- `errorCode`: Firebase error code

### Example Error Handling
```dart
final result = await db.createUser(user);

if (result.success) {
  // Success
  print('User created: ${result.data?.fullName}');
} else {
  // Error
  print('Error: ${result.message}');
  print('Code: ${result.errorCode}');
  
  // Handle specific errors
  if (result.errorCode == 'permission-denied') {
    // Show permission error
  }
}
```

### Common Error Codes
- `permission-denied`: Insufficient permissions
- `not-found`: Document doesn't exist
- `already-exists`: Document ID already exists
- `unavailable`: Service unavailable
- `deadline-exceeded`: Operation timeout

## Firestore Security Rules

### Basic Rules (Development)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'admin';
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'admin';
    }
    
    // Bills collection
    match /bills/{billId} {
      allow read: if request.auth != null;
      allow create: if request.auth.token.role == 'admin';
      allow update: if request.auth.token.role == 'admin';
    }
    
    // Payments collection
    match /payments/{paymentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth.token.role == 'admin';
    }
    
    // Visitors collection
    match /visitors/{visitorId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
    
    // Notices collection
    match /notices/{noticeId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'admin';
    }
    
    // Complaints collection
    match /complaints/{complaintId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null || request.auth.token.role == 'admin';
    }
  }
}
```

## Best Practices

### 1. Always Check Results
```dart
final result = await db.getUser('user123');
if (result.success && result.data != null) {
  // Use result.data
} else {
  // Handle error
}
```

### 2. Use Streams for Real-time Data
```dart
StreamBuilder<List<BillModel>>(
  stream: db.streamBillsByFlat('flat123'),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ListView.builder(
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          final bill = snapshot.data![index];
          return ListTile(title: Text(bill.type));
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

### 3. Update Timestamps
```dart
// Timestamps are automatically updated in update methods
await db.updateUser('user123', {
  'fullName': 'New Name',
  // updatedAt is automatically set
});
```

### 4. Handle Offline Mode
Firestore supports offline persistence by default. Data is cached locally and synced when online.

### 5. Batch Operations
For multiple operations, use Firestore batch writes:
```dart
final batch = FirebaseFirestore.instance.batch();
// Add multiple operations
await batch.commit();
```

## Testing

### Unit Tests
```dart
test('Create user', () async {
  final db = DatabaseService();
  final user = UserModel(/* ... */);
  final result = await db.createUser(user);
  expect(result.success, true);
});
```

### Integration Tests
Use Firebase Emulator Suite for testing:
```bash
firebase emulators:start
```

## Performance Optimization

### 1. Use Indexes
Create composite indexes for complex queries in Firebase Console.

### 2. Limit Query Results
```dart
final snapshot = await _firestore
    .collection('bills')
    .limit(10)
    .get();
```

### 3. Pagination
```dart
DocumentSnapshot? lastDocument;

Future<void> loadMore() async {
  var query = _firestore.collection('bills').limit(10);
  
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument!);
  }
  
  final snapshot = await query.get();
  lastDocument = snapshot.docs.last;
}
```

### 4. Use Subcollections
For hierarchical data, use subcollections:
```
buildings/{buildingId}/flats/{flatId}
```

## Troubleshooting

### Permission Denied
- Check Firestore Security Rules
- Verify user authentication
- Check user role/claims

### Document Not Found
- Verify document ID
- Check if document was deleted
- Verify collection name

### Timeout Errors
- Check internet connection
- Verify Firestore configuration
- Check for large documents

## Next Steps

### Recommended Enhancements
1. Add pagination for large lists
2. Implement search functionality
3. Add data validation
4. Implement caching strategy
5. Add offline support indicators
6. Implement data migration tools
7. Add analytics tracking
8. Implement backup/restore

### Production Checklist
- [ ] Configure security rules
- [ ] Set up indexes
- [ ] Enable offline persistence
- [ ] Add error logging
- [ ] Implement rate limiting
- [ ] Set up monitoring
- [ ] Test with production data
- [ ] Document API changes

## Support

For issues or questions:
- Firestore Docs: https://firebase.google.com/docs/firestore
- Flutter Fire Docs: https://firebase.flutter.dev/docs/firestore/overview
- Check Firebase Console for logs
- Review security rules
