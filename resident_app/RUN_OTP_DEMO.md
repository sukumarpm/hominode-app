# 🚀 Run OTP Demo - Quick Commands

## ⚡ Quick Start

```bash
cd resident_app
flutter run lib/otp_flow_demo.dart
```

## 🔐 Test Credentials

```
Mobile: 1234567890
OTP:    123456
```

## 📱 Test Flow

```
1. Enter mobile: 1234567890
2. Tap: Send OTP
3. Enter OTP: 1 2 3 4 5 6
4. Tap: Verify & Continue
5. ✅ Success!
```

## 📚 Documentation

- `OTP_TEST_CREDENTIALS.md` - Full test guide
- `QUICK_TEST_GUIDE.md` - Quick reference
- `OTP_FLOW_VISUAL.md` - Visual diagrams
- `OTP_IMPLEMENTATION_SUMMARY.md` - Complete overview

## ✅ What's Implemented

- Login screen with mobile input
- Send OTP functionality
- OTP screen with 6 boxes
- Auto-focus between boxes
- Verify OTP functionality
- Resend OTP functionality
- Navigation to dashboard
- Error handling
- Test credentials validation

## 🎯 Success Criteria

You'll know it works when:
1. ✅ Mobile 1234567890 sends OTP
2. ✅ OTP 123456 verifies successfully
3. ✅ Navigates to dashboard
4. ✅ Wrong credentials show errors

---

**Ready?** Run: `flutter run lib/otp_flow_demo.dart`
