# Resident App Check / optional profile email correction

The acceptance log is from Android, not iOS. No production settings, data,
Functions or Rules were changed by this task.

## Verified initialization and identity

`resident_app/lib/main.dart` awaits Firebase.initializeApp(), then awaits the only
App Check activation in shipping Resident code, before token acquisition and app
services. `kDebugMode` selects AndroidProvider.debug and AppleProvider.debug;
non-debug builds keep Play Integrity and App Attest. This correct startup/provider
selection was left unchanged. Debug startup can continue when attestation fails,
so login alone does not demonstrate that protected photo APIs will accept it.

Native configuration and generated Dart options agree:

- Project: hominode-prod; bucket: hominode-prod.firebasestorage.app.
- Current Android applicationId/package: com.marantrix.hominode.resident.
- Android Firebase app: 1:551984029668:android:ef652ea4d8e070ca0db1f1.
- iOS app: 1:551984029668:ios:cb57ef578d5066b50db1f1, same bundle identifier.
- google-services.json also contains an older com.marantrix.lyvo.resident client;
  it does not match the current Gradle applicationId. Register the debug secret
  against the current Resident Android app, not this legacy client or Admin.
- No generated Android debug resource output was present to inspect. No rebuild
  or live-device acceptance was performed; the above checks are source/native
  configuration checks, not a claim that the installed APK was rebuilt.

## Root causes and exact client corrections

- Email was incorrectly required in the edit form. Null/empty/whitespace input
  is now valid; the patch persists email as an empty string, which also clears an
  existing display email. Nonempty malformed input is still rejected. Auth email,
  phoneNumber and legacy phone values are never changed by this save path.
- Ordinary saves did not directly call App Check, but choosing a photo retained
  a pending file after failure. Subsequent Save Changes retried its verification
  before writing name/email. Ordinary display fields now save first. Only a
  pending photo enters the verified private-upload path. A photo failure keeps
  the form/file available for retry and clearly says details were saved; it does
  not publish photo metadata or report total success. Profile reloads after
  returning from the editor, including after a partial save.
- The prior photo preflight forced a token exchange on every attempt. It now uses
  getToken() and the SDK's normal valid-token cache/refresh/backoff behavior.
  Failed/empty attestation still blocks staging and attachment. No fallback,
  debug bypass or enforcement change was added.
- SDK code=unknown now has safe fixed reason categories for known throttling and
  attestation-rejected messages. Raw exception text, tokens and personal fields
  are not logged. User guidance says to retry later rather than rapidly retry.

## Focused validation

`flutter test --no-pub test/profile_form_acceptance_test.dart test/profile_acceptance_test.dart test/edit_profile_screen_localization_test.dart --timeout 45s`

**19 passed, 0 failed.** Covers optional/missing/cleared email, nonempty invalid
email, no photo verification on field-only saves, fields saved before failed
photo verification, authenticated identity preservation, fail-closed App Check,
privacy-safe error categories, write failure and existing localization/layouts.

Scoped Flutter analysis of the six changed Dart files: **0 errors, 0 warnings,
25 informational lints**. Default analyzer exit is 1 because of those infos; no
suppression was added. Formatting and git diff --check pass. No unrelated suite
or emulator/backend suite was rerun; this task changes no backend/Rules code.

## Exact Android registration and retest steps — owner action only

1. Keep the current app installed so its installation-specific debug secret stays
   stable. Run this Resident target in DEBUG on the intended emulator, using the
   device ID from flutter devices:

   ```sh
   cd /Users/sukumarmuthiah/Documents/lyvo1/resident_app
   flutter run --debug -t lib/main.dart -d EMULATOR_ID
   ```

2. In Firebase Console select **hominode-prod → App Check → Apps**, then the
   Android app **com.marantrix.hominode.resident** (app ID above), its overflow
   menu, **Manage debug tokens → Add debug token**.
3. Privately register this exact emulator installation's SDK-generated debug
   secret using Firebase's supported local debug workflow. The native debug SDK
   emits that secret locally; this task does not print or collect it. Do not
   paste it into chat, source, shared logs, commands or committed environment
   files. Do not reuse the Admin app's registration. Official instructions:
   https://firebase.google.com/docs/app-check/flutter/debug-provider#android
4. Stop repeated attempts. If the SDK reports Too many attempts, let its backoff
   expire; do not force exchanges or clear app data to bypass throttling. After
   registration/cooldown, restart the same debug installation normally.
5. With an approved synthetic account, save a name with email empty and no selected
   photo. Reopen Profile: name/empty display email persist, phone remains unchanged.
6. Select a synthetic JPEG/PNG and Save. Successful attestation must precede
   prepare/upload/complete/attach. If it still fails, capture only stage/code/reason
   diagnostics; saved display fields must remain saved. Production Play Integrity
   must not be tested by substituting an emulator debug build for a release device.

## Separate gallery deployment status — confirmed still pending

Read-only verification on October 18, 2026 found live Firestore release
`projects/hominode-prod/rulesets/782ea474-30f7-42ed-b9ec-6a203b4edace`, updated
19:13:52 PHT, still using residentSameBuilding for apartmentImages. It differs
from the already committed minimal community-gallery Rules. Consequently the
community-only Firestore query can be denied independently of App Check.

The deployed readStorageImage was last updated 19:36:50 PHT, before the
community-gallery correction commit f096ce3 at 20:50:14 PHT. Its previously
prepared correction is also pending. This task changes neither artifact.

After separate approval, the scoped commands remain:

```sh
cd /Users/sukumarmuthiah/Documents/lyvo1
firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only firestore:rules
firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only functions:readStorageImage
```

Do not deploy broader root Rules or unrelated Functions. No Storage Rules,
cleanup schedulers or other callables are needed for this follow-up. No backend
deployment is required for this task's optional email/client-save corrections.
After the separately approved deployment, retest the active same-community
slideshow and cross-community denial using synthetic data.

## Changed files

```text
resident_app/assets/translations/ar.json
resident_app/assets/translations/en.json
resident_app/assets/translations/es.json
resident_app/assets/translations/hi.json
resident_app/assets/translations/kn.json
resident_app/assets/translations/ml.json
resident_app/assets/translations/ta.json
resident_app/assets/translations/te.json
resident_app/lib/profile_screen.dart
resident_app/lib/src/screens/edit_profile_screen.dart
resident_app/lib/src/services/profile_diagnostics.dart
resident_app/lib/src/services/profile_image_service.dart
resident_app/test/profile_acceptance_test.dart
resident_app/test/profile_form_acceptance_test.dart
docs/RESIDENT_APPCHECK_PROFILE_FIX.md
```

All six excluded files remain untouched. Local commit only; no push or deployment.
