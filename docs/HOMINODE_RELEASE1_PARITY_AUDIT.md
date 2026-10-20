# Hominode Release 1 — Phase C parity audit

Date: **2026-10-20, Asia/Manila**. Decision: **hold public release; controlled acceptance can continue**.
Audit only: no application, Rules, Functions, production records or configuration changed.

## Scope and evidence

Targeted inspection reused `FIREBASE_STORAGE_PHASE_1.md`, `FIREBASE_STORAGE_PHASE_2A.md`,
`FIREBASE_STORAGE_PHASE_2B.md`, `FIREBASE_MIGRATION_CHECKPOINT.md`,
`RELEASE_1_FINAL_READINESS.md` and recent acceptance commits. Older documents describe
historical gates; the production observations below supersede their deployment claims.

Path prefixes: **M** = this root repository; **AW** =
`/Users/sukumarmuthiah/Documents/hominode-admin-web`; **RW** =
`/Users/sukumarmuthiah/Documents/hominode-resident-web`. Paths below are relative to
those roots. Findings distinguish confirmed source/deployment facts from device,
browser, IAM or production-behavior checks still required. No customer records,
legacy images, secrets or App Check debug tokens were retrieved.

Read-only production observations:

- Project `hominode-prod`; bucket `hominode-prod.firebasestorage.app`, `US-EAST1`.
- Live Firestore Rules, updated **2026-10-19 13:14:01 UTC**, exactly match
  `deployment/storage-minimal/firestore.rules`, including nested comment authorization.
- Live Storage Rules, updated **2026-10-18 11:13:49 UTC**, exactly match
  `deployment/storage-minimal/storage.rules`. Do not deploy the broader root Rules
  indiscriminately: the minimal variant intentionally retains unrelated production behavior.
- All seven private-image callables are ACTIVE in `asia-southeast1`, Node.js 22:
  `prepareStorageImageUpload`, `completeStorageImageUpload`, `readStorageImage`,
  `saveApartmentImage`, `deleteApartmentImage`, `createResidentImageDraft`,
  `commitResidentImages`. Client names/regions match.
- Complete paginated Functions inventory checked: 100 Functions, one page, no continuation.
  Missing exports identified below are deployment gaps, not guesses from update dates.
- Local Linux evidence is now successful: Cloud Build
  `300b4abf-7ac0-4937-9df1-5c90969e8a75` completed on October 18;
  Linux Node 22 + Sharp 0.35.5 installed, loaded and decoded synthetic JPEG/PNG.
  Native compatibility is **not an outstanding blocker**. Load/device acceptance remains separate.
- Evidence/logs retained locally in ignored `.firebase/release1-parity-audit/`;
  prior Linux evidence is in `.firebase/storage-deploy-final-gate/`.

## A. Production blockers before public release / TestFlight acceptance

### F01 — P0: Resident paid-receipt callable is absent

- **Affected/source:** M `functions/src/index.js`, `functions/src/billing_v2_receipt.js`,
  `resident_app/lib/src/services/resident_billing_v2_receipt_service.dart`,
  `resident_app/lib/receipt_screen.dart`; RW `src/residentBillingV2Receipt.ts`, `src/pages.tsx`.
- **Parity/contract:** both Resident clients invoke `getResidentBillingV2Receipt` for
  canonical paid Billing V2 receipts; production has no such callable. This is a
  **confirmed deployment gap**. Existing legacy receipt presentation is a separate path;
  it does not implement this missing endpoint. No settlement corruption was demonstrated.
- **Smallest action:** review and selectively deploy this existing approved callable,
  then test a synthetic paid receipt, foreign resident denial and missing reference.
  Deployment: this Function only, `asia-southeast1`; clients already contain readers.
  **Implementation:** manual scoped deployment/acceptance is practical; Codex is optional.

### F02 — P0: deployed Essential entitlement contradicts approved policy

- **Affected/source:** M `functions/src/subscription_management.js`, `functions/src/index.js`,
  `packages/hominode_entitlements/lib/src/subscription_entitlement.dart`,
  `resident_app/lib/src/services/community_wall_entitlement_policy.dart`;
  AW `src/subscription.ts`; RW `src/eventsEntitlement.ts`.
- **Parity/contract:** deployed `getCurrentCommunityEntitlement` is the October 8
  version with **Essential `communityWall: false`**; local approved source says true
  for Essential/Plus/Pro. The old response blocks the mobile Wall even with valid
  Auth/App Check and a valid Essential subscription. Pro is not implicated by this flag.
  Web currently exposes fewer Wall interactions, not an alternative entitlement source.
  **Confirmed by deployed-source comparison**, not by editing subscriptions.
- **Smallest action:** selectively update `getCurrentCommunityEntitlement`; verify all
  three tiers and inactive/missing subscription denial. Preserve Essential restrictions
  on Marketplace, Events and booking. No subscription writes or global bypass.
  Deployment: this Function only; no necessary client code change for the flag.
  **Implementation:** manual deployment is practical; Codex optional for regression review.

### F03 — P0 verification gate: release attestation and private-bucket permissions

- **Affected/source:** M `resident_app/lib/main.dart`, `hominode-admin/admin_app/lib/main.dart`,
  `security_app/lib/main.dart`, `deployment/storage-minimal/storage.rules`,
  `functions/src/index.js`; AW/RW `src/firebase.ts`.
- **Parity/contract:** mobile release uses Play Integrity/App Attest; debug builds use
  debug providers. Web uses reCAPTCHA Enterprise, with debug gated by Vite DEV.
  The seven image callables enforce App Check. Successful Resident emulator acceptance
  does not certify signed iOS, Android release or either hosted web identity.
- **Confirmed configuration:** Storage App Check is **UNENFORCED**; bucket uniform
  access is disabled and public-access prevention is **inherited**, whose effective
  organization policy was not established. This is **not evidence of public objects**
  or a reason to block controlled image testing. Fine-grained ACL/IAM and release-client
  token acceptance still require verification. Earlier gate evidence records a broad
  runtime Editor grant; least privilege remains a hardening action, not a new invocation failure.
- **Smallest action:** owner verifies signed-client registrations/domains, effective
  bucket IAM/ACL/public-access prevention and synthetic private-read denial. Plan
  Storage enforcement only after all affected clients pass; do not enable blindly.
  Rollout: Console/IAM actions and signed builds, only with separate approval.
  **Implementation:** Console/device work is manual; Codex cannot replace acceptance.

### F04 — P0 publication gate: root ancestry remains unsafe to publish

- **Affected/source:** M Git history and `docs/RELEASE_1_FINAL_READINESS.md`,
  `docs/FIREBASE_MIGRATION_CHECKPOINT.md`; earlier clean snapshot procedure referenced there.
- **Parity/contract:** mobile/backend share the contaminated root ancestry; the web
  repositories have independent histories. Prior credential investigation established
  historical private-credential exposure. Source redaction and newer local commits do
  not remove ancestry or prove revocation. No secret value was inspected or reproduced here.
- **Smallest action:** owner confirms credential revocation; regenerate/verify an
  independent sanitized snapshot containing the **latest** approved root commits before
  publication. Do not push `production-release-v1` or reuse an older snapshot blindly.
  No runtime deployment is needed for publication itself.
  **Implementation:** manual Git/security-owner procedure is practical; Codex optional.

## B. Missing or inconsistent parity

### F05 — P1: Community Wall like/unlike is incompatible with owner-only updates

- **Affected/source:** M `resident_app/lib/src/services/post_firestore_service.dart`
  (`likePost`, `unlikePost`, building-only feed queries), `firestore.rules` and
  `deployment/storage-minimal/firestore.rules` (`/posts/{postId}`).
- **Parity/contract:** mobile writes `likes`, `likedBy`, `updatedAt` directly; the live
  update rule permits content owners/Admins or the narrowly bound comment-counter
  transaction. It has no peer-like permission. A resident liking somebody else's
  post is therefore **denied by the current contract**. Web does not implement
  equivalent like/comment controls. The recent comment fix does not authorize likes.
- **Smallest action:** add an idempotent, authenticated own-UID like/unlike contract
  with exact counter/array diffs, community checks and focused emulator tests. Do not
  grant generic peer post updates. Separately test mobile feed queries, which filter
  only `buildingId`, against community-aware Rules; query compatibility is **unverified**,
  not a demonstrated cross-tenant exposure. Preserve intentional legacy-read compatibility.
  Rollout: Resident rebuild + minimal Firestore Rules update, if that design is approved.
  **Implementation:** a developer can implement manually; Codex optional, security tests essential.

### F06 — P1: notification inboxes/read state diverge; payment notification rollout incomplete

- **Affected/source:** M `resident_app/lib/dashboard_screen.dart`,
  `resident_app/lib/src/screens/notifications_screen.dart`,
  `resident_app/lib/src/services/notice_firestore_service.dart`,
  `functions/src/payment_v2_notifications.js`, `functions/src/payment_v2.js`,
  `functions/src/index.js`; AW/RW `src/Shell.tsx`, `src/data.ts`, `src/actions.ts`.
- **Parity/contract:** mobile Home bell/Notifications uses notice discovery and
  `notices/{id}/readBy/{uid}`; web bells use recipient/community/role/app-scoped
  `notifications` and `isRead/readAt`. Reading one is not reading the other. This
  **confirmed source difference** must not be called synchronized notification parity.
- Production also lacks `dispatchBillingV2PaymentNotification` and
  `notifyResidentOfSubmittedV2PaymentProof`; deployed payment writers predate their
  atomic notification-event writes. Deploying triggers alone would not complete it.
- **Smallest action:** first agree a canonical notification inbox contract and keep
  announcement read state distinct; then wire existing clients/read routing to it.
  Review payment event writers and the two triggers as a separate financial deployment
  task; do not deploy unrelated billing exports. The Storage-finalize trigger belongs
  in `us-east1`; Firestore dispatch stays `asia-southeast1`.
  Rollout: scoped backend update plus affected client rebuilds/web hosting.
  **Implementation:** manual development is practical; Codex optional for contract tests.

### F07 — P1: web has no private-image viewer for several existing record screens

- **Affected/source:** M `resident_app/lib/src/services/resident_private_images.dart`,
  `resident_app/lib/src/services/apartment_images_service.dart`,
  `hominode-admin/admin_app/lib/widgets/complaint_attachments.dart`;
  AW/RW `src/pages.tsx`, `src/data.ts` (`safeUrl`), `src/models.ts`.
- **Parity/contract:** mobile renders `imageAsset` / `managedImageAssets` and
  `hominode-image:<assetId>` through authorized reads. Web complaint details,
  profile/avatar and apartment information currently show text/initials rather
  than those private photos. **Confirmed missing presentation**, not evidence that
  opaque IDs are being fetched as URLs or that data is publicly exposed.
- **Smallest action:** add a session-scoped, bounded authorized reader only to
  already-existing web screens whose authorized users need these attachments,
  starting with Admin complaint evidence. Use server read authorization; do not
  convert private references to permanent public tokens or add unused viewers.
  Rollout: relevant web hosting; backend authorization changes only if a specific
  valid audience is proven unsupported.
  **Implementation:** manual web development practical; Codex optional.

### F08 — P1 scope decision: Marketplace and full Wall interaction are mobile-only today

- **Affected/source:** M `resident_app/lib/src/screens/marketplace_screen.dart`,
  `marketplace_create_listing_screen.dart`, `marketplace_edit_listing_screen.dart`,
  `marketplace_your_product_detail_screen.dart`, `resident_app/lib/community_wall_screen.dart`;
  AW/RW `src/navigation.ts`, `src/App.tsx`, `src/pages.tsx`, `src/actions.ts`.
- **Parity/contract:** mobile supports listing create/edit/sold/delete, ordered
  multi-image detail display and Wall post/comment interaction. Neither website
  supplies Marketplace routes; the web Community page is community information,
  not the mobile Wall. **Confirmed capability gap; not automatically a release bug.**
- **Smallest action:** owner records the Release 1 web capability scope. If required,
  implement each workflow independently against `marketplaces`, `posts` and existing
  image callables, preserving roles/entitlements. Do not duplicate mobile mutation
  logic through permissive direct writes. If intentionally mobile-only, document
  that limitation rather than expanding this release.
  Rollout: none for an accepted scope decision; web hosting for future implementation.
  **Implementation:** product decision/manual implementation practical; Codex not required.

### F09 — P1 privacy/lifecycle decision: web event/facility images use URL-bearing galleries

- **Affected/source:** AW `src/actions.ts` (`uploadEventImages`, `uploadFacilityImages`,
  `removeEventImage`, `deleteFacilityImage`), `src/models.ts`, `src/pages.tsx`;
  RW `src/pages.tsx`; M `deployment/storage-minimal/storage.rules`.
- **Parity/contract:** these existing Firebase workflows write
  `event_images/{communityId}/{eventId}/...` and `facility_images/{communityId}/{facilityId}/...`,
  then store ordered `{url,storagePath,name}` galleries and primary `imageUrl`.
  They use `getDownloadURL`, unlike the private apartment/Resident foundation.
  This is Firebase-only and backward compatible, but a download-token URL is a
  bearer capability, not the private callable delivery model. **Confirmed architecture;
  no unauthorized access or public-media policy violation was demonstrated.**
- **Smallest action:** owner explicitly classifies these media as URL-shareable or
  tenant-private. If private, plan a scoped upload/read contract migration with
  existing URL display preserved. Review deletion/save failure recovery before
  changing lifecycle ordering. This becomes a P0 privacy blocker only if private
  handling is required by the product/privacy contract.
  Rollout: conditional Rules/Functions and web/mobile consumers; no changes for
  intentionally shareable historical media.
  **Implementation:** owner decision and manual development practical; Codex optional.

### F10 — P1 public-scale gate: private-image cleanup schedules are not deployed

- **Affected/source:** M `functions/src/index.js`, `functions/src/apartment_images.js`,
  `functions/src/resident_images.js`, `functions/src/storage_images.js`.
- **Parity/contract:** mobile uses staging/finalization, atomic attachment and deferred
  retirement; no caller should delete a replacement's old bytes prematurely. Both
  `cleanupApartmentImages` and `cleanupResidentImages` are **absent in production**,
  intentionally excluded from controlled rollout. Interrupted uploads/retired assets
  therefore lack the intended scheduled reclamation. Web URL galleries use another lifecycle.
- **Smallest action:** approve retention, cleanup IAM, monitoring and a synthetic-only
  cleanup acceptance run before enabling either existing schedule. Review staging abuse
  limits/budgets and metadata retention separately; do not blindly TTL active assets.
  Rollout: these schedules/configuration only after approval, not necessary for today's
  controlled acceptance and not authorized by this audit.
  **Implementation:** operational owner/manual deployment practical; Codex optional for tests.

### F11 — P2: older diagnostics and validation artifacts need explicit reconciliation

- **Affected/source:** M `functions/src/resident_images.js`,
  `functions/test/residentImages.unit.test.js:264`, `docs/RESIDENT_ACCEPTANCE_BLOCKERS_002.md`.
- **Parity/contract:** deployed image drafts still return generic permission denial
  for missing subscription configuration; local source distinguishes it with
  `failed-precondition`. This is a **diagnostic-only deployment difference**, not
  proof that valid Pro uploads are broken. Read/commit exports contain an older
  shared module, but the inspected diff is in draft error classification.
- A previously reproduced test still expects same-building-only apartment reads;
  approved community-wide galleries permit other buildings in the same community.
  It remains a **known stale test expectation**, not a reason to tighten gallery access.
- **Smallest action:** optionally update `createResidentImageDraft` for the approved
  error distinction; separately update only the stale positive fixture while
  retaining foreign-community/inactive/unverified denial. Do not redeploy all seven
  callables just because a bundled shared module differs byte-for-byte.
  Rollout: optional single callable; none for test maintenance.
  **Implementation:** manual correction practical; Codex optional. No test suppressed here.

### F12 — P2: artwork, gallery UX and signed/browser acceptance remain incomplete

- **Affected/source:** M `resident_app/lib/src/widgets/community_image_slideshow.dart`,
  `resident_app/lib/dashboard_screen.dart`, `resident_app/lib/src/services/apartment_images_service.dart`,
  `resident_app/lib/src/models/event_model.dart`, `hominode-admin/admin_app/lib/events_announcements_screen.dart`,
  `security_app/lib/screens/login_screen.dart`, all three `pubspec.yaml` and `ios/Podfile`;
  AW/RW `src/pages.tsx`, `src/Dashboard.tsx`, `public/images/logo.png`, `firebase.json`, `.firebaserc`.
- **Parity/contract:** Resident Home rotates authorized community apartment images;
  web banners remain static. Marketplace detail supports multiple images on mobile;
  web has facility galleries, while Admin mobile Events reads the primary image
  and Admin Web can store multiple event images. These are **confirmed UX differences**,
  not authorization defects or a mandate for a redesign.
- Admin/Resident login artwork now uses alpha-capable `Admin_New1.png` /
  `Resident_New1.png`; both web logos have alpha. Security login still uses an
  opaque `Security_New.png`. Lack of alpha is confirmed; whether its visible
  background violates branding needs visual approval. Launcher icons may
  intentionally be opaque; role-specific symbols are not parity defects.
- **Smallest action:** manual normal/enlarged-text and Chrome/Safari/iOS/Android
  acceptance of existing screens; obtain approved Security transparent artwork if
  needed. Do not regenerate excluded backup images or add a web slideshow merely
  for symmetry. Build/version/signing acceptance remains unverified in this audit.
  Rollout: asset/client rebuild only for an approved change; web hosting only if changed.
  **Implementation:** manual design/device acceptance practical; Codex not necessary.

## C. Existing functionality confirmed consistent

These are code/contract confirmations, not a claim of complete production acceptance.

| Area                     | Confirmed evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Project/configuration    | All three native Android/iOS configurations point to `hominode-prod`; role bundle IDs are distinct. Both web Firebase initializers use the correct project/bucket and `asia-southeast1`.                                                                                                                                                                                                                                                                                                                     |
| Private upload lifecycle | Shared `packages/hominode_storage/lib/src/storage_image_upload.dart`, Resident `firebase_image_upload_service.dart` / `resident_image_operations.dart`, Admin `cloudinary_apartment_images_service.dart` use Firebase staging/finalization/attachment. The Admin compatibility class name is not an external upload.                                                                                                                                                                                         |
| Cloudinary               | Targeted shipping-service/import inspection found no active external upload/delete transport. Resident `cloudinary_service.dart` methods fail locally; remaining generic/example helpers lead to that guard. Legacy read-only URLs remain intentionally supported and were not fetched.                                                                                                                                                                                                                      |
| Private reads            | Live `readStorageImage` apartment module matches local source; private staging/final prefixes are not public download URLs. Resident cache is bounded to three entries / 20 MiB with session/community invalidation; revocation/cache behavior still needs signed-device acceptance.                                                                                                                                                                                                                         |
| Comments                 | `posts/{postId}/comments/{commentId}` payload includes community/author/server time and an atomic parent counter update. Live Rules match commit `21e342f`; prior 22 Rules tests passed. No further comment Rules deployment is indicated.                                                                                                                                                                                                                                                                   |
| Events/announcements     | Mobile services and both web query specs use `events_announcements`; web event queries include `type == event`. Resident announcement discovery is separate, preserving eligible Essential announcement access when Events are restricted.                                                                                                                                                                                                                                                                   |
| Visitors/Security        | Resident mobile/web invoke `createVisitorInvitation` / `getVisitorCredentials`; Security invokes `verifyVisitorCredential`, `denyVisitorEntry`, `checkoutVisitors`. Credential creation/read/verification sources match production. Crucially, the actual deployed `listSecurityVisitors` module matches the current denial/history fix; older copies bundled in other exports are not evidence of a broken list. Admin Web sets both `status` and `isApproved` on approval/rejection.                       |
| Billing baseline         | Existing clients separate legacy and schema-2 records, minor-unit amounts and `paymentProofsV2`. `preparePaymentProofV2`, `verifyPaymentProofV2`, `recordOfflinePaymentV2` are deployed; the billing-statement module matches local. Flexible Resident amount creation remains disabled by default. Deployed writers lack later flexible-amount/notification additions: do not claim those paths work or enable them without a separate contract rollout. Legacy exact-balance behavior is not shown broken. |
| Resident UI fixes        | Latest root ancestry contains profile optional-email/App Check separation, gallery/banner, notification stream ownership, comment atomicity and Marketplace button/tab refinements. No pending tracked application changes at audit start.                                                                                                                                                                                                                                                                   |
| Region/native packaging  | Private callables stay `asia-southeast1`; the local payment-receipt Storage trigger is correctly configured for bucket region `us-east1`. Native Linux Sharp verification succeeded; earlier reports listing it as unavailable are historical.                                                                                                                                                                                                                                                               |

## D. Release branches, commits and deployment gaps

| Repository | Local branch / audited HEAD                                            | Remote/publication status                                                                                                                                                                                                        |
| ---------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M          | `production-release-v1` / `db0609b80cb81bfba9d2215cd75849c592a1c453`   | No configured upstream; no matching branch returned by fresh `ls-remote`. `origin/main` is `ab186c3a926c9dd1720b70473f9b605f6e19f512`; local cached comparison has 52 outgoing commits. Contaminated history must not be pushed. |
| AW         | `production-readiness-v1` / `2bf3e5319c26bed45097bbcd491de70a1909d49b` | Fresh remote tip `fd505e38d80515abff8521537bb55a3c512697a0`; cached upstream comparison 0 behind / 5 ahead. Existing tracking branch is the normal fast-forward target after approval.                                           |
| RW         | `billing-v2-client` / `a6a3fa054b6111d57586c7dd2f92ad69a9ff4dca`       | Fresh remote tip `5065bf6e356f50a699de4139cd29e076ff0832e3`; cached upstream comparison 0 behind / 4 ahead. Existing tracking branch is the normal fast-forward target after approval.                                           |

- Root fixes present: `08a0d4a` listing retry/entitlement feedback; `1d19fd3`
  optional email/App Check separation; `117aef4` approved artwork; `f096ce3` gallery;
  `e2bf73d` notification lifecycle; `21e342f` comments; `db0609b` Marketplace UI.
- Required production gaps: F01/F02; payment-notification backend rollout and cleanup
  are F06/F10, separately scoped. The comment/gallery Rules are already current.
- Hosted web versions and installed app binary revisions were not established from
  these Git tips; direct local deployments can occur without Git pushes.
- Hosting targets remain distinct: AW `hominode_app` -> `hominode-app-prod`;
  RW `hominode_prod` -> `hominode-prod`, with tenant-route preparation in
  `scripts/prepare-hosting.mjs`. Do not deploy bare Hosting targets from the wrong workspace.
- Release configuration: Admin `1.0.0+5`, minimum iOS **15.5**; Resident/Security
  `1.0.0+4`, minimum iOS **15.0**. All have configured role-specific bundle IDs/signing
  team. These differing SDK/minimum versions are not themselves a parity bug;
  archive/provisioning/App Store build-number acceptance remains required.
- Both web worktrees were clean. Root had nine pre-existing untracked paths:
  two planning/diagnosis documents, one demo activation test, two seed-login scripts
  and four backup PNGs. Preserve all; the six script/image exclusions must never enter
  a release snapshot. This audit commits only this report.

## E. Small independent next tasks

1. **Deployment preparation, no source redesign:** close F02 with the existing
   entitlement callable and tier-specific checks. Separately review F01 receipt
   callable with paid/foreign/missing-reference tests. Request deployment authorization;
   do not bundle either with billing writers or cleanup schedules.
2. **Next source implementation task:** `RESIDENT-WALL-LIKE-CONTRACT` (F05).
   Implement/test safe own-UID like/unlike and separately reproduce the feed-query
   concern before changing it. Small Resident + minimal-Rules scope; no general Wall redesign.
3. **Notification contract decision and rollout** (F06): distinguish inbox events
   from announcement read receipts; stage financial event producers/triggers behind
   their own reviewed deployment manifest. Keep flexible payment amounts disabled.
4. **Existing web evidence viewer** (F07): start with authorized Admin complaint
   attachments, then explicitly choose which Resident private-photo surfaces are in scope.
   Decide Marketplace/Wall web scope before creating new modules (F08).
5. **Operations before public scale** (F03/F09/F10): signed App Check acceptance,
   effective IAM/ACL review, URL-media privacy classification, quotas/retention and
   approved synthetic cleanup validation. No automatic configuration changes.
6. **Final checkpoint/publication** (F04/F11/F12): repair the stale gallery test in
   a separate change, finish visual/signing acceptance and create a fresh sanitized
   root publication snapshot. Preserve existing development history and exclusions.

## F. Minimal final acceptance checklist

- [ ] Essential/Plus/Pro Wall policy correct; premium restrictions and missing/inactive
      subscription denial unchanged; Auth/App Check failures remain distinct.
- [ ] Paid V2 receipt retrieval works on Resident mobile/web; missing references stay
      missing, foreign receipts denied, exact-balance payment review remains correct.
- [ ] Admin upload -> Resident community/apartment display; profile, complaint, Wall
      and Marketplace multi-image create/edit/replace/delete; interruption/retry leaves
      no partial records; legacy URLs display without migration.
- [ ] Cross-community/user reads and writes denied; logout/community switch and
      session revocation clear private frames; no permanent private download tokens.
- [ ] Peer comments work atomically; peer like/unlike is fixed and tested; mobile
      Wall feed query verified against the live-equivalent Rules using synthetic emulator data.
- [ ] Resident invite/host QR -> Admin approval/rejection -> Security scan/deny/history/
      checkout stay consistent; merely opening QR/emergency UI sends no emergency operation.
- [ ] Mobile/web notification sources, unread/read behavior and payment event routing
      match their explicitly approved contracts; no announcement/chat over-counting.
- [ ] Signed iOS/Android and hosted web App Check valid; Chrome/Safari, narrow widths,
      RTL/enlarged text, logos, slideshow disposal/fallback and multiple-image ordering accepted.
- [ ] Correct Hosting targets, signed archive/build numbers, owner security/retention
      gates and sanitized publication snapshot approved. No direct contaminated-root push.

## Validation performed for this audit

| Existing focused check                                                                                                                   | Result                                                                                                                           |
| ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Backend: `functions/test/releaseEntitlementContracts.unit.test.js`, `billingV2Receipt.unit.test.js`, `security_visitor_workflow.test.js` | **24 passed, 0 failed**                                                                                                          |
| AW: `src/test/release1Queries.test.ts`, `visitorTransitions.test.ts`                                                                     | **5 passed, 0 failed**                                                                                                           |
| RW: `src/test/release1Queries.test.ts`, `ResidentNotificationRouting.test.tsx`                                                           | **7 passed, 0 failed**                                                                                                           |
| Total executed                                                                                                                           | **36 passed, 0 failed**                                                                                                          |
| Rules/Flutter history reused, not rerun                                                                                                  | Prior comment Rules 22/22; latest Marketplace UI 10/10, including 320–430px / 2x text                                            |
| Scope/checks                                                                                                                             | Read-only source/config/deployment comparisons, Linux evidence review, Git status/tips, report formatting and `git diff --check` |

No full builds, typechecks, complete Flutter suites, customer-file reads or device
acceptance were performed. Passing local tests establish local contracts, not that
missing/stale production Functions have been deployed. No fixes, deployment, push,
branch switch, production write or credential change was made by this audit.

## Image-contract addendum — 2026-10-20

**Source baseline:** M `4b060a8`, AW `2bf3e53`, RW `a6a3fa0`. This is a targeted,
source-only refinement of F07–F10, not a fresh production inventory. Original
production observations above retain their original dates. No customer images,
historical Cloudinary objects, credentials or production configuration were accessed.
No application code changed. Both web worktrees were clean; root's nine existing
untracked paths were preserved.

**Release impact:** IMG01/IMG02/IMG06 are confirmed gaps in already-present event
photo workflows. IMG03/IMG04 require explicit web scope decisions; missing modules
are not automatically defects. IMG05 is a conditional privacy blocker, not proof
of unauthorized production access. Cross-platform image parity is not yet accepted.

### Contract comparison

| Workflow                    | Current mobile/backend contract                                                                                                                                                                                                                                                                                                                                                                          | Current AW / RW support                                                                                                                                                                                                                                 |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Marketplace                 | `marketplaces/{id}`: ordered `images: string[]`, `managedImageAssets`, `imageRevision`; private strings are `hominode-image:<UUID>`. Resident creates an owned draft, stages/finalizes, then atomically publishes/edits through `commitResidentImages`.                                                                                                                                                  | Neither web app has a Marketplace route or mutation adapter. This is absent capability, not a broken existing web uploader.                                                                                                                             |
| Community Wall              | `posts/{id}`: primary `imageUrl`, ordered `imageUrls`, additive managed assets/revision; the same draft/commit flow binds author and community. Private author avatars resolve to the current profile pointer.                                                                                                                                                                                           | `src/data.ts` defines a posts query, but routed `CommunityPage` is community information, not a Wall image/post editor. No web private-image reader.                                                                                                    |
| Events                      | `events_announcements/{id}`, `type: event`. AW writes ordered `images: {url,storagePath,name}[]`, `imageUrls`, primary `imageUrl`; Resident mobile merges these URL fields. Admin mobile still writes a selected device's `localImagePath` and null `imageUrl`.                                                                                                                                          | AW event details render `images[].url` / `imageUrl` through `FacilityGallery`; RW event details are generic text, without an event gallery. AW's reader does not consume an `imageUrls`-only record, although its own uploader writes all three fields. |
| Announcements               | Canonical `events_announcements`, with existing announcement/notice discovery compatibility. Mobile models accept `attachments`, `imageUrls`, primary `imageUrl`; these attachment views are network-URL readers, not private-asset readers.                                                                                                                                                             | Existing announcement forms/details are text-oriented and have no attachment gallery/private upload adapter. Do not publish opaque announcement references before adding an authorized contract and readers.                                            |
| Apartment/community gallery | `apartmentImages/{id}` retains metadata, ordering/timestamps and legacy `imageUrl`, adding server-owned `imageAsset` / `revision`. Readers must prefer the private asset, without falling back to an old URL on authorization failure. Current backend permits operational residents in the same community to read active gallery records, validates the record's building, and permits assigned Admins. | Neither app queries/renders this gallery in current profile/apartment/community pages. Static community banners and text/initials remain. Older Phase 2 documents saying exact resident-building-only access are superseded by current source.          |
| Resident photo              | `users/{uid}` synchronizes `profileImage`, `profileImageUrl`, `photoURL` with an opaque string plus managed assets/revision; Firebase Auth's public photo URL is not used to store the opaque reference. Owner uploads/changes; operational same-community residents and assigned Admins may read under backend checks.                                                                                  | Current profile/resident surfaces show initials/text. No photo upload/edit adapter or private-avatar rendering; no demonstrated new external upload.                                                                                                    |

Exact mobile/domain source: M
`resident_app/lib/src/services/{resident_image_operations,profile_image_service,post_firestore_service,listing_firestore_service,apartment_images_service,resident_private_images}.dart`,
`resident_app/lib/src/models/{event_model,announcement_model}.dart`,
`resident_app/lib/events_announcements_screen.dart`,
`hominode-admin/admin_app/lib/services/{cloudinary_apartment_images_service,event_announcement_service}.dart`,
`hominode-admin/admin_app/lib/widgets/private_apartment_image.dart`,
`functions/src/{storage_images,resident_images,apartment_images}.js`.

### Authorization and transport: confirmed source facts

- All inspected configurations target `hominode-prod` and
  `hominode-prod.firebasestorage.app`; mobile/web callable region is
  `asia-southeast1`. This pass found no bucket/region string mismatch. Browser
  App Check acceptance, actual deployed source and bucket IAM were not reverified.
- Existing seven callable names match mobile adapters:
  `prepareStorageImageUpload`, `completeStorageImageUpload`, `readStorageImage`,
  `saveApartmentImage`, `deleteApartmentImage`, `createResidentImageDraft`,
  `commitResidentImages`. M `functions/src/index.js` enforces App Check and verified
  phone/canonical identity. Both web `src/firebase.ts` initialize reCAPTCHA Enterprise,
  enable debug only in DEV, and already provide a callable wrapper in that region.
- `prepareStorageImageUpload({feature,resourceId,contentType,size})` issues the
  server-owned reservation; upload only to its returned path/metadata, then call
  `completeStorageImageUpload({assetId})`. Staging paths are
  `apartment_images/{communityId}/{uid}/{assetId}.{ext}` or
  `resident_images/{communityId}/{uid}/{feature}/{assetId}.{ext}`; final objects use
  `private_images/{communityId}/{ownerId}/{feature}/{assetId}.{ext}`. Clients must not
  choose trusted community, role, owner, bucket or final path.
- `createResidentImageDraft({feature})` supports Wall/Marketplace targets not yet
  created. `commitResidentImages({feature,resourceId,operationId,expectedRevision,
references,content?,deleteResource?})` validates ownership/entitlement and attaches
  atomically. Apartment save/delete use `imageId` and optimistic `expectedRevision`
  for existing records. Do not replace these with client writes to managed fields.
- `readStorageImage({assetId,knownAssetId?,knownGeneration?})` returns authorized
  asset metadata and bounded base64 bytes or `notModified`; it rechecks access after
  I/O and can redirect replaced profile pointers. It does **not** return a permanent
  URL. M `deployment/storage-minimal/{storage,firestore}.rules` deny direct final
  object access and protect managed document fields. Source reads retain tenant,
  operational identity, owner/audience and feature-entitlement checks; Admin and
  Resident permissions are not interchangeable.
- Private uploads are limited to 10 MiB, JPEG/PNG/WebP, plus GIF only for profile/Wall;
  backend Sharp validates actual image content. This is different from AW event
  uploads: direct `event_images/{communityId}/{eventId}/{fileName}`, up to six images,
  5 MiB each, JPEG/PNG/WebP, MIME/size checks and Firebase token-bearing download URLs.
  Event Rules preserve scoped Admin writes and same-community reads; the private
  five-feature foundation has **no event/announcement feature**.
- No Cloudinary write/delete implementation was found in either web's active TS/TSX
  source. Admin apartment service's historical class name now wraps Firebase.
  Resident `cloudinary_service.dart` upload/delete methods throw without HTTP;
  remaining old helper/example references cannot perform provider requests. Legacy
  HTTPS URLs stay readable only at surfaces already supporting network images.
  Both web `safeUrl` helpers intentionally reject opaque references: changing that
  URL allowlist would not implement private viewing. No historical URL was fetched.

### Confirmed gaps, conditional blockers and smallest corrections

| ID / severity                                                    | Exact affected source and confirmed difference                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Smallest safe action / rollout                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| IMG01 — **P1, must fix for the existing event photo picker**     | M `hominode-admin/admin_app/lib/widgets/create_event_modal.dart:550`, `events_announcements_screen.dart:276,878`, `services/event_announcement_service.dart:80,446`. Selected photo is returned as a local File/path, persisted without upload, then preferred over `imageUrl` by `Image.file`. Admin mobile also drops the ordered URL gallery fields AW writes. This cannot share the selected photo to another device; multi-image rendering differs from Resident mobile. Confirmed code defect; cross-device/failure UI acceptance pending. | Upload the selected file through an approved event image contract, store shared references only after success, and normalize ordered image fields in the Admin model/view. Ignore device-local paths for shared display. Decide URL-shareable versus private event policy first (IMG05); do not invent an unsupported private `feature: event` request. Admin rebuild; backend/Rules only if introducing private event media.                                            |
| IMG02 — **P1, existing web event viewer gap**                    | RW `src/pages.tsx:1548–1557` renders galleries for facilities only; event detail uses `DetailFields`. AW `src/pages.tsx:306,353` renders event galleries but ignores `imageUrls`-only inputs. Resident mobile `src/models/event_model.dart` / `events_announcements_screen.dart` consumes ordered URL lists. Confirmed source gap; existing AW three-field records already avoid its fallback edge case.                                                                                                                                         | RW: render a scoped event gallery in existing event details, preserving list order and legacy primary URL. AW: normalize the same accepted URL variants. Do not pass private IDs to `<img>`. No new backend feature needed for existing URL records; affected web hosting only.                                                                                                                                                                                          |
| IMG03 — **P1, explicit web photo-scope decision**                | AW/RW `src/pages.tsx` (`ProfilePage`, `ApartmentInfo`, `CommunityPage`), `src/data.ts`, `src/models.ts`; no private adapter, no `apartmentImages` query, no private avatar. Mobile gallery/profile images are implemented. Confirmed missing presentation, not evidence of unauthorized access.                                                                                                                                                                                                                                                  | For required existing web surfaces, add a bounded session/community-scoped callable reader, validate response identity/MIME/size/generation, release object URLs and discard stale responses on sign-out, scope change or denial. Integrate profile photos and the approved gallery only; no unused viewer or Admin use of Resident upload authority. Web hosting; existing backend audience appears sufficient, subject to synthetic tests.                             |
| IMG04 — **P1 scope decision, not automatically a blocker**       | AW/RW `src/{App.tsx,navigation.ts,pages.tsx,actions.ts,data.ts}`: no Marketplace or interactive Wall image workflow; announcement attachments are not presented. Mobile supports these images.                                                                                                                                                                                                                                                                                                                                                   | Record mobile-only Release 1 scope or separately authorize each workflow. If web editing is required, reuse drafts, exact image fields and atomic commit/revision contracts; preserve Essential Wall and Plus/Pro Marketplace checks. Do not build these modules merely to claim image parity. Hosting/rebuild only for approved work, with backend changes only for a proven unsupported contract.                                                                      |
| IMG05 — **P0 conditional privacy gate / P1 contract difference** | AW `src/actions.ts:169–192`, M `deployment/storage-minimal/storage.rules:163`, `functions/src/storage_images.js` feature registry. New event uploads are Firebase-only but bypass private finalization/Sharp and store bearer download URLs. This differs from private mobile gallery/profile/Wall/Marketplace, but no current account leak or breached private-event policy was established.                                                                                                                                                    | Owner explicitly classifies new event/announcement media. If tenant-private is required, block that rollout until a narrow server-authorized event contract, actual-content validation and all active readers support private media. If URL-shareable is approved, document it and test current scoped writes. Do not migrate/revoke historical URLs during this task. Conditional Functions/Rules + client rollout, not a blind change to the seven existing callables. |
| IMG06 — **P1, current AW event image failure/retry defect**      | AW `src/actions.ts:174–209,256–270`, `src/pages.tsx:1269–1279`. Delete removes bytes before Firestore metadata update; failed metadata update leaves a broken image reference. Create persists an event before upload; retry can create another event. A failed `getDownloadURL` occurs before the uploaded object enters the rollback list. Confirmed ordering gaps; no production failure was induced.                                                                                                                                         | Retain the created event ID for retry; track uploaded paths immediately; confirm metadata removal before retiring bytes, with idempotent cleanup/retry on interruption. Preserve ordering/primary fields and failed-replacement originals. Fault-injection tests before hosting rollout; no generic migration or unrelated event redesign.                                                                                                                               |

All source tasks above are practical for a developer manually; **Codex is optional**.
Privacy/scope decisions, browser/signed-device attestation and production permission
acceptance require the owner/tester and cannot be certified by code inspection.

### Prioritized file-by-file handoff

1. **Shared prerequisite:** agree IMG05's event-media policy and IMG04's web feature
   scope. M `functions/src/{storage_images,resident_images,apartment_images}.js`,
   `deployment/storage-minimal/{storage,firestore}.rules` remain unchanged unless a
   specific new authorized event contract is approved. Do not deploy broader root Rules.
2. **Admin Web, existing event workflow first:** AW `src/actions.ts` fixes IMG06;
   `src/pages.tsx` retains pending event identity and normalizes event image variants;
   `src/models.ts` declares the event gallery shape; focused `src/test/actions.test.ts`
   and a proposed new `src/test/eventImages.test.tsx` cover failure/retry/order. Keep
   supported URL records readable. Pair with the three IMG01 mobile files and mobile
   event model/presentation tests; this is the next recommended implementation task.
3. **Resident Web, existing event presentation:** RW `src/pages.tsx` normalizes/renders
   scoped ordered event URLs; proposed `src/test/eventImages.test.tsx` covers AW-written
   records, URL-only variants, empty/error states and narrow-screen navigation. No upload
   controls, Marketplace routes or private-feature expansion in this task.
4. **Web private photos, only approved existing surfaces:** separately in AW and RW,
   propose `src/privateImages.ts` and `src/components/PrivateImage.tsx` plus focused tests;
   reuse existing `src/firebase.ts` `call`, add strict contract types in `src/models.ts`,
   scoped gallery reads in `src/data.ts`, integrate only selected `src/pages.tsx` surfaces.
   These are proposed files, not present implementations. Add a Resident upload adapter
   only if web photo editing is explicitly required; its server contract already exists.
5. **Rollout:** current URL-view/lifecycle fixes need web hosting and the affected mobile
   rebuild. Private web readers reuse existing callables, subject to acceptance. A newly
   approved private event contract needs backend/Rules before compatible clients and
   before emitting new reference shapes. Do not activate cleanup schedulers implicitly.
   Their previously documented retention/operational gate remains separate and was not
   freshly checked here. No deployment was performed.

### Minimal cross-platform acceptance and validation

- Use synthetic fixtures only: AW event with two ordered photos -> AW, Resident
  mobile and RW event detail; Admin mobile event photo -> a second device/browser.
  Exercise `images`, `imageUrls` and primary-only legacy shapes separately. Mock all
  legacy URLs; do not fetch or migrate historical Cloudinary test images.
- Admin apartment upload/replace/delete -> same-community Resident mobile and any
  approved web gallery. Preserve metadata/date/order; deny foreign-community access;
  a private-read denial must not fall back to an old URL. Include an active gallery
  record from another building in the same community, per current backend policy.
- Resident profile replacement -> current same-community avatar; denied foreign read,
  removed photo and expired session. Test private reader redirects, cached generation,
  auth/community switch, bounded memory and discarded in-flight replies in web mocks
  and browser acceptance. Never use permanent download URLs for private assets.
- Mobile Wall/Marketplace create/edit/multi-image/delete -> authorized same-community
  mobile readers. Web is not an acceptance target for absent modules unless approved.
  Confirm Essential Wall allowed / Marketplace denied, Plus/Pro Marketplace allowed,
  wrong owner/community and invalid App Check denied; no arbitrary managed-field writes.
- Inject event upload, URL retrieval, metadata-save and byte-delete failures; retry
  must not duplicate events, break retained images or silently abandon cleanup.
- Hosted AW/RW reCAPTCHA Enterprise + signed/debug mobile App Check, phone-auth identity,
  direct private-object denial and exact backend deployment remain runtime checks.
  No live claims from the original audit were refreshed in this pass.
- **Run this pass:** AW `src/test/release1Queries.test.ts` + `src/test/firebase.test.ts`:
  **15 passed, 0 failed**. RW same two focused files: **16 passed, 0 failed**.
  These prove mocked config/query/legacy-URL behavior, **not private web rendering or
  live authorization**. No broad builds, application suites, new tests or backend
  emulators were needed for this documentation-only change. Report formatting and
  `git diff --check` are checked before its local-only commit.
