# Onboarding Flow - Quick Reference Card

## ⚡ Run Demo (30 seconds)

```bash
cd resident_app
flutter run -t lib/onboarding_main.dart
```

---

## 📁 Files

```
lib/
├── onboarding_main.dart                    # Run this!
└── src/
    ├── screens/onboarding_flow.dart       # Main widget
    ├── widgets/animated_onboarding_card.dart
    └── constants/onboarding_styles.dart   # Colors & styles
```

---

## 🎨 Quick Customization

### Change Colors
`lib/src/constants/onboarding_styles.dart`
```dart
static const Color primaryBlue = Color(0xFF2563EB);
```

### Change Content
`lib/src/screens/onboarding_flow.dart` → Find `_pages`
```dart
OnboardingPage(
  icon: Icons.your_icon,
  title: 'Your Title',
  subtitle: 'Your description',
  iconData: Icons.your_icon,
)
```

---

## 🔗 Integration (1 minute)

Add to `main.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'src/screens/onboarding_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_completed') ?? false);
  runApp(MyApp(showOnboarding: showOnboarding));
}
```

---

## 📱 Screens

1. **Welcome to Lyvo** (apartment icon)
2. **Visitor Management** (people icon)
3. **Stay Updated** (bell icon)
4. **Safe & Secure** (shield icon)

---

## 🎯 Key Features

✅ Swipe between pages  
✅ Skip to end  
✅ Smooth animations  
✅ Progress dots  
✅ State persistence  
✅ Responsive design  

---

## 🎨 Design Specs

```
Colors:     #2563EB → #1E40AF (gradient)
Card:       254px × 254px, 20px radius
Title:      34px, bold italic
Subtitle:   15px, regular
Button:     56px height, full width
```

---

## 📚 Documentation

- `ONBOARDING_QUICK_START.md` - Start here
- `ONBOARDING_INTEGRATION_GUIDE.md` - Integration steps
- `ONBOARDING_README.md` - Full docs
- `ONBOARDING_VISUAL_REFERENCE.md` - Design specs
- `ONBOARDING_ACCEPTANCE_CHECKLIST.md` - QA testing

---

## 🐛 Troubleshooting

**Can't find file?**
```bash
cd resident_app
flutter run -t lib/onboarding_main.dart
```

**Missing dependency?**
```bash
flutter pub get
```

**Choppy animations?**
```bash
flutter run -t lib/onboarding_main.dart --release
```

---

## ✅ Quick Test

- [ ] Run demo
- [ ] See all 4 screens
- [ ] Swipe works
- [ ] Skip works
- [ ] Animations smooth

---

**Need more info?** → `ONBOARDING_QUICK_START.md`
