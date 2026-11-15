# Resident Android App Check debug-token diagnosis

Verified 2026-10-19, Asia/Manila. No application source, provider configuration,
dependencies, deployed resources or production records were changed. No debug
secret values were printed, written to artifacts, embedded or committed.

## Confirmed causes

1. The secret is stable when app data is preserved. On `emulator-5554`, its
   in-memory hash remained identical through **two Android process restarts**
   and **one successful Flutter hot restart** using `flutter attach --machine`.
   The attach session was detached afterward, leaving the app installed/running.
2. The installed Firebase Android debug SDK **18.0.0** loads the secret from
   app-private SharedPreferences keyed by Firebase app persistence identity.
   Inspection of the installed SDK bytecode shows that the diagnostic log
   runs after both retrieval and generation, so seeing the message again does
   not mean a new secret was generated.
3. `emulator-5554` has actual Resident removal/reinstallation events on October
   18 and October 19, including around **00:09–00:10 on October 19**. Package
   metadata has first-install and last-update time **00:10:06**. These are
   installation resets, not normal hot restarts. The logs do not establish
   whether a person or a development tool initiated each removal.
4. `emulator-5556` has its own different persisted secret. A second emulator is
   a separate installation, not evidence that the first one's secret changed.
5. No targeted app startup/native code or repository launch configuration was
   found clearing App Check storage. Normal Flutter installation uses
   `adb install -t -r`; the installed Flutter tool can fall back to uninstalling
   when replacement installation fails. That fallback is a possible mechanism,
   not a confirmed explanation for the observed uninstalls.

There is **no verified application token-regeneration bug to patch**. Native
persistence is already the stable development mechanism. A hardcoded token,
custom provider, environment-secret bridge or dependency upgrade is unnecessary.
The correction is to preserve the chosen emulator installation and register its
current secret once, rather than uninstalling or clearing data on each restart.

## Firebase identity and activation order

- Project: `hominode-prod`.
- Android package: `com.marantrix.hominode.resident`.
- Firebase Android app ID: `1:551984029668:android:ef652ea4d8e070ca0db1f1`.
- Both emulators' stored App Check persistence identities match this app ID.
- `google-services.json` also contains the legacy
  `com.marantrix.lyvo.resident` registration. Do not select that legacy app when
  registering a secret for the current package.
- Startup awaits `Firebase.initializeApp()` before provider activation and token
  acquisition. Debug builds select Android debug / Apple debug providers;
  non-debug builds retain Play Integrity / App Attest. No forced token refresh
  was added.
- Read-only Console API inspection found four debug-token registrations on the
  current Android app and none on the legacy app. The API omitted token values,
  so it could not establish whether either emulator's current secret matches a
  registration. No Console registrations were added, changed or removed.

## One-time registration and normal development

1. Choose `emulator-5554` explicitly. Keep its app installation and data; do not
   use `adb uninstall`, `pm clear`, IDE Clear Storage, or AVD Wipe Data as a
   restart workflow. If Flutter reports **Uninstalling old version**, inspect
   the preceding install/signature error before repeatedly retrying.
2. In your private local Flutter/logcat console, obtain the **current Resident
   installation's** SDK debug secret. After a hot restart the SDK repeats the
   same stored secret. Do not copy a different app/emulator's log entry, and do
   not paste secrets into chat, source, shell history or reports.
3. In Firebase Console → `hominode-prod` → App Check → Apps, choose the current
   Resident Android app above → Manage debug tokens. Register that secret once
   with a label identifying the emulator. This is an owner action, not performed
   during this investigation. This is the documented Firebase workflow:
   https://firebase.google.com/docs/app-check/flutter/debug-provider.
4. Restart once while preserving data and retry the operation once. If SDK
   throttling persists, allow its backoff rather than forcing token exchanges
   or clearing data. The emulator still logged `Too many attempts` during this
   investigation; repeated restarts alone do not register or repair attestation.
5. Reuse `r`/`R` in the existing Flutter session. To attach without installation:

   ```sh
   cd resident_app
   flutter attach -d emulator-5554 --app-id com.marantrix.hominode.resident
   ```

   When starting a fresh development session, select the device explicitly:
   `flutter run --debug -d emulator-5554`. Register another emulator separately
   if it is used. A genuinely new installation/data reset may require a new
   registration; ordinary hot restart does not.

## GREEN-WAVE Community Wall — separate blockers

- Exact community remains active `Green Wave Residences`, ID `GREEN-WAVE`,
  slug `green-wave`, Firestore database `(default)`.
- **`subscriptions/GREEN-WAVE` is still absent.** Queries for subscriptions
  assigned to `GREEN-WAVE` or `green-wave` also returned no matching records.
  No embedded plan/subscription metadata was present on the community document.
  The reported Plus activation is not reflected in the canonical data used by
  the backend. No subscription was created/changed during this task.
- `getCurrentCommunityEntitlement` remains ACTIVE in `asia-southeast1`, last
  updated **2026-10-08 05:33:48 UTC**, Node.js 20. The previously prepared
  entitlement update has **not** been deployed.
- The Resident log at **2026-10-19 00:15:54 Asia/Manila** reports Wall
  `unauthenticated`. The corresponding backend invocation at
  **2026-10-18 16:15:52–54 UTC** returned HTTP **401**, with
  **Auth VALID / App Check INVALID**. This is an App Check rejection, not a
  lost Firebase login or a subscription/plan decision for that invocation.
- Earlier entitlement invocations had Auth VALID / App Check VALID and HTTP 400. The reported missing-subscription message corresponds to the resolver's
  `failed-precondition` branch. Once attestation succeeds, the missing canonical
  subscription remains an independent configuration blocker.
- App Check registration and authorized subscription provisioning need separate
  owner actions. Do not infer Plus from a label, bypass the callable, relax
  attestation/Rules, or enable features when verification fails. An old Essential
  plan definition is a separate deployment issue; it does not turn an absent
  subscription into Plus.

## Focused verification

- Device: **2/2 process restarts and 1/1 Flutter hot restart** preserved the
  secret. Raw SDK logs and secret values were processed only in memory.
- Resident tests: **24 passed, 0 failed** across `profile_acceptance_test.dart`,
  `community_wall_entitlement_policy_test.dart` and
  `community_verification_feedback_test.dart`.
- Backend entitlement-contract tests: **7 passed, 0 failed** in
  `releaseEntitlementContracts.unit.test.js`.
- `git diff --check` passes. No unrelated suites or runtime refactoring.

Only this report was added by this task. Existing untracked preparation work
and all six excluded files are preserved. No commits, pushes or deployments.
