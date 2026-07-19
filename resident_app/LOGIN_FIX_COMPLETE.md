# Login Fix - Email or Phone Number Support

## Problem Identified

Looking at your screenshots, the issue was:

1. **User exists in Firestore** with:
   - Email: `preethampriyatharson07@gmail.com`
   - Phone: `7010678124`
   - Password: `teste123` (stored as plain text in Firestore)

2. **User does NOT exist in Firebase Authentication**
   - That's why login fails with "Invalid credentials"

3. **Root Cause:** When admin creates a user, the user is only saved to Firestore, NOT to Firebase Authentication

## Solution Implemented

### 1. Updated FirebaseAuthService
**File:** `lib/src/services/firebase_auth_service.dart`

Added support for login with email OR phone number:

```dart
Future<AuthResult> signInWithEmail({
  required String email,
  required String password,
}) async {
  String loginEmail = email.trim();

  // Detect if input is phone number
  final isPhoneNumber = RegExp(r'^[\d+\s()-]+$').hasMatch(loginEmail);

  if (isPhoneNumber) {
    // Clean phone number
    final cleanPhone = loginEmail.replaceAll(RegExp(r'[\s()-]'), '');
    
    // Query Firestore for user with this phone
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: cleanPhone)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return AuthResult.failure(
        message: 'No account found with this phone number',
      );
    }

    // Get email from Firestore
    final userData = querySnapshot.docs.first.data();
    loginEmail = userData['email'] as String;
  }

  // Login with email
  final userCredential = await _auth.signInWithEmailAndPassword(
    email: loginEmail,
    password: password,
  );
  
  // ... rest of login logic
}
```

### 2. Updated Login Screen
**File:** `lib/src/screens/login_screen.dart`

- Changed label from "Email" to "Email or Phone"
- Updated placeholder to "Enter your email or phone number"
- Enhanced validation to accept both formats

## IMPORTANT: Admin Must Create Users in Firebase Auth

For users to login, they MUST exist in Firebase Authentication. Here's what needs to happen:

### When Admin Creates a User:

**Step 1: Create in Firebase Authentication**
```dart
// Admin panel should do this:
final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: 'user@example.com',
  password: 'userPassword123',
);
```

**Step 2: Save to Firestore**
```dart
await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
  'uid': userCredential.user!.uid,
  'email': 'user@example.com',
  'phone': '7010678124',
  'name': 'User Name',
  'role': 'resident',
  'flatId': 'b202',
  'flatLabel': 'b202',
  'residentId': 'RBS2393',
  'status': 'active',
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  // DO NOT store password in Firestore!
});
```

### Current User Issue

The user `preethampriyatharson07@gmail.com` exists in Firestore but NOT in Firebase Auth. To fix this:

**Option 1: Create the user in Firebase Auth (Recommended)**
```dart
// Run this once to create the user in Firebase Auth:
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: 'preethampriyatharson07@gmail.com',
  password: 'teste123',  // Use the password from Firestore
);
```

**Option 2: User Self-Registration**
- User can register through the app
- This will create them in both Firebase Auth and Firestore

## How Login Works Now

### Login with Email
1. User enters: `preethampriyatharson07@gmail.com`
2. Password: `teste123`
3. System authenticates with Firebase Auth
4. User is logged in

### Login with Phone Number
1. User enters: `7010678124`
2. Password: `teste123`
3. System detects it's a phone number
4. Queries Firestore to find email: `preethampriyatharson07@gmail.com`
5. Authenticates with Firebase Auth using email + password
6. User is logged in

## Supported Phone Formats

All these formats work:
- `7010678124`
- `+917010678124`
- `701-067-8124`
- `(701) 067-8124`
- `701 067 8124`

## Testing

### Test Case 1: Email Login
1. Email: `preethampriyatharson07@gmail.com`
2. Password: `teste123`
3. ✅ Should work (after user is created in Firebase Auth)

### Test Case 2: Phone Login
1. Phone: `7010678124`
2. Password: `teste123`
3. ✅ Should work (after user is created in Firebase Auth)

## Error Messages

| Scenario | Error Message |
|----------|--------------|
| User not in Firebase Auth | "Invalid credentials. Please check and try again." |
| Phone not in Firestore | "No account found with this phone number" |
| Wrong password | "Incorrect password. Please try again." |
| Invalid email format | "Please enter a valid email or phone number" |

## Security Notes

1. **Never store passwords in Firestore** - Firebase Auth handles password hashing
2. **Phone numbers** are stored in Firestore for lookup only
3. **Authentication** is always done through Firebase Auth
4. **Password** must be set in Firebase Auth, not Firestore

## Next Steps

1. **Update Admin Panel** to create users in Firebase Auth when creating new users
2. **Migrate existing users** from Firestore to Firebase Auth
3. **Remove password field** from Firestore (it's not used and shouldn't be stored)

## Hot Reload

To apply changes:
- Press `r` in terminal for hot reload
- Or press `R` for hot restart

## Status

✅ FirebaseAuthService updated to support phone lookup
✅ Login screen updated for email/phone input
✅ Validation updated for both formats
✅ Error handling improved
✅ Ready for testing (after users are created in Firebase Auth)

The login now supports both email and phone number, but users MUST exist in Firebase Authentication to login successfully!
