# Firebase Authentication + Firestore Sync - Complete

## Overview

When a new user registers or logs in, their data is automatically stored in both Firebase Authentication and Firestore database according to the flow.

## Implementation Status: ✅ COMPLETE

## Registration Flow

### Step 1: User Fills Registration Form
- Name (required)
- Email (required)
- Phone (optional)
- Password (required, min 6 characters)
- Confirm Password (required, must match)

### Step 2: Firebase Authentication
```dart
// Create user in Firebase Auth
final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// Get the user
final User? user = userCredential.user;

// Update display name
await user.updateDisplayName(name);
```

### Step 3: Firestore Database
```dart
// Save user data to Firestore users collection
await _firestore.collection('users').doc(uid).set({
  'authUid': uid,              // Link to Firebase Auth
  'uid': uid,                  // Backward compatibility
  'name': name,                // User's full name
  'email': email,              // User's email
  'phone': phone,              // User's phone (optional)
  'role': 'resident',          // Default role
  'flatId': null,              // Assigned by admin later
  'flatLabel': null,           // Assigned by admin later
  'buildingId': null,          // Assigned by admin later
  'profileImage': null,        // Profile photo URL
  'photoURL': null,            // Alternative photo field
  'isActive': true,            // Account status
  'createdAt': Timestamp,      // Registration timestamp
  'updatedAt': Timestamp,      // Last update timestamp
});
```

### Step 4: Navigate to Home
- User is automatically logged in
- Redirected to dashboard/home screen
- Can access app features

## Login Flow

### Step 1: User Enters Credentials
- Email or Phone Number
- Password

### Step 2: Identifier Resolution
```dart
// Check if input is phone number
if (isPhoneNumber) {
  // Query Firestore to find email by phone
  final querySnapshot = await _firestore
      .collection('users')
      .where('phone', isEqualTo: cleanPhone)
      .limit(1)
      .get();
  
  // Get email from Firestore
  loginEmail = userData['email'];
}
```

### Step 3: Firebase Authentication
```dart
// Login with email and password
final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
  email: loginEmail,
  password: password,
);
```

### Step 4: Firestore Verification
```dart
// Check if user exists in Firestore
final userDoc = await _firestore
    .collection('users')
    .doc(user.uid)
    .get();

if (!userDoc.exists) {
  // Create Firestore profile if missing
  await _saveUserToFirestore(...);
} else {
  // Update authUid if missing
  if (!data.containsKey('authUid')) {
    await _firestore.collection('users').doc(user.uid).update({
      'authUid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

### Step 5: Navigate to Home
- User logged in successfully
- Redirected to dashboard
- User data available throughout app

## Data Structure

### Firebase Authentication
```
Authentication Users:
  - UID: auto-generated unique ID
  - Email: user's email
  - Display Name: user's full name
  - Phone Number: user's phone (if provided)
  - Photo URL: profile picture URL
  - Email Verified: false (initially)
  - Created: timestamp
  - Last Sign In: timestamp
```

### Firestore Database
```
users/
  {uid}/
    authUid: string (Firebase Auth UID)
    uid: string (same as authUid, for compatibility)
    name: string
    email: string
    phone: string | null
    role: string (resident/admin)
    flatId: string | null (assigned by admin)
    flatLabel: string | null (assigned by admin)
    buildingId: string | null (assigned by admin)
    profileImage: string | null
    photoURL: string | null
    isActive: boolean
    createdAt: timestamp
    updatedAt: timestamp
```

## Key Features

### ✅ Automatic Sync
- Registration creates both Auth and Firestore records
- Login verifies and creates Firestore if missing
- Updates authUid field if missing

### ✅ Phone Number Support
- Users can login with phone number
- System looks up email from Firestore
- Seamless authentication

### ✅ Profile Management
- Update name, phone, photo
- Updates both Auth and Firestore
- Real-time sync

### ✅ Error Handling
- User-friendly error messages
- Handles all Firebase errors
- Graceful fallbacks

### ✅ Backward Compatibility
- Supports existing users
- Adds authUid to old records
- No data loss

## Files Involved

### 1. Registration Screen
**File:** `lib/src/screens/register_screen.dart`

**Features:**
- Form validation
- Password confirmation
- Loading states
- Error handling
- Success navigation

### 2. Login Screen
**File:** `lib/src/screens/login_screen.dart`

**Features:**
- Phone OTP tab
- Email/Password tab
- Forgot password
- Phone/Email login support

### 3. Auth Service
**File:** `lib/src/services/firebase_auth_firestore_service.dart`

**Methods:**
- `registerWithEmailPassword()` - Register new user
- `loginWithEmailPassword()` - Login existing user
- `_saveUserToFirestore()` - Save to Firestore
- `getUserProfile()` - Get user data
- `updateUserProfile()` - Update user data
- `signOut()` - Logout user

## Testing

### Test Registration

**1. Open app**
```bash
flutter run -d <device_id>
```

**2. Navigate to Register**
- Tap "Register" or "Create Account"

**3. Fill form:**
- Name: John Doe
- Email: john@test.com
- Phone: 9876543210 (optional)
- Password: password123
- Confirm Password: password123

**4. Tap "Create Account"**

**5. Verify:**
- ✅ Success message shown
- ✅ Redirected to home/dashboard
- ✅ Check Firebase Console → Authentication
  - User exists with email
  - Display name set
- ✅ Check Firebase Console → Firestore → users
  - Document exists with UID
  - All fields populated
  - authUid field present

### Test Login

**1. Logout if logged in**

**2. Navigate to Login**

**3. Test Email Login:**
- Email: john@test.com
- Password: password123
- Tap "Login"

**4. Verify:**
- ✅ Login successful
- ✅ Redirected to home
- ✅ User data loaded

**5. Logout**

**6. Test Phone Login:**
- Email/Phone: 9876543210
- Password: password123
- Tap "Login"

**7. Verify:**
- ✅ System finds email by phone
- ✅ Login successful
- ✅ Same user logged in

### Test Existing Users

**For users created before this update:**

**1. Login with existing credentials**

**2. System automatically:**
- ✅ Checks Firestore document
- ✅ Adds authUid if missing
- ✅ Updates timestamp
- ✅ No data loss

## Admin Assignment Flow

### After Registration

**1. User registers**
- Account created
- flatId, flatLabel, buildingId are null
- User blocked from app features (flat access control)

**2. Admin assigns flat**
- Admin logs into admin panel
- Assigns user to flat
- Updates Firestore:
  ```dart
  await _firestore.collection('users').doc(userId).update({
    'flatId': 'flat_001',
    'flatLabel': 'A-101',
    'buildingId': 'building_001',
    'updatedAt': FieldValue.serverTimestamp(),
  });
  ```

**3. User gains access**
- Flat access control detects flatId
- User can now access app features
- Data filtered by flatId/buildingId

## Security

### Firebase Authentication
- Secure password hashing
- Email verification available
- Password reset via email
- Session management

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      // Users can read their own data
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Users can update their own profile (limited fields)
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['name', 'phone', 'profileImage', 'photoURL', 'updatedAt']);
      
      // Only admins can create/delete users
      allow create, delete: if request.auth != null && 
                               get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Error Handling

### Registration Errors
- **Email already in use** → "This email is already registered. Please login instead."
- **Invalid email** → "Please enter a valid email address."
- **Weak password** → "Password is too weak. Please use at least 6 characters."
- **Network error** → "Network error. Please check your internet connection."

### Login Errors
- **User not found** → "No account found with this email. Please register first."
- **Wrong password** → "Incorrect password. Please try again."
- **Invalid credential** → "Invalid email or password. Please try again."
- **Too many requests** → "Too many failed attempts. Please try again later."

## Benefits

### For Users
- ✅ Simple registration process
- ✅ Multiple login options (email/phone)
- ✅ Secure authentication
- ✅ Profile management
- ✅ Password reset

### For Admins
- ✅ User management
- ✅ Flat assignment
- ✅ Role management
- ✅ Activity tracking

### For Developers
- ✅ Clean code structure
- ✅ Error handling
- ✅ Logging for debugging
- ✅ Backward compatibility
- ✅ Easy to maintain

## Summary

✅ **Registration** creates both Auth and Firestore records
✅ **Login** verifies and syncs data
✅ **Phone login** supported via Firestore lookup
✅ **Profile updates** sync to both systems
✅ **Error handling** comprehensive and user-friendly
✅ **Backward compatible** with existing users
✅ **Admin assignment** flow integrated
✅ **Security** rules in place
✅ **Testing** guide provided

The authentication system is complete and production-ready!
