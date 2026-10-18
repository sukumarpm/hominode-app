# Resident acceptance blockers 002 — 2026-10-18

## Findings and limits

- The deployed `getCurrentCommunityEntitlement` source (last updated
  2026-10-08 05:33:48 UTC) has `essential.features.communityWall = false`.
  The current local source has `true` for Essential, Plus and Pro. This is a
  confirmed stale deployment, not a reason to override the server on-device.
- The reported “subscription is not configured” text is the separate
  `failed-precondition` response for a missing canonical
  `subscriptions/{resolvedCommunityId}` record. Both deployed and local
  entitlement code use this collection. The caller derives the community from
  the authenticated resident; the app sends no chosen community ID.
- Read-only logs show a `createResidentImageDraft` request returning HTTP 403
  at 2026-10-18 14:03:59 UTC. Its callable verification log at 14:04:01 UTC
  reports both Auth and App Check VALID. This failure is before image staging,
  Storage upload, finalization or listing creation. The old logs do not identify
  which backend authorization check rejected it. A specific test community was
  not supplied, so no production subscription/profile records were queried.
- Marketplace is intentionally unavailable on Essential; Plus and Pro allow it
  subject to an active subscription and resident/resource authorization. Profile
  and complaint image workflows do not require the Marketplace entitlement.
  These restrictions remain unchanged. An eligible-community upload defect has
  not been demonstrated by the available production logs.

## Changes

- The Marketplace create screen delegates draft reservation, image upload and
  atomic attachment to the same form-owned `ListingFirestoreService` and
  `ResidentImageOperations`. Previously the screen uploaded with one adapter
  and the service saved with another; the service-only path created a fresh
  draft on each retry. One adapter now retains draft, finalized assets and
  operation IDs through failures and lost replies. Duplicate concurrent submits
  are rejected. No listing is written before all selected images finalize.
- Moderation precedes image upload. The service snapshots the selected paths;
  no filesystem path is sent as a Firestore image reference.
- Errors report the failed stage and SDK error code in debug builds without
  printing raw exceptions, content, identifiers, tokens or image data.
  Subscription/authorization failures get actionable messages instead of a
  generic image-upload error. Missing draft subscription configuration is now
  distinguished server-side without authorizing the request. Existing private
  read/commit denial behavior is unchanged.
- Community Wall missing-configuration feedback now offers Retry, keeping access
  closed until a new server verification succeeds. Existing translated text is
  reused. No premium features are inferred from missing/unavailable data.
- UI layout, Rules, App Check and billing behavior are unchanged.

## Validation

- Resident focused tests: **37 passed, 0 failed** across
  `marketplace_listing_submission_test.dart`, `resident_image_operations_test.dart`,
  `community_wall_entitlement_policy_test.dart`, and
  `community_verification_feedback_test.dart`.
- Backend affected tests: **43 passed, 0 failed** across resident-image,
  Release 1 entitlement-contract and subscription-management unit tests, with
  `--test-skip-pattern='apartment bytes'` excluding one unrelated existing test.
  The initial unfiltered run was **43 passed, 1 failed**. The excluded
  apartment-reader test expects same-building denial; it also fails against
  unchanged HEAD source in isolation (**0 passed, 1 failed**). Earlier approved
  community-wide gallery behavior makes that assertion stale. It is untouched.
- Local Firestore/Storage emulator: **7 passed, 0 failed**, selected with
  `--test-name-pattern='[Mm]arketplace|Wall|subscription|draft'` from
  `storageImages.emulator.test.js`, minimal Rules, project
  `demo-hominode-storage-images`. Includes real SDK draft upload/finalization,
  atomic publication, cross-user/community denial, Essential Wall access,
  premium denial and missing-subscription fail-closed checks.
- Scoped Flutter analysis: **0 errors, 0 warnings, 64 existing informational
  diagnostics**; default analyzer exit is 1 because infos are reported.
- Dart formatting, changed JavaScript block formatting, Functions syntax checks
  and `git diff --check` pass. No unrelated full suites were run.

## Required deployment/configuration and manual retest

No deployment or live record changes were made. A Resident app update and the
following two callable updates are needed; no Rules update is required by this
task. Run only after separate deployment authorization, from the repository root:

```sh
functions/node_modules/.bin/firebase deploy \
  --project hominode-prod \
  --config firebase.storage-minimal.json \
  --only functions:getCurrentCommunityEntitlement,functions:createResidentImageDraft
```

Both retain `asia-southeast1` and enforced App Check. Do not deploy cleanup
schedulers or unrelated Functions. Deploying the entitlement reader does not
create a missing subscription record; an authorized owner must verify/configure
the named test community through the existing subscription-management workflow.
Do not infer a plan from a community label or grant Plus/Pro to make a test pass.

Manual acceptance, after deploying the two callables and installing this app:

1. Use the registered Android App Check debug client and an approved resident of
   a test community whose canonical subscription is known. Verify Essential Wall
   opens; confirm Marketplace, bookings and Events remain restricted on Essential.
2. On an existing eligible Plus/Pro test community, create a listing with a JPEG
   or PNG. Verify one listing, ordered private images, authorized display, and
   retained listing contents after reopening it.
3. Interrupt the image upload, retry in the same form, and verify no partial
   listing. Interrupt the save reply, retry without editing the form, and verify
   one listing and no duplicate attachment/upload. Do not simulate failures by
   weakening production Rules or attestation.
4. Test missing/unavailable subscription responses with local emulators/mocks:
   verify no draft/image/listing is created, Wall remains closed, configuration
   guidance appears, and Retry succeeds after the fixture is restored.
5. Repeat cross-community and foreign-owner denial using synthetic emulator
   identities. No customer files or live records are needed.

Actual device acceptance and the failed test community's exact authorization
condition remain unverified. The unrelated pre-existing apartment test is a
separate test-maintenance finding.
