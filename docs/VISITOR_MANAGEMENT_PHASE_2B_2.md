# Visitor Management Phase 2B-2 — Resident integration

Completed against the current local working trees on 2026-11-09. No deployment, production data access, commit, push, release build or policy activation was performed. Security Flutter, Admin clients, Firebase backend source, rules and indexes were not edited in this phase. Existing unrelated modifications remain in place.

## Confirmed gaps and implementation

Phase 1 had repaired private credential retrieval in Resident Flutter. Resident Web still accepted an incompatible document-ID QR fallback. Both Resident clients lacked the Phase 2A pet disclosure, managed authorization presentation and callable rescheduling integration; Flutter cancellation still deleted visitor documents directly.

Both clients now:

- Submit an explicit `bringingPet` boolean, initially false, alongside the existing invitation fields. Backend context supplies advisory pet/approval guidance; final creation/rescheduling remains server-authoritative. The generic prohibition message does not reveal whether a restriction is temporary or permanent, and residents can clear the checkbox and continue.
- Present backend authorization separately from physical visit state: Resident authorized, Admin authorized, pending Admin approval, rejected or revoked, alongside expected/check-in/check-out/cancelled/expired states. They do not treat legacy `isApproved` as proof of a manual Admin decision. Older rows without authoritative authorization metadata are described as legacy invitations whose pass availability must be checked by the server.
- Reflect Admin decisions through existing visitor subscriptions. Reopening the screen reloads persisted state. Private pass views also revalidate on policy revision changes and foreground/focus, and clear credentials when invitation state changes. Scheduled validity boundaries remove unusable passes.
- Retrieve actual private QR/manual credentials, require the expected credential shapes and reject legacy/malformed responses. There is no active document-ID QR fallback. Public visitor documents are not credential sources; Web visitor details use a public-field allowlist. Flutter rereads the visitor after credential retrieval to reject a concurrently changed authorization revision or arrival time.
- Keep credentials in pass-view memory, with no new storage, logging or public document writes. Existing Flutter sharing revalidates the pass first and shares the private manual code using the existing OS share action. Web has no newly introduced sharing workflow.
- Confirm cancellation and submit the displayed authorization revision through the existing mutation callable. They retain the invitation and its audit history instead of deleting it. Rescheduling uses the same callable, rechecks authorization/pet policy, and refreshes pass availability. Unchanged arrival time is omitted, allowing pet removal without unnecessarily replacing the existing visit window. The forms explain that rescheduling resets previous Admin authorization.
- Prevent concurrent submissions/actions, wait for confirmed acknowledgements, and report stale revisions, denied access and uncertain network outcomes. A Web confirmed-action lock is tied to the submitted revision so an already-arrived newer snapshot does not remain blocked. Flutter provides a scoped list refresh for reviewing conflicts.

Configured community `timeZone` values are interpreted as IANA zones and converted to epoch milliseconds. Skipped/repeated DST times are rejected. An unconfigured community preserves existing device-time behavior and labels that fallback explicitly; configure the canonical timezone before strict rollout.

No client evaluates owner/tenant eligibility, grants an identity-verification exemption, creates an arrival notification or performs a Security check-in. Those decisions remain on the existing backend. The confirmed community owner-verification exemption is preserved and tested as explicitly unverified in the policy snapshot.

## Existing contracts consumed

All callables use the existing authenticated/App Check integration in `asia-southeast1`:

| Callable | Request used by these clients | Result handling |
| --- | --- | --- |
| `createVisitorInvitation` | `visitorName`, `purpose`, epoch-ms `expectedArrival`, optional `phoneNumber`/`vehicleNumber`, boolean `bringingPet` | Require `visitorId`; show pending feedback from `authorizationState`. Do not retain any creation-response secrets. |
| `getResidentVisitorContext` | epoch-ms `expectedArrival` only | Validate returned community and `petPermitted`; use `authorizationState` as advisory guidance only. |
| `getVisitorCredentials` | `visitorId` | Use server-issued `qrToken` and `visitorPassCode`; reject `legacy: true` or malformed credentials. |
| `mutateResidentVisitor` | `visitorId`, `action: cancel/reschedule`, `expectedRevision`; rescheduling optionally adds epoch-ms `expectedArrival` and boolean `bringingPet` | Require matching ID, revision and authorization state before reporting success. No direct deletion or protected field writes. |

No backend compatibility correction or new API was needed. The shared fixture `docs/fixtures/resident_visitor_contract.json` verifies matching Web/Flutter creation, guidance and mutation payloads.

## Exact files changed in this phase

Resident Flutter, relative to `resident_app/`:

- `lib/add_expected_visitor_modal.dart`
- `lib/visitor_qr_screen.dart`
- `lib/src/models/resident_visitor_authorization.dart` (new)
- `lib/src/models/resident_visitor_lifecycle.dart`
- `lib/src/screens/visitor_management_screen_new.dart`
- `lib/src/services/resident_visitor_policy_service.dart` (new)
- `lib/src/services/resident_visitor_pass_service.dart` (existing Phase 1 file extended)
- `lib/src/services/visitor_firestore_service.dart`
- `lib/src/services/visitor_qr_contract.dart`
- `pubspec.yaml`
- `test/resident_visitor_policy_integration_test.dart` (new)
- `test/resident_visitor_pass_test.dart`
- `test/resident_visitor_lifecycle_test.dart`
- `test/visitor_qr_contract_test.dart`

The already cached `timezone: ^0.10.1` dependency is now direct. Offline dependency resolution changed the local Git-ignored lockfile classification from transitive to direct without upgrading its version.

Resident Web, relative to `/Users/sukumarmuthiah/Documents/hominode-resident-web/`:

- `src/actions.ts`
- `src/pages.tsx`
- `src/residentVisitor.ts` (new)
- `src/residentVisitorService.ts` (new)
- `src/residentVisitor.css` (new)
- `src/components/ResidentVisitorForm.tsx` (new)
- `src/components/ResidentVisitorActions.tsx` (new)
- `src/components/VisitorQrPass.tsx`
- `src/test/actions.test.ts`
- `src/test/residentVisitor.test.tsx` (new)
- `src/test/residentVisitorService.test.ts` (new)
- `src/test/visitorQr.test.tsx`
- `e2e/ResidentVisitorHarness.tsx` (new, synthetic/offline only)
- `e2e/residentVisitor.spec.ts` (new)
- `e2e/harness.tsx`
- `e2e/data.ts` (missing offline exports restored; unrelated live resources remain empty in this harness)

Shared/backend test additions, relative to `lyvo1/`:

- `docs/fixtures/resident_visitor_contract.json`
- `functions/test/visitorResidentClients.firestore.emulator.test.js`
- `docs/VISITOR_MANAGEMENT_PHASE_2B_2.md` (this report)

Existing modifications in these files were preserved. Other dirty/untracked paths are outside this phase's change list.

## Focused validation

| Validation | Final result |
| --- | --- |
| Resident Flutter: new integration tests plus Phase 1 private-pass, lifecycle, QR-contract and expiry regressions | **53 passed** |
| Resident Web: visitor form/actions/service/QR tests plus existing actions tests | **61 passed** |
| Offline Chrome: complete synthetic visitor flow at 393/600/800/1440px and existing Visitors route opening the pet-aware form | **5 passed** |
| Firestore emulator: new Resident-client scenarios plus existing policy, Phase 1, transitions, verification and migration suites | **55 passed, 0 skipped** |
| Existing unchanged Security Flutter QR payload, model-status and workflow-screen regressions | **14 passed** |
| Targeted Flutter analysis | **0 errors, 0 warnings**; 43 existing `avoid_print` informational notices remain in legacy visitor service methods |
| TypeScript `tsc --noEmit` | **Passed** |
| Targeted ESLint | **0 errors**; existing Billing detail-effect dependency warning in `src/pages.tsx` remains |
| Dart formatting, changed Web/shared-file formatting, scoped Git whitespace checks, new emulator test syntax check | **Passed** |
| Production-mode Vite bundle to `/private/tmp/hominode-resident-visitor-2b2-build` | **Passed**, no hosting preparation/deployment |

The original Resident test failures were resolved by correcting the test provider/listener adapter, accounting for the new committed-document reread, supplying the required exception message, and scrolling the History segment into view. No Flutter failures remain.

Coverage includes owner/tenant policy combinations, owner identity exemption, inactive/unverified/invalid-unit rejection, backend-only community isolation, pending/approved/rejected/revoked states, pet restrictions and effective-window boundaries, captured credential denial, private credential isolation, confirmed cancellation/audit retention/replay rejection, rescheduling and private index validity, duplicate locks, malformed credentials and QR fallback rejection. Flutter form layouts cover 393/600/800px at text scales 1.0 and 1.3; existing pass-layout tests remain green.

The 55 emulator cases use only synthetic `demo-hominode-resident-clients` data. Strict modes are enabled only inside synthetic fixtures to exercise the existing backend. Existing QR/manual integration tests prove automatic check-in and one stored Resident notification plus mocked push dispatch. They do **not** verify a real camera, deployed App Check, live FCM or a real device.

Commands used:

```sh
# resident_app
flutter test --no-pub test/resident_visitor_policy_integration_test.dart test/resident_visitor_pass_test.dart test/resident_visitor_lifecycle_test.dart test/visitor_qr_contract_test.dart test/resident_visitor_expiry_test.dart
# flutter analyze --no-pub --no-fatal-infos was limited to the changed visitor Dart sources/tests listed above.

# hominode-resident-web
npx tsc --noEmit
npx vitest run src/test/visitorQr.test.tsx src/test/residentVisitor.test.tsx src/test/residentVisitorService.test.ts src/test/actions.test.ts
npx playwright test e2e/residentVisitor.spec.ts
npx vite build --outDir /private/tmp/hominode-resident-visitor-2b2-build
# ESLint and formatting were limited to the changed files.

# functions — local Firestore emulator, config selecting port 8085 and working-tree rules
npx firebase emulators:exec --config /private/tmp/visitor-phase1-emulator.json --project demo-hominode-resident-clients --only firestore 'node --test --test-concurrency=1 test/visitorResidentClients.firestore.emulator.test.js test/visitorPolicy.firestore.emulator.test.js test/visitorPhase1.firestore.emulator.test.js test/visitorTransitions.emulator.test.js test/visitorVerification.firestore.emulator.test.js test/visitorCredentialMigration.firestore.emulator.test.js'

# security_app — existing tests only, no source/test changes
flutter test --no-pub test/visitor_qr_payload_test.dart test/visitor_model_status_test.dart test/visitor_workflow_screen_test.dart
```

## Deployment dependencies and remaining UAT

There are **no additional Phase 2B-2 backend/rules/index changes to deploy**. Production rollout depends on the reviewed Phase 1/2A backend foundation, especially the four consumed callables and the existing guarded Security verification/legacy gate routes. Preserve the credential HMAC secret, App Check, authentication, notification trigger and legacy cutoff configuration. The Phase 2A audit-history index and Phase 2B-1 Admin clients must be available for the combined workflow. Deployment state was not inspected against production.

Follow the Phase 2A staging/deployment order, review the combined dirty backend diff separately, and validate minimum supported older-client behavior. **Strict enforcement remains disabled in the client rollout; no enable/readiness/policy writes were made by this phase.** Existing Phase 2B-1 settings continue to stage disabled configuration. Staged mandatory-approval, emergency and pet restrictions have no effect while disabled. No production rollout flag was changed.

Manual UAT, using approved staging data and keeping production enforcement disabled:

1. On iPhone, Android/Pixel and Web, create as an eligible verified owner, an exempt owner and a verified tenant. Check default pet=false and all existing form fields. Reject inactive/unverified/invalid-unit accounts. Confirm another Resident or community cannot retrieve, mutate or open the pass.
2. With enforcement disabled, confirm staged strict/emergency/pet settings do not change current admission. In a separately approved synthetic/staging policy setup, exercise all three approval modes and emergency start/end: pending invitations have no QR/manual code; Admin approval appears without reopening; rejection/revocation clears an open pass. Do not enable production to perform these checks.
3. Check allowed/prohibited/temporary pet policies before, during and after the effective restriction and for overlapping visit windows. Confirm generic wording, no leaked restriction schedule, uncheck-and-continue, and backend denial of a modified prohibited request.
4. Show the actual private QR to the unchanged Security scanner, then separately enter the private manual code. Verify automatic check-in, visitor details, exactly one real Resident arrival notification and checkout. Confirm upcoming Security lists expose neither credential. Check invalid/document-ID/expired/cancelled/revoked credentials fail.
5. Cancel after confirmation; verify retained History and audit records, captured QR/manual invalidation, stale-revision handling and repeated-action rejection. Reschedule across approval/pet restrictions, verify new credential windows and prior Admin authorization reset, including pet-only removal without changing arrival.
6. Background/foreground, restart, switch accounts/community, lose/recover network and let the pass expire while open. Confirm no stale private pass reappears and no success is shown for an unconfirmed request. Test Flutter OS sharing on both platforms.
7. Check Flutter at 393/600/800px with normal/modest text scaling and keyboard open; check Web at 393/600/800/1440px, including nested reschedule dialogs, labels, scrolling and read/error states. Verify configured community timezones on a device in a different zone and around DST boundaries.

Remaining risks are real-device/deployed integration verification and the existing non-idempotent creation API: clients lock concurrent submissions and do not automatically retry uncertain results, but after a timeout the Resident must check the visitor list before retrying. No new idempotency API was invented. Legacy credentials flagged for replacement remain unavailable rather than receiving a guessed fallback. These are documented release/UAT dependencies, not unresolved automated-test failures.

Phase 2B-2 stops here. No Phase 3 work or Security redesign was started.
