# FINAL LOGIN SOLUTION - Complete Guide

## Current Situation

Looking at your Firebase:
- ✅ User exists in Firestore: `preethampriyatharson07@gmail.com`
- ✅ User exists in Firebase Auth: `preethampriyatharson07@gmail.com`
- ❌ BUT `authUid` in Firestore is `null`
- ❌ This breaks the login

## Why Login Fails

The app tries to login with Firebase Auth, but the Firestore document has `authUid: null`, so the system can't link the authenticated user to their profile data.

## SOLUTION (Choose ONE method)

### Method 1: Firebase Console (RECOMMENDED - 2 minutes)

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/
   - Select project: `lyvo-app`

2. **Get the UID from Authentication:**
   - Click "Authentication" → "Users"
   - Find: `preethampriyatharson07@gmail.com`
   - Copy the UID (looks like: `T7hNDCpFF1KTm1d4TvOw`)

3. **Update Firestore:**
   - Click "Firestore Database"
   - Go to `users` collection
   - Find document: `T7hNDCpFF1KTm1d4TvOw` (or search by email)
   - Edit field `authUid`: change from `null` to the UID you copied
   - Click "Update"

4. **Test:**
   - Hot restart app (press `R`)
   - Login with email or phone
   - ✅ Should work!

### Method 2: Run Script (If Method 1 doesn't work)

```bash
cd resident_app
flutter run lib/create_firebase_user.dart -d chrome
```

Wait for success message, then hot restart app.

### Method 3: Delete and Recreate User

If both methods above fail:

1. **Delete from Firebase Auth:**
   - Firebase Console → Authentication → Users
   - Find `preethampriyatharson07@gmail.com`
   - Click three dots → Delete user

2. **Delete from Firestore:**
   - Firestore Database → users collection
   - Find the document
   - Delete it

3. **Recreate properly:**
   - Firebase Console → Authentication → Users
   - Click "Add user"
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `teste123`
   - Click "Add user"
   - **Copy the new UID**

4. **Create Firestore document:**
   - Firestore Database → users collection
   - Click "Add document"
   - Document ID: **Paste the UID you copied**
   - Add fields:
     ```
     uid: [the UID]
     authUid: [the UID]
     email: "preethampriyatharson07@gmail.com"
     phone: "7010678124"
     name: "preetham"
     role: "resident"
     status: "active"
     flatId: "b202"
     flatLabel: "b202"
     residentId: "RBS2393"
     familyMembers: 2
     ownershipType: "Owner"
     createdAt: [timestamp]
     updatedAt: [timestamp]
     ```
   - Click "Save"

5. **Test login**

## After Fix - How to Login

### Option 1: Email Login
- Email: `preethampriyatharson07@gmail.com`
- Password: `teste123`

### Option 2: Phone Login
- Phone: `7010678124`
- Password: `teste123`

Both should work with the same password!

## For Admin Panel - Proper User Creation

Update your admin panel to create users correctly:

```dart
Future<void> createUserByAdmin({
  required String email,
  required String password,
  required String name,
  required String phone,
  required String flatId,
  required String flatLabel,
  required String residentId,
}) async {
  try {
    // Step 1: Create in Firebase Authentication
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final uid = userCredential.user!.uid;
    print('✅ Created in Firebase Auth with UID: $uid');
    
    // Step 2: Create in Firestore with SAME UID
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)  // IMPORTANT: Use the same UID as document ID
        .set({
      'uid': uid,
      'authUid': uid,  // IMPORTANT: Store the auth UID
      'email': email,
      'phone': phone,
      'name': name,
      'role': 'resident',
      'status': 'active',
      'flatId': flatId,
      'flatLabel': flatLabel,
      'residentId': residentId,
      'familyMembers': 0,
      'ownershipType': 'Owner',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // DO NOT store password in Firestore!
    });
    
    print('✅ Created in Firestore with UID: $uid');
    print('🎉 User created successfully!');
    
  } catch (e) {
    print('❌ Error creating user: $e');
    rethrow;
  }
}
```

## Key Points

1. **Firebase Auth** handles login/passwords
2. **Firestore** stores user profile data
3. **They must be linked** with the same UID
4. **Never store passwords** in Firestore
5. **authUid field** must match the Firebase Auth UID

## Troubleshooting

### "Invalid credentials" error
- User doesn't exist in Firebase Auth
- OR password is wrong
- Solution: Check Firebase Console → Authentication → Users

### "No account found with this phone number"
- Phone number not in Firestore
- OR phone number format is wrong
- Solution: Check Firestore → users → phone field

### User logs in but no data shows
- authUid is null or wrong
- Solution: Update authUid in Firestore to match Firebase Auth UID

## Status

After following Method 1 (Firebase Console), your login should work immediately!

✅ Simple login screen (no Phone OTP tab)
✅ Email or phone number login
✅ Same password for both
✅ Ready to use

Just update the `authUid` field in Firestore and you're done!
