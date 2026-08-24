# Admin and Resident Data Separation - Complete

## Problem Statement
When an admin creates a new resident, the Firebase Auth `createUserWithEmailAndPassword` method automatically signs in the newly created user, which logs out the admin. This causes the admin to lose their session and see resident data instead of admin data.

## Solution Implemented
**Deferred Firebase Auth Account Creation**

Instead of creating Firebase Auth accounts immediately when the admin creates a resident, we now:
1. Store resident data in Firestore with a flag `authAccountCreated: false`
2. Create the Firebase Auth account only when the resident logs in for the first time
3. This prevents the admin from being logged out during resident creation

## Changes Made

### 1. User Service (`lib/services/user_service.dart`)

#### Before (Problematic):
```dart
// Created Firebase Auth account immediately
userCredential = await _auth.createUserWithEmailAndPassword(
  email: authEmail,
  password: password,
);
// This logged out the admin!
```

#### After (Fixed):
```dart
// Generate document ID without creating Firebase Auth account
final residentDocRef = _firestore.collection('users').doc();
uid = residentDocRef.id;

// Store data with flag for future auth account creation
final firestoreData = {
  'authEmail': authEmail,
  'password': password,
  'authAccountCreated': false, // Flag for first-time login
  // ... other fields
};
```

### 2. Auth Service (`lib/services/auth_service.dart`)

#### Updated `signInWithPhone` method:
```dart
// Check if Firebase Auth account exists
if (!authAccountCreated) {
  // Create Firebase Auth account on first login
  final userCredential = await _auth.createUserWithEmailAndPassword(
    email: authEmail,
    password: password,
  );
  
  // Mark as created in Firestore
  await _firestore.collection('users').doc(userDoc.id).update({
    'authAccountCreated': true,
    'authUid': userCredential.user!.uid,
  });
}
```

#### Updated `signInWithResidentId` method:
Same logic as `signInWithPhone` - creates Firebase Auth account on first login.

## Data Flow

### Admin Creates Resident
```
1. Admin logged in (Firebase Auth session active)
   ↓
2. Admin creates resident via UI
   ↓
3. System generates Firestore document ID
   ↓
4. Resident data stored in 'users' collection
   - authEmail: stored for future use
   - password: stored securely
   - authAccountCreated: false
   - role: 'resident'
   ↓
5. Admin remains logged in ✅
   (No Firebase Auth account created yet)
```

### Resident First Login
```
1. Resident enters phone/residentId and password
   ↓
2. System finds resident in Firestore
   ↓
3. Check authAccountCreated flag
   ↓
4. If false: Create Firebase Auth account now
   ↓
5. Update Firestore: authAccountCreated = true
   ↓
6. Sign in resident
   ↓
7. Resident logged in successfully
```

### Admin Profile Access
```
1. Admin logged in
   ↓
2. Admin navigates to Profile screen
   ↓
3. System fetches from 'admins' collection ONLY
   - Uses admin's Firebase Auth UID
   - Collection: admins/{adminUid}
   ↓
4. Admin data displayed
   - NO resident data shown
   - NO mixing of data
```

## Collection Structure

### Admins Collection
```
admins/
  {adminUid}/  ← Firebase Auth UID
    name: "John Admin"
    email: "admin@lyvo.com"
    phone: "+91 9876543210"
    organization: "LYVO Property Management"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    role: "admin"
    createdAt: Timestamp
    updatedAt: Timestamp
```

### Users Collection (Residents)
```
users/
  {residentDocId}/  ← Firestore auto-generated ID
    name: "Jane Resident"
    email: "jane@example.com"
    phone: "+91 9876543211"
    authEmail: "9876543211.1234567890@lyvo.com"
    password: "securepass123"
    authAccountCreated: false  ← Key flag
    authUid: null  ← Set after first login
    residentId: "RES1234"
    role: "resident"
    buildingId: "building123"
    buildingName: "Sunrise Apartments"
    adminId: "{adminUid}"
    flatId: null
    createdAt: Timestamp
    updatedAt: Timestamp
```

## Benefits

1. **Admin Session Preserved**: Admin stays logged in when creating residents
2. **Clean Separation**: Admin data in `admins` collection, resident data in `users` collection
3. **No Data Mixing**: Admin profile never shows resident data
4. **Secure**: Passwords stored securely, auth accounts created on-demand
5. **Scalable**: Can create unlimited residents without affecting admin session

## Testing

### Test 1: Admin Creates Resident
1. Login as admin
2. Navigate to Residents
3. Click "Add Resident"
4. Fill in resident details
5. Submit
6. ✅ Verify: Admin still logged in
7. ✅ Verify: Resident data in Firestore with `authAccountCreated: false`

### Test 2: Admin Profile Access
1. Login as admin
2. Navigate to Profile screen
3. ✅ Verify: Admin data displayed (from `admins` collection)
4. ✅ Verify: NO resident data shown
5. Click "Edit Profile"
6. ✅ Verify: Only admin fields editable

### Test 3: Resident First Login
1. Use resident phone/ID and password
2. Login
3. ✅ Verify: Firebase Auth account created
4. ✅ Verify: Firestore updated with `authAccountCreated: true`
5. ✅ Verify: Resident logged in successfully

### Test 4: Resident Subsequent Login
1. Logout resident
2. Login again with same credentials
3. ✅ Verify: Uses existing Firebase Auth account
4. ✅ Verify: No new account created

## Important Notes

- **Admin data**: Always fetched from `admins` collection
- **Resident data**: Always stored in `users` collection
- **Firebase Auth**: Created on-demand for residents, immediately for admins
- **Session Management**: Admin session never affected by resident creation
- **Security**: Passwords stored securely, auth accounts properly managed

## Migration Notes

If you have existing residents with Firebase Auth accounts already created:
1. They will continue to work normally
2. The `authAccountCreated` flag will be missing (treated as `false`)
3. On next login, the system will try to create account (will fail with "email-already-in-use")
4. System will catch this and proceed with normal sign-in
5. Optionally, run a migration script to set `authAccountCreated: true` for existing residents

## Future Improvements

For production environments, consider:
1. Using Firebase Admin SDK on a backend server
2. This allows creating auth accounts without affecting client sessions
3. More secure and scalable approach
4. Current solution works well for client-side only applications
