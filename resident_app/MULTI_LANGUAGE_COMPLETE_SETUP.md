# Multi-Language Localization System - Complete Setup

## Overview
Complete JSON-based localization system with Firestore integration and dynamic language switching for English, Tamil, Hindi, Spanish, and Arabic.

## Architecture

### 1. **Localization Service** (`lib/src/services/localization_service.dart`)
- Singleton pattern for global access
- Loads JSON translation files from assets
- Supports 5 languages: EN, TA, HI, ES, AR
- RTL support for Arabic
- Parameter interpolation for dynamic text

### 2. **Language Provider** (`lib/src/providers/language_provider.dart`)
- ChangeNotifier for reactive UI updates
- Loads user's saved language preference from Firestore
- Saves language preference to Firestore on change
- Handles loading states and errors
- Provides translation methods: `translate()` and `t()`

### 3. **User Data Service** (`lib/src/services/user_data_service.dart`)
- New methods:
  - `getUserLanguagePreference(userId)` - Fetch saved language
  - `saveUserLanguagePreference(userId, languageCode)` - Save to Firestore

### 4. **Language Selector Widget** (`lib/src/widgets/language_selector.dart`)
- Two display modes: compact (chips) and full (grid)
- Visual feedback for selected language
- Integrated with LanguageProvider
- Loading and error states

### 5. **Translation Files** (`lib/l10n/translations_*.json`)
- 5 JSON files: en, ta, hi, es, ar
- 100+ translation keys
- Consistent structure across all languages

## File Structure

```
resident_app/
├── lib/
│   ├── main.dart (updated with LanguageProvider)
│   ├── l10n/
│   │   ├── translations_en.json
│   │   ├── translations_ta.json
│   │   ├── translations_hi.json
│   │   ├── translations_es.json
│   │   └── translations_ar.json
│   └── src/
│       ├── providers/
│       │   └── language_provider.dart (NEW)
│       ├── services/
│       │   ├── localization_service.dart (NEW)
│       │   └── user_data_service.dart (UPDATED)
│       ├── widgets/
│       │   └── language_selector.dart (UPDATED)
│       └── screens/
│           └── app_settings_screen.dart (UPDATED)
```

## Usage

### 1. **In Widgets - Using Consumer**
```dart
Consumer<LanguageProvider>(
  builder: (context, languageProvider, _) {
    return Text(
      languageProvider.translate('home'),
      // or
      languageProvider.t('home'),
    );
  },
)
```

### 2. **Change Language**
```dart
final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
await languageProvider.setLanguage('ta'); // Tamil
// Automatically:
// - Updates UI
// - Saves to Firestore
// - Rebuilds entire app
```

### 3. **Get Current Language**
```dart
final currentLang = languageProvider.currentLanguageCode; // 'en', 'ta', etc.
```

### 4. **Check RTL**
```dart
if (languageProvider.isRTL()) {
  // Arabic layout
}
```

### 5. **With Parameters**
```dart
languageProvider.translate('key', params: {
  'name': 'John',
  'count': '5',
})
```

## Firestore Integration

### User Document Structure
```json
{
  "id": "user123",
  "name": "John Doe",
  "email": "john@example.com",
  "language": "ta",
  "updatedAt": "2024-03-28T10:30:00Z"
}
```

### Flow
1. User logs in → LanguageProvider initializes
2. Fetches user's saved language from Firestore
3. If not found, defaults to 'en'
4. User selects language in Settings
5. LanguageProvider saves to Firestore
6. App rebuilds with new language

## Supported Languages

| Code | Language | RTL | Status |
|------|----------|-----|--------|
| en   | English  | No  | ✅ |
| ta   | Tamil    | No  | ✅ |
| hi   | Hindi    | No  | ✅ |
| es   | Spanish  | No  | ✅ |
| ar   | Arabic   | Yes | ✅ |

## Translation Keys (100+)

### Navigation
- `home`, `profile`, `settings`, `logout`
- `notifications`, `messages`, `complaints`
- `amenities`, `billing`, `visitors`
- `community_wall`, `marketplace`

### Common Actions
- `save`, `cancel`, `delete`, `edit`, `add`
- `submit`, `update`, `close`, `loading`
- `yes`, `no`, `ok`, `confirm`

### Settings
- `language`, `select_language`
- `settings_notifications`, `settings_security`
- `settings_privacy`, `settings_select_language`

### Status
- `pending`, `completed`, `rejected`, `approved`
- `in_progress`, `success`, `error`

### Messages
- `language_changed`, `language_preference_saved`
- `error_saving_language`, `error_loading_translations`

## Implementation Steps

### Step 1: Add to pubspec.yaml
```yaml
dependencies:
  provider: ^6.0.0
  cloud_firestore: ^4.0.0
  firebase_auth: ^4.0.0
```

### Step 2: Initialize in main()
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
```

### Step 3: Wrap App with Provider
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
    ),
  ],
  child: MaterialApp(...)
)
```

### Step 4: Use in Screens
```dart
Consumer<LanguageProvider>(
  builder: (context, languageProvider, _) {
    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.t('home')),
      ),
    );
  },
)
```

## Dynamic UI Rebuilding

When language changes:
1. LanguageProvider notifies all listeners
2. Consumer widgets rebuild
3. All Text widgets update with new translations
4. RTL layout adjusts for Arabic
5. Entire app UI refreshes

## Error Handling

### Missing Translation
- Returns the key itself as fallback
- Logs error to console
- Doesn't crash the app

### Firestore Error
- Shows error message in UI
- Allows retry
- Falls back to default language

### Loading State
- Shows spinner while loading
- Prevents interaction during save
- Displays error if save fails

## Testing

### Test Language Switch
1. Go to Settings
2. Select different language
3. Verify all UI updates
4. Check Firestore for saved preference
5. Restart app - language persists

### Test RTL (Arabic)
1. Select Arabic
2. Verify text direction changes
3. Check layout alignment
4. Verify icons position

### Test Offline
1. Disable internet
2. Change language
3. Should work with cached data
4. Syncs when online

## Performance

- **Lazy Loading**: Translations loaded on demand
- **Caching**: Translations cached in memory
- **Minimal Rebuilds**: Only Consumer widgets rebuild
- **Efficient Storage**: JSON files ~50KB each

## Troubleshooting

### Translations Not Loading
- Check JSON file paths in assets
- Verify JSON syntax
- Check console for errors

### Language Not Saving
- Check Firestore rules allow write
- Verify user is authenticated
- Check network connectivity

### RTL Not Working
- Ensure Directionality widget wraps app
- Check isRTL() returns true for Arabic
- Verify TextDirection.rtl applied

### UI Not Updating
- Ensure using Consumer widget
- Check LanguageProvider in context
- Verify notifyListeners() called

## Future Enhancements

1. **Pluralization**: Handle singular/plural forms
2. **Date Formatting**: Locale-specific dates
3. **Number Formatting**: Locale-specific numbers
4. **Offline Sync**: Queue language changes offline
5. **Analytics**: Track language preferences
6. **A/B Testing**: Test translations

## Security

- Language preference stored in user document
- No sensitive data in translations
- JSON files included in app bundle
- Firestore rules control access

## Maintenance

### Adding New Language
1. Create `translations_XX.json`
2. Add language code to `supportedLanguages`
3. Add to `languageNames` map
4. Update Firestore rules if needed

### Updating Translations
1. Edit JSON file
2. Maintain key consistency
3. Test all languages
4. Deploy with app update

## Support

For issues or questions:
1. Check translation keys exist
2. Verify Firestore connection
3. Check console logs
4. Test with English first
5. Verify JSON syntax

---

**Status**: ✅ Complete and Ready to Use
**Last Updated**: March 28, 2024
