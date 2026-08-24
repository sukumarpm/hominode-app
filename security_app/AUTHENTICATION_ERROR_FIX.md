# Authentication Error Fix

## Error Message
```
Authentication error: The supplied auth credential is incorrect, malformed or has expired.
```

## Root Cause
The error occurred because:
1. Firestore stores passwords in plain text
2. Firebase Auth has its own password storage (hashed)
3. The app was trying to authenticate with Firebase Auth using a password that doesn't match Firebase's stored password
4. Firebase Auth account might not exist or have a different password than Firestore

## Solution
Updated the authentication flow to:

1. **Verify against Firestore first** - Check if email/phone and password match Firestore data
2. **Skip Firebase Auth verification** - Don't try to sign in with Firebase Auth password
3. **Create Firebase Auth account** - If Firestore password matches, create a new Firebase Auth account with the same password
4. **Handle existing accounts** - If account already exists in Firebase Auth, sign in normally
5. **Store UID** - Update Firestore with the Firebase UID for future logins

## Updated Authentication Flow

```
User enters email/phone + password
    ↓
Query Firestore staff collection
    ↓
Find matching email or phone
    ↓
Compare password with Firestore stored password
    ↓
If password doesn't match:
    └─ Return error: "Incorrect password"
    ↓
If password matches:
    ├─ Check if Firebase UID exists in Firestore
    │  ├─ If UID exists:
    │  │  └─ Try Firebase Auth sign in
    │  └─ If UID doesn't exist:
    │     └─ Continue to create account
    ├─ Create Firebase Auth account with same password
    ├─ Update Firestore with new UID
    └─ Return success
    ↓
Navigate to Dashboard
```

## Key Changes in AuthService

### Before
```dart
// Only tried Firebase Auth
final userCredential = await _auth.signInWithEmailAndPassword(
  email: staffEmail,
  password: password,
);
// Failed if user didn't exist in Firebase Auth
```

### After
```dart
// 1. Verify password against Firestore
if (storedPassword != password) {
  return error;
}

// 2. Try Firebase Auth if UID exists
if (firebaseUid != null && firebaseUid.isNotEmpty) {
  try {
    final userCredential = await _auth.signInWithEmailAndPassword(...);
    return success;
  } on FirebaseAuthException {
    // Continue to create new account
  }
}

// 3. Create Firebase Auth account
final userCredential = await _auth.createUserWithEmailAndPassword(
  email: staffEmail,
  password: password,
);

// 4. Update Firestore with UID
await _firestore.collection('staff').doc(staffId).update({
  'uid': userCredential.user!.uid,
});
```

## Error Handling

The updated flow handles these scenarios:

| Scenario | Action | Result |
|----------|--------|--------|
| Email/phone not found | Return error | "Staff member not found" |
| Password doesn't match | Return error | "Incorrect password" |
| Firebase UID exists & sign in works | Return success | Login successful |
| Firebase UID exists & sign in fails | Create new account | Create and login |
| Firebase UID doesn't exist | Create account | Create and login |
| Account already exists in Firebase | Sign in | Login successful |
| Firebase Auth error | Return error | "Authentication failed" |

## Testing the Fix

### Test Credentials
```
Email: sibi@gmail.com
Phone: +91 9234567891
Password: BCDEFGHIJKLM
```

### Expected Behavior
1. First login: Creates Firebase Auth account, updates Firestore with UID
2. Subsequent logins: Uses existing Firebase Auth account
3. Dashboard displays: User's actual name and gate assignment
4. Profile displays: All staff details from Firestore

### Test Steps
1. Launch app
2. Enter email: `sibi@gmail.com`
3. Enter password: `BCDEFGHIJKLM`
4. Click Login
5. Should navigate to dashboard
6. Verify user name and gate display correctly

## Security Implications

### Current Implementation
- Passwords stored in plain text in Firestore
- Firebase Auth handles password hashing
- First login creates Firebase Auth account
- Subsequent logins use Firebase Auth

### Production Recommendations
1. **Hash Passwords**: Use bcrypt or similar for Firestore passwords
2. **Remove Plain Text**: Don't store passwords in Firestore
3. **Use Firebase Auth Only**: Let Firebase Auth handle all authentication
4. **Implement Password Reset**: Add forgot password functionality
5. **Rate Limiting**: Limit login attempts
6. **Audit Logging**: Log all authentication events

## Files Modified

- `lib/services/auth_service.dart` - Updated `loginWithEmailOrPhone()` method

## Verification

All files compile without errors:
```
✓ lib/services/auth_service.dart
✓ lib/screens/login_screen.dart
✓ lib/screens/security_dashboard_screen.dart
✓ lib/screens/profile_screen.dart
✓ lib/models/security_user_model.dart
✓ lib/main.dart
```

## Troubleshooting

### Still Getting Authentication Error
1. Verify Firestore password matches exactly (case-sensitive)
2. Check for extra spaces in password field
3. Ensure email/phone exists in Firestore
4. Clear app cache and reinstall

### Login Succeeds but Dashboard Shows "Loading..."
1. Check Firestore security rules
2. Verify staff document has all required fields
3. Check network connectivity
4. Verify UID was updated in Firestore

### Profile Data Not Displaying
1. Ensure UID field is populated in Firestore
2. Check Firestore security rules allow read access
3. Verify all required fields exist in staff document

## Next Steps

1. Test login with provided credentials
2. Verify dashboard displays correctly
3. Test profile screen
4. Implement password hashing for production
5. Add additional security measures
