# Localization Quick Reference

## Quick Start

### 1. Use in Any Widget
```dart
Consumer<LanguageProvider>(
  builder: (context, lang, _) {
    return Text(lang.t('home'));
  },
)
```

### 2. Change Language
```dart
final lang = Provider.of<LanguageProvider>(context, listen: false);
await lang.setLanguage('ta'); // Tamil
```

### 3. Get Current Language
```dart
final currentLang = languageProvider.currentLanguageCode;
```

## Common Translation Keys

| Key | English | Tamil | Hindi | Spanish | Arabic |
|-----|---------|-------|-------|---------|--------|
| `home` | Home | முகப்பு | होम | Inicio | الرئيسية |
| `profile` | Profile | சுயவிவரம் | प्रोफाइल | Perfil | الملف الشخصي |
| `settings` | Settings | அமைப்புகள் | सेटिंग्स | Configuración | الإعدادات |
| `logout` | Logout | வெளியேறு | लॉगआउट | Cerrar sesión | تسجيل الخروج |
| `save` | Save | சேமி | सहेजें | Guardar | حفظ |
| `cancel` | Cancel | ரத்து செய் | रद्द करें | Cancelar | إلغاء |
| `delete` | Delete | நீக்கு | हटाएं | Eliminar | حذف |
| `loading` | Loading... | ஏற்றுகிறது... | लोड हो रहा है... | Cargando... | جاري التحميل... |
| `error` | Error | பிழை | त्रुटि | Error | خطأ |
| `success` | Success | வெற்றி | सफलता | Éxito | نجاح |

## Language Codes

```dart
'en' // English
'ta' // Tamil
'hi' // Hindi
'es' // Spanish
'ar' // Arabic
```

## RTL Support

```dart
// Check if RTL
if (languageProvider.isRTL()) {
  // Arabic layout
}

// Get text direction
final direction = languageProvider.getTextDirection();
```

## Firestore Integration

### Save Language
```dart
final userService = UserDataService();
await userService.saveUserLanguagePreference(userId, 'ta');
```

### Load Language
```dart
final language = await userService.getUserLanguagePreference(userId);
```

## Adding New Translations

### 1. Add to all JSON files
```json
{
  "new_key": "English text",
  ...
}
```

### 2. Use in code
```dart
Text(languageProvider.t('new_key'))
```

## Common Patterns

### Settings Screen
```dart
Consumer<LanguageProvider>(
  builder: (context, lang, _) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('settings')),
      ),
      body: LanguageSelector(),
    );
  },
)
```

### Dialog with Translations
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(lang.t('confirm')),
    content: Text(lang.t('delete_account')),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(lang.t('cancel')),
      ),
      TextButton(
        onPressed: () => _delete(),
        child: Text(lang.t('delete')),
      ),
    ],
  ),
)
```

### List with Translations
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(
      title: Text(lang.t('item_${index + 1}')),
    );
  },
)
```

## Debugging

### Check Current Language
```dart
print('Current: ${languageProvider.currentLanguageCode}');
```

### Check Translation
```dart
print('Translation: ${languageProvider.t('key')}');
```

### Check RTL
```dart
print('RTL: ${languageProvider.isRTL()}');
```

### Check Error
```dart
print('Error: ${languageProvider.error}');
```

## Performance Tips

1. **Use Consumer wisely** - Only wrap what needs translation
2. **Cache translations** - Don't call t() multiple times
3. **Lazy load** - Translations load on first use
4. **Minimize rebuilds** - Use listen: false when not needed

## Common Issues

### Text Not Updating
- Ensure using Consumer widget
- Check LanguageProvider in MultiProvider
- Verify notifyListeners() called

### Translation Missing
- Check JSON file has the key
- Verify key spelling matches
- Check JSON syntax

### Firestore Not Saving
- Check user is authenticated
- Verify Firestore rules allow write
- Check network connectivity

### RTL Not Working
- Ensure Directionality wraps app
- Check isRTL() returns true
- Verify TextDirection.rtl applied

## Testing Checklist

- [ ] All languages load correctly
- [ ] Language changes update UI
- [ ] Preference saves to Firestore
- [ ] Preference loads on app restart
- [ ] Arabic RTL layout works
- [ ] No missing translations
- [ ] Error handling works
- [ ] Loading states display
- [ ] Offline mode works

---

**Quick Links**:
- Full Setup: `MULTI_LANGUAGE_COMPLETE_SETUP.md`
- Language Selector: `lib/src/widgets/language_selector.dart`
- Settings Screen: `lib/src/screens/app_settings_screen.dart`
