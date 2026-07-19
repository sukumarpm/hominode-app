# Logo Setup Instructions

## Your Logo Files

I can see you've provided two logo images:
1. Blue background version (for light backgrounds)
2. Transparent/dark version (for dark backgrounds)

## Setup Steps

### Step 1: Save the Logo
Save the **transparent/dark version** (second image) as:
```
resident_app/assets/logo.png
```

This version will work best on the blue gradient splash screen background.

### Step 2: Run Flutter Pub Get
```bash
cd resident_app
flutter pub get
```

### Step 3: Test the Splash Screen
```bash
flutter run
```

## Logo Specifications

The splash screen is configured for:
- **Size:** 140x140 pixels (will scale automatically)
- **Format:** PNG with transparency
- **Background:** Transparent (shows on blue gradient)
- **Colors:** White/light colors work best

## Current Implementation

The splash screen will:
✅ Load `assets/logo.png`
✅ Apply smooth animations (scale, rotate, fade)
✅ Show fallback "L" if logo not found
✅ Work on all screen sizes

## If Logo Doesn't Show

If you see a white "L" instead of your logo:
1. Check that `assets/logo.png` exists
2. Run `flutter pub get`
3. Restart the app (hot reload won't work for new assets)
4. Check console for any asset loading errors

## Alternative: Use Both Logos

If you want to use both versions:

1. Save both images:
   ```
   assets/logo_blue.png    (blue background version)
   assets/logo_white.png   (transparent version)
   ```

2. Update `pubspec.yaml`:
   ```yaml
   assets:
     - assets/logo_blue.png
     - assets/logo_white.png
   ```

3. Use the white/transparent version for splash:
   ```dart
   Image.asset('assets/logo_white.png', ...)
   ```

## Need Help?

The logo is already integrated in the code. Just save your logo file to `assets/logo.png` and run the app!
