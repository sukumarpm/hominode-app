# Photo ownership contract V2 — backend foundation

Local implementation only. No deployment, production reads/writes, media requests,
reclassification, migration, or client changes are part of this task.

## Schema and compatibility boundary

Descriptive `type`/category never grants access. The uploader `ownerId` remains the
Firebase Auth UID, distinct from the resource's ownership scope.

| Version                    | Metadata collection           | Binding                                                                                                       |
| -------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Omitted (existing clients) | `apartmentImages/{imageId}`   | Existing building-linked, **unclassified** community-visible gallery contract                                 |
| 2                          | `apartmentImagesV2/{imageId}` | Immutable `contractVersion: 2`, `ownershipScope`, `resourceId`, canonical `communityId`; derived fields below |

| `ownershipScope` | `resourceId`                                      | Derived fields              | Resident read                                                                                  |
| ---------------- | ------------------------------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------- |
| COMMUNITY        | `communities/{id}` document ID                    | No `buildingId` or `unitId` | Operational resident in that active community                                                  |
| BUILDING         | `buildings/{id}` document ID                      | `buildingId`                | Operational resident currently assigned to that building and community                         |
| UNIT             | `flats/{id}` **document ID**, never display label | `buildingId`, `unitId`      | Same canonical unit/building/community, occupied unit, reciprocal unambiguous current occupant |

A separate **metadata** collection is necessary: existing clients query all active
community `apartmentImages`. Mixing restricted V2 records into that collection
would either break those queries or expose restricted metadata. Storage bytes,
reservations (`storageImageUploads`), callable names and lifecycle remain shared.
The old collection and its Rules match remain byte-identical. Old clients do not
see V2 records; new clients must explicitly consume them. No dual writes.

V2 UNIT writes are Admin-only, as are existing apartment-gallery writes. UNIT
reads use `users/{uid}.flatId` and `.buildingId` plus `flats/{unitId}.communityId`,
`.buildingId`, `.status == occupied`, and `.residentUserId == uid`. Existing alias
pointers, if present, must agree. `residentIds` may only be empty or `[uid]`.
Canonical registration/assignment in `resident_identity.js` already establishes
these pointers. Missing, stale, conflicting, or multiple-occupant pointers deny
UNIT reads; there is no category/label/phone lookup fallback. Supporting additional
household members requires a separately approved membership contract, not a bypass.
Security staff receive no new image permissions.

## Existing callables, opt-in evolution

All callables retain `asia-southeast1`, Auth/phone binding and enforced App Check.

1. `prepareStorageImageUpload` accepts the old payload unchanged. For V2 add
   `contractVersion: 2, ownershipScope: COMMUNITY|BUILDING|UNIT`, retaining
   `feature: apartment, resourceId, contentType, size`. Server fetches the canonical
   target chain and authorizes the Admin's community. Caller-supplied `communityId`,
   `buildingId`, `unitId`, owner, bucket, path and roles are rejected.
2. Upload bytes to the returned staging path using the **existing five** metadata
   fields: `assetId, ownerId, communityId, feature, resourceId`; MIME/size/create-only
   Storage Rules are unchanged. Community uploads require no building document.
3. `completeStorageImageUpload({assetId})` rechecks the reservation's scope and
   current authorization, verifies bounded image bytes with existing Sharp checks,
   writes private/token-free bytes and removes staging. Permanent object metadata
   adds server-written string `contractVersion: "2"` and `ownershipScope`.
4. `saveApartmentImage` keeps its existing payload. It derives the metadata
   collection and scope from the finalized asset, never from descriptive category.
   V2 results add `contractVersion: 2` to `{imageId, revision}`. Retries attach once.
5. `readStorageImage({assetId,...existing cache fields})` chooses the metadata
   collection from the server asset. It validates binding, generation, current
   community/resource/recipient permissions and rechecks after download. Cached
   generation matches still reauthorize. No public download URLs are minted.
6. Replacement uses the existing `imageId, expectedRevision` save payload and a new
   finalized asset. Version, scope, community, building and unit must match exactly.
   The record update commits before retirement of the old asset. No implicit
   legacy-to-V2 conversion or reparenting is allowed.
7. `deleteApartmentImage` accepts old requests unchanged. V2 requests **must add**
   `contractVersion: 2` alongside `imageId, expectedRevision`. Collection selection
   never falls back. Tombstones use the existing `apartmentImageDeletes` collection
   with `v2_<imageId>` IDs; the binding is retained for idempotent retries.
8. Existing cleanup code resolves V2 references in the proper collection and keeps
   the existing exact-generation/orphan protections. No scheduler activation is
   authorized. Existing retention/cleanup operational prerequisites still apply.

Firestore V2 metadata is read-only to clients; no client can create, replace,
reclassify, delete or edit its bindings. Private Storage remains inaccessible to
clients. Storage Rules need no change; finalization remains the publication gate.

## Legacy handling and deterministic dry-run plan

No category, title, building association, URL or filename is evidence of new scope.
Existing records remain unclassified and retain their prior authorized workflows,
including community-wide legacy reads. Historical URLs are never fetched or moved.

A later separately authorized dry run can operate on an explicitly supplied,
offline metadata export (not customer image bytes). No export is requested here:

1. Fix the snapshot timestamp and checksum; sort input collection/document IDs.
2. Report versioned records against their explicit immutable bindings. For every
   unversioned record report `UNCLASSIFIED`; independently validate its referenced
   building/community, asset ID, state, generation and revision where present.
3. Emit deterministic findings: missing target, conflicting tenant, missing or
   malformed asset, duplicate reference, absent revision, or `owner review needed`.
   Do not infer COMMUNITY/UNIT from `Common Area` or a unit-looking display label.
4. Produce counts and document IDs without personal data, URL tokens or file bytes;
   sort findings by collection, document ID, finding code. Repeat against the same
   export and compare report checksums.
5. Any migration requires an owner-approved per-record scope manifest plus fresh
   expected revisions/target checks. A separate controlled migration implementation
   must preserve or explicitly revoke old shared visibility. Copying a confidential
   UNIT asset while leaving its old community-readable reference is not secure.
   This foundation deliberately provides no automatic migration endpoint.

## Stage B clients

- Shared Flutter `StorageImageAsset` parser/serializer: retain version/scope and
  optional building/unit IDs; don't require a building for COMMUNITY.
- Admin Mobile/Web: explicit Community and building/unit management contexts;
  send V2 prepare fields; store/display only returned bindings; V2 delete version;
  accessible confirmation modal names the exact scope/photo. Preserve order,
  pending previews, progress and retry state. Do not default a Community upload to
  the first building. Old unclassified media must have a clearly separate legacy view.
- Resident Mobile/Web: separate queries on `apartmentImagesV2` by selected scope,
  active status and assigned canonical resource. Include `contractVersion == 2`,
  `ownershipScope`, `communityId`, `resourceId`, plus `buildingId`/`unitId` as
  applicable. Use existing opaque references/read callable. Update private adapter
  validation so COMMUNITY assets don't require a building; never fallback from a
  rejected private reference to an old public URL.
- Stop mobile community aggregation from including V2 BUILDING/UNIT records. Keep
  legacy galleries separate rather than declaring them scoped. Logout, reassignment
  and community changes must discard cached private bytes and subscriptions.
- Use bounded client sorting by existing creation timestamps; any added server
  ordering/composite indexes must be separately reviewed/tested before rollout.

## Deployment and rollback (commands NOT executed)

First recheck production Rules freshness against the locally captured baseline.
The minimal Rules contain earlier approved local changes; do not deploy unrelated
pending Rules accidentally. Review the complete scoped diff before deploying.

From the root checkout, after approval:

```sh
functions/node_modules/.bin/firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only firestore:rules
functions/node_modules/.bin/firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only functions:prepareStorageImageUpload,functions:completeStorageImageUpload,functions:saveApartmentImage,functions:readStorageImage,functions:deleteApartmentImage
```

No Storage Rules, indexes, Hosting, billing, visitor, SOS, draft/resident image
callables or cleanup schedulers are selected. If `cleanupApartmentImages` is already
active, its collection-resolution update must be selectively deployed **before V2
writes**, using `--only functions:cleanupApartmentImages`; do not deploy it merely
to enable scheduling when currently inactive. No production status was queried here.

Deploy Rules first (new namespace only; legacy unchanged), then all five image
handlers, then updated Stage B readers/management clients. Allow new V2 writes only
after cross-client acceptance. Deployment alone does not fix current web scope/UI.

Before V2 writes, rollback to the saved prior Rules/Functions artifact is safe.
After V2 writes, stop new V2 management actions and retain V2 readers/lifecycle
handlers while rolling forward; blindly reverting to old Functions makes V2 reads
unavailable. A prior Rules rollback denies the new namespace rather than opening
it; legacy remains available. Do not downgrade scope or copy V2 references into
legacy records. Preserve assets/tombstones; no automatic destructive rollback.

## Focused verification

- Unit: storage image, apartment image, resident image, V2 scope and export/discovery
  tests; no broad application/financial suites.
- Firestore + Storage emulator project: `demo-hominode-storage-images`, loopback only.
  Run `photoOwnership.emulator.test.js` and existing `storageImages.emulator.test.js`
  sequentially with `HOMINODE_STORAGE_RULES_VARIANT=minimal`; repeat V2 tests against
  release Rules. Tests use synthetic records and a tiny local JPEG only.
- Acceptance: zero-building COMMUNITY upload; building separation; canonical UNIT
  and reciprocal occupancy; denial of foreign/revoked/malformed requests; immutable
  scope/replacements; revision/delete retries; old request/query compatibility;
  token-free private objects; post-read revocation; exact scope gallery selection.

### Results for this checkpoint

- Focused backend, scope, legacy-match and callable/export/source-discovery checks:
  **81 passed, 0 failed, 0 skipped**.
- Minimal Firestore/Storage Rules + full existing affected image emulator file:
  **45 passed, 0 failed, 0 skipped**.
- V2 emulator file against release Rules: **7 passed, 0 failed, 0 skipped**.
- Node syntax checks, changed JS/Markdown formatting and `git diff --check`: pass.
- The older `storageMinimalRules.unit.test.js` baseline structural audit reports
  a pre-existing `posts/{postId}` read mismatch (2 pass / 1 fail), also reproduced
  against the pre-task `78dbba9` Rules. It is not changed here. New scoped guard
  tests pin the legacy image match and compare both V2 Rules variants directly.
- One stale resident-image unit assertion was corrected: unclassified legacy
  apartment photos were already community-visible. V2 building/unit denials are
  independently tested; no production authorization was relaxed.

No Flutter/web rebuilds were needed for backend validation. Stage B client work,
production Rules freshness, optional active-cleanup update and device/browser
acceptance remain rollout prerequisites; no production claim is made.
