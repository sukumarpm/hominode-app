# Green Wave Residences — proposed Pro demo activation

Prepared 2026-10-18, Asia/Manila. **NOT ACTIVATED. Production writes are not
authorized.** No deployed mutating callable was invoked, and no application
source, Rules, billing logic or production settings were changed.

## Verified production state (read-only)

- Project: `hominode-prod`.
- Exact community document: `communities/GREEN-WAVE`.
- Name: `Green Wave Residences`; slug and websitePath: `green-wave`;
  `isActive: true`. Created 2026-10-06 00:29:13 UTC.
- `subscriptions/GREEN-WAVE`: absent.
- Query of `subscriptions` where `communityId == "GREEN-WAVE"`: zero matching
  records, including other document IDs or expired/inactive records.
- `subscriptionEvents` for this community: zero matching events.
- `billingSchedules` for this community: zero matching schedules.
- No assumption was made that “green-view” identifies another community. The
  proposed operation uses only the verified canonical `GREEN-WAVE` identity.

Community creation does not create subscriptions. Subscription provisioning is
a separate Super Admin action. The current configuration step is missing; the
available state/events do not establish whether a record was ever deleted or
an earlier provisioning attempt failed.

## Existing authorized workflow

Admin Flutter already exposes `SuperAdminSubscriptionCard` on the selected
community's details screen in `super_admin_communities_screen.dart`.
`SubscriptionService.createSubscription` calls `createCommunitySubscription`
in `asia-southeast1`. The deployed creator is ACTIVE and supports Pro, an
explicit end date, a server-generated start date and an audit note.

The callable enforces App Check and phone authentication; its core requires an
active Super Admin profile. Ordinary community Admins cannot create or upgrade
subscriptions. Use an existing properly authenticated Super Admin app session;
do not impersonate a user or bypass the callable using privileged Firestore
writes.

Existing change-plan and status Functions are available, but are not needed
for the currently absent record. They must not be invoked automatically if
the state changes before approval. The deployed creator rejects existing
records with `already-exists` and atomically creates the subscription plus its
audit event. No subscription trigger was found in the local Functions exports;
the inspected deployed creation routine writes only these two collections.

## Exact proposed operation — only after explicit approval

Proposed validity: active from the server's activation time through
**2026-11-17 23:59:59.999 Asia/Manila** (2026-11-17 15:59:59.999 UTC), about a
30-day demo if approved on October 18. If approval is delayed, obtain agreement
on the end date before proceeding. Freeze the approved end timestamp across
all retries; do not silently extend it.

Proposed input to the existing authorized `createCommunitySubscription` callable:

```json
{
  "communityId": "GREEN-WAVE",
  "planId": "pro",
  "status": "active",
  "endsAtMs": 1794931199999,
  "notes": "Approved Green Wave Residences client demo; Pro access through 2026-11-17 Asia/Manila; no subscription charge or renewal requested."
}
```

`startsAtMs` is intentionally omitted, matching the existing Admin UI; the
backend uses `Timestamp.now()`. The UI date picker uses device-local time:
confirm Asia/Manila when choosing November 17, or supply the exact timestamp
above through the existing authorized `SubscriptionService`.

Idempotent procedure:

1. Re-read `communities/GREEN-WAVE`; require the verified name, slug and active
   state. Stop if identity/state differs. Recheck for noncanonical duplicate
   subscription records assigned to this community.
2. Read the subscription through the authorized `getCommunitySubscription`
   action. If absent, submit the exact approved payload once. Do not change
   any other community or seed all plans/communities.
3. If the request times out or returns `already-exists`, re-read rather than
   changing the plan/status or sending a new end date. An existing matching
   active Pro subscription within the approved validity window is a no-op:
   verify its timestamps and corresponding creation event. If its terms,
   identity or audit provenance differ, stop and report for review.
4. Re-read the canonical subscription and its audit event. Confirm only the
   intended subscription/event were added. Do not run billing generation,
   payment, settlement, seed or migration Functions.
5. In an approved GREEN-WAVE Resident session, refresh/reopen the app and call
   `getCurrentCommunityEntitlement` normally with no community override.
   Expect `communityId: GREEN-WAVE`, `planId: pro`, `status: active` and current
   Pro features. Check Community Wall and Marketplace navigation without
   running financial transactions. Verify existing authorization remains in
   force and an unrelated community retains its prior entitlements.

The creator is create-only, not a silent upsert. Existing expired, suspended,
inactive or different-plan records require separate review; this proposal
does not authorize overwriting them.

## Canonical persisted fields

Collection/document: `subscriptions/GREEN-WAVE`.

| Field | Value/source |
| --- | --- |
| `communityId` | `GREEN-WAVE` |
| `planId` | `pro` |
| `status` | `active` |
| `startsAt` | Backend Firestore Timestamp at activation |
| `endsAt` | Firestore Timestamp from approved `endsAtMs` |
| `schemaVersion` | `1` |
| `createdAt`, `updatedAt` | Server timestamps |
| `createdBy`, `updatedBy` | Verified Super Admin UID |

The backend also creates `subscriptionEvents/{generatedId}` with
`type: subscription_created`, canonical IDs, actor, previous/current summaries,
notes, creation timestamp and schema version. Notes are stored on this audit
event, not as a feature bypass on the subscription. Features and limits are
derived from trusted `PLAN_DEFINITIONS`, not client-written feature maps or
a required `subscriptionPlans/pro` document.

## Billing, expiry and deployment implications

The subscription creation routine has no price/charge/payment input and writes
no bills, payment proofs, financial transactions, settlement records or recurring
schedules. Unit tests enforce this write boundary. Existing hourly recurring
billing acts on separately configured schedules; none were found for GREEN-WAVE.

No automatic renewal is created. At `endsAt`, the normal entitlement policy
denies access even if the stored status still says `active`; no demo bypass or
expiry scheduler is required for entitlement expiry. Pro does not bypass
membership, ownership, resource authorization, App Check or operational
configuration. Pro enables normal financial capabilities: the audit note is
not a payment sandbox, so later billing/payment actions can still create real
records and must not be executed as part of this activation.

**No Functions or Rules deployment is needed to create this Pro subscription
using the existing workflow.** The deployed Pro definition already enables
Community Wall and Marketplace. The previously identified stale Essential
definition and pending Resident acceptance-fix deployments are separate tasks;
this proposal does not deploy them or certify all device flows.

## Focused validation and changed files

```sh
node --test functions/test/demoCommunityProActivation.unit.test.js \
  functions/test/releaseEntitlementContracts.unit.test.js \
  functions/test/subscriptionManagement.unit.test.js
```

Result: **29 passed, 0 failed, 0 skipped**, including nine new isolated demo
activation tests. Coverage includes authorized creation, actual Admin payload
shape, canonical Pro resolution, all Pro feature flags, normal start/expiry
boundaries, another community remaining Essential, ordinary-role denial,
duplicate/concurrent creation protection, existing subscription preservation,
missing-community/invalid-expiry rejection, and no financial or unrelated writes.

Tests use synthetic in-memory records, with no Admin SDK app initialization,
production credentials, network calls or customer data. JavaScript syntax and
formatting checks and `git diff --check` pass. No unrelated suites were run.

Local additions only:

- `functions/test/demoCommunityProActivation.unit.test.js`
- `docs/GREEN_WAVE_PRO_DEMO_ACTIVATION_PLAN.md`

No commits, deployments, pushes, production writes or subscription-mutating
callables were executed. All six previously excluded local files are preserved.
Await explicit approval before activating this verified demo community.
