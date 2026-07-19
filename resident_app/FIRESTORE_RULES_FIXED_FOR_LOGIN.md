# Firestore Rules - Fixed for Login

## Current Rules (Too Restrictive for Login)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users to read and write
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Problem**: Requires authentication to read, but login needs to query BEFORE authentication.

## Fixed Rules (Allow Login)

Replace with:

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

## What Changed

1. **Added specific rule for users collection** that allows unauthenticated read
2. **Kept write protection** - only authenticated users can write
3. **Kept all other collections protected** - require authentication

## Why This Works

✅ **Login can now query users collection** (unauthenticated read allowed)
✅ **Password validated in app code** (not in Firestore)
✅ **Write access still protected** (only authenticated users)
✅ **All other collections protected** (require authentication)

## Deployment Steps

1. Go to **Firebase Console**
2. Select your project
3. Go to **Firestore Database** → **Rules**
4. Replace all content with the fixed rules above
5. Click **Publish**
6. Wait for deployment (1-2 minutes)

## Test Login

After deploying:

1. Open the app
2. Go to login screen
3. Enter credentials:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `wlG0czyq`
4. Click Login
5. Should succeed and navigate to home screen

## Expected Console Output

```
🔐 Starting login...
   Identifier: preethampriyatharson07@gmail.com
🔐 Starting Firestore-only authentication...
   Identifier: preethampriyatharson07@gmail.com
📧 Detected email, searching in Firestore...
   Searching for email: preethampriyatharson07@gmail.com
✅ Found user with email: preethampriyatharson07@gmail.com
✅ User found in Firestore: [user-id]
   Name: Preetham Priyatharson
   Email: preethampriyatharson07@gmail.com
🔐 Step 2: Verifying password...
✅ Password verified successfully
🔐 Step 3: Syncing with Firebase Authentication...
✅ Firebase Auth sign-in successful
✅ Login successful!
   Welcome: Preetham Priyatharson
```

---

**Status**: Ready to deploy ✅
**Time to fix**: 1 minute
