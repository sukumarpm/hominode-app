# Fix Firestore Security Rules - URGENT

## Problem: Data Not Saving to Firestore

Your Firestore database is empty because security rules are likely blocking writes.

## IMMEDIATE FIX (5 minutes)

### Step 1: Set Security Rules to Test Mode

1. **Go to Firebase Console** (where you took the screenshot)
2. **Click "Rules" tab** (next to "Data" tab at the top)
3. **Replace ALL rules with this:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

4. **Click "Publish"** button
5. **Wait for "Rules published successfully" message**

### Step 2: Rebuild and Test App

```bash
cd resident_app
flutter clean
flutter pub get
flutter run -d ZA222LQT6V
```

### Step 3: Test Registration

1. Open app on device
2. Go to Register/Create Account screen
3. Fill in details:
   - Name: Test User
   - Email: test@example.com
   - Password: Test123!
4. Click Register/Create Account
5. Watch terminal for logs

### Step 4: Check Firebase Console

1. Go back to Firebase Console → Firestore Database → Data tab
2. You should now see a "users" collection
3. Click on it to see your user document

---

## If Still Not Working

### Check These:

1. **Is Firestore Enabled?**
   - You should see "Start collection" button
   - If you see "Create database", Firestore is NOT enabled
   - Click "Create database" → Choose "Start in test mode" → Enable

2. **Check Terminal Logs**
   
   Look for these messages during registration:
   ```
   🔵 Starting registration...
   🔐 Creating Firebase Auth user...
   ✅ Firebase Auth user created
   💾 Saving to Firestore...
   ✅ Firestore document created
   ```

   If you see errors like:
   - `❌ Firebase Exception: permission-denied` → Security rules issue
   - `❌ Firebase Exception: unavailable` → Firestore not enabled
   - `❌ Firebase Exception: not-found` → Wrong project

3. **Verify google-services.json**
   
   - Open `android/app/google-services.json`
   - Check `project_id` matches your Firebase Console project
   - If different, download correct file from Firebase Console

---

## Test Mode Security Rules Explained

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // ← Allows ALL reads and writes
    }
  }
}
```

⚠️ **WARNING:** These rules are NOT SECURE for production!
- Anyone can read/write your database
- Use ONLY for development/testing
- Update to secure rules before going live

---

## Production Security Rules (Use After Testing)

Once data is saving successfully, update to these secure rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Users can read their own document
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Users can create their own document during registration
      allow create: if request.auth != null 
                    && request.auth.uid == userId
                    && request.resource.data.uid == userId
                    && request.resource.data.role == 'resident';
      
      // Users can update their own document
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // No one can delete
      allow delete: if false;
    }
  }
}
```

---

## Quick Verification Steps

### 1. Check if Firestore is Enabled
- Firebase Console → Firestore Database
- Should show database interface, not "Create database" button

### 2. Check Security Rules
- Firebase Console → Firestore Database → Rules tab
- Should show rules code, not empty

### 3. Check App Logs
- Run app with `flutter run -d ZA222LQT6V`
- Watch terminal during registration
- Look for success/error messages

### 4. Check Firebase Console
- After registration, refresh Firestore Database → Data tab
- Should see "users" collection with documents

---

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "permission-denied" error | Set rules to test mode (allow all) |
| "unavailable" error | Enable Firestore in Firebase Console |
| "not-found" error | Check google-services.json project_id |
| No error but no data | Check if using correct Firebase project |
| Rules won't publish | Wait 1-2 minutes and try again |

---

## Next Steps After Fix

1. ✅ Verify data appears in Firestore
2. ✅ Test with multiple users
3. ✅ Update to production security rules
4. ✅ Remove debug logging (optional)
5. ✅ Test all CRUD operations

---

## Need More Help?

If still not working after following these steps:

1. Take screenshot of:
   - Firebase Console → Firestore Database → Rules tab
   - Terminal logs during registration
   - Firebase Console → Project Settings → General tab

2. Check:
   - Is internet connection working?
   - Is Firebase project correct?
   - Is app rebuilt after changes?

---

**START WITH STEP 1 ABOVE - Setting security rules to test mode is the most common fix!**
