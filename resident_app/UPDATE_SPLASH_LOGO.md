# 🎨 Update Splash Screen Logo

## 📍 Current Splash Logo Location

```
D:\Resident_App\resident_app\assets\logo1.png
```

## 🔄 How to Change the Splash Screen Logo

### Step 1: Replace the Logo File

1. **Prepare your new logo**:
   - Recommended size: **1024x1024px** or larger
   - Format: PNG with transparency
   - Keep important content in the center
   - Logo will be displayed on blue gradient background

2. **Replace the file**:
   - Navigate to: `D:\Resident_App\resident_app\assets\`
   - Replace `logo1.png` with your new logo
   - Keep the same filename: `logo1.png`

### Step 2: Regenerate Splash Screen

After replacing the logo, run these commands:

```bash
cd D:\Resident_App\resident_app
flutter pub run flutter_native_splash:create
flutter clean
flutter pub get
flutter run
```

## 📱 Where the Logo Appears

The `logo1.png` is used in:
- **Splash Screen** - Shows when app launches
- **App Icon** (if configured)

## 🎨 Logo Design Tips

### Best Practices
- **Size**: 1024x1024px minimum
- **Format**: PNG with transparency
- **Content**: Keep logo centered
- **Safe Zone**: Keep important elements in center 70%
- **Background**: Transparent (will show on blue gradient)
- **Colors**: White or light colors work best on blue background

### For SocietyConnect App
Consider these elements:
- 🏢 Building/apartment icon
- 🏠 Home symbol
- 👥 Community icon
- Clean, modern design
- Simple and recognizable

## 🔧 Alternative: Use a Different File

If you want to use a different filename (not `logo1.png`), I can update the configuration.

**Current splash configuration** uses:
- `assets/logo1.png` for the splash screen logo

**To use a different file**:
1. Add your new logo to `assets/` folder (e.g., `new_logo.png`)
2. Let me know the filename
3. I'll update `splash_config.json` to use it

## 📝 Quick Steps

1. **Replace** `D:\Resident_App\resident_app\assets\logo1.png` with your new logo
2. **Run**: `flutter pub run flutter_native_splash:create`
3. **Clean**: `flutter clean && flutter pub get`
4. **Test**: `flutter run`

## ✅ Verification

After updating:
- [ ] Logo file replaced at `assets/logo1.png`
- [ ] Splash screen regenerated
- [ ] App cleaned and rebuilt
- [ ] New logo appears on splash screen
- [ ] Logo looks good on blue gradient background

---

**Current Logo**: `assets/logo1.png`  
**Action**: Replace file, then regenerate splash  
**Command**: `flutter pub run flutter_native_splash:create`
