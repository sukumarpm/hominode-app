# Visitor Management Phase 2A — backend foundation

Implemented against the local working trees on 2026-11-09. Nothing deployed. No frontend or Security Flutter files changed. Phase 1 remains in place.

## Current-code findings

- Resident Flutter creates invitations through `createVisitorInvitation` in `resident_app/lib/src/services/visitor_firestore_service.dart`. Phase 1 private pass retrieval lives in `resident_app/lib/src/services/resident_visitor_pass_service.dart` and `resident_app/lib/visitor_qr_screen.dart`. Cancellation still deletes the visitor document directly. Its form has no pet disclosure or mandatory-approval feedback.
- Admin Flutter's existing Visitors navigation and Expected/Inside/History queues remain intact. `hominode-admin/admin_app/lib/services/visitor_service.dart` directly updates approval/rejection/checkout and can delete records. `lib/community_settings_screen.dart` already hosts community settings, but has no visitor policy controls. Existing dashboard counts use legacy expected/pending and `isApproved` fields, not the new authorization state.
- Admin Web has an active `/visitors` route. `src/pages.tsx`, `src/visitorTransitions.ts`, and `src/actions.ts:updateScoped` implement community-scoped direct approval/rejection writes. `src/CommunityPaymentSettings.tsx` provides a callable-based settings precedent. No visitor-policy settings or policy history UI exists.
- Resident Web **already has invitation creation, visitor list/detail/status, private QR retrieval and manual-code display** (`src/actions.ts:createVisitor`, `src/pages.tsx`, `src/components/VisitorQrPass.tsx`). However, its QR helper still accepts a legacy document-ID fallback and does not validate tokens like the Phase 1 Flutter pass service. It has no pet checkbox, managed authorization presentation, or migrated cancellation/rescheduling flow. This is a specific Phase 2B parity gap; no web files were changed here.
- Security Flutter already uses `verifyVisitorCredential` for private QR/manual verification and automatic entry. The backend still exposes `resolveVisitorQr` / `transitionVisitorFromQr` for legacy clients. All these backend routes now apply the shared authorization guard. No Security scanner, manual-entry, navigation, notification, or details-screen changes were made.
- Existing community metadata uses **`timeZone`**, validated by `normalizeIanaTimeZone`; community documents are already server-write-only. Existing `auditLogs` are server-only. The new implementation reuses both.

## Architecture and rollout boundary

`functions/src/visitor_policy.js` is the shared evaluator. `visitor_policy_management.js` implements policy reads/updates, Admin decisions, Resident mutations/context, and scoped history. Creation, private retrieval, unified verification and both legacy routes call the shared evaluator/guard. Existing denial, checkout and notification dispatch remain separate from authorization.

Enforcement is **disabled by default**. Policy updates cannot set `enabled: true` until the community has the server-owned `visitorPolicyRolloutReady: true` flag. No client API can set that flag. Existing community update callables use explicit field allowlists; Firestore denies direct community writes. An authorized release operator must establish readiness only after Phase 2B migration and device validation. This flag is a release interlock, not a substitute for authorization checks.

While disabled, new invitations retain the existing `status: expected, isApproved: false` contract and direct legacy approval/cancellation remains available. Each new invitation records a server-owned policy snapshot and creation audit, but is not a managed authorization record. Legacy direct-write decisions during this compatibility period are **not** upgraded to transactional policy audits. Strict enforcement and complete decision auditing must therefore remain disabled until clients migrate. Policy settings may be staged while disabled; staged emergency/pet restrictions do not take effect.

When enabled, creation stores `authorizationManaged: true`, `authorizationState`, `authorizationRevision: 1` and a policy snapshot. Pending invitations receive private credentials internally, but **creation returns no secrets**, retrieval rejects, and all gate routes reject even a captured credential. Rules deny direct approval/rejection/rescheduling/deletion for managed records and for all records in an enabled community. Existing narrow Admin checkout remains available. Managed records stay backend-owned even after enforcement is disabled.

Identity resolution reuses `trustedResidentType`, `identityVerificationRequired`, `identityIsVerified` and `resolveFlatOccupant`. Creation and Resident mutations transactionally re-read account, community and unit. Approved, active account, matching verified phone and occupied canonical unit are required. Tenant verification is required. Conflicting owner/tenant/declared fields fail closed. Family metadata grants no independent role. **The user's confirmed decision is preserved:** an owner exempted by the community remains eligible, with `identityVerified: false` and `identityBasis: community_owner_exemption`; an owner in a verification-required community must be verified.

## Policy schema and defaults

Stored as `communities/{communityId}.visitorPolicy`; no duplicate settings collection:

```js
{
  schemaVersion: 1,
  enabled: false,
  timeZone: 'Asia/Manila', // canonical IANA value; must match community.timeZone
  approvalMode: 'resident_authorized',
  emergency: null, // or {startAt: epochMilliseconds, endAt: epochMilliseconds}
  pets: {
    mode: 'allowed',
    normalMode: 'allowed',
    restriction: null // or {startAt: epochMilliseconds, endAt: epochMilliseconds}
  },
  revision: 1, updatedBy: 'adminUID', updatedAt: serverTimestamp,
  enforcementStartedAt: null // first enable time; never reset by disable/re-enable
}
```

- Exactly three normal modes: `resident_authorized`, `tenant_approval_required`, `all_approval_required`. Default unconfigured mode is resident-authorized, disabled, pets allowed, revision zero.
- No categories or family-member privileges. Auto authorization does not populate Admin approval identity/timestamps.
- Emergency interval is half-open `[startAt, endAt)` and evaluated using server creation/rescheduling time. It overrides all normal modes for owners and tenants. No scheduler or rewrite is needed at expiry. Invitations created pending during an override remain pending after expiry.
- Clients convert community-local date/time to explicit epoch milliseconds using the supplied IANA zone, handling DST ambiguity explicitly. The backend never interprets a device-local date string. An unset community `timeZone` must be configured through the existing authorized community metadata process first.
- Pet modes: `allowed`, `not_allowed`, `temporarily_restricted`. `normalMode` is `allowed` or `not_allowed`; for a non-temporary mode it must equal `mode`. Temporary mode requires a valid restriction interval; other modes require null. The normal mode applies outside the restriction. No scheduled writes.
- The current credential validity window is inclusive arrival ±24h. A declared-pet invitation is rejected if **any part** of this window overlaps the half-open restriction interval. Thus `arrival + 24h == restriction.startAt` is blocked; `arrival - 24h == restriction.endAt` is allowed. Merely configuring a restriction in the past does not block later, non-overlapping visits.
- `bringingPet` is strictly boolean when supplied; absent legacy fields mean false. Null/string/numeric values are invalid. All pet rejection paths return only: **“Pets are not permitted for this visit. You may continue without a pet.”** The Resident context API returns only `petPermitted`, not a permanent/temporary explanation. A no-pet visit is never blocked by pet policy.

## Invitation model and existing passes

Managed authorization states are `auto_authorized`, `pending_admin`, `admin_authorized`, `rejected`, `revoked`. Physical lifecycle remains represented by existing arrival/departure/cancellation fields: expected before entry, inside after actualArrival, completed after departure, cancelled after cancellation. Legacy `status` values `approved`/`rejected` project authorization for old clients; they are not independent physical entry evidence. Do not derive Admin authorization from `isApproved` alone.

`visitorPolicySnapshot` records schema/revision, whether enforced, effective normal mode, emergency activation, trusted resident type, identity-verification boolean/basis and server evaluation milliseconds. `authorizationRevision` advances on Admin and Resident mutations. Gate entry never changes managed authorization or writes a fake Admin approver. Truly legacy Security transitions retain their old compatibility fields; legacy `approvedBy` may therefore be a Security actor and must not be interpreted as a new Admin authorization decision.

**Implemented existing-pass treatment:** normal approval changes and emergency activation apply prospectively. Already-authorized managed passes stay authorized. Unmanaged passes issued by this backend while enforcement was disabled are grandfathered through their immutable compatibility snapshot, including across disable/re-enable. Older records without a snapshot must have `createdAt` strictly before first enforcement. Missing dates or newly introduced unmanaged documents after that boundary fail closed. Grandfathering never overrides terminal/cancelled/denied/used/expired status. Pending, rejected and revoked managed passes never regain authorization merely because a policy expires or is disabled.

**Pet policies apply at creation, retrieval and gate validation to existing declared-pet passes too**, using their original arrival window. Their historical authorization is not rewritten. The host can remove the pet declaration through the mutation API; that re-evaluates authorization and may require fresh Admin approval. Old passes with no declaration remain no-pet; software cannot infer an undeclared animal. Gate operations must enforce actual pet entry operationally.

Tradeoff requiring community/release signoff before enable: prospective emergency approval preserves existing promised access but does not implement an immediate lockdown of all outstanding passes. Existing declared-pet passes can become unusable under a newly activated pet restriction. These choices are explicit, tested and should be explained to Admins in Phase 2B. A community wanting retrospective emergency revocation needs a separately designed, audited revocation operation; none is silently performed here.

Emergency response/evacuation remains on existing SOS and operational emergency procedures, **outside guest invitation approval**. This engine does not alter SOS endpoints, create responder categories or mint bypass credentials. Do not funnel emergency responders into ordinary invitation approval as an emergency-access procedure. Confirm the operational procedure with community staff before enabling any strict mode.

## Exact callable contracts for Phase 2B

All use Firebase callable protocol, `asia-southeast1`, valid App Check and authenticated phone login. Admin authority comes from the authenticated UID's active Admin record and authorized community membership, never a supplied actor/recipient UID. Resident scope comes from the authenticated profile/unit. Unknown fields are rejected by new APIs. Policy/history timestamps in responses are epoch milliseconds. Public visitor documents retain Firestore timestamps.

| Callable | Request | Result / behavior | Consumers |
| --- | --- | --- | --- |
| `getCommunityVisitorPolicy` | `{communityId}` | `{communityId, policy, serverTime, rolloutReady}`; policy includes server revision/update metadata | Both Admin clients |
| `updateCommunityVisitorPolicy` | `{communityId, policy, expectedRevision, reason?}` | `{communityId, revision, enabled}`; policy input contains only schemaVersion, enabled, timeZone, approvalMode, emergency, pets; do not send server metadata | Both Admin clients |
| `getVisitorPolicyHistory` | `{communityId, beforeId?}` | `{events, nextBeforeId}`; 50 most recent visitor/policy audits; next request uses returned cursor; events contain id, timestamp, actor, action, target, metadata and before/after when applicable | Both Admin clients |
| `decideVisitorInvitation` | `{communityId, visitorId, action: 'approve'|'reject'|'revoke', expectedRevision, reason?}` | `{visitorId, authorizationState, authorizationRevision}`; no creation, no check-in. No decision after entry/departure/denial. Cannot reapprove rejected/revoked; create a new invitation instead | Both Admin clients |
| `getResidentVisitorContext` | `{expectedArrival: epochMilliseconds}` | `{communityId, authorizationState, petPermitted, policyRevision, serverTime}` for a future arrival; advisory only; server rechecks at submission | Both Resident clients |
| `createVisitorInvitation` (existing) | Existing `{visitorName,purpose,expectedArrival,phoneNumber?,vehicleNumber?}` plus optional boolean `bringingPet` | Authorized: existing `{visitorId,qrToken,visitorPassCode}`. Pending: `{visitorId,authorizationState:'pending_admin',authorizationRevision:1,credentialsAvailable:false}` with **no credential fields**. Listen to own visitor document for current state/revision | Both Resident clients |
| `getVisitorCredentials` (existing) | `{visitorId}` | Existing `{qrToken,visitorPassCode}` only while authorized/valid and owned; blocked states return failure. Legacy retrieval may return `legacy:true` but new clients must refuse legacy fallback | Both Resident clients |
| `mutateResidentVisitor` | `{visitorId,action:'cancel'|'reschedule',expectedRevision,reason?,expectedArrival?,bringingPet?}` | `{visitorId,authorizationState,authorizationRevision}`. Cancel cannot contain visit detail changes. Reschedule can change arrival and/or pet declaration; omitted arrival preserves it if its window is still usable. Explicit new arrival must be future. Re-evaluates policy/identity and resets any previous Admin approval. Private QR/manual indexes and validity windows update atomically. Legacy passes without private credentials require replacement | Both Resident clients |
| `verifyVisitorCredential` (existing) | Existing `{qrToken,operationId}` OR `{manualCode,operationId}` | Existing sanitized visitor details + additive boolean `bringingPet`; automatic check-in, same-operation replay and notification trigger preserved | Security Flutter unchanged |
| `resolveVisitorQr` / `transitionVisitorFromQr` (legacy) | Existing payloads unchanged | Same authorization/pet guard; legacy cutoff and credential checks remain. Managed legacy “approve” performs entry only; managed legacy “reject” records separate gate denial | Existing legacy clients only |

Read `expectedRevision` from the latest visitor's `authorizationRevision` (missing means zero), or policy revision. On `aborted`, reload and ask the actor to reconsider the current state; do not silently overwrite it. `permission-denied` means authority/scope failure; `failed-precondition` covers rollout lock, pending/revoked/terminal/invalid pass and the exact pet message; `invalid-argument` covers schema/boolean/time/input failures. Existing invalid-credential and manual rate-limit errors remain. Display backend errors without optimistic success or legacy QR fallback.

Gate transactions read the community policy with the visitor, Security account, indexes and private credential. Managed/enforced entry and Admin approval also recheck the host's current active/approved account, identity requirements and canonical occupied unit (two additional reads). Deactivation or reassignment conflicts with entry rather than leaving an outstanding credential usable. Admin/Resident mutations transactionally read the same visitor, so check-in and revocation cannot both commit contradictory results. If check-in wins first, subsequent revocation fails; it does not rewrite an inside record. If revocation wins, check-in fails. A successful same-operation retry returns its original result without re-entry, even after checkout or later policy changes. Retrieval is also transactional, but an already shared/captured secret never grants authorization by itself.

Audits use existing `buildAuditLog` conventions in `auditLogs` and are committed atomically with creation, configuration and authorization mutations. They contain community, visitor/policy target, actor/role, timestamp, effective policy, revision, state and optional reason. Policy edits include full before/after configurations. No credential values or hashes are logged. Runtime automatic expiry needs no extra audit write; issuance snapshots show the effective decision at that instant.

## Rules, reads and indexes

- Community writes and audit reads/writes remain denied to clients. Private credential/index documents remain denied to all clients, including Security.
- Visitor rules add one cached community document lookup for compatibility-write eligibility. They deny managed/direct sensitive writes and all direct sensitive writes when enabled, while retaining existing scoped reads and narrow Admin checkout. Existing rule expression-budget regression tests pass; no new broad collection access is granted.
- Existing visitor queries/indexes are unchanged. One new composite index supports audit history: `auditLogs(communityId ASC, targetType ASC, timestamp DESC)`.
- Emulator verifies query execution and rules, but does not prove production composite-index readiness. Wait for the deployed index to finish building before exposing history.

## Validation

Focused commands (from `functions`; emulator config points at the working-tree rules and local port 8085):

```sh
node --test test/visitor_policy.test.js test/visitor_credentials.test.js test/visitor_verification.test.js test/visitor_gate.test.js test/security_visitor_workflow.test.js test/visitor_notifications.test.js
./node_modules/.bin/firebase emulators:exec --config /private/tmp/visitor-phase1-emulator.json --project demo-hominode-visitor-policy --only firestore 'node --test --test-concurrency=1 test/visitorPolicy.firestore.emulator.test.js test/visitorPhase1.firestore.emulator.test.js test/visitorTransitions.emulator.test.js test/visitorVerification.firestore.emulator.test.js test/visitorCredentialMigration.firestore.emulator.test.js'
```

Security regression command (from `security_app`):

```sh
flutter test test/visitor_qr_payload_test.dart test/visitor_model_status_test.dart test/visitor_workflow_screen_test.dart
```

Results: **80 Node unit tests, 50 Firestore emulator/integration tests, and 14 unchanged Security Flutter tests**. Node syntax checks cover all changed backend sources, index JSON parses, and new JavaScript files are formatted. Emulator cases cover all approval/role combinations, captured QR/manual denial, authorized entry, revocation/cancel, prospective emergency behavior, temporary/permanent pet restrictions, legacy cutoff boundaries, private data isolation, scoped Admin authority/audits, rollout lock, rescheduling/index synchronization, current host eligibility, rules and real transaction races. Existing Phase 1 QR/manual notification tests verify one stored notification and one mocked push. No production data or live FCM was used.

### Files changed in this phase

- `functions/src/visitor_policy.js` (new)
- `functions/src/visitor_policy_management.js` (new)
- `functions/src/visitor_credentials.js`
- `functions/src/visitor_verification.js`
- `functions/src/visitor_gate.js`
- `functions/src/security_visitor_workflow.js`
- `functions/src/index.js`
- `firestore.rules`
- `firestore.indexes.json`
- `functions/test/visitor_policy.test.js` (new)
- `functions/test/visitorPolicy.firestore.emulator.test.js` (new)
- `docs/VISITOR_MANAGEMENT_PHASE_2A.md` (new)

Existing modifications in these files and all unrelated working-tree changes were preserved. Client repositories and all Flutter source files were inspected only.

## Deployment requirements and safest order — not executed

1. Complete Phase 2B clients and validation before enabling policy. First deploy the **disabled** backend/rules/index foundation to a staging project and run the same real-client flows. No approval/pet restrictions take effect just from deployment.
2. Review the combined local Firebase diff carefully: this working tree contains unrelated backend/rules/index work. Deploy only reviewed visitor function targets, the reviewed rules, and the required index. New functions: `getCommunityVisitorPolicy`, `updateCommunityVisitorPolicy`, `getVisitorPolicyHistory`, `decideVisitorInvitation`, `getResidentVisitorContext`, `mutateResidentVisitor`. Changed functions: `createVisitorInvitation`, `getVisitorCredentials`, `verifyVisitorCredential`, `resolveVisitorQr`, `transitionVisitorFromQr`, `listSecurityVisitors` (additive pet details). Existing `VISITOR_CREDENTIAL_HMAC_KEY`, App Check and legacy-cutoff configuration must remain intact. No new secret or scheduled function is required.
3. Deploy rules and index while enforcement is still disabled, then all changed/current/legacy function targets before any activation. Do not enable between partial deployments. Preserve the existing visitor-update notification trigger; its source is unchanged.
4. Release Admin Web and Admin Flutter first, migrating all decisions to callables and adding settings/history/pending queues. Then Resident Web and Resident Flutter with pet disclosure, pending feedback, private pass handling, callable cancellation/rescheduling and error handling. No Security Flutter release is required by this phase, but test existing installed versions.
5. On real devices verify owner/tenant creation, pending-without-pass, Admin decisions on both clients, QR and manual check-in on unchanged Security, one arrival notification, checkout, pet rejection/removal, emergency boundaries and community switching. Test older installed clients: no strict bypass, understandable denied operations. Require an agreed minimum supported client/upgrade path for old direct-write clients before activation; rules deliberately reject their writes under strict policy.
6. Obtain signoff for existing-pass and emergency operational treatment. An authorized operator can then set only the server-owned readiness flag for the validated community. The Admin subsequently enables policy through the audited revision-checked callable. Do not grant Admin clients direct access to readiness. Roll out community by community.

No deployment command was executed and no release artifact was built. Strict policy is **not production-ready to enable** until the client migration, production index readiness, minimum-client plan, operational signoff and end-to-end device checks are complete.

## Phase 2B application impact

| Application | Changes still needed |
| --- | --- |
| Admin Flutter | Keep Phase 1 navigation/queues; add policy/emergency/pet settings and history; replace approve/reject/delete with decision callables; use authorizationState for pending counts and outcomes, distinguish denial/entry; handle revisions/readiness lock |
| Admin Web | Same authoritative APIs/settings/queue/count/history migration; remove direct policy-sensitive visitor patches; responsive confirmation and failures |
| Resident Flutter | Pet checkbox, context/error feedback, pending authorization state and pass gating; callable cancellation/rescheduling; no policy decisions in Dart |
| Resident Web | Same Resident APIs and status/pet UX; remove actual legacy document-ID QR fallback; validate private credential shape and current lifecycle/denial; improve loading/retry/status refresh in existing pass component |
| Security Flutter | No source/UI/navigation changes. Existing QR/manual entry and checkout preserved; additive pet data is available in authorized backend responses and upcoming-list details, without revealing credentials or requiring new interactions |

Do not start those frontend changes as part of Phase 2A.
