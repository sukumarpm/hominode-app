# Multi-Language Implementation - Quick Guide

## For Developers: How to Add Localization to New Screens

### Step 1: Add Translation Keys
Add your text keys to all 5 translation JSON files:
- `lib/l10n/translations_en.json`
- `lib/l10n/translations_ta.json`
- `lib/l10n/translations_hi.json`
- `lib/l10n/translations_es.json`
- `lib/l10n/translations_ar.json`

Example:
```json
{
  "my_new_key": "My English Text",
  "another_key": "Another Text"
}
```

### Step 2: Wrap Screen with Consumer
```dart
import 'package:provider/provider.dart';
import 'src/providers/language_provider.dart';

class MyNewScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          title: languageProvider.translate('my_new_key'),
          // ... rest of UI
        );
      },
    );
  }
}
```

### Step 3: Use Translation Keys
Replace hardcoded text with translation keys:
```dart
// ❌ Before
Text('My English Text')

// ✅ After
Text(languageProvider.translate('my_new_key'))
```

### Step 4: Pass languageProvider to Methods
If you have helper methods that need translations:
```dart
Widget _buildCard(LanguageProvider languageProvider) {
  return Card(
    child: Text(languageProvider.translate('card_title')),
  );
}

// In build method:
_buildCard(languageProvider)
```

---

## Current Implementation Status

### ✅ Fully Localized Screens
1. Main Navigation (Bottom Nav)
2. Dashboard Screen
3. Visitor Management Screen
4. Events & Announcements Screen
5. Maintenance & Billing Screen
6. Profile Screen

### 📝 Partially Localized Screens
- App Settings Screen (has language selector)
- Edit Profile Screen
- Family Vehicles Screen
- Domestic Staff Screen
- My Bookings Screen
- Documents & Circulars Screen
- Community Wall Screen
- Marketplace Screen
- Notifications Settings Screen

### ⚠️ Not Yet Localized
- Login Screen
- Register Screen
- Various modals and dialogs

---

## Translation Keys Available

### Navigation & Screens
- `home` - Home screen
- `profile` - Profile screen
- `settings` - Settings screen
- `visitors` - Visitors screen
- `billing` - Billing screen
- `events` - Events screen
- `visitor_management` - Visitor Management title
- `maintenance_billing` - Maintenance & Billing title

### Status & States
- `pending` - Pending status
- `approved` - Approved status
- `completed` - Completed status
- `rejected` - Rejected status
- `in_progress` - In Progress status
- `loading` - Loading state
- `no_data` - No data available

### Actions & Buttons
- `save` - Save button
- `cancel` - Cancel button
- `delete` - Delete button
- `edit` - Edit button
- `add` - Add button
- `logout` - Logout button
- `submit` - Submit button
- `update` - Update button

### Messages
- `error` - Error message
- `success` - Success message
- `language_changed` - Language changed successfully
- `payment_successful` - Payment successful
- `payment_failed` - Payment failed
- `error_loading_visitors` - Error loading visitors
- `error_loading_bills` - Error loading bills
- `error_loading_announcements` - Error loading announcements
- `error_loading_events` - Error loading events

### Other
- `language` - Language
- `select_language` - Select Language
- `english` - English
- `tamil` - Tamil
- `hindi` - Hindi
- `spanish` - Spanish
- `arabic` - Arabic

---

## How to Test Language Switching

1. Open App Settings
2. Tap "Select Language"
3. Choose a different language
4. Observe all screens update automatically
5. Close and reopen app - language preference persists

---

## RTL Support (Arabic)

Arabic automatically gets:
- Right-to-left text direction
- Mirrored layout
- Reversed navigation
- Proper text alignment

No additional code needed - handled by Flutter's built-in RTL support.

---

## Common Issues & Solutions

### Issue: Text not updating when language changes
**Solution:** Make sure screen is wrapped with `Consumer<LanguageProvider>`

### Issue: Translation key not found
**Solution:** Add the key to all 5 translation JSON files

### Issue: Arabic text not displaying correctly
**Solution:** Ensure you're using proper Arabic Unicode characters in JSON files

### Issue: Layout not mirroring for Arabic
**Solution:** Use `Directionality` widget or ensure app-level RTL is configured

---

## File Locations

- **Language Provider:** `lib/src/providers/language_provider.dart`
- **Translation Files:** `lib/l10n/translations_*.json`
- **Localization Service:** `lib/src/services/localization_service.dart`
- **Localization Helper:** `lib/src/utils/localization_helper.dart`

---

## Performance Notes

- Language switching is instant (no network calls)
- Translations are loaded once at app startup
- Consumer rebuilds only affected widgets
- Minimal performance impact

---

## Adding New Languages

1. Create new translation file: `lib/l10n/translations_xx.json` (where xx is language code)
2. Add all translation keys with translations
3. Update LanguageProvider to include new language
4. Update language selector UI to show new language option

---

**Last Updated:** March 28, 2026
**Status:** Production Ready
