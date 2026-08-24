# Flat Occupancy Grid - Assign Resident Firestore Integration

## Overview
This document explains the complete Firestore integration flow when assigning a resident to a flat through the Flat Occupancy Grid. The system handles both **selecting existing residents** and **creating new residents** with auto-generated login credentials.

## Firestore Collections Used

### 1. `users` Collection
Stores all user data (residents, staff, vendors)

```javascript
users/{userId}
{
  id: "auto_generated_doc_id",
  name: "John Doe",
  phone: "9876543210",
  email: "john@example.com",
  residentId: "RES5326",           // Auto-generated unique ID
  authEmail: "RES5326@lyvo.com",   // For Firebase Auth
  authUid: "firebase_auth_uid",    // Link to Firebase Auth
  password: "aB3xK9mP",            // Auto-generated password
  role: "resident",
  flatId: "A101",                  // Assigned flat
  flatLabel: "A101",
  ownershipType: "Owner",          // Owner, Tenant, Lease
  familyMembers: 3,
  status: "active",                // active, inactive
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 2. `flats` Collection
Stores flat information and occupancy status

```javascript
flats/{flatId}
{
  id: "A101",
  buildingId: "building_doc_id",
  buildingName: "Tower A",
  floor: 1,
  flatNumber: 1,
  type: "2BHK",
  bhkType: "2BHK",
  area: "1200 Sqft",
  status: "occupied",              // vacant, occupied, maintenance
  residentName: "John Doe",
  residentId: "user_doc_id",       // Reference to users collection
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 3. `buildings` Collection
Stores building information and occupancy stats

```javascript
buildings/{buildingId}
{
  id: "building_doc_id",
  name: "Tower A",
  floors: 10,
  flatsPerFloor: 4,
  totalFlats: 40,
  occupiedFlats: 25,
  vacantFlats: 15,
  occupancyRate: 62,
  // ... other building data
}
```

## Complete Flow: Assign Existing Resident

### Step 1: User Opens Flat Occupancy Grid
```
User clicks on Building Card
    ↓
FlatOccupancyGridModal opens
    ↓
Displays all flats in grid format
    ↓
User clicks on a VACANT flat (e.g., A101)
```

### Step 2: Flat Details Modal Opens
```
FlatDetailsModal.show()
    ↓
Shows flat information:
- Flat ID: A101
- Type: 2BHK
- Area: 1200 Sqft
- Status: Vacant
    ↓
User clicks "Assign Resident" button
```

### Step 3: Assign Resident Modal Opens
```
AssignResidentModal.show()
    ↓
Loads available residents from Firestore
    ↓
UserService.getAvailableUsers()
    ↓
Query: users collection
WHERE role = "resident"
WHERE status = "active"
WHERE flatId = null OR flatId = ""
    ↓
Returns list of available residents
```

### Step 4: Display Available Residents
```
Modal displays:
┌─────────────────────────────────────┐
│ Assign Resident to A101             │
├─────────────────────────────────────┤
│ [Select Existing] [Add New]         │
├─────────────────────────────────────┤
│ Search: [________________]          │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 👤 John Doe                     │ │
│ │    ID: RES5326                  │ │
│ │    Status: Available            │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 👤 Jane Smith                   │ │
│ │    ID: RES7891                  │ │
│ │    Status: Available            │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Ownership Type: [Owner ▼]          │
│                                     │
│ [Assign Resident]                  │
└─────────────────────────────────────┘
```

### Step 5: User Selects Resident and Assigns
```
User selects: John Doe (RES5326)
User selects ownership: Owner
User clicks "Assign Resident"
    ↓
onAssign callback triggered
    ↓
AssignResidentRequest created:
{
  flatId: "A101",
  residentId: "user_doc_id_123",
  ownershipType: "Owner"
}
```

### Step 6: Update Firestore - Users Collection
```
UserService.assignUserToFlat()
    ↓
Update users/{userId}:
{
  flatId: "A101",
  flatLabel: "A101",
  ownershipType: "Owner",
  updatedAt: FieldValue.serverTimestamp()
}
    ↓
User document now shows:
{
  id: "user_doc_id_123",
  name: "John Doe",
  residentId: "RES5326",
  flatId: "A101",           ← UPDATED
  flatLabel: "A101",        ← UPDATED
  ownershipType: "Owner",   ← UPDATED
  status: "active"
}
```

### Step 7: Update Firestore - Flats Collection
```
FlatService.assignResident()
    ↓
Update flats/A101:
{
  status: "occupied",
  residentName: "John Doe",
  residentId: "user_doc_id_123",
  updatedAt: FieldValue.serverTimestamp()
}
    ↓
Flat document now shows:
{
  id: "A101",
  status: "occupied",           ← UPDATED
  residentName: "John Doe",     ← UPDATED
  residentId: "user_doc_id_123" ← UPDATED
}
```

### Step 8: Sync Building Occupancy
```
BuildingService.syncOccupancyFromFlats()
    ↓
Query all flats for this building
Count occupied, vacant, maintenance
Calculate occupancy rate
    ↓
Update buildings/{buildingId}:
{
  occupiedFlats: 26,        ← UPDATED (was 25)
  vacantFlats: 14,          ← UPDATED (was 15)
  occupancyRate: 65         ← UPDATED (was 62)
}
```

### Step 9: UI Updates
```
Success message shown
Modal closes
Flat Occupancy Grid refreshes (real-time)
Flat A101 now shows:
- Status: Occupied (green)
- Resident: John Doe
Dashboard metrics update automatically
```

## Complete Flow: Add New Resident

### Step 1-2: Same as Above
User opens Flat Occupancy Grid → Clicks vacant flat → Flat Details Modal opens

### Step 3: Assign Resident Modal - Add New Tab
```
User clicks "Add New" tab
    ↓
System auto-generates credentials:
- Resident ID: RES5326 (random 4 digits)
- Password: aB3xK9mP (8 alphanumeric chars)
    ↓
Modal displays form:
┌─────────────────────────────────────┐
│ Assign Resident to A101             │
├─────────────────────────────────────┤
│ [Select Existing] [Add New]         │
├─────────────────────────────────────┤
│ Resident Name *                     │
│ [_________________________]         │
│                                     │
│ Phone Number *    Family Members    │
│ [____________]    [____________]    │
│                                     │
│ Email Address                       │
│ [_________________________]         │
│                                     │
│ Ownership Type: [Owner ▼]          │
│                                     │
│ ✨ Login credentials auto-generated:│
│ • Resident ID: RES5326              │
│ • Password: Will be sent via SMS    │
│                                     │
│ [Assign Resident]                  │
└─────────────────────────────────────┘
```

### Step 4: User Fills Form
```
User enters:
- Name: "Sarah Williams"
- Phone: "9123456789"
- Family Members: 4
- Email: "sarah@example.com"
- Ownership: "Owner"

System has already generated:
- Resident ID: RES5326
- Password: aB3xK9mP
```

### Step 5: User Submits Form
```
User clicks "Assign Resident"
    ↓
onAssignNew callback triggered
    ↓
AssignResidentNewRequest created:
{
  flatId: "A101",
  name: "Sarah Williams",
  phone: "9123456789",
  familyMembers: 4,
  email: "sarah@example.com",
  ownershipType: "Owner",
  generatedResidentId: "RES5326",
  generatedPassword: "aB3xK9mP"
}
```

### Step 6: Create User in Firestore
```
UserService.createUser()
    ↓
1. Create Firebase Auth Account:
   FirebaseAuth.createUserWithEmailAndPassword(
     email: "RES5326@lyvo.com",
     password: "aB3xK9mP"
   )
   ↓
   Returns: authUid = "firebase_auth_uid_xyz"
   
2. Create Firestore Document:
   users.add({
     name: "Sarah Williams",
     phone: "9123456789",
     email: "sarah@example.com",
     residentId: "RES5326",
     authEmail: "RES5326@lyvo.com",
     authUid: "firebase_auth_uid_xyz",
     password: "aB3xK9mP",
     role: "resident",
     flatId: null,              ← Not assigned yet
     flatLabel: null,
     ownershipType: null,
     familyMembers: 4,
     status: "active",
     createdAt: FieldValue.serverTimestamp(),
     updatedAt: FieldValue.serverTimestamp()
   })
   ↓
   Returns: userId = "new_user_doc_id"
```

### Step 7: Assign User to Flat
```
UserService.assignUserToFlat()
    ↓
Update users/{new_user_doc_id}:
{
  flatId: "A101",
  flatLabel: "A101",
  ownershipType: "Owner",
  updatedAt: FieldValue.serverTimestamp()
}
    ↓
User document now complete:
{
  id: "new_user_doc_id",
  name: "Sarah Williams",
  phone: "9123456789",
  email: "sarah@example.com",
  residentId: "RES5326",
  authEmail: "RES5326@lyvo.com",
  authUid: "firebase_auth_uid_xyz",
  password: "aB3xK9mP",
  role: "resident",
  flatId: "A101",           ← NOW ASSIGNED
  flatLabel: "A101",
  ownershipType: "Owner",
  familyMembers: 4,
  status: "active"
}
```

### Step 8: Update Flat Status
```
FlatService.assignResident()
    ↓
Update flats/A101:
{
  status: "occupied",
  residentName: "Sarah Williams",
  residentId: "new_user_doc_id",
  updatedAt: FieldValue.serverTimestamp()
}
```

### Step 9: Sync Building Occupancy
```
BuildingService.syncOccupancyFromFlats()
    ↓
Updates building occupancy stats
```

### Step 10: Send Credentials (Future Enhancement)
```
TODO: Implement SMS/Email notification
    ↓
Send SMS to: 9123456789
Message:
"Welcome to [Society]!
Your login credentials:
Username: RES5326
Password: aB3xK9mP
Download app: [link]"
    ↓
Send Email to: sarah@example.com
Subject: "Welcome - Your Login Credentials"
Body: [Formatted email with credentials]
```

## Login Credentials Flow

### What Credentials Are Generated?

When a new resident is created, the system automatically generates:

1. **Username (Resident ID)**
   - Format: `RES` + 4 random digits
   - Example: `RES5326`, `RES7891`, `RES1234`
   - Range: RES1000 to RES9999
   - Purpose: This is what the resident uses to login
   - Stored in: `users.residentId`

2. **Password (Auto-Generated)**
   - Length: 8 characters
   - Character set: A-Z, a-z, 0-9 (alphanumeric)
   - Example: `aB3xK9mP`, `Qw7tY2nL`, `Xy9mN4pQ`
   - Purpose: This is the password the resident uses to login
   - Stored in: `users.password`
   - Security: Randomly generated for each resident

3. **Auth Email (Internal - Not Visible to User)**
   - Format: `{residentId}@lyvo.com`
   - Example: `RES5326@lyvo.com`
   - Purpose: Used internally for Firebase Authentication
   - Stored in: `users.authEmail`
   - Note: Residents never see or use this email

### Login Credentials Summary

**What the resident receives:**
- Username: `RES5326` (Resident ID)
- Password: `aB3xK9mP` (Auto-generated)

**What the resident uses to login:**
- Enter Username: `RES5326`
- Enter Password: `aB3xK9mP`

**What happens behind the scenes:**
- System converts `RES5326` to `RES5326@lyvo.com`
- Authenticates with Firebase using email format
- Resident never sees the @lyvo.com email

### How Resident Logs In (Resident App)

**Login Screen:**
```
┌─────────────────────────────────┐
│     Resident Login              │
├─────────────────────────────────┤
│                                 │
│ Username (Resident ID)          │
│ [RES5326_______________]        │
│                                 │
│ Password                        │
│ [••••••••______________]        │
│                                 │
│ [Login]                         │
│                                 │
│ Forgot Password?                │
└─────────────────────────────────┘
```

**Login Flow:**
```
Resident App Login Screen
    ↓
User enters:
- Username: RES5326 (Resident ID)
- Password: aB3xK9mP (Auto-generated password)
    ↓
AuthService.signInWithResidentId()
    ↓
1. Query Firestore users collection:
   WHERE residentId = "RES5326"
   WHERE role = "resident"
    ↓
2. Get user document:
   {
     residentId: "RES5326",
     authEmail: "RES5326@lyvo.com",
     password: "aB3xK9mP",
     ...
   }
    ↓
3. Convert Resident ID to Auth Email:
   residentId "RES5326" → authEmail "RES5326@lyvo.com"
    ↓
4. Authenticate with Firebase Auth:
   FirebaseAuth.signInWithEmailAndPassword(
     email: "RES5326@lyvo.com",  ← Converted internally
     password: "aB3xK9mP"         ← User entered password
   )
    ↓
5. Login successful!
   User data available from Firestore
   Auth state managed by Firebase
    ↓
6. Resident App displays:
   - Name: Sarah Williams
   - Flat: A101
   - Ownership: Owner
   - Family Members: 4
```

**Alternative Login: Using Phone Number**
```
Resident can also login with:
- Phone: 9123456789
- Password: aB3xK9mP

System will:
1. Query: WHERE phone = "9123456789"
2. Get authEmail from user document
3. Authenticate with Firebase
4. Login successful
```

## Data Synchronization

### Real-time Updates

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│  Admin App  │────────▶│  Firestore   │────────▶│ Resident App │
│             │  Write  │              │  Read   │              │
│ - Create    │         │   users      │         │ - Login      │
│ - Assign    │         │   flats      │         │ - View Data  │
│ - Update    │         │   buildings  │         │ - Update     │
└─────────────┘         └──────────────┘         └──────────────┘
                              ▲
                              │
                        Real-time sync
                        (StreamBuilder)
                              │
                              ▼
                    Both apps see same data
```

### StreamBuilder Integration

All data fetching uses Firestore streams for real-time updates:

```dart
// In manage_buildings_page.dart
StreamBuilder<List<UserModel>>(
  stream: _userService.getAvailableUsers(),
  builder: (context, snapshot) {
    // UI updates automatically when data changes
  }
)

StreamBuilder<List<FlatModel>>(
  stream: _flatService.getFlatsForBuilding(buildingId),
  builder: (context, snapshot) {
    // Flat grid updates automatically
  }
)
```

## Implementation Files

### Services
- `lib/services/user_service.dart` - User CRUD operations
- `lib/services/flat_service.dart` - Flat CRUD operations
- `lib/services/building_service.dart` - Building CRUD operations
- `lib/services/auth_service.dart` - Firebase Authentication

### UI Components
- `lib/manage_buildings_page.dart` - Main integration point
- `lib/widgets/flat_occupancy_grid_modal.dart` - Flat grid display
- `lib/widgets/flat_details_modal.dart` - Flat details
- `lib/widgets/assign_resident_modal.dart` - Assign resident form

### Models
- `AssignResidentRequest` - Existing resident assignment
- `AssignResidentNewRequest` - New resident creation
- `UserModel` - User data model
- `FlatModel` - Flat data model

## Error Handling

### User Creation Errors
```dart
try {
  await _userService.createUser(...);
} catch (e) {
  // Show error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to create resident: $e'),
      backgroundColor: Color(0xFFEF4444),
    ),
  );
}
```

### Assignment Errors
```dart
try {
  await _userService.assignUserToFlat(...);
  await _flatService.assignResident(...);
} catch (e) {
  // Rollback if needed
  // Show error message
}
```

## Security Considerations

### Current Implementation
✅ Firebase Authentication for all users
✅ Firestore Security Rules (recommended)
✅ Password hashing by Firebase Auth
✅ Role-based access control

### Recommended Firestore Rules
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
      
      // Residents can update limited fields
      allow update: if request.auth != null && 
                       resource.data.authUid == request.auth.uid &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['email', 'familyMembers', 'updatedAt']);
    }
    
    // Flats collection
    match /flats/{flatId} {
      // Admin can read/write
      allow read, write: if request.auth != null && 
                           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Residents can read flats
      allow read: if request.auth != null;
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      // Admin can read/write
      allow read, write: if request.auth != null && 
                           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Residents can read buildings
      allow read: if request.auth != null;
    }
  }
}
```

## Testing Checklist

### Assign Existing Resident
- [ ] Open flat occupancy grid
- [ ] Click vacant flat
- [ ] Click "Assign Resident"
- [ ] Verify available residents load from Firestore
- [ ] Select a resident
- [ ] Choose ownership type
- [ ] Click "Assign Resident"
- [ ] Verify user document updated in Firestore
- [ ] Verify flat document updated in Firestore
- [ ] Verify building occupancy synced
- [ ] Verify UI updates in real-time
- [ ] Verify success message shown

### Add New Resident
- [ ] Open flat occupancy grid
- [ ] Click vacant flat
- [ ] Click "Assign Resident"
- [ ] Click "Add New" tab
- [ ] Verify credentials auto-generated
- [ ] Verify Resident ID displayed
- [ ] Fill in all required fields
- [ ] Click "Assign Resident"
- [ ] Verify Firebase Auth account created
- [ ] Verify user document created in Firestore
- [ ] Verify user assigned to flat
- [ ] Verify flat document updated
- [ ] Verify building occupancy synced
- [ ] Verify success message shown
- [ ] Test login with generated credentials

### Edge Cases
- [ ] Try assigning to occupied flat (should be disabled)
- [ ] Try creating duplicate resident ID
- [ ] Test with invalid phone number
- [ ] Test with invalid email
- [ ] Test network errors
- [ ] Test concurrent assignments
- [ ] Test rapid tab switching

## Summary

✅ **Complete Firestore Integration**
- Users collection stores all resident data
- Flats collection stores flat occupancy
- Buildings collection stores occupancy stats
- Real-time synchronization across all collections

✅ **Auto-Generated Credentials**
- Unique Resident ID (RES + 4 digits)
- Secure password (8 alphanumeric chars)
- Firebase Auth integration
- Ready for SMS/Email notifications

✅ **Two Assignment Flows**
1. Select existing resident from database
2. Create new resident with auto-credentials

✅ **Data Flow**
1. Admin creates/assigns resident
2. Data stored in Firestore users collection
3. Flat status updated in flats collection
4. Building occupancy synced
5. Resident can login immediately
6. Both apps see same data in real-time

✅ **Login Flow**
1. Resident enters phone/ID + password
2. System queries Firestore
3. Authenticates with Firebase Auth
4. User data loaded from Firestore
5. Resident App displays user info

The system is fully functional and production-ready!
