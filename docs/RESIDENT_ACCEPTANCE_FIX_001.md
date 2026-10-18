# Resident acceptance correction — 001

Local implementation and validation only. No production data, configuration,
Functions or Rules were modified; no images were uploaded or migrated.

## Findings and corrections

- **Profile photo:** production image-callable warnings around 20:21–20:22 on
  October 18 show `prepareStorageImageUpload` rejecting App Check with
  `app-check/invalid-argument`, before Storage staging. Those logs do not identify
  the acceptance device. Resident debug startup continues after token acquisition
  failure, and ProfileImageService previously swallowed the underlying exception.
  The photo service now obtains fresh attestation with a bounded timeout before
  any profile lookup/upload, fails closed, preserves retry, and reports only
  safe operation/error categories. The UI gives a localized device-verification
  message instead of an indistinguishable upload failure. No token, user data,
  file path, private reference or bytes are added to diagnostic messages.
- **Save Changes:** a failed pending photo aborted the existing save before its
  name/email write, explaining why both actions fail together. An independent
  name/email-only production failure was not captured. The separate write path is
  validated against the current authorization policy. It now copies only the
  supplied display-field patch plus updatedAt to the authenticated UID; canonical
  phoneNumber and legacy display phone remain unchanged. Optional Firebase Auth
  display-name synchronization no longer reports a failed save after a successful
  Firestore commit. Real write failure still reports failure. Personal debug
  output and stale SharedPreferences identity fallback were removed from the
  traced edit-profile load/save path. Private/legacy photo aliases remain readable.
- **Community banner:** the previous one-shot gallery query and private reader
  limited images to the resident's building. The new live query uses the Admin
  `apartmentImages` collection, active status and the current canonical community.
  The gallery Rules/private read contract now permits approved, active residents
  to view active community gallery images across buildings in their own tenant;
  current building-record/asset binding, ownership of mutations, identity checks
  and cross-tenant denial remain enforced. Profile/logout/community changes clear
  image subscriptions. Records retain ordering and legacy URL compatibility.
  A five-second slideshow crossfades over 600 ms, pauses while inactive/backgrounded,
  disposes its timer, supports swiping, and retains the existing fallback and
  foreground gradient/text/dimensions.
- **Notification indicator:** the old red dot was unconditional. Home now uses
  the same authorized `notices` and persisted own `readBy` receipts as its actual
  Notifications screen, refreshes on reads/navigation and periodically while
  visible, displays only positive counts, and caps the badge at 99+. Opening a
  notice records its read receipt. Unknown/read errors do not invent unread
  notifications. A minimal Rules correction permits checking a missing own
  receipt only when its parent notice is eligible; existing and foreign receipts
  remain protected. The actual notice-detail test also exposed an existing date
  row overflow; author/date text can now wrap without changing hierarchy.
- **Logo:** the square is embedded in the opaque PNG artwork, rather than added
  by ResidentHomeLogo. Existing reviewed transparent Resident/Admin variants are
  bundled without changing configured widget sizes or regenerating artwork.
  Those two variants were locally ignored; this task includes those exact assets
  so a clean checkout can render them. Launcher icon configuration and PDF logo
  artwork remain unchanged. No matching approved tracked transparent Security
  counterpart was established; its current artwork remains unchanged. A matching
  transparent Security asset is still required. The excluded Security_New1.png
  and the other five explicitly excluded files remain byte-for-byte unchanged.

## Focused validation

- Resident: 61 affected profile/upload/private-viewer/banner/notification widget
  and service tests passed; three additional unread-source tests passed; two
  focused logo tests passed: **66 distinct tests, zero final failures**.
- Admin transparent-logo test: **1 passed**.
- Backend apartment lifecycle/community reader + minimal Rules structure:
  **19 passed, zero failed**.
- Minimal Firestore/Storage emulators, project `demo-hominode-storage-images`:
  **37 passed, zero failed, zero skipped**. Includes own profile display-field
  updates, protected phone/community fields, cross-user/cross-tenant denial,
  gallery reads across same-community buildings, inactive/withdrawn denial, and
  missing/read/foreign notice-receipt checks. Only synthetic localhost data used.
- Scoped Resident analysis: **0 errors, 0 warnings, 68 informational style
  diagnostics**; default CLI exits 1 for those informational diagnostics. No
  diagnostics were suppressed. Scoped Admin analysis: **no issues**.
- Dart formatting, affected JavaScript syntax checks and `git diff --check`: pass.
- No new live-device visual acceptance or production writes were performed.

## Remaining release actions — owner approval required, not executed

1. For the Resident iPhone simulator/debug app, verify/register its own App Check
   debug token under the Resident iOS Firebase app. Do not use Admin's registration,
   disable enforcement, commit tokens, or change to an unsigned upload fallback.
   Release device builds continue using their existing production providers.
2. The community gallery and exact own-notice-receipt correction require the
   updated minimal **Firestore Rules** and **readStorageImage** callable. No
   Storage Rules, other image APIs or cleanup schedulers need deployment for this
   correction. After separate approval, scoped commands are:

   ```sh
   firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only firestore:rules
   firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only functions:readStorageImage
   ```

   Deploy the minimal variant, never the broader root Rules as part of this fix.
   No backend deployment is needed for the client-side profile save corrections.
3. Supply/approve a matching transparent Security logo; do not strip intentional
   artwork or silently include the explicitly excluded backup.

## Exact manual retest

Use approved synthetic acceptance accounts/images; do not alter customer records.
After the separately approved deployment above, install the updated apps:

1. Register the Resident simulator's App Check debug token privately if required;
   restart. Save name/email with no pending photo. Reopen Profile and confirm the
   display fields persisted and authenticated phoneNumber is unchanged.
2. Pick a small synthetic JPEG/PNG, Save Changes, reopen Profile/Home and confirm
   private display. Retry after a temporary connection failure. An unattested
   device must receive a device-verification error and must not stage/attach data.
   If name/email-only save still fails, capture only the new operation/code log.
3. Use two active Admin gallery images in the same test community, including
   different buildings. Confirm Home rotation, swipe, readable text, hidden-tab
   pause and fallback. A different community and inactive account must be denied;
   logout/community change must not retain the old private image.
4. Empty actual inbox: no badge. Eligible unread notice: positive count. Open it
   and return: badge decrements/clears. A failed read-state lookup must not create
   a false count; other-user/other-community receipts remain inaccessible.
5. Check Resident Home, login, OTP and splash plus Admin visible logos on light
   and dark backgrounds. Existing layout sizes stay unchanged. Security artwork
   remains pending the approved asset; no claim of its visual correction is made.

## Exact changed files

```text
deployment/storage-minimal/README.md
deployment/storage-minimal/firestore.rules
docs/RESIDENT_ACCEPTANCE_FIX_001.md
firestore.rules
functions/src/apartment_images.js
functions/test/apartmentImages.unit.test.js
functions/test/storageImages.emulator.test.js
functions/test/storageMinimalRules.unit.test.js
hominode-admin/admin_app/assets/Admin_New1.png
hominode-admin/admin_app/lib/admin_desktop_shell.dart
hominode-admin/admin_app/lib/admin_login_desktop.dart
hominode-admin/admin_app/lib/admin_login_screen.dart
hominode-admin/admin_app/lib/splash_screen.dart
hominode-admin/admin_app/test/logo_asset_test.dart
resident_app/assets/translations/ar.json
resident_app/assets/translations/en.json
resident_app/assets/translations/es.json
resident_app/assets/translations/hi.json
resident_app/assets/translations/kn.json
resident_app/assets/translations/ml.json
resident_app/assets/translations/ta.json
resident_app/assets/translations/te.json
resident_app/lib/assets/Resident_New1.png
resident_app/lib/dashboard_screen.dart
resident_app/lib/main.dart
resident_app/lib/receipt_screen.dart
resident_app/lib/src/screens/edit_profile_screen.dart
resident_app/lib/src/screens/notifications_screen.dart
resident_app/lib/src/screens/simple_login_screen.dart
resident_app/lib/src/screens/splash_screen_clean.dart
resident_app/lib/src/screens/verify_otp_screen_single_field.dart
resident_app/lib/src/services/apartment_images_service.dart
resident_app/lib/src/services/notice_firestore_service.dart
resident_app/lib/src/services/profile_diagnostics.dart
resident_app/lib/src/services/profile_image_service.dart
resident_app/lib/src/services/user_data_service.dart
resident_app/lib/src/widgets/community_image_slideshow.dart
resident_app/lib/src/widgets/flat_access_wrapper.dart
resident_app/lib/src/widgets/resident_home_identity_actions.dart
resident_app/lib/src/widgets/resident_notification_button.dart
resident_app/pubspec.yaml
resident_app/test/community_banner_acceptance_test.dart
resident_app/test/notice_unread_count_test.dart
resident_app/test/notification_indicator_test.dart
resident_app/test/notifications_localization_test.dart
resident_app/test/profile_acceptance_test.dart
resident_app/test/profile_form_acceptance_test.dart
resident_app/test/resident_home_identity_actions_test.dart
```

All six excluded files were checked against their earlier preservation hashes.
Existing commits remain intact; the task creates local commits only.
