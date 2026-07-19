# Fix Login - Use Firebase Console (EASIEST METHOD)

## The Problem

Your user exists in Firestore but the `authUid` is `null`. This means the user was never created in Firebase Authentication.

## Solution - Do This Now

### Step 1: Go to Firebase Console

1. Open: https://console.firebase.google.com/
2. Click on your project: **lyvo-app**

### Step 2: Go to Authentication

1. Click "Authentication" in the left sidebar
2. Click "Users" tab at the top

### Step 3: Check if User Exists

Look for: `preethampriyatharson07@gmail.com`

**If user EXISTS:**
- Note down the UID
- Go to Step 4

**If user DOES NOT exist:**
- Click "Add user" button
- Email: `preethampriyatharson07@gmail.com`
- Password: `teste123`
- Click "Add user"
- Note down the UID that was created

### Step 4: Update Firestore

1. Go to "Firestore Database" in left sidebar
2. Click on "users" collection
3. Find the document with email `preethampriyatharson07@gmail.com`
4. Click on that document
5. Find the field `authUid`
6. Change it from `null` to the UID from Firebase Auth
7. Click "Update"

### Step 5: Test Login

1. Go back to your app
2. Hot restart (press `R` in terminal)
3. Try login with:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `teste123`
4. ✅ Should work!

OR

3. Try login with:
   - Phone: `7010678124`
   - Password: `teste123`
4. ✅ Should work!

## Why This Happens

When admin creates a user, they must:
1. Create user in Firebase Authentication (handles login)
2. Save user data to Firestore (stores profile)
3. Link them with the same UID

Your user was only created in Firestore, not in Firebase Auth.

## For Future Users

Update your admin panel to do this when creating users:

```dart
// Step 1: Create in Firebase Auth
final userCredential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(
  email: email,
  password: password,
);

final uid = userCredential.user!.uid;

// Step 2: Save to Firestore with the same UID
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)  // Use the same UID!
    .set({
  'uid': uid,
  'authUid': uid,
  'email': email,
  'phone': phone,
  'name': name,
  // ... other fields
});
```

## Quick Checklist

- [ ] Go to Firebase Console
- [ ] Authentication → Users
- [ ] Add user if not exists (email + password)
- [ ] Copy the UID
- [ ] Firestore → users collection
- [ ] Find user document
- [ ] Update `authUid` field with the UID
- [ ] Hot restart app
- [ ] Try login
- [ ] ✅ Success!

This is the EASIEST and FASTEST way to fix your login issue!
