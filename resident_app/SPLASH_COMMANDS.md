# 🚀 Splash Screen - Command Reference

## Quick Commands

### Run Full App (Splash Included)
```bash
flutter run
```

### Test Splash in Isolation
```bash
flutter run lib/splash_demo.dart
```

### Run on iPhone 13 (Target Device)
```bash
flutter run -d "iPhone 13"
```

### Run on iOS Simulator
```bash
flutter run -d ios
```

### Run on Android
```bash
flutter run -d android
```

### After Adding Logo Asset
```bash
flutter pub get
flutter run
```

### Check for Issues
```bash
flutter analyze lib/src/screens/animated_splash_screen.dart
```

### Build Release
```bash
flutter build ios --release
flutter build apk --release
```

### Profile Performance
```bash
flutter run --profile
```

## File Locations

- **Splash Screen:** `lib/src/screens/animated_splash_screen.dart`
- **Main App:** `lib/main.dart`
- **Demo App:** `lib/splash_demo.dart`
- **Logo Asset:** `assets/logo.png` (add this)
- **Config:** `pubspec.yaml`

## Documentation Files

- **Quick Start:** `SPLASH_SCREEN_QUICK_START.md`
- **Full Docs:** `SPLASH_SCREEN_IMPLEMENTATION.md`
- **Timeline:** `SPLASH_ANIMATION_TIMELINE.md`
- **Logo Guide:** `REPLACE_LOGO_GUIDE.md`
- **Summary:** `SPLASH_SCREEN_SUMMARY.md`
- **Checklist:** `SPLASH_SCREEN_CHECKLIST.md`

## Quick Edits

### Change Duration
File: `lib/src/screens/animated_splash_screen.dart`
Line: ~40 (SplashConfig class)
```dart
static const int totalDuration = 2200; // Change this
```

### Change Colors
File: `lib/src/screens/animated_splash_screen.dart`
Line: ~50 (SplashConfig class)
```dart
static const Color gradientStart = Color(0xFF2F80ED);
static const Color gradientEnd = Color(0xFF2563EB);
```

### Replace Logo
File: `lib/src/screens/animated_splash_screen.dart`
Line: ~580 (_buildLogoImage method)
See: `REPLACE_LOGO_GUIDE.md`

### Enable Particles
File: `lib/src/screens/animated_splash_screen.dart`
Line: ~70 (SplashConfig class)
```dart
static const bool enableParticles = true;
```

## That's It!

Everything is ready. Just run `flutter run` to see your splash screen! 🎉
