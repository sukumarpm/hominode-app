# 🚨 QUICK FIX - Firestore Not Working

## The Problem
Data not fetching/storing in Firestore `users` collection.

## The Solution (2 minutes)

### Fix: Update Firestore Security Rules

1. Open: https://console.firebase.google.com
2. Select your project
3. Click: **Firestore Database** → **Rules**
4. Replace everything with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

5. Click **Publish**
6. Wait 30 seconds
7. Restart your app

## Test It Works

1. Login: admin@lyvo.com / test@123
2. Go to Residents tab
3. Should see residents (or empty list, not error)

## Still Not Working?

### Also check:
- **Authentication** → **Sign-in method** → Enable **Email/Password**
- Create test data in Firestore (see COMPLETE_FIX_SUMMARY.md)
- Check console logs for errors

## Why This Fixes It

Default Firestore rules block ALL access. This rule allows authenticated users to read/write data, which is what your app needs.

---

**That's it! This one change fixes the data fetching issue.**

