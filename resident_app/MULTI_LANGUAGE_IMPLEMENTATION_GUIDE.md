# Multi-Language Implementation Guide

## Overview
This guide explains the complete multi-language localization system for the Lyvo Resident app with dynamic language switching, Firestore persistence, and full app UI updates.

## Architecture

### Components

1. **LanguageProvider** (`lib/src/providers/language_provider.dart`)
   - Manages current language state
   - Handles language changes
   - Saves preferences to Firestore
   - Triggers full app rebuild on language change

2. **LocalizationService** (`lib/src/services/localization_service.dart`)
   - Loads JSON translation files
   - Provides translation lookup
   - Handles RTL support for Arabic

3. **UserDataService** (`lib/src/services/user_data_service.dart`)
   - Saves language preference to Firestore users collection
   - Retrieves saved language preference on app startup

4. **LocalizationHelper** (`lib/src/utils/localization_helper.dart`)
   - Convenient methods to access translations
   - Extension methods on BuildContext
   - Helper functions for language management

5. **Localized Widgets** (`lib/src/widgets/localized_text.dart`)
   - LocalizedText - Auto-rebuilding text widget
   - LocalizedButton - Button with localized text
   - LocalizedTextButton - Text button with localized text
   - LocalizedOutlinedButton - Outlined button with localized text
   - LocalizedAppBarTitle - App bar title with localized text
   - LocalizedTooltip - Tooltip with localized text

## Supported Languages

- **English** (en) - Default
- **Tamil** (ta)
- **Hindi** (hi)
- **Spanish** (es)
- **Arabic** (ar) - RTL support

## Translation Files

Located in `lib/l10n/`:
- `translations_en.json` - English
- `translations_ta.json` - Tamil
- `translations_hi.json` - Hindi
- `translations_es.json` - Spanish
- `translations_ar.json` - Arabic

## How It Works

### 1. App Initialization

```dart
// main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return KeyedSubtree(
            key: ValueKey(languageProvider.rebuildCounter),
            child: MaterialApp(
              locale: Locale(languageProvider.currentLanguageCode),
              builder: (context, child) {
                return Directionality(
                  textDirection: languageProvider.isRTL()
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child!,
                );
              },
              // ... rest of MaterialApp config
            ),
          );
        },
      ),
    );
  }
}
```

### 2. Language Initialization

When the app starts:
1. LanguageProvider initializes
2. Checks if user is logged in
3. Fetches saved language preference from Firestore
4. Falls back to English if no preference found
5. Loads translation JSON file

### 3. Language Switching

When user selects a language:
1. LanguageProvider.setLanguage() is called
2. LocalizationService loads new translation file
3. Language preference is saved to Firestore
4. rebuildCounter is incremented
5. KeyedSubtree forces full app rebuild with new locale
6. All UI updates to new language

### 4. Firestore Storage

Language preference is stored in the users collection:

```
users/
  {userId}/
    language: "ta"  // Tamil
    updatedAt: timestamp
```

## Usage Examples

### Method 1: Using LocalizationHelper

```dart
import 'package:provider/provider.dart';
import '../utils/localization_helper.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.translate('home')),
      ),
      body: Column(
        children: [
          Text(context.t('welcome')),
          ElevatedButton(
            onPressed: () async {
              await context.changeLanguage('ta');
            },
            child: Text(context.translate('select_language')),
          ),
        ],
      ),
    );
  }
}
```

### Method 2: Using Localized Widgets

```dart
import '../widgets/localized_text.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LocalizedAppBarTitle('home'),
      ),
      body: Column(
        children: [
          LocalizedText('welcome'),
          LocalizedButton(
            'select_language',
            onPressed: () async {
              await context.changeLanguage('ta');
            },
          ),
        ],
      ),
    );
  }
}
```

### Method 3: Using LanguageProvider Directly

```dart
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(languageProvider.translate('home')),
          ),
          body: Column(
            children: [
              Text(languageProvider.t('welcome')),
              ElevatedButton(
                onPressed: () async {
                  await languageProvider.setLanguage('ta');
                },
                child: Text(languageProvider.translate('select_language')),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Adding New Translation Keys

### Step 1: Add to English translation file

```json
// lib/l10n/translations_en.json
{
  "my_new_key": "My New Text"
}
```

### Step 2: Add to all other language files

```json
// lib/l10n/translations_ta.json
{
  "my_new_key": "என் புதிய உரை"
}
```

### Step 3: Use in your code

```dart
LocalizedText('my_new_key')
// or
context.translate('my_new_key')
// or
languageProvider.t('my_new_key')
```

## RTL Support (Arabic)

The app automatically handles RTL layout for Arabic:

```dart
// Automatically applied in main.dart
Directionality(
  textDirection: languageProvider.isRTL()
      ? TextDirection.rtl
      : TextDirection.ltr,
  child: child!,
)
```

Check RTL status:
```dart
bool isArabic = context.isRTL;
// or
bool isArabic = languageProvider.isRTL();
```

## Language Selector Widget

The app includes a built-in language selector:

```dart
import '../widgets/language_selector.dart';

// Full selector (grid layout)
LanguageSelector(
  showTitle: true,
  isCompact: false,
)

// Compact selector (horizontal chips)
LanguageSelector(
  showTitle: false,
  isCompact: true,
)
```

## Best Practices

### 1. Always Use Translation Keys

❌ **Don't:**
```dart
Text('Home')
```

✅ **Do:**
```dart
LocalizedText('home')
// or
Text(context.translate('home'))
```

### 2. Use Localized Widgets for Common UI Elements

❌ **Don't:**
```dart
ElevatedButton(
  onPressed: onPressed,
  child: Text(languageProvider.translate('save')),
)
```

✅ **Do:**
```dart
LocalizedButton(
  'save',
  onPressed: onPressed,
)
```

### 3. Handle Parameters in Translations

```json
// translations_en.json
{
  "welcome_user": "Welcome, {name}!"
}
```

```dart
LocalizedText(
  'welcome_user',
  params: {'name': 'John'},
)
// Output: "Welcome, John!"
```

### 4. Use Consumer for Complex Screens

```dart
Consumer<LanguageProvider>(
  builder: (context, languageProvider, _) {
    return Scaffold(
      // All widgets here will rebuild when language changes
    );
  },
)
```

### 5. Cache Translations When Needed

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late String _cachedTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedTitle = context.translate('home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_cachedTitle)),
    );
  }
}
```

## Troubleshooting

### Issue: Language doesn't change

**Solution:** Ensure you're using Consumer or LocalizedText widgets that listen to LanguageProvider changes.

### Issue: Translations not loading

**Solution:** Check that JSON files are in `lib/l10n/` and named correctly: `translations_{languageCode}.json`

### Issue: RTL layout broken

**Solution:** Ensure Directionality widget is applied in main.dart and all widgets support RTL.

### Issue: Firestore not saving language

**Solution:** Check that user is logged in and has write permissions to users collection.

## Testing Language Switching

```dart
// Test in your app
void testLanguageSwitching() async {
  final provider = LanguageProvider();
  
  // Test English
  await provider.setLanguage('en');
  assert(provider.currentLanguageCode == 'en');
  
  // Test Tamil
  await provider.setLanguage('ta');
  assert(provider.currentLanguageCode == 'ta');
  assert(provider.isRTL() == false);
  
  // Test Arabic
  await provider.setLanguage('ar');
  assert(provider.currentLanguageCode == 'ar');
  assert(provider.isRTL() == true);
}
```

## Performance Considerations

1. **Translation files are cached** - Loaded once and reused
2. **Firestore saves are async** - Don't block UI
3. **Full app rebuild is efficient** - Only happens on language change
4. **Consumer widgets are optimized** - Only rebuild when needed

## Migration Guide

If you have existing hardcoded text:

### Before:
```dart
Text('Home')
Text('Profile')
Text('Settings')
```

### After:
```dart
LocalizedText('home')
LocalizedText('profile')
LocalizedText('settings')
```

## File Structure

```
lib/
├── main.dart
├── l10n/
│   ├── translations_en.json
│   ├── translations_ta.json
│   ├── translations_hi.json
│   ├── translations_es.json
│   └── translations_ar.json
├── src/
│   ├── providers/
│   │   └── language_provider.dart
│   ├── services/
│   │   ├── localization_service.dart
│   │   └── user_data_service.dart
│   ├── utils/
│   │   └── localization_helper.dart
│   ├── widgets/
│   │   ├── language_selector.dart
│   │   └── localized_text.dart
│   └── screens/
│       └── app_settings_screen_localized.dart
```

## Next Steps

1. Replace all hardcoded text with translation keys
2. Add missing translation keys to all language files
3. Test language switching on all screens
4. Verify Firestore persistence
5. Test RTL layout with Arabic
6. Deploy and monitor language preferences

## Support

For issues or questions about localization:
1. Check the troubleshooting section
2. Review example screens
3. Check translation files for missing keys
4. Verify Firestore rules allow language field updates
