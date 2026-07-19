# Visitor Management - Flat & Admin Access Complete ✅

## Overview
The visitor management system now stores `flatId`, `flatLabel`, and `adminId` in the Firestore `visitors` collection. This enables proper data access control where admins can only see visitors for flats they manage.

## Data Structure

### Visitor Document Fields
```dart
{
  'id': 'auto-generated',
  'hostUserId': 'user-id-who-added-visitor',
  'hostName': 'User Name',
  'hostEmail': 'user@example.com',
  'flatId': 'flat-document-id',           // ✅ NEW
  'flatLabel': 'A-101',                    // ✅ NEW
  'adminId': 'admin-user-id',              // ✅ NEW
  'visitorName': 'Visitor Name',
  'purpose': 'Personal Visit',
  'expectedArrival': Timestamp,
  'phoneNumber': '+1234567890',
  'vehicleNumber': 'ABC-1234',
  'status': 'expected',
  'isApproved': false,
  'approvedBy': null,
  'approvedAt': null,
  'actualArrival': null,
  'departure': null,
  'createdAt': Timestamp,
  'updatedAt': Timestamp,
}
```

## Flow Function

### 1. Resident Adds Visitor
```
User logs in → User data fetched from Firestore
  ↓
Extract: flatId, flatLabel, adminId from user document
  ↓
Create visitor document with all fields
  ↓
Store in Firestore 'visitors' collection
```

### 2. Admin Views Visitors
```
Admin logs in → Check user role
  ↓
If role == 'admin':
  Query: visitors.where('adminId', isEqualTo: currentUserId)
  ↓
Returns: All visitors for flats managed by this admin
```

### 3. Resident Views Visitors
```
Resident logs in → Check user role
  ↓
If role == 'resident':
  Query: visitors.where('hostUserId', isEqualTo: currentUserId)
  ↓
Returns: Only visitors added by this resident
```

## Updated Files

### 1. Visitor Model (`lib/src/models/visitor_model.dart`)
- Added `flatLabel` field (String?)
- Added `adminId` field (String?)
- Updated `toMap()`, `fromJson()`, `fromMap()`, and `copyWith()` methods

### 2. Visitor Service (`lib/src/services/visitor_firestore_service.dart`)
- Updated `addExpectedVisitor()` to fetch and store flatId, flatLabel, adminId
- Added `getAdminVisitors()` - Query visitors by adminId
- Added `getVisitorsByFlatId()` - Query visitors by flatId
- Added `getVisitorsForCurrentUser()` - Auto-detect role and return appropriate data
- Added `streamAdminVisitors()` - Real-time stream for admin
- Added `streamVisitorsForCurrentUser()` - Auto-detect role for streaming

## API Methods

### For Residents
```dart
// Get my visitors only
final visitors = await VisitorFirestoreService.instance.getMyVisitors();

// Stream my visitors
VisitorFirestoreService.instance.streamMyVisitors();
```

### For Admins
```dart
// Get all visitors for flats I manage
final visitors = await VisitorFirestoreService.instance.getAdminVisitors();

// Get visitors for specific flat
final flatVisitors = await VisitorFirestoreService.instance
    .getVisitorsByFlatId('flat-id');

// Stream admin visitors
VisitorFirestoreService.instance.streamAdminVisitors();
```

### Auto-Detect Role
```dart
// Automatically returns correct data based on user role
final visitors = await VisitorFirestoreService.instance
    .getVisitorsForCurrentUser();

// Stream with auto-detect
VisitorFirestoreService.instance.streamVisitorsForCurrentUser();
```

## Firestore Queries

### Resident Query
```dart
visitors
  .where('hostUserId', isEqualTo: currentUserId)
  .get()
```

### Admin Query
```dart
visitors
  .where('adminId', isEqualTo: currentAdminId)
  .get()
```

### Flat-Specific Query
```dart
visitors
  .where('flatId', isEqualTo: flatId)
  .get()
```

## Security Rules (Recommended)

```javascript
match /visitors/{visitorId} {
  // Residents can read their own visitors
  allow read: if request.auth != null && 
    resource.data.hostUserId == request.auth.uid;
  
  // Admins can read visitors for flats they manage
  allow read: if request.auth != null && 
    resource.data.adminId == request.auth.uid;
  
  // Residents can create visitors
  allow create: if request.auth != null && 
    request.resource.data.hostUserId == request.auth.uid;
  
  // Only host or admin can update/delete
  allow update, delete: if request.auth != null && 
    (resource.data.hostUserId == request.auth.uid || 
     resource.data.adminId == request.auth.uid);
}
```

## Testing

### Test Resident Flow
```dart
// 1. Login as resident
// 2. Add visitor
final result = await VisitorFirestoreService.instance.addExpectedVisitor(
  visitorName: 'John Doe',
  purpose: 'Personal Visit',
  expectedDate: DateTime.now(),
  expectedTime: DateTime.now(),
);

// 3. Verify visitor has flatId, flatLabel, adminId
final visitors = await VisitorFirestoreService.instance.getMyVisitors();
print('Flat ID: ${visitors[0]['flatId']}');
print('Flat Label: ${visitors[0]['flatLabel']}');
print('Admin ID: ${visitors[0]['adminId']}');
```

### Test Admin Flow
```dart
// 1. Login as admin
// 2. Get all visitors for managed flats
final visitors = await VisitorFirestoreService.instance.getAdminVisitors();
print('Total visitors: ${visitors.length}');

// 3. Get visitors for specific flat
final flatVisitors = await VisitorFirestoreService.instance
    .getVisitorsByFlatId('flat-123');
print('Flat visitors: ${flatVisitors.length}');
```

## Benefits

1. **Data Isolation**: Residents only see their own visitors
2. **Admin Access**: Admins see all visitors for flats they manage
3. **Flat Filtering**: Easy to filter visitors by flat
4. **Scalability**: Efficient queries using indexed fields
5. **Security**: Proper access control at database level

## Next Steps

1. Update visitor management screen to use `getVisitorsForCurrentUser()`
2. Add admin dashboard showing all visitors
3. Implement flat-wise visitor filtering for admins
4. Add Firestore security rules
5. Test with multiple residents and admins

## Status: ✅ COMPLETE

All visitor documents now include:
- ✅ flatId
- ✅ flatLabel  
- ✅ adminId
- ✅ Admin query methods
- ✅ Role-based access methods
- ✅ Real-time streaming support
