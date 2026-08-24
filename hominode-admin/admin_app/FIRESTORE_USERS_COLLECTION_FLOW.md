# Firestore Users Collection - Complete Flow

## Overview
The `users` collection in Firestore is the single source of truth for all user data (residents, staff, vendors). Both the Admin App and Resident App use this same collection.

## Firestore Collection: `users`

### Collection Structure
```
Firestore Database
└── users (collection)
    ├── user_doc_1 (document)
    │   ├── name: "John Doe"
    │   ├── phone: "1234567890"
    │   ├── email: "john@example.com"
    │   ├── residentId: "RES1234"
    │   ├── authEmail: "RES1234@lyvo.com"
    │   ├── authUid: "firebase_auth_uid"
    │   ├── password: "aB3xY9Zk"
    │   ├── role: "resident"
    │   ├── flatId: "A101"
    │   ├── flatLabel: "A101"
    │   ├── ownershipType: "Owner"
    │   ├── familyMembers: 4
    │   ├── status: "active"
    │   ├── createdAt: Timestamp
    │   └── updatedAt: Timestamp
    ├── user_doc_2 (document)
    └── user_doc_3 (document)
```

## Complete Data Flow

### 1. Admin App - Create New Resident

**When Admin Creates New Resident:**
```
Admin App (Assign Resident Modal)
    ↓
UserService.createUser()
    ↓
1. Create Firebase Auth Account
   - Email: RES1234@lyvo.com
   - Password: Auto-generated
   - Display Name: Resident Name
    ↓
2. Store in Firestore 'users' collection
   - All user data
   - authEmail: RES1234@lyvo.com
   - authUid: Firebase Auth UID
   - password: For reference
   - role: "resident"
   - status: "active"
    ↓
3. Assign to Flat
   - flatId: "A101"
   - flatLabel: "A101"
   - ownershipType: "Owner"
    ↓
4. Update Flat Document
   - status: "occupied"
   - residentName: "John Doe"
   - residentId: user_doc_id
    ↓
5. Sync Building Occupancy
   - occupied count
   - occupancy rate
```

### 2. Admin App - Assign Existing Resident

**When Admin Assigns Existing Resident:**
```
Admin App (Assign Resident Modal)
    ↓
UserService.getAvailableUsers()
    ↓
Fetch from Firestore 'users' collection
    - WHERE role = "resident"
    - WHERE status = "active"
    - Real-time stream
    ↓
Display list of available residents
    ↓
Admin selects resident
    ↓
UserService.assignUserToFlat()
    ↓
Update Firestore 'users' collection
    - flatId: "A101"
    - flatLabel: "A101"
    - ownershipType: "Owner"
    ↓
Update 'flats' collection
    - status: "occupied"
    - residentName: from user data
    - residentId: user_doc_id
    ↓
Sync building occupancy
```

### 3. Resident App - Login

**When Resident Logs In:**
```
Resident App (Login Screen)
    ↓
Enter Phone/Resident ID + Password
    ↓
AuthService.signInWithPhone() OR
AuthService.signInWithResidentId()
    ↓
1. Query Firestore 'users' collection
   - WHERE phone = "1234567890" OR
   - WHERE residentId = "RES1234"
   - WHERE role = "resident"
    ↓
2. Get authEmail from user document
   - authEmail: "RES1234@lyvo.com"
    ↓
3. Authenticate with Firebase Auth
   - Email: RES1234@lyvo.com
   - Password: User entered password
    ↓
4. Login successful
   - User data available from Firestore
   - Auth state managed by Firebase
```

### 4. Resident App - Fetch User Data

**When Resident App Needs User Data:**
```
Resident App
    ↓
Get current Firebase Auth user
    ↓
Get authUid
    ↓
Query Firestore 'users' collection
    - WHERE authUid = current_user_uid
    OR
    - Direct document read if doc ID known
    ↓
Fetch user data:
    - name
    - phone
    - email
    - residentId
    - flatId
    - flatLabel
    - ownershipType
    - familyMembers
    - All other user data
    ↓
Display in Resident App
```

## Data Synchronization

### Admin App → Firestore → Resident App

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│  Admin App  │────────▶│  Firestore   │────────▶│ Resident App │
│             │  Write  │    users     │  Read   │              │
│ - Create    │         │  collection  │         │ - Login      │
│ - Assign    │         │              │         │ - View Data  │
│ - Update    │         │              │         │ - Update     │
└─────────────┘         └──────────────┘         └──────────────┘
                              ▲
                              │
                        Real-time sync
                              │
                              ▼
                    Both apps see same data
```

## Key Points

### ✅ Single Source of Truth
- **ONE** `users` collection in Firestore
- Admin App writes to it
- Resident App reads from it
- Both apps use the same data

### ✅ Real-time Synchronization
- Changes in Admin App instantly visible in Resident App
- StreamBuilder ensures real-time updates
- No data duplication

### ✅ Firebase Authentication Integration
- Every resident has a Firebase Auth account
- Auth email format: `RES1234@lyvo.com`
- Linked to Firestore via `authUid`
- Residents can login immediately after creation

### ✅ Data Flow
1. Admin creates resident → Stored in `users` collection
2. Resident logs in → Fetches from `users` collection
3. Admin updates resident → Updates `users` collection
4. Resident sees changes → Real-time from `users` collection

## Example Scenarios

### Scenario 1: New Resident Created by Admin

**Step 1: Admin Creates Resident**
```javascript
// Admin App calls
UserService.createUser({
  name: "John Doe",
  phone: "9876543210",
  residentId: "RES5678",
  password: "xY9kL2mN",
  email: "john@example.com",
  familyMembers: 3
})

// Firestore 'users' collection now has:
{
  id: "auto_generated_doc_id",
  name: "John Doe",
  phone: "9876543210",
  email: "john@example.com",
  residentId: "RES5678",
  authEmail: "RES5678@lyvo.com",
  authUid: "firebase_auth_uid_xyz",
  password: "xY9kL2mN",
  role: "resident",
  flatId: null,
  flatLabel: null,
  ownershipType: null,
  familyMembers: 3,
  status: "active",
  createdAt: Timestamp,
  updatedAt: Timestamp
}

// Firebase Authentication now has:
{
  uid: "firebase_auth_uid_xyz",
  email: "RES5678@lyvo.com",
  displayName: "John Doe"
}
```

**Step 2: Admin Assigns to Flat**
```javascript
// Admin App calls
UserService.assignUserToFlat({
  userId: "auto_generated_doc_id",
  flatId: "B205",
  flatLabel: "B205",
  ownershipType: "Tenant"
})

// Firestore 'users' collection updated:
{
  ...previous data,
  flatId: "B205",
  flatLabel: "B205",
  ownershipType: "Tenant",
  updatedAt: Timestamp (new)
}
```

**Step 3: Resident Logs In**
```javascript
// Resident App calls
AuthService.signInWithPhone("9876543210", "xY9kL2mN")

// Process:
1. Query Firestore: WHERE phone = "9876543210"
2. Get authEmail: "RES5678@lyvo.com"
3. Firebase Auth: signInWithEmailAndPassword("RES5678@lyvo.com", "xY9kL2mN")
4. Success! User logged in
5. Fetch user data from Firestore using authUid
6. Display in Resident App:
   - Name: John Doe
   - Flat: B205
   - Ownership: Tenant
   - Family Members: 3
```

### Scenario 2: Existing Resident Assigned to New Flat

**Step 1: Resident Already Exists**
```javascript
// Firestore 'users' collection has:
{
  id: "existing_user_id",
  name: "Jane Smith",
  phone: "1122334455",
  residentId: "RES9999",
  authEmail: "RES9999@lyvo.com",
  role: "resident",
  flatId: null,  // Not assigned yet
  status: "active"
}
```

**Step 2: Admin Assigns to Flat**
```javascript
// Admin App:
1. Opens Assign Resident Modal
2. Fetches available residents from 'users' collection
3. Sees "Jane Smith - RES9999 - Available"
4. Selects Jane Smith
5. Assigns to Flat C301

// UserService.assignUserToFlat() updates:
{
  ...previous data,
  flatId: "C301",
  flatLabel: "C301",
  ownershipType: "Owner",
  updatedAt: Timestamp (new)
}
```

**Step 3: Resident App Sees Update**
```javascript
// Resident App (if Jane is logged in):
- Real-time listener on 'users' collection
- Automatically receives update
- UI updates to show:
  - Flat: C301
  - Ownership: Owner
```

## Implementation Files

### Admin App Files:
- `lib/services/user_service.dart` - CRUD operations on `users` collection
- `lib/services/auth_service.dart` - Authentication with Firebase Auth
- `lib/manage_buildings_page.dart` - Assign resident flow
- `lib/widgets/assign_resident_modal.dart` - UI for assigning residents

### Resident App Files (to be implemented):
- `lib/services/user_service.dart` - Read operations on `users` collection
- `lib/services/auth_service.dart` - Login with phone/resident ID
- `lib/profile_screen.dart` - Display user data from Firestore
- `lib/home_screen.dart` - Show flat info from user data

## Security Rules (Recommended)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Admin can read/write all users
      allow read, write: if request.auth != null && 
                           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Residents can read their own data
      allow read: if request.auth != null && 
                     resource.data.authUid == request.auth.uid;
      
      // Residents can update their own profile (limited fields)
      allow update: if request.auth != null && 
                       resource.data.authUid == request.auth.uid &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['email', 'familyMembers', 'updatedAt']);
    }
  }
}
```

## Summary

✅ **Admin App**: Creates and manages users in `users` collection
✅ **Resident App**: Reads user data from same `users` collection  
✅ **Firebase Auth**: Provides authentication for all users
✅ **Real-time Sync**: Both apps see the same data instantly
✅ **Single Source**: No data duplication, one collection for all users
✅ **Complete Flow**: Create → Store → Authenticate → Fetch → Display

The system is fully integrated with Firestore `users` collection as the single source of truth!
