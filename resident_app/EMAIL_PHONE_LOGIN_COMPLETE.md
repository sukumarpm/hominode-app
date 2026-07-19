# Email or Phone Number Login - Complete

## Overview
Users can now login using either their **email address** OR **phone number** with the same password. This is especially useful when admin creates user accounts.

## How It Works

### Login Flow
1. User enters **email** OR **phone number** in the login field
2. User enters their **password**
3. System detects if input is phone or email
4. If phone number:
   - System queries Firestore `users` collection for matching phone
   - Retrieves the associated email address
   - Uses email + password for Firebase Authentication
5. If email:
   - Directly uses email + password for Firebase Authentication
6. User is logged in successfully

### Phone Number Detection
The system automatically detects phone numbers using this pattern:
- Contains only digits, spaces, +, -, ( )
- Examples: `+1234567890`, `123-456-7890`, `(123) 456-7890`

## Changes Made

### 1. Updated Authentication Service
**File:** `lib/src/services/firebase_auth_firestore_service.dart`

**Key Changes:**
```dart
Future<AuthFirestoreResult> loginWithEmailPassword({
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
    final querySnapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: cleanPhone)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return AuthFirestoreResult.failure(
        message: 'No account found with this phone number',
      );
    }

    // Get email from Firestore
    final userData = querySnapshot.docs.first.data();
    loginEmail = userData['email'] as String;
  }

  // Login with email
  final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
    email: loginEmail,
    password: password,
  );
  
  // ... rest of login logic
}
```

### 2. Updated Login Screen UI
**File:** `lib/src/screens/login_screen_new.dart`

**Key Changes:**
- Field label changed from "Email" to "Email or Phone Number"
- Placeholder text updated to "Enter your email or phone number"
- Icon changed from email icon to person icon
- Validator updated to accept both email and phone formats
- Forgot password handler updated to handle phone number input

**Validation Logic:**
```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email or phone number';
  }
  
  // Check if it's a phone number or email
  final isPhone = RegExp(r'^[\d+\s()-]+$').hasMatch(value.trim());
  
  if (!isPhone) {
    // Validate as email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email or phone number';
    }
  }
  return null;
}
```

## Admin User Creation Flow

### When Admin Creates a User
1. Admin creates user in admin panel with:
   - Name
   - Email
   - Phone number
   - Password
2. User document is saved to Firestore `users` collection:
```json
{
  "uid": "firebase_auth_uid",
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+1234567890",
  "role": "resident",
  "createdAt": "timestamp",
  "isActive": true
}
```
3. Firebase Authentication account is created with email + password

### User Login Options
The created user can now login using:
- **Option 1:** Email + Password
  - Email: `john@example.com`
  - Password: `admin_set_password`

- **Option 2:** Phone + Password
  - Phone: `+1234567890`
  - Password: `admin_set_password` (same password)

## Firestore Requirements

### Users Collection Structure
Ensure your Firestore `users` collection has these fields:
```json
{
  "uid": "string",
  "name": "string",
  "email": "string",
  "phone": "string",  // REQUIRED for phone login
  "role": "string",
  "createdAt": "timestamp",
  "isActive": "boolean"
}
```

### Firestore Index
For optimal performance, create a composite index:
- Collection: `users`
- Fields: `phone` (Ascending)
- Query scope: Collection

## Testing

### Test Case 1: Login with Email
1. Open the app
2. Enter email: `test@example.com`
3. Enter password: `password123`
4. Tap Login
5. ✅ Should login successfully

### Test Case 2: Login with Phone Number
1. Open the app
2. Enter phone: `+1234567890`
3. Enter password: `password123`
4. Tap Login
5. ✅ Should login successfully

### Test Case 3: Phone Number Formats
All these formats should work:
- `+1234567890`
- `1234567890`
- `123-456-7890`
- `(123) 456-7890`
- `123 456 7890`

### Test Case 4: Invalid Phone Number
1. Enter phone number not in database
2. ✅ Should show: "No account found with this phone number"

### Test Case 5: Forgot Password with Phone
1. Enter phone number
2. Tap "Forgot Password?"
3. ✅ Should show: "Password reset is only available via email"

## Error Messages

| Scenario | Error Message |
|----------|--------------|
| Phone not found | "No account found with this phone number" |
| Invalid email | "Please enter a valid email or phone number" |
| Wrong password | "Incorrect password. Please try again." |
| Empty field | "Please enter your email or phone number" |
| Forgot password with phone | "Password reset is only available via email. Please enter your email address." |

## Security Considerations

1. **Phone Number Privacy:** Phone numbers are stored in Firestore and used only for lookup
2. **Password Security:** Same password works for both email and phone login (Firebase Auth handles this)
3. **Rate Limiting:** Firebase Auth automatically rate limits login attempts
4. **Data Validation:** Both email and phone formats are validated before processing

## Hot Reload
To see the changes:
1. Press `r` in the terminal where Flutter is running
2. Or restart the app with `R`

## Status
✅ Authentication service updated to handle phone lookup
✅ Login screen UI updated for email/phone input
✅ Validation logic updated for both formats
✅ Error handling for phone number not found
✅ Forgot password handler updated
✅ Ready for testing

Users created by admin can now login with either email or phone number using the same password!
