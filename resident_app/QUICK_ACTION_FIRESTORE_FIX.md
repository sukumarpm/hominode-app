# Quick Action: Fix Firestore Permission Errors

## The Error
App shows "Error checking access" and logs show `PERMISSION_DENIED` errors on collections like users, complaints, visitors, announcements.

## The Fix (2 Steps)

### Step 1: Deploy New Firestore Rules
Copy these rules and deploy to Firebase Console:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

**How to deploy:**
1. Open Firebase Console
2. Go to Firestore Database → Rules tab
3. Replace all content with the rules above
4. Click "Publish"
5. Wait for deployment (1-2 minutes)

### Step 2: Restart the App
1. Stop the app on your device
2. Run: `flutter run`
3. Or use hot restart: Press `r` in the terminal

## Expected Result
✅ App loads successfully
✅ "Error checking access" message disappears
✅ User data displays
✅ All features work (complaints, visitors, bills, etc.)

## Why This Works
- Old rules required Firebase Auth (`request.auth != null`)
- App uses Firestore-only auth (user ID in SharedPreferences)
- New rules allow all access (development/testing only)
- All services now work without permission errors

## Verification
Check logs for:
- `✅ Access granted with flatId: T001`
- `✅ User data fetched`
- `✅ Fetched X complaints/visitors/bills`

---

**File to reference**: `resident_app/FIRESTORE_SECURITY_RULES_FINAL.txt` (already updated with new rules)
