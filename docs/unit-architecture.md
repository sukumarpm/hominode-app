# Generalized housing and canonical unit identity

The Admin app still stores structures in `buildings` and units in `flats`.
`flats/{documentId}` is the canonical unit identity used by residents,
onboarding, reservations and approval. A unit's `flatLabel`, legacy `flatId`,
and legacy `unitId` are display references. They are never allocation IDs.
BHK stays in `type` / `bhkType`; the new `unitType` is the housing category.

## Additive schema

| Document | Field | Values / meaning |
| --- | --- | --- |
| Building | `structureType` | `apartment_building`, `villa_cluster`, `row_house_cluster`, `townhouse_cluster`, `mixed`, `other` |
| Unit | `unitType` | `apartment`, `villa`, `row_house`, `duplex`, `townhouse`, `other` |
| Unit | `unitIndex` | Positive stable position for a cluster; absent for apartments |
| Unit | `unitLabelNormalized` | NFKC, trimmed, case-insensitive label with collapsed whitespace |

Missing structure/unit types are interpreted as apartment building/apartment.
Reads do not backfill documents. Current labels use the first nonempty value of
`flatLabel`, `flatId`, `unitId`. A stale legacy alias does not override a current
custom `flatLabel`. The normalized field is written by creation and rename;
matching still computes normalization from the current label so legacy and stale
normalized fields remain safe.

Apartment reconciliation retains `floor` + `flatNumber`. Clusters use
`unitIndex`; their legacy `floor` is 0 and `flatNumber` mirrors the index for old
numeric readers. The Admin UI displays no floor for indexed units. Cluster
buildings store 0 for legacy floor dimensions and use actual `totalFlats`.
Mixed/Other use the same simple indexed layout and a unit-type selector, including
Duplex. There is no nested block/street/floor hierarchy or automatic repartition.
Existing heterogeneous unit types are preserved unless explicitly changed.

Switching between apartment and indexed layouts requires an unchanged unit count
and complete, unambiguous source positions. Conversion updates position metadata
on the same documents, including resident-linked units. Change type first, then
expand/reduce separately. Existing IDs, labels, links and creation timestamps
survive. Invalid positions and unsafe removals fail before writing.

## Trusted writes and limits

`createBuilding` and `reconcileBuilding` use authorized server transactions and
App Check protected callable wrappers in `asia-southeast1`. Creation/reconciliation
share generation logic. The layout limit remains 499 units and each edit remains
one transaction with at most 500 writes, including synchronized references.
Existing rules, tenant context, authentication, App Check configuration, navigation
and identity requirements are unchanged.

Rename queries the building's current units inside its transaction, rejects
case-insensitive duplicates, and synchronizes current resident/onboarding display
references. Labels may repeat in different buildings. Existing duplicate legacy
labels are not silently repaired: rename/import reports a conflict.

## Bulk import and updates

CSV/XLSX columns are unchanged: Building and Unit contain the current building
name/reference and visible custom unit name. Resolution is scoped to the selected
community and building and must identify exactly one unit document. Current
building document IDs are also accepted as building references. Unit position
numbers and document IDs are not alternate display-label guesses.

Validation rejects missing/wrong-building/ambiguous labels, duplicate phones,
duplicate allocations (including tenants), occupied/reserved units, malformed
resident pointers and conflicting existing allocations.

Each imported row is atomic, rather than the entire file. Every row transaction
rechecks authorization, current references, profiles and unit state. A successful
new row creates pending, unverified onboarding and reserves its canonical unit in
the same commit, along with occupancy counters and the import marker. An existing
unclaimed onboarding may reserve a vacant unit or update its own matching
reservation. It must cancel its reservation before moving elsewhere.

An existing resident on the same canonical unit can receive contact/display
updates. Approval, resident type, identity flags and allocation IDs are preserved.
Active residents are never automatically moved out by import. A previously
moved-out eligible resident goes through `reassignResidentCore`, with its import
marker/contact update attached to that same transaction. The original identity,
role, vacancy and moved-out checks still apply.

Successful row markers record the normalized input and canonical allocation.
An identical job/row retry does not allocate twice. Changed contents for a
completed row require a new import job. Legacy completed markers without a
fingerprint remain completed and cannot cause another write. Failed rows may be
corrected/retried using the existing screen.

## Deployment

Deploy backend functions before releasing the updated Admin Flutter app:

- `createBuilding` (new)
- `reconcileBuilding`
- `renameUnit`
- `validateResidentBulkImport`
- `importResidentsBulk`
- `assignResidentOnboardingToFlat`
- `reassignResident`

Target project: `hominode-prod`; region: `asia-southeast1`.
No Firestore rules changes or new composite indexes are introduced. Queries use
existing/equality-indexable community, building, phone and unit-reference fields;
normalized labels do not require a new index. No migration, backfill, collection
rename, canonical-ID rewrite, or production deployment was run.

## Main implementation files

- `functions/src/unit_schema.js`: normalization, vacancy and statistics helpers.
- `functions/src/building_reconciliation.js`: shared creation/reconciliation.
- `functions/src/resident_identity.js`: normalized rename and trusted lifecycle integration.
- `functions/src/resident_bulk_import.js`: custom-label validation and atomic import/update.
- `functions/src/index.js`: callable registration.
- `hominode-admin/admin_app/lib/models/unit_schema.dart`: typed compatibility helpers.
- `hominode-admin/admin_app/lib/services/{building_service,flat_service}.dart`.
- `hominode-admin/admin_app/lib/widgets/add_building_modal.dart`.
- `hominode-admin/admin_app/lib/manage_buildings_page.dart`.
- `hominode-admin/admin_app/lib/widgets/flat_{occupancy_grid,details,occupied,maintenance}_modal.dart`.
- `hominode-admin/admin_app/lib/resident_bulk_import_screen.dart`.

Focused backend tests are in `buildingReconciliation.unit.test.js` and
`residentBulkImport.unit.test.js`. The new `unitArchitecture.emulator.test.js`
is registered in `npm run test:emulator`; emulator files run sequentially because
they share one emulator, while race tests explicitly run concurrent operations.
Flutter coverage includes `unit_architecture_test.dart`, the existing building
edit tests, import screen tests, flat-scope tests, and tenant-context/session tests.

## Validation results (2026-09-07)

- Focused reconciliation/import backend tests: 65 passed.
- Registered Firestore emulator suite: 40 passed, including real transaction races,
  reservation/cancellation, OTP claim, approval, and type-conversion round trips.
- Relevant Flutter tests: 29 passed.
- Focused analyzer on all changed Flutter files: no errors; 8 existing warnings
  and 179 informational diagnostics remain.
- Full backend unit suite: 177 passed, 2 pre-existing failures remain in the
  resident-approval error-message assertion and the community-slug update test.
- JavaScript syntax checks and `git diff --check` passed.
