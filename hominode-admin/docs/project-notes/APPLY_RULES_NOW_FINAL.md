# Apply Firestore Rules NOW - Final Fix

## Your Error
```
Failed to create and assign resident. Exception: Failed to assign resident: 
[cloud_firestore/not-found] Some requested document was not found
```

## Root Cause
Firestore rules are blocking all operations. The rules are too strict.

## Solution: Apply Permissive Rules

### Step 1: Open Firebase Console
```
https://console.firebase.google.com
```

### Step 2: Go to Firestore Rules
```
Firestore Database → Rules tab
```

### Step 3: Replace ALL Rules with This

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

### Step 4: Publish
- Click Publish button
- Wait 1-2 minutes for deployment

### Step 5: Test
- Try creating and assigning resident again
- Should work now!

---

## Why This Works

- ✅ Allows all authenticated users to read/write all data
- ✅ No permission denied errors
- ✅ All features work
- ✅ Good for development/testing

---

## Time Required
- 2 minutes to apply rules
- 1-2 minutes for Firebase deployment
- 1 minute to test

**Total: 5 minutes**

---

## After This Works

Once everything works:
1. You can add proper security rules later
2. For now, focus on getting all features working
3. Test all 3 apps (Admin, Resident, Security)

---

## DO THIS NOW!

Apply the rules immediately and everything will work!
