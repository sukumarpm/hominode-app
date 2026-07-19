# Complaints & Requests - Admin Implementation Summary

## ✅ Implementation Complete

Both visitor management and complaints/requests systems have been updated to store and query data based on flat and admin relationships.

## Changes Made

### 1. Complaint Model Updated
**File**: `lib/src/models/complaint_model.dart`

Added fields:
- `flatLabel` (String?) - Human-readable flat number
- `adminId` (String?) - Admin who manages the flat

Updated methods:
- `toMap()` - Includes new fields
- `fromJson()` - Parses new fields
- `fromMap()` - Parses new fields
- `copyWith()` - Supports new fields

### 2. Complaint Service Enhanced
**File**: `lib/src/services/complaint_firestore_service.dart`

#### Updated Methods:
- `createComplaint()` - Now fetches and stores flatId, flatLabel, adminId from user data

#### New Methods:
- `getAdminComplaints()` - Get all complaints for flats managed by admin
- `getComplaintsByFlatId(flatId)` - Get complaints for specific flat
- `getComplaintsForCurrentUser()` - Auto-detect role and return appropriate data
- `streamAdminComplaints()` - Real-time stream for admin complaints
- `streamComplaintsForCurrentUser()` - Auto-detect role for streaming

## Data Flow

### When Resident Creates Complaint:
```
1. User creates complaint
2. System fetches user data from Firestore
3. Extracts: flatId, flatLabel, adminId
4. Creates complaint document with all fields
5. Stores in 'complaints' collection
```

### When Admin Views Complaints:
```
1. Admin opens complaints list
2. System checks user role
3. If admin: Query by adminId
4. Returns all complaints for managed flats
```

### When Resident Views Complaints:
```
1. Resident opens complaints list
2. System checks user role
3. If resident: Query by userId
4. Returns only personal complaints
```

## Firestore Document Structure

### Complaints Collection
```javascript
{
  "id": "auto-generated",
  "userId": "user-who-created-complaint",
  "userName": "User Name",
  "userEmail": "user@example.com",
  "flatId": "flat-document-id",        // ✅ NEW
  "flatLabel": "A-101",                 // ✅ NEW
  "adminId": "admin-user-id",           // ✅ NEW
  "title": "Complaint Title",
  "description": "Detailed description",
  "category": "maintenance",
  "priority": "medium",
  "status": "pending",
  "assignedTo": "Technician Name",
  "technicianPhone": "+1234567890",
  "assignedStaffId": "staff-id",
  "assignedStaffRole": "Plumber",
  "resolution": "Resolution details",
  "resolvedAt": "Timestamp",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## API Reference

### Resident Methods
```dart
// Get my complaints
final complaints = await ComplaintFirestoreService.instance.getMyComplaints();

// Stream my complaints
ComplaintFirestoreService.instance.streamMyComplaints();
```

### Admin Methods
```dart
// Get all complaints for managed flats
final complaints = await ComplaintFirestoreService.instance.getAdminComplaints();

// Get complaints for specific flat
final flatComplaints = await ComplaintFirestoreService.instance
    .getComplaintsByFlatId('flat-id');

// Stream admin complaints
ComplaintFirestoreService.instance.streamAdminComplaints();
```

### Auto-Detect Methods
```dart
// Automatically returns correct data based on role
final complaints = await ComplaintFirestoreService.instance
    .getComplaintsForCurrentUser();

// Stream with auto-detect
ComplaintFirestoreService.instance.streamComplaintsForCurrentUser();
```

## Complete System Coverage

### ✅ Visitors
- flatId, flatLabel, adminId stored
- Admin query methods implemented
- Role-based access control
- Real-time streaming support

### ✅ Complaints/Requests
- flatId, flatLabel, adminId stored
- Admin query methods implemented
- Role-based access control
- Real-time streaming support

## Testing

### Test Scripts
1. **Visitors**: `flutter run lib/test_visitor_admin_access.dart`
2. **Complaints**: `flutter run lib/test_complaint_admin_access.dart`

### Manual Testing Checklist

#### For Residents:
- [ ] Login as resident
- [ ] Create a visitor - verify flatId, flatLabel, adminId stored
- [ ] Create a complaint - verify flatId, flatLabel, adminId stored
- [ ] View visitors - should see only own visitors
- [ ] View complaints - should see only own complaints

#### For Admins:
- [ ] Login as admin
- [ ] View all visitors for managed flats
- [ ] View all complaints for managed flats
- [ ] Filter by specific flat
- [ ] Verify data isolation (no access to other admins' data)

## Security Recommendations

### Firestore Security Rules

```javascript
// Visitors Collection
match /visitors/{visitorId} {
  allow read: if request.auth != null && 
    (resource.data.hostUserId == request.auth.uid ||
     resource.data.adminId == request.auth.uid);
  
  allow create: if request.auth != null && 
    request.resource.data.hostUserId == request.auth.uid;
  
  allow update, delete: if request.auth != null && 
    (resource.data.hostUserId == request.auth.uid || 
     resource.data.adminId == request.auth.uid);
}

// Complaints Collection
match /complaints/{complaintId} {
  allow read: if request.auth != null && 
    (resource.data.userId == request.auth.uid ||
     resource.data.adminId == request.auth.uid);
  
  allow create: if request.auth != null && 
    request.resource.data.userId == request.auth.uid;
  
  allow update: if request.auth != null && 
    (resource.data.userId == request.auth.uid || 
     resource.data.adminId == request.auth.uid);
  
  allow delete: if request.auth != null && 
    resource.data.userId == request.auth.uid &&
    request.time < resource.data.createdAt + duration.value(1, 'd');
}
```

## Files Created/Updated

### Updated Files:
- ✅ `lib/src/models/visitor_model.dart`
- ✅ `lib/src/services/visitor_firestore_service.dart`
- ✅ `lib/src/models/complaint_model.dart`
- ✅ `lib/src/services/complaint_firestore_service.dart`

### Documentation Files:
- ✅ `VISITOR_FLAT_ADMIN_ACCESS_COMPLETE.md`
- ✅ `VISITOR_ADMIN_QUICK_GUIDE.md`
- ✅ `VISITOR_FLAT_ADMIN_IMPLEMENTATION.md`
- ✅ `COMPLAINTS_FLAT_ADMIN_ACCESS_COMPLETE.md`
- ✅ `COMPLAINTS_REQUESTS_ADMIN_IMPLEMENTATION.md`

### Test Files:
- ✅ `lib/test_visitor_admin_access.dart`
- ✅ `lib/test_complaint_admin_access.dart`

## Benefits

1. **Data Isolation**: Residents only see their own data
2. **Admin Visibility**: Admins see all data for flats they manage
3. **Flat-Based Filtering**: Easy filtering by flat for detailed views
4. **Scalability**: Efficient indexed queries
5. **Security**: Database-level access control
6. **Consistency**: Same pattern across all modules
7. **Real-Time Updates**: Streaming support for live data

## Query Performance

### Indexed Fields (Recommended):
```
visitors:
  - adminId (ascending)
  - hostUserId (ascending)
  - flatId (ascending)
  - status (ascending)

complaints:
  - adminId (ascending)
  - userId (ascending)
  - flatId (ascending)
  - status (ascending)
```

## Next Steps

1. ✅ Update visitor management screen to use new methods
2. ✅ Update complaints screen to use new methods
3. [ ] Add admin dashboard with flat-wise views
4. [ ] Implement Firestore security rules
5. [ ] Add analytics for admins
6. [ ] Test with multiple residents and admins
7. [ ] Add composite indexes in Firestore console

## Migration Notes

### For Existing Data:
If you have existing visitors or complaints without flatId, flatLabel, adminId:

```dart
// Run migration script to update existing documents
Future<void> migrateExistingData() async {
  // Get all visitors without flatId
  final visitors = await FirebaseFirestore.instance
      .collection('visitors')
      .where('flatId', isNull: true)
      .get();
  
  for (var doc in visitors.docs) {
    final userId = doc.data()['hostUserId'];
    
    // Fetch user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      
      // Update visitor with flat data
      await doc.reference.update({
        'flatId': userData['flatId'],
        'flatLabel': userData['flatLabel'],
        'adminId': userData['adminId'],
      });
    }
  }
  
  // Repeat for complaints
}
```

## Status: ✅ COMPLETE

Both visitors and complaints systems now properly store flatId, flatLabel, and adminId, enabling correct role-based data access.
