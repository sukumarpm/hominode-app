# Hominode Phase 2A: resident OTP authentication

## Active flow before this phase

`main.dart` routed residents to `SimpleLoginScreen`. That screen accepted an
email or phone plus password and called `FirestoreAuthService`, which queried
`users`, read the document's plaintext `password`, compared it in the client,
and then attempted Firebase email/password sign-in or account creation. Login
state could also be accepted from `SharedPreferences` without a valid Firebase
Auth session.

Other resident implementations found during the audit include:

- `FirebaseAuthService`: phone OTP plus email/password, password reset, and
  password validation in one service.
- `ResidentLoginService`: reads `users.password`, signs in or creates an
  email/password user, and stores `authUid`.
- `FirebaseAuthFirestoreService` and `SecureAuthService`: email/password
  registration, sign-in, and password reset.
- `AuthService` and `ChangePasswordScreen`: `EmailAuthProvider` password-based
  reauthentication and password changes.
- `CreateAccountScreen`: creates fake `{phone}@resident.app` email accounts.
- Old login/register/demo/diagnostic entrypoints under `lib/` and
  `lib/src/screens/` contain hardcoded or entered passwords.
- Admin login code also reads a password. It was audited but deliberately not
  modified because the separate admin authentication flow is outside Phase 2A.

## Password data located

The resident code reads or writes the `password` field in root `users`
documents. `create_auth_user_now.dart` explicitly writes it. Diagnostic files
also print stored and supplied passwords. No separate password collection was
found. `two_factor_service.dart` sends a `password` field to a placeholder
external 2FA API; it is not part of the new resident login flow.

No stored password fields or production documents were deleted or migrated in
this phase.

## Active flow after this phase

1. Resident enters an E.164 phone number on the existing login route.
2. Firebase Phone Authentication sends the OTP.
3. Manual OTP entry or Android automatic verification signs in using only a
   `PhoneAuthCredential`.
4. `TenantResolutionService` reads `users/{firebaseAuthUid}` and resolves the
   profile's `communityId`, `role`, and `isActive`, then loads
   `communities/{communityId}`.
5. The session is accepted only when the profile exists, profile is active,
   community exists and is active, and role is exactly `resident`.
6. Any failure clears tenant context and signs out Firebase Auth before an error
   is shown. App startup repeats the same checks; local preferences no longer
   establish a session.

OTP resend updates the verification ID. No email/password fallback, password
reset, fake-email creation, or password-based reauthentication exists in the
active resident route.

## Required migration and Firebase Console actions

1. Enable the Phone provider in Firebase Authentication. Disable Email/Password
   only after confirming the separate admin application does not depend on the
   same provider; provider settings apply to the shared Firebase project.
2. Add Android SHA-1 and SHA-256 signing fingerprints for debug and release.
   Configure APNs authentication and push capabilities for iOS Phone Auth.
3. Add test phone numbers/codes in Firebase Console for development. Never add
   a hardcoded OTP bypass to the application.
4. Ensure every resident Firebase Phone Auth UID has a matching
   `users/{uid}` document with `communityId`, `role: resident`, and
   `isActive: true`. The referenced community must exist and be active.
5. Normalize resident phone numbers to E.164 and verify uniqueness before
   linking legacy records. The phone field is profile data only; UID is the
   authorization key.
6. Safely inventory and later remove plaintext `users.password` fields. Do not
   log, export, or copy their values during cleanup.
7. Inventory and disable/delete legacy resident email/password Firebase Auth
   accounts, including `@resident.app` accounts, after matching them to phone
   UIDs and preserving required application data.
8. Remove or quarantine legacy diagnostic/demo source files listed above before
   production distribution. They are not reachable from the active app, but
   several still contain password examples or deprecated auth calls.
9. Do not deploy the Phase 1 rules until UID-keyed profiles and tenant fields
   are backfilled and verified. No rules or production data were changed here.
