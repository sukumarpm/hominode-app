# Multi-Language Implementation - Developer Guide

## Quick Start

### Adding Translations to a New Screen

1. **Import EasyLocalization**
```dart
import 'package:easy_localization/easy_localization.dart';
```

2. **Use `.tr()` for all user-facing text**
```dart
Text('welcome'.tr())
ElevatedButton(
  child: Text('submit'.tr()),
  onPressed: () {},
)
```

3. **Add translation keys to all JSON files**
```json
// assets/translations/en.json
{
  "welcome": "Welcome",
  "submit": "Submit"
}

// assets/translations/ta.json
{
  "welcome": "வரவேற்கிறோம்",
  "submit": "சமர்ப்பிக்கவும்"
}
```

---

## Translation Key Naming Convention

Use snake_case for all translation keys:

```dart
// ✅ CORRECT
'user_profile'.tr()
'error_loading_data'.tr()
'payment_successful'.tr()

// ❌ WRONG
'userProfile'.tr()
'ErrorLoadingData'.tr()
'paymentSuccessful'.tr()
```

---

## Language Switching

### From Any Screen

```dart
// Get LanguageProvider
final languageProvider = context.read<LanguageProvider>();

// Change language
await languageProvider.setLanguage('ta', context);
```

### In app_settings_screen.dart

```dart
Consumer<LanguageProvider>(
  builder: (context, languageProvider, _) {
    return GridView.builder(
      itemCount: languageProvider.supportedLanguages.length,
      itemBuilder: (context, index) {
        final language = languageProvider.supportedLanguages[index];
        return GestureDetector(
          onTap: () async {
            await languageProvider.setLanguage(language, context);
          },
          child: LanguageButton(language: language),
        );
      },
    );
  },
)
```

---

## Supported Languages

```dart
// Access supported languages
final languages = LanguageProvider.supportedLanguages;
// Returns: ['en', 'ta', 'hi', 'es', 'ar']

// Get language display name
final name = LanguageProvider.languageNames['ta'];
// Returns: 'Tamil'

// Get language code (e.g., 'EN', 'TA')
final code = LanguageProvider.languageCodes['ta'];
// Returns: 'TA'
```

---

## RTL Support (Arabic)

### Automatic RTL Layout

The app automatically applies RTL layout for Arabic:

```dart
// In main.dart - already configured
Directionality(
  textDirection: localizationProvider.isRTL 
    ? TextDirection.rtl 
    : TextDirection.ltr,
  child: child,
)
```

### Check if Current Language is RTL

```dart
final languageProvider = context.read<LanguageProvider>();
if (languageProvider.isRTL()) {
  // Apply RTL-specific styling
}
```

---

## Translation Files Location

```
resident_app/
├── assets/
│   └── translations/
│       ├── en.json      (English)
│       ├── ta.json      (Tamil)
│       ├── hi.json      (Hindi)
│       ├── es.json      (Spanish)
│       └── ar.json      (Arabic)
```

---

## Common Translation Keys

### Navigation & UI
```
home, settings, profile, logout, back, next, submit, cancel
```

### Screens
```
visitor_management, maintenance_billing, events, announcements
community_wall, marketplace, notifications, documents
```

### Actions
```
edit_profile, add_visitor, book_amenity, send_message
```

### Status Messages
```
loading, error, success, pending, approved, rejected
payment_successful, payment_failed, error_loading_data
```

### Validation
```
field_required, invalid_email, invalid_phone, password_mismatch
```

---

## Firestore Integration

### Saving Language Preference

```dart
// Automatically saved when language is changed
await languageProvider.setLanguage('ta', context);

// Saves to Firestore:
// users/{userId}/preferences/language = 'ta'
```

### Loading Saved Preference

```dart
// Automatically loaded on app startup
// LanguageProvider._initializeLanguage() fetches from Firestore
```

---

## Error Handling

### Missing Translation Key

If a translation key is missing, EasyLocalization will display the key itself:

```dart
'missing_key'.tr()  // Displays: "missing_key"
```

**Solution**: Add the key to all translation JSON files

### Language Not Supported

```dart
// Check if language is supported before switching
if (LanguageProvider.supportedLanguages.contains(languageCode)) {
  await languageProvider.setLanguage(languageCode, context);
}
```

---

## Best Practices

### 1. Always Use Translation Keys
```dart
// ✅ CORRECT
Text('welcome'.tr())

// ❌ WRONG
Text('Welcome')
```

### 2. Keep Keys Consistent
```dart
// ✅ CORRECT - Same key used everywhere
'error_loading_data'.tr()

// ❌ WRONG - Different keys for same message
'error_loading_data'.tr()
'data_load_error'.tr()
'failed_to_load'.tr()
```

### 3. Use Meaningful Key Names
```dart
// ✅ CORRECT
'visitor_management_title'.tr()
'visitor_pending_status'.tr()

// ❌ WRONG
'title1'.tr()
'status1'.tr()
```

### 4. Handle Parameters (if needed)
```dart
// For dynamic text, use parameters in translation
'welcome_user'.tr(args: ['John'])

// In JSON:
{
  "welcome_user": "Welcome, {}!"
}
```

---

## Testing Language Switching

### Manual Testing Steps

1. Open app_settings_screen
2. Tap on a language button
3. Verify all text updates immediately
4. Close and reopen app
5. Verify language persists (saved to Firestore)
6. Test Arabic for RTL layout

### Automated Testing

```dart
// Test language switching
test('Language switching works', () async {
  final provider = LanguageProvider();
  await provider.setLanguage('ta', context);
  expect(provider.currentLanguageCode, 'ta');
});
```

---

## Troubleshooting

### Issue: Text not updating after language change

**Solution**: Ensure you're using `.tr()` method, not hardcoded strings

### Issue: Translation key displays instead of text

**Solution**: Add the key to all translation JSON files

### Issue: RTL layout not working for Arabic

**Solution**: Verify `Directionality` widget is in main.dart

### Issue: Language preference not persisting

**Solution**: Check Firestore rules allow write access to user preferences

---

## Migration Checklist

When converting an existing screen:

- [ ] Add `import 'package:easy_localization/easy_localization.dart';`
- [ ] Replace all `languageProvider.translate()` with `.tr()`
- [ ] Replace all hardcoded strings with `.tr()` calls
- [ ] Add all translation keys to JSON files
- [ ] Test language switching
- [ ] Test RTL layout (if applicable)
- [ ] Verify no compilation errors

---

## Resources

- **EasyLocalization Docs**: https://pub.dev/packages/easy_localization
- **Translation Files**: `assets/translations/`
- **Provider Setup**: `lib/main.dart`
- **Language Provider**: `lib/src/providers/language_provider.dart`

---

## Support

For issues or questions:
1. Check this guide
2. Review existing screen implementations
3. Check translation JSON files for missing keys
4. Verify Firestore rules for language preference storage
