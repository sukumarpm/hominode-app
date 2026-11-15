# Visitor Management Phase 2B-1 — Admin integration

Implemented locally on 2026-11-09 against the current working trees and the complete [Phase 2A handoff](VISITOR_MANAGEMENT_PHASE_2A.md). Nothing deployed. No production Firestore data accessed or modified. Phase 1/2A and unrelated local changes were preserved.

## Functionality

Both Admin clients now provide **Visitor Approval Settings** in their existing Settings area. Flutter: Settings → Community Settings, below payment settings. Web: Settings, below community payment settings.

The forms load authoritative configuration and support exactly:

- No Admin approval required (`resident_authorized`).
- Tenant invitations require approval (`tenant_approval_required`).
- All invitations require approval (`all_approval_required`).
- A nullable emergency interval, with explicit start/end and cancellation through a null interval.
- Pets allowed, not allowed or temporarily restricted, including the normal pet policy outside the temporary restriction.

**All saves explicitly send `enabled: false`. There is no enforcement switch and neither client writes the readiness flag.** An unexpectedly enabled backend policy is displayed read-only. The UI makes clear that settings are staged and do not activate restrictions during this release.

Date/time inputs use the backend's canonical community `timeZone`. Both clients convert wall time to epoch milliseconds and reject invalid calendar dates, end-before-start, skipped DST times and repeated/ambiguous DST times. They require a different, unambiguous time instead of silently choosing an offset. Flutter's picker keeps calendar components independent of the device timezone. A missing community timezone prevents saving until it is configured through community administration.

Scheduled/active/expired labels use the last **serverTime** returned by the callable and show the time/zone context. Reload and foreground/focus refresh obtain a new server snapshot; no local timer changes policy or claims authority over expiry. Community revision subscriptions pick up changes from the other Admin platform. Unsaved edits are retained, but a changed revision blocks saving until reload. Request generations/community keys discard late responses from an earlier community.

Both forms explain prospective emergency behavior (existing authorized passes remain valid, pending decisions stay pending after expiry, emergency operations remain separate) and pet restrictions covering the full arrival ±24-hour credential window, including existing declared-pet passes.

Visitor Management now separates **Pending approval**, **Expected / authorized**, **Inside**, and **History**. Existing navigation remains. Flutter keeps the original Expected/Inside/History indices and adds Pending approval as index 3. Managed pending invitations appear only in the review queue; auto/Admin-authorized invitations remain expected until Security checks them in. Rejected, revoked, gate-denied, cancelled, completed and unrecognized legacy records remain visible. Optional legacy decisions remain available without claiming mandatory approval. Managed pending counts use authorization state; Flutter retains its Phase 1 count fallback for legacy records without policy metadata.

Approve/reject requires confirmation, locks repeated/conflicting submissions, sends the **displayed revision**, and waits for the callable before reporting success. Stale decisions show a reload/review message and refresh the queue. No client manufactures physical arrival or marks an authorized invitation inside. Web's old generic visitor direct-write path now refuses mutation. Flutter's approval/rejection methods use the callable for both managed and legacy invitations. Existing narrow checkout behavior is unchanged.

Responsive corrections needed for the fourth queue were limited to the visitor UI: Flutter's header uses normal logical sizing on tablets, tabs wrap, list height follows available viewport constraints, empty content can scroll, and tab listeners can resubscribe safely. Web's visitor table anchors its absolute accessibility captions inside the existing horizontal scroller so they cannot widen a 393px page.

## Contracts consumed

Region remains `asia-southeast1`, with existing Phone Auth/App Check integration.

| API | Request | Client handling |
| --- | --- | --- |
| `getCommunityVisitorPolicy` | `{communityId}` | Validates returned community, uses policy revision and serverTime |
| `updateCommunityVisitorPolicy` | `{communityId, policy, expectedRevision}` | Whitelists only schemaVersion, enabled=false, timeZone, approvalMode, emergency, pets; reloads authoritative policy after confirmed save |
| `decideVisitorInvitation` | `{communityId, visitorId, action: approve/reject, expectedRevision}` | No actor/recipient ID supplied; no creation or physical entry writes; displays backend failures |

Existing community documents are observed for revision changes; existing community-scoped visitor queries remain the data source. The backend remains the authority for Admin membership, resident eligibility, approval, pet enforcement and gate entry. No API names or backend schemas changed. No backend/rules/index changes were necessary in this phase.

Both test suites consume [the same JSON contract fixture](fixtures/visitor_policy_contract.json), covering exact load/save/decision shapes. Policy metadata and rollout readiness are never echoed into update requests. The older clients' direct approval mutations and lack of authorization-state models were compatibility gaps repaired here, not Phase 2A API mismatches.

## Files changed

Admin Flutter, relative to `hominode-admin/admin_app/`:

- `lib/services/visitor_policy_service.dart` — new callable/configuration/timezone support.
- `lib/widgets/visitor_policy_settings_card.dart` — new settings form and lifecycle/revision refresh.
- `lib/community_settings_screen.dart` — settings integration.
- `lib/services/visitor_service.dart` — callable decisions, displayed revisions and authorization-aware model fields.
- `lib/services/visitor_lifecycle.dart` — managed authorization classification/counts and labels.
- `lib/visitor_management_screen.dart` — fourth queue, confirmation/locking, separate state labels, refresh and responsive sizing.
- `pubspec.yaml` — declares the already-cached `timezone` 0.10.1 package directly.
- `test/visitor_policy_integration_test.dart` — new policy, service, error, contract and responsive tests.
- `test/visitor_phase1_test.dart` — preserves navigation/queues and adds managed pending coverage.
- `test/visitor_management_rejection_test.dart` — confirms decisions before submission and checks server-confirmed outcomes.

Offline dependency resolution also updates the local, Git-ignored `pubspec.lock` classification of timezone from transitive to direct; no dependency version upgrade was performed.

Admin Web, relative to `/Users/sukumarmuthiah/Documents/hominode-admin-web/`:

- `src/visitorPolicy.ts` — new types, presentation classification and timezone conversion.
- `src/visitorPolicyService.ts` — new scoped callable integration and error handling.
- `src/VisitorPolicySettings.tsx` — new policy form and revision/focus refresh.
- `src/VisitorDecisionActions.tsx` — new authorization details, confirmation and submission locking.
- `src/visitorPolicy.css` — scoped responsive settings/queue/table styles.
- `src/pages.tsx` — settings, queues and detail/action integration.
- `src/actions.ts` — prevents legacy generic visitor mutations.
- `src/test/visitorPolicy.test.tsx`, `src/test/visitorPolicyService.test.ts` — new tests.
- `e2e/visitorPolicy.spec.ts` — focused offline browser checks.
- `e2e/data.ts`, `e2e/harness.tsx` — synthetic policy/visitor fixtures and injected offline service implementations, excluded from production entry points.

Shared additions: this report and `docs/fixtures/visitor_policy_contract.json`.

## Validation results

- **53 Flutter tests passed** across `visitor_policy_integration_test.dart`, `visitor_phase1_test.dart`, `visitor_service_rejection_test.dart`, and `visitor_management_rejection_test.dart`. Covers contract payloads, all normal/pet modes, emergency dates/cancellation, stale/permission failures, loading, confirmed save, duplicate prevention, community rejection, pending versus physical state, iOS navigation, and 393/600/800px layouts at text scales 1.0/1.3.
- Targeted Flutter analysis: **zero errors**. The existing unused `_fadeAnimation` warning and 23 existing print/deprecation notices remain. Newly introduced analyzer notices were corrected. Dart formatting completed.
- **182 Web tests passed** across the two new policy files and existing visitor-transition, navigation and actions tests. The actions module was included because its visitor mutation guard changed; this was not the full application suite.
- **9 offline Chrome checks passed**: policy/confirmation and all visitor queues at 393/600/800/1440px, plus loading/empty/error states. Production HTTPS requests were blocked. The dedicated policy harness injects synthetic services; it does not exercise deployed callables.
- TypeScript typecheck, targeted ESLint and production Vite build passed. Vite reports a non-blocking chunk-size warning above 500 kB. New Web files were formatted; no unrelated mass formatting was performed.

Focused commands:

```sh
# Admin Flutter
flutter test --no-pub test/visitor_policy_integration_test.dart test/visitor_phase1_test.dart test/visitor_service_rejection_test.dart test/visitor_management_rejection_test.dart
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings lib/services/visitor_policy_service.dart lib/widgets/visitor_policy_settings_card.dart lib/services/visitor_service.dart lib/services/visitor_lifecycle.dart lib/visitor_management_screen.dart lib/community_settings_screen.dart test/visitor_policy_integration_test.dart test/visitor_management_rejection_test.dart test/visitor_phase1_test.dart

# Admin Web
npm run typecheck
./node_modules/.bin/vitest run src/test/visitorPolicy.test.tsx src/test/visitorPolicyService.test.ts src/test/visitorTransitions.test.ts src/test/navigation.test.tsx src/test/actions.test.ts
./node_modules/.bin/playwright test e2e/visitorPolicy.spec.ts --reporter=line
npm run build
```

## Deployment dependencies and manual verification

Deployment is **not authorized and was not performed**. These clients depend on the Phase 2A callables, reviewed visitor rules and other Phase 2A gate protections being deployed first, with enforcement disabled. A missing callable must be resolved through the backend release; there is deliberately no fallback to direct approval writes. This phase adds no new index; retain Phase 2A's audit-history index for its history endpoint.

In staging, after the reviewed Phase 2A foundation is available:

1. On Admin Web and Admin Flutter (iOS and Android), open the same community's Visitor Approval Settings. Save each normal mode, reload, and confirm it appears on the other platform. Verify the stored policy remains disabled and readiness is unchanged.
2. Test schedules while the device/browser timezone differs from the community. Check future, active and expired periods using a server refresh; reject invalid/end-before-start and DST-ambiguous times. Cancel an emergency interval. Test all pet modes and the normal policy after temporary restriction.
3. With unsaved edits open on one platform, save from the other. Confirm the first retains its draft, blocks stale saving and requires reload. Switch communities during a load/save and confirm no prior-community state appears or action targets the newly selected community incorrectly.
4. Use **synthetic managed pending fixtures in staging**, rather than enabling production policy. Confirm pending → Admin-authorized → Expected; it must not become Inside from an Admin decision. Confirm reject/history and two-Admin conflicting decisions. Verify unauthorized/cross-community attempts fail server-side.
5. On the unchanged Security app, scan/manual-enter an authorized pass, verify automatic check-in and one Resident arrival notification, then checkout. Confirm pending/rejected/revoked credentials remain blocked by Phase 2A. Verify existing SOS behavior operationally; this phase did not alter it.
6. Verify phone, 7-inch, 10-inch and desktop layouts with real content and text scaling. Keep enforcement disabled after all checks.

Actual deployed callable/App Check behavior, live cross-platform updates, physical-device presentation and live push delivery still require these staging/device checks. Unit/offline browser tests are not a claim that the deployed backend was exercised.

## Remaining Phase 2B-2 Resident work

Both Resident clients still need pet disclosure, authorization/pending feedback, advisory context calls, pass availability driven by backend authorization, callable cancellation/rescheduling and revision/error handling. Resident Web additionally needs its legacy document-ID QR fallback removed and private credential validation/status refresh brought to Flutter parity. No Resident source was edited in this phase.

Do not enable enforcement until that work, supported-version/upgrade planning, Phase 2A operational signoff, backend/rules deployment and real-device verification are complete. No readiness flag was changed, no policy was enabled, and no IPA/AAB was built. Stop at Phase 2B-1.
