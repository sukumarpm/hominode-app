# Firebase Storage — Admin apartment images, Phase 2A

Local implementation only. No rules, functions, scheduler, IAM, Firebase or
Cloudinary production configuration was deployed or accessed. No customer file
was read or transferred. No commits, pushes, branch switches or dependency
changes were made. Phase 1 dirty work and all six excluded files are preserved.

## Admin workflow

The existing Add Image modal now picks an image and calls the Firebase transport
through the existing apartment service entry point. The internal compatibility
class name still contains Cloudinary; there is no external upload implementation
or fallback. The approved dashboard, screen colors, card geometry, dates, time
controls and navigation are retained. A small Replace image action opens the same
modal; replacement preserves the original record's metadata and creation time.
The gallery builds cards lazily to avoid downloading/decoding the entire gallery.

1. Check the active Admin session/community, local file length and JPEG/PNG/WebP
   signature. File reading is capped at 10 MiB + one byte; larger/empty/unsupported
   input is rejected before reservation. The picker bounds selected dimensions;
   previews and displayed images decode at a bounded width.
2. Phase 1 callables authorize an existing building, generate the reservation,
   accept owner-only create-once staging, validate/finalize an immutable private
   object and remove its token-bearing staging generation. No public download
   URL is requested or persisted.
3. `saveApartmentImage` atomically creates/replaces the `apartmentImages` pointer
   and marks its asset attached. New record IDs equal the server-generated asset
   UUID. Repeating a lost-response save is idempotent. The modal retains the
   reservation/ready asset for finalize/save retries without another upload.
   A failed Storage write can be retried; abandoned attempts expire into cleanup.
4. `readStorageImage` resolves an attached apartment record and rechecks the
   current phone-authenticated, canonical active Admin, authorized community and
   existing building before and after byte I/O. Assigned peer Admins may read;
   residents and foreign-community Admins are not granted apartment bytes by
   this phase. Owner-only pre-attachment previews remain available.
5. Replacement compares the expected record revision. Its transaction attaches
   the new ready asset and retires the old one together. It never deletes the old
   file before the replacement pointer commits. `createdAt`, existing date/time,
   title, description, type, creator, status, ordering/custom fields and legacy
   `imageUrl` remain unchanged; only `imageAsset`, `revision`, `updatedAt` change.
6. `deleteApartmentImage` atomically removes the gallery record, retains a minimal
   server-only tombstone for idempotent retries and retires its managed asset.
   Legacy URL-only deletion retains the existing metadata-only behavior. No URL
   is used as a destructive Storage path and no legacy host is contacted.
7. A retryable cleanup core and **undeployed** 15-minute scheduler delete retired
   files only after detachment. Unattached reservations/private copies are
   eligible one hour after the reservation's 15-minute expiry. A transaction
   claims `deleting` so late finalizers/attachments cannot publish the asset.
   It checks canonical paths, bucket, binding, MIME/size and pinned private
   hash/generation, then deletes exact object generations. A failed delete stays
   journaled for the next sweep; a changed private generation is retained for
   owner review. A persisted cursor bounds each sweep to 100 journal records.

A ready reference and a public URL are different representations: `imageAsset`
is additive managed metadata, never input to `Image.network`. New records retain
`imageUrl: ''` for schema compatibility. Existing Firebase and historical
Cloudinary URLs keep their existing network reader. For replaced legacy records,
the private reference takes precedence and an authorization failure never falls
back to the old URL. No live legacy URL is rewritten or migrated automatically.

## API and authorization

All client-callable exports use the existing App Check + verified-phone +
canonical-profile wrapper. Community, role, owner, bucket and paths are derived
from server-read records, not accepted as client authority.

| Callable                       | Input                                                                 | Result / behavior                                                                                                                             |
| ------------------------------ | --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `saveApartmentImage` (create)  | `assetId`, `title`, `description`, `type`, `uploadDate`, `uploadTime` | `{imageId, revision}`; owned ready apartment asset, existing authorized building, atomic pointer/journal attachment                           |
| `saveApartmentImage` (replace) | `assetId`, `imageId`, `expectedRevision`                              | Same result; same building/community, optimistic concurrency, original metadata retained, prior asset retired                                 |
| `deleteApartmentImage`         | `imageId`, `expectedRevision`                                         | `{imageId, deleted:true}`; same community/building authority, reference removed before retirement                                             |
| `readStorageImage`             | `assetId`, optional `knownGeneration`                                 | Existing bounded base64/MIME/size/generation response; attached apartment audience checked against gallery and building before/after download |

`apartmentImages.imageAsset` and `revision` are server-owned: Firestore Rules deny
client creation, updates, removal of those fields and deletion of managed records.
Legacy URL-only writes retain their existing same-community rules. Journal,
tombstone and maintenance collections deny all client access. Phase 1 private
Storage and existing financial paths/rules are unchanged by this phase.

A matching optional `knownGeneration` performs the same authority and object
metadata checks before/after I/O and returns `notModified:true` without reading
image bytes. The Admin cache uses this check to renew access to an immutable
cached/visible image rather than repeatedly downloading a full-resolution file.
It never treats a failed authorization check as permission to keep displaying it.

The screen owns a session/community-scoped LRU: at most three entries and 20 MiB,
60-second cache lifetime with periodic authorization refresh, serialized reads,
no cached failures, and stale in-flight response rejection. Sign-out/community changes clear it and remove
private widgets. Decoded providers are evicted when replaced/disposed. Rebuilds
do not restart the read; off-screen cards are disposed instead of kept alive.

## Focused validation

All data is synthetic and all Firebase services are mocked or localhost demo
emulators. No production Auth, Cloudinary HTTP, customer images, camera or
notification endpoints were used. No unrelated full test suites were rerun.

| Check                                                              | Result                                                           |
| ------------------------------------------------------------------ | ---------------------------------------------------------------- |
| Backend image foundation + apartment contract unit tests           | 33 passed, 0 failed                                              |
| Storage/Firestore emulator tests, including concurrent replacement | 27 passed, 0 failed, 0 skipped                                   |
| Admin isolated upload/service/cache/modal tests                    | 40 passed, 0 failed                                              |
| Resident shared-contract regression tests                          | 27 passed, 0 failed                                              |
| Scoped Admin analysis                                              | 0 errors, 0 warnings; 3 existing `withOpacity` deprecation infos |
| Scoped Resident helper/tests and shared package analysis           | Clean                                                            |
| Dart formatting, new/scoped JS Prettier and JS syntax              | Passed                                                           |
| `git diff --check`                                                 | Passed                                                           |

The Add Image test selects a synthetic file, verifies date validation, scrolls to
existing date/time controls and confirms submission/navigation. Replacement and
failed-save retry tests exercise the real modal with an injected isolated
service. Private reader tests cover display, retry, cache limits, session changes
and wrong selected community. Backend/emulator checks cover authority, reference
forgery, revision races, legacy metadata, failure recovery, generation-safe
cleanup, and access revocation during download.

There is no emulator **visual acceptance** claim. Automated rules emulators and
widget tests ran; the installed Admin app was not driven against live services.

## Remaining rollout dependencies and exact Phase 2B handoff

1. **First migrate the Resident apartment audience and reader.**
   `resident_app/lib/src/services/apartment_images_service.dart` still extracts
   `imageUrl` strings, so it cannot display newly created private images. Extend
   the server's attached-apartment read branch to the canonical operational
   resident in the exact record building/community (and active image status),
   before and after I/O. Do not grant apartment bytes to every authenticated
   resident. Adapt the service result/model and its direct gallery consumers to
   private references with the same bounded cache/session invalidation and
   untouched legacy URL fallback. Check other consuming clients before rollout.
2. Implement the Resident profile, Community Wall, complaint and marketplace
   attachment contracts against Phase 1's trusted targets (`users/{uid}`,
   `posts.authorId`, `complaints.userId`, `marketplaces.sellerId`). Reuse atomic
   pointer/journal/revision/retirement sequencing, but define each audience and
   ownership rule separately. Wall and marketplace need server-owned drafts for
   pre-publication files; keep existing moderation and entitlements fail-closed.
3. Wire the identified profile upload flow, `add_post_modal`, complaint flow and
   marketplace create/edit callers. Remove arbitrary-user lookup fallbacks and
   sensitive URL/identity logging there. Their existing central external-upload
   guards remain in place until private attachment/read parity is tested. There
   is no external-storage rollback path.
4. Add Resident expiry/orphan/cancellation recovery and quotas. Apartment cleanup
   covers **reserved** managed attempts and their possible private copies; direct
   unreserved staging writes are still possible under Phase 1's two-document
   Storage Rules limit. Their expiry/quota policy and older-client retirement
   remain rollout gates. Never include immutable financial evidence in cleanup.
5. Resolve Phase 1's accepted-media decoder/dimension/frame policy (current server
   checks are bounded headers, not a complete decoder/malware scanner), review
   bucket IAM/public access prevention/ACLs and App Check client registration,
   and verify the scheduler's permissions/retention/monitoring with synthetic
   staging data. Unexpected private generation/binding mismatches require owner
   review and are deliberately not deleted.
6. Add cross-role/building/tenant/revocation, multi-client metadata, failed-draft,
   concurrent replacement and cleanup tests, then visually inspect the affected
   installed-app flows. Only after those gates, request a separately approved
   coordinated rules/backend/scheduler/client rollout. Nothing here authorizes
   deployment or migration of existing customer files.

## Exact Phase 2A changed files

- `firestore.rules`
- `functions/src/apartment_images.js`
- `functions/src/index.js`
- `functions/src/storage_images.js`
- `functions/test/apartmentImages.unit.test.js`
- `functions/test/helpers/storage_images_fixture.js`
- `functions/test/storageImages.emulator.test.js`
- `functions/test/storageImages.unit.test.js`
- `hominode-admin/admin_app/lib/apartment_images_management_screen.dart`
- `hominode-admin/admin_app/lib/services/cloudinary_apartment_images_service.dart`
- `hominode-admin/admin_app/lib/services/firebase_image_upload_service.dart`
- `hominode-admin/admin_app/lib/widgets/private_apartment_image.dart`
- `hominode-admin/admin_app/test/apartment_image_modal_test.dart`
- `hominode-admin/admin_app/test/cloudinary_upload_contract_test.dart`
- `hominode-admin/admin_app/test/firebase_image_upload_service_test.dart`
- `hominode-admin/admin_app/test/private_apartment_image_test.dart`
- `packages/hominode_storage/lib/src/storage_image_upload.dart`
- `docs/FIREBASE_STORAGE_PHASE_2A.md`

Other dirty/untracked Phase 1 files are unchanged by Phase 2A. Preservation hashes,
logs and the implementation report are in `/tmp/firebase-storage-phase-2a`.
