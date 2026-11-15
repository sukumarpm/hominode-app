# Security notification read permission fix

## Confirmed cause

On 9 November 2026, read-only production inspection found matching `SOS Alert — Nova, N014` notifications with canonical `recipientId`, `communityId`, `audience: security`, `role: security`, and `appId: security`. Recipients matched active Security profiles in the same community. These records were not legacy phone-number recipients and had no `deletedAt` field.

The deployed Firestore rules (release updated `2026-10-31T09:10:49.023990Z`) contained the same notification authorization helper as the checkout. Reproduction against those exact rules in the local emulator allowed the Security read but denied the read-state update with **maximum of 1000 expressions to evaluate has been reached**.

`isNotificationRecipient` evaluated unrelated Resident and Admin authorization before Security authorization. The update rule invokes it for both the stored and resulting document. The repeated checks exceeded the Rules evaluation budget. Existing Flutter fakes did not execute Firestore rules and therefore did not catch this failure.

## Narrow correction

Dispatch to the existing authorization function using the document's audience before doing profile checks. Each selected function still verifies the authenticated recipient, community, account eligibility, audience, role and app ID. Both old-document and new-document authorization checks remain in place, as do the existing mutable-field allowlist and deletion protections.

No client, callable, notification content, SOS navigation or push changes are needed. Canonical legacy notifications without optional read timestamps remain supported. Noncanonical phone-number recipients or missing/mismatched audience, role or app ID are denied, never reinterpreted as another officer's inbox.

## Validation

- `functions/test/securityNotificationRead.rules.emulator.test.js` executes real Rules checks for Security SOS read-state persistence, general notifications, recipient/community isolation, immutable content/routing/delivery fields, legacy routing rejection, Phone Auth requirements, and Admin/Resident update compatibility.
- Run in a demo Firestore emulator only; the test skips without `FIRESTORE_EMULATOR_HOST`.
- Optional `NOTIFICATION_RULES_FILE` selects a captured rules artifact for before/after validation; the default is the checkout's `firestore.rules`.
- Existing Security inbox/widget tests cover confirmation before read-state UI changes, failed writes, loading/empty/error states, responsive layouts and canonical SOS routing.

## Deployment requirement — not deployed by this task

A **Firestore rules-only deployment** is required for the existing app's Mark as read action to work. No Functions deployment, index change, data migration, app rebuild or notification rewrite is required.

The checkout already contains unrelated uncommitted rules changes. Do not publish all of those changes accidentally. A temporary release artifact was prepared at `/private/tmp/security-notification-read-release/` from the exact deployed rules snapshot plus only the notification helper correction. Its `firebase.json` contains only the Firestore rules target. The snapshot is `/private/tmp/security-notification-deployed.rules`.

Review the artifact diff before using it. If the deployed release has changed since the inspection above, regenerate the artifact from the new deployed rules with the same helper-only change. Temporary artifacts are local to this workstation and are not tracked release assets.

For the reviewed artifact, from `functions/`, the rules-only deployment command is:

```sh
./node_modules/.bin/firebase deploy --project hominode-prod --config /private/tmp/security-notification-read-release/firebase.json --only firestore:rules
```

This command was **not executed**. After authorized deployment, reopen the Security inbox, mark the SOS notification as read, reopen again to confirm persistence, and verify Open SOS alert and push taps still reach the same emergency. No production read-state mutations were performed during diagnosis or validation.
