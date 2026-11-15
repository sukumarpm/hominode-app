# Security account deletion request — P0

This implementation records a request for manual community review. It does not
delete or disable accounts, remove assignments, or modify historical records.
P1/P2 profile placeholders remain unchanged.

## Architecture and reuse

- `security_app/lib/screens/profile_screen.dart` adds **Request Account Deletion**.
- The review screen loads the signed-in officer's request status, obtains explicit
  consent, and submits through the `securityAccountDeletionRequest` callable.
- The callable enforces App Check. The core requires phone authentication and an
  active `securityStaff/{auth.uid}` profile whose UID and registered phone match
  the verified session. It verifies the profile's active community server-side.
- Payloads contain only `action: status`, or `action: submit, confirmed: true`.
  Client target UIDs, community IDs, email recipients and other fields are rejected.
- Recipient lookup uses `communityDeletionContacts/{verifiedCommunityId}.email`,
  the same server-only schema used by the community-routing release's public form.
  Email addresses never appear in callable responses. Missing/invalid routing fails
  before an intake is written or an email is sent.
- Email uses the existing `HOMINODE_DELETION_SMTP_APP_PASSWORD` secret and sender.
  Successful submission requires persisted intake and acknowledged mail delivery.
- Intakes live in `securityAccountDeletionRequests`, separately from Resident
  `accountDeletionRequests` and its automatic fulfillment/retry workers. No Security
  request is passed to those workers or the Resident-only Admin review queue.
- The request document ID is derived from the authenticated UID. Retries/reopening
  recognize the same reference; a transaction lease prevents concurrent email sends.
  Failed/expired delivery can retry with the same reference. SMTP delivery itself
  cannot guarantee exactly-once delivery after a lost acknowledgment.
- Status reads and writes are through the callable. The existing Firestore
  catch-all deny protects this collection; no rules changes are needed.

The primary working copies contain an older Resident-only public form; the
community dropdown/private-routing implementation was inspected in
`hominode-routing-validation` and `hominode-community-routing-release` under
`Documents`. They were read only. No public form, CAPTCHA, public endpoint,
Resident/Admin workflow, authentication or startup policy was changed.

## Review and retention

Community recipients receive the request reference, trusted account identity and
community scope, with explicit manual-review/retention instructions. Receipt is
not proof of completed deletion. Human reviewers must verify identity/consent,
review and reassign duties, and assess historical record retention before any
later account action. This P0 adds no fulfillment or historical cleanup capability.

Admin Security provisioning already creates Auth and `securityStaff/{uid}` records
through a server callable. `removeSecurityAssignment` clears assignment fields and
records the operation; it does not delete/disable the Firebase Auth user. Generic
staff-record deletion helpers do not provide Security account deletion semantics.

## Deployment prerequisites (not performed)

1. Review/deploy only the new `securityAccountDeletionRequest` function. The
   current branch contains unrelated backend work and older public-form code;
   this task does not authorize deploying the full Functions bundle or hosting.
2. Verify the existing SMTP secret and Gmail sender are usable by this function.
3. Verify an active community's private `communityDeletionContacts/{id}.email`
   configuration through the authorized operational process. No production
   contact records were read or changed during implementation.
4. Rebuild the Security app. Existing Security App Check registration/startup
   verification must remain enabled. No rules, indexes or website deployment is
   required for this feature.

## Manual Pixel 9 check

Use a test Firebase environment with a test officer and a test community recipient;
do not submit production test requests or send real mail without explicit approval.

1. Sign in using the existing phone OTP flow. Open **Profile & Shift** and select
   **Request Account Deletion**. Confirm the trusted community is shown.
2. Select **Cancel**: return to the profile without a request write or mail send.
3. Reopen, read the review/retention explanation, select consent and submit. Verify
   progress, disabled repeated submission/back actions, and a server-confirmed
   reference. The account and work assignments remain active.
4. Reopen again: see the same reference without another request or notification.
5. Simulate callable/network/mail failure in the test environment. Check that no
   success is shown and retry retains the existing reference.
6. Verify a missing community recipient fails clearly; verify Resident and
   cross-community payloads cannot submit through this endpoint.
7. Check phone/tablet font scaling and that all consent, error and receipt text
   remains reachable by scrolling.
