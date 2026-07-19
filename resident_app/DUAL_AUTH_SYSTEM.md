# Dual Authentication System - Phone OTP & Email/Password

## Overview
The app now supports TWO authentication methods:
1. **Phone Number with OTP** - Firebase Phone Authentication
2. **Email with Password** - Firebase Email/Password Authentication

Users can choose their preferred method from a tabbed interface on the login screen.

## Features Implemented

### Login Screen
- ✅ Tabbed interface with "Phone OTP" and "Email" tabs
- ✅ Phone OTP tab: Phone number input → Send OTP → Verify OTP
- ✅ Email tab: Email + Password → Direct login
- ✅ Forgot Password functionality for email users
- ✅ Register link on both tabs

### Phone OTP Authentication
- ✅ Send OTP to phone number
- ✅ Auto-verification on Android (when available)
- ✅ Manual OTP entry with 6-digit code
- ✅ Resend OTP functionality
- ✅ Firebase Phone Authentication integration
- ✅ E.164 phone number formatting (+91XXXXXXXXXX)

### Email/Password Authentication
- ✅ Email validation
- ✅ Password visibility toggle
- ✅ Forgot password with email reset link
- ✅ Firebase Email/Password Authentication
- ✅ Password strength validation

## User Flow

### Phone OTP Login
```
1. User opens app → Login screen
2. User selects "Phone OTP" tab
3. User enters 10-digit phone number
4. User clicks "Send OTP"
5. Firebase sends SMS with 6-digit code
6. User navigates to OTP verification screen
7. User enters 6-digit OTP
8. Firebase verifies OTP
9. User logged in → Navigate to home
```

### Email/Password Login
```
1. User opens app → Login screen
2. User selects "Email" tab
3. User enters email address
4. User enters password
5. User clicks "Login"
6. Firebase verifies credentials
7. User logged in → Navigate to home
```

### Registration
```
1. User clicks "Register" link
2. User enters: Full Name, Email/Phone, Password, Block, Flat
3. User clicks "Continue"
4. Firebase creates account
5. User profile updated with display name
6. Navigate to setup profile screen
```

## Firebase Configuration

### Phone Authentication Setup
1. Enable Phone Authentication in Firebase Console
2. Add SHA-1 and SHA-256 fingerprints for Android
3. Configure reCAPTCHA for web (if needed)
4. Add test phone numbers for development (optional)

### Email/Password Setup
1. Enable Email/Password Authentication in Firebase Console
2. Configure email templates (optional)
3. Set up password reset email (optional)

## API Reference

### FirebaseAuthService Methods

#### Phone Authentication
```dart
// Send OTP
await authService.signInWithPhone(
  phoneNumber: '+919876543210',
  onCodeSent: (verificationId) {
    // Navigate to OTP screen
  },
  onError: (error) {
    // Show error
  },
  onAutoVerify: (credential) {
    // Auto-verified (Android only)
  },
);

// Verify OTP
final result = await authService.verifyOtp(
  smsCode: '123456',
  verificationId: verificationId,
);

// Resend OTP
await authService.resendOtp(
  phoneNumber: '+919876543210',
  onCodeSent: (verificationId) {},
  onError: (error) {},
);
```

#### Email/Password Authentication
```dart
// Sign in
final result = await authService.signInWithEmail(
  email: 'user@example.com',
  password: 'SecurePass123',
);

// Create account
final result = await authService.createAccountWithEmail(
  email: 'user@example.com',
  password: 'SecurePass123',
);

// Reset password
final result = await authService.sendPasswordResetEmail(
  email: 'user@example.com',
);
```

#### User Management
```dart
// Get current user
final user = authService.getCurrentUser();

// Check if signed in
final isSignedIn = await authService.isSignedIn();

// Sign out
final result = await authService.signOut();

// Update profile
final result = await authService.updateProfile(
  displayName: 'John Doe',
  photoURL: 'https://example.com/photo.jpg',
);
```

## Validation

### Phone Number
- Must be 10 digits
- Must start with 6-9 (Indian format)
- Automatically formatted to E.164 (+91XXXXXXXXXX)

### Email
- Must be valid email format
- Example: user@example.com

### Password
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

## Error Handling

All methods return `AuthResult` with:
- `success`: Boolean
- `message`: User-friendly message
- `errorCode`: Firebase error code
- `user`: Firebase User object (when applicable)

### Common Errors

**Phone Auth:**
- `invalid-phone-number`: Invalid format
- `too-many-requests`: Rate limit exceeded
- `invalid-verification-code`: Wrong OTP
- `session-expired`: OTP expired

**Email/Password:**
- `email-already-in-use`: Email taken
- `invalid-email`: Invalid format
- `user-not-found`: No account exists
- `wrong-password`: Incorrect password
- `weak-password`: Password too weak

## UI Components

### Login Screen
- TabBar with 2 tabs: "Phone OTP" and "Email"
- Phone OTP tab: Phone input + Send OTP button
- Email tab: Email input + Password input + Login button
- Forgot Password link (Email tab only)
- Register link (both tabs)

### OTP Verification Screen
- 6-digit OTP input field
- Visual digit separation
- Verify button
- Resend OTP button
- Timer countdown (optional)

### Create Account Screen
- Full Name input
- Email or Phone Number input
- Password input with visibility toggle
- Block and Flat Number inputs
- Continue button

## Testing

### Phone OTP Testing
1. Use Firebase test phone numbers:
   - Go to Firebase Console → Authentication → Sign-in method → Phone
   - Add test phone numbers with verification codes
   - Example: +1 650-555-3434 with code 123456

2. Test on real device:
   - Enter real phone number
   - Receive SMS with OTP
   - Verify OTP

### Email/Password Testing
1. Create test account:
   - Use valid email format
   - Use strong password
   - Verify account creation

2. Test login:
   - Enter email and password
   - Verify successful login

3. Test forgot password:
   - Click "Forgot Password?"
   - Enter email
   - Check email for reset link

## Security Best Practices

1. **Phone Authentication:**
   - Enable App Check to prevent abuse
   - Use reCAPTCHA for web platforms
   - Implement rate limiting
   - Monitor for suspicious activity

2. **Email/Password:**
   - Enforce strong password requirements
   - Implement email verification
   - Use secure password reset flow
   - Enable account recovery options

3. **General:**
   - Never log sensitive data
   - Use HTTPS for all API calls
   - Implement proper session management
   - Follow Firebase security rules

## Files Modified

1. `lib/src/screens/login_screen.dart`
   - Added TabBar with Phone OTP and Email tabs
   - Implemented dual authentication UI
   - Added phone OTP flow
   - Added email/password flow

2. `lib/src/screens/verify_otp_screen_single_field.dart`
   - Updated to use Firebase Phone Auth
   - Added verificationId parameter
   - Implemented Firebase OTP verification

3. `lib/src/services/firebase_auth_service.dart`
   - Complete Firebase Auth integration
   - Phone OTP methods
   - Email/Password methods
   - User management methods

## Configuration Files

1. `android/app/google-services.json`
   - Firebase project configuration
   - Package name: com.marantrix.lyvo

2. `android/app/build.gradle.kts`
   - Firebase dependencies
   - Google Services plugin

3. `android/app/src/main/res/values/strings.xml`
   - Firebase configuration values
   - API keys and project IDs

## Troubleshooting

### Phone OTP Not Working
1. Check Firebase Console → Authentication → Phone is enabled
2. Verify SHA-1/SHA-256 fingerprints are added
3. Check phone number format (must be E.164)
4. Verify SMS quota not exceeded
5. Check device has SMS permission

### Email/Password Not Working
1. Check Firebase Console → Authentication → Email/Password is enabled
2. Verify email format is correct
3. Check password meets requirements
4. Verify network connection
5. Check Firebase project configuration

### General Issues
1. Verify `google-services.json` is in correct location
2. Check package name matches Firebase configuration
3. Verify Firebase dependencies are installed
4. Check internet connection
5. Review Firebase Console logs

## Next Steps

### Recommended Enhancements
1. Add email verification after registration
2. Implement social login (Google, Apple, Facebook)
3. Add biometric authentication
4. Implement multi-factor authentication (MFA)
5. Add account linking (link phone and email)
6. Implement password strength meter
7. Add login history and device management
8. Implement account recovery options

### Production Checklist
- [ ] Enable App Check
- [ ] Configure email templates
- [ ] Set up monitoring and alerts
- [ ] Implement rate limiting
- [ ] Add analytics tracking
- [ ] Test on multiple devices
- [ ] Review security rules
- [ ] Set up backup authentication methods

## Support

For issues or questions:
- Firebase Auth Docs: https://firebase.google.com/docs/auth
- Flutter Fire Docs: https://firebase.flutter.dev/docs/auth/overview
- Check Firebase Console for authentication logs
- Review error messages in `AuthResult`
