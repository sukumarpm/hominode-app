# EasyLocalization - Quick Start Guide

## 🚀 Getting Started in 5 Minutes

### Step 1: Install Dependencies
```bash
cd resident_app
flutter pub get
```

### Step 2: Replace Text with Translations
**Before:**
```dart
Text('Home')
Text('Profile')
Text('Settings')
```

**After:**
```dart
import 'package:easy_localization/easy_localization.dart';

Text('home'.tr())
Text('profile'.tr())
Text('settings'.tr())
```

### Step 3: Add Language Selector to Settings
```dart
import 'package:resident_app/src/widgets/language_selector_easy.dart';

// In your settings screen
LanguageSelectorEasy(
  onLanguageChanged: () {
    // Optional: refresh UI
    setState(() {});
  },
)
```

### Step 4: Test Language Switching
1. Run the app
2. Go to Settings
3. Select a different language
4. Watch entire app change language instantly ✨

---

## 📝 Common Translation Patterns

### Simple Text
```dart
Text('home'.tr())
```

### With Parameters
```dart
Text('welcome_user'.tr(args: ['John']))
// In JSON: "welcome_user": "Welcome, {0}!"
```

### Plurals
```dart
Text('items_count'.plural(5))
// In JSON: "items_count": {"one": "1 item", "other": "{} items"}
```

### Conditional
```dart
String text = context.locale.languageCode == 'ar' 
  ? 'right_to_left'.tr() 
  : 'left_to_right'.tr();
```

---

## 🌍 Supported Languages

- 🇬🇧 English (en)
- 🇮🇳 Tamil (ta)
- 🇮🇳 Hindi (hi)
- 🇪🇸 Spanish (es)
- 🇸🇦 Arabic (ar) - RTL

---

## 📂 Translation Files Location

```
assets/translations/
├── en.json (English)
├── ta.json (Tamil)
├── hi.json (Hindi)
├── es.json (Spanish)
└── ar.json (Arabic)
```

---

## ✅ Checklist for Implementation

### Phase 1: Setup (Already Done ✓)
- [x] Add easy_localization to pubspec.yaml
- [x] Create translation JSON files
- [x] Update main.dart with EasyLocalization
- [x] Create LanguageService
- [x] Create LanguageSelectorEasy widget

### Phase 2: Integration (Do This)
- [ ] Replace hardcoded text with `.tr()` in all screens
- [ ] Add LanguageSelectorEasy to Settings screen
- [ ] Test language switching
- [ ] Verify RTL for Arabic
- [ ] Test persistence (close/reopen app)

### Phase 3: Polish (Optional)
- [ ] Add more translation keys as needed
- [ ] Optimize translation loading
- [ ] Add language-specific formatting (dates, numbers)
- [ ] Test with real users

---

## 🔧 Troubleshooting

### Problem: "translation key not found"
**Solution:** Add the key to all 5 JSON files in `assets/translations/`

### Problem: Language doesn't change
**Solution:** Make sure you're using `context.setLocale()` not manual changes

### Problem: Arabic text not RTL
**Solution:** Check that main.dart has RTL builder configured

### Problem: Translations not loading
**Solution:** Run `flutter clean` then `flutter pub get`

---

## 💡 Pro Tips

1. **Use consistent key naming:** `screen_name_element` (e.g., `home_title`, `profile_name`)

2. **Group related translations:** Keep all home screen translations together in JSON

3. **Test all languages:** Don't just test English, test all 5 languages

4. **Check RTL:** Always test Arabic to ensure layout mirrors correctly

5. **Use context.locale:** Get current language with `context.locale.languageCode`

---

## 📊 Translation Statistics

| Language | Keys | Status |
|----------|------|--------|
| English | 150+ | ✅ Complete |
| Tamil | 150+ | ✅ Complete |
| Hindi | 150+ | ✅ Complete |
| Spanish | 150+ | ✅ Complete |
| Arabic | 150+ | ✅ Complete |

---

## 🎯 Next Actions

1. **Immediate:** Replace text in 3-4 main screens
2. **This week:** Complete all screens
3. **Testing:** Test with real users in different languages
4. **Feedback:** Gather feedback and refine translations

---

## 📞 Need Help?

- Check `EASY_LOCALIZATION_IMPLEMENTATION.md` for detailed guide
- Review translation JSON files for available keys
- Test with `flutter run` and select different languages

---

**Ready to go!** 🚀 Start replacing text with `.tr()` calls and watch your app become multilingual!
