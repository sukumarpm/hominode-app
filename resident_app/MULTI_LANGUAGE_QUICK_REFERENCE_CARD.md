# Multi-Language Quick Reference Card

## Quick Start

### 1. Display Translated Text

```dart
// Option A: Using LocalizedText widget (recommended)
LocalizedText('home')

// Option B: Using context extension
Text(context.translate('home'))

// Option C: Using LanguageProvider
Consumer<LanguageProvider>(
  builder: (context, provider, _) => Text(provider.t('home')),
)
```

### 2. Change Language

```dart
// Option A: Using context extension
await context.changeLanguage('ta');

// Option B: Using LanguageProvider
await Provider.of<LanguageProvider>(context, listen: false)
    .setLanguage('ta');
```

### 3. Get Current Language

```dart
// Option A: Using context extension
String lang = context.currentLanguage;

// Option B: Using LanguageProvider
String lang = languageProvider.currentLanguageCode;
```

## Common Widgets

### Text
```dart
LocalizedText('home')
LocalizedText('welcome_user', params: {'name': 'John'})
```

### Buttons
```dart
LocalizedButton('save', onPressed: () {})
LocalizedTextButton('cancel', onPressed: () {})
LocalizedOutlinedButton('delete', onPressed: () {})
```

### App Bar
```dart
AppBar(
  title: LocalizedAppBarTitle('home'),
)
```

### Tooltip
```dart
LocalizedTooltip(
  'help_text',
  child: Icon(Icons.help),
)
```

## Language Codes

| Code | Language | RTL |
|------|----------|-----|
| en   | English  | No  |
| ta   | Tamil    | No  |
| hi   | Hindi    | No  |
| es   | Spanish  | No  |
| ar   | Arabic   | Yes |

## Check RTL

```dart
// Option A: Using context extension
bool isRTL = context.isRTL;

// Option B: Using LanguageProvider
bool isRTL = languageProvider.isRTL();
```

## Add New Translation

### 1. Add to all JSON files

```json
// lib/l10n/translations_en.json
{ "my_key": "My Text" }

// lib/l10n/translations_ta.json
{ "my_key": "என் உரை" }
```

### 2. Use in code

```dart
LocalizedText('my_key')
```

## Language Selector

```dart
// Full grid selector
LanguageSelector(showTitle: true, isCompact: false)

// Compact horizontal selector
LanguageSelector(showTitle: false, isCompact: true)
```

## Firestore Storage

Language is automatically saved to:
```
users/{userId}/language: "ta"
```

## Full App Rebuild

Language change automatically triggers full app rebuild via:
- `rebuildCounter` increment in LanguageProvider
- `KeyedSubtree` in main.dart
- `locale` property in MaterialApp

## Common Patterns

### Settings Screen
```dart
Consumer<LanguageProvider>(
  builder: (context, provider, _) {
    return Scaffold(
      appBar: AppBar(
        title: LocalizedAppBarTitle('settings'),
      ),
      body: LanguageSelector(),
    );
  },
)
```

### Dialog
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: LocalizedText('confirm'),
    content: LocalizedText('are_you_sure'),
    actions: [
      LocalizedTextButton('cancel', onPressed: () => Navigator.pop(context)),
      LocalizedButton('ok', onPressed: () => Navigator.pop(context)),
    ],
  ),
)
```

### Snackbar
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: LocalizedText('saved')),
)
```

## Debugging

### Print current language
```dart
print(context.currentLanguage);
```

### Print all supported languages
```dart
print(LanguageProvider.supportedLanguages);
```

### Print language names
```dart
print(LanguageProvider.languageNames);
```

### Check if translation exists
```dart
String text = context.translate('my_key');
// Returns 'my_key' if not found
```

## Performance Tips

1. Use `LocalizedText` for simple text (auto-rebuilds)
2. Use `Consumer` for complex screens (rebuilds entire screen)
3. Cache translations in StatefulWidget if needed
4. Avoid rebuilding entire app unnecessarily

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Text not changing | Use LocalizedText or Consumer widget |
| Translation not found | Check JSON file has the key |
| RTL broken | Ensure Directionality in main.dart |
| Firestore not saving | Check user is logged in |
| Language reverts | Check Firestore rules allow updates |

## File Locations

- Providers: `lib/src/providers/language_provider.dart`
- Services: `lib/src/services/localization_service.dart`
- Widgets: `lib/src/widgets/localized_text.dart`
- Utils: `lib/src/utils/localization_helper.dart`
- Translations: `lib/l10n/translations_*.json`

## Key Classes

- `LanguageProvider` - State management
- `LocalizationService` - Translation loading
- `LocalizationHelper` - Convenience methods
- `LocalizedText` - Auto-rebuilding text widget
- `LanguageSelector` - Language selection UI

## Extension Methods

```dart
// On BuildContext
context.translate(key)
context.t(key)
context.currentLanguage
context.currentLanguageName
context.isRTL
context.textDirection
context.changeLanguage(code)
```

## Next Steps

1. Replace hardcoded text with translation keys
2. Add missing translations to all language files
3. Test on all screens
4. Verify Firestore persistence
5. Test RTL with Arabic
