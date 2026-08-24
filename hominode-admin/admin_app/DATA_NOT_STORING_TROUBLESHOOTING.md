# Data Not Storing Properly - Troubleshooting Guide

## Issue
Data is not being stored properly in Firestore when creating residents or assigning them to flats.

## Quick Diagnostic Steps

### Step 1: Run the Diagnostic Tool

1. Add this import to your `main.dart` or any screen:
```dart
import 'debug_data_storage_screen.dart';
```

2. Navigate to the debug screen:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const DebugDataStorageScreen()),
);
```

3. Tap "Run Diagnostic" button
4. Check the console output for detailed information

### Step 2: Check Admin Profile

The most common issue is an incomplete admin profile.

**Check Firestore Console**:
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to `admins` collection
4. Find your admin document (use your admin ID)
5. Verify these fields exist and are NOT empty:
   - `name`
   - `email`
   - `phone`
   - `organization`
   - `buildingId` (optional but recommended)
   - `buildingName` (optional but recommended)

**If fields are missing or empty**:
```json
{
  "name": "Your Name",
  "email": "your@email.com",
  "phone": "1234567890",
  "organization": "Your Organization",
  "buildingId": "your-building-id",
  "buildingName": "Your Building Name"
}
```

### Step 3: Check Firestore Rules

Make sure your Firestore rules allow writing to the collections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
    
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }
    
    match /admins/{adminId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == adminId;
    }
  }
}
```

### Step 4: Check Console Logs

When creating a resident, check the console for these logs:

```
╔════════════════════════════════════════════════════════╗
║         CREATE USER - START                            ║
╚════════════════════════════════════════════════════════╝
```

Look for:
- ✅ "Admin details fetched"
- ✅ "Resident ID generated"
- ✅ "Firestore document created successfully"
- ✅ "Document verified in Firestore"

If you see ❌ errors, note the error message.

### Step 5: Manual Verification

After creating a resident:

1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to `users` collection
4. Find the newly created user document
5. Check if these fields exist:
   - ✅ `adminId`
   - ✅ `adminName`
   - ✅ `adminEmail`
   - ✅ `adminPhone`
   - ✅ `organization`
   - ✅ `buildingId`
   - ✅ `buildingName`

## Common Issues and Solutions

### Issue 1: Admin Profile is Empty

**Symptom**: Fields like `adminName`, `adminPhone`, `organization` are empty strings in user documents.

**Cause**: Admin profile in `admins` collection is incomplete.

**Solution**:
1. Open Firebase Console → Firestore
2. Go to `admins` collection
3. Find your admin document
4. Click "Edit" and add missing fields:
   ```
   name: "Your Name"
   email: "your@email.com"
   phone: "1234567890"
   organization: "Your Organization"
   ```
5. Save changes
6. Try creating a resident again

### Issue 2: buildingId/buildingName are null

**Symptom**: `buildingId` and `buildingName` are null in user documents.

**Cause**: Not passing building info when creating resident, and admin profile doesn't have it either.

**Solution**:
1. When creating resident from building management, ensure building info is passed
2. OR add `buildingId` and `buildingName` to admin profile
3. Check the code calls `createUser()` with buildingId and buildingName parameters

### Issue 3: Flat Assignment Not Working

**Symptom**: When assigning resident to flat, data doesn't update.

**Cause**: Missing parameters or Firestore rules blocking writes.

**Solution**:
1. Check console logs for errors
2. Verify Firestore rules allow writes to `users` and `flats` collections
3. Ensure `buildingId` and `buildingName` are passed to `assignUserToFlat()`

### Issue 4: residentId/residentName Not in Flats

**Symptom**: Flat document doesn't have `residentId` or `residentName` after assignment.

**Cause**: `assignUserToFlat()` method not updating flat document.

**Solution**:
1. Check if `assignUserToFlat()` is being called correctly
2. Verify the flat document exists in Firestore
3. Check Firestore rules allow updates to flats collection

## Testing Checklist

### Test 1: Create Resident
- [ ] Admin profile has complete data
- [ ] Run app and create a new resident
- [ ] Check console for success messages
- [ ] Open Firestore Console
- [ ] Verify user document has all required fields:
  - [ ] adminId
  - [ ] adminName
  - [ ] adminEmail
  - [ ] adminPhone
  - [ ] organization
  - [ ] buildingId
  - [ ] buildingName

### Test 2: Assign to Flat
- [ ] Create a resident (or use existing)
- [ ] Assign resident to a flat
- [ ] Check console for success messages
- [ ] Open Firestore Console
- [ ] Verify user document updated:
  - [ ] flatId
  - [ ] flatLabel
  - [ ] buildingId
  - [ ] buildingName
- [ ] Verify flat document updated:
  - [ ] residentId
  - [ ] residentName
  - [ ] residentUserId
  - [ ] status: "occupied"

## Debug Commands

### Check Admin Profile
```dart
final adminService = AdminService();
final adminId = adminService.getCurrentAdminId();
final profile = await adminService.getAdminProfile();
print('Admin ID: $adminId');
print('Admin Profile: $profile');
```

### Check User Document
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('User data: ${userDoc.data()}');
```

### Check Flat Document
```dart
final flatDoc = await FirebaseFirestore.instance
    .collection('flats')
    .doc(flatId)
    .get();
print('Flat data: ${flatDoc.data()}');
```

## Still Not Working?

If data is still not storing after following all steps:

1. **Run the diagnostic tool** (see Step 1 above)
2. **Check console output** for specific error messages
3. **Verify Firestore rules** are not blocking writes
4. **Check network connectivity** - ensure device can reach Firebase
5. **Try creating data manually** in Firestore Console to verify rules work
6. **Check Firebase project** - ensure you're connected to the correct project

## Expected Console Output (Success)

When everything works correctly, you should see:

```
╔════════════════════════════════════════════════════════╗
║         CREATE USER - START                            ║
╚════════════════════════════════════════════════════════╝
Input parameters:
  - Name: John Doe
  - Phone: 1234567890
  - BuildingId: abc123
  - BuildingName: Tower A

[Step 1] Admin details fetched
   AdminId: xyz789
   AdminName: Admin Name
   Organization: My Organization

[Step 5] Creating Firestore document with admin and building details...
  adminId: xyz789
  adminName: Admin Name
  adminEmail: admin@example.com
  adminPhone: 9876543210
  organization: My Organization
  buildingId: abc123
  buildingName: Tower A

✅ Firestore document created successfully!

[Step 6] Verifying document...
✅ Document verified in Firestore
   adminId: xyz789
   buildingId: abc123
   buildingName: Tower A

╔════════════════════════════════════════════════════════╗
║         CREATE USER - SUCCESS                          ║
╚════════════════════════════════════════════════════════╝
```

## Contact Support

If you've tried everything and it's still not working, provide:
1. Console output from diagnostic tool
2. Screenshot of admin document in Firestore
3. Screenshot of user document in Firestore
4. Any error messages from console
