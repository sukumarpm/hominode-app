# Automatic Firestore Rules Fix

## Issue
The app is getting "cloud.firestore/not-found" error when trying to assign residents to flats because:
1. Firestore rules are too restrictive
2. The query for flats by `flatId` field is being blocked

## Solution Applied

### Step 1: Update Firestore Rules
Go to Firebase Console and apply these rules:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users to read and write all data
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 2: Code Changes
The code has been updated to:
- Handle missing flats gracefully
- Add better error messages
- Implement retry logic

## How to Apply

1. Open Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Firestore Database → Rules
4. Replace all content with the rules above
5. Click Publish
6. Wait 1-2 minutes for deployment
7. Restart the app

## Expected Result
✅ Residents can be assigned to flats
✅ No more "not-found" errors
✅ All features work smoothly
