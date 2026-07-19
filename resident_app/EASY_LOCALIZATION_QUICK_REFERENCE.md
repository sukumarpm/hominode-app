# EasyLocalization - Quick Reference Card

## 🚀 Quick Start (30 seconds)

```dart
// 1. Import
import 'package:easy_localization/easy_localization.dart';

// 2. Use
Text('home'.tr())

// 3. Done! ✅
```

---

## 📝 Common Patterns

### Simple Text
```dart
Text('home'.tr())
```

### Button
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('save'.tr()),
)
```

### AppBar
```dart
AppBar(
  title: Text('profile'.tr()),
)
```

### Dialog
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('confirm'.tr()),
    content: Text('are_you_sure'.tr()),
  ),
)
```

### SnackBar
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('saved'.tr())),
)
```

---

## 🌍 Language Switching

### Change Language
```dart
context.setLocale(Locale('ta'))  // Tamil
context.setLocale(Locale('hi'))  // Hindi
context.setLocale(Locale('es'))  // Spanish
context.setLocale(Locale('ar'))  // Arabic
context.setLocale(Locale('en'))  // English
```

### Get Current Language
```dart
String lang = context.locale.languageCode;
// Returns: 'en', 'ta', 'hi', 'es', 'ar'
```

### Check if RTL
```dart
bool isRTL = context.locale.languageCode == 'ar';
```

---

## 📂 Translation Files

**Location:** `assets/translations/`

```
assets/translations/
├── en.json (English)
├── ta.json (Tamil)
├── hi.json (Hindi)
├── es.json (Spanish)
└── ar.json (Arabic)
```

**Format:**
```json
{
  "home": "Home",
  "profile": "Profile",
  "settings": "Settings"
}
```

---

## ✅ All Available Keys (153 total)

### Navigation
`home`, `profile`, `settings`, `logout`

### Actions
`save`, `delete`, `edit`, `add`, `cancel`, `submit`, `update`

### Status
`pending`, `completed`, `approved`, `rejected`, `in_progress`

### Messages
`loading`, `no_data`, `error`, `success`, `try_again`

### Screens
`visitors`, `billing`, `events`, `complaints`, `messages`, `community_wall`, `marketplace`, `amenities`, `notifications`

### Settings
`language`, `select_language`, `english`, `tamil`, `hindi`, `spanish`, `arabic`

### Payments
`payment_successful`, `payment_failed`, `select_payment_method`, `upi`, `card`, `net_banking`

### Other
`welcome`, `login`, `register`, `email`, `password`, `phone`, `name`, `apartment`, `building`, `date`, `time`, `search`, `filter`, `sort`, `description`, `category`, `priority`, `high`, `medium`, `low`, `attachment`, `attachments`, `upload`, `download`, `share`, `report`, `block`, `unblock`

---

## 🔄 Conversion Checklist

For each screen:

- [ ] Add import: `import 'package:easy_localization/easy_localization.dart';`
- [ ] Remove: `import 'src/providers/language_provider.dart';`
- [ ] Remove: `Consumer<LanguageProvider>` wrapper
- [ ] Replace: `languageProvider.translate('key')` → `'key'.tr()`
- [ ] Test: Run app and change language
- [ ] Verify: All text updates in all 5 languages

---

## 🧪 Testing

### Test Language Switching
```bash
flutter run
# Go to Settings
# Select different language
# Verify text updates
```

### Test All Languages
- [ ] English
- [ ] Tamil
- [ ] Hindi
- [ ] Spanish
- [ ] Arabic (check RTL)

### Test Persistence
```bash
# 1. Change language to Tamil
# 2. Close app
# 3. Reopen app
# 4. Verify language is still Tamil
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Key not found | Add to all 5 JSON files |
| Language doesn't change | Use `context.setLocale()` |
| Arabic not RTL | Check main.dart RTL builder |
| Translations not loading | Run `flutter clean` + `flutter pub get` |
| Build error | Check JSON syntax |

---

## 📊 Supported Languages

| Language | Code | Status | RTL |
|----------|------|--------|-----|
| English | en | ✅ | No |
| Tamil | ta | ✅ | No |
| Hindi | hi | ✅ | No |
| Spanish | es | ✅ | No |
| Arabic | ar | ✅ | Yes |

---

## 🎯 Conversion Progress

```
MainNavigation ✅
DashboardScreen ✅
ProfileScreen ⏳
VisitorManagementScreen ⏳
EventsAnnouncementsScreen ⏳
MaintenanceBillingScreen ⏳
AppSettingsScreen ⏳
... (13 more screens)
```

**Progress:** 2/18 screens (11%)

---

## 📚 Documentation

- `EASY_LOCALIZATION_QUICK_START.md` - 5-minute guide
- `EASY_LOCALIZATION_EXAMPLE_SCREEN.md` - Before/after
- `EASY_LOCALIZATION_IMPLEMENTATION.md` - Complete guide
- `NEXT_SCREENS_TO_CONVERT.md` - Step-by-step
- `EASY_LOCALIZATION_INTEGRATION_COMPLETE.md` - Phase 2 summary

---

## 💡 Pro Tips

1. **Use consistent key naming:** `screen_name_element` (e.g., `home_title`)
2. **Group related translations:** Keep all home screen keys together
3. **Test all languages:** Don't just test English
4. **Check RTL:** Always test Arabic for layout issues
5. **Use context.locale:** Get current language with `context.locale.languageCode`

---

## 🚀 Next Steps

1. Convert ProfileScreen (10 min)
2. Convert VisitorManagementScreen (15 min)
3. Convert EventsAnnouncementsScreen (15 min)
4. Convert MaintenanceBillingScreen (15 min)
5. Convert AppSettingsScreen (20 min)

**Total Time:** ~75 minutes

---

## ✨ Key Benefits

✅ Simple `.tr()` method  
✅ Automatic language switching  
✅ No app restart needed  
✅ Language persists  
✅ RTL support for Arabic  
✅ Easy to add new languages  
✅ Easy to maintain  

---

**Ready to convert?** Start with ProfileScreen! 🎯
