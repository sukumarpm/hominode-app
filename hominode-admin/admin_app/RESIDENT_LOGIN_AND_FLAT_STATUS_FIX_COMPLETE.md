# Resident Login & Flat Status Update - Complete Fix

## Issues Fixed

### Issue 1: Flat Status Update Error
**Error**: "Failed to update flat status: [cloud_firestore/not-found] Some requested document was not found"

**Root Cause**: The code was using the sequential flat ID (e.g., "T001") as the Firestore document ID when updating the flat status.

**Solution**: Updated `updateFlatStatus()` method to query for the flat using the `flatId` field before updating.

### Issue 2: Resident Login Failure
**Error**: "Login failed. Please check your connection and try again."

**Root Cause**: Firestore rules don't allow residents to read their own user documents because:
- Residents are created with auto-generated Firestore document IDs
- Each resident has an `authUid` field (Firebase Auth UID) that's different from the document ID
- Current rules check `request.auth.uid == userId` (document ID), but should check `request.auth.uid == resource.data.authUid`

**Solution**: Update Firestore rules to check the `authUid` field instead of the document ID.

## Changes Made

### 1. Fixed Flat Service (flat_service.dart)

**Updated `updateFlatStatus()` method:**
```dart
Future<void> updateFlatStatus({
  required String flatId,  // Sequential ID (T001, A101, etc.)
  required String status,
  String? residentName,
  String? residentId,
}) async {
  // Query for the flat document using flatId field
  final flatQuery = await _firestore
      .collection(_collection)
      .where('flatId', isEqualTo: flatId)
      .limit(1)
      .get();
  
  if (flatQuery.docs.isEmpty) {
    throw Exception('Flat not found. Please ensure the flat exists in the system.');
  }
  
  final flatDocRef = flatQuery.docs.first.reference;
  
  // Update using the correct Firestore document reference
  await flatDocRef.update({
    'status': status,
    'residentName': residentName,
    'residentId': residentId,
    'residentUserId': residentId,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

### 2. Updated Firestore Rules

**Key Change in Users Collection:**

**Before:**
```firestore
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

**After:**
```firestore
match /users/{userId} {
  allow read: if request.auth.uid == resource.data.authUid;
  allow write: if request.auth.uid == resource.data.authUid;
}
```

## Flow Function: Resident Login

### STEP 1: Resident Enters Credentials
- Email/Phone + Password
- Or Resident ID + Password

### STEP 2: Auth Service Queries Firestore
- Finds resident document by phone/email/residentId
- Retrieves `authEmail` and `authUid` fields

### STEP 3: Firebase Auth Login
- Creates Firebase Auth account on first login (if not exists)
- Signs in with email + password
- Returns Firebase Auth UID

### STEP 4: Firestore Rules Check
- Resident tries to read their user document
- Rule checks: `request.auth.uid == resource.data.authUid`
- ✅ Access granted (auth UID matches authUid field)

### STEP 5: Resident Logged In
- Resident can now access their profile and data
- All subsequent reads/writes use the same auth UID

## Flow Function: Flat Status Update

### STEP 1: Admin Changes Flat Status
- Admin clicks on flat and changes status (Vacant → Occupied, etc.)

### STEP 2: Query for Flat Document
- Use sequential ID (T001, A101) to query
- Find the Firestore document with matching `flatId` field

### STEP 3: Update Flat Document
- Use the correct Firestore document reference
- Update status, resident info, timestamps

### STEP 4: Sync Building Occupancy
- Update building occupancy stats
- Reflect changes in UI

## Testing Checklist

### Flat Status Update
- [ ] Create a building with flats
- [ ] Create a resident
- [ ] Assign resident to flat (status changes to Occupied)
- [ ] Verify no "not-found" error
- [ ] Verify occupancy rate updates

### Resident Login
- [ ] Create a resident through admin app
- [ ] Note the email and password
- [ ] Logout from admin account
- [ ] Try to login as resident with email + password
- [ ] Verify login succeeds
- [ ] Verify resident can see their profile

## Deployment Steps

### 1. Update Firestore Rules
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules**
4. Replace all content with rules from `FIRESTORE_RULES_RESIDENT_LOGIN_FIX.md`
5. Click **Publish**
6. Wait for deployment (1-2 minutes)

### 2. Rebuild App
```bash
flutter clean
flutter pub get
flutter run
```

### 3. Test
- Test flat status updates
- Test resident login

## Key Insights

### Document ID vs Sequential ID
- **Firestore Document ID**: Auto-generated unique identifier (e.g., `abc123xyz`)
- **Sequential ID**: User-friendly identifier (e.g., `T001`, `A101`)
- **Firebase Auth UID**: Unique identifier for authenticated user (e.g., `auth_xyz789`)

Always use the correct ID for the operation:
- **Firestore Updates**: Use Firestore document ID or query by field
- **User Display**: Use sequential ID
- **Auth Operations**: Use Firebase Auth UID

### Firestore Rules Best Practices
- Check `resource.data.fieldName` instead of document ID when field values differ
- Use `request.auth.uid` for authenticated user checks
- Always validate that the authenticated user has permission to access the data

## Related Documentation

- `admin_app/RESIDENT_ASSIGNMENT_FIX_FIRESTORE_DOCID.md` - Resident assignment fix
- `admin_app/FIRESTORE_RULES_RESIDENT_LOGIN_FIX.md` - Detailed Firestore rules
- `admin_app/lib/services/auth_service.dart` - Resident login implementation
- `admin_app/lib/services/flat_service.dart` - Flat management
- `admin_app/lib/services/user_service.dart` - User management
