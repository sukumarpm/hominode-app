# EasyLocalization Implementation Guide

## Overview
This document explains how to use EasyLocalization for global language translation in the Flutter app.

## What Was Implemented

### 1. Dependencies Added
- `easy_localization: ^3.0.7` - Added to pubspec.yaml

### 2. Translation Files Created
Located in `assets/translations/`:
- `en.json` - English translations (150+ keys)
- `ta.json` - Tamil translations
- `hi.json` - Hindi translations
- `es.json` - Spanish translations
- `ar.json` - Arabic translations (with RTL support)

### 3. Main.dart Updated
- Integrated EasyLocalization wrapper
- Configured supported locales
- Added RTL support for Arabic
- Automatic locale detection and switching

### 4. Services Created

#### LanguageService (`lib/src/services/language_service.dart`)
Handles:
- Saving language to SharedPreferences
- Saving language to Firestore (per user)
- Loading language from Firestore
- Changing app locale
- RTL detection

#### LanguageSelectorEasy (`lib/src/widgets/language_selector_easy.dart`)
Beautiful UI for language selection with:
- Language flags/emojis
- Native language names
- Smooth transitions
- Loading states
- Success/error messages

## How to Use

### 1. Basic Translation in Widgets
```dart
import 'package:easy_localization/easy_localization.dart';

// Simple translation
Text('home'.tr())

// Translation with parameters
Text('welcome_user'.tr(args: ['John']))

// Plural translation
Text('items_count'.plural(5))
```

### 2. Change Language Programmatically
```dart
import 'package:easy_localization/easy_localization.dart';

// Change to Tamil
await context.setLocale(const Locale('ta'));

// Change to Arabic
await context.setLocale(const Locale('ar'));
```

### 3. Add Language Selector to Settings
```dart
import 'package:resident_app/src/widgets/language_selector_easy.dart';

// In your settings screen
LanguageSelectorEasy(
  onLanguageChanged: () {
    // Refresh UI if needed
    setState(() {});
  },
)
```

### 4. Get Current Language
```dart
// Get current language code
String currentLanguage = context.locale.languageCode;

// Check if RTL
bool isRTL = context.locale.languageCode == 'ar';
```

## File Structure
```
resident_app/
├── assets/
│   └── translations/
│       ├── en.json
│       ├── ta.json
│       ├── hi.json
│       ├── es.json
│       └── ar.json
├── lib/
│   ├── main.dart (Updated with EasyLocalization)
│   └── src/
│       ├── services/
│       │   └── language_service.dart (NEW)
│       └── widgets/
│           └── language_selector_easy.dart (NEW)
└── pubspec.yaml (Updated with easy_localization)
```

## Supported Languages

| Code | Language | Native Name | RTL |
|------|----------|-------------|-----|
| en | English | English | No |
| ta | Tamil | தமிழ் | No |
| hi | Hindi | हिंदी | No |
| es | Spanish | Español | No |
| ar | Arabic | العربية | Yes |

## Key Features

### ✅ Automatic App-Wide Updates
When user changes language:
1. All screens automatically rebuild
2. All text updates instantly
3. No manual refresh needed
4. RTL layout applies automatically for Arabic

### ✅ Persistent Language Preference
- Saved to SharedPreferences (local)
- Saved to Firestore (cloud, per user)
- Restored on app restart
- Synced across devices

### ✅ RTL Support
- Arabic automatically gets RTL layout
- Text direction mirrors automatically
- Navigation reverses for RTL
- No additional code needed

### ✅ Easy Integration
- Simple `.tr()` method for translations
- Works with parameters and plurals
- Context-based locale switching
- No Provider needed (uses EasyLocalization's built-in state management)

## Migration from Provider-Based Approach

### Old Way (Provider)
```dart
Consumer<LanguageProvider>(
  builder: (context, languageProvider, _) {
    return Text(languageProvider.translate('home'));
  },
)
```

### New Way (EasyLocalization)
```dart
Text('home'.tr())
```

## Adding New Translation Keys

1. Add key to all 5 JSON files in `assets/translations/`
2. Use in code with `.tr()`
3. No need to restart app - changes apply immediately

Example:
```json
{
  "new_feature": "New Feature",
  "new_feature_description": "This is a new feature"
}
```

Usage:
```dart
Text('new_feature'.tr())
Text('new_feature_description'.tr())
```

## Troubleshooting

### Issue: Translations not loading
**Solution:** Ensure `assets/translations/` path is in pubspec.yaml

### Issue: Language not changing
**Solution:** Use `context.setLocale()` instead of manual locale changes

### Issue: RTL not working for Arabic
**Solution:** Check that `context.locale.languageCode == 'ar'` in builder

### Issue: Translations not updating in hot reload
**Solution:** Full app restart may be needed for translation file changes

## Performance Notes

- Translations loaded once at app startup
- No network calls for language switching
- Minimal memory overhead
- Instant UI updates when language changes

## Next Steps

1. Replace all hardcoded text with `.tr()` calls
2. Add language selector to app settings
3. Test all screens with different languages
4. Verify RTL layout for Arabic
5. Test language persistence across app restarts

## Example: Complete Settings Screen with Language Selector

```dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:resident_app/src/widgets/language_selector_easy.dart';

class AppSettingsScreen extends StatefulWidget {
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Language Selector
            LanguageSelectorEasy(
              onLanguageChanged: () {
                setState(() {});
              },
            ),
            // Other settings...
          ],
        ),
      ),
    );
  }
}
```

## Testing Checklist

- [ ] Select English → All text changes to English
- [ ] Select Tamil → All text changes to Tamil
- [ ] Select Hindi → All text changes to Hindi
- [ ] Select Spanish → All text changes to Spanish
- [ ] Select Arabic → All text changes to Arabic + RTL layout
- [ ] Close and reopen app → Language preference persists
- [ ] Check Firestore → Language saved to user document
- [ ] Check SharedPreferences → Language saved locally
- [ ] Test on different screens → All screens update
- [ ] Test with slow network → Language changes instantly

## Documentation References

- [EasyLocalization Package](https://pub.dev/packages/easy_localization)
- [Flutter Localization](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)
- [RTL Support in Flutter](https://flutter.dev/docs/development/accessibility-and-localization/rtl-support)

---

**Status:** ✅ Ready for Implementation
**Last Updated:** March 28, 2026
