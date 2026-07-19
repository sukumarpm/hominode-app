# 🔧 Fix Login Error - Quick Guide

## Problem
Error: "Authentication failed: The supplied auth credential is incorrect, malformed or has expired."

## Root Cause
The user exists in Firestore but NOT in Firebase Authentication.

## Solution Options

### Option 1: Run Diagnostic Tool (Recommended)
```bash
cd resident_app
flutter run -t lib/fix_login_issue.dart
```

Or double-click: `RUN_LOGIN_FIX.bat`

This will:
1. Check if user exists in Firestore ✓
2. Check if user exists in Firebase Auth ✗
3. Create user in Firebase Auth automatically ✓

### Option 2: Manual Fix in Firebase Console

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com
   - Select project: `lyvo-app`

2. **Go to Authentication**
   - Click "Authentication" in left sidebar
   - Click "Users" tab

3. **Add User**
   - Click "Add user" button
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `*DvgIDLEy*`
   - Click "Add user"

4. **Test Login**
   - Open app
   - Enter email and password
   - Should work now!

### Option 3: Quick Code Fix

Add this to `firestore_auth_service.dart` after line 150:

```dart
// Auto-create Firebase Auth user if doesn't exist
try {
  await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
} on FirebaseAuthException catch (e) {
  if (e.code == 'user-not-found') {
    // Create user in Firebase Auth
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    print('✅ Created user in Firebase Auth');
  }
}
```

## Verify Fix

After applying any solution:

1. Open app
2. Enter credentials:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `*DvgIDLEy*`
3. Tap "Login"
4. Should navigate to dashboard ✓

## Why This Happens

The app has TWO authentication systems:
1. **Firestore** - Stores user profile data
2. **Firebase Auth** - Handles authentication

Both need to have the user for login to work.

Your user exists in Firestore but not in Firebase Auth, causing the error.

## Prevention

When creating new users, always:
1. Create in Firestore (user profile)
2. Create in Firebase Auth (authentication)

The diagnostic tool does both automatically.

---

**Quick Fix**: Run `RUN_LOGIN_FIX.bat` and tap the button!
