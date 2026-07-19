# Modern Splash Screen - Integration Guide

## ✅ Setup Complete

Your logo is already configured:
- **File location**: `D:\Resident_App\resident_app\assets\logo1.png` ✓
- **pubspec.yaml**: Already includes `assets/logo1.png` ✓

## 🚀 Quick Start

### Option 1: Test as Standalone App
```dart
// Run the splash screen directly
flutter run lib/src/screens/modern_splash_screen.dart
```

### Option 2: Integrate into Your Main App

Update your `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'src/screens/modern_splash_screen.dart';
// Import your actual home screen
// import 'main_navigation.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ModernSplashScreen(), // Start with splash
    );
  }
}
```

### Option 3: Replace Navigation Target

In `modern_splash_screen.dart`, line 107, replace `HomeScreen()` with your actual home:

```dart
// Change this:
const HomeScreen(),

// To this:
const MainNavigation(), // or whatever your main screen is
```

## 🎨 Design Specs

- **Device**: iPhone 13 (390×844px)
- **Background**: Gradient #2563EB → #1E40AF
- **Card**: White, 32px radius, shadow (black 8%, blur 10, offset 0,6)
- **Logo**: 160×160px centered in card
- **Title**: "Lyvo" - 28pt, Semibold, White
- **Subtitle**: "Your Community, Connected" - 14pt, White 70%

## ⚡ Animation Timeline

- **0-1500ms**: Logo card scales (0.6 → 1.0) with easeOutBack + fade in
- **0-2200ms**: Progress bar animates
- **2200ms**: Auto-navigate to home with 500ms fade transition

## 🔧 Customization

### Change Colors
```dart
// In ModernSplashScreen, update gradient:
colors: [
  Color(0xFF2563EB), // Top color
  Color(0xFF1E40AF), // Bottom color
],
```

### Change Timing
```dart
// In _ModernSplashScreenState initState():
_controller = AnimationController(
  duration: const Duration(milliseconds: 2200), // Total duration
  vsync: this,
);

// Navigation delay:
Future.delayed(const Duration(milliseconds: 2200), () {
  // Navigate...
});
```

### Change Text
```dart
// Update title:
const Text('Lyvo', ...)

// Update subtitle:
Text('Your Community, Connected', ...)
```

## 📱 Testing

```bash
# Run on connected device
flutter run

# Run on specific device
flutter devices
flutter run -d <device-id>

# Hot reload works for most changes
# Press 'r' in terminal after making changes
```

## ✨ Features

- ✅ Production-ready code
- ✅ Null-safe
- ✅ GPU-optimized animations
- ✅ Responsive layout
- ✅ Error handling with fallback
- ✅ Proper animation disposal
- ✅ Smooth transitions
- ✅ No external dependencies

## 🎯 File Location

**Splash Screen**: `lib/src/screens/modern_splash_screen.dart`

The code is self-contained and ready to use!
