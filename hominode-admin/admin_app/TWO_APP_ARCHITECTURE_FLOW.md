# Two App Architecture - Complete Flow

## System Overview

The system consists of TWO separate Flutter applications sharing ONE Firebase/Firestore backend:

```
┌─────────────────────────────────────────────────────────────┐
│                    Firebase Backend                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Firestore Database                         │ │
│  │  - users (collection)                                   │ │
│  │  - buildings (collection)                               │ │
│  │  - flats (collection)                                   │ │
│  │  - complaints (collection)                              │ │
│  │  - visitors (collection)                                │ │
│  │  - announcements (collection)                           │ │
│  │  - etc...                                               │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Firebase Authentication                         │ │
│  │  - Admin accounts                                       │ │
│  │  - Resident accounts                                    │ │
│  │  - Staff accounts                                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ▲                    ▲
                    │                    │
        ┌───────────┴──────────┐    ┌───┴──────────────┐
        │                      │    │                   │
┌───────▼────────┐    ┌────────▼────────┐
│  RESIDENT APP  │    │   ADMIN APP     │
│                │    │                 │
│ - Register     │    │ - Manage        │
│ - Login        │    │   Buildings     │
│ - View Profile │    │ - Assign        │
│ - Complaints   │    │   Residents     │
│ - Visitors     │    │ - View All      │
│ - Announcements│    │   Residents     │
│ - Payments     │    │ - Manage        │
└────────────────┘    │   Complaints    │
                      │ - Manage Staff  │
                      │ - Analytics     │
                      └─────────────────┘
```

## App 1: RESIDENT APP

### Purpose
Residents use this app to:
- Register their account
- Login to their account
- View their profile and flat details
- Submit complaints
- Request visitor passes
- View announcements
- Make payments
- View bills

### Resident App Flow

#### 1. Registration Flow (Self-Registration)
```
Resident App - Registration Screen
    ↓
User enters:
    - Name
    - Phone Number
    - Email (optional)
    - Password
    - Flat Number (if known)
    ↓
Resident App calls Firebase
    ↓
1. Create Firebase Auth Account
   - Email: phone@lyvo.com OR actual email
   - Password: User chosen password
    ↓
2. Create Firestore Document in 'users' collection
   {
     name: "John Doe",
     phone: "9876543210",
     email: "john@example.com",
     authEmail: "9876543210@lyvo.com",
     authUid: "firebase_auth_uid",
     role: "resident",
     flatId: null,  // Not assigned yet
     flatLabel: null,
     ownershipType: null,
     status: "pending", // Waiting for admin approval
     createdAt: Timestamp,
     updatedAt: Timestamp
   }
    ↓
3. Registration Complete
   - User can login
   - Profile shows "Pending Flat Assignment"
   - Wait for admin to assign flat
```

#### 2. Login Flow
```
Resident App - Login Screen
    ↓
User enters:
    - Phone Number OR Email
    - Password
    ↓
AuthService.signInWithPhone() OR signInWithEmail()
    ↓
1. Query Firestore 'users' collection
   - WHERE phone = entered_phone OR email = entered_email
   - WHERE role = "resident"
    ↓
2. Get authEmail from user document
    ↓
3. Firebase Auth: signInWithEmailAndPassword()
    ↓
4. Login Successful
    ↓
5. Fetch user data from Firestore
    ↓
6. Navigate to Home Screen
```

#### 3. Profile Screen
```
Resident App - Profile Screen
    ↓
Fetch current user data from Firestore
    ↓
Display:
    - Name
    - Phone
    - Email
    - Resident ID (if assigned by admin)
    - Flat Number (if assigned)
    - Ownership Type (if assigned)
    - Family Members
    - Status (pending/active)
    ↓
If flatId is null:
    Show: "Waiting for flat assignment by admin"
Else:
    Show: "Flat: A101, Ownership: Owner"
```

#### 4. Submit Complaint
```
Resident App - Complaints Screen
    ↓
User fills form:
    - Title
    - Description
    - Category
    - Priority
    - Photo (optional)
    ↓
Create document in 'complaints' collection
    {
      residentId: current_user_id,
      residentName: "John Doe",
      flatId: "A101",
      flatLabel: "A101",
      title: "Water Leakage",
      description: "...",
      category: "Plumbing",
      priority: "High",
      status: "pending",
      createdAt: Timestamp
    }
    ↓
Admin App can now see this complaint
```

## App 2: ADMIN APP

### Purpose
Admin uses this app to:
- Manage buildings and flats
- View all registered residents
- Assign residents to flats
- Approve/reject resident registrations
- Manage complaints
- Manage staff and vendors
- View analytics

### Admin App Flow

#### 1. View All Residents
```
Admin App - Residents Screen
    ↓
Fetch from Firestore 'users' collection
    - WHERE role = "resident"
    - Real-time stream
    ↓
Display list:
    - Name
    - Phone
    - Resident ID
    - Flat (if assigned)
    - Status (pending/active)
    ↓
Admin can:
    - View details
    - Assign to flat
    - Edit information
    - Approve/reject
```

#### 2. Assign Resident to Flat (Existing Resident)
```
Admin App - Flat Occupancy Grid
    ↓
Click on vacant flat
    ↓
Flat Details Modal opens
    ↓
Click "Assign Resident"
    ↓
Assign Resident Modal opens
    ↓
Tab: "Select Existing"
    ↓
Fetch from Firestore 'users' collection
    - WHERE role = "resident"
    - WHERE status = "active" OR "pending"
    - WHERE flatId = null (not assigned)
    ↓
Display list of available residents
    (These are residents who registered via Resident App)
    ↓
Admin selects resident
    ↓
Admin chooses ownership type
    ↓
Click "Assign Resident"
    ↓
Update Firestore 'users' collection:
    {
      flatId: "A101",
      flatLabel: "A101",
      ownershipType: "Owner",
      status: "active",
      updatedAt: Timestamp
    }
    ↓
Update Firestore 'flats' collection:
    {
      status: "occupied",
      residentName: "John Doe",
      residentId: user_doc_id
    }
    ↓
Resident App automatically sees update
    (Real-time sync via StreamBuilder)
```

#### 3. Create New Resident (Admin Creates)
```
Admin App - Flat Occupancy Grid
    ↓
Click on vacant flat
    ↓
Flat Details Modal opens
    ↓
Click "Assign Resident"
    ↓
Assign Resident Modal opens
    ↓
Tab: "Add New"
    ↓
Admin fills form:
    - Name
    - Phone
    - Email (optional)
    - Family Members
    - Ownership Type
    ↓
System auto-generates:
    - Resident ID: RES1234
    - Password: aB3xY9Zk
    - Auth Email: RES1234@lyvo.com
    ↓
Click "Assign Resident"
    ↓
1. Create Firebase Auth Account
   - Email: RES1234@lyvo.com
   - Password: aB3xY9Zk
    ↓
2. Create Firestore 'users' document
   {
     name: "Jane Smith",
     phone: "1122334455",
     residentId: "RES1234",
     authEmail: "RES1234@lyvo.com",
     authUid: "firebase_auth_uid",
     password: "aB3xY9Zk",
     role: "resident",
     flatId: "A101",
     flatLabel: "A101",
     ownershipType: "Owner",
     status: "active",
     createdAt: Timestamp
   }
    ↓
3. Update 'flats' collection
    ↓
4. Send credentials to resident
   (SMS/Email with Resident ID and Password)
    ↓
Resident can now login to Resident App
```

## Data Synchronization Between Apps

### Scenario 1: Resident Registers → Admin Assigns

```
RESIDENT APP                    FIRESTORE                    ADMIN APP
     │                              │                             │
     │ 1. Register                  │                             │
     ├─────────────────────────────▶│                             │
     │   Create user document       │                             │
     │   status: "pending"          │                             │
     │   flatId: null               │                             │
     │                              │                             │
     │                              │ 2. Real-time sync           │
     │                              ├────────────────────────────▶│
     │                              │   New resident appears      │
     │                              │   in residents list         │
     │                              │                             │
     │                              │ 3. Admin assigns to flat    │
     │                              │◀────────────────────────────┤
     │                              │   Update user document      │
     │                              │   flatId: "A101"            │
     │                              │   status: "active"          │
     │                              │                             │
     │ 4. Real-time sync            │                             │
     │◀─────────────────────────────┤                             │
     │   Profile updates            │                             │
     │   Shows flat: A101           │                             │
     │                              │                             │
```

### Scenario 2: Admin Creates → Resident Logs In

```
ADMIN APP                       FIRESTORE                    RESIDENT APP
     │                              │                             │
     │ 1. Create new resident       │                             │
     ├─────────────────────────────▶│                             │
     │   Create user document       │                             │
     │   Create Firebase Auth       │                             │
     │   Assign to flat             │                             │
     │   status: "active"           │                             │
     │                              │                             │
     │ 2. Send credentials          │                             │
     │   (SMS/Email)                │                             │
     │                              │                             │
     │                              │ 3. Resident receives        │
     │                              │    credentials              │
     │                              │                             │
     │                              │ 4. Login with credentials   │
     │                              │◀────────────────────────────┤
     │                              │   Authenticate              │
     │                              │   Fetch user data           │
     │                              │                             │
     │                              │ 5. Show profile             │
     │                              ├────────────────────────────▶│
     │                              │   Name, Flat, etc.          │
     │                              │                             │
```

### Scenario 3: Resident Submits Complaint → Admin Views

```
RESIDENT APP                    FIRESTORE                    ADMIN APP
     │                              │                             │
     │ 1. Submit complaint          │                             │
     ├─────────────────────────────▶│                             │
     │   Create complaint doc       │                             │
     │   residentId: user_id        │                             │
     │   flatId: "A101"             │                             │
     │   status: "pending"          │                             │
     │                              │                             │
     │                              │ 2. Real-time sync           │
     │                              ├────────────────────────────▶│
     │                              │   New complaint appears     │
     │                              │   in complaints list        │
     │                              │                             │
     │                              │ 3. Admin assigns staff      │
     │                              │◀────────────────────────────┤
     │                              │   Update complaint          │
     │                              │   status: "in-progress"     │
     │                              │   assignedTo: staff_id      │
     │                              │                             │
     │ 4. Real-time sync            │                             │
     │◀─────────────────────────────┤                             │
     │   Complaint status updates   │                             │
     │   Shows: "In Progress"       │                             │
     │                              │                             │
```

## Shared Firestore Collections

### 1. users (collection)
**Used by:** Both apps
- **Resident App:** Creates during registration, reads for profile
- **Admin App:** Reads for resident list, updates for flat assignment

### 2. buildings (collection)
**Used by:** Admin App only
- **Admin App:** Creates, reads, updates, deletes buildings

### 3. flats (collection)
**Used by:** Both apps
- **Admin App:** Creates (auto-generated), updates (assign resident)
- **Resident App:** Reads (view flat details)

### 4. complaints (collection)
**Used by:** Both apps
- **Resident App:** Creates (submit complaint), reads (view status)
- **Admin App:** Reads (view all), updates (assign staff, change status)

### 5. visitors (collection)
**Used by:** Both apps
- **Resident App:** Creates (request visitor pass), reads (view visitors)
- **Admin App:** Reads (view all visitors), updates (approve/reject)

### 6. announcements (collection)
**Used by:** Both apps
- **Admin App:** Creates (post announcement)
- **Resident App:** Reads (view announcements)

### 7. payments (collection)
**Used by:** Both apps
- **Admin App:** Creates (generate bills)
- **Resident App:** Reads (view bills), updates (mark as paid)

## Implementation Status

### ✅ Admin App - IMPLEMENTED
- Firebase Authentication integration
- Firestore buildings, flats, users integration
- Create new resident with auto-generated credentials
- Assign existing resident to flat
- Real-time data synchronization
- Complete flat management flow

### 🔄 Resident App - TO BE IMPLEMENTED
- Registration screen
- Login screen (phone/email + password)
- Profile screen (fetch from Firestore users collection)
- Complaints screen (create in Firestore complaints collection)
- Visitors screen (create in Firestore visitors collection)
- Announcements screen (read from Firestore announcements collection)
- Payments screen (read from Firestore payments collection)

## Key Points

### ✅ Single Firebase Project
- Both apps connect to the SAME Firebase project
- Same Firestore database
- Same Authentication system
- Different app configurations (google-services.json)

### ✅ Shared Data Model
- Both apps use the same collection structure
- Both apps see the same data in real-time
- Changes in one app instantly visible in the other

### ✅ Role-Based Access
- Residents can only see their own data
- Admins can see all data
- Firestore security rules enforce access control

### ✅ Two Registration Methods
1. **Self-Registration (Resident App):**
   - Resident creates account
   - Status: "pending"
   - Waits for admin to assign flat

2. **Admin-Created (Admin App):**
   - Admin creates account with credentials
   - Status: "active"
   - Flat assigned immediately
   - Credentials sent to resident

## Next Steps

### For Admin App (Current):
✅ Already implemented correctly
✅ Fetches from Firestore users collection
✅ Creates new residents in Firestore
✅ Assigns residents to flats
✅ Real-time synchronization

### For Resident App (To Implement):
1. Create registration screen
2. Create login screen
3. Implement user service to read from Firestore
4. Create profile screen showing flat details
5. Implement complaints feature
6. Implement visitors feature
7. Implement announcements feature
8. Implement payments feature

The architecture is correctly designed with both apps sharing the same Firestore backend!
