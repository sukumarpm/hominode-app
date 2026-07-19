# Onboarding Flow - Integration Guide

Quick guide to integrate the onboarding flow into your existing Flutter app.

## 🚀 Quick Start (Standalone Demo)

Test the onboarding flow immediately:

```bash
cd resident_app
flutter run -t lib/onboarding_main.dart
```

This runs a standalone demo with a placeholder home screen.

## 📦 Files Created

```
resident_app/
├── lib/
│   ├── onboarding_main.dart                    # Standalone demo app
│   └── src/
│       ├── screens/
│       │   └── onboarding_flow.dart           # Main onboarding widget
│       ├── widgets/
│       │   └── animated_onboarding_card.dart  # Animated card component
│       └── constants/
│           └── onboarding_styles.dart         # Design system constants
├── ONBOARDING_README.md                        # Full documentation
├── ONBOARDING_INTEGRATION_GUIDE.md            # This file
└── ONBOARDING_ACCEPTANCE_CHECKLIST.md         # QA checklist
```

## 🔧 Integration Steps

### Option 1: Show Onboarding on First Launch (Recommended)

Modify your `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/screens/onboarding_flow.dart';
import 'main_navigation.dart'; // Your existing home screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;
  
  runApp(MyApp(showOnboarding: !hasCompletedOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  
  const MyApp({Key? key, required this.showOnboarding}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Show onboarding or home based on flag
      home: showOnboarding ? const OnboardingFlow() : const MainNavigation(),
      routes: {
        '/home': (context) => const MainNavigation(),
        '/onboarding': (context) => const OnboardingFlow(),
      },
    );
  }
}
```

### Option 2: Show from Splash Screen

If you have a splash screen, check onboarding status there:

```dart
// In your splash_screen.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/onboarding_flow.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));
    
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;
    
    if (!mounted) return;
    
    if (hasCompletedOnboarding) {
      // Go to home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Show onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

### Option 3: Manual Trigger (Settings)

Add an option in settings to replay onboarding:

```dart
// In your settings screen
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text('View Tutorial'),
  subtitle: const Text('Replay the onboarding flow'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OnboardingFlow(),
      ),
    );
  },
)
```

## 🎨 Customization

### Change Colors

Edit `lib/src/constants/onboarding_styles.dart`:

```dart
static const Color primaryBlue = Color(0xFF2563EB);      // Your brand color
static const Color primaryBlueDark = Color(0xFF1E40AF);  // Darker shade
```

### Change Content

Edit `lib/src/screens/onboarding_flow.dart`, find the `_pages` list:

```dart
final List<OnboardingPage> _pages = [
  OnboardingPage(
    icon: Icons.your_icon,           // Change icon
    title: 'Your Title',             // Change title
    subtitle: 'Your description',    // Change subtitle
    iconData: Icons.your_icon,
  ),
  // Add or remove pages as needed
];
```

### Use Custom Images Instead of Icons

1. Add images to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/onboarding/welcome.png
    - assets/onboarding/visitors.png
    - assets/onboarding/notifications.png
    - assets/onboarding/security.png
```

2. Modify `animated_onboarding_card.dart`:

```dart
// Replace the Icon widget with:
Image.asset(
  'assets/onboarding/${widget.imagePath}',
  width: cardSize * 0.5,
  height: cardSize * 0.5,
  color: Colors.white,
)
```

3. Update `OnboardingPage` model to include `imagePath`:

```dart
class OnboardingPage {
  final String imagePath;
  final String title;
  final String subtitle;

  OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}
```

## 🧪 Testing

### Test Onboarding Flow

```bash
# Run standalone demo
flutter run -t lib/onboarding_main.dart

# Test in your main app
flutter run
```

### Reset Onboarding Flag (for testing)

Add this helper function anywhere in your app:

```dart
Future<void> resetOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('onboarding_completed');
  print('Onboarding flag cleared');
}
```

Or use the placeholder home screen in the demo which has a "Restart Onboarding" button.

### Manual Testing Checklist

- [ ] Onboarding shows on first app launch
- [ ] All 4 screens display correctly
- [ ] Can swipe between screens
- [ ] "Next" button works
- [ ] "Skip" button works and shows snackbar
- [ ] "Get Started" navigates to home
- [ ] Onboarding doesn't show on second launch
- [ ] Animations are smooth
- [ ] Works on different screen sizes

## 🔍 Troubleshooting

### Onboarding Shows Every Time

The flag isn't being saved. Check:
- `shared_preferences` is in `pubspec.yaml`
- Run `flutter pub get`
- Check console for errors when saving

### Navigation Doesn't Work

Make sure your routes are configured:

```dart
MaterialApp(
  routes: {
    '/home': (context) => const YourHomeScreen(),
  },
)
```

### Animations Are Choppy

- Run in Release mode: `flutter run --release`
- Check device performance
- Reduce wave animation complexity if needed

### Icons Don't Display

Make sure you're using Material Icons:

```dart
Icon(Icons.apartment_rounded)  // ✅ Correct
Icon(Icons.apartment)          // ✅ Also works
```

## 📱 Platform-Specific Notes

### iOS
- Status bar icons are automatically dark on light background
- Safe area is handled automatically
- No additional configuration needed

### Android
- Status bar is transparent by default
- Safe area is handled automatically
- Test on devices with notches/cutouts

## 🎯 Next Steps

1. **Test the standalone demo** to see the flow in action
2. **Choose an integration option** (first launch, splash, or manual)
3. **Customize content and colors** to match your brand
4. **Test on multiple devices** to ensure responsiveness
5. **Use the acceptance checklist** to verify everything works

## 📚 Additional Resources

- **ONBOARDING_README.md** - Full documentation
- **ONBOARDING_ACCEPTANCE_CHECKLIST.md** - QA testing checklist
- **Flutter Animation Docs** - https://flutter.dev/docs/development/ui/animations

## 💡 Tips

- Keep onboarding screens to 3-5 pages maximum
- Make content scannable and concise
- Test with real users to validate flow
- Consider A/B testing different content
- Allow users to replay onboarding from settings

---

**Need Help?** Check the inline code comments or refer to the full README.
