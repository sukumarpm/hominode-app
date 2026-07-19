# Login Fix - Action Required NOW (1 minute)

## Problem

Login fails with `PERMISSION_DENIED` because Firestore rules require authentication to read the `users` collection, but login needs to query it BEFORE authentication.

## Solution (Copy-Paste Ready)

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com
2. Select your project
3. Click **Firestore Database** (left sidebar)
4. Click **Rules** tab

### Step 2: Replace Rules

Delete everything and paste this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow unauthenticated read to users collection for login
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Allow all authenticated users to read and write everything else
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 3: Publish
1. Click **Publish** button
2. Wait for "Rules updated successfully" message
3. Done! ✅

### Step 4: Test Login
1. Go back to the app
2. Enter credentials:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `wlG0czyq`
3. Click Login
4. Should work now! ✅

## Why This Works

- ✅ Allows unauthenticated read to `users` collection (for login query)
- ✅ Password is validated in app code (not Firestore)
- ✅ Write access still requires authentication
- ✅ All other collections remain protected

## Time Required

⏱️ **1 minute** to deploy

---

**Status**: Action required ⚠️
