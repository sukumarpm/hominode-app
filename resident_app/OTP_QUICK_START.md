# OTP Verification Screen - Quick Start Guide

## 🚀 Run the OTP Screen

### Option 1: Run Demo App
```bash
cd resident_app
flutter run -t lib/verify_otp_demo.dart
```

### Option 2: Test on Specific Device
```bash
# List devices
flutter devices

# Run on Windows
flutter run -d windows -t lib/verify_otp_demo.dart

# Run on Chrome
flutter run -d chrome -t lib/verify_otp_demo.dart

# Run on Android/iOS
flutter run -d <device-id> -t lib/verify_otp_demo.dart
```

## 📁 Files Created

```
✅ lib/src/screens/verify_otp_screen.dart     - Main OTP screen
✅ lib/src/components/otp_input_box.dart      - Reusable OTP box
✅ lib/verify_otp_demo.dart                    - Demo app
✅ OTP_SCREEN_README.md                        - Full documentation
✅ OTP_QUICK_START.md                          - This file
```

## 🎨 Design Specs Implemented

### Colors
- ✅ Header Gradient: #2F80ED → #2563EB
- ✅ Background: #F7F7F7
- ✅ OTP Box Border: #E5E5E5 (default), #2563EB (focused)
- ✅ OTP Box Background: #FFFFFF
- ✅ Primary Button: #2563EB

### Typography
- ✅ Header Title: 20pt Semibold White
- ✅ Heading: 24pt Bold Black
- ✅ Subheading: 16pt Regular Grey
- ✅ OTP Digits: 22pt Semibold Black
- ✅ Button: 17pt Semibold White

### Layout
- ✅ Header radius: 24px
- ✅ OTP box size: 56x56px
- ✅ OTP box radius: 12px
- ✅ OTP box spacing: 12px
- ✅ Button height: 54px

## 🔧 Integration

### Add to Main App Routes
```dart
// In your main.dart or router
import 'package:resident_app/src/screens/verify_otp_screen.dart';

routes: {
  '/login': (context) => const LoginScreen(),
  '/verify-otp': (context) => const VerifyOTPScreen(),
  '/home': (context) => const MainNavigation(),
}
```

### Navigate from Login
```dart
// In login_screen.dart
void _handleSendOTP() async {
  final mobile = _mobileController.text;
  
  // Send OTP
  await _authService.sendOTP(mobile);
  
  // Navigate to OTP screen
  Navigator.pushNamed(
    context,
    '/verify-otp',
    arguments: {'mobile': mobile},
  );
}
```

### Navigate to Home
```dart
// In verify_otp_screen.dart
void _handleVerify() async {
  final otp = _getOTP();
  
  // Verify OTP
  final success = await _authService.verifyOTP(mobile, otp);
  
  if (success) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }
}
```

## 📱 Preview

The screen matches the provided design exactly:
- Gradient blue header with curved bottom
- Back arrow + "Verify OTP" title
- Centered "Enter OTP" heading
- 6 OTP input boxes
- "Verify & Continue" button
- "Didn't receive code? Resend" link

## ✅ Features

- [x] Pixel-perfect design match
- [x] Gradient header with curved bottom
- [x] 6 OTP input boxes
- [x] Auto-focus first box
- [x] Auto-advance on input
- [x] Backspace navigation
- [x] Focus state styling
- [x] Smooth animations
- [x] Loading state
- [x] Resend functionality
- [x] Responsive layout
- [x] Keyboard handling

## 🎯 Behavior

### Auto-Focus
- First box focuses automatically
- Keyboard appears on screen load

### Auto-Advance
- Typing moves to next box
- Last box stays focused

### Backspace
- Empty box: moves to previous
- Filled box: clears digit

### Verify Button
- Disabled until OTP complete
- Shows loading spinner
- Enabled when all 6 digits entered

## 💡 Tips

- OTP boxes only accept digits (0-9)
- Focus state shows blue border
- Button enables automatically when OTP complete
- Resend link is immediately tappable
- Smooth fade-in animation on load

## 🐛 Troubleshooting

**Issue**: First box doesn't auto-focus
- Check `WidgetsBinding.instance.addPostFrameCallback`
- Ensure focus node is properly initialized

**Issue**: Auto-advance not working
- Verify `onChanged` callback
- Check focus node management

**Issue**: Keyboard covers input
- Already handled with `SingleChildScrollView`
- Ensure proper padding

**Issue**: Backspace doesn't work
- Use `KeyboardListener` for better handling
- Check `onBackspace` callback

## 🔄 Complete Auth Flow

```
Login Screen
    ↓ (Enter mobile, tap "Send OTP")
OTP Screen
    ↓ (Enter 6-digit OTP, tap "Verify & Continue")
Home Screen
```

## 📚 Next Steps

1. **Test the screen**: Run the demo app
2. **Integrate with login**: Connect navigation
3. **Add backend**: Connect to OTP API
4. **Add timer**: Countdown for resend (optional)
5. **Add paste**: Support OTP paste (optional)
6. **Add auto-submit**: Verify when complete (optional)

## 🎨 Customization

### Change OTP Length
```dart
// Change from 6 to 4 digits
final List<TextEditingController> _otpControllers =
    List.generate(4, (_) => TextEditingController());
```

### Change Box Size
```dart
// In otp_input_box.dart
Container(
  width: 64,  // Change from 56
  height: 64, // Change from 56
  ...
)
```

### Change Colors
```dart
// Header gradient
colors: [
  Color(0xFFYOUR_COLOR_1),
  Color(0xFFYOUR_COLOR_2),
]

// Focus border
color: Color(0xFFYOUR_BRAND_COLOR)
```

---

**Ready to use!** Run `flutter run -t lib/verify_otp_demo.dart` to see it in action.
