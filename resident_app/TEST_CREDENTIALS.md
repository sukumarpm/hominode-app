# Test Credentials for App Testing

## Login Flow Test Credentials

For testing the authentication flow without connecting to a real backend, use these credentials:

### Mobile Number
```
1234567890
```

### OTP Code
```
123456
```

## Testing Flow

### First Time Login

1. **Launch App**
   - App checks login state
   - Shows loading screen briefly
   - Navigates to Login Screen (first time)

2. **Enter Mobile Number**
   - Type: `1234567890`
   - Click "Send OTP"
   - You'll be navigated to OTP verification screen

3. **Enter OTP**
   - Type: `123456`
   - Click "Verify & Continue"
   - Login state is saved locally
   - You'll be logged in and navigated to Dashboard

### Subsequent App Launches

1. **Launch App**
   - App checks login state
   - Detects you're already logged in
   - **Automatically navigates to Dashboard** (skips login)

### Logout

1. **Go to Profile Tab**
   - Scroll down to bottom
   - Click "Logout" button
   - Confirm logout in dialog
   - Login state is cleared
   - Navigates back to Login Screen

2. **Next Launch**
   - App will show Login Screen again

## Important Notes

- **Remember Me**: Login state is persisted using `shared_preferences`
- Once logged in, you stay logged in until you explicitly logout
- These credentials are hardcoded in `lib/src/services/auth_service.dart`
- The app is in **DEMO MODE** - no real API calls are made
- Any other mobile number will be rejected
- Any other OTP will be rejected
- This is for testing purposes only

## For Production

When connecting to real backend:

1. Update `auth_service.dart` to remove demo mode checks
2. Uncomment the actual API call code
3. Update the `_baseUrl` constant with your API endpoint
4. Remove the hardcoded test credentials
5. The login persistence will work automatically with real tokens

## Current App Flow

```
App Launch
    ↓
Check Login State
    ↓
    ├─ Logged In? → Dashboard (Skip Login)
    └─ Not Logged In? → Login Screen
                            ↓
                    Enter Mobile: 1234567890
                            ↓
                    OTP Screen (OTP: 123456)
                            ↓
                    Save Login State
                            ↓
                    Dashboard
```

## Quick Test Commands

To test the app:
```bash
cd resident_app
flutter run
```

To test logout and re-login:
1. Login with test credentials
2. Go to Profile → Logout
3. Close and reopen app
4. You'll see Login Screen again

To clear saved login state manually:
```bash
# Uninstall and reinstall the app
flutter clean
flutter run
```
