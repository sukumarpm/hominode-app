# Firestore Troubleshooting Guide

## Issue: Data Not Storing/Fetching from Firestore

### Quick Diagnosis Steps

Run these checks in order:

#### 1. Check Console Logs

When you try to create a resident or view existing residents, check the console for:

```
╔════════════════════════════════════════════════════════╗
║         CREATE USER - START                            ║
╚════════════════════════════════════════════════════════╝
```

or

```
╔════════════════════════════════════════════════════════╗
║         GET AVAILABLE USERS - START                    ║
╚════════════════════════════════════════════════════════╝
```

**If you don't see these logs:** The functions are not being called.

**If you see error messages:** Note the exact error and check solutions below.

#### 2. Use Debug Button

Add the debug button to your app to run tests:

```dart
// In manage_buildings_page.dart
import 'widgets/firestore_debug_button.dart';

// In build method, add:
floatingActionButton: const FirestoreDebugButton(),
```

Then click the red bug icon and run tests.

### Common Issues and Solutions

#### Issue 1: Firestore Rules Blocking Access

**Symptoms:**
- Console shows: `permission-denied` or `PERMISSION_DENIED`
- Data not saving or loading

**Solution:**
Update Firestore Security Rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all reads and writes (for development only!)
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

**For Production**, use proper rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Admin can read/write all users
      allow read, write: if request.auth != null && 
                           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Residents can read their own data
      allow read: if request.auth != null && 
                     resource.data.authUid == request.auth.uid;
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read, write: if request.auth != null;
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### Issue 2: Firebase Not Initialized

**Symptoms:**
- Console shows: `Firebase has not been correctly initialized`
- App crashes on startup

**Solution:**
Check `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

#### Issue 3: Wrong Collection Name

**Symptoms:**
- Data goes to wrong collection
- Can't find data when querying

**Solution:**
Verify collection name in `user_service.dart`:

```dart
class UserService {
  final String _collection = 'users';  // ← Must be 'users'
  
  // ...
}
```

#### Issue 4: Network/Internet Issues

**Symptoms:**
- Console shows: `network error` or `timeout`
- Intermittent failures

**Solution:**
1. Check internet connection
2. Check Firebase project status
3. Enable offline persistence:

```dart
// In main.dart, after Firebase.initializeApp()
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

#### Issue 5: Authentication Issues

**Symptoms:**
- Console shows: `auth/email-already-in-use`
- Console shows: `auth/invalid-email`
- Console shows: `auth/weak-password`

**Solution:**

For `email-already-in-use`:
- This is expected if creating user with same email twice
- Firestore document should still be created
- Check console logs for "Continuing with Firestore creation anyway..."

For `invalid-email`:
- Check email format
- Ensure phone@lyvo.com format is valid

For `weak-password`:
- Ensure password is at least 6 characters
- Update password generation to use longer passwords

#### Issue 6: Data Structure Mismatch

**Symptoms:**
- Data saves but doesn't display correctly
- Console shows null values

**Solution:**
Verify data structure matches expected format:

```javascript
// Expected structure in Firestore
users/{docId} = {
  name: "string",
  phone: "string",
  email: "string" or null,
  residentId: "string",
  authEmail: "string",
  password: "string",
  authUid: "string" or null,
  role: "resident",
  flatId: "string" or null,
  flatLabel: "string" or null,
  ownershipType: "string" or null,
  familyMembers: number,
  status: "active" or "inactive",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Debugging Steps

#### Step 1: Enable Detailed Logging

The enhanced logging is already added. When you create or fetch users, you'll see detailed logs like:

```
╔════════════════════════════════════════════════════════╗
║         CREATE USER - START                            ║
╚════════════════════════════════════════════════════════╝
Input parameters:
  - Name: Sarah Williams
  - Phone: 9123456789
  - Email: sarah@example.com
  - Password: aB3xK9mP
  - Family Members: 4

[Step 1] Auth email determined: sarah@example.com
[Step 2] Creating Firebase Auth account...
✅ Firebase Auth account created
   Auth UID: abc123xyz
✅ Display name updated

[Step 3] Generating resident ID...
✅ Resident ID generated: RES5326

[Step 4] Creating Firestore document...
Collection: users
Data to store:
  {name: Sarah Williams, phone: 9123456789, ...}
✅ Firestore document created successfully!
   Document ID: user_doc_123

[Step 5] Verifying document...
✅ Document verified in Firestore
   Data: {name: Sarah Williams, ...}

╔════════════════════════════════════════════════════════╗
║         CREATE USER - SUCCESS                          ║
╚════════════════════════════════════════════════════════╝
```

#### Step 2: Check Firebase Console

1. Open Firebase Console: https://console.firebase.google.com
2. Select your project: `lyvo-app`
3. Go to Firestore Database
4. Check if `users` collection exists
5. Check if documents are being created
6. Check document structure

#### Step 3: Test with Debug Button

1. Add debug button to your app (see code above)
2. Click the red bug icon
3. Run "Test Create User"
4. Check console for detailed logs
5. Check Firebase Console to see if document was created

#### Step 4: Test Manually in Firebase Console

1. Go to Firestore Database in Firebase Console
2. Click "Start collection"
3. Collection ID: `users`
4. Add a test document manually:
   ```
   name: "Manual Test"
   phone: "1234567890"
   role: "resident"
   status: "active"
   flatId: null
   ```
5. Try to fetch this user in your app
6. If it shows up, the issue is with creating, not fetching

### Testing Checklist

Run through this checklist:

- [ ] Firebase initialized in main.dart
- [ ] Internet connection working
- [ ] Firebase project selected correctly
- [ ] Firestore rules allow read/write
- [ ] Collection name is "users"
- [ ] Console shows detailed logs
- [ ] Can create document manually in Firebase Console
- [ ] Can see document in Firebase Console after app creates it
- [ ] Debug button tests pass

### Getting Help

If issues persist, provide:

1. **Console logs** - Copy the entire log output
2. **Firebase Console screenshot** - Show the users collection
3. **Firestore Rules** - Copy your current rules
4. **Error messages** - Exact error text
5. **Test results** - Results from debug button tests

### Quick Fixes

#### Fix 1: Reset Firestore Rules (Development Only)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // ← Allow everything
    }
  }
}
```

#### Fix 2: Clear App Data and Restart

```bash
# Flutter
flutter clean
flutter pub get
flutter run
```

#### Fix 3: Check Firebase Configuration

```bash
# Verify firebase_options.dart exists
ls lib/firebase_options.dart

# If missing, run:
flutterfire configure
```

#### Fix 4: Verify Dependencies

Check `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
```

Run:
```bash
flutter pub get
```

### Success Indicators

You'll know it's working when you see:

1. **Console logs show:**
   ```
   ✅ Firestore document created successfully!
   ✅ Document verified in Firestore
   ```

2. **Firebase Console shows:**
   - `users` collection exists
   - Documents appear after creating residents
   - Document structure matches expected format

3. **App behavior:**
   - "Select Existing" tab shows residents
   - Status indicators display correctly
   - Real-time updates work

### Still Not Working?

If you've tried everything above and it's still not working:

1. **Check the exact error message** in console
2. **Take a screenshot** of Firebase Console showing the users collection
3. **Copy the console logs** from creating a user
4. **Share the Firestore rules** you're using

This will help identify the specific issue!
