# Firebase Authentication - Quick Start Guide

## ✅ What's Been Implemented

Firebase Authentication is now fully integrated with:
- Email/Password login
- Phone Number/Password login (no OTP required)
- Auto-creation of admin account
- Session management with auth state persistence

## 🔑 Admin Credentials

### Email Login
```
Email: admin@lyvo.com
Password: test@123
```

### Phone Login
```
Phone: 1234567890
Password: test@123
```

## 🚀 How to Test

### 1. Email Login
1. Run the app
2. On login screen, ensure "Email" tab is selected
3. Enter: `admin@lyvo.com`
4. Enter password: `test@123`
5. Click "Login"
6. You'll be redirected to the dashboard

### 2. Phone Login
1. Run the app
2. Click "Phone" tab on login screen
3. Enter: `1234567890`
4. Enter password: `test@123`
5. Click "Login"
6. You'll be redirected to the dashboard

## 🔧 Build Fix Applied

Fixed the package name mismatch:
- Changed `com.example.admin_app` to `com.marantrix.lyvo` in build.gradle.kts
- Now matches the package name in google-services.json

## 📁 Files Created/Modified

### New Files:
- `lib/services/auth_service.dart` - Simplified authentication service
- `FIREBASE_AUTH_QUICK_START.md` - This file

### Modified Files:
- `pubspec.yaml` - Added firebase_auth dependency
- `lib/admin_login_screen.dart` - Simple email/phone + password login
- `lib/auth_wrapper.dart` - Uses Firebase auth state
- `lib/settings_screen.dart` - Fixed logout method
- `android/app/build.gradle.kts` - Fixed package name

## 🔧 Key Features

### AuthService Methods:
```dart
// Email login
signInWithEmail(email, password)

// Sign out
signOut()

// Get current user
getCurrentUser()

// Auth state stream
authStateChanges
```

### Login Flow:
- Both Email and Phone login use the same password
- Phone login validates credentials then signs in with email internally
- No OTP verification needed
- Simple and straightforward

### Auto-Features:
- Admin account auto-created on first launch
- Session persists across app restarts
- Auto-redirect to dashboard when logged in
- Auto-redirect to login when logged out

## 📱 Testing Flow

1. **First Launch**:
   - App creates admin account automatically
   - Shows login screen

2. **Login (Email or Phone)**:
   - Choose Email or Phone tab
   - Enter credentials (both use same password: test@123)
   - Click Login

3. **Dashboard**:
   - Automatically redirected after successful login
   - Session persists

4. **Logout**:
   - Go to Settings → Logout
   - Redirected to login screen

## 🐛 Troubleshooting

### Build Error: "No matching client found"
✅ **FIXED** - Package name updated to match google-services.json

### "User not found" error:
- The admin account is auto-created on first launch
- Wait a moment and try again

### Build errors:
```bash
cd admin_app
flutter clean
flutter pub get
flutter run
```

## 🔐 Security Notes

- Admin credentials are hardcoded for demo purposes
- Both email and phone login use the same backend authentication
- In production, implement proper user management
- Use Firebase Admin SDK for role-based access

## ✨ Simplified Design

- No OTP verification needed
- Simple phone number + password login
- Same password for both email and phone login
- Faster login experience
- Less Firebase Console configuration required
