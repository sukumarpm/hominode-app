# Fix Firestore Data Not Storing - Action Plan

## MOST LIKELY CAUSE: Firestore Not Enabled or Security Rules Blocking

### ⚡ Quick Fix (5 minutes)

#### Step 1: Enable Firestore in Firebase Console

1. **Open Firebase Console:** https://console.firebase.google.com/
2. **Select your project** (the one linked to this app)
3. **Click "Firestore Database"** in left sidebar
4. **If you see "Create database" button:**
   - Click it
   - Choose **"Start in test mode"** ← IMPORTANT
   - Select location (e.g., asia-south1 for India)
   - Click "Enable"
   - Wait 1-2 minutes for setup

#### Step 2: Set Security Rules to Test Mode

1. In Firestore Database, click **"Rules"** tab
2. Replace with this code:

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

3. Click **"Publish"**
4. Wait for "Rules published successfully" message

#### Step 3: Rebuild and Test

```bash
cd resident_app
flutter clean
flutter pub get
flutter run -d ZA222LQT6V
```

#### Step 4: Test Registration

1. Open app on device
2. Go to Create Account
3. Fill in details:
   - Name: Test User
   - Email: test@example.com
   - Password: Test123!
   - Block: A
   - Flat: 101
4. Click Continue
5. Watch the terminal for logs

#### Step 5: Check Firebase Console

1. Go back to Firebase Console → Firestore Database
2. Look for **"users"** collection
3. You should see a document with your user data

---

## 🔍 Debugging Steps

### Check Logs in Terminal

After registration, you should see:

```
🔵 Starting registration process...
📧 Email/Phone: test@example.com
👤 Full Name: Test User
📧 Creating account with email...
✅ Auth result: true
🆔 User ID: [some-id]
✅ Display name updated
💾 Creating Firestore document...
🔵 ResidentDatabaseService.createUser called
✅ Firestore write successful!
```

### If You See Errors:

#### ❌ "permission-denied"
**Problem:** Security rules are blocking writes
**Fix:** Set rules to test mode (see Step 2 above)

#### ❌ "not-found" or "unavailable"  
**Problem:** Firestore not enabled
**Fix:** Enable Firestore (see Step 1 above)

#### ❌ No logs at all
**Problem:** App not rebuilt with new code
**Fix:** Run `flutter clean && flutter pub get && flutter run`

---

## 📋 Complete Checklist

Before testing, verify:

- [ ] Firebase Console → Firestore Database is enabled
- [ ] Security rules are set to test mode (allow all)
- [ ] `google-services.json` exists in `android/app/`
- [ ] App has been rebuilt with `flutter clean`
- [ ] Device has internet connection
- [ ] You're watching terminal for logs during registration

---

## 🎯 Expected Result

### In Terminal:
```
✅ Firestore write successful!
💾 Firestore result: true
💾 Message: User created successfully
```

### In Firebase Console:
```
Firestore Database
└── users (collection)
    └── [user-id] (document)
        ├── id: "abc123..."
        ├── fullName: "Test User"
        ├── email: "test@example.com"
        ├── phoneNumber: null
        ├── role: "resident"
        ├── isActive: true
        ├── createdAt: [timestamp]
        └── updatedAt: [timestamp]
```

---

## 🚨 If Still Not Working

### Option 1: Check google-services.json

1. Open `android/app/google-services.json`
2. Find `"project_id"` field
3. Verify it matches your Firebase Console project ID
4. If different, download correct file from Firebase Console:
   - Project Settings → Your apps → Android app
   - Click "google-services.json" download button
   - Replace the file
   - Rebuild app

### Option 2: Verify Firebase Project

1. Firebase Console → Project Settings
2. Check "Your apps" section
3. Verify Android app is registered
4. Package name should be: `com.example.resident_app`
5. If not registered, add Android app

### Option 3: Test Firestore Directly

Add this button to your app temporarily:

```dart
ElevatedButton(
  onPressed: () async {
    try {
      await FirebaseFirestore.instance
          .collection('test')
          .doc('test123')
          .set({'message': 'Hello Firestore!', 'timestamp': DateTime.now()});
      print('✅ Test write successful!');
    } catch (e) {
      print('❌ Test write failed: $e');
    }
  },
  child: Text('Test Firestore'),
)
```

If this works but registration doesn't, the issue is in the registration code.
If this fails, the issue is with Firebase setup.

---

## 📞 Need Help?

Provide these details:

1. **Firebase Console screenshot** showing Firestore Database page
2. **Terminal logs** during registration (copy all output)
3. **Security rules** from Firebase Console
4. **google-services.json project_id** (just the ID, not the whole file)

---

## ⚠️ Important Notes

### Test Mode Security Rules

The test mode rules (`allow read, write: if true`) are **NOT SECURE** for production!

They allow anyone to read/write your database.

**Use only for development/testing.**

### Production Rules

Once testing is complete, update to secure rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ Terminal shows "Firestore write successful!"
2. ✅ Firebase Console shows users collection with data
3. ✅ No error messages in terminal
4. ✅ Registration completes and navigates to next screen

---

## 🎉 After It Works

1. **Test with multiple users** to verify consistency
2. **Check data structure** in Firebase Console
3. **Update security rules** to production rules
4. **Remove debug print statements** (optional)
5. **Set up Firestore indexes** if needed for queries

---

## Quick Commands Reference

```bash
# Rebuild app
flutter clean
flutter pub get
flutter run -d ZA222LQT6V

# View logs only
flutter logs

# Check connected devices
flutter devices

# Kill existing app instance
adb shell am force-stop com.example.resident_app
```

---

**Start with Step 1 above and work through each step. Most issues are resolved by enabling Firestore and setting test mode rules.**
