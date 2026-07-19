# Two-Factor Authentication (2FA) Feature

Complete implementation of Two-Factor Authentication settings for the Resident App.

## 📁 Files Created

1. **`lib/src/screens/two_factor_settings_screen.dart`** - Main 2FA settings screen
2. **`lib/src/modals/otp_verification_dialog.dart`** - OTP verification dialog
3. **`lib/src/services/two_factor_service.dart`** - 2FA service with API stubs

## ✨ Features

### Current Status Display
- Visual status badge (Enabled/Disabled)
- Shows active authentication method
- Color-coded status indicators

### Three Authentication Methods
1. **Authenticator App** (Recommended)
   - QR code display for easy setup
   - Manual secret key entry option
   - Works with Google Authenticator, Authy, etc.

2. **SMS**
   - Sends codes to registered phone number
   - Masked phone number display
   - Resend code functionality with countdown

3. **Email**
   - Sends codes to registered email
   - Masked email display
   - Resend code functionality with countdown

### Enable Flow
1. User selects authentication method
2. System initiates setup (sends code or shows QR)
3. User enters 6-digit verification code
4. System verifies and enables 2FA
5. Success confirmation

### Disable Flow
1. User clicks "Disable 2FA" button
2. Password confirmation dialog appears
3. User enters password
4. System verifies and disables 2FA
5. Success confirmation

### OTP Verification Dialog
- 6-digit code input with auto-focus
- Auto-submit when complete
- QR code display for authenticator apps
- Secret key with copy functionality
- Resend code button (SMS/Email only)
- 60-second countdown timer

## 🎨 UI Components

### Status Card
```dart
- Current status badge
- Method indicator
- Color-coded (Green = Enabled, Gray = Disabled)
```

### Method Selection Cards
```dart
- Icon representation
- Method name and description
- "RECOMMENDED" badge for Authenticator App
- Tap to enable
```

### Verification Dialog
```dart
- 6-digit OTP input fields
- QR code display (Authenticator)
- Secret key with copy button
- Resend code button (SMS/Email)
- Cancel and Verify actions
```

## 🔌 API Integration

### Backend Endpoints Required

#### 1. Get 2FA Status
```
GET /api/user/2fa/status
Headers: { "Authorization": "Bearer <token>" }

Response 200:
{
  "enabled": true,
  "method": "authenticator_app" | "sms" | "email"
}
```

#### 2. Initiate 2FA Setup
```
POST /api/user/2fa/enable
Headers: { 
  "Authorization": "Bearer <token>",
  "Content-Type": "application/json"
}
Body: { "method": "authenticator_app" | "sms" | "email" }

Response 200 (Authenticator):
{
  "success": true,
  "qrCode": "otpauth://totp/...",
  "secret": "BASE32SECRET"
}

Response 200 (SMS/Email):
{
  "success": true,
  "destination": "+1 *** *** 1234",
  "message": "Verification code sent"
}
```

#### 3. Verify 2FA Setup
```
POST /api/user/2fa/verify
Headers: { 
  "Authorization": "Bearer <token>",
  "Content-Type": "application/json"
}
Body: { 
  "method": "authenticator_app" | "sms" | "email",
  "code": "123456"
}

Response 200:
{
  "success": true,
  "message": "Two-Factor Authentication enabled"
}

Response 400:
{
  "success": false,
  "message": "Invalid verification code"
}
```

#### 4. Disable 2FA
```
POST /api/user/2fa/disable
Headers: { 
  "Authorization": "Bearer <token>",
  "Content-Type": "application/json"
}
Body: { "password": "user_password" }

Response 200:
{
  "success": true,
  "message": "Two-Factor Authentication disabled"
}

Response 401:
{
  "success": false,
  "message": "Incorrect password"
}
```

#### 5. Resend Code
```
POST /api/user/2fa/resend
Headers: { 
  "Authorization": "Bearer <token>",
  "Content-Type": "application/json"
}
Body: { "method": "sms" | "email" }

Response 200:
{
  "success": true,
  "message": "Verification code sent"
}
```

## 🚀 Usage

### Navigate from Settings
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const TwoFactorSettingsScreen(),
  ),
);
```

### Check 2FA Status
```dart
final status = await TwoFactorService.instance.get2FAStatus();
if (status.enabled) {
  print('2FA is enabled with method: ${status.method}');
}
```

### Enable 2FA Programmatically
```dart
// Step 1: Initiate setup
final setupResult = await TwoFactorService.instance.initiate2FASetup(
  TwoFactorMethod.authenticatorApp,
);

// Step 2: Show verification dialog
final code = await showOTPVerificationDialog(
  context,
  method: TwoFactorMethod.authenticatorApp,
  qrCode: setupResult.qrCodeData,
  secret: setupResult.secret,
);

// Step 3: Verify and enable
if (code != null) {
  final result = await TwoFactorService.instance.verify2FASetup(
    method: TwoFactorMethod.authenticatorApp,
    code: code,
  );
}
```

## 🧪 Testing

### Test Codes (Stubs)
- Valid code: `123456`
- Invalid code: Any other 6-digit code

### Test Passwords (Disable)
- Valid: Any non-empty password except "wrong"
- Invalid: "wrong" or empty

### Test Flow
1. Open Settings → Two-Factor Authentication
2. Select "Authenticator App"
3. Scan QR code or copy secret
4. Enter code `123456`
5. Verify 2FA is enabled
6. Click "Disable Two-Factor Authentication"
7. Enter any password (not "wrong")
8. Verify 2FA is disabled

## 🎯 Integration Steps

1. **Replace API Stubs**
   - Update `TwoFactorService` methods with actual HTTP calls
   - Add proper error handling
   - Implement authentication token management

2. **Add QR Code Generation**
   - Install `qr_flutter` package
   - Replace QR code placeholder in dialog
   ```dart
   QrImageView(
     data: widget.qrCodeData!,
     version: QrVersions.auto,
     size: 200.0,
   )
   ```

3. **Implement Secure Storage**
   - Store 2FA status locally if needed
   - Cache method preference

4. **Add Analytics**
   - Track 2FA enable/disable events
   - Monitor verification success rates

5. **Error Handling**
   - Network timeouts
   - Invalid codes
   - Rate limiting

## 🔒 Security Considerations

1. **Secret Key Protection**
   - Never log or expose secret keys
   - Clear from memory after use

2. **Rate Limiting**
   - Implement server-side rate limiting for code verification
   - Add client-side retry limits

3. **Code Expiration**
   - Codes should expire after 5-10 minutes
   - Implement server-side validation

4. **Password Confirmation**
   - Always require password to disable 2FA
   - Consider requiring 2FA code as well

5. **Backup Codes**
   - Generate backup codes during setup
   - Store securely for account recovery

## 📱 User Experience

### Success States
- ✅ Clear success messages
- ✅ Immediate status updates
- ✅ Smooth transitions

### Error States
- ❌ Inline error messages
- ❌ Retry options
- ❌ Clear error descriptions

### Loading States
- ⏳ Loading indicators during API calls
- ⏳ Disabled buttons during processing
- ⏳ Countdown timers for resend

## 🎨 Design Specs

### Colors
- Primary Blue: `#2563EB`
- Success Green: `#22C55E`
- Error Red: `#EF4444`
- Warning Orange: `#F59E0B`
- Gray Text: `#6B7280`

### Typography
- Header: 22px, Bold
- Title: 18px, Bold
- Body: 14px, Regular
- Caption: 12px, Medium

### Spacing
- Section padding: 20px
- Card padding: 16-20px
- Element spacing: 12-16px

## 📦 Dependencies

Current (no additional dependencies required):
- Flutter Material Design
- Dart async/await

Optional (for enhanced features):
- `qr_flutter` - QR code generation
- `flutter_secure_storage` - Secure local storage
- `http` or `dio` - API calls

## 🐛 Known Limitations (Stubs)

1. QR code is placeholder text (needs `qr_flutter`)
2. API calls are simulated with delays
3. No actual backend integration
4. No persistent storage
5. Test codes hardcoded

## 📝 Next Steps

1. Integrate with actual backend API
2. Add QR code generation library
3. Implement secure local storage
4. Add backup codes feature
5. Add biometric verification option
6. Implement account recovery flow
7. Add 2FA requirement for sensitive actions

## 🎉 Complete!

The Two-Factor Authentication feature is fully implemented and ready for backend integration. All UI flows, dialogs, and service stubs are in place.
