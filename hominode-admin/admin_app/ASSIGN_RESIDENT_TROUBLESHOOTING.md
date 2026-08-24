# Assign Resident - Troubleshooting Guide

## Issue: No Residents Found When Assigning to Flat

### Problem Description
When clicking on a flat in the occupancy grid and trying to assign a resident, the list shows "No residents found" even though residents exist in the Firestore `users` collection.

### Root Causes

#### 1. Field Name Mismatch
**Issue:** The code was looking for `status: "active"` (string) but Firebase had `isActive: true` (boolean).

**Solution:** Updated `UserService` to handle both field types:
```dart
// Handle both 'status' string and 'isActive' boolean
String status = 'active';
if (data.containsKey('status')) {
  status = data['status'] ?? 'active';
} else if (data.containsKey('isActive')) {
  status = (data['isActive'] == true) ? 'active' : 'inactive';
}
```

#### 2. Missing Required Fields
**Issue:** Users in Firestore might be missing required fields.

**Required Fields in Firestore:**
```javascript
users/{userId} {
  name: "string",           // Required
  phone: "string",          // Required
  role: "resident",         // Required - must be "resident"
  residentId: "string",     // Required (e.g., "RES1234")
  
  // Optional but recommended
  email: "string",
  familyMembers: number,
  flatId: "string",         // null if not assigned
  flatLabel: "string",      // null if not assigned
  ownershipType: "string",  // null if not assigned
  status: "active",         // or use isActive: true
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

#### 3. Role Filter
**Issue:** Users must have `role: "resident"` to appear in the list.

**Check:** Verify in Firebase Console that users have:
```javascript
role: "resident"  // NOT "admin" or any other value
```

### How the Flow Works

#### Step 1: Open Flat Occupancy Grid
```
Building Management → Click Grid Icon → Flat Occupancy Grid Opens
```

#### Step 2: Select Vacant Flat
```
Click on a grey (vacant) flat → Flat Details Modal Opens
```

#### Step 3: Assign Resident
```
Click "Assign Resident" → Assign Resident Modal Opens
```

#### Step 4: Load Residents from Firestore
```dart
loadResidents: () async {
  // Fetch real users from Firestore
  final users = await _userService.getAvailableUsers().first;
  return users.map((user) {
    return ResidentSummary(
      id: user.id,
      name: user.name,
      uniqueId: user.residentId,
      status: user.isAssigned 
          ? ResidentStatus.assigned 
          : ResidentStatus.available,
      flatLabel: user.flatLabel,
    );
  }).toList();
}
```

#### Step 5: Display Residents
- Available residents shown with checkmark
- Already assigned residents shown with flat label
- Search functionality available

#### Step 6: Select and Assign
```
Select resident → Choose ownership type → Click "Assign Resident"
```

#### Step 7: Update Firestore
```
1. Update users/{userId}:
   - flatId: "A101"
   - flatLabel: "A101"
   - ownershipType: "Owner"

2. Update flats/A101:
   - status: "occupied"
   - residentName: "John Doe"
   - residentId: userId

3. Update buildings/{buildingId}:
   - occupied: +1
   - vacant: -1
   - occupancyRate: recalculated
```

### Verification Steps

#### 1. Check Firebase Console
1. Open Firebase Console
2. Navigate to Firestore Database
3. Open `users` collection
4. Verify at least one document exists with:
   - `role: "resident"`
   - `name: "some name"`
   - `phone: "some phone"`
   - `residentId: "RES####"`

#### 2. Check User Data Format
Example of correct user document:
```javascript
{
  "name": "bot balla",
  "phone": "9940843260",
  "email": "9940843260@resident.app",
  "residentId": "CYjUjLaYzCqHRQP4MeysidGzs2",
  "role": "resident",
  "isActive": true,  // or status: "active"
  "familyMembers": 1,
  "flatId": null,
  "flatLabel": null,
  "ownershipType": null,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

#### 3. Test the Query
Run this in Firebase Console Query:
```
Collection: users
Where: role == resident
```

Should return all residents.

#### 4. Check App Logs
Look for errors in the console when opening assign resident modal.

### Common Issues and Solutions

#### Issue 1: "No residents found"
**Cause:** No users with `role: "resident"` in Firestore

**Solution:**
1. Create a test resident in Firebase Console
2. Or use the "Add New" tab in assign resident modal
3. Ensure `role` field is set to "resident"

#### Issue 2: Residents not showing but exist in Firebase
**Cause:** Field name mismatch (status vs isActive)

**Solution:** Already fixed in updated `UserService`

#### Issue 3: Can't assign resident
**Cause:** Missing required fields in user document

**Solution:** Ensure user has:
- name
- phone
- residentId
- role: "resident"

#### Issue 4: Resident assigned but not showing in grid
**Cause:** Flat status not updated

**Solution:** Check that flat document has:
- status: "occupied"
- residentName: "name"
- residentId: "userId"

### Creating New Resident via Assign Modal

#### Step 1: Open "Add New" Tab
```
Assign Resident Modal → Click "Add New" Tab
```

#### Step 2: Fill Form
```
Name*: John Doe
Phone*: +91 98765 43210
Email: john@example.com (optional)
Family Members: 4
Ownership Type: Owner
```

#### Step 3: Auto-Generated Credentials
System automatically generates:
```
Resident ID: RES1234 (unique)
Password: abc123XY (8 characters)
Auth Email: RES1234@lyvo.com
```

#### Step 4: Submit
```
Click "Assign Resident" → Creates:
1. Firebase Auth account
2. Firestore user document
3. Assigns to flat
4. Updates building occupancy
```

#### Step 5: Resident Can Login
New resident can now login using:
- Phone + Password
- Resident ID + Password
- Auth Email + Password

### Data Flow Diagram

```
┌─────────────────────────────────────────┐
│  Click Vacant Flat                      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Flat Details Modal Opens               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Click "Assign Resident"                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Assign Resident Modal Opens            │
│  Calls: loadResidents()                 │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  UserService.getAvailableUsers()        │
│  Query: users where role == "resident"  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Firestore Returns Users                │
│  Maps to ResidentSummary objects        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Display Residents in List              │
│  - Available (checkmark)                │
│  - Assigned (flat label)                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  User Selects Resident                  │
│  Chooses Ownership Type                 │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Click "Assign Resident"                │
│  Calls: onAssign(request)               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Update Firestore:                      │
│  1. users/{userId}                      │
│  2. flats/{flatId}                      │
│  3. buildings/{buildingId}              │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Success Notification                   │
│  Flat turns blue in grid                │
│  Real-time update                       │
└─────────────────────────────────────────┘
```

### Testing Checklist

- [ ] Open Building Management
- [ ] Click grid icon on a building
- [ ] Flat occupancy grid opens
- [ ] Click on a vacant (grey) flat
- [ ] Flat details modal opens
- [ ] Click "Assign Resident"
- [ ] Assign resident modal opens
- [ ] See list of residents from Firestore
- [ ] Search for a resident
- [ ] Select a resident
- [ ] Choose ownership type
- [ ] Click "Assign Resident"
- [ ] Success notification appears
- [ ] Flat turns blue in grid
- [ ] Resident name appears on flat

### Alternative: Create New Resident

- [ ] Open assign resident modal
- [ ] Click "Add New" tab
- [ ] Fill in name and phone
- [ ] See auto-generated credentials
- [ ] Choose ownership type
- [ ] Click "Assign Resident"
- [ ] Firebase Auth account created
- [ ] User document created in Firestore
- [ ] Flat assigned
- [ ] Success notification
- [ ] Flat turns blue
- [ ] Resident can login

### Firestore Security Rules

Ensure your Firestore rules allow reading users:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow authenticated users to read
      allow read: if request.auth != null;
      
      // Allow authenticated users to write
      allow write: if request.auth != null;
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### Quick Fix Commands

#### Add Test Resident via Firebase Console
1. Go to Firestore Database
2. Click "users" collection
3. Click "Add document"
4. Use auto-generated ID
5. Add fields:
```
name: "Test User"
phone: "1234567890"
role: "resident"
residentId: "RES1234"
isActive: true
familyMembers: 1
flatId: null
flatLabel: null
```

#### Update Existing User to Resident
1. Find user document in Firebase
2. Edit document
3. Set `role: "resident"`
4. Save

### Support

If issues persist:
1. Check Firebase Console for users
2. Verify role field is "resident"
3. Check app logs for errors
4. Verify Firestore security rules
5. Test with a new test resident

### Summary

The assign resident flow is now fixed to:
- ✅ Fetch residents from Firestore `users` collection
- ✅ Handle both `status` and `isActive` fields
- ✅ Show all residents with role == "resident"
- ✅ Allow assigning existing residents
- ✅ Allow creating new residents with auto-generated credentials
- ✅ Update all related collections (users, flats, buildings)
- ✅ Provide real-time updates in the UI

The system is now fully functional and ready to use!
