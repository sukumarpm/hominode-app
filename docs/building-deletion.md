# Trusted building deletion

## API and atomicity

`validateBuildingDeletion` and `deleteBuilding` are registered through the existing
`appCheckedCallable` wrapper in `asia-southeast1`. Both use
`requireOperationalAdmin` inside a Firestore transaction. They require a selected
community, an existing building, and matching community ownership. No changes to
authentication, App Check, identity verification, or tenant routing were made.

Preflight returns `canDelete`, the current building name, actual unit count,
bounded reasons, conflict count, and planned write count. It performs no writes.
The final delete independently repeats the same transactional inspection. It
does not accept a client approval token or trust the earlier preflight result.

The transaction reads all canonical units for the building, dependency queries,
and any legacy owner-admin summary before writing. It deletes units, the building,
and eligible empty parking slots, fills missing historical display fields, and
removes that building from the owner's legacy summary arrays. It never clears
resident assignments or deletes resident/onboarding/security/history records.
Failed validation, failed commits, and transaction retries cannot partially delete.

No deletion marker or background deletion worker is introduced. Existing
reconciliation, reservation, approval, reassignment, and bulk-allocation
transactions already read the building and affected units. Their concurrent
changes serialize with deletion or cause revalidation/rejection. Real emulator
tests exercise reservation, reconciliation, reassignment, and bulk races.

## Dependency policy

`functions/src/building_deletion.js` contains the explicit `POLICIES` inventory.
Community-scoped scans inspect direct, array, and nested references. Separate
unscoped canonical building/unit queries catch direct legacy references lacking
community metadata, and conflicting community references block deletion without
revealing another community's resident data. Additional probes cover indirect
amenity bookings, gate/staff links, parking-slot vehicles, and bill payments.
Future modules adding physical building/unit allocations must extend this policy
and its tests; it is not a runtime discovery mechanism for arbitrary collections.

| Category | Policy |
| --- | --- |
| Unit documents | Only vacant or maintenance, with no `residentUserId`, `residentId`, `residentUid`, nonempty/malformed `residentIds`, or `reservedOnboardingId`. Unknown status/pointer data blocks. |
| `users`, legacy `residents` | Current references block, including suspended/deactivated residents. Explicit moved-out/rejected inactive history can remain; previous-only references remain history, even when a resident now occupies another building. |
| `residentOnboarding`, allocation/assignment/reservation records | Pending/claimed/active/unclear allocations block. Explicit unclaimed cancelled/released/rejected/expired onboarding can remain. Active label-only legacy onboarding with no canonical building reference blocks pending canonical repair, even when a rename makes its old label unrecognizable. Unrelated terminal history is not relabelled. |
| Parking and vehicles | Assigned vehicles and unresolved violations block. A strictly vacant parking slot with no resident, vehicle, user, or reservation pointer is the only automatically deleted child configuration. Indirect active vehicle references still block. |
| Amenities, gates, staff, security, vendors, family/emergency contacts | Active or unclear assignments/configuration block. Explicit inactive records with consistent states can remain; gates with assigned security still block. They are never automatically deleted. |
| Complaints, maintenance/service/emergency requests | Unresolved requests block. Explicit resolved/closed/completed/cancelled/rejected history remains. An unassigned maintenance unit is safe only after these checks pass. |
| Bills and payments | Unpaid/overdue/pending/unclear records block. Paid/void/cancelled bills and completed/failed/rejected/refunded/cancelled payments remain. |
| Visitors, parcels, attendance | Current/unclear activity blocks. Explicit terminal states or valid departure/completion timestamps remain. Empty/malformed departure values are not proof of completion. |
| Bookings, amenity bookings, marketplace requests | Pending/approved/confirmed/unclear requests block; explicit completed/cancelled/rejected history remains. |
| Notices, events, announcements, broadcasts, posters, pinned posts, listings | Building/unit-targeted active or unclear publications block. Explicit inactive/archived/expired/completed/closed/cancelled records remain. Admin visibility `buildingIds` metadata is not treated as a physical allocation in parking, vehicles, or notices; actual `buildingId`/`targetFlats` references are checked. |
| Documents, apartment images, posts, community wall, comments, reports, chats/messages, notifications | Retained independent content/history. Missing display fields are filled on relevant records; content and files are never deleted. |
| Resident import jobs/rows | Completed/committed/imported markers remain. Active/unclear work referencing the building blocks. Idempotency markers are not removed. |
| Audit logs | Existing entries remain append-only. A deletion audit preserves building/unit identity and label snapshots. |

Conservative checks can block inconsistent legacy data even when a unit looks
vacant. Resolve the underlying allocation/state; do not erase profiles or history
to make deletion pass. These checks validate the stored snapshot and the existing
trusted allocation transactions; they do not convert unrelated legacy module
write APIs into new lifecycle APIs.

## History, identity, and audit

Canonical document IDs and existing labels are never rewritten. Historical
references stay intact. Missing `buildingName`, `flatLabel`, `unitLabel`, or
previous-building/unit label fields are filled in the deletion transaction.
Multi-target historical records can receive an ID-keyed `deletedUnitLabels` map.
Existing names, timestamps, and business content remain unchanged. The complaint
model/screen now uses the stored label when the canonical unit no longer exists;
bills and visitors already use their stored `flatLabel`.

The deletion audit uses `buildAuditLog` and the existing best-effort audit
convention. It records actor, community, canonical building ID/name, timestamp,
unit count, and result. Its additional `buildingSnapshot` includes only canonical
unit IDs and labels, so older append-only audit references remain distinguishable
without storing resident names, phone numbers, or identity data.

**Audit persistence is separate from the atomic deletion.** Audit failures are
logged as critical and do not turn a completed deletion into a reported failure.
This follows the application's existing audit convention; it is not a durable
transactional outbox or guaranteed audit-delivery mechanism.

Creation continues to use Firestore auto IDs for buildings and units. Reusing a
visible building name therefore cannot reassign old canonical history to the new
building. The emulator verifies distinct replacement IDs.

## Limits

- At most 499 units, and at most **500 total transaction writes**, including the
  building, units, safe child configuration, history display repairs, and admin
  summaries. A 499-unit building fits when those 500 deletes are the entire plan.
  Any additional write blocks the complete operation before mutation.
- Automatic dependency review caps each query at 2,000 documents and the combined
  unique dependency set at 12,000 documents. Exceeding either cap fails closed.
  A large community may need a separately reviewed maintenance operation, even
  when the building itself is small. Queries use bounded concurrency.
- Firestore request/document-size and transaction deadlines still apply; any
  transaction failure leaves the data intact. No partial-delete fallback exists.
- A size conflict calls for a reviewed missing-label backfill or removal of
  genuinely unused child configuration, never deletion of meaningful history.

## UI and security rules

The existing page opens a small deletion dialog: checking state, then either a
conflict list or explicit red destructive confirmation with the actual unit
count and history-retention wording. Duplicate submissions and dismissal while
deleting are disabled. Server conflicts remain in the dialog, raw exceptions are
not rendered, and success appears only after the callable completes. Existing
building and unit Firestore streams remain the source of displayed data.

Rules now deny direct client deletion of buildings and canonical flats, and
require an existing parent building in the same community for client flat creation. This closes the
old client deletion bypass. No rules were weakened. Trusted Admin SDK lifecycle
operations retain access. Other navigation/back behavior is unchanged.

## Changed files and verification

- Backend: `functions/src/building_deletion.js`; callable registrations in
  `functions/src/index.js`.
- Admin: `services/building_service.dart`, `manage_buildings_page.dart`, new
  `models/building_deletion.dart`, new `widgets/building_deletion_dialog.dart`.
- History fallback: `services/complaint_service.dart`,
  `complaint_management_screen.dart`.
- Security/tests: `firestore.rules`, `functions/package.json`, new
  `buildingDeletion.unit.test.js` and `buildingDeletion.emulator.test.js`, added
  rule tests in `crossTenantRules.emulator.test.js`, and Flutter
  `test/building_deletion_test.dart`.

Focused verification covers all unit safety pointers, active/indirect/legacy
dependencies, historical preservation, custom labels, authorization, write
limits, transaction retries/failures, real races, live streams, replacement ID
uniqueness, and dialog loading/conflict/success/failure behavior. Existing
architecture/reconciliation/reservation/approval/bulk and tenant-scope regression
tests are included in the focused runs. Final results: 121 focused backend tests, 48 emulator tests, and 36 Flutter tests passed. The changed-file analyzer reports no errors, with 6 existing warnings and 112 existing informational findings; unrelated findings were not changed. `git diff --check` passes.

## Deployment

Deploy both **`validateBuildingDeletion` and `deleteBuilding`**, the tightened
Firestore rules, and the Admin app together. Deploy the functions before exposing
the new UI; old Admin clients will be unable to use their unsafe direct delete
path once the rules are deployed. No other callable deployment is required by
this change. Existing preceding architecture changes have their own deployment
requirements in `unit-architecture.md`.

No composite indexes are added: the new queries use existing automatic
single-field equality/`in`/array indexes (`fieldOverrides` is empty). No migration
or global backfill is required. Missing historical labels are repaired only for
the inspected building and only within its atomic write budget.

**No production deployment or production data mutation was performed.**
