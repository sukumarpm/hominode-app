# Admin Data Fetched from Admins Collection - Complete

## Overview
Updated the system to ensure admin profile data is fetched ONLY from the `admins` collection in Firestore, not from the `users` collection. This maintains proper data separation according to the flow function requirements.

## Changes Made

### 1. Admin Service (`lib/services/admin_service.dart`)
**Changed collection from 'users' to 'admins':**
```dart
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'admins'; // Changed from 'users' to 'admins'
```

**Methods that now use 'admins' collection:**
- `getAdminProfile()` - Fetches admin profile data
- All admin-related queries

### 2. Profile Screen (`lib/profile_screen.dart`)
**Already correctly using 'admins' collection:**
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('admins')
    .doc(user.uid)
    .get();
```

### 3. Edit Profile Modal (`lib/widgets/edit_profile_modal.dart`)
**Already correctly using 'admins' collection:**

**Load data:**
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('admins')
    .doc(_userId)
    .get();
```

**Save data:**
```dart
await FirebaseFirestore.instance
    .collection('admins')
    .doc(_userId)
    .set({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'organization': _organizationController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
```

## Data Flow

### Admin Profile Flow
```
1. Admin logs in
   ↓
2. Firebase Auth provides UID
   ↓
3. System fetches admin data from 'admins' collection using UID
   ↓
4. Admin profile displayed in UI
   ↓
5. Admin edits profile
   ↓
6. Changes saved to 'admins' collection
```

### Collection Separation
```
admins/
  └── {adminUid}/
      ├── name
      ├── email
      ├── phone
      ├── organization
      ├── buildingId
      ├── buildingName
      ├── role: 'admin'
      └── timestamps

users/
  └── {userUid}/
      ├── name
      ├── email
      ├── phone
      ├── residentId
      ├── role: 'resident'
      ├── buildingId
      ├── buildingName
      ├── adminId (who created them)
      └── timestamps
```

## Verification

### Files Using 'admins' Collection (Correct)
✅ `lib/services/admin_service.dart` - Admin profile operations
✅ `lib/profile_screen.dart` - Display admin profile
✅ `lib/widgets/edit_profile_modal.dart` - Edit admin profile

### Files Using 'users' Collection (Correct - for residents)
✅ `lib/services/user_service.dart` - Resident operations
✅ `lib/services/auth_service.dart` - Resident authentication
✅ `lib/services/dashboard_service.dart` - Resident statistics
✅ `lib/services/billing_service.dart` - Resident billing
✅ `lib/services/broadcast_service.dart` - Resident messaging
✅ `lib/complaint_management_screen.dart` - Resident complaints

## Benefits

1. **Data Separation**: Admin data is completely separate from resident data
2. **Security**: Admins and residents have different access patterns
3. **Scalability**: Each collection can be optimized independently
4. **Clarity**: Clear distinction between admin and resident data
5. **Multi-Tenancy**: Admins manage their own data in their own collection

## Testing

### Test Admin Profile Display
1. Login as admin
2. Navigate to Profile screen
3. Verify admin data is displayed correctly
4. Check browser console - should show: "Fetching from: admins/{adminUid}"

### Test Admin Profile Edit
1. Login as admin
2. Navigate to Profile screen
3. Click "Edit Profile"
4. Modify name, phone, or organization
5. Save changes
6. Check Firestore console:
   - Changes should be in `admins/{adminUid}` document
   - NOT in `users` collection

### Test Data Separation
1. Check Firestore console
2. Verify `admins` collection contains only admin documents
3. Verify `users` collection contains only resident documents
4. Verify no mixing of admin and resident data

## Firestore Structure

### Admins Collection
```
admins/
  {adminUid}/
    name: "John Admin"
    email: "admin@lyvo.com"
    phone: "+91 9876543210"
    organization: "LYVO Property Management"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    role: "admin"
    createdAt: Timestamp
    updatedAt: Timestamp
```

### Users Collection (Residents Only)
```
users/
  {residentUid}/
    name: "Jane Resident"
    email: "jane@example.com"
    phone: "+91 9876543211"
    residentId: "RES1234"
    role: "resident"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    adminId: "{adminUid}"
    adminName: "John Admin"
    flatId: "flat456"
    flatLabel: "A-101"
    createdAt: Timestamp
    updatedAt: Timestamp
```

## Notes

- Admin data is NEVER stored in the `users` collection
- Resident data is NEVER stored in the `admins` collection
- Each collection has its own security rules
- Admin UID from Firebase Auth is used as document ID in `admins` collection
- Resident UID from Firebase Auth is used as document ID in `users` collection
- The `role` field helps distinguish between different user types if needed
