# Firebase Authentication Integration Guide

## Overview

Firebase Authentication has been successfully integrated into the app with support for:
- **Phone Number OTP Authentication**
- **Email/Password Authentication**
- Comprehensive error handling
- Loading states
- User management

## Setup Complete

### 1. Dependencies Added
```yaml
# pubspec.yaml
firebase_core: ^3.8.1
firebase_analytics: ^11.3.5
firebase_auth: ^5.3.3
```

### 2. Android Configuration
- Google Services plugin configured
- Firebase BoM and Auth dependencies added
- `google-services.json` file present

### 3. Firebase Initialization
Firebase is initialized in `main.dart` before app starts:
```dart
await Firebase.initializeApp();
```

## FirebaseAuthService API

### Phone Authentication

#### Send OTP
```dart
final authService = FirebaseAuthService();

final result = await authService.signInWithPhone(
  phoneNumber: '+911234567890', // E.164 format
  onCodeSent: (verificationId) {
    print('OTP sent! Verification ID: $verificationId');
    // Navigate to OTP verification screen
  },
  onError: (error) {
    print('Error: $error');
    // Show error to user
  },
  onAutoVerify: (credential) {
    // Optional: Handle auto-verification on Android
    print('Auto-verified!');
  },
);
```

#### Verify OTP
```dart
final result = await authService.verifyOtp(
  smsCode: '123456', // 6-digit code
);

if (result.success) {
  print('User signed in: ${result.user?.uid}');
  // Navigate to home screen
} else {
  print('Error: ${result.message}');
  // Show error to user
}
```

#### Resend OTP
```dart
final result = await authService.resendOtp(
  phoneNumber: '+911234567890',
  onCodeSent: (verificationId) {
    print('OTP resent!');
  },
  onError: (error) {
    print('Error: $error');
  },
);
```

### Email/Password Authentication

#### Sign In
```dart
final result = await authService.signInWithEmail(
  email: 'user@example.com',
  password: 'SecurePass123',
);

if (result.success) {
  print('Signed in: ${result.user?.email}');
  // Navigate to home screen
} else {
  print('Error: ${result.message}');
}
```

#### Create Account
```dart
final result = await authService.createAccountWithEmail(
  email: 'newuser@example.com',
  password: 'SecurePass123',
);

if (result.success) {
  print('Account created: ${result.user?.uid}');
  // Navigate to profile setup
} else {
  print('Error: ${result.message}');
}
```

#### Reset Password
```dart
final result = await authService.sendPasswordResetEmail(
  email: 'user@example.com',
);

if (result.success) {
  print('Reset email sent!');
} else {
  print('Error: ${result.message}');
}
```

### User Management

#### Get Current User
```dart
final user = authService.getCurrentUser();

if (user != null) {
  print('User ID: ${user.uid}');
  print('Email: ${user.email}');
  print('Phone: ${user.phoneNumber}');
  print('Display Name: ${user.displayName}');
}
```

#### Check Sign-In Status
```dart
final isSignedIn = await authService.isSignedIn();

if (isSignedIn) {
  // User is authenticated
} else {
  // User needs to sign in
}
```

#### Sign Out
```dart
final result = await authService.signOut();

if (result.success) {
  print('Signed out successfully');
  // Navigate to login screen
}
```

#### Update Profile
```dart
final result = await authService.updateProfile(
  displayName: 'John Doe',
  photoURL: 'https://example.com/photo.jpg',
);

if (result.success) {
  print('Profile updated!');
}
```

#### Delete Account
```dart
final result = await authService.deleteAccount();

if (result.success) {
  print('Account deleted');
  // Navigate to welcome screen
} else if (result.errorCode == 'requires-recent-login') {
  // User needs to re-authenticate
  print('Please sign in again to delete account');
}
```

### Validation Helpers

#### Validate Phone Number
```dart
final isValid = authService.validatePhoneNumber('9876543210');
// Returns true for valid 10-digit Indian numbers (6-9 prefix)
```

#### Format Phone Number
```dart
final formatted = authService.formatPhoneNumber('9876543210');
// Returns: +919876543210
```

#### Validate Email
```dart
final isValid = authService.validateEmail('user@example.com');
// Returns true for valid email format
```

#### Validate Password
```dart
final error = authService.validatePassword('weak');
// Returns error message if invalid, null if valid

// Password requirements:
// - At least 8 characters
// - At least one uppercase letter
// - At least one lowercase letter
// - At least one number
```

### Auth State Listener
```dart
authService.authStateChanges().listen((user) {
  if (user != null) {
    print('User signed in: ${user.uid}');
  } else {
    print('User signed out');
  }
});
```

## Complete Example: Phone Login Screen

```dart
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/auth_loading_button.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({Key? key}) : super(key: key);

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    
    // Validate
    if (!_authService.validatePhoneNumber(phone)) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Format to E.164
    final formattedPhone = _authService.formatPhoneNumber(phone);

    final result = await _authService.signInWithPhone(
      phoneNumber: formattedPhone,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        
        // Navigate to OTP screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phoneNumber: formattedPhone,
              verificationId: verificationId,
            ),
          ),
        );
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                hintText: '9876543210',
                prefixText: '+91 ',
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AuthLoadingButton(
              text: 'Send OTP',
              isLoading: _isLoading,
              onPressed: _sendOTP,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
```

## Complete Example: OTP Verification Screen

```dart
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/auth_loading_button.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.verificationId,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyOtp(
      smsCode: otp,
      verificationId: widget.verificationId,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.resendOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully')),
        );
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter the 6-digit code sent to',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              widget.phoneNumber,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AuthLoadingButton(
              text: 'Verify OTP',
              isLoading: _isLoading,
              onPressed: _verifyOTP,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : _resendOTP,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
```

## Complete Example: Email Login Screen

```dart
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/auth_loading_button.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Validate
    if (!_authService.validateEmail(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            AuthLoadingButton(
              text: 'Sign In',
              isLoading: _isLoading,
              onPressed: _signIn,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Navigate to forgot password screen
              },
              child: const Text('Forgot Password?'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

## Error Handling

All methods return `AuthResult` with:
- `success`: Boolean indicating operation success
- `message`: User-friendly error/success message
- `errorCode`: Firebase error code (for specific handling)
- `user`: Firebase User object (when applicable)

### Common Error Codes

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

**General:**
- `network-request-failed`: No internet
- `requires-recent-login`: Re-authentication needed

## Testing

### Phone Authentication Testing
Firebase provides test phone numbers for development:

1. Go to Firebase Console → Authentication → Sign-in method → Phone
2. Add test phone numbers with verification codes
3. Example: `+1 650-555-3434` with code `123456`

### Email Authentication Testing
Create test accounts directly or use Firebase Auth Emulator for local testing.

## Security Notes

1. **Never commit** `google-services.json` to public repositories
2. Enable **App Check** in production to prevent abuse
3. Implement **rate limiting** on your backend
4. Use **reCAPTCHA** for web platforms
5. Enable **email verification** for email/password auth
6. Implement **account recovery** flows

## Next Steps

1. ✅ Firebase Auth integrated
2. ✅ Phone OTP support added
3. ✅ Email/Password support added
4. ✅ Error handling implemented
5. ✅ Loading states added
6. ✅ Helper widgets created

### Recommended Enhancements:
- Add biometric authentication
- Implement social login (Google, Apple, Facebook)
- Add email verification flow
- Implement account linking
- Add multi-factor authentication (MFA)
- Create custom auth UI components

## Support

For issues or questions:
- Firebase Auth Docs: https://firebase.google.com/docs/auth
- Flutter Fire Docs: https://firebase.flutter.dev/docs/auth/overview
