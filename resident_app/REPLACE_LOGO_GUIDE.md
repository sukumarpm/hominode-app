# 🎨 Logo Replacement Guide

## Current Status

The splash screen currently uses a **custom-painted placeholder logo** that mimics the Lyvo design. You need to replace it with your actual logo asset.

## 3-Step Replacement Process

### Step 1: Prepare Your Logo

**Recommended Specifications:**
- **Size:** 120x120 pixels (or larger, will be scaled)
- **Format:** PNG with transparency (recommended) or SVG
- **Background:** Transparent
- **Colors:** White or light colors (shows on blue gradient)
- **Quality:** High resolution (2x or 3x for retina displays)

**File naming:**
```
logo.png          (1x - 120x120px)
logo@2x.png       (2x - 240x240px) - Optional but recommended
logo@3x.png       (3x - 360x360px) - Optional but recommended
```

Or for vector:
```
logo.svg          (Scalable vector - best quality)
```

### Step 2: Add Logo to Assets

1. **Create assets folder** (if it doesn't exist):
   ```
   resident_app/
   └── assets/
       └── logo.png
   ```

2. **Copy your logo file** to `resident_app/assets/logo.png`

3. **Update `pubspec.yaml`:**

   Find the `flutter:` section and add:
   ```yaml
   flutter:
     assets:
       - assets/logo.png
       # Or if using multiple resolutions:
       - assets/logo.png
       - assets/logo@2x.png
       - assets/logo@3x.png
       # Or if using SVG:
       - assets/logo.svg
   ```

4. **Run pub get:**
   ```bash
   flutter pub get
   ```

### Step 3: Update the Code

Open `lib/src/screens/animated_splash_screen.dart` and find the `_buildLogoImage()` method (around line 580).

#### Option A: PNG Logo (Recommended)

**Find this code:**
```dart
Widget _buildLogoImage({double opacity = 1.0}) {
  // Replace with your actual logo asset
  // For now, using a placeholder that matches the design
  return Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(20),
    ),
    child: CustomPaint(
      painter: _LyvoLogoPainter(opacity: opacity),
    ),
  );
  
  // UNCOMMENT THIS TO USE YOUR ACTUAL LOGO IMAGE:
  // return Image.asset(
  //   'assets/logo.png',
  //   width: 120,
  //   height: 120,
  //   opacity: AlwaysStoppedAnimation(opacity),
  // );
}
```

**Replace with:**
```dart
Widget _buildLogoImage({double opacity = 1.0}) {
  return Image.asset(
    'assets/logo.png',
    width: 120,
    height: 120,
    opacity: AlwaysStoppedAnimation(opacity),
  );
}
```

#### Option B: SVG Logo (Best Quality)

1. **Add dependency to `pubspec.yaml`:**
   ```yaml
   dependencies:
     flutter_svg: ^2.0.9
   ```

2. **Run pub get:**
   ```bash
   flutter pub get
   ```

3. **Add import at top of file:**
   ```dart
   import 'package:flutter_svg/flutter_svg.dart';
   ```

4. **Replace `_buildLogoImage()` method:**
   ```dart
   Widget _buildLogoImage({double opacity = 1.0}) {
     return SvgPicture.asset(
       'assets/logo.svg',
       width: 120,
       height: 120,
       colorFilter: ColorFilter.mode(
         Colors.white.withOpacity(opacity),
         BlendMode.srcIn,
       ),
     );
   }
   ```

#### Option C: Keep Custom Painter (Customize)

If you want to keep the custom painter but match your exact logo design:

1. Find the `_LyvoLogoPainter` class (around line 640)
2. Modify the `paint()` method to draw your logo shape
3. Use paths, shapes, and colors to recreate your logo

**Example structure:**
```dart
class _LyvoLogoPainter extends CustomPainter {
  final double opacity;

  _LyvoLogoPainter({this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Draw your logo shapes here
    // Example: Circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Add more shapes as needed
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

## Verification

### Test Your Logo

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Or test splash in isolation:**
   ```bash
   flutter run lib/splash_demo.dart
   ```

3. **Check that:**
   - [ ] Logo appears centered
   - [ ] Logo is the right size (120x120)
   - [ ] Logo is visible on blue gradient
   - [ ] Logo animates smoothly
   - [ ] Logo has proper transparency
   - [ ] Logo looks sharp (not pixelated)

### Troubleshooting

**Logo not showing:**
- ✅ Check file path: `assets/logo.png` exists
- ✅ Verify `pubspec.yaml` includes asset
- ✅ Run `flutter pub get`
- ✅ Restart app (hot reload may not work for assets)
- ✅ Check console for asset loading errors

**Logo looks pixelated:**
- ✅ Use higher resolution (2x or 3x)
- ✅ Or switch to SVG format
- ✅ Ensure source image is high quality

**Logo wrong color:**
- ✅ Use white or light-colored logo
- ✅ Ensure PNG has transparency
- ✅ Check if logo has dark background

**Logo wrong size:**
- ✅ Adjust `width` and `height` parameters
- ✅ Recommended: 100-140px range

## Advanced: Multiple Logo Layers

If your logo has multiple layers (main + shadow), you can add them separately:

### Step 1: Prepare Assets
```
assets/
├── logo_main.png
└── logo_shadow.png
```

### Step 2: Update Code
```dart
Widget _buildLogoImage({double opacity = 1.0}) {
  return Stack(
    alignment: Alignment.center,
    children: [
      // Shadow layer
      Image.asset(
        'assets/logo_shadow.png',
        width: 120,
        height: 120,
        opacity: AlwaysStoppedAnimation(opacity * 0.5),
      ),
      // Main layer
      Image.asset(
        'assets/logo_main.png',
        width: 120,
        height: 120,
        opacity: AlwaysStoppedAnimation(opacity),
      ),
    ],
  );
}
```

## Logo Size Adjustment

If you want to change the logo size:

### Find all instances of logo size (120):
```dart
// In _buildLogoImage()
width: 120,   // Change to your desired size
height: 120,  // Change to your desired size

// In shadow container (around line 540)
width: 120,   // Change to match logo size
height: 120,  // Change to match logo size
```

### Recommended sizes:
- **Small:** 80-100px (subtle)
- **Medium:** 120px (current, recommended)
- **Large:** 140-160px (prominent)

## Logo with Background

If your logo needs a background (not transparent):

```dart
Widget _buildLogoImage({double opacity = 1.0}) {
  return Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Image.asset(
      'assets/logo.png',
      opacity: AlwaysStoppedAnimation(opacity),
    ),
  );
}
```

## Logo Color Tinting

To tint your logo to match the gradient:

```dart
Widget _buildLogoImage({double opacity = 1.0}) {
  return Image.asset(
    'assets/logo.png',
    width: 120,
    height: 120,
    opacity: AlwaysStoppedAnimation(opacity),
    color: Colors.white, // Tint color
    colorBlendMode: BlendMode.srcIn, // Blend mode
  );
}
```

## Quick Reference

### File Structure
```
resident_app/
├── assets/
│   └── logo.png              ← Your logo here
├── lib/
│   └── src/
│       └── screens/
│           └── animated_splash_screen.dart  ← Edit this file
└── pubspec.yaml              ← Add asset here
```

### Code Location
- **File:** `lib/src/screens/animated_splash_screen.dart`
- **Method:** `_buildLogoImage()` (around line 580)
- **Lines to change:** ~10 lines

### Commands
```bash
# After adding logo
flutter pub get

# Test splash
flutter run lib/splash_demo.dart

# Run full app
flutter run
```

## Checklist

- [ ] Logo file prepared (120x120px or larger)
- [ ] Logo copied to `assets/` folder
- [ ] `pubspec.yaml` updated with asset path
- [ ] `flutter pub get` executed
- [ ] Code updated in `_buildLogoImage()`
- [ ] App tested (logo appears correctly)
- [ ] Logo visible on blue gradient
- [ ] Logo animates smoothly
- [ ] Logo looks sharp (not pixelated)
- [ ] Logo size is appropriate

## Done!

Once you complete these steps, your actual logo will appear in the splash screen with all the smooth animations intact.

**Need help?** Check the inline comments in `animated_splash_screen.dart` or refer to `SPLASH_SCREEN_IMPLEMENTATION.md`.
