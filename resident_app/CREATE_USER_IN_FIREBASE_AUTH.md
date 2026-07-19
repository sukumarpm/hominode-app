# Create User in Firebase Authentication

## Problem
Your user exists in Firestore but NOT in Firebase Authentication, which is why login fails.

## Quick Fix

You need to create the user in Firebase Authentication. Here are your options:

### Option 1: Using Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `lyvo-app`
3. Click on "Authentication" in the left menu
4. Click on "Users" tab
5. Click "Add user" button
6. Enter:
   - Email: `preethampriyatharson07@gmail.com`
   - Password: `teste123`
7. Click "Add user"

✅ Done! Now you can login with this email and password.

### Option 2: Using Flutter Code (For Testing)

Create a temporary test file to register the user:

**File:** `lib/create_test_user.dart`

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> createTestUser() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    
    // Create user in Firebase Auth
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'preethampriyatharson07@gmail.com',
      password: 'teste123',
    );
    
    print('✅ User created successfully!');
    print('UID: ${userCredential.user?.uid}');
    print('Email: ${userCredential.user?.email}');
    
    // Sign out after creation
    await FirebaseAuth.instance.signOut();
    print('✅ User signed out');
    
  } catch (e) {
    print('❌ Error creating user: $e');
  }
}

void main() async {
  await createTestUser();
}
```

Then run:
```bash
flutter run lib/create_test_user.dart
```

### Option 3: Using Admin SDK (For Production)

If you have an admin panel, update it to create users in Firebase Auth:

```dart
// In your admin panel's create user function:
Future<void> createUserByAdmin({
  required String email,
  required String password,
  required String name,
  required String phone,
  required String flatId,
}) async {
  try {
    // Step 1: Create in Firebase Auth
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final uid = userCredential.user!.uid;
    
    // Step 2: Save to Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'phone': phone,
      'name': name,
      'flatId': flatId,
      'role': 'resident',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // DO NOT store password here!
    });
    
    print('✅ User created successfully in both Firebase Auth and Firestore');
    
  } catch (e) {
    print('❌ Error creating user: $e');
    rethrow;
  }
}
```

## After Creating the User

Once the user is created in Firebase Authentication:

1. Open the app
2. Go to Email tab
3. Enter email: `preethampriyatharson07@gmail.com`
4. Enter password: `teste123`
5. Click Login
6. ✅ Should login successfully!

OR

1. Enter phone: `7010678124`
2. Enter password: `teste123`
3. Click Login
4. ✅ Should login successfully!

## Verify User Exists

To check if user exists in Firebase Auth:

1. Go to Firebase Console
2. Authentication > Users
3. Look for `preethampriyatharson07@gmail.com`
4. If it's there, login will work!

## Important Notes

1. **Password in Firestore is NOT used** - Firebase Auth handles passwords
2. **Remove password from Firestore** - it's a security risk to store it there
3. **All future users** created by admin must be created in Firebase Auth first
4. **Phone number** in Firestore is only used for lookup, not authentication

## Status

After creating the user in Firebase Auth, the login will work with both email and phone number!
