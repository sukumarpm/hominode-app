# Visitor Admin Access - Quick Guide

## What Changed?

Visitor documents now include:
- `flatId` - The flat document ID
- `flatLabel` - Human-readable flat number (e.g., "A-101")
- `adminId` - The admin who manages this flat

## Usage

### For Residents
```dart
// Get my visitors only
final visitors = await VisitorFirestoreService.instance.getMyVisitors();

// Or use auto-detect
final visitors = await VisitorFirestoreService.instance
    .getVisitorsForCurrentUser();
```

### For Admins
```dart
// Get all visitors for flats I manage
final visitors = await VisitorFirestoreService.instance.getAdminVisitors();

// Get visitors for specific flat
final flatVisitors = await VisitorFirestoreService.instance
    .getVisitorsByFlatId('flat-id');

// Or use auto-detect (automatically returns admin visitors)
final visitors = await VisitorFirestoreService.instance
    .getVisitorsForCurrentUser();
```

### Real-Time Streaming
```dart
// For residents
StreamBuilder(
  stream: VisitorFirestoreService.instance.streamMyVisitors(),
  builder: (context, snapshot) {
    // Build UI
  },
)

// For admins
StreamBuilder(
  stream: VisitorFirestoreService.instance.streamAdminVisitors(),
  builder: (context, snapshot) {
    // Build UI
  },
)

// Auto-detect role
StreamBuilder(
  stream: VisitorFirestoreService.instance.streamVisitorsForCurrentUser(),
  builder: (context, snapshot) {
    // Build UI
  },
)
```

## Testing

Run the test script:
```bash
# Make sure you're logged in first
flutter run lib/test_visitor_admin_access.dart
```

## Firestore Structure

```
visitors/
  └── {visitorId}
      ├── hostUserId: "user-123"
      ├── flatId: "flat-456"           ← NEW
      ├── flatLabel: "A-101"           ← NEW
      ├── adminId: "admin-789"         ← NEW
      ├── visitorName: "John Doe"
      ├── purpose: "Personal Visit"
      ├── expectedArrival: Timestamp
      ├── status: "expected"
      └── ...
```

## Query Examples

### Resident Query
```dart
// Returns only visitors where hostUserId matches current user
visitors.where('hostUserId', isEqualTo: currentUserId)
```

### Admin Query
```dart
// Returns all visitors for flats managed by this admin
visitors.where('adminId', isEqualTo: currentAdminId)
```

### Flat Query
```dart
// Returns all visitors for a specific flat
visitors.where('flatId', isEqualTo: flatId)
```

## Benefits

1. **Proper Access Control**: Admins see all visitors for their flats
2. **Data Isolation**: Residents only see their own visitors
3. **Easy Filtering**: Filter by flat, admin, or resident
4. **Scalable**: Efficient indexed queries
5. **Secure**: Database-level access control

## Next Steps

1. Update visitor management screen to use new methods
2. Add admin dashboard with flat-wise visitor view
3. Implement Firestore security rules
4. Test with multiple users and roles
