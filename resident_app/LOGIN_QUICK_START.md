# Login Screen - Quick Start Guide

## 🚀 Run the Login Screen

### Option 1: Run Demo App
```bash
cd resident_app
flutter run -t lib/login_demo.dart
```

### Option 2: Test on Specific Device
```bash
# List devices
flutter devices

# Run on Windows
flutter run -d windows -t lib/login_demo.dart

# Run on Chrome
flutter run -d chrome -t lib/login_demo.dart

# Run on Android/iOS
flutter run -d <device-id> -t lib/login_demo.dart
```

## 📁 Files Created

```
✅ lib/src/screens/login_screen.dart          - Main login screen
✅ lib/src/components/auth_text_field.dart    - Reusable input field
✅ lib/src/components/auth_primary_button.dart - Reusable button
✅ lib/login_demo.dart                         - Demo app
✅ LOGIN_SCREEN_README.md                      - Full documentation
✅ LOGIN_QUICK_START.md                        - This file
```

## 🎨 Design Specs Implemented

### Colors
- ✅ Gradient Background: #2F80ED → #2563EB
- ✅ White Card: #FFFFFF with 28px radius
- ✅ Input Field: #F5F5F5 background
- ✅ Primary Button: #2563EB
- ✅ Link Blue: #2563EB

### Typography
- ✅ Title: 28pt Bold White
- ✅ Subtitle: 16pt Regular White
- ✅ Form Heading: 22pt Semibold Black
- ✅ Label: 16pt Medium Black
- ✅ Button: 17pt Semibold White

### Layout
- ✅ Card radius: 28px
- ✅ Card padding: 28px horizontal, 32px vertical
- ✅ Input radius: 12px
- ✅ Button height: 54px
- ✅ Button radius: 12px

## 🔧 Integration

### Add to Main App
```dart
// In your main.dart or router
import 'package:resident_app/src/screens/login_screen.dart';

// Navigate to login
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const LoginScreen()),
);
```

### Use Components Elsewhere
```dart
// Import components
import 'package:resident_app/src/components/auth_text_field.dart';
import 'package:resident_app/src/components/auth_primary_button.dart';

// Use in your screens
AuthTextField(
  controller: _emailController,
  hintText: 'Enter email',
  keyboardType: TextInputType.emailAddress,
)

AuthPrimaryButton(
  text: 'Submit',
  onPressed: () => _handleSubmit(),
)
```

## 📱 Preview

The screen matches the provided design exactly:
- Gradient blue background
- Centered "Welcome Back" title
- White rounded card with login form
- Mobile number input field
- "Send OTP" button
- "Don't have an account? Register" link

## ✅ Features

- [x] Pixel-perfect design match
- [x] Responsive layout
- [x] Keyboard handling
- [x] iOS Cupertino feel
- [x] Reusable components
- [x] Clean code structure
- [x] No compilation errors
- [x] Ready for backend integration

## 🎯 Next Steps

1. **Test the screen**: Run the demo app
2. **Customize**: Modify colors/text as needed
3. **Add OTP screen**: Create verification flow
4. **Backend integration**: Connect to API
5. **Add validation**: Implement form checks

## 💡 Tips

- The screen uses `SafeArea` for notch handling
- `SingleChildScrollView` prevents keyboard overlap
- All colors match the exact hex values provided
- Components are reusable across the app
- Status bar is set to light mode for visibility

## 🐛 Troubleshooting

**Issue**: Screen doesn't look right
- Check device width (optimized for 390px)
- Ensure Flutter is up to date
- Clear build cache: `flutter clean`

**Issue**: Keyboard covers input
- Already handled with `SingleChildScrollView`
- Ensure you're using the provided implementation

**Issue**: Colors look different
- Check device color profile
- Verify hex values in code
- Test on actual device vs simulator

---

**Ready to use!** Run `flutter run -t lib/login_demo.dart` to see it in action.
