# Admin Profile from Users Collection - Complete ✅

## Overview

Admin profile details are now fetched from and saved to the `users` Firestore collection, keeping all user data (admins and residents) in one centralized location. This follows the flow function requirement for unified data management.

## Changes Made

### 1. Edit Profile Modal (`lib/widgets/edit_profile_modal.dart`)
- Changed from `admins` collection to `users` collection
- Fetches admin data from `users/{userId}`
- Saves admin data to `users/{userId}`
- Maintains role conversion for dropdown compatibility

### 2. Profile Screen (`lib/profile_screen.dart`)
- Added real-time data fetching from Firestore
- Displays actual user name, email, and role from `users` collection
- Auto-refreshes after profile edit
- Added loading state management

## Firestore Structure

All users (admins and residents) are stored in the same collection:

```
users/
  └── {userId}/
      ├── name: string
      ├── email: string
      ├── phone: string
      ├── role: string (admin, super_admin, manager, staff, resident)
      ├── organization: string (for admins only)
      ├── residentId: string (for residents only)
      ├── flatId: string (for residents only)
      ├── buildingId: string (for residents only)
      ├── authEmail: string (for residents only)
      ├── createdAt: timestamp
      └── updatedAt: timestamp
```

## Data Flow

### Loading Profile
```
User opens Profile screen
    ↓
Get Firebase Auth user
    ↓
Fetch from users/{userId}
    ↓
Display name, email, role
    ↓
User sees their profile
```

### Editing Profile
```
User clicks "Edit Profile"
    ↓
Modal opens
    ↓
Fetch current data from users/{userId}
    ↓
User makes changes
    ↓
Save to users/{userId}
    ↓
Profile screen refreshes
    ↓
Updated data displayed
```

## Role Differentiation

Users are differentiated by the `role` field:

| Role | Type | Has Organization | Has Flat/Building |
|------|------|------------------|-------------------|
| super_admin | Admin | Yes | No |
| admin | Admin | Yes | No |
| manager | Admin | Yes | No |
| staff | Admin | Yes | No |
| resident | Resident | No | Yes |

## Benefits

### 1. Unified Data Management
- All users in one collection
- Easier to query and manage
- Consistent data structure

### 2. Simplified Architecture
- No need for separate collections
- Reduced complexity
- Single source of truth

### 3. Easy Role-Based Access
- Filter by role field
- Simple queries for admins vs residents
- Flexible permission management

### 4. Better Scalability
- Can add new roles easily
- Support for multiple admin types
- Extensible structure

## Code Examples

### Fetch Admin Profile
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

if (userDoc.exists) {
  final data = userDoc.data()!;
  String name = data['name'];
  String email = data['email'];
  String role = data['role']; // admin, super_admin, etc.
}
```

### Update Admin Profile
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .set({
  'name': 'Admin Name',
  'email': 'admin@example.com',
  'phone': '+91 1234567890',
  'organization': 'My Society',
  'role': 'super_admin',
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

### Query All Admins
```dart
final adminsSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('role', whereIn: ['admin', 'super_admin', 'manager', 'staff'])
    .get();
```

### Query All Residents
```dart
final residentsSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'resident')
    .get();
```

## Firestore Security Rules

Update your rules to handle both admins and residents:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - for both admins and residents
    match /users/{userId} {
      // Users can read their own data
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Users can update their own data
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Admins can read all users
      allow read: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in 
        ['admin', 'super_admin', 'manager'];
      
      // Only admins can create new users
      allow create: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in 
        ['admin', 'super_admin'];
    }
  }
}
```

## Testing Guide

### Test 1: View Profile
1. Login as admin
2. Navigate to Profile screen
3. ✅ Should display real name from Firestore
4. ✅ Should display real email
5. ✅ Should display formatted role

### Test 2: Edit Profile
1. Click "Edit Profile"
2. Change name to "Test Admin"
3. Change phone number
4. Click "Save Changes"
5. ✅ Should save to `users` collection
6. ✅ Profile screen should refresh
7. ✅ Should display "Test Admin"

### Test 3: Verify Firestore
1. Edit profile and save
2. Open Firebase Console
3. Go to Firestore → `users` collection
4. Find document with your userId
5. ✅ Should see updated fields
6. ✅ Should have `role` field (admin, super_admin, etc.)
7. ✅ Should have `organization` field

### Test 4: Role Display
Test with different roles:
1. Set role to "super_admin" in Firestore
2. Refresh app
3. ✅ Should display "Super Admin"
4. Set role to "manager"
5. ✅ Should display "Manager"

### Test 5: Data Persistence
1. Edit profile
2. Close app completely
3. Reopen app
4. Navigate to Profile
5. ✅ Should show updated data
6. ✅ Data persists across sessions

## Profile Screen Features

### Real-Time Data Display
- Name from Firestore
- Email from Firestore
- Role from Firestore (formatted)
- Auto-refresh after edit

### Loading States
- Shows loading while fetching data
- Graceful error handling
- Default values if no data

### Auto-Refresh
- Refreshes after editing profile
- Ensures UI stays in sync
- No manual refresh needed

## Files Modified

1. **lib/widgets/edit_profile_modal.dart**
   - Changed collection from `admins` to `users`
   - Updated `_loadUserData()` method
   - Updated `_saveProfile()` method
   - Maintains role conversion functions

2. **lib/profile_screen.dart**
   - Added Firebase imports
   - Added state variables for user data
   - Added `_loadUserData()` method
   - Added `_formatRole()` helper
   - Updated profile header to display real data
   - Added auto-refresh after edit

## Migration Notes

If you have existing admin data in a separate `admins` collection:

1. **No migration needed** if starting fresh
2. **If migrating**: Copy admin documents from `admins` to `users` collection
3. Ensure `role` field is set correctly (admin, super_admin, etc.)
4. Add `organization` field for admin users
5. Delete old `admins` collection after verification

## Status: ✅ COMPLETE

Admin profile details are now properly fetched from and saved to the `users` Firestore collection, providing unified data management for all users according to the flow function requirements.
