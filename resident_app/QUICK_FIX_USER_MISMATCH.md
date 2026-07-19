# QUICK FIX - User Document Mismatch

## The Problem
You're logged in as: `preethampriyatharson07@gmail.com` (UID: DzmaLniSoUP0YxMWEwp8omFMiV12)
But the Firestore document is for: `preethampr@thanson07@gmail.com` (Document ID: WCfPPKTkuJ81amozcos)

## IMMEDIATE FIX - Option 1: Login with Correct Email

1. **Logout** from the app
2. **Login** with email: `preethampr@thanson07@gmail.com`
3. Use the password for that account
4. ✅ Edit Profile will work

## IMMEDIATE FIX - Option 2: Create Document in Firebase Console

If you want to keep using `preethampriyatharson07@gmail.com`:

### Step 1: Open Firebase Console
Go to: https://console.firebase.google.com/project/lyvo-app-9f0ca/firestore

### Step 2: Create New Document
1. Click on `users` collection
2. Click "Add document"
3. Document ID: `DzmaLniSoUP0YxMWEwp8omFMiV12` (copy exactly)
4. Add these fields:

```
Field Name          | Type      | Value
--------------------|-----------|----------------------------------
uid                 | string    | DzmaLniSoUP0YxMWEwp8omFMiV12
authUid             | string    | DzmaLniSoUP0YxMWEwp8omFMiV12
email               | string    | preethampriyatharson07@gmail.com
name                | string    | Preetham
phone               | string    | 7010678124
flatId              | string    | b001
flatLabel           | string    | b201
residentId          | string    | RES7397
ownershipType       | string    | Owner
familyMembers       | number    | 2
role                | string    | resident
isActive            | boolean   | true
createdAt           | timestamp | (click "Set to current time")
updatedAt           | timestamp | (click "Set to current time")
```

### Step 3: Save and Test
1. Click "Save"
2. Go back to your app
3. Pull down to refresh (or restart app)
4. Go to Edit Profile
5. ✅ Data should now display

## IMMEDIATE FIX - Option 3: Use Firebase CLI

If you have Firebase CLI installed:

```bash
# Create a script to add the document
firebase firestore:write users/DzmaLniSoUP0YxMWEwp8omFMiV12 '{
  "uid": "DzmaLniSoUP0YxMWEwp8omFMiV12",
  "authUid": "DzmaLniSoUP0YxMWEwp8omFMiV12",
  "email": "preethampriyatharson07@gmail.com",
  "name": "Preetham",
  "phone": "7010678124",
  "flatId": "b001",
  "flatLabel": "b201",
  "residentId": "RES7397",
  "ownershipType": "Owner",
  "familyMembers": 2,
  "role": "resident",
  "isActive": true
}'
```

## Verify the Fix

After applying any fix:

1. **Check in Firebase Console:**
   - Go to Firestore → users collection
   - Look for document: `DzmaLniSoUP0YxMWEwp8omFMiV12`
   - Verify all fields are present

2. **Check in App:**
   - Restart the app
   - Login (if needed)
   - Go to Dashboard → Check if name shows
   - Go to Profile → Check if name and flat show
   - Go to Edit Profile → Check if all fields are filled
   - Edit something and save
   - ✅ Should save successfully

## Why This Happened

Your registration flow created a Firebase Auth user but didn't create the corresponding Firestore document. This needs to be fixed in the registration code to prevent future issues.

## Prevent Future Issues

Update your registration flow to always create both:
1. Firebase Auth user (done ✅)
2. Firestore document with matching UID (missing ❌)

The registration code should look like:
```dart
// 1. Create Auth user
final userCredential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(email: email, password: password);

// 2. Create Firestore document (IMPORTANT!)
await FirebaseFirestore.instance
    .collection('users')
    .doc(userCredential.user!.uid)  // Use same UID!
    .set({
      'uid': userCredential.user!.uid,
      'email': email,
      'name': name,
      // ... other fields
    });
```

## Current Status

- ✅ Login works
- ✅ Firebase Auth user exists
- ❌ Firestore document missing
- ❌ Edit Profile can't fetch data
- ❌ Edit Profile can't save data

After fix:
- ✅ Login works
- ✅ Firebase Auth user exists
- ✅ Firestore document exists
- ✅ Edit Profile fetches data
- ✅ Edit Profile saves data
