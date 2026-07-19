# Multi-Language Support - Quick Start Guide

## 🚀 Quick Setup (5 minutes)

### Step 1: Update Dependencies
```bash
flutter pub get
```

### Step 2: Generate Localization Files
```bash
flutter gen-l10n
```

### Step 3: Update main.dart
Replace your `main.dart` with the localized version:
```bash
cp lib/main_localized.dart lib/main.dart
```

### Step 4: Run the App
```bash
flutter run
```

---

## 📱 Using Translations in Your Code

### In Any Widget
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Text(l10n?.homeWelcome ?? 'Welcome');
  }
}
```

### Access Current Language
```dart
import 'package:provider/provider.dart';
import 'src/providers/localization_provider.dart';

Consumer<LocalizationProvider>(
  builder: (context, localizationProvider, _) {
    return Text('Language: ${localizationProvider.currentLanguage}');
  },
)
```

---

## 🌐 Language Switcher

### Add to Settings Screen
```dart
import 'src/widgets/language_switcher.dart';

LanguageSwitcher(
  isCompact: false,
  onLanguageChanged: () {
    print('Language changed!');
  },
)
```

### Show Language Dialog
```dart
showDialog(
  context: context,
  builder: (context) => LanguageSwitcherDialog(),
);
```

---

## 📝 Adding New Translations

### 1. Edit ARB Files
Edit `lib/l10n/app_en.arb` and add:
```json
{
  "myNewKey": "My new text"
}
```

Do the same for all other language files:
- `app_ta.arb` (Tamil)
- `app_hi.arb` (Hindi)
- `app_es.arb` (Spanish)
- `app_ar.arb` (Arabic)

### 2. Regenerate
```bash
flutter gen-l10n
```

### 3. Use in Code
```dart
Text(l10n?.myNewKey ?? 'Fallback')
```

---

## 🎯 Supported Languages

| Language | Code | Flag |
|----------|------|------|
| English | en | 🇬🇧 |
| Tamil | ta | 🇮🇳 |
| Hindi | hi | 🇮🇳 |
| Spanish | es | 🇪🇸 |
| Arabic | ar | 🇸🇦 |

---

## ✨ Features

✅ **5 Languages**: English, Tamil, Hindi, Spanish, Arabic
✅ **RTL Support**: Automatic for Arabic
✅ **Persistent**: Language saved to device
✅ **Dynamic**: Change language without restart
✅ **Easy Integration**: Simple API for translations
✅ **Complete UI**: Settings screen with language switcher

---

## 🔧 Common Tasks

### Change Language Programmatically
```dart
final provider = context.read<LocalizationProvider>();
await provider.setLanguage('ar');
```

### Check if RTL
```dart
final isRTL = context.read<LocalizationProvider>().isRTL;
```

### Get Language Name
```dart
final name = context.read<LocalizationProvider>()
    .getLanguageName('ta'); // Returns "Tamil"
```

---

## 🧪 Testing

### Test in Different Languages
```bash
# English
flutter run

# Arabic (RTL)
flutter run --dart-define=LOCALE=ar
```

### Check RTL Layout
1. Change language to Arabic
2. Verify all UI elements align correctly
3. Check text direction is right-to-left

---

## 📂 File Structure

```
lib/
├── l10n/
│   ├── app_en.arb
│   ├── app_ta.arb
│   ├── app_hi.arb
│   ├── app_es.arb
│   └── app_ar.arb
├── gen/l10n/
│   └── app_localizations.dart (auto-generated)
├── src/
│   ├── services/localization_service.dart
│   ├── providers/localization_provider.dart
│   ├── widgets/language_switcher.dart
│   └── screens/app_settings_screen.dart
└── main.dart (updated with localization)
```

---

## 🐛 Troubleshooting

### Translations Not Showing?
```bash
flutter clean
flutter pub get
flutter gen-l10n
flutter run
```

### RTL Not Working?
- Ensure you're using Arabic locale (ar)
- Check Directionality widget in main.dart
- Verify isRTL property is true

### Language Not Saving?
- Check SharedPreferences is initialized
- Verify LocalizationService.initialize() is called
- Check device storage permissions

---

## 📚 Translation Keys

All keys are in `lib/l10n/app_en.arb`. Common ones:

```
common_*       - Common UI elements
login_*        - Login screen
home_*         - Home screen
profile_*      - Profile screen
amenities_*    - Amenities feature
bookings_*     - Bookings feature
complaints_*   - Complaints feature
documents_*    - Documents feature
billing_*      - Billing feature
messages_*     - Messages feature
```

---

## 🎨 Customization

### Add More Languages
1. Create `lib/l10n/app_XX.arb` (XX = language code)
2. Add translations for all keys
3. Update `l10n.yaml` locales list
4. Run `flutter gen-l10n`

### Customize Language Names
Edit `LocalizationService.languageNames`:
```dart
static const Map<String, String> languageNames = {
  'en': 'English',
  'ta': 'Tamil',
  // Add more...
};
```

### Customize Language Flags
Edit `LanguageSwitcher._getLanguageFlag()`:
```dart
const flagMap = {
  'en': '🇬🇧',
  'ta': '🇮🇳',
  // Add more...
};
```

---

## 📖 Full Documentation

See `MULTI_LANGUAGE_IMPLEMENTATION.md` for:
- Complete setup instructions
- Advanced usage
- RTL considerations
- Performance tips
- Future enhancements

---

## ✅ Checklist

- [ ] Run `flutter gen-l10n`
- [ ] Update main.dart with localization
- [ ] Test language switching
- [ ] Test Arabic RTL layout
- [ ] Add language switcher to settings
- [ ] Update all screens to use translations
- [ ] Test on device
- [ ] Verify language persists after restart

---

**Ready to go!** 🎉

Start using translations in your screens now.
