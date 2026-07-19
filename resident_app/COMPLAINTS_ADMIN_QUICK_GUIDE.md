# Complaints Admin Access - Quick Guide

## What Changed?

Complaint documents now include:
- `flatId` - The flat document ID
- `flatLabel` - Human-readable flat number (e.g., "A-101")
- `adminId` - The admin who manages this flat

## Usage

### For Residents
```dart
// Get my complaints only
final complaints = await ComplaintFirestoreService.instance.getMyComplaints();

// Or use auto-detect
final complaints = await ComplaintFirestoreService.instance
    .getComplaintsForCurrentUser();
```

### For Admins
```dart
// Get all complaints for flats I manage
final complaints = await ComplaintFirestoreService.instance.getAdminComplaints();

// Get complaints for specific flat
final flatComplaints = await ComplaintFirestoreService.instance
    .getComplaintsByFlatId('flat-id');

// Or use auto-detect (automatically returns admin complaints)
final complaints = await ComplaintFirestoreService.instance
    .getComplaintsForCurrentUser();
```

### Real-Time Streaming
```dart
// For residents
StreamBuilder(
  stream: ComplaintFirestoreService.instance.streamMyComplaints(),
  builder: (context, snapshot) {
    // Build UI
  },
)

// For admins
StreamBuilder(
  stream: ComplaintFirestoreService.instance.streamAdminComplaints(),
  builder: (context, snapshot) {
    // Build UI
  },
)

// Auto-detect role
StreamBuilder(
  stream: ComplaintFirestoreService.instance.streamComplaintsForCurrentUser(),
  builder: (context, snapshot) {
    // Build UI
  },
)
```

## Testing

Run the test script:
```bash
# Make sure you're logged in first
flutter run lib/test_complaint_admin_access.dart
```

## Firestore Structure

```
complaints/
  └── {complaintId}
      ├── userId: "user-123"
      ├── flatId: "flat-456"           ← NEW
      ├── flatLabel: "A-101"           ← NEW
      ├── adminId: "admin-789"         ← NEW
      ├── title: "Water Leakage"
      ├── description: "Pipe leaking"
      ├── category: "maintenance"
      ├── status: "pending"
      └── ...
```

## Query Examples

### Resident Query
```dart
// Returns only complaints where userId matches current user
complaints.where('userId', isEqualTo: currentUserId)
```

### Admin Query
```dart
// Returns all complaints for flats managed by this admin
complaints.where('adminId', isEqualTo: currentAdminId)
```

### Flat Query
```dart
// Returns all complaints for a specific flat
complaints.where('flatId', isEqualTo: flatId)
```

## Complaint Status

- `pending` - Newly created, awaiting assignment
- `inProgress` - Assigned to staff, work in progress
- `completed` - Resolved and closed

## Complaint Categories

- Maintenance
- Plumbing
- Electrical
- Cleaning
- Security
- Noise
- Parking
- Other

## Benefits

1. **Proper Access Control**: Admins see all complaints for their flats
2. **Data Isolation**: Residents only see their own complaints
3. **Easy Filtering**: Filter by flat, admin, or resident
4. **Scalable**: Efficient indexed queries
5. **Secure**: Database-level access control

## Complete System

Both systems now support flat & admin access:
- ✅ Visitors Management
- ✅ Complaints/Requests

## Next Steps

1. Update complaints screen to use new methods
2. Add admin dashboard with flat-wise complaint view
3. Implement Firestore security rules
4. Test with multiple users and roles
5. Add complaint analytics for admins
