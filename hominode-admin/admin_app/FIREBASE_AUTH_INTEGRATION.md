# Firebase Authentication Integration

## Overview
Firebase Authentication has been successfully integrated into the admin app with support for both Email/Password and Phone Number authentication.

## Admin Credentials

### Email Login
- **Email**: `admin@lyvo.com`
- **Password**: `test@123`

### Phone Login
- **Phone Number**: `1234567890`
- **OTP**: Will be sent via Firebase (requires Firebase Console configuration)

## Features Implemented

### 1. AuthService Class (`lib/services/auth_service.dart`)

The AuthService provides the following methods:

- **`signInWithEmail(email, password)`** - Email/password authentication
- **`signInWithPhone(phoneNumber, onCodeSent, onAutoVerify)`** - Phone number authentication (Step 1: Send OTP)
- **`verifyOTP(verificationId, otp)`** - Verify OTP code (Step 2: Complete phone auth)
- **`signOut()`** - Sign out current user
- **`getCurrentUser()`** - Get currently logged-in user
- **`authStateChanges`** - Stream of authentication state changes
- **`createAdminAccount()`** - One-time setup to create admin account in Firebase

### 2. Enhanced Login Screen (`lib/admin_login_screen.dart`)

Features:
- Toggle between Email and Phone login
- Email/Password login with validation
- Phone number login with OTP verification
- Loading states during authentication
- Error handling with user-friendly messages
- Auto-navigation to dashboard on success

### 3. Auth Wrapper (`lib/auth_wrapper.dart`)

- Listens to Firebase auth state changes
- Automatically shows login screen when logged out
- Shows dashboard when logged in
- Displays splash screen during initialization

## Setup Instructions

### 1. Firebase Console Configuration

#### Enable Authentication Methods:
1. Go to Firebase Console → Authentication → Sign-in method
2. Enable **Email/Password** authentication
3. Enable **Phone** authentication

#### For Phone Authentication:
- Add your app's SHA-1 and SHA-256 fingerprints in Firebase Console
- Configure reCAPTCHA for web (if building for web)
- For testing, you can add test phone numbers in Firebase Console

### 2. Create Admin Account

The admin account is automatically created on first app launch. The `createAdminAccount()` method is called in the login screen's `initState()`.

Alternatively, you can manually create it in Firebase Console:
1. Go to Firebase Console → Authentication → Users
2. Click "Add User"
3. Email: `admin@lyvo.com`
4. Password: `test@123`

### 3. Android Configuration (Already Done)

The following are already configured:
- `google-services.json` in `android/app/`
- Google Services plugin in `android/settings.gradle.kts`
- Firebase dependencies in `android/app/build.gradle.kts`

### 4. iOS Configuration (If needed)

For iOS support:
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add it to `ios/Runner/` directory
3. Update `ios/Runner/Info.plist` with URL schemes

## Usage Examples

### Email Login
```dart
final authService = AuthService();
final result = await authService.signInWithEmail(
  'admin@lyvo.com',
  'test@123',
);

if (result.success) {
  // Navigate to dashboard
} else {
  // Show error: result.message
}
```

### Phone Login
```dart
final authService = AuthService();

// Step 1: Send OTP
final result = await authService.signInWithPhone(
  '1234567890',
  (verificationId, resendToken) {
    // OTP sent successfully
    // Save verificationId for step 2
  },
  (credential) {
    // Auto-verification (instant verification)
    // User is automatically signed in
  },
);

// Step 2: Verify OTP
final verifyResult = await authService.verifyOTP(
  verificationId,
  '123456', // OTP code
);

if (verifyResult.success) {
  // User signed in successfully
}
```

### Sign Out
```dart
final authService = AuthService();
await authService.signOut();
```

### Get Current User
```dart
final authService = AuthService();
final user = authService.getCurrentUser();

if (user != null) {
  print('User ID: ${user.uid}');
  print('Email: ${user.email}');
  print('Phone: ${user.phoneNumber}');
}
```

## Error Handling

The AuthService includes comprehensive error handling with user-friendly messages:

- Invalid credentials
- Network errors
- Invalid OTP
- Too many attempts
- Account disabled
- And more...

All errors are returned in the `AuthResult` object with a descriptive message.

## Security Notes

1. **Admin credentials are hardcoded** for demo purposes. In production:
   - Store credentials securely
   - Implement role-based access control
   - Use Firebase Admin SDK for user management

2. **Phone Authentication** requires:
   - Valid SHA certificates for Android
   - reCAPTCHA configuration for web
   - Test phone numbers for development

3. **Session Management**:
   - Firebase handles session persistence automatically
   - Users remain logged in across app restarts
   - Use `signOut()` to clear session

## Testing

### Test Email Login:
1. Open app
2. Select "Email" tab
3. Enter: `admin@lyvo.com` / `test@123`
4. Click "Login"

### Test Phone Login:
1. Open app
2. Select "Phone" tab
3. Enter: `1234567890`
4. Click "Login"
5. Enter OTP received
6. Click "Verify OTP"

## Troubleshooting

### "User not found" error:
- Run the app once to auto-create admin account
- Or manually create user in Firebase Console

### Phone authentication not working:
- Check SHA certificates are added in Firebase Console
- Verify phone authentication is enabled
- For testing, add test phone numbers in Firebase Console

### Build errors:
- Run `flutter clean`
- Run `flutter pub get`
- Rebuild the app

## Next Steps

1. **Add more authentication methods**:
   - Google Sign-In
   - Apple Sign-In
   - Facebook Login

2. **Implement role-based access**:
   - Admin roles
   - Staff roles
   - Resident roles

3. **Add profile management**:
   - Update profile
   - Change password
   - Update phone number

4. **Implement security features**:
   - Two-factor authentication
   - Biometric authentication
   - Session timeout
