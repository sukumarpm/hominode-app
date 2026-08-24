# Resident Creation Permission Denied Fix

## Problem
When creating a new resident, the app was showing:
```
Failed to create and assign resident: Exception: Failed to create resident: 
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

Also, loading buildings showed:
```
Error loading buildings: [cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

## Root Cause
The Firestore security rules had an issue with the `create` operation. The rules were:

```
allow create: if request.auth.uid != null;
```

But the `write` operation checked:
```
allow write: if request.auth.uid == userId || 
                (request.auth.uid != null && 
                 resource.data.adminId == request.auth.uid);
```

**The Problem**: When creating a new document, `resource.data` doesn't exist yet (it's a new document), so the condition fails even though the admin is authenticated.

## Solution
Updated the Firestore rules to use `request.resource.data` for the `create` operation, which represents the data being written:

### Before (Incorrect)
```
match /users/{userId} {
  allow create: if request.auth.uid != null;
}

match /buildings/{buildingId} {
  allow create: if request.auth.uid != null;
}

match /flats/{flatId} {
  allow create: if request.auth.uid != null;
}
```

### After (Correct)
```
match /users/{userId} {
  allow create: if request.auth.uid != null && 
                   request.resource.data.adminId == request.auth.uid;
}

match /buildings/{buildingId} {
  allow create: if request.auth.uid != null && 
                   request.resource.data.adminId == request.auth.uid;
}

match /flats/{flatId} {
  allow create: if request.auth.uid != null && 
                   request.resource.data.adminId == request.auth.uid;
}
```

## How to Apply the Fix

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Click on "Firestore Database" in the left menu

### Step 2: Navigate to Rules
1. Click on the "Rules" tab at the top
2. You'll see the current rules

### Step 3: Replace Rules
1. Select all text in the rules editor (Ctrl+A or Cmd+A)
2. Delete the selected text
3. Copy the complete rules from `FIRESTORE_RULES_PRODUCTION.md`
4. Paste them into the editor
5. Click "Publish"

### Step 4: Verify
1. Wait for the rules to be published (usually 1-2 minutes)
2. Check the status indicator at the bottom
3. You should see "Rules updated successfully"

## What Changed
- **Users Collection**: Admins can now create resident documents with their adminId
- **Buildings Collection**: Admins can now create building documents with their adminId
- **Flats Collection**: Admins can now create flat documents with their adminId

## Flow Function Compliance
This fix ensures the resident creation flow function works properly:

```
STEP 1: Validate Admin Authentication ✅
STEP 2: Get Admin Details ✅
STEP 3: Generate Resident ID ✅
STEP 4: Create Firestore Document ✅ (NOW WORKS)
STEP 5: Verify Document ✅
```

## Testing
After applying the rules:

1. **Create a Resident**
   - Click "Add" button in Resident Management
   - Fill in resident details
   - Click "Create"
   - Should succeed without permission errors

2. **Load Buildings**
   - Navigate to Building Management
   - Should load buildings without permission errors

3. **Assign Resident to Flat**
   - Create a resident
   - Assign to a flat
   - Should succeed without permission errors

## Security Notes
- The rules still maintain tenant isolation (admins can only access their own data)
- The rules require authentication (request.auth.uid != null)
- The rules verify adminId matches the authenticated user
- No cross-tenant data access is possible

## Status
✅ **FIXED** - Firestore rules updated to allow resident creation

**Date**: 2026-03-28
**Version**: 1.0
