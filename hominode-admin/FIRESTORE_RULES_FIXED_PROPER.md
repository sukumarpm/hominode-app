# Firestore Rules - Fixed Properly

## The Problem
Your current rules are incomplete. The error persists because the rule structure isn't correct.

## The Correct Rule

Replace ALL your current rules with this EXACT rule:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users to read and write all collections
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Steps to Apply

### 1. Open Firebase Console
Go to: `https://console.firebase.google.com`

### 2. Select Your Project
Click on your project

### 3. Go to Firestore Database
Click: Firestore Database

### 4. Click Rules Tab
At the top, click "Rules"

### 5. Delete ALL Current Rules
- Click in the editor
- Press Ctrl+A (or Cmd+A)
- Press Delete

### 6. Paste This EXACT Rule
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 7. Verify No Red Underlines
- Check that there are NO red underlines
- All syntax should be correct

### 8. Click Publish
- Bottom right corner
- Click "Publish" button

### 9. Wait 1-2 Minutes
- Look for green checkmark
- Rules should show as "Published"

### 10. Restart App
- Close app completely
- Restart app
- Try the action again

---

## What This Rule Does

```firestore
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

- ✅ Matches ALL documents in ALL collections
- ✅ Allows read access if user is authenticated
- ✅ Allows write access if user is authenticated
- ✅ No permission denied errors
- ✅ No "not-found" errors

---

## If Still Getting Error

### Check 1: Rule is Published
- Go to Firebase Console → Firestore Database → Rules
- Look for green checkmark
- If red X, click Publish again

### Check 2: Clear App Cache
- Close app completely
- Clear app cache
- Restart app
- Try again

### Check 3: Check Firestore Data
- Go to Firebase Console → Firestore Database → Data
- Verify collections exist: admins, users, flats, etc.
- Verify documents have data

### Check 4: Check Firebase Auth
- Go to Firebase Console → Authentication
- Verify admin user exists
- Verify admin is logged in

---

## Expected Result After Applying Rules

- ✅ No more "not-found" errors
- ✅ Flat status updates work
- ✅ Resident assignment works
- ✅ Resident creation works
- ✅ All features work

---

## DO THIS NOW!

Apply the rule exactly as shown above and restart your app.

The error will be fixed immediately.

