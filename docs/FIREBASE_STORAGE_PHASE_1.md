# Firebase Storage migration — Phase 1

This is the upload foundation, not a production migration or completed UI cutover.
No deployed rules/configuration, existing image URLs, customer files, billing or
SOS behavior are changed by this checkpoint. Nothing has been committed/pushed.

## Current behavior

- The new Admin/Resident `FirebaseImageUploadService` uses Firebase Functions and
  mocked/testable Firebase Storage adapters, with a dependency-free local Dart
  package, `packages/hominode_storage`.
- The old Cloudinary upload entry points now fail explicitly. They cannot issue
  uploads, silently fall back externally, save a new Cloudinary URL or claim
  external deletion succeeded. Existing network-image readers remain intact.
- **Existing apartment/profile/wall/complaint/marketplace image upload buttons
  are intentionally unavailable until Phase 2 connects private-reference-aware
  readers and metadata attachment.** Do not ship this as a completed upload UI.
  Legacy poster HTTP uploading is also blocked, although outside the current
  Admin main import graph.
- Existing live Firestore image fields and URLs are untouched. The foundation
  writes only new server-owned `storageImageUploads` records when invoked.

## API and authorization

The two-document boundary follows [Firebase Storage rule conditions](https://firebase.google.com/docs/storage/security/rules-conditions).
Callable attestation uses [Firebase App Check enforcement](https://firebase.google.com/docs/app-check/cloud-functions).

All three callable exports require App Check, verified-phone Firebase Auth and
the existing canonical-profile checks. Image verification/read handlers use
512 MiB with concurrency 4 to bound memory pressure from files up to 10 MiB.

1. `prepareStorageImageUpload({feature, resourceId, contentType, size})` verifies
   the current profile, active community, role and existing target ownership.
   It generates an asset UUID and a 15-minute reservation. It accepts no role,
   community ID, owner, bucket, path or URL override from the client.
2. The client uploads once to the returned staging path, with the prescribed
   content type and binding metadata. Storage Rules independently check current
   canonical role/phone, active community membership, resident operational
   identity status, file extension/MIME, nonempty size <=10 MiB and uploader UID.
   Rules read only the profile and community documents, within the two-document
   Storage limit. Staging is a private owner namespace, not published content.
3. `completeStorageImageUpload({assetId})` rechecks authority, feature entitlement,
   ownership and reservation expiry. It verifies object binding/size/MIME and
   image headers, reads a bounded byte range without decompression, and creates
   an immutable, generation-pinned private object using the Admin/GCS API.
   It journals `verified`, deletes the staging generation, rechecks authority and
   returns `ready` only after cleanup. Failed cleanup remains retryable. It never
   changes an existing domain image field.
4. `readStorageImage({assetId})` currently permits the authorized uploader only.
   It checks current membership/target/entitlement before and after I/O, verifies
   metadata/hash/generation and returns bounded bytes as base64, never a public
   URL. The Flutter helper decodes those bytes. Phase 2 adds explicit existing
   domain audiences; do not broaden reads to every signed-in account.

### Features and source-of-truth targets

| Feature          | Role and target                                                   | Extra policy                        |
| ---------------- | ----------------------------------------------------------------- | ----------------------------------- |
| `apartment`      | Admin; `buildings/{resourceId}` determines community              | Active assigned Admin               |
| `profile`        | Resident; `users/{uid}`, resource ID must equal authenticated UID | Operational resident                |
| `community_wall` | Resident; `posts/{resourceId}.authorId`                           | Current `communityWall` entitlement |
| `complaints`     | Resident; `complaints/{resourceId}.userId`                        | Own complaint                       |
| `marketplace`    | Resident; `marketplaces/{resourceId}.sellerId`                    | Current `marketplace` entitlement   |

Conflicting ownership aliases fail closed. Existing wall/marketplace records
without `communityId` may derive it from their server-read building record.
Existing identity-verification and subscription policy implementations are
reused without changes. Missing entitlement verification never grants access.

### Paths and private delivery

- Admin staging: `apartment_images/{communityId}/{adminUid}/{assetId}.{ext}`.
- Resident staging:
  `resident_images/{communityId}/{uid}/{feature}/{assetId}.{ext}`.
- Final private assets:
  `private_images/{communityId}/{uid}/{feature}/{assetId}.{ext}`.

Staging permits authorized owner `get` and create-only writes. Namespace lists,
overwrites, metadata updates and client deletes are denied. A staging upload
alone does not prove target authorization: only the callables can reserve,
verify or make an asset ready. A client may create an unreserved file in its
own staging namespace; it cannot finalize or publish it. Quota/orphan cleanup
is a Phase 2 rollout requirement.

All client operations on `private_images` and `storageImageUploads` are denied,
including attempts to mint `getDownloadURL` capabilities. The Firebase upload
API can add download tokens to staging objects. Final objects are created via
the Admin/GCS API without those tokens; staging copies are deleted before a
ready reference is returned. The emulator tests verify that the old staging URL
cannot serve the file and that private metadata/token-URL requests are denied.

No user-supplied URL is fetched and no Cloudinary API is called. New asset metadata
contains provider, bucket, path, tenant, owner, feature, target, MIME, size,
generation, SHA-256 and lifecycle state/timestamps. It contains no public URL.
Use `asset.toMap()` as additive managed-image metadata during Phase 2. Its
`gs://` reference is **not** an `Image.network` URL.

JPEG, PNG and WebP are supported for all five features; GIF remains supported
for profiles/wall. Header checks are bounded and reject MIME mismatches, SVG,
HTML, encoded payloads and invalid PNG/GIF dimension bounds. This is not a full
decoder, malware scanner or exhaustive animated-image resource validator.
Do not claim otherwise; validate the accepted-media policy before UI rollout.

## Active caller cutover checklist

| Existing caller                                                                                        | Current guard                                     | Phase 2 attachment/reader work                                                                                                                                |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Admin `apartment_images_management_screen.dart` → `cloudinary_apartment_images_service.dart`           | Upload method rejects before HTTP/metadata writes | New upload helper + server-authorized gallery attachment; keep title/building/date/order fields and existing URL fallback                                     |
| Resident `edit_profile_screen.dart` → `profile_image_service.dart` → `image_upload_flow_function.dart` | Central Cloudinary uploader rejects               | Canonical UID, upload/ready asset, atomic profile pointer replacement, private image provider                                                                 |
| Resident `add_post_modal.dart` → upload flow                                                           | Same central guard                                | Reserve/create owned post or server-owned draft before upload; attach only after moderation/verification; delete arbitrary-first-user authentication fallback |
| Resident `create_complaint_modal.dart` → `complaint_image_service.dart`                                | Same central guard                                | Use the already-created complaint ID; preserve text-only complaint and clear failure/retry behavior; bind an owned ready asset                                |
| Resident marketplace create/edit screens → direct `CloudinaryService.uploadImage`                      | Same central guard                                | Reserve owned listing/draft before upload, preserve gallery order/removals and moderation, conditionally attach new ready assets                              |

Generic unused upload helpers inherit the central guard. Legacy URL rendering
does not create a new upload; it still contacts the external host. Existing
Cloudinary account ownership/recoverability and historical credential exposure
remain unresolved outside this implementation.

## Exact Phase 2 sequence and remaining gates

1. Add server-authorized attach/replace/delete operations against ready assets
   and existing domain records. Recheck owner/community/feature, compare the
   expected record revision, preserve existing scalar/list fields and order,
   journal reference changes and delete only unreferenced exact generations.
   Never derive a destructive operation from an arbitrary client URL/path.
2. Support pre-publication uploads with server-owned drafts/reservations for wall
   and marketplace creation. Current foundation requires an existing owned
   target; it deliberately does not create unfinished public posts/listings.
3. Define/read the same audiences as current domain records: owner and authorized
   complaint handlers; building/community apartment viewers; permitted profile,
   wall and marketplace viewers. Add resource- and entitlement-aware reads to
   the callable; preserve tenant isolation and revoke access on status changes.
4. Add private Flutter image providers using authenticated reads, bounded caches
   and cache clearing on logout/tenant change. Keep legacy URL fallback unchanged
   until independently approved historical migration. Adapt the named callers
   and return messages above without changing UI proportions/navigation. Remove
   legacy arbitrary-user lookup fallbacks and URL/identity logging in those flows.
5. Add expiry cleanup for unreserved/pending staging files, verified private
   orphans, cancelled forms and failed metadata attachment. Retain journals,
   retries, grace periods, exact-generation safeguards and per-uploader quotas.
   No generic photo cleanup may touch immutable payment evidence.
6. Complete accepted-format decoding/dimension/frame/resource-limit tests and
   privacy/retention policy. Verify bucket IAM/public-access prevention/default
   ACLs, authorized staging App Check enforcement, client registration and any
   required CORS. Storage Rules do not control independent GCS IAM grants.
7. Run focused integration, concurrency/failure/cleanup and cross-role/tenant
   emulator tests; compare all five flows visually with existing UI at mobile
   widths/text sizes. Verify no new Cloudinary requests, public download-token
   persistence or old image URL mutation. Keep billing/receipt/SOS regressions.
8. Plan an explicitly approved backend/rules/client rollout using synthetic
   staging data first. No production deployment is authorized by Phase 1.
   Retire older installed clients separately; this source change cannot prevent
   old released binaries from contacting an unsigned external preset.
9. Only after parity, remove obsolete Cloudinary names/configuration/unused
   dependency/tests/docs. Historical transfer needs separate owner approval,
   lawful access and integrity/recoverability checks. Never reactivate external
   upload fallback for rollback; pause uploads or use a tested Firebase version.

## Validation

Focused tests use mocked Flutter Storage or a localhost-only demo Firebase
project. No production Auth, customer images, provider requests, uploads or
deletions are involved. Emulator fixtures are synthetic and cleaned recursively.

```sh
# From functions/, with demo Firestore + Storage emulators running:
node --test test/storageImages.unit.test.js test/storageImages.emulator.test.js

# From Admin app:
flutter test --no-pub test/firebase_image_upload_service_test.dart test/cloudinary_upload_contract_test.dart

# From Resident app:
flutter test --no-pub test/firebase_image_upload_service_test.dart test/cloudinary_service_test.dart
```

Exact final results, scoped analysis and preservation checks are recorded in
`/tmp/firebase-storage-migration-phase-1/implementation-report.md`.
