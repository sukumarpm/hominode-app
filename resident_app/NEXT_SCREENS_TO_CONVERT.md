# Next Screens to Convert - Quick Action Guide

## Priority Order

### 1. ProfileScreen (HIGH PRIORITY)
**Location:** `resident_app/lib/profile_screen.dart`

**Steps:**
1. Add import: `import 'package:easy_localization/easy_localization.dart';`
2. Remove import: `import 'src/providers/language_provider.dart';`
3. Remove `Consumer<LanguageProvider>` wrapper
4. Replace all `languageProvider.translate()` with `.tr()`
5. Common keys to use:
   - `'profile'.tr()`
   - `'edit_profile'.tr()`
   - `'change_password'.tr()`
   - `'logout'.tr()`
   - `'settings'.tr()`

**Estimated Time:** 10 minutes

---

### 2. VisitorManagementScreen (HIGH PRIORITY)
**Location:** `resident_app/lib/src/screens/visitor_management_screen_new.dart`

**Steps:**
1. Add import: `import 'package:easy_localization/easy_localization.dart';`
2. Remove Provider imports if used
3. Replace all hardcoded text with `.tr()`
4. Common keys to use:
   - `'visitor_management'.tr()`
   - `'visitors'.tr()`
   - `'add'.tr()`
   - `'delete'.tr()`
   - `'status'.tr()`

**Estimated Time:** 15 minutes

---

### 3. EventsAnnouncementsScreen (HIGH PRIORITY)
**Location:** `resident_app/lib/events_announcements_screen.dart`

**Steps:**
1. Add import: `import 'package:easy_localization/easy_localization.dart';`
2. Remove Provider imports if used
3. Replace all hardcoded text with `.tr()`
4. Common keys to use:
   - `'events'.tr()`
   - `'announcements'.tr()`
   - `'date'.tr()`
   - `'time'.tr()`
   - `'description'.tr()`

**Estimated Time:** 15 minutes

---

### 4. MaintenanceBillingScreen (HIGH PRIORITY)
**Location:** `resident_app/lib/maintenance_billing_screen.dart`

**Steps:**
1. Add import: `import 'package:easy_localization/easy_localization.dart';`
2. Remove Provider imports if used
3. Replace all hardcoded text with `.tr()`
4. Common keys to use:
   - `'maintenance_billing'.tr()`
   - `'billing'.tr()`
   - `'payment_successful'.tr()`
   - `'payment_failed'.tr()`
   - `'select_payment_method'.tr()`

**Estimated Time:** 15 minutes

---

### 5. AppSettingsScreen (HIGH PRIORITY)
**Location:** `resident_app/lib/src/screens/app_settings_screen.dart`

**Steps:**
1. Add import: `import 'package:easy_localization/easy_localization.dart';`
2. Add import: `import 'package:resident_app/src/widgets/language_selector_easy.dart';`
3. Replace all hardcoded text with `.tr()`
4. Add LanguageSelectorEasy widget to language section
5. Common keys to use:
   - `'settings'.tr()`
   - `'language'.tr()`
   - `'notifications'.tr()`
   - `'privacy_policy'.tr()`
   - `'terms_conditions'.tr()`

**Estimated Time:** 20 minutes

---

## Quick Conversion Template

```dart
// BEFORE
import 'package:provider/provider.dart';
import 'src/providers/language_provider.dart';

class MyScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(languageProvider.translate('screen_name')),
          ),
          body: Text(languageProvider.translate('some_text')),
        );
      },
    );
  }
}

// AFTER
import 'package:easy_localization/easy_localization.dart';

class MyScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('screen_name'.tr()),
      ),
      body: Text('some_text'.tr()),
    );
  }
}
```

---

## Common Translation Keys

### Navigation
- `'home'.tr()`
- `'profile'.tr()`
- `'settings'.tr()`
- `'logout'.tr()`

### Actions
- `'save'.tr()`
- `'delete'.tr()`
- `'edit'.tr()`
- `'add'.tr()`
- `'cancel'.tr()`
- `'submit'.tr()`

### Status
- `'pending'.tr()`
- `'completed'.tr()`
- `'approved'.tr()`
- `'rejected'.tr()`
- `'in_progress'.tr()`

### Messages
- `'loading'.tr()`
- `'no_data'.tr()`
- `'error'.tr()`
- `'success'.tr()`

### Screens
- `'visitors'.tr()`
- `'billing'.tr()`
- `'events'.tr()`
- `'complaints'.tr()`
- `'messages'.tr()`
- `'community_wall'.tr()`
- `'marketplace'.tr()`
- `'amenities'.tr()`

---

## Testing Each Screen

After converting each screen:

1. **Compile Check**
   ```bash
   flutter analyze
   ```

2. **Run App**
   ```bash
   flutter run
   ```

3. **Test Language Switching**
   - Go to Settings
   - Select different language
   - Verify screen text updates
   - Navigate back and forth

4. **Test All 5 Languages**
   - English ✓
   - Tamil ✓
   - Hindi ✓
   - Spanish ✓
   - Arabic (check RTL) ✓

---

## Estimated Total Time

- ProfileScreen: 10 min
- VisitorManagementScreen: 15 min
- EventsAnnouncementsScreen: 15 min
- MaintenanceBillingScreen: 15 min
- AppSettingsScreen: 20 min
- **Total: ~75 minutes (~1.25 hours)**

---

## Progress Tracking

- [x] MainNavigation - DONE
- [x] DashboardScreen - DONE
- [ ] ProfileScreen - TODO
- [ ] VisitorManagementScreen - TODO
- [ ] EventsAnnouncementsScreen - TODO
- [ ] MaintenanceBillingScreen - TODO
- [ ] AppSettingsScreen - TODO
- [ ] EditProfileScreen - TODO
- [ ] FamilyVehiclesScreen - TODO
- [ ] DomesticStaffScreen - TODO
- [ ] MyBookingsScreen - TODO
- [ ] DocumentsCircularsScreen - TODO
- [ ] CommunityWallScreen - TODO
- [ ] MarketplaceScreen - TODO
- [ ] NotificationsScreen - TODO
- [ ] LoginScreen - TODO
- [ ] RegisterScreen - TODO
- [ ] SetupProfileScreen - TODO

---

## Need Help?

Refer to:
- `EASY_LOCALIZATION_EXAMPLE_SCREEN.md` - Before/after example
- `EASY_LOCALIZATION_QUICK_START.md` - Quick reference
- `assets/translations/en.json` - All available translation keys

---

**Ready to convert?** Start with ProfileScreen! 🚀
