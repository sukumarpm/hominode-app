# Demo Credentials - Testing Guide

## 🎯 Demo Mode

The authentication flow is currently configured with **hardcoded demo credentials** for testing purposes.

## 📱 Demo Credentials

### Login Screen
```
Mobile Number: 1234567890
```

### OTP Verification Screen
```
OTP Code: 123456
```

## 🚀 How to Test

### Complete Flow Test

1. **Run the app**:
   ```bash
   cd resident_app
   flutter run -t lib/auth_flow_demo.dart
   ```

2. **Splash Screen** (2.2 seconds):
   - Watch the animated logo
   - Automatic transition to login

3. **Login Screen**:
   - Enter mobile: `1234567890`
   - Tap "Send OTP"
   - Wait for success message

4. **OTP Screen**:
   - Enter OTP: `123456`
   - Tap "Verify & Continue"
   - Navigate to home screen

### Testing Different Scenarios

#### ✅ Success Path
```
Mobile: 1234567890
OTP: 123456
Result: ✅ Login successful
```

#### ❌ Invalid Mobile
```
Mobile: 9999999999 (or any other number)
Result: ❌ "Failed to send OTP"
```

#### ❌ Invalid OTP
```
Mobile: 1234567890
OTP: 111111 (or any other code)
Result: ❌ "Invalid OTP. Please try again."
```

#### 🔄 Resend OTP
```
Mobile: 1234567890
Action: Tap "Resend"
Result: ✅ "OTP resent successfully"
Note: Same OTP (123456) will work
```

## 🔍 Console Output

When testing, you'll see helpful debug messages in the console:

### Successful OTP Send
```
✅ OTP sent to: 1234567890
📱 Demo OTP: 123456
```

### Failed OTP Send
```
❌ Invalid mobile number for demo
💡 Use demo mobile: 1234567890
```

### Successful OTP Verification
```
Verifying OTP: 123456 for mobile: 1234567890
✅ OTP verified successfully
🎉 User authenticated
```

### Failed OTP Verification
```
❌ Invalid OTP
💡 Demo credentials: Mobile=1234567890, OTP=123456
```

### Resend OTP
```
🔄 OTP resent to: 1234567890
📱 Demo OTP: 123456
```

## 📝 Implementation Details

### Auth Service Location
```
File: lib/src/services/auth_service.dart
```

### Demo Configuration
```dart
// Demo credentials (hardcoded)
const demoMobile = '1234567890';
const demoOTP = '123456';

// API delay simulation
Duration: 1 second
```

### Methods Updated
- `sendOTP(String mobile)` - Only accepts 1234567890
- `verifyOTP(String mobile, String otp)` - Only accepts 123456
- `resendOTP(String mobile)` - Only accepts 1234567890

## 🔧 Switching to Production

When ready to connect to real API:

### Step 1: Update Auth Service
```dart
// In lib/src/services/auth_service.dart

// Remove demo mode checks
// Replace with actual API calls

Future<bool> sendOTP(String mobile) async {
  final response = await http.post(
    Uri.parse('$_baseUrl/auth/send-otp'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'mobile': mobile}),
  );
  
  return response.statusCode == 200;
}
```

### Step 2: Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0
  shared_preferences: ^2.2.2
```

### Step 3: Configure API URL
```dart
// In auth_service.dart
static const String _baseUrl = 'https://your-api-url.com/api';
```

### Step 4: Add Token Storage
```dart
Future<void> _saveAuthToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', token);
}
```

## 🧪 Testing Checklist

### Login Screen
- [ ] Enter demo mobile (1234567890)
- [ ] Tap "Send OTP"
- [ ] See loading spinner
- [ ] Navigate to OTP screen
- [ ] Try invalid mobile (should fail)

### OTP Screen
- [ ] See 6 OTP boxes
- [ ] First box auto-focused
- [ ] Enter demo OTP (123456)
- [ ] Auto-advance between boxes
- [ ] Button enables when complete
- [ ] Tap "Verify & Continue"
- [ ] See loading spinner
- [ ] Navigate to home screen
- [ ] Try invalid OTP (should fail)
- [ ] Try "Resend" link (should work)

### Error Handling
- [ ] Empty mobile number
- [ ] Invalid mobile format
- [ ] Wrong mobile number
- [ ] Incomplete OTP
- [ ] Wrong OTP
- [ ] Network simulation

## 💡 Tips

### Quick Test
```bash
# Run and test immediately
flutter run -t lib/auth_flow_demo.dart

# Then:
# 1. Wait for splash (2.2s)
# 2. Enter: 1234567890
# 3. Tap: Send OTP
# 4. Enter: 123456
# 5. Tap: Verify & Continue
# 6. See: Home screen
```

### Debug Mode
Check console output for detailed logs:
- ✅ Success messages
- ❌ Error messages
- 💡 Helpful hints
- 📱 Demo credentials

### Common Issues

**Issue**: OTP not working
**Solution**: Make sure you're using exactly `123456`

**Issue**: Mobile not accepted
**Solution**: Make sure you're using exactly `1234567890`

**Issue**: Can't see console output
**Solution**: Run from terminal, not IDE run button

## 📚 Related Documentation

- `AUTH_FLOW_COMPLETE.md` - Complete auth flow guide
- `LOGIN_SCREEN_COMPLETE.md` - Login screen details
- `OTP_SCREEN_COMPLETE.md` - OTP screen details
- `AUTH_QUICK_REFERENCE.md` - Quick reference card

## 🎉 Summary

**Demo Credentials**:
- Mobile: `1234567890`
- OTP: `123456`

**Test Command**:
```bash
flutter run -t lib/auth_flow_demo.dart
```

**Expected Flow**:
Splash (2.2s) → Login (enter mobile) → OTP (enter code) → Home

**Status**: ✅ Ready for testing

---

**Last Updated**: 2025-01-20
**Mode**: Demo/Testing
**Production Ready**: Update auth_service.dart with real API
