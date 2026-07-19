# Screens Needing Localization Fix

## Status: 68 screens need EasyLocalization import added

### Priority 1: Core Screens (10)
1. ✅ admin_login_screen.dart
2. ✅ admin_dashboard_screen.dart
3. ✅ admin_chat_conversation_screen.dart
4. ✅ access_blocked_screen.dart
5. ✅ amenities_booking_screen.dart
6. ✅ building_management_screen.dart
7. ✅ chat_conversation_screen.dart
8. ✅ create_account_screen.dart
9. ✅ documents_circulars_screen.dart
10. ✅ domestic_staff_screen.dart

### Priority 2: Login & Auth Screens (8)
11. ✅ login_screen.dart
12. ✅ login_screen_new.dart
13. ✅ register_screen.dart
14. ✅ simple_login_screen.dart
15. ✅ verify_otp_screen.dart
16. ✅ verify_otp_screen_single_field.dart
17. ✅ edit_profile_screen.dart
18. ✅ setup_profile_screen.dart

### Priority 3: Feature Screens (15)
19. ✅ marketplace_screen.dart
20. ✅ marketplace_create_listing_screen.dart
21. ✅ marketplace_edit_listing_screen.dart
22. ✅ marketplace_product_detail_screen.dart
23. ✅ marketplace_buyer_phone_view_screen.dart
24. ✅ marketplace_your_products_screen.dart
25. ✅ marketplace_your_product_detail_screen.dart
26. ✅ family_vehicles_screen.dart
27. ✅ my_bookings_screen.dart
28. ✅ notifications_screen.dart
29. ✅ notifications_settings_screen.dart
30. ✅ messages_screen.dart
31. ✅ messages_screen_enhanced.dart
32. ✅ chat_with_technician_screen.dart
33. ✅ qr_scanner_screen.dart

### Priority 4: Admin Screens (8)
34. ✅ admin_chat_query_selection_screen.dart
35. ✅ admin_chat_query_template_screen.dart
36. ✅ flat_management_screen.dart
37. ✅ admin_chat_conversation_screen.dart
38. ✅ admin_dashboard_screen.dart
39. ✅ admin_login_screen.dart
40. ✅ building_management_screen.dart
41. ✅ flat_management_screen.dart

### Priority 5: Splash & Loading Screens (8)
42. ✅ splash_screen.dart
43. ✅ splash_screen_clean.dart
44. ✅ splash_screen_new.dart
45. ✅ simple_splash_screen.dart
46. ✅ modern_splash_screen.dart
47. ✅ animated_splash_screen.dart
48. ✅ loading_screen.dart
49. ✅ splash_flow.dart

### Priority 6: Settings & Utility Screens (10)
50. ✅ settings_screen.dart
51. ✅ language_settings_screen.dart
52. ✅ biometric_settings_screen.dart
53. ✅ two_factor_settings_screen.dart
54. ✅ two_factor_settings_screen_backup.dart
55. ✅ change_password_screen.dart
56. ✅ notifications_center_screen.dart
57. ✅ emergency_sos_screen.dart
58. ✅ document_viewer_screen.dart
59. ✅ image_upload_example_screen.dart

### Priority 7: Other Screens (9)
60. ✅ onboarding_flow.dart
61. ✅ events_module_screen.dart
62. ✅ events_tab.dart
63. ✅ notices_tab.dart
64. ✅ polls_screen.dart
65. ✅ polls_tab.dart
66. ✅ product_detail_screen.dart
67. ✅ add_marketplace_item_screen.dart
68. ✅ chat_conversation_screen_fixed.dart

---

## Fix Template

For each screen, add this import after the existing imports:

```dart
import 'package:easy_localization/easy_localization.dart';
```

Then replace all hardcoded strings with `.tr()`:

**Before:**
```dart
Text('Welcome')
ElevatedButton(child: Text('Submit'))
```

**After:**
```dart
Text('welcome'.tr())
ElevatedButton(child: Text('submit'.tr()))
```

---

## Automated Fix Script

Run this to add the import to all files:

```bash
# Add import to all screen files
for file in resident_app/lib/src/screens/*.dart; do
  if ! grep -q "import 'package:easy_localization" "$file"; then
    sed -i "/^import 'package:flutter\/material.dart';/a import 'package:easy_localization/easy_localization.dart';" "$file"
  fi
done
```

---

## Next Steps

1. Add EasyLocalization import to all 68 screens
2. Convert hardcoded strings to use `.tr()`
3. Add missing translation keys to JSON files
4. Test language switching on all screens
5. Verify no compilation errors

---

**Total Screens to Fix:** 68
**Estimated Time:** 2-3 hours
**Priority:** HIGH - Required for production release
