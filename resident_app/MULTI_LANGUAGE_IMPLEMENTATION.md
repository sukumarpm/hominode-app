# Multi-Language Support Implementation Guide

## Overview
Complete multi-language support for the Lyvo app with dynamic language switching and RTL support for Arabic.

**Supported Languages:**
- 🇬🇧 English (en)
- 🇮🇳 Tamil (ta)
- 🇮🇳 Hindi (hi)
- 🇪🇸 Spanish (es)
- 🇸🇦 Arabic (ar) - with RTL support

---

## Project Structure

```
resident_app/
├── lib/
│   ├── l10n/                          # Localization files
│   │   ├── app_en.arb                 # English translations
│   │   ├── app_ta.arb                 # Tamil translations
│   │   ├── app_hi.arb                 # Hindi translations
│   │   ├── app_es.arb                 # Spanish translations
│   │   └── app_ar.arb                 # Arabic translations
│   ├── gen/
│   │   └── l10n/
│   │       └── app_localizations.dart # Auto-generated (run: flutter gen-l10n)
│   ├── src/
│   │   ├── services/
│   │   │   └── localization_service.dart    # Localization service
│   │   ├── providers/
│   │   │   └── localization_provider.dart   # State management
│   │   ├── widgets/
│   │   │   └── language_switcher.dart       # Language switcher widget
│   │   └── screens/
│   │       └── app_settings_screen.dart     # Settings with language switcher
│   ├── main_localized.dart            # Updated main with localization
│   └── main.dart                      # Original main (keep as backup)
├── l10n.yaml                          # Localization configuration
└── pubspec.yaml                       # Updated with dependencies
```

---

## Setup Instructions

### 1. Update Dependencies

Already added to `pubspec.yaml`:
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.18.0
  provider: ^6.0.0
```

Run:
```bash
flutter pub get
```

### 2. Generate Localization Files

Run the localization generation command:
```bash
flutter gen-l10n
```

This generates `lib/gen/l10n/app_localizations.dart` with all translations.

### 3. Update main.dart

Replace your `main.dart` with `main_localized.dart`:

```bash
cp lib/main_localized.dart lib/main.dart
```

Or manually update your main.dart to include:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'src/providers/localization_provider.dart';
import 'src/services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final localizationService = LocalizationService();
  await localizationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocalizationProvider()..initialize(),
        ),
      ],
      child: Consumer<LocalizationProvider>(
        builder: (context, localizationProvider, _) {
          return MaterialApp(
            locale: localizationProvider.currentLocale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationService.getSupportedLocales(),
            localeResolutionCallback:
                LocalizationService.localeResolutionCallback,
            builder: (context, child) {
              return Directionality(
                textDirection: localizationProvider.isRTL
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              );
            },
            // ... rest of your app configuration
          );
        },
      ),
    );
  }
}
```

---

## Usage in Screens

### Using Translations in Widgets

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.appTitle ?? 'Lyvo'),
      ),
      body: Column(
        children: [
          Text(l10n?.homeWelcome ?? 'Welcome'),
          ElevatedButton(
            onPressed: () {},
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
```

### Accessing Localization Provider

```dart
import 'package:provider/provider.dart';
import 'src/providers/localization_provider.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationProvider>(
      builder: (context, localizationProvider, _) {
        return Text(
          'Current Language: ${localizationProvider.currentLanguage}',
        );
      },
    );
  }
}
```

---

## Language Switcher Implementation

### Compact Dropdown Switcher

```dart
import 'src/widgets/language_switcher.dart';

LanguageSwitcher(
  isCompact: true,
  onLanguageChanged: () {
    // Handle language change
  },
)
```

### Full Grid Switcher

```dart
LanguageSwitcher(
  isCompact: false,
  onLanguageChanged: () {
    // Handle language change
  },
)
```

### Language Switcher Dialog

```dart
import 'src/widgets/language_switcher.dart';

showDialog(
  context: context,
  builder: (context) => LanguageSwitcherDialog(
    onLanguageChanged: () {
      // Handle language change
    },
  ),
);
```

---

## Adding New Translations

### 1. Add to ARB Files

Edit each `.arb` file in `lib/l10n/`:

```json
{
  "@@locale": "en",
  "myNewKey": "My new translation",
  "myNewKey_description": "Description for translators"
}
```

### 2. Regenerate Localizations

```bash
flutter gen-l10n
```

### 3. Use in Code

```dart
final l10n = AppLocalizations.of(context);
Text(l10n?.myNewKey ?? 'Fallback text');
```

---

## RTL Support for Arabic

Automatic RTL support is enabled for Arabic:

```dart
// In main.dart
builder: (context, child) {
  return Directionality(
    textDirection: localizationProvider.isRTL
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: child!,
  );
},
```

### RTL Considerations

1. **Text Direction**: Automatically handled by Directionality widget
2. **Layout**: Use `Row` and `Column` - they respect text direction
3. **Padding/Margin**: Use `EdgeInsets.symmetric()` or `EdgeInsets.only()`
4. **Icons**: Most icons automatically mirror in RTL
5. **Custom Widgets**: Test thoroughly in RTL mode

---

## Persistent Language Selection

Language preference is saved using SharedPreferences:

```dart
// Automatically saved when language is changed
await localizationProvider.setLanguage('ar');

// Automatically loaded on app start
await localizationService.initialize();
```

---

## Settings Screen Integration

The app includes a complete settings screen with language switcher:

```dart
import 'src/screens/app_settings_screen.dart';

// Navigate to settings
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
);
```

Features:
- Language selection grid
- Notification settings
- Security settings
- Privacy settings
- About section

---

## Testing Multi-Language Support

### Test Language Switching

```dart
// In your test
testWidgets('Language switching works', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  // Find language switcher
  final switcher = find.byType(LanguageSwitcher);
  expect(switcher, findsOneWidget);
  
  // Change language
  await tester.tap(switcher);
  await tester.pumpAndSettle();
});
```

### Test RTL Layout

```dart
// Run app in RTL mode
flutter run --dart-define=LOCALE=ar
```

### Manual Testing Checklist

- [ ] All screens display correctly in each language
- [ ] Language persists after app restart
- [ ] Arabic displays correctly with RTL layout
- [ ] All UI elements align properly in RTL
- [ ] Date/time formatting works in each language
- [ ] Numbers display correctly in each language
- [ ] Language switcher updates all screens
- [ ] No text overflow in any language

---

## Supported Locales

| Language | Code | Locale | RTL |
|----------|------|--------|-----|
| English | en | en | No |
| Tamil | ta | ta | No |
| Hindi | hi | hi | No |
| Spanish | es | es | No |
| Arabic | ar | ar | Yes |

---

## Translation Keys Reference

### Common Keys
- `common_home`, `common_profile`, `common_settings`
- `common_save`, `common_cancel`, `common_delete`
- `common_loading`, `common_error`, `common_success`

### Login Keys
- `login_email`, `login_phone`, `login_password`
- `login_sign_in`, `login_sign_up`

### Home Keys
- `home_welcome`, `home_recent_activity`
- `home_notifications`, `home_bookings`

### Profile Keys
- `profile_my_profile`, `profile_edit_profile`
- `profile_domestic_staff`, `profile_my_bookings`

### Feature Keys
- `amenities_*`, `bookings_*`, `complaints_*`
- `documents_*`, `billing_*`, `messages_*`

See `lib/l10n/app_en.arb` for complete list.

---

## Troubleshooting

### Translations Not Showing

1. Run `flutter clean`
2. Run `flutter pub get`
3. Run `flutter gen-l10n`
4. Rebuild the app

### RTL Not Working

1. Ensure `Directionality` widget wraps the app
2. Check `isRTL` property in LocalizationProvider
3. Verify Arabic locale is set correctly

### Language Not Persisting

1. Check SharedPreferences initialization
2. Verify `LocalizationService.initialize()` is called in main
3. Check file permissions on device

### Missing Translations

1. Verify key exists in all `.arb` files
2. Run `flutter gen-l10n` to regenerate
3. Check for typos in key names

---

## Performance Considerations

- Translations are loaded once at app startup
- Language switching is instant (no network calls)
- SharedPreferences caches language preference
- Generated localization file is optimized

---

## Future Enhancements

1. **Dynamic Translation Loading**: Load translations from server
2. **Pluralization**: Handle plural forms in different languages
3. **Date/Time Formatting**: Locale-specific date/time formats
4. **Number Formatting**: Locale-specific number formats
5. **More Languages**: Add additional language support
6. **Translation Management**: Admin panel for managing translations

---

## Files Created/Modified

### Created Files
- `lib/l10n/app_en.arb` - English translations
- `lib/l10n/app_ta.arb` - Tamil translations
- `lib/l10n/app_hi.arb` - Hindi translations
- `lib/l10n/app_es.arb` - Spanish translations
- `lib/l10n/app_ar.arb` - Arabic translations
- `lib/src/services/localization_service.dart` - Localization service
- `lib/src/providers/localization_provider.dart` - State management
- `lib/src/widgets/language_switcher.dart` - Language switcher widget
- `lib/src/screens/app_settings_screen.dart` - Settings screen
- `lib/main_localized.dart` - Updated main with localization
- `l10n.yaml` - Localization configuration

### Modified Files
- `pubspec.yaml` - Added dependencies and localization config

---

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Flutter localization documentation
3. Check ARB file format
4. Verify all files are in correct locations

---

**Status**: ✅ Complete and Ready for Use
**Last Updated**: March 28, 2026
