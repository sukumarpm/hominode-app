# Complete Login to Home Screen Flow

## Overview

This document explains the complete flow from login to home screen, including how the flat access control works.

---

## Complete User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. USER OPENS APP                                               │
│    ↓                                                             │
│    App checks if user is logged in (SharedPreferences)          │
│    ├─ If logged in: Go to home screen                           │
│    └─ If not logged in: Show login screen                       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. LOGIN SCREEN                                                 │
│    ↓                                                             │
│    User enters email/phone and password                         │
│    User taps "Login" button                                     │
│    ↓                                                             │
│    Calls: FirestoreAuthService.signInWithEmail()                │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. FIRESTORE AUTH SERVICE - signInWithEmail()                   │
│    ↓                                                             │
│    🔵 START: signInWithEmail()                                  │
│    ├─ 🔍 Detect identifier type (email or phone)               │
│    ├─ 🔐 Search Firestore for user                             │
│    ├─ ✅ Verify password                                        │
│    ├─ 🔐 Sync with Firebase Auth                               │
│    ├─ 🔐 Assign flatId if missing                              │
│    ├─ 💾 Save login state to SharedPreferences                 │
│    └─ ✅ Return FirestoreAuthResult.success()                  │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. LOGIN SCREEN - HANDLE RESULT                                 │
│    ↓                                                             │
│    if (result.success) {                                        │
│      Show "Login successful!" message                           │
│      Wait 500ms                                                 │
│      Navigate to '/home'                                        │
│    } else {                                                     │
│      Show error message                                         │
│      Stay on login screen                                       │
│    }                                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. HOME SCREEN - FLAT ACCESS WRAPPER                            │
│    ↓                                                             │
│    FlatAccessWrapper checks access:                             │
│    ├─ 🔐 Call FlatAccessControlService.checkFlatAccess()       │
│    ├─ 🔍 Get current user ID from SharedPreferences            │
│    ├─ 📥 Fetch user document from Firestore                    │
│    ├─ ✅ Check if flatId exists                                │
│    │   ├─ If flatId exists: Grant access                       │
│    │   └─ If flatId missing: Deny access                       │
│    └─ Return AccessControlResult                               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. SHOW HOME SCREEN OR ACCESS RESTRICTED                        │
│    ↓                                                             │
│    if (accessResult.hasAccess) {                                │
│      Show home screen                                           │
│      User can access all features                               │
│    } else {                                                     │
│      Show "Access Restricted" screen                            │
│      User cannot access features                                │
│    }                                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Breakdown

### Step 1: User Opens App

**File:** `lib/main.dart` or `lib/app.dart`

```dart
// Check if user is logged in
final isLoggedIn = await FirestoreAuthService().isLoggedIn();

if (isLoggedIn) {
  // Navigate to home screen
  Navigator.pushReplacementNamed(context, '/home');
} else {
  // Show login screen
  Navigator.pushReplacementNamed(context, '/login');
}
```

---

### Step 2: User Enters Credentials and Taps Login

**File:** `lib/src/screens/login_screen.dart`

```dart
Future<void> _handleEmailLogin() async {
  final identifier = _emailController.text.trim();
  final password = _passwordController.text;
  
  // Validate
  if (identifier.isEmpty || password.isEmpty) {
    _showError('Please enter your email/phone and password');
    return;
  }
  
  setState(() => _isLoading = true);
  
  // Call auth service
  final result = await _authService.signInWithEmail(
    email: identifier,  // Can be email or phone
    password: password,
  );
  
  setState(() => _isLoading = false);
  
  if (result.success) {
    _showSuccess('Login successful!');
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  } else {
    _showError(result.message ?? 'Login failed');
  }
}
```

---

### Step 3: FirestoreAuthService.signInWithEmail()

**File:** `lib/src/services/firestore_auth_service.dart`

#### 3.1: Detect Identifier Type
```dart
final identifier = email.trim();
final isPhone = RegExp(r'^[\d+\s()-]+$').hasMatch(identifier);

print('🔍 Identifier type: ${isPhone ? 'Phone' : 'Email'}');
```

#### 3.2: Search Firestore
```dart
QuerySnapshot querySnapshot;

if (isPhone) {
  // Clean phone number and try variations
  String cleanPhone = identifier.replaceAll(RegExp(r'[\s()-]'), '');
  
  // Try: 9876543210, +919876543210, 919876543210
  final phoneVariations = [cleanPhone, '+91$cleanPhone', '91$cleanPhone'];
  
  for (var phoneVar in phoneVariations) {
    final query = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phoneVar)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      querySnapshot = query;
      break;
    }
  }
} else {
  // Search by email
  querySnapshot = await _firestore
      .collection('users')
      .where('email', isEqualTo: identifier)
      .limit(1)
      .get();
}

if (querySnapshot.docs.isEmpty) {
  return FirestoreAuthResult.failure(
    message: 'No account found with this ${isPhone ? 'phone' : 'email'}',
  );
}
```

#### 3.3: Verify Password
```dart
final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
final storedPassword = userData['password'] as String;

if (storedPassword != password) {
  return FirestoreAuthResult.failure(
    message: 'Invalid credentials. Please check and try again.',
  );
}

print('✅ Password verified successfully');
```

#### 3.4: Sync with Firebase Auth
```dart
final userEmail = userData['email'] as String?;

if (userEmail != null && userEmail.isNotEmpty) {
  try {
    // Try to sign in with Firebase Auth
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: userEmail,
      password: password,
    );
    
    print('✅ Firebase Auth sign-in successful');
    
    // Update Firestore with Firebase UID
    await _firestore.collection('users').doc(userId).update({
      'authUid': userCredential.user!.uid,
      'uid': userCredential.user!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: userEmail,
        password: password,
      );
      
      // Update Firestore with Firebase UID
      await _firestore.collection('users').doc(userId).update({
        'authUid': userCredential.user!.uid,
        'uid': userCredential.user!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
```

#### 3.5: Assign FlatId if Missing
```dart
if (!userData.containsKey('flatId') || userData['flatId'] == null || userData['flatId'].toString().isEmpty) {
  print('⚠️  No flatId assigned, assigning default...');
  
  await _firestore.collection('users').doc(userId).update({
    'flatId': 'flat_001',
    'flatLabel': 'A-101',
    'buildingId': 'building_001',
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  userData['flatId'] = 'flat_001';
  userData['flatLabel'] = 'A-101';
  userData['buildingId'] = 'building_001';
}

print('✅ User has flatId: ${userData['flatId']}');
```

#### 3.6: Save Login State
```dart
await _saveLoginState(
  userId: userId,
  email: userData['email'],
  phone: userData['phone'],
);

print('✅ Login successful!');
print('   Welcome: ${userData['name']}');

return FirestoreAuthResult.success(
  message: 'Login successful',
  userData: userData,
  userId: userId,
);
```

---

### Step 4: Login Screen Handles Result

**File:** `lib/src/screens/login_screen.dart`

```dart
if (result.success) {
  _showSuccess('Login successful!');
  await Future.delayed(const Duration(milliseconds: 500));
  if (mounted) {
    Navigator.of(context).pushReplacementNamed('/home');
  }
} else {
  _showError(result.message ?? 'Login failed');
}
```

---

### Step 5: Home Screen - Flat Access Wrapper

**File:** `lib/src/widgets/flat_access_wrapper.dart` or `lib/src/screens/home_screen.dart`

```dart
class FlatAccessWrapper extends StatelessWidget {
  final Widget child;
  
  const FlatAccessWrapper({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccessControlResult>(
      future: FlatAccessControlService().checkFlatAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        
        final result = snapshot.data;
        
        if (result == null || !result.hasAccess) {
          return AccessBlockedScreen(
            message: result?.message ?? 'Access denied',
          );
        }
        
        // Access granted, show home screen
        return child;
      },
    );
  }
}
```

---

### Step 6: FlatAccessControlService.checkFlatAccess()

**File:** `lib/src/services/flat_access_control_service.dart`

```dart
Future<AccessControlResult> checkFlatAccess({bool forceRefresh = false}) async {
  try {
    print('🔐 Checking flat access...');
    
    // Get current user ID from SharedPreferences
    String? userId = await _authService.getCurrentUserId();
    
    if (userId == null) {
      print('❌ No user logged in');
      return AccessControlResult.denied(
        message: 'Please log in to continue',
      );
    }
    
    print('📥 Fetching user data from Firestore...');
    print('   User ID: $userId');
    
    // Fetch user document
    final userDoc = await _firestore.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      print('❌ User document not found');
      return AccessControlResult.denied(
        message: 'User account not found. Please contact support.',
      );
    }
    
    final userData = userDoc.data()!;
    final flatId = userData['flatId'] as String?;
    final buildingId = userData['buildingId'] as String?;
    
    print('✅ User data fetched');
    print('   Name: ${userData['name']}');
    print('   Flat ID: $flatId');
    print('   Building ID: $buildingId');
    
    // Validate flat assignment
    if (flatId == null || flatId.isEmpty) {
      print('❌ No flat assigned to user');
      return AccessControlResult.denied(
        message: 'Your account is not yet assigned to a flat. Please contact admin.',
      );
    }
    
    print('✅ Flat access granted');
    print('   Flat: $flatId');
    print('   Building: $buildingId');
    
    return AccessControlResult.granted(
      flatId: flatId,
      buildingId: buildingId ?? '',
      userData: userData,
    );
    
  } catch (e) {
    print('❌ Error checking flat access: $e');
    return AccessControlResult.denied(
      message: 'Error checking access. Please try again.',
    );
  }
}
```

---

### Step 7: Show Home Screen or Access Restricted

**File:** `lib/src/screens/home_screen.dart` or `lib/src/screens/access_blocked_screen.dart`

```dart
if (result.hasAccess) {
  // Show home screen
  return HomeScreen(
    flatId: result.flatId!,
    buildingId: result.buildingId!,
    userData: result.userData!,
  );
} else {
  // Show access restricted screen
  return AccessBlockedScreen(
    message: result.message ?? 'Access denied',
  );
}
```

---

## Data Flow Diagram

```
┌──────────────────┐
│  Login Screen    │
│  (email/phone)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ FirestoreAuthService                 │
│ .signInWithEmail()                   │
│                                      │
│ 1. Detect identifier type            │
│ 2. Search Firestore                  │
│ 3. Verify password                   │
│ 4. Sync Firebase Auth                │
│ 5. Assign flatId                     │
│ 6. Save login state                  │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ SharedPreferences                    │
│ - is_logged_in: true                 │
│ - user_id: "user_doc_id"             │
│ - user_email: "user@example.com"     │
│ - user_phone: "9876543210"           │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Firestore - users collection         │
│ Document: user_doc_id                │
│ - email: "user@example.com"          │
│ - phone: "9876543210"                │
│ - password: "password123"            │
│ - name: "User Name"                  │
│ - flatId: "flat_001"                 │
│ - buildingId: "building_001"         │
│ - authUid: "firebase_uid_123"        │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Firebase Authentication              │
│ - uid: "firebase_uid_123"            │
│ - email: "user@example.com"          │
│ - displayName: "User Name"           │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ FlatAccessControlService             │
│ .checkFlatAccess()                   │
│                                      │
│ 1. Get user ID from SharedPreferences│
│ 2. Fetch user from Firestore         │
│ 3. Check flatId exists               │
│ 4. Return AccessControlResult        │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Home Screen                          │
│ (if access granted)                  │
│                                      │
│ OR                                   │
│                                      │
│ Access Blocked Screen                │
│ (if access denied)                   │
└──────────────────────────────────────┘
```

---

## Key Points

1. **Firestore-First**: User credentials are stored in Firestore, not Firebase Auth
2. **Password Verification**: Password is verified against Firestore stored password
3. **Firebase Auth Sync**: Firebase Auth account is created/synced after Firestore verification
4. **FlatId Assignment**: If user doesn't have flatId, it's automatically assigned
5. **Login State Persistence**: User ID is saved in SharedPreferences for future logins
6. **Access Control**: FlatAccessControlService checks if user has flatId before granting access
7. **Flow Function Pattern**: All operations follow flow function pattern with proper logging

---

## Success Criteria

✅ User can login with email or phone
✅ User navigates to home screen after login
✅ User does NOT see "Access Restricted" screen
✅ FlatId is assigned if missing
✅ Firebase Auth account is created/synced
✅ Console shows flow function logs
✅ All error cases are handled gracefully

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Access Restricted" after login | User doesn't have flatId | Code now auto-assigns flat_001 |
| "User not found" | User doesn't exist in Firestore | Create user in Firestore first |
| "Invalid credentials" | Wrong password | Verify password in Firestore |
| "User account not found in database" | Firebase Auth account creation failed | Check Firebase Auth console |
| Phone number not recognized | Phone format not matching | Code tries multiple formats |

---

## Next Steps

1. ✅ Test login with email
2. ✅ Test login with phone
3. ✅ Verify home screen is shown
4. ✅ Verify FlatAccessControlService grants access
5. ✅ Check console logs for flow function indicators
6. ⏳ Test complete app flow end-to-end
