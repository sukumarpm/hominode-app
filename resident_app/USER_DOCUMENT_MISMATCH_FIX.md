# User Document Mismatch - Root Cause & Solution

## The Real Problem

Your app has a **data mismatch** between Firebase Authentication and Firestore:

### Current Situation:
```
Firebase Auth User:
- UID: DzmaLniSoUP0YxMWEwp8omFMiV12
- Email: preethampriyatharson07@gmail.com
- Status: Logged in ✅

Firestore Document:
- Document ID: WCfPPKTkuJ81amozcos
- Email: preethampr@thanson07@gmail.com (different!)
- Name: Preetham
- Phone: 7010678124
- Flat: b201
```

**The logged-in user's UID doesn't match any document in Firestore!**

## Why This Happened

This typically occurs when:
1. User was created in Firebase Auth but not in Firestore
2. User registered with a different email than what's in Firestore
3. Manual data entry in Firebase Console with wrong UID
4. Registration flow didn't complete properly

## Solution Options

### Option 1: Login with the Correct Account (RECOMMENDED)

The Firestore document belongs to a user with email `preethampr@thanson07@gmail.com`. You need to:

1. **Logout** from current account
2. **Login** with: `preethampr@thanson07@gmail.com`
3. The app will fetch data from document `WCfPPKTkuJ81amozcos`
4. Edit Profile will work correctly

**Steps:**
```
1. Open app
2. Go to Profile → Logout
3. Login with: preethampr@thanson07@gmail.com
4. Password: [your password]
5. Navigate to Edit Profile
6. ✅ Data should display correctly
```

### Option 2: Fix the Firestore Document ID

Update the Firestore document to match the logged-in user's UID:

**In Firebase Console:**
1. Go to Firestore Database
2. Find document: `users/WCfPPKTkuJ81amozcos`
3. Copy all the data
4. Create new document: `users/DzmaLniSoUP0YxMWEwp8omFMiV12`
5. Paste the data
6. Update the `email` field to: `preethampriyatharson07@gmail.com`
7. Update the `uid` field to: `DzmaLniSoUP0YxMWEwp8omFMiV12`
8. Delete the old document (optional)

**Document structure:**
```json
{
  "uid": "DzmaLniSoUP0YxMWEwp8omFMiV12",
  "authUid": "DzmaLniSoUP0YxMWEwp8omFMiV12",
  "email": "preethampriyatharson07@gmail.com",
  "name": "Preetham",
  "phone": "7010678124",
  "flatId": "b001",
  "flatLabel": "b201",
  "password": "PYvldepS",
  "residentId": "RES7397",
  "ownershipType": "Owner",
  "familyMembers": 2,
  "role": "resident",
  "createdAt": [current timestamp],
  "updatedAt": [current timestamp],
  "isActive": true
}
```

### Option 3: Create User Document During Registration

Update the registration flow to always create a Firestore document when a user registers:

**In `firebase_auth_firestore_service.dart`:**
```dart
Future<AuthFirestoreResult> registerWithEmailPassword({
  required String name,
  required String email,
  required String password,
  String? phone,
}) async {
  // Create Firebase Auth user
  final userCredential = await _auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  final user = userCredential.user!;
  
  // IMPORTANT: Create Firestore document with matching UID
  await _firestore.collection('users').doc(user.uid).set({
    'uid': user.uid,
    'authUid': user.uid,
    'email': email,
    'name': name,
    'phone': phone,
    'role': 'resident',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'isActive': true,
  });
  
  return AuthFirestoreResult.success(user: user);
}
```

## How the App Works Now

### Fetch Flow:
```
1. User logs in → Firebase Auth UID: ABC123
2. App fetches: Firestore users/ABC123
3. If document exists → Display data ✅
4. If document doesn't exist → Show empty form ❌
```

### Save Flow:
```
1. User clicks Save
2. App checks: Does users/ABC123 exist?
3. If YES → Update document ✅
4. If NO → Show error "User profile not found" ❌
```

## Current Code Behavior

The Edit Profile screen now:
- ✅ Only updates existing documents
- ❌ Does NOT create new documents
- ✅ Shows error if document doesn't exist
- ✅ Prevents data corruption

## Recommended Action

**For immediate fix:**
1. Logout from `preethampriyatharson07@gmail.com`
2. Login with `preethampr@thanson07@gmail.com`
3. Edit Profile will work correctly

**For long-term fix:**
1. Ensure registration creates Firestore document
2. Use same UID for both Auth and Firestore
3. Always validate document exists after login

## Verification Steps

After applying the fix:

1. **Check Firebase Auth:**
   ```
   - Open Firebase Console → Authentication
   - Find your user
   - Copy the UID
   ```

2. **Check Firestore:**
   ```
   - Open Firebase Console → Firestore
   - Navigate to users collection
   - Find document with same UID
   - Verify data exists
   ```

3. **Test in App:**
   ```
   - Login
   - Go to Profile
   - Check if name/flat displays
   - Go to Edit Profile
   - Check if data loads
   - Edit and save
   - Verify changes in Firebase Console
   ```

## Debug Information

When you see these logs:
```
🔵 EditProfile: Current user UID: DzmaLniSoUP0YxMWEwp8omFMiV12
🔵 EditProfile: Document exists: false
❌ EditProfile: User document does not exist in Firestore
```

It means:
- User is logged into Firebase Auth ✅
- But no Firestore document exists with that UID ❌
- You need to either:
  - Login with correct account, OR
  - Create/fix the Firestore document

## Status

- ✅ Edit Profile only updates existing users
- ✅ Proper error messages shown
- ✅ No accidental document creation
- ⚠️ Need to fix UID mismatch in your data
