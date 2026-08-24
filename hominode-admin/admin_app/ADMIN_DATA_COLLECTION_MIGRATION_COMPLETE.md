# Admin Data Collection Migration - Complete

## Overview
Migrated all admin profile data fetching and storage from `users` collection to `admins` collection. This implements proper data separation between admins and residents according to the multi-tenancy architecture.

## Changes Made

### 1. Edit Profile Modal (`lib/widgets/edit_profile_modal.dart`)

#### Data Fetching
```dart
// BEFORE: Fetched from 'users' collection
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(_userId)
    .get();

// AFTER: Fetches from 'admins' collection
final userDoc = await FirebaseFirestore.instance
    .collection('admins')
    .doc(_userId)
    .get();
```

#### Data Saving
```dart
// BEFORE: Saved to 'users' collection
await FirebaseFirestore.instance
    .collection('users')
    .doc(_userId)
    .set({...}, SetOptions(merge: true));

// AFTER: Saves to 'admins' collection
await FirebaseFirestore.instance
    .collection('admins')
    .doc(_userId)
    .set({...}, SetOptions(merge: true));
```

### 2. Dashboard (`lib/admin_dashboard_page.dart`)

#### Admin Data Loading
```dart
// BEFORE: Fetched from 'users' collection
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();

// AFTER: Fetches from 'admins' collection
final userDoc = await FirebaseFirestore.instance
    .collection('admins')
    .doc(user.uid)
    .get();
```

### 3. Profile Screen (`lib/profile_screen.dart`)

#### User Data Loading
```dart
// BEFORE: Fetched from 'users' collection
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();

// AFTER: Fetches from 'admins' collection
final userDoc = await FirebaseFirestore.instance
    .collection('admins')
    .doc(user.uid)
    .get();
```

## Data Architecture

### Collection Structure

#### `admins` Collection (Admin Data)
```javascript
{
  "uid": "admin_firebase_auth_uid",
  "name": "Admin Name",
  "email": "admin@example.com",
  "phone": "1234567890",
  "organization": "Harmony Heights",
  "role": "admin",  // or "super_admin", "manager", "staff"
  "buildingIds": ["building_id_1", "building_id_2"],  // For multi-tenancy
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

#### `users` Collection (Resident Data)
```javascript
{
  "uid": "resident_firebase_auth_uid",
  "name": "Resident Name",
  "email": "resident@example.com",
  "phone": "9876543210",
  "residentId": "RES1234",
  "authEmail": "RES1234@lyvo.com",
  "authUid": "firebase_auth_uid",
  "password": "generated_password",
  "role": "resident",
  "flatId": "A101",
  "flatLabel": "A101",
  "ownershipType": "Owner",
  "familyMembers": 4,
  "status": "active",
  "buildingId": "building_id",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

## Data Flow

### Admin Profile Edit Flow
```
Admin opens Edit Profile
    ↓
Fetch from 'admins' collection
    - Document ID: Firebase Auth UID
    - Fields: name, email, phone, organization
    ↓
Display in form
    ↓
Admin updates fields
    ↓
Save to 'admins' collection
    - Document ID: Firebase Auth UID
    - Update: name, email, phone, organization, updatedAt
    ↓
Success message
```

### Dashboard Data Flow
```
Dashboard loads
    ↓
Fetch admin data from 'admins' collection
    - Document ID: Firebase Auth UID
    - Fields: name, role, organization
    ↓
Display in header:
    - Welcome back, {name}
    - Building: {organization}
    - Role badge
```

### Profile Screen Data Flow
```
Profile screen loads
    ↓
Fetch admin data from 'admins' collection
    - Document ID: Firebase Auth UID
    - Fields: name, email, role
    ↓
Display profile information
```

## Benefits of Separation

### ✅ Data Isolation
- Admin data stored separately from resident data
- Clear separation of concerns
- Easier to manage permissions

### ✅ Multi-Tenancy Support
- Each admin has their own profile in `admins` collection
- `buildingIds` array links admins to their buildings
- Admins can only access data from their buildings

### ✅ Security
- Firestore rules can enforce admin-only access to `admins` collection
- Residents cannot access admin data
- Admins cannot access other admins' data (unless super admin)

### ✅ Scalability
- Support unlimited admins
- Each admin manages their own properties
- Easy to add/remove admin access

### ✅ Flexibility
- Different data structures for admins vs residents
- Admin-specific fields (organization, buildingIds)
- Resident-specific fields (flatId, residentId, ownershipType)

## Files Updated

1. `admin_app/lib/widgets/edit_profile_modal.dart`
   - Changed data fetch from `users` to `admins`
   - Changed data save from `users` to `admins`

2. `admin_app/lib/admin_dashboard_page.dart`
   - Changed admin data fetch from `users` to `admins`
   - Displays organization name from `admins` collection

3. `admin_app/lib/profile_screen.dart`
   - Changed user data fetch from `users` to `admins`
   - Displays admin profile from `admins` collection

## Testing Checklist

### Profile Edit Tests
- [ ] Open edit profile modal
- [ ] Verify data loads from `admins` collection
- [ ] Update name, email, phone, organization
- [ ] Save changes
- [ ] Verify data saved to `admins` collection
- [ ] Check Firestore console to confirm

### Dashboard Tests
- [ ] Login as admin
- [ ] Verify admin name displays correctly
- [ ] Verify organization/building name displays correctly
- [ ] Check data is fetched from `admins` collection

### Profile Screen Tests
- [ ] Navigate to profile screen
- [ ] Verify admin name displays correctly
- [ ] Verify email displays correctly
- [ ] Verify role displays correctly
- [ ] Check data is fetched from `admins` collection

### Data Verification
- [ ] Check Firestore console
- [ ] Verify `admins` collection exists
- [ ] Verify admin document has correct structure
- [ ] Verify `users` collection only has residents

## Migration Steps (If Needed)

If you have existing admin data in `users` collection, run this migration:

```dart
Future<void> migrateAdminDataToAdminsCollection() async {
  final firestore = FirebaseFirestore.instance;
  
  // 1. Get all admin users from 'users' collection
  final adminsSnapshot = await firestore
      .collection('users')
      .where('role', whereIn: ['admin', 'super_admin', 'manager', 'staff'])
      .get();
  
  print('Found ${adminsSnapshot.docs.length} admins to migrate');
  
  // 2. Copy each admin to 'admins' collection
  for (var doc in adminsSnapshot.docs) {
    final data = doc.data();
    
    await firestore
        .collection('admins')
        .doc(doc.id)  // Use same document ID (Firebase Auth UID)
        .set({
      'name': data['name'] ?? 'Admin User',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'organization': data['organization'] ?? 'LYVO Property Management',
      'role': data['role'] ?? 'admin',
      'buildingIds': [],  // Initialize empty, will be populated later
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('Migrated admin: ${data['name']} (${doc.id})');
  }
  
  print('Migration complete!');
}
```

## Firestore Security Rules

Update your security rules to enforce data separation:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null && 
             exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Helper function to get admin's building IDs
    function getAdminBuildingIds() {
      return get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.buildingIds;
    }
    
    // Admins collection - Admin profiles
    match /admins/{adminId} {
      // Admins can read their own profile
      allow read: if request.auth != null && request.auth.uid == adminId;
      
      // Admins can update their own profile (limited fields)
      allow update: if request.auth != null && 
                       request.auth.uid == adminId &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['name', 'email', 'phone', 'organization', 'updatedAt']);
      
      // Only super admins can create/delete admin accounts
      allow create, delete: if request.auth != null && 
                               get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'super_admin';
    }
    
    // Users collection - Resident profiles
    match /users/{userId} {
      // Admins can read residents from their buildings
      allow read: if isAdmin() && 
                     resource.data.buildingId in getAdminBuildingIds();
      
      // Residents can read their own profile
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Admins can create/update residents in their buildings
      allow create, update: if isAdmin() && 
                               request.resource.data.buildingId in getAdminBuildingIds();
      
      // Residents can update their own profile (limited fields)
      allow update: if request.auth != null && 
                       request.auth.uid == userId &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['email', 'phone', 'familyMembers', 'updatedAt']);
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      allow read: if isAdmin() && buildingId in getAdminBuildingIds();
      allow write: if isAdmin() && buildingId in getAdminBuildingIds();
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read, write: if isAdmin() && 
                            resource.data.buildingId in getAdminBuildingIds();
    }
  }
}
```

## Next Steps

### 1. Data Migration (If Needed)
- Run migration script to copy admin data from `users` to `admins` collection
- Verify all admin data is correctly migrated
- Test login and profile functionality

### 2. Building Association
- Implement building creation with admin association
- Add `buildingIds` array to admin documents
- Link existing buildings to admins

### 3. Multi-Tenancy Implementation
- Use `AdminService` to filter data by buildings
- Update all queries to respect building boundaries
- Test data isolation between admins

### 4. Security Rules
- Deploy updated Firestore security rules
- Test access control
- Verify data isolation

## Status: ✅ COMPLETE

All admin profile screens now fetch and save data to the `admins` collection instead of the `users` collection. This implements proper data separation and prepares the app for full multi-tenancy support.

## Related Documentation
- `ADMIN_BUILDING_MULTI_TENANCY_IMPLEMENTATION.md` - Full multi-tenancy guide
- `ADMIN_BUILDING_ASSOCIATION_ARCHITECTURE.md` - Building association architecture
- `FIRESTORE_USERS_COLLECTION_FLOW.md` - Resident data flow (users collection)
- `DASHBOARD_BUILDING_NAME_DISPLAY_COMPLETE.md` - Dashboard building name display
