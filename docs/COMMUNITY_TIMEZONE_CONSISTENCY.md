# Community timezone consistency — visitor workflow

Implementation and audit: November 14, 2026. Scope: visitor scheduling and presentation in Resident, Admin, Security, the two React web repositories, and the older Flutter web client. This does not establish application-wide timezone coverage.

## Root cause

`ResidentVisitTime` already interpreted configured community wall times and rejected DST gaps/folds. The invitation form used it, but the Resident visitor card read calendar components directly from `Timestamp.toDate()` and compared them with the device's `DateTime.now()`. QR details, Admin expected-arrival labels, and Security visitor cards similarly formatted device-local dates. Thus a correctly stored `2026-11-14T17:02:00Z` could appear as November 15, 1:02 AM on a Philippines device instead of November 14, 10:32 PM in India.

Additional issues were the Resident helper's missing-zone device fallback, the time picker's device-local initial time, the raw `Asia/Calcutta` form label, browser-local invitation input parsing, and the backend creation validator's use of the server's midnight.

## Existing configuration and helpers

- `communities/{communityId}.timeZone` is the existing authority. No second timezone field was added. `tenant_management.normalizeIanaTimeZone` validates community metadata, and `create_community` requires a timezone. The Admin create-community dialog passes that field through `CommunityInviteService`. Location updates do not infer or replace it from GPS/country.
- Admin mobile `TenantConfig` already exposes `timeZone`. Resident visitor scope reads it from the authenticated Resident's community. Security presentation resolves the staff assignment through `requireSecurityProfile`, then reads that community. Browser clients use their authorized session community and recheck authority before writes.
- Resident `CommunityModel` and shared core `TenantConfig` now preserve the same existing field when parsing community documents. The latter supplies the older Flutter web session.
- Existing helpers include Resident `ResidentVisitTime`, Admin `VisitorSchedule`, React `visitorArrival` / `visitorLocalTime` and `scheduleInstant` / `localSchedule`, backend `normalizeIanaTimeZone`, and booking `dayBounds`.
- The existing `functions/scripts/auditCommunityTimeZones.js` is a read-only configuration audit. It was inspected, not run against production. No production record was inspected or migrated for this change.

## Implemented contract

The small `hominode_time` package shares Dart timezone conversion, calendar-day comparisons, canonical India-alias display, and formatting. It depends only on the already-used `timezone` library. It does not pull the core package's spreadsheet dependencies into Resident or Security. Existing Resident/Admin scheduling entry points delegate to it.

Picker dates are calendar components. Combining a selected date and time produces a community wall-time string, converted to a UTC instant exactly once. Stored timestamps retain their epoch value. Presentation converts that instant to the community zone; it does not reconstruct or rewrite it. Missing/invalid zones report configuration errors and prevent scheduling. DST gaps and ambiguous new selections are rejected. An unchanged reschedule omits the arrival field, retaining stored seconds and the original instant, including an existing DST-fold appointment.

Scheduling controls identify the community zone; `Asia/Calcutta` is displayed as `Asia/Kolkata`. Appointment labels include an abbreviation and IANA identifier. Existing localization remains available for date text. Today/Tomorrow and Security day/week comparisons use community calendar dates. Absolute elapsed durations, pass deadlines, expiry comparisons, and authorization remain instant-based.

The backend change is necessary: `visitorFields` now checks the arrival against the community's start of today using the existing `dayBounds` helper. It reports missing/invalid timezone configuration. It still stores `Timestamp.fromMillis(arrivalMs)` and retains the existing credential window around that instant. Approval, gate authorization, token generation/formats, and Firestore rules were not changed by this task.

## Files changed by this task

These lists describe this task's edits; the workspace already contained substantial unrelated local changes.

| Application | Files |
| --- | --- |
| Shared Dart | `packages/hominode_time/pubspec.yaml`, `lib/community_time.dart`, `test/community_time_test.dart`; `packages/hominode_core/lib/src/tenant_config.dart` |
| Resident mobile | `resident_app/pubspec.yaml`; `lib/add_expected_visitor_modal.dart`; `lib/visitor_qr_screen.dart`; `lib/src/models/community_model.dart`; `lib/src/services/resident_visitor_policy_service.dart`; `lib/src/screens/visitor_management_screen_new.dart`; `test/resident_visitor_policy_integration_test.dart`; `test/visitor_qr_contract_test.dart` |
| Admin mobile | `hominode-admin/admin_app/pubspec.yaml`; `lib/services/visitor_policy_service.dart`; `lib/services/visitor_service.dart`; `lib/visitor_management_screen.dart`; `lib/qr_gate_scanner_screen.dart`; `test/visitor_management_rejection_test.dart` |
| Security mobile | `security_app/pubspec.yaml`; `lib/screens/visitor_management_screen.dart`; `lib/models/visitor_model.dart`; `test/visitor_workflow_screen_test.dart` |
| Older Flutter web | `hominode_web/pubspec.yaml`; `lib/src/pages/resident_visitors_page.dart`; `lib/src/pages/admin_visitors_page.dart`; `lib/src/services/resident_visitor_service.dart` |
| Functions | `functions/src/visitor_credentials.js`; `functions/test/visitor_credentials.test.js`; `functions/test/visitorPhase1.firestore.emulator.test.js`; `functions/test/visitorCallables.emulator.test.js` (configured-community fixture updates) |
| Admin React web, sibling repository | `src/actions.ts`; `src/pages.tsx`; `src/VisitorDecisionActions.tsx`; `src/visitorPolicy.ts`; `src/test/communityVisitorTime.test.ts` |
| Resident React web, sibling repository | `src/actions.ts`; `src/pages.tsx`; `src/residentVisitor.ts`; `src/residentVisitorService.ts`; `src/components/ResidentVisitorForm.tsx`; `src/test/communityVisitorTime.test.ts`; `src/test/residentVisitor.test.tsx`; `src/test/residentVisitorService.test.ts` |
| Documentation | This report |

Canonical `expectedArrival` now takes precedence over the legacy `expectedTime` field when both exist. Browser detail fields suppress the competing legacy value. The React QR component itself displays no appointment/validity timestamp; its surrounding visitor details now use community time. Security gate receipts display no appointment timestamp and retain their existing server-owned outcome behavior.

## Validation

| Checks | Result |
| --- | --- |
| Shared Dart timezone tests | 5 passed; also passed under `TZ=Asia/Manila` and `TZ=Asia/Kolkata` |
| Resident Flutter: policy integration, pass, lifecycle, QR contract | 76 passed, including a Philippines process timezone run |
| Admin Flutter: policy integration, phase 1, management rejection, service rejection | 76 passed |
| Security Flutter: workflow screen, scanner receipt, model status | 39 passed; workflow/model tests also passed under `TZ=Asia/Kolkata` |
| Resident React: community time, visitor form/actions, service, QR | 39 passed |
| Admin React: community time, policy UI/service, transitions | 61 passed |
| React timezone helper matrix under the alternate device zone | Passed for both repositories |
| Node: credentials, gate, policy, policy management/resolver, verification, Security workflow, booking timezones | 90 passed, 1 pre-existing rollout-readiness failure |
| Local Firestore emulator: phase 1, Resident clients, verification, policy | 46 passed, 2 pre-existing rollout-readiness failures |
| TypeScript `tsc --noEmit`, both repositories | Passed |
| Shared Dart analysis; targeted Resident, Security, older Flutter web analysis | No errors; final QR analysis clean |
| Targeted Admin Flutter analysis | No errors; existing warnings/information remain, including unused `_fadeAnimation` |
| Targeted browser ESLint | No errors; existing Resident `useEffect` dependency warning remains |
| Syntax and whitespace | `node --check functions/src/visitor_credentials.js` and `git diff --check` passed |

Coverage includes India/Philippines in both directions, New York/India, London DST gaps/folds and adjacent valid times, correct UTC submission, no double conversion, canonical alias display, missing/invalid configuration, midnight date labels, cross-role widget presentation, unchanged seconds, and a browser reschedule through an existing DST fold. Existing approval, credential-window, denial, checkout, and gate-entry tests ran alongside these checks.

The three failing tests are:

1. `visitor_policy_management.test.js`: “unconfigured policy returns canonical zone, zero write revision and blocked readiness” — expects `rolloutReady == false`, receives `true`.
2. `visitorPolicy.firestore.emulator.test.js`: “Admin policy authority, rollout lock, optimistic revisions and append-only audit” — expected rollout-lock rejection does not occur.
3. The same emulator file: “scheduled saves require future instants, canonical community zone and current rollout readiness” — expects blocked readiness, receives `true`.

All three failures were reproduced with this task's backend timezone imports/validator removed in memory, while leaving the user's existing working files unchanged. Rollout-readiness behavior is outside this timezone fix and was not altered. The full selected backend checks are therefore not green.

Useful reproduction commands, from the indicated application directories:

```sh
# packages/hominode_time
TZ=Asia/Manila dart test
TZ=Asia/Kolkata dart test

# resident_app
flutter test --no-pub test/resident_visitor_policy_integration_test.dart test/resident_visitor_pass_test.dart test/resident_visitor_lifecycle_test.dart test/visitor_qr_contract_test.dart

# hominode-admin/admin_app
flutter test --no-pub test/visitor_policy_integration_test.dart test/visitor_phase1_test.dart test/visitor_management_rejection_test.dart test/visitor_service_rejection_test.dart

# security_app
flutter test --no-pub test/visitor_workflow_screen_test.dart test/visitor_scanner_receipt_test.dart test/visitor_model_status_test.dart

# functions
node --test test/visitor_credentials.test.js test/visitor_gate.test.js test/visitor_policy.test.js test/visitor_policy_management.test.js test/visitor_policy_resolver.test.js test/visitor_verification.test.js test/security_visitor_workflow.test.js test/amenityBooking.timezones.test.js

# functions, with a local Firestore emulator already listening
FIRESTORE_EMULATOR_HOST=127.0.0.1:8087 GCLOUD_PROJECT=demo-hominode-timezone node --test --test-concurrency=1 test/visitorPhase1.firestore.emulator.test.js test/visitorResidentClients.firestore.emulator.test.js test/visitorVerification.firestore.emulator.test.js test/visitorPolicy.firestore.emulator.test.js
```

Run `npm test --` followed by the four visitor test files listed above in each browser repository; run `npm run typecheck` for static checks. Test output for this session is in `/private/tmp/hominode-timezone`.

## Remaining standardization work

| Workflow | Verified state and remaining work |
| --- | --- |
| Facility bookings | Backend `amenity_booking.js` requires community IANA configuration, preserves selected date-only keys, and computes DST-aware day boundaries. Its timezone tests passed. Resident `booking_modal.dart` and `calendar_grid.dart` still derive Today/current month/past-date UI from device `DateTime.now()`. `booking_firestore_service.dart` explicitly sends the picker's device offset to preserve a selected calendar date; this is a date-only contract, not an appointment conversion to blindly replace. Migrate calendar UI and date-only presentation separately. |
| Visitor policy schedules | Existing Admin/browser conversion rejects DST gaps/folds and submits absolute instants; server policy resolution uses absolute effective times and enforces community-owned timezone input. Existing scheduling tests ran. The independent rollout-readiness failures above remain. |
| Security dashboard visitor counters | `security_visitor_summary.js` already resolves the authorized staff community timezone and uses `dayBounds`; the dashboard shows its community date and zone. Staff attendance/activity time labels elsewhere still read device-local components and need a separate pass. |
| Events | Admin `widgets/create_event_modal.dart` uses device-based picker bounds and constructs `DateTime(year, month, day)` while storing a separate time string. Define whether each field is a calendar date or an appointment, then convert actual event starts using community time. Resident event presentation must be audited with that contract. |
| Complaints / maintenance | Inspected paths display request creation/resolution timestamps using existing device-oriented helpers/fallbacks. No distinct maintenance appointment contract was verified in those paths. Standardize timestamp presentation and inspect any appointment feature separately; do not reinterpret creation dates as scheduled visits. |
| Deliveries | `parcel_delivery_tracking_screen.dart` records collection with `DateTime.now()`. Capturing an absolute occurrence is valid; community-local presentation and any expected-delivery scheduling still need review. |
| Announcements / notices | Inspected announcement UI includes a device-generated ISO string for `createdAt`; no complete scheduled-publication path was verified. Establish publication timestamp/date-only semantics and audit its consumers before claiming coverage. |
| Billing | Inspected backend recurring billing and due-date validation already use community `timeZone` and calendar keys (`billing_schedule.js`, `payment_v2.js`, `billing_revision.js`). The UTC scheduler cadence is not a community appointment. Frontend billing/date-only display was not migrated or exhaustively verified. |

No deployment, commit, push, security-rule change, production data migration, or bulk timestamp rewrite was performed. Existing correctly stored appointment instants retain their meaning. Manual on-device visitor QA and configuration review of live communities remain separate from these automated checks.
