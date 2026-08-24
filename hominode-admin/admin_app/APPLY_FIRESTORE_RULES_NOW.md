# Apply Firestore Rules Now - Quick Action Guide

## The Error You're Seeing
```
Failed to create and assign resident: Exception: Failed to create resident: 
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

## Why It's Happening
The Firestore security rules don't allow admins to create new resident documents. The rules need to be updated to use `request.resource.data` instead of `resource.data` for the create operation.

## How to Fix (5 Minutes)

### Step 1: Open Firebase Console
Go to: https://console.firebase.google.com

### Step 2: Select Your Project
Click on your project name

### Step 3: Open Firestore Rules
1. Click "Firestore Database" in the left menu
2. Click the "Rules" tab at the top

### Step 4: Copy the New Rules
Open this file: `admin_app/FIRESTORE_RULES_PRODUCTION.md`

Copy the entire rules block (starting from `rules_version = '2';` to the closing `}`)

### Step 5: Replace in Firebase Console
1. In Firebase Console, select ALL text in the rules editor (Ctrl+A or Cmd+A)
2. Delete it
3. Paste the new rules
4. Click "Publish"

### Step 6: Wait for Deployment
- Wait 1-2 minutes for the rules to be published
- You'll see "Rules updated successfully" at the bottom

### Step 7: Test
1. Go back to the admin app
2. Try creating a resident again
3. It should work now!

## What Changed
The key change is in the `create` operation for three collections:

**Before:**
```
allow create: if request.auth.uid != null;
```

**After:**
```
allow create: if request.auth.uid != null && 
               request.resource.data.adminId == request.auth.uid;
```

This ensures:
- Only authenticated admins can create documents
- The document must have their adminId
- Maintains security and tenant isolation

## If You Need Help
1. Check the Firebase Console for any error messages
2. Verify the rules syntax is correct (no red errors)
3. Make sure you're logged in as an admin
4. Try creating a resident again

## Status
✅ Rules are ready to apply
✅ No code changes needed
✅ Just update Firestore rules

**Time to fix**: ~5 minutes
