# Release 1 final readiness — 2026-10-18

Follow-up checkpoint: [Firebase migration finish and local checkpoint](FIREBASE_MIGRATION_CHECKPOINT.md).
This document records the earlier readiness run; the follow-up records the automatic
apartment date/time correction, approved local commits and clean publication snapshot.

**Recommendation: NO-GO for production deployment or direct root-branch push.**
Local implementation and targeted validation are complete. Credential revocation,
clean-history publication, console/IAM/App Check and device/release acceptance
remain mandatory owner gates. No production operation, customer-file access,
deployment, commit, push, merge, branch change or history rewrite was performed.

## Fixes and cross-app findings

- The two failing storage emulator cases were stale fixture assertions: they
  expected a four-byte JPEG marker after the fixture became a genuine 267-byte
  JPEG. Assertions now use fixture length. Ordering, ownership, generation,
  no-republish, tenant and cleanup assertions remain intact.
- Existing Sharp 0.35.5 decoding was verified on Node 22.23.1/libvips 8.18.7.
  JPEG/PNG/GIF/WebP signatures are checked before native parsing; decoded format
  must match MIME. Malformed/truncated inputs, oversized encoded files, a real
  two-frame GIF and a 50-megapixel header are rejected. The former conditional
  animation test is now unconditional and proves its fixture has two frames.
  New uploads support single-frame images, <=10 MiB and <=40 million pixels.
  Historical animated URL images are unchanged. A decoder edge case that accepted
  PNGs with missing IEND trailer bytes was corrected with an explicit complete
  trailer check and twelve late-truncation regression cases.
- Decoder failure sensitivity is now `warning`, with a 10-second processing
  timeout. Image callable concurrency is one per 512 MiB instance; native
  libvips workers/cache are bounded (one worker, 16 MiB cache). This is image
  decoding/resource validation, not a malware-scanning claim. Native Linux and
  device memory/load validation remain required. Sharp/package-lock changes
  already existed at task start and are preserved, with no dependency upgrade.
- Admin's existing complaint attachment action previously displayed a dummy
  file/download placeholder. It now streams the authorized complaint and renders
  its ordered private image references using the existing cache/read widget;
  legacy HTTP images retain their network reader. It does not invent attachment
  names/sizes or claim a download occurred. Missing/denied reads fail closed.
  Token errors and tenant/session changes clear visible private images.
- Admin's client read helper now permits server-authorized readers of Resident
  assets; server role/resource/membership/entitlement checks still decide access.
  The shared client retains owner-only reads by default. Admin decoded images
  are bounded on both dimensions to 1024 while preserving aspect ratio.
- The reported App Check startup exception was rethrown before `runApp`.
  The app now shows a bounded startup/recovery gate, verifies App Check before
  building authenticated screens, and supports retry/forced token refresh.
  Firebase/provider initialization is reused safely on retry. Debug providers
  remain debug-only; release Play Integrity/App Attest/web attestation and
  backend enforcement remain enabled. No token or SDK exception body is shown.
- `phoneNumber` is the canonical Auth/profile field across Functions and the
  active Admin, Resident, Security and Web auth paths. Both registration/claim
  branches now write only that field. Shipping Admin/Resident profile, user-list,
  chat, parking-contact and Marketplace display projections prefer it and retain
  a `phone` display fallback. Existing `phone` DTO/contact keys remain unchanged.
  Authentication never falls back to the legacy alias. Duplicate-account checks
  still inspect historical aliases; no existing documents were migrated.
- The reviewed Essential Community Wall policy was ported as one canonical
  feature flag plus catalogue/test coverage. Essential Events, facility booking
  and Marketplace remain restricted; tenant/identity checks are unchanged.
- A new Resident Web regression test exposed a real missing Events query filter.
  `src/data.ts` now scopes events to `type == event` in the existing shared
  collection; announcements retain their separate discovery path.

The earlier private image contracts cover Admin apartment and Resident profile,
Wall, complaint and Marketplace create/edit/upload/replace/delete/read workflows.
The shipping private-image consumer missing in Admin is now connected. Resident
readers retain Phase 2B scope invalidation and bounded memory behavior. Security
has no shipping network-image/file-upload consumer and receives no new read grant.

Both Web apps' existing facility/event galleries consume their established
Firebase URL shape. Wall/complaint/profile record screens do not consume the
new private-image strings as image sources. No unused Web private-reader adapter
or new image UI was added. Regression tests preserve legacy Cloudinary/Firebase
URL parsing and reject opaque private IDs as network URLs; gallery ordering tests
remain passing. Existing URL galleries/token capabilities were not rewritten or
revoked. The new `private_images` objects never mint public download URLs.

All identified Cloudinary upload/delete entry points remain explicit local
failures or have migrated to Firebase. The unused poster/generic examples retain
those guards. No external upload/deletion fallback was reactivated. Retiring old
installed binaries/presets is an owner operation outside this source change.

## Security, lifecycle and operational boundaries

Callables retain enforced App Check and verified-phone/canonical-profile checks.
Server-read roles, active membership/community, resource ownership and current
entitlements determine attachment/read authorization. Reads recheck current
pointers/authority before and after byte I/O. Rules deny client mutation/read of
private assets and managed journals; staging remains create-only in the current
uploader's authorized namespace. Cross-user/community/role denial, unsupported
MIME/size, unauthorized deletion, revocation, CAS replacement and retry are tested.

Replacement retires old assets only after pointer commit. Cleanup claims exact
canonical generations, protects current attachments, retries failures, and sweeps
expired/unreserved staging without touching legacy URLs or financial evidence.
Resident reservation quota is 30 per UID/15 minutes. Reservations expire in 15
minutes, unbound final assets become reclaimable after the one-hour grace, and
unreserved/recreated staging expires after 24 hours. Each sweep is cursor-bounded
at 100 records/objects, with undeployed 15-minute schedules.

Console/operational checks not established locally:

- Register each emulator's generated debug token manually; verify production
  Android/iOS/web App Check identities/providers and Storage enforcement. Never
  ship a debug provider or disable enforcement to solve the 403.
- Verify private bucket public-access prevention, IAM/ACLs and no broad GCS
  readers; least-privilege runtime identities and scheduler permissions. HTTPS
  callable invoker reachability does not replace Auth/App Check authorization.
- Verify native Linux Sharp packaging, memory/CPU limits, concurrency and peak
  load with synthetic staging images. Confirm the single-frame upload policy.
- Set project budgets, abuse monitoring and appropriate creation/rate limits.
  Callable reservation limits do not limit direct unreserved staging bytes or
  unbounded draft-document creation; these remain abuse-control review gates.
- Agree metadata retention/TTL for drafts, receipts, retired journals and
  profile-avatar redirects. Do not blindly expire active attachment metadata.
  File cleanup is implemented, but no production TTL/retention configuration
  or scheduling has been provisioned or tested.

Core/Rules emulators use synthetic Auth contexts; they do not establish real
App Check token acceptance or IAM. Existing local emulator logs were inspected
without printing tokens or launching an app; the bounded retained log window
no longer contained the reported historical 403/main.dart:51 frame. Source and
mocked startup tests establish recovery behavior, not on-device attestation
success. No installed-device visual acceptance is claimed.

## Exact validation

| Check                                                              | Result                                                                                   |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| Final PNG-only validation (two affected tests)                     | 2 passed, 0 failed, 0 skipped; complete trailer and all twelve truncations verified      |
| Backend image, phone/registration and entitlement contracts        | 80 passed, 0 failed                                                                      |
| Storage/Firestore image + registration emulator contracts          | 36 passed, 0 failed, 0 skipped                                                           |
| Admin startup, attachments, image regressions and phone display    | 48 passed, 0 failed; affected phone projection rechecked after helper wiring             |
| Resident image/viewer/modal and phone display contracts            | 53 passed, 0 failed                                                                      |
| Admin Web image/query/session/App Check configuration tests        | 114 passed, 0 failed                                                                     |
| Resident Web image/query/session/App Check configuration tests     | 103 passed, 0 failed                                                                     |
| Both Web TypeScript checks                                         | Passed                                                                                   |
| Resident Web production build (production query changed)           | Passed                                                                                   |
| Admin Web production build                                         | Prior validated baseline retained; no production Web code changed here                   |
| New/reworked Admin startup/readers/tests scoped analysis (9 files) | Clean                                                                                    |
| All changed Admin Dart files (14 files)                            | 0 errors; 9 existing warnings, 429 existing infos; nonzero exit                          |
| Changed Resident phone/display scope                               | 0 errors/warnings; 292 existing infos; nonzero exit                                      |
| Dart formatting                                                    | 21 changed files pass; one existing noncanonical file retained: `user_data_service.dart` |
| Scoped new/image JavaScript and Web Prettier; JS syntax            | Passed                                                                                   |
| `git diff --check`, all three repos                                | Passed                                                                                   |

Every retained Dart diagnostic is on a source line already present in HEAD;
none was suppressed. `user_data_service.dart` was already noncanonical in HEAD;
only its import and two phone reads changed, preserving unrelated formatting.
Existing full-file JS style in `index.js`, `register_resident.js` and
`subscription_management.js` was retained; edited snippets follow surrounding
style. No unrelated complete application suite was rerun. Logs and machine-readable
checks are in `/tmp/release-1-final-readiness-001/`.

## GitHub reconciliation and publication risks

Remote tips were refreshed read-only with `ls-remote`; cached named branch objects
were reviewed without merging/fetching branch refs or applying old whole files.

| Reviewed change                       | Current resolution                                                                                                                                                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apartment automatic upload timestamps | Old patch targets the replaced Cloudinary uploader. Private commits already use server timestamps; approved manual display date/time metadata remains. Do not import the obsolete uploader patch. |
| Essential Community Wall              | Narrow canonical feature/catalogue change ported; positive/private-image and premium/foreign/revoked denial cases pass. No subscription documents changed.                                        |
| Entitlement contract tests            | Current-scope, canonical Plus, missing-subscription and inactive/pending/wrong-role coverage adapted into a new focused file.                                                                     |
| Admin announcement tests              | Current merged-feed metadata and real tenant/type-filtered listeners tested, rather than copying the obsolete exact Spec assertion.                                                               |
| Resident Events regression            | Test port exposed and fixed the missing type filter.                                                                                                                                              |
| Old Resident Billing V2 guard         | Superseded/conflicting; not merged or ported. No financial behavior changed.                                                                                                                      |

The current root source scan has zero matches for the known exposed Cloudinary
private value. However, **30 of 36 outgoing root commits contain it**, across 26
historical paths. The audited `origin/main` anchor also contained it. Current
source redaction does not revoke the credential or make ancestry safe to publish.
Owner confirmation of revocation remains required; no live secret verification
or rotation was attempted. No credential value was printed or written to reports.

Existing 13 local Release 1 commits, branches, HEADs and indexes are preserved.
The six excluded seed-login scripts/backup images remain untracked and byte-for-
byte unchanged. The proposed checkpoint manifest explicitly excludes them.

## Proposed commits and exact safe push strategy — NOT EXECUTED

`checkpoint-manifest.tsv` assigns every current dirty/untracked file to one
checkpoint group or EXCLUDE, with hashes. It includes earlier Phase 1/2A/2B work;
it is a new proposal, not permission to reuse stale earlier manifests.

Proposed local root groups, applied only after separate approval:

1. Shared Firebase Storage contract/package.
2. Backend private media, lifecycle, phone/entitlement contracts, pinned existing
   Sharp dependency, rules and targeted tests (keep mixed index/rules files whole).
3. Admin readers/upload foundation, complaint attachment recovery, startup gate,
   phone compatibility and tests.
4. Resident private image flows/readers and phone compatibility/tests.
5. Storage/readiness/feature documentation.

Web groups: Admin current announcement/query/legacy-image regression tests;
Resident Events type-filter correction with query/legacy-image regressions.
Checkpoint groups must be validated/released as a whole, not treated as isolated
production releases. No staging command or commit has been executed.

**Root: do not push `production-release-v1`**, even after more cleanup commits.
Do not base a new public branch on current HEAD or the contaminated main anchor.
In a separately approved task, export an explicitly allowlisted, sanitized current
snapshot into a new independent publication repository/checkout with **no parent
history**, excluding Git metadata, ignored/env/credential/generated files and all
six exclusions. Verify every exported file and the complete proposed reachable
history, run relevant checks, then approve its initial clean commit. Preserve this
worktree and its local commits. Coordinate existing remote-history remediation
separately with the owner; a clean new branch does not erase old GitHub exposure.

Only after those checks and explicit publication approval, proposed refspecs are:

- Root, from the independent clean publication checkout:
  `HEAD:refs/heads/release-1-sanitized` to
  `https://github.com/sukumarpm/hominode-app.git` (new branch, no force-push).
- Admin Web: `production-readiness-v1:refs/heads/production-readiness-v1` to
  `https://github.com/sukumarpm/hominode-admin-web.git`. Current audited remote
  `fd505e38d80515abff8521537bb55a3c512697a0`; current local checkpoint is four
  commits ahead, with new test work still uncommitted. Recheck fast-forward first.
- Resident Web: `billing-v2-client:refs/heads/billing-v2-client` to
  `https://github.com/sukumarpm/hominode-resident-web.git`. Current audited remote
  `5065bf6e356f50a699de4139cd29e076ff0832e3`; current local checkpoint is three
  commits ahead, with the new query/test work still uncommitted. Recheck first.

No main-branch update, force-push, reset, clean, existing-history rewrite or
`resident-old` remote publication is part of this proposal.

## P0 acceptance checklist

- [ ] Auth/App Check: real Android/iOS/web attestation, registered debug devices,
      rejected/expired sessions, tenant switching and cross-tenant/role denial using
      synthetic accounts. Confirm approved Home visuals and recovery screens.
- [ ] Billing V2: exact settlement/partial/excess-credit/idempotency and immutable
      receipt totals/reference integrity; missing references remain missing. No
      historical ledger edits as rollback. This task did not modify billing logic.
- [ ] Visitor/Security: persisted QR credential privacy/expiry, no unintended
      token output, authorized approval/arrival/checkout and Security status sync,
      session loss/recovery. No real visitor/notification endpoints were invoked.
- [ ] SOS: opening UI does not send an alert; separately authorized synthetic
      delivery/acknowledgement/retry/recovery exercises. No emergency action here.
- [ ] Storage: all five migrated features plus Admin complaint display, legacy
      URLs, replacement/deletion/interruption, entitlement revocation, cache blanking,
      exact-generation cleanup and expiry under slow/offline conditions. Review abuse
      and retention settings before scheduling cleanup.
- [ ] Release builds: signed Android AAB and iOS archive on approved release
      configurations; Linux Node 22 functions/Sharp artifact; TestFlight/internal
      Android distribution, install/upgrade tests and real-device memory checks.
- [ ] Websites: confirm approved domain/App Check configuration and isolated
      Hosting targets (`hominode_app` Admin, `hominode_prod` Resident) in each Web repo.
      Typecheck/build plus browser acceptance at normal/enlarged text sizes.

## Safe deployment order — proposal only

1. Close credential revocation/history-publication gates, approve the clean
   source checkpoint and complete synthetic staging acceptance. No current
   repository/root history may be published as-is.
2. Verify bucket/runtime IAM, App Check identities/enforcement, secrets required
   by existing Auth/visitor flows, budgets and retention decisions. Produce Linux
   Node 22/Sharp and signed client artifacts; no dependency upgrade is implied.
3. Deploy additive storage readers and attach/draft APIs to staging first, keeping
   upload/commit invocation disabled until compatible consumers are ready. In a
   later approved production rollout, use explicit individual function targets:
   `prepareStorageImageUpload`, `completeStorageImageUpload`, `readStorageImage`,
   `saveApartmentImage`, `deleteApartmentImage`, `createResidentImageDraft`,
   `commitResidentImages`. Do not run a broad root Firebase deployment.
4. Deploy matching private Storage/Firestore Rules before enabling private
   publication. Verify real Auth/App Check and denied direct/public access.
   Preserve existing financial/visitor/SOS rules and legacy URL delivery.
5. Distribute compatible Admin/Resident readers via TestFlight/internal Android;
   verify installed and upgrading clients. Retire/gate incompatible older clients
   before new private references or canonical-only user documents are produced.
6. Enable new upload/commit invocation after rules/readers pass. Deploy the
   canonical phone writer and reviewed entitlement resolver changes only with
   compatible clients; do not blindly reseed subscription documents.
7. Enable `cleanupApartmentImages` and `cleanupResidentImages` schedules only
   after prefix/age/IAM/retention/backlog review and synthetic lifecycle checks.
8. Publish Web artifacts separately from their own workspaces and explicit
   Hosting targets. Verify browser flows and monitor denied/failed operations.
   Root Hosting aliases overlap Web sites; avoid root/mixed Hosting deploys.

Rollback pauses new uploads/attachments (and cleanup if integrity is uncertain),
keeps authorized read/backward-compatible metadata support, and restores only
compatible tested code. Never reactivate Cloudinary fallback, roll readers back
past private-reference support, mutate financial history, or delete/transfer
customer assets as rollback. No step above has been executed.

## Exact files changed in this request

### lyvo1

- `docs/subscription-feature-catalogue.md`
- `functions/src/index.js`
- `functions/src/register_resident.js`
- `functions/src/storage_images.js`
- `functions/src/subscription_management.js`
- `functions/test/phoneSchema.unit.test.js`
- `functions/test/registerResident.emulator.test.js`
- `functions/test/releaseEntitlementContracts.unit.test.js`
- `functions/test/residentImages.unit.test.js`
- `functions/test/storageImages.emulator.test.js`
- `functions/test/storageImages.unit.test.js`
- `hominode-admin/admin_app/lib/main.dart`
- `hominode-admin/admin_app/lib/services/chat_service.dart`
- `hominode-admin/admin_app/lib/services/firebase_image_upload_service.dart`
- `hominode-admin/admin_app/lib/services/parking_service.dart`
- `hominode-admin/admin_app/lib/services/resident_service.dart`
- `hominode-admin/admin_app/lib/services/user_service.dart`
- `hominode-admin/admin_app/lib/utils/resident_phone.dart`
- `hominode-admin/admin_app/lib/widgets/admin_startup_gate.dart`
- `hominode-admin/admin_app/lib/widgets/complaint_attachments.dart`
- `hominode-admin/admin_app/lib/widgets/complaint_detail_modal.dart`
- `hominode-admin/admin_app/lib/widgets/private_apartment_image.dart`
- `hominode-admin/admin_app/test/admin_startup_gate_test.dart`
- `hominode-admin/admin_app/test/complaint_attachments_test.dart`
- `hominode-admin/admin_app/test/resident_phone_schema_test.dart`
- `packages/hominode_storage/lib/src/storage_image_upload.dart`
- `resident_app/lib/profile_screen.dart`
- `resident_app/lib/src/screens/edit_profile_screen.dart`
- `resident_app/lib/src/services/chat_firestore_service.dart`
- `resident_app/lib/src/services/listing_firestore_service.dart`
- `resident_app/lib/src/services/user_data_service.dart`
- `resident_app/lib/src/utils/resident_phone.dart`
- `resident_app/test/resident_phone_schema_test.dart`
- `docs/RELEASE_1_FINAL_READINESS.md`

### hominode-admin-web

- `src/test/data.test.tsx`
- `src/test/release1Queries.test.ts`

### hominode-resident-web

- `src/data.ts`
- `src/test/release1Queries.test.ts`
