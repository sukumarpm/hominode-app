# Updated Authentication Flow

## Overview
The authentication flow has been updated to use **Email/Phone + Password** instead of OTP-based authentication.

## Changes Made

### 1. Login Screen (`login_screen.dart`)
**Before:** Mobile number → Send OTP → Verify OTP
**After:** Email/Phone + Password → Login directly

**Features:**
- Single input field accepts both email and phone number
- Password field with show/hide toggle
- Forgot Password functionality
- Direct login without OTP verification
- Firebase Authentication integration

**UI Components:**
- Email or Phone Number input
- Password input with visibility toggle
- Forgot Password link
- Login button with loading state
- Register link

### 2. Create Account Screen (`create_account_screen.dart`)
**Before:** Name, Phone, Block, Flat → OTP verification
**After:** Name, Email/Phone, Password, Block, Flat → Create account directly

**Features:**
- Email or phone number input
- Password with validation (min 8 chars, uppercase, lowercase, number)
- Block and Flat number fields
- Firebase account creation
- Profile name update
- Direct account creation without OTP

**UI Components:**
- Full Name input
- Email or Phone Number input
- Password input with visibility toggle
- Block and Flat Number inputs (side by side)
- Continue button with loading state

## Authentication Logic

### Login Flow
```dart
1. User enters email or phone number
2. User enters password
3. System validates input format
4. If email: signInWithEmail(email, password)
5. If phone: Convert to email format (phone@resident.app) → signInWithEmail
6. On success: Navigate to home
7. On failure: Show error message
```

### Registration Flow
```dart
1. User enters full name
2. User enters email or phone number
3. User enters password (validated for strength)
4. User enters block and flat number
5. System validates all inputs
6. If email: createAccountWithEmail(email, password)
7. If phone: Convert to email format → createAccountWithEmail
8. Update user profile with display name
9. On success: Navigate to setup profile
10. On failure: Show error message
```

### Password Reset Flow
```dart
1. User clicks "Forgot Password?"
2. Dialog appears requesting email
3. User enters email
4. System sends password reset email via Firebase
5. User receives email with reset link
6. User clicks link and resets password
```

## Phone Number Handling

Since Firebase Auth requires either:
- Email + Password
- Phone + OTP

We've implemented a hybrid approach for phone numbers:
- Phone numbers are converted to email format: `{phone}@resident.app`
- Example: `9876543210` becomes `9876543210@resident.app`
- This allows password-based authentication with phone numbers
- Users can login with either their phone number or the generated email

## Validation Rules

### Email
- Must be valid email format
- Example: `user@example.com`

### Phone Number
- Must be 10 digits
- Must start with 6-9 (Indian format)
- Example: `9876543210`

### Password
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- Example: `SecurePass123`

## Firebase Integration

### Services Used
- `FirebaseAuthService` - Main authentication service
- `firebase_auth` package - Firebase Authentication SDK

### Methods
- `signInWithEmail()` - Login with email/password
- `createAccountWithEmail()` - Create new account
- `sendPasswordResetEmail()` - Send password reset link
- `updateProfile()` - Update user display name
- `validateEmail()` - Validate email format
- `validatePhoneNumber()` - Validate phone format
- `validatePassword()` - Validate password strength

## Error Handling

All authentication operations return `AuthResult` with:
- `success`: Boolean indicating operation success
- `message`: User-friendly error/success message
- `errorCode`: Firebase error code for specific handling
- `user`: Firebase User object (when applicable)

### Common Errors
- Invalid email format
- Invalid phone number
- Weak password
- Email already in use
- Wrong password
- User not found
- Network error

## Testing

### Test Accounts
Create test accounts using:
- Email: `test@example.com` / Password: `Test1234`
- Phone: `9876543210` / Password: `Test1234`

### Demo Flow
1. Open app → Login screen
2. Click "Register" → Create account
3. Fill in details with valid email/phone and password
4. Click "Continue" → Account created
5. Return to login → Enter credentials
6. Click "Login" → Navigate to home

## Files Modified

1. `lib/src/screens/login_screen.dart`
   - Removed OTP flow
   - Added password input
   - Added forgot password
   - Integrated FirebaseAuthService

2. `lib/src/screens/create_account_screen.dart`
   - Removed OTP flow
   - Added email/phone input
   - Added password input with validation
   - Integrated FirebaseAuthService

3. `lib/src/services/firebase_auth_service.dart`
   - Complete Firebase Auth integration
   - Email/Password authentication
   - Phone number handling
   - Validation helpers

## Migration Notes

### For Existing Users
If you have existing users with OTP-based accounts:
1. They need to set a password
2. Implement a "Set Password" flow for existing users
3. Or migrate their accounts to the new system

### For New Users
- All new registrations use email/phone + password
- No OTP verification required
- Immediate account creation

## Security Considerations

1. **Password Strength**: Enforced minimum requirements
2. **Password Reset**: Secure email-based reset flow
3. **Firebase Rules**: Configure Firestore security rules
4. **Email Verification**: Consider adding email verification
5. **Rate Limiting**: Firebase provides built-in rate limiting

## Future Enhancements

1. **Email Verification**: Send verification email after registration
2. **Social Login**: Add Google, Apple, Facebook login
3. **Biometric Auth**: Add fingerprint/face recognition
4. **Multi-Factor Auth**: Add optional 2FA
5. **Account Linking**: Link email and phone accounts
6. **Password Strength Meter**: Visual password strength indicator

## Support

For issues or questions:
- Check Firebase Console for authentication logs
- Review error messages in `AuthResult`
- Test with Firebase Auth Emulator for development
- Check `FIREBASE_AUTH_INTEGRATION.md` for detailed API docs
