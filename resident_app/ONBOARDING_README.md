# Onboarding Flow - Production Ready

A pixel-perfect, animated 4-page onboarding flow for Flutter apps, matching iPhone 13 design specifications.

## Features

✅ **4 Beautiful Screens**
- Welcome to Lyvo (apartment icon)
- Visitor Management (people icon)
- Stay Updated (notification bell icon)
- Safe & Secure (shield icon)

✅ **Smooth Animations**
- Card entrance: fade-in + scale with ease-out-back curve
- Page transitions: slide + cross-fade (350ms)
- Button press: micro-interaction with scale effect
- Background: subtle wave animation for premium feel

✅ **Modern Interactions**
- Swipe left/right between pages
- Skip button with confirmation snackbar
- Progress dots indicator
- Responsive to all screen sizes

✅ **Accessibility**
- Semantic labels on all interactive elements
- Minimum 44px touch targets
- Screen reader support

✅ **State Persistence**
- Saves `onboarding_completed` flag using SharedPreferences
- App can check flag to bypass onboarding on subsequent launches

## Quick Start

### 1. Run the Demo

```bash
# Run standalone onboarding demo
flutter run -t lib/onboarding_main.dart
```

### 2. Integrate into Your App

```dart
import 'package:resident_app/src/screens/onboarding_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

// In your main.dart or splash screen:
Future<void> checkOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  final completed = prefs.getBool('onboarding_completed') ?? false;
  
  if (completed) {
    // Navigate to home
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    // Show onboarding
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
    );
  }
}
```

### 3. Add to pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.2.2

# Optional: Add custom onboarding images
# assets:
#   - assets/onboarding/welcome.png
#   - assets/onboarding/visitors.png
#   - assets/onboarding/notifications.png
#   - assets/onboarding/security.png
```

## File Structure

```
lib/
├── onboarding_main.dart                    # Standalone demo app
├── src/
    ├── screens/
    │   └── onboarding_flow.dart           # Main onboarding widget
    ├── widgets/
    │   └── animated_onboarding_card.dart  # Reusable animated card
    └── constants/
        └── onboarding_styles.dart         # Colors, typography, spacing
```

## Customization

### Change Colors

Edit `lib/src/constants/onboarding_styles.dart`:

```dart
static const Color primaryBlue = Color(0xFF2563EB);      // Your brand color
static const Color primaryBlueDark = Color(0xFF1E40AF);  // Darker shade
static const Color backgroundColor = Color(0xFFF7F7F7);  // Background
```

### Change Content

Edit the `_pages` list in `onboarding_flow.dart`:

```dart
final List<OnboardingPage> _pages = [
  OnboardingPage(
    icon: Icons.your_icon,
    title: 'Your Title',
    subtitle: 'Your subtitle text here',
    iconData: Icons.your_icon,
  ),
  // Add more pages...
];
```

### Use Custom Images

Replace `Icon` widget in `animated_onboarding_card.dart`:

```dart
// Instead of:
Icon(widget.icon, size: cardSize * 0.4, color: Colors.white)

// Use:
Image.asset(
  'assets/onboarding/${widget.imagePath}',
  width: cardSize * 0.5,
  height: cardSize * 0.5,
  color: Colors.white,
)
```

## Design Specifications

### Colors
- Primary Blue: `#2563EB`
- Primary Blue Dark: `#1E40AF`
- Background: `#F7F7F7`
- Text Primary: `#111111`
- Text Secondary: `#666666`

### Typography
- Title: 34px, Bold Italic, -0.5 letter spacing
- Subtitle: 15px, Regular, 1.5 line height
- Button: 18px, Semibold, 0.2 letter spacing
- Skip: 16px, Medium

### Layout (iPhone 13 - 390px width)
- Card size: 65% of screen width (~254px)
- Card border radius: 20px
- Icon size: 40% of card size
- Horizontal padding: 16px
- Button height: 56px
- Button border radius: 12px

### Animations
- Card entrance: 600ms ease-out-back
- Page transition: 350ms ease-out-cubic
- Button press: 200ms scale (0.95x)
- Wave background: 2000ms loop

## Testing Checklist

- [ ] All 4 screens display correctly
- [ ] Card gradient matches design (blue gradient)
- [ ] Icons are centered and white
- [ ] Title is bold italic, large size
- [ ] Subtitle is centered, two lines
- [ ] Skip button works and shows snackbar
- [ ] Next button advances pages
- [ ] Get Started navigates to home
- [ ] Page dots update correctly
- [ ] Swipe gestures work
- [ ] Animations are smooth
- [ ] Status bar doesn't overlap content
- [ ] Works on different screen sizes
- [ ] Onboarding flag persists correctly

## Dependencies

- `shared_preferences: ^2.2.2` - For saving onboarding completion state

## Notes

- Target device: iPhone 13 (390px width) but responsive
- Uses SafeArea to prevent status bar overlap
- Implements Material Design accessibility guidelines
- Production-ready code with proper error handling
- Clean, well-commented code structure

## Integration Example

```dart
// In your main.dart
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
      home: showOnboarding ? const OnboardingFlow() : const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
```

## Support

For issues or questions, refer to the inline code comments or check the Flutter documentation for animation and navigation patterns.
