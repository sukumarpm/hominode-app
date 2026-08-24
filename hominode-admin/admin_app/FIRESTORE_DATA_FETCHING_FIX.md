# Firestore Data Fetching and Storage Fix

## Problem Analysis

Based on the user's issue, the data is not:
1. Fetching from Firestore `users` collection
2. Storing new user data in `users` collection
3. Properly authenticating residents when they login

## Root Causes Identified

### 1. Missing Debug Logging
The current implementation doesn't have sufficient logging to debug Firestore connection issues.

### 2. Potential Firestore Rules Issue
Firestore security rules might be blocking read/write operations.

### 3. Firebase Configuration
The Firebase project might not be properly configured or connected.

### 4. Collection Name Mismatch
The collection name might be different in Firestore console vs code.

## Complete Fix Implementation

### Step 1: Update UserService with Debug Logging

The `user_service.dart` has been updated with comprehensive logging:
- Logs when fetching residents
- Logs the number of documents received
- Logs each resident being processed
- Logs errors with full stack traces

### Step 2: Verify Firebase Configuration

Check these files exist and are properly configured:

**Android:**
- `admin_app/android/app/google-services.json`

**iOS:**
- `admin_app/ios/Runner/GoogleService-Info.plist`

**Web:**
- `admin_app/web/index.html` (Firebase config in script tags)

### Step 3: Check Firestore Security Rules

Go to Firebase Console → Firestore Database → Rules

**Current Rules (Too Restrictive):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Recommended Rules (For Development):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users to read/write (for testing)
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Recommended Rules (For Production):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow authenticated users to read all users
      allow read: if request.auth != null;
      
      // Allow authenticated users to create new users
      allow create: if request.auth != null;
      
      // Allow users to update their own document
      allow update: if request.auth != null && 
                       (request.auth.uid == resource.data.authUid ||
                        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
      
      // Only admins can delete
      allow delete: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Buildings collection
    match /buildings/{buildingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Flats collection
    match /flats/{flatId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Other collections
    match /{collection}/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 4: Verify Firestore Collection Structure

In Firebase Console → Firestore Database, verify:

1. Collection name is exactly: `users` (lowercase, plural)
2. Documents have the correct structure:
```
users (collection)
  └── [auto-generated-id] (document)
      ├── name: "John Doe"
      ├── phone: "9876543210"
      ├── email: "john@example.com" (optional)
      ├── residentId: "RES1234"
      ├── authEmail: "RES1234@lyvo.com"
      ├── authUid: "firebase_auth_uid"
      ├── password: "aB3xY9Zk"
      ├── role: "resident"
      ├── flatId: null or "A101"
      ├── flatLabel: null or "A101"
      ├── ownershipType: null or "Owner"
      ├── familyMembers: 1
      ├── status: "active" or "pending"
      ├── createdAt: Timestamp
      └── updatedAt: Timestamp
```

### Step 5: Test Data Creation Manually

To verify Firestore is working, create a test document manually:

1. Go to Firebase Console → Firestore Database
2. Click "Start collection"
3. Collection ID: `users`
4. Document ID: (auto-generate)
5. Add fields:
   - name (string): "Test User"
   - phone (string): "1234567890"
   - residentId (string): "RES9999"
   - role (string): "resident"
   - status (string): "active"
   - familyMembers (number): 1
   - createdAt (timestamp): (current time)
   - updatedAt (timestamp): (current time)
6. Save

Then check if this appears in the Admin App residents list.

### Step 6: Check Flutter Console Logs

Run the app with:
```bash
cd admin_app
flutter run
```

Watch the console for logs like:
```
UserService: Fetching all residents from Firestore
UserService: Received 5 residents from Firestore
UserService: Processing resident abc123: John Doe
```

If you see errors, they will appear as:
```
UserService ERROR: Failed to fetch residents: [error details]
```

### Step 7: Verify Firebase Authentication

1. Go to Firebase Console → Authentication
2. Check if admin account exists:
   - Email: admin@lyvo.com
   - Should be created automatically on first login

3. Check if resident accounts are being created when you add residents

### Step 8: Test the Complete Flow

#### Test 1: Admin Login
1. Open Admin App
2. Login with:
   - Email: admin@lyvo.com
   - Password: test@123
3. Should navigate to dashboard

#### Test 2: View Residents
1. Navigate to Residents tab (bottom nav)
2. Should see list of residents from Firestore
3. Check console logs for fetch operations

#### Test 3: Create New Resident
1. Go to Buildings tab
2. Select a building
3. Click on a vacant flat
4. Click "Assign Resident"
5. Switch to "Add New" tab
6. Fill in:
   - Name: "Test Resident"
   - Phone: "9999888877"
   - Family Members: 2
7. Click "Assign Resident"
8. Check console logs for creation process
9. Verify in Firebase Console that:
   - New document in `users` collection
   - New user in Authentication

#### Test 4: Assign Existing Resident
1. First, create a resident without assigning to flat
2. Go to Buildings tab
3. Select a building
4. Click on a vacant flat
5. Click "Assign Resident"
6. Stay on "Select Existing" tab
7. Should see list of available residents
8. Select a resident
9. Choose ownership type
10. Click "Assign Resident"
11. Verify flat is now occupied

#### Test 5: Resident Login (Future - Resident App)
1. Open Resident App
2. Login with:
   - Phone: 9999888877 OR Resident ID: RES1234
   - Password: (the auto-generated password)
3. Should authenticate and show profile

## Debugging Checklist

### ✅ Firebase Configuration
- [ ] `google-services.json` exists in `android/app/`
- [ ] `GoogleService-Info.plist` exists in `ios/Runner/`
- [ ] Firebase project ID matches in all config files
- [ ] App is registered in Firebase Console

### ✅ Firestore Setup
- [ ] Firestore Database is created (not Realtime Database)
- [ ] Database is in production mode or test mode
- [ ] Security rules allow authenticated read/write
- [ ] Collection name is exactly `users`

### ✅ Authentication Setup
- [ ] Email/Password authentication is enabled in Firebase Console
- [ ] Admin account exists (admin@lyvo.com)
- [ ] Resident accounts are being created

### ✅ Code Implementation
- [ ] `user_service.dart` has correct collection name
- [ ] `auth_service.dart` has correct authentication logic
- [ ] StreamBuilder is used for real-time updates
- [ ] Error handling is in place

### ✅ Network & Permissions
- [ ] App has internet permission (Android manifest)
- [ ] Device/emulator has internet connection
- [ ] No firewall blocking Firebase connections

## Common Errors and Solutions

### Error: "No residents found"
**Cause:** Firestore collection is empty or security rules blocking read
**Solution:**
1. Check Firestore console - is `users` collection populated?
2. Check security rules - do they allow read for authenticated users?
3. Check console logs - are there any error messages?

### Error: "Failed to create user"
**Cause:** Firebase Auth or Firestore write blocked
**Solution:**
1. Check Firebase Console → Authentication - is Email/Password enabled?
2. Check security rules - do they allow write for authenticated users?
3. Check console logs for specific error message

### Error: "No registered residents found" in Assign Modal
**Cause:** No residents in Firestore with flatId = null
**Solution:**
1. Create a test resident manually in Firestore with flatId: null
2. Or create a resident via "Add New" tab first
3. Check that getAvailableUsers() is filtering correctly

### Error: Authentication failed
**Cause:** Wrong credentials or Firebase Auth not configured
**Solution:**
1. Verify admin credentials: admin@lyvo.com / test@123
2. Check Firebase Console → Authentication - is admin user created?
3. Try creating admin account manually in Firebase Console

## Testing Commands

### Run with verbose logging:
```bash
cd admin_app
flutter run -v
```

### Check Firebase connection:
```bash
cd admin_app
flutter pub run firebase_core:check
```

### Clear app data and restart:
```bash
flutter clean
flutter pub get
flutter run
```

## Expected Console Output (Success)

```
UserService: Fetching all residents from Firestore
UserService: Received 3 residents from Firestore
UserService: Processing resident abc123: John Doe
UserService: Processing resident def456: Jane Smith
UserService: Processing resident ghi789: Bob Johnson
UserService: Found 3 available residents
```

## Expected Console Output (Error)

```
UserService: Fetching all residents from Firestore
UserService ERROR: Failed to fetch residents: [cloud_firestore/permission-denied] The caller does not have permission
```

This indicates security rules need to be updated.

## Next Steps

1. Apply the updated `user_service.dart` with logging
2. Update Firestore security rules
3. Run the app and check console logs
4. Create a test resident manually in Firestore
5. Verify it appears in the app
6. Test creating a new resident from the app
7. Verify it appears in Firestore Console

## Support

If issues persist after following this guide:
1. Share the console logs (especially errors)
2. Share screenshots of:
   - Firestore Console (users collection)
   - Firebase Authentication (users list)
   - Firestore Security Rules
3. Confirm Firebase project configuration is correct

