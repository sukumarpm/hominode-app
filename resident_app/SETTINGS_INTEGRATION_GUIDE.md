# Settings Screen - Quick Integration Guide

## 🚀 Quick Start (5 minutes)

### 1. Add to Profile Screen
```dart
// In profile_screen.dart
import 'src/screens/settings_screen.dart';

// Add settings button/tile
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  },
  child: Container(
    // Your settings tile design
    child: Row(
      children: [
        Icon(Icons.settings),
        Text('Settings'),
        Spacer(),
        Icon(Icons.chevron_right),
      ],
    ),
  ),
)
```

### 2. Test the Demo
```bash
flutter run lib/settings_demo.dart
```

## 📁 Files Created

```
lib/
├── src/
│   ├── models/
│   │   └── setting_item.dart          ✅ Created
│   ├── components/
│   │   ├── setting_tile.dart          ✅ Created
│   │   └── settings_toggle.dart       ✅ Created
│   └── screens/
│       └── settings_screen.dart       ✅ Created
├── settings_demo.dart                 ✅ Created
├── SETTINGS_SCREEN_README.md          ✅ Created
└── SETTINGS_INTEGRATION_GUIDE.md      ✅ This file
```

## 🔗 Connect to Existing Screens

### Family & Vehicles
```dart
void _navigateToFamilyMembers() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const FamilyVehiclesScreen(),
    ),
  );
}
```

### Payment Methods
```dart
void _navigateToPaymentMethods() {
  // TODO: Create or import PaymentMethodsScreen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const PaymentMethodsScreen(),
    ),
  );
}
```

## 💾 Add Persistence (SharedPreferences)

### 1. Add dependency
```yaml
# pubspec.yaml
dependencies:
  shared_preferences: ^2.2.2
```

### 2. Load settings on init
```dart
@override
void initState() {
  super.initState();
  _loadSettings();
}

Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _biometricEnabled = prefs.getBool('biometric_enabled') ?? true;
    _darkModeEnabled = prefs.getBool('dark_mode') ?? false;
  });
}
```

### 3. Save settings on change
```dart
Future<void> _saveBiometricSetting(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('biometric_enabled', value);
}
```

## 🔐 Add Biometric Authentication

### 1. Add dependency
```yaml
dependencies:
  local_auth: ^2.1.7
```

### 2. Implement biometric check
```dart
import 'package:local_auth/local_auth.dart';

Future<void> _toggleBiometric(bool value) async {
  if (value) {
    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    
    if (canCheck) {
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Enable biometric login',
      );
      
      if (authenticated) {
        setState(() => _biometricEnabled = true);
        await _saveBiometricSetting(true);
      }
    }
  } else {
    setState(() => _biometricEnabled = false);
    await _saveBiometricSetting(false);
  }
}
```

## 🌐 Connect to Backend API

### Example API Service
```dart
class SettingsService {
  final String baseUrl = 'https://api.yourapp.com';
  
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(settings),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update settings');
    }
  }
  
  Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/settings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load settings');
  }
}
```

### Usage in Settings Screen
```dart
final _settingsService = SettingsService();

Future<void> _saveDarkModeSetting(bool value) async {
  // Save locally
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dark_mode', value);
  
  // Sync to backend
  try {
    await _settingsService.updateSettings({
      'dark_mode': value,
    });
  } catch (e) {
    // Handle error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to sync settings: $e')),
    );
  }
}
```

## 🎨 Customize Colors

### Update to match your brand
```dart
// In settings_screen.dart, update colors:

// Header gradient
colors: [Color(0xFFYOUR_COLOR_1), Color(0xFFYOUR_COLOR_2)]

// Primary blue
const Color(0xFF2563EB) → const Color(0xFFYOUR_PRIMARY)

// Success green
const Color(0xFF22C55E) → const Color(0xFFYOUR_SUCCESS)

// Danger red
const Color(0xFFEF4444) → const Color(0xFFYOUR_DANGER)
```

## ✅ Testing Checklist

- [ ] Settings screen opens from profile
- [ ] All navigation items work
- [ ] Toggles animate smoothly
- [ ] Settings persist after app restart
- [ ] Logout confirmation works
- [ ] Delete account confirmation works
- [ ] Report issue modal works
- [ ] Language selector works
- [ ] Status badges display correctly
- [ ] Scrolling is smooth
- [ ] Back button works
- [ ] No console errors

## 🐛 Common Issues

### Issue: Toggle not animating
**Solution**: Ensure `SingleTickerProviderStateMixin` is used in SettingsToggle

### Issue: Settings not persisting
**Solution**: Check SharedPreferences is initialized and await is used

### Issue: Navigation not working
**Solution**: Verify screen imports and routes are correct

### Issue: Colors don't match
**Solution**: Update color constants to match your app's theme

## 📱 Screenshots Locations

To add screenshots:
1. Run the app on iPhone 13 simulator
2. Navigate to Settings
3. Take screenshots of:
   - Main settings screen
   - Toggle animation
   - Confirmation dialogs
   - Modal bottom sheets

## 🚢 Production Checklist

Before deploying:
- [ ] Replace all TODO comments with actual implementations
- [ ] Add proper error handling
- [ ] Implement actual logout logic
- [ ] Connect to real backend APIs
- [ ] Add analytics tracking
- [ ] Test on multiple devices
- [ ] Test with different screen sizes
- [ ] Add loading states
- [ ] Add offline support
- [ ] Test accessibility
- [ ] Add unit tests
- [ ] Add widget tests
- [ ] Update documentation

## 📞 Support

For questions or issues:
- Check `SETTINGS_SCREEN_README.md` for detailed documentation
- Review code comments in source files
- Test with `settings_demo.dart`

---

**Integration Time**: ~15 minutes
**Customization Time**: ~30 minutes
**Full Backend Integration**: ~2 hours
**Status**: Ready to integrate ✅
