# Select Existing - Fetch Issue Debug Guide

## Issue
When opening "Assign Resident" modal and selecting "Select Existing" tab, residents are not being fetched from Firestore.

## Expected Console Logs

When the modal opens, you should see:

```
🟡 FlatDetailsModal: Opening AssignResidentModal
   - FlatId: A-101
   - Has UserService: true
   - Has FlatService: true
   - Has BuildingService: true
   - BuildingId: xyz123

🟡 AssignResidentModal: _loadResidents() called
   - widget.loadResidents is null: false

🔵 Starting to load residents from Firestore...
🔵 Calling widget.loadResidents()...

🔵 loadResidents callback triggered

╔════════════════════════════════════════════════════════╗
║         GET AVAILABLE USERS - START                    ║
╚════════════════════════════════════════════════════════╝
Collection: users
Query: WHERE role = "resident"

[Snapshot Received]
Total documents: 3

Processing documents...
  Document abc123:
    Name: John Doe
    FlatId: null
    Available: true
  Document def456:
    Name: Jane Smith
    FlatId: A-102
    Available: false
  Document ghi789:
    Name: Bob Wilson
    FlatId: null
    Available: true

✅ Available residents: 2
   - John Doe (1234567890) - Status: active
   - Bob Wilson (9876543210) - Status: active

🔵 Fetched 2 users from Firestore
   - John Doe (RES-001) - Available
   - Bob Wilson (RES-003) - Available

✅ Loaded 2 residents successfully
✅ State updated with residents
```

## Troubleshooting Steps

### 1. Check if Services are Passed
Look for this log when opening the modal:
```
🟡 FlatDetailsModal: Opening AssignResidentModal
   - Has UserService: true  <-- Should be TRUE
```

If `Has UserService: false`, the services are not being passed from `manage_buildings_page.dart`.

### 2. Check if loadResidents Callback is Null
Look for this log:
```
🟡 AssignResidentModal: _loadResidents() called
   - widget.loadResidents is null: false  <-- Should be FALSE
```

If it shows `true`, the callback is not being passed to the modal.

### 3. Check Firestore Data
If the callback is working but no residents show:
```
[Snapshot Received]
Total documents: 0
⚠️  No residents found in Firestore!
```

This means:
- No residents have been created yet in Firestore
- Create a resident first using "Add New" tab
- Then try "Select Existing" again

### 4. Check Firestore Rules
If you see permission errors:
```
❌ Error loading residents: [firebase_auth/permission-denied]
```

Update Firestore rules to allow read access:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 5. Check Available vs Assigned
The query filters for available residents (not assigned to any flat):
```
Processing documents...
  Document abc123:
    Name: John Doe
    FlatId: null        <-- Available (no flat assigned)
    Available: true
  Document def456:
    Name: Jane Smith
    FlatId: A-102       <-- Not available (already assigned)
    Available: false
```

If all residents are already assigned, you'll see:
```
✅ Available residents: 0
```

## Quick Fix Commands

### Test the Flow
1. Run the app:
```bash
flutter run -d <device>
```

2. Navigate: Manage Buildings → Grid Icon → Vacant Flat → Assign Resident

3. Watch console for the logs above

### Create Test Data
If no residents exist, create one first:
1. Click "Add New" tab
2. Fill in details
3. Click "Assign Resident"
4. Then try "Select Existing" on another flat

## Files Involved
- `admin_app/lib/widgets/flat_details_modal.dart` - Passes services and loadResidents callback
- `admin_app/lib/widgets/assign_resident_modal.dart` - Calls loadResidents in initState
- `admin_app/lib/services/user_service.dart` - getAvailableUsers() method
- `admin_app/lib/manage_buildings_page.dart` - Passes services to FlatDetailsModal

## Status
✅ Code updated with comprehensive logging
⏳ Waiting for console output to diagnose issue
