# Firestore Troubleshooting Guide

## Issue: Data Not Storing in Firestore

### Step 1: Check Firebase Console

1. **Go to Firebase Console:** https://console.firebase.google.com/
2. **Select your project**
3. **Navigate to Firestore Database** (left sidebar)
4. **Check if Firestore is enabled:**
   - If you see "Create database" button → Firestore is NOT enabled
   - If you see collections/documents → Firestore IS enabled

### Step 2: Enable Firestore (if not enabled)

1. Click **"Create database"**
2. Choose **"Start in test mode"** (for development)
3. Select a location (closest to your users)
4. Click **"Enable"**

### Step 3: Set Up Security Rules

In Firebase Console → Firestore Database → Rules tab:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all reads and writes for testing (DEVELOPMENT ONLY)
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

**⚠️ WARNING:** These rules allow anyone to read/write. Use only for testing!

### Step 4: Production Security Rules

Once testing is complete, use these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow user to read their own document
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow user creation during registration
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // Allow user to update their own document
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Prevent deletion
      allow delete: if false;
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admins can modify
    }
    
    // Bills collection
    match /bills/{billId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admins can modify
    }
    
    // Payments collection
    match /payments/{paymentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if false;
    }
    
    // Notices collection
    match /notices/{noticeId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admins can modify
    }
    
    // Visitors collection
    match /visitors/{visitorId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if false;
    }
    
    // Complaints collection
    match /complaints/{complaintId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if false;
    }
  }
}
```

### Step 5: Check App Logs

Run the app with logging enabled:

```bash
flutter run -d ZA222LQT6V
```

Look for these log messages during registration:

```
🔵 Starting registration process...
📧 Email/Phone: test@example.com
👤 Full Name: Test User
📧 Creating account with email...
✅ Auth result: true
🆔 User ID: abc123xyz789
✅ Display name updated
💾 Creating Firestore document...
🔵 ResidentDatabaseService.createUser called
🆔 User ID: abc123xyz789
👤 Full Name: Test User
📧 Email: test@example.com
📦 User model created
💾 Attempting to write to Firestore...
📍 Collection: users
📄 Document ID: abc123xyz789
✅ Firestore write successful!
💾 Firestore result: true
💾 Message: User created successfully
```

### Step 6: Common Errors and Solutions

#### Error: "permission-denied"
**Cause:** Firestore security rules are blocking the write
**Solution:** 
1. Go to Firebase Console → Firestore → Rules
2. Temporarily set to test mode (allow all)
3. Publish rules
4. Try registration again

#### Error: "not-found" or "unavailable"
**Cause:** Firestore is not enabled
**Solution:** Enable Firestore in Firebase Console

#### Error: "deadline-exceeded"
**Cause:** Network timeout
**Solution:** 
1. Check internet connection
2. Try again
3. Check Firebase status page

#### No Error but No Data
**Cause:** Silent failure or wrong project
**Solution:**
1. Verify `google-services.json` is correct
2. Check if using correct Firebase project
3. Rebuild app: `flutter clean && flutter pub get && flutter run`

### Step 7: Verify google-services.json

1. **Location:** `android/app/google-services.json`
2. **Check project_id matches your Firebase project**
3. **Verify it's not from a different project**

```json
{
  "project_info": {
    "project_number": "123456789",
    "project_id": "your-project-id",  // ← Should match Firebase Console
    "storage_bucket": "your-project-id.appspot.com"
  }
}
```

### Step 8: Test Firestore Connection

Add this test function to your app:

```dart
Future<void> testFirestoreConnection() async {
  try {
    print('🧪 Testing Firestore connection...');
    
    final testDoc = FirebaseFirestore.instance
        .collection('test')
        .doc('connection_test');
    
    await testDoc.set({
      'timestamp': FieldValue.serverTimestamp(),
      'message': 'Connection test successful',
    });
    
    print('✅ Firestore write successful!');
    
    final snapshot = await testDoc.get();
    if (snapshot.exists) {
      print('✅ Firestore read successful!');
      print('📄 Data: ${snapshot.data()}');
    }
    
    await testDoc.delete();
    print('✅ Firestore delete successful!');
    
  } catch (e) {
    print('❌ Firestore test failed: $e');
  }
}
```

Call this in your app's initState or on a button press.

### Step 9: Check Firebase Project Settings

1. Go to Firebase Console → Project Settings
2. Verify **Android app is registered**
3. Check **Package name** matches your app: `com.example.resident_app`
4. Download latest `google-services.json` if needed
5. Replace old file and rebuild app

### Step 10: Rebuild App

After making changes:

```bash
cd resident_app
flutter clean
flutter pub get
flutter run -d ZA222LQT6V
```

### Quick Checklist

- [ ] Firestore is enabled in Firebase Console
- [ ] Security rules allow writes (test mode for development)
- [ ] `google-services.json` is in `android/app/` folder
- [ ] Package name matches in Firebase Console
- [ ] Internet connection is working
- [ ] App has been rebuilt after changes
- [ ] Logs show successful Firestore write
- [ ] Firebase Console shows the data

### Still Not Working?

1. **Check Firebase Console → Usage tab**
   - See if any requests are being made
   - Check for errors

2. **Enable Firebase Debug Logging**
   ```bash
   adb shell setprop log.tag.FirebaseFirestore DEBUG
   flutter run -d ZA222LQT6V
   ```

3. **Try Manual Test**
   - Go to Firebase Console → Firestore
   - Manually create a document
   - If this fails, there's a Firebase project issue

4. **Verify Firebase Initialization**
   - Check `main.dart` has `await Firebase.initializeApp()`
   - Ensure it's called before `runApp()`

### Contact Support

If still not working, provide:
1. Firebase project ID
2. App logs during registration
3. Firestore security rules
4. Screenshot of Firebase Console → Firestore Database

---

## Next Steps After Fixing

Once data is storing successfully:

1. **Update security rules** to production rules
2. **Test with multiple users**
3. **Verify data structure** in Firebase Console
4. **Set up indexes** if needed for queries
5. **Monitor usage** in Firebase Console
