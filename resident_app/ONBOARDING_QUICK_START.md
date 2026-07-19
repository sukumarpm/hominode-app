# Onboarding Flow - Quick Start

Get the onboarding flow running in under 2 minutes.

## ⚡ Instant Demo

```bash
cd resident_app
flutter run -t lib/onboarding_main.dart
```

That's it! The onboarding flow will launch with a demo home screen.

---

## 🎯 What You'll See

1. **Screen 1:** Welcome to Lyvo (apartment icon)
2. **Screen 2:** Visitor Management (people icon)
3. **Screen 3:** Stay Updated (bell icon)
4. **Screen 4:** Safe & Secure (shield icon)

Each screen has:
- Large blue gradient card with white icon
- Bold italic title
- Two-line subtitle
- "Next" button (or "Get Started" on final screen)
- "Skip" link in top-right
- Progress dots at bottom

---

## 🎮 How to Use

### Navigation
- **Tap "Next"** - Go to next screen
- **Tap "Skip"** - Jump to end (shows snackbar)
- **Swipe left** - Next screen
- **Swipe right** - Previous screen
- **Tap "Get Started"** - Complete onboarding

### Testing
- Complete the flow to reach the demo home screen
- Tap "Restart Onboarding" to test again
- Close and reopen app - onboarding won't show (flag saved)

---

## 📋 Quick Commands

### Run Demo
```bash
flutter run -t lib/onboarding_main.dart
```

### Run on Specific Device
```bash
# iOS Simulator
flutter run -t lib/onboarding_main.dart -d "iPhone 13"

# Android Emulator
flutter run -t lib/onboarding_main.dart -d emulator-5554

# Physical Device
flutter run -t lib/onboarding_main.dart -d <device-id>
```

### List Available Devices
```bash
flutter devices
```

### Run in Release Mode (Better Performance)
```bash
flutter run -t lib/onboarding_main.dart --release
```

### Clear Onboarding Flag (Reset)
The demo home screen has a "Restart Onboarding" button, or manually:

```bash
# Clear app data (Android)
flutter run -t lib/onboarding_main.dart --clear-cache

# Or uninstall and reinstall
flutter clean
flutter run -t lib/onboarding_main.dart
```

---

## 🔧 Integration (30 seconds)

Add to your existing app's `main.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'src/screens/onboarding_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_completed') ?? false);
  
  runApp(MyApp(showOnboarding: showOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  
  const MyApp({Key? key, required this.showOnboarding}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: showOnboarding ? const OnboardingFlow() : const YourHomeScreen(),
      routes: {
        '/home': (context) => const YourHomeScreen(),
      },
    );
  }
}
```

Done! Onboarding shows on first launch only.

---

## 📁 Files Overview

```
lib/
├── onboarding_main.dart              # ← Run this for demo
└── src/
    ├── screens/
    │   └── onboarding_flow.dart      # Main widget
    ├── widgets/
    │   └── animated_onboarding_card.dart
    └── constants/
        └── onboarding_styles.dart    # Colors & typography
```

---

## 🎨 Quick Customization

### Change Colors
Edit `lib/src/constants/onboarding_styles.dart`:

```dart
static const Color primaryBlue = Color(0xFF2563EB);      // Your color
static const Color primaryBlueDark = Color(0xFF1E40AF);  // Darker shade
```

### Change Content
Edit `lib/src/screens/onboarding_flow.dart`, find `_pages`:

```dart
final List<OnboardingPage> _pages = [
  OnboardingPage(
    icon: Icons.your_icon,
    title: 'Your Title',
    subtitle: 'Your description',
    iconData: Icons.your_icon,
  ),
];
```

---

## ✅ Quick Test Checklist

- [ ] Run demo successfully
- [ ] See all 4 screens
- [ ] Swipe between screens works
- [ ] "Next" button advances
- [ ] "Skip" shows snackbar
- [ ] "Get Started" goes to home
- [ ] Animations are smooth
- [ ] Restart works from home screen

---

## 🐛 Troubleshooting

### "Target file not found"
```bash
# Make sure you're in the right directory
cd resident_app
flutter run -t lib/onboarding_main.dart
```

### "shared_preferences not found"
```bash
flutter pub get
flutter run -t lib/onboarding_main.dart
```

### Animations are choppy
```bash
# Run in release mode
flutter run -t lib/onboarding_main.dart --release
```

### Can't find device
```bash
# List devices
flutter devices

# Run on specific device
flutter run -t lib/onboarding_main.dart -d <device-id>
```

---

## 📚 More Info

- **Full Documentation:** `ONBOARDING_README.md`
- **Integration Guide:** `ONBOARDING_INTEGRATION_GUIDE.md`
- **Visual Reference:** `ONBOARDING_VISUAL_REFERENCE.md`
- **QA Checklist:** `ONBOARDING_ACCEPTANCE_CHECKLIST.md`

---

## 🚀 Next Steps

1. ✅ Run the demo (you're here!)
2. 📖 Read `ONBOARDING_INTEGRATION_GUIDE.md`
3. 🎨 Customize colors and content
4. 🔗 Integrate into your app
5. ✅ Use acceptance checklist to verify

---

**Need help?** Check the inline code comments or other documentation files.

**Ready to integrate?** See `ONBOARDING_INTEGRATION_GUIDE.md` for step-by-step instructions.
