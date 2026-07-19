# Complaints & Requests - Flat & Admin Access Complete ✅

## Overview
The complaints/requests management system now stores `flatId`, `flatLabel`, and `adminId` in the Firestore `complaints` collection. This enables proper data access control where admins can only see complaints for flats they manage.

## Data Structure

### Complaint Document Fields
```dart
{
  'id': 'auto-generated',
  'userId': 'user-id-who-created-complaint',
  'userName': 'User Name',
  'userEmail': 'user@example.com',
  'flatId': 'flat-document-id',           // ✅ NEW
  'flatLabel': 'A-101',                    // ✅ NEW
  'adminId': 'admin-user-id',              // ✅ NEW
  'title': 'Complaint Title',
  'description': 'Detailed description',
  'category': 'maintenance',
  'priority': 'medium',
  'status': 'pending',
  'assignedTo': 'Technician Name',
  'technicianPhone': '+1234567890',
  'assignedStaffId': 'staff-id',
  'assignedStaffRole': 'Plumber',
  'resolution': 'Resolution details',
  'resolvedAt': Timestamp,
  'createdAt': Timestamp,
  'updatedAt': Timestamp,
}
```

## Flow Function

### 1. Resident Creates Complaint
```
User logs in → User data fetched from Firestore
  ↓
Extract: flatId, flatLabel, adminId from user document
  ↓
Create complaint document with all fields
  ↓
Store in Firestore 'complaints' collection
```

### 2. Admin Views Complaints
```
Admin logs in → Check user role
  ↓
If role == 'admin':
  Query: complaints.where('adminId', isEqualTo: currentUserId)
  ↓
Returns: All complaints for flats managed by this admin
```

### 3. Resident Views Complaints
```
Resident logs in → Check user role
  ↓
If role == 'resident':
  Query: complaints.where('userId', isEqualTo: currentUserId)
  ↓
Returns: Only complaints created by this resident
```

## Updated Files

### 1. Complaint Model (`lib/src/models/complaint_model.dart`)
- Added `flatLabel` field (String?)
- Added `adminId` field (String?)
- Updated `toMap()`, `fromJson()`, `fromMap()`, and `copyWith()` methods

### 2. Complaint Service (`lib/src/services/complaint_firestore_service.dart`)
- Updated `createComplaint()` to fetch and store flatId, flatLabel, adminId
- Added `getAdminComplaints()` - Query complaints by adminId
- Added `getComplaintsByFlatId()` - Query complaints by flatId
- Added `getComplaintsForCurrentUser()` - Auto-detect role and return appropriate data
- Added `streamAdminComplaints()` - Real-time stream for admin
- Added `streamComplaintsForCurrentUser()` - Auto-detect role for streaming

## API Methods

### For Residents
```dart
// Get my complaints only
final complaints = await ComplaintFirestoreService.instance.getMyComplaints();

// Stream my complaints
ComplaintFirestoreService.instance.streamMyComplaints();
```

### For Admins
```dart
// Get all complaints for flats I manage
final complaints = await ComplaintFirestoreService.instance.getAdminComplaints();

// Get complaints for specific flat
final flatComplaints = await ComplaintFirestoreService.instance
    .getComplaintsByFlatId('flat-id');

// Stream admin complaints
ComplaintFirestoreService.instance.streamAdminComplaints();
```

### Auto-Detect Role
```dart
// Automatically returns correct data based on user role
final complaints = await ComplaintFirestoreService.instance
    .getComplaintsForCurrentUser();

// Stream with auto-detect
ComplaintFirestoreService.instance.streamComplaintsForCurrentUser();
```

## Firestore Queries

### Resident Query
```dart
complaints
  .where('userId', isEqualTo: currentUserId)
  .get()
```

### Admin Query
```dart
complaints
  .where('adminId', isEqualTo: currentAdminId)
  .get()
```

### Flat-Specific Query
```dart
complaints
  .where('flatId', isEqualTo: flatId)
  .get()
```

## Security Rules (Recommended)

```javascript
match /complaints/{complaintId} {
  // Residents can read their own complaints
  allow read: if request.auth != null && 
    resource.data.userId == request.auth.uid;
  
  // Admins can read complaints for flats they manage
  allow read: if request.auth != null && 
    resource.data.adminId == request.auth.uid;
  
  // Residents can create complaints
  allow create: if request.auth != null && 
    request.resource.data.userId == request.auth.uid;
  
  // Only creator or admin can update
  allow update: if request.auth != null && 
    (resource.data.userId == request.auth.uid || 
     resource.data.adminId == request.auth.uid);
  
  // Only creator can delete (within 24 hours)
  allow delete: if request.auth != null && 
    resource.data.userId == request.auth.uid &&
    request.time < resource.data.createdAt + duration.value(1, 'd');
}
```

## Testing

### Test Resident Flow
```dart
// 1. Login as resident
// 2. Create complaint
final result = await ComplaintFirestoreService.instance.createComplaint(
  title: 'Water Leakage',
  description: 'Leaking pipe in bathroom',
  category: ComplaintCategory.maintenance,
);

// 3. Verify complaint has flatId, flatLabel, adminId
final complaints = await ComplaintFirestoreService.instance.getMyComplaints();
print('Flat ID: ${complaints[0].flatId}');
print('Flat Label: ${complaints[0].flatLabel}');
print('Admin ID: ${complaints[0].adminId}');
```

### Test Admin Flow
```dart
// 1. Login as admin
// 2. Get all complaints for managed flats
final complaints = await ComplaintFirestoreService.instance.getAdminComplaints();
print('Total complaints: ${complaints.length}');

// 3. Get complaints for specific flat
final flatComplaints = await ComplaintFirestoreService.instance
    .getComplaintsByFlatId('flat-123');
print('Flat complaints: ${flatComplaints.length}');
```

## Benefits

1. **Data Isolation**: Residents only see their own complaints
2. **Admin Access**: Admins see all complaints for flats they manage
3. **Flat Filtering**: Easy to filter complaints by flat
4. **Scalability**: Efficient queries using indexed fields
5. **Security**: Proper access control at database level
6. **Tracking**: Better complaint tracking per flat and admin

## Complaint Categories

- Maintenance
- Plumbing
- Electrical
- Cleaning
- Security
- Noise
- Parking
- Other

## Complaint Status Flow

```
pending → in_progress → completed
   ↓
rejected
```

## Next Steps

1. Update complaints screen to use `getComplaintsForCurrentUser()`
2. Add admin dashboard showing all complaints
3. Implement flat-wise complaint filtering for admins
4. Add Firestore security rules
5. Add complaint analytics for admins
6. Implement complaint assignment workflow

## Status: ✅ COMPLETE

All complaint documents now include:
- ✅ flatId
- ✅ flatLabel  
- ✅ adminId
- ✅ Admin query methods
- ✅ Role-based access methods
- ✅ Real-time streaming support
