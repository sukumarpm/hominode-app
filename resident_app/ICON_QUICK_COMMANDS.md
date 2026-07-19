# ⚡ App Icon - Quick Commands

Fast reference for setting up your app icon.

---

## 🚀 Quick Setup (5 Minutes)

### 1. Add Package
```bash
# Add to pubspec.yaml dev_dependencies:
flutter_launcher_icons: ^0.13.1
```

### 2. Configure
Add to end of `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#2563EB"
  remove_alpha_ios: true
```

### 3. Create Icon File
```bash
# Create folder
mkdir -p assets/icon

# Place your 1024x1024 PNG icon as:
# assets/icon/app_icon.png
```

### 4. Generate
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### 5. Test
```bash
flutter clean
flutter run
```

---

## 📁 Required File Structure

```
resident_app/
├── assets/
│   └── icon/
│       └── app_icon.png (1024x1024)
└── pubspec.yaml (with config)
```

---

## 🎨 Icon Requirements

- **Size:** 1024x1024 pixels
- **Format:** PNG
- **Background:** Your choice (recommend #2563EB)
- **Content:** Simple, recognizable design
- **No transparency** for iOS

---

## ✅ Verification

```bash
# Check Android icons generated
ls android/app/src/main/res/mipmap-*/ic_launcher.png

# Check iOS icons generated
ls ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png

# Count files (should be 5 for Android, 16 for iOS)
ls android/app/src/main/res/mipmap-*/ic_launcher.png | wc -l
ls ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png | wc -l
```

---

## 🔧 Troubleshooting

### Icon not showing?
```bash
flutter clean
flutter pub get
flutter run
# Uninstall app from device first
```

### Need to regenerate?
```bash
flutter pub run flutter_launcher_icons
```

### Check package installed?
```bash
flutter pub deps | grep flutter_launcher_icons
```

---

## 🎯 Complete pubspec.yaml Example

```yaml
name: resident_app
description: "Lyvo - Your Community, Connected"
version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  # ... other dependencies

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  flutter_launcher_icons: ^0.13.1

flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
    - assets/icon/app_icon.png

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#2563EB"
  remove_alpha_ios: true
```

---

## 🎨 Quick Icon Design Options

### Option 1: Use Online Generator
- https://www.appicon.co/ (upload 1024x1024)
- https://makeappicon.com/ (generates all sizes)

### Option 2: Simple Text Icon
- Open Canva
- Create 1024x1024
- Blue circle (#2563EB)
- White letter "L"
- Download PNG

### Option 3: Use Material Icon
```dart
// Temporary - screenshot this for icon
Container(
  width: 1024,
  height: 1024,
  color: Color(0xFF2563EB),
  child: Icon(
    Icons.apartment,
    size: 600,
    color: Colors.white,
  ),
)
```

---

## 📱 Test Checklist

- [ ] Run `flutter pub run flutter_launcher_icons`
- [ ] Check files generated in Android mipmap folders
- [ ] Check files generated in iOS AppIcon.appiconset
- [ ] Run `flutter clean`
- [ ] Uninstall app from device
- [ ] Run `flutter run`
- [ ] Check icon on home screen
- [ ] Icon is sharp and clear
- [ ] Colors match brand (#2563EB)

---

## 🚨 Common Errors

### Error: "No pubspec.yaml found"
```bash
# Make sure you're in the project root
cd resident_app
flutter pub run flutter_launcher_icons
```

### Error: "Image not found"
```bash
# Check file exists
ls assets/icon/app_icon.png

# Check path in pubspec.yaml matches
```

### Error: "Invalid image format"
```bash
# Convert to PNG if needed
# Must be PNG, not JPEG or other format
```

---

## 💡 Pro Tips

1. **Keep source file** - Save your 1024x1024 PNG for future updates
2. **Test on real device** - Emulators may not show icon correctly
3. **Simple is better** - Complex icons don't scale well
4. **Use brand colors** - #2563EB for consistency
5. **No text** - Text is hard to read at small sizes

---

## 🎯 One-Line Setup

If you have your icon ready:
```bash
mkdir -p assets/icon && flutter pub add dev:flutter_launcher_icons && flutter pub run flutter_launcher_icons && flutter clean && flutter run
```

---

**Need the full guide?** See `APP_ICON_SETUP_GUIDE.md`
