# 🚀 Quick Test Guide - OTP Login Flow

## ⚡ Quick Start

### Run the Demo
```bash
cd resident_app
flutter run lib/otp_flow_demo.dart
```

## 🔐 Test Credentials

| Field | Value |
|-------|-------|
| **Mobile Number** | `1234567890` |
| **OTP Code** | `123456` |

## 📱 3-Step Test Flow

### Step 1: Login Screen
```
Enter: 1234567890
Tap: Send OTP
```

### Step 2: OTP Screen
```
Enter: 1 2 3 4 5 6 (one digit per box)
Tap: Verify & Continue
```

### Step 3: Success!
```
✅ Logged in to Dashboard
```

## 🎯 What to Test

### ✅ Happy Path
- [x] Enter mobile: 1234567890
- [x] Tap Send OTP
- [x] See success message
- [x] Navigate to OTP screen
- [x] Enter OTP: 123456
- [x] Tap Verify & Continue
- [x] Navigate to Dashboard

### ❌ Error Cases
- [x] Wrong mobile number → Error message
- [x] Wrong OTP → Error message + boxes cleared
- [x] Empty fields → Validation errors

### 🔄 Additional Features
- [x] Back button on OTP screen
- [x] Resend OTP button
- [x] Auto-focus between OTP boxes
- [x] Backspace moves to previous box
- [x] Paste full 6-digit OTP

## 🎨 UI Features to Check

### Login Screen
- Blue gradient background
- White card with rounded corners
- Mobile number input (10 digits max)
- Send OTP button with loading state
- Register link at bottom

### OTP Screen
- Blue gradient header with back button
- 6 separate input boxes
- Focused box has blue border
- Verify button (enabled when all 6 digits entered)
- Resend OTP link
- Loading state during verification

## 📝 Console Output

Watch for these logs:
```
✅ OTP sent to: 1234567890
📱 Demo OTP: 123456
Verifying OTP: 123456 for mobile: 1234567890
✅ OTP verified successfully
🎉 User authenticated
```

## 🐛 Troubleshooting

### OTP not sending?
- Make sure you're using: **1234567890**
- Any other number will fail in demo mode

### OTP verification failing?
- Make sure you're entering: **123456**
- Any other code will fail in demo mode

### App not navigating?
- Check console for error messages
- Make sure routes are configured in main.dart

## 📂 Files Modified

- `lib/src/screens/login_screen.dart` - Added Send OTP functionality
- `lib/src/screens/verify_otp_screen.dart` - OTP verification with 6 boxes
- `lib/src/services/auth_service.dart` - Test credentials validation
- `lib/otp_flow_demo.dart` - Demo app to test the flow

## 🎉 Success Criteria

You've successfully tested the OTP flow when:
1. ✅ You can enter mobile number 1234567890
2. ✅ Send OTP button works and shows success message
3. ✅ Navigate to OTP screen automatically
4. ✅ Enter OTP 123456 in 6 separate boxes
5. ✅ Verify button works and shows loading state
6. ✅ Navigate to Dashboard after verification
7. ✅ Error messages show for wrong credentials

---

**Ready to test?** Run: `flutter run lib/otp_flow_demo.dart`
