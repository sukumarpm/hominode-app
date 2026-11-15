# Admin-assisted Resident deletion — Phase 2A

Backend only. No public intake, website OTP, direct deletion endpoint, or Admin UI is added.
Both new callables require App Check from an allowlisted Admin Firebase application, a canonical active Community Admin with verified phone authentication, authentication within five minutes, and current authorization for the target community. The API payload cannot supply actor IDs, timestamps, financial approvals, or execution claims.

## 1. Create pending intake

Callable: `createAdminAssistedDeletionRequest`

```json
{
  "residentUid": "canonical-auth-and-users-document-uid",
  "communityId": "GREEN-WAVE",
  "supportCaseReference": "CASE-123",
  "verificationMethod": "in_person_with_community_records",
  "verificationEvidenceReference": "EVIDENCE-456",
  "verificationNotes": "Protected evidence and community records independently checked; explicit deletion consent recorded.",
  "consentAttested": true
}
```

Allowed verification methods:

- `in_person_with_community_records`
- `live_video_with_community_records`
- `document_and_community_records`

The Admin must already have independently checked identity and explicit deletion consent. Email alone, a support-case reference alone, or a generic Admin approval is insufficient. Evidence references are opaque identifiers for protected support evidence, not document contents or image URLs. Case references are 3–80 characters; evidence references are 3–160 characters, using letters, digits, `.`, `_`, `:`, and `-`. The evidence reference must differ from the case reference. Notes must be 20–600 characters; raw image data and document links are rejected. Do not put identity-document images or sensitive document contents in notes.

The server requires an existing `users/{residentUid}` Resident with the exact UID and community, no additional Admin/Security role, and no ambiguous multi-community assignment. It records the immutable intake under the existing `accountDeletionRequests` collection, with `sourceApp: "admin_assisted"`, a server timestamp and actor, a digest binding all intake evidence, and a transactional `auditLogs` entry.

Returns:

```json
{
  "requestId": "assisted_...",
  "status": "pending_assisted_verification",
  "sourceApp": "admin_assisted",
  "intakeDigest": "64-character-sha256",
  "idempotent": false
}
```

Pending intake has no verification-completion marker or retry queue entry. Neither coordinator calls, reassessment nor financial handover may promote it to deletion.
Resident status lookup preserves the pending verification state without describing an unverified intake as automatic financial processing.

## 2. Confirm saved evidence and consent

Callable: `verifyAdminAssistedDeletionRequest`

```json
{
  "requestId": "assisted_...",
  "intakeDigest": "the-digest-returned-by-create-or-the-scoped-Admin-list",
  "identityConfirmed": true,
  "consentConfirmed": true
}
```

The server rechecks the Admin, current target profile, community, immutable digest, and pending status. The verifier can be the initiating Admin or another currently authorized Community Admin. It records the verifier UID and server time, identity confirmation, consent confirmation, and matching evidence provenance, plus a second transactional audit entry. It does not collect Resident OTPs or claim that the Admin is the Resident.

Returns `verificationStatus: "verified"`, `status: "pending_review"`, and `processingStatus: "queued"`. Verification queues the existing retry worker; it does **not** mean that deletion completed. The current worker runs every four hours, and the existing authorized `reassessAccountDeletionRequest` action can request an earlier trusted attempt.

## Existing processing and audit

Verified assisted requests reuse the existing eligibility assessment, financial settlement and request-bound handover, retention/legal controls, assignment release, durable coordinator, recovery worker, and Auth-last deletion. No financial waiver is accepted by either new callable. Unit reassignment and shared-occupant protections remain in the existing cleanup implementation.

`listCommunityAccountDeletionRequests` includes pending/verified assisted requests and their intake, digest and verification metadata for authorized Admins. Existing status/review and completion records retain the final outcome, verification provenance and immutable audit entries according to the current deletion retention behavior.

Repeated intake with the same evidence returns the same request. Repeated verification never changes the original verifier or requeues a completed request. Duplicate intake after completed deletion returns the retained completed request. Different evidence cannot overwrite an intake. Existing verified Resident-origin requests are returned for the existing review/reassessment workflow, without changing their origin or creating another intake. Unverified, cross-community or ambiguous existing-request conflicts fail closed for reconciliation; Phase 2A has no evidence-edit, cancellation or takeover API.

Normal Resident submission, recent-authentication/OTP behavior and client Firestore write denial remain in place. Assisted records are recognized only with complete server-owned provenance; `sourceApp: "admin"` or a bare `verificationCompletedAt` is not sufficient.

Manual verification remains an operational responsibility: the backend enforces authorization, a recorded evidence reference, explicit attestations and auditability; it cannot independently establish whether an external support case/evidence exists or whether an offline identity check was truthful.

## Deployment (not executed)

From `lyvo1`:

```sh
firebase deploy --project hominode-prod --only functions:createAdminAssistedDeletionRequest,functions:verifyAdminAssistedDeletionRequest,functions:submitAccountDeletionRequest,functions:getAccountDeletionRequestStatus,functions:listCommunityAccountDeletionRequests,functions:recordAccountDeletionFinancialReview,functions:reassessAccountDeletionRequest,functions:reviewAccountDeletionEligibility,functions:retryVerifiedAccountDeletions
```

No Firestore rules/index deployment, migration, website update, or Admin/Resident app release is required by this backend phase. Admin UI integration is a later phase.
