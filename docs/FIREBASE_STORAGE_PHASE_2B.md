# Firebase Storage — Resident migration, Phase 2B

Local implementation and synthetic validation only. No deployment, production
Firebase/Cloudinary operation, customer-file access/migration, Git history/index
change, dependency upgrade or unrelated full-suite run was performed. Existing
historical image URLs remain unchanged. All six excluded files and 28 unaffected
files from the prior dirty-work snapshot retain their original hashes.

## Feature completion

| Resident feature          | Local implementation status                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apartment/property images | Existing service extracts an authorized private reference from Admin `imageAsset` metadata. Dashboard/avatar/gallery consumers use the private provider. Reader requires a canonical operational resident in the exact building/community and an active image, or an assigned active Admin. Historical URL readers are retained.                                              |
| Profile                   | Existing edit-profile flow stages/finalizes and atomically attaches the owner's photo. Replacement/removal preserves the previous file until the pointer commits. Profile aliases remain populated, without writing an opaque reference into Firebase Auth's public photo URL. All identified Resident avatar readers use the private provider.                               |
| Community Wall            | Existing modal owns a server-created draft, uploads privately, and publishes canonical author/building/community metadata plus content/images atomically. Failed upload/publication keeps the form retryable. Deletion retains the existing hard-delete behavior and retires images. Copied author-photo references resolve to the current authorized profile image.          |
| Complaints                | Existing complaint is saved once; its photo attaches to that owned record. A photo failure leaves the complaint intact and the form retryable without duplicate records. Replacement/removal retires managed images after the transaction and preserves unrelated legacy document attachments. The existing detail view supports private, legacy URL and base64 branches.     |
| Marketplace create/edit   | Create uses an owned unpublished draft; edit attaches to the existing seller-owned listing with revision comparison. Image order and retained legacy URLs survive edits. Content and pointers commit together. Removal/replacement retires images; listing deletion keeps existing soft-delete behavior. Product, list, edit and owner detail readers support private images. |

These are local code/test completion statuses, not production deployment or
installed-device visual acceptance. Existing UI dimensions, navigation and data
fields are retained; no new third-party upload fallback was introduced.

## Data contract and consistency

New Resident display strings use `hominode-image:<asset UUID>` in the existing
profile/image/list fields. This is an opaque identifier, not a URL or access
capability. Additive `managedImageAssets` contains server-issued asset metadata;
`imageRevision` provides optimistic concurrency. Admin apartment records retain
Phase 2A's `imageAsset`/`revision` shape. Legacy HTTP URLs use their existing
network readers; a failed private read never falls back to a legacy URL.

`createResidentImageDraft({feature})` supports Wall and Marketplace. The server
creates a UUID draft scoped to the current canonical resident/building/community,
with a 24-hour lifetime. It creates no incomplete public post/listing.

`commitResidentImages({feature, resourceId, expectedRevision, operationId,
references, content?, deleteResource?})` attaches only owned ready assets belonging
to the exact feature/resource/tenant. Existing legacy URLs may be retained, but
new external URLs and other residents' assets cannot be attached. The transaction
checks authority, entitlements and revision; writes the domain record, attachment
journal and operation receipt; and retires removed assets together. Wall and
Marketplace retain the existing keyword moderation policy on both client/server.
Content inputs cannot set owner, role, tenant, path or managed metadata.

The client retains reservation/ready state and the original operation/revision
across a lost response, so retries do not duplicate uploads or publish twice.
Confirmed saves discard reusable upload attempts so selecting the same local file
later reserves a fresh asset. Auth changes reject late results. Profile operations
clear pending state on canonical-community changes. Expired/conflicting forms
fail safely and can be reopened with current metadata.

Firestore Rules keep existing collection authorization and add managed-pointer
protection only to `users`, `posts`, `complaints` and `marketplaces`. Client image
writes cannot inject the private prefix, alter managed metadata, or delete/mark
deleted records with attached managed assets. Unchanged managed fields allow
existing non-image updates. Legacy attachment lists retain arbitrary existing
lengths; every string is checked, including entries beyond position five and
newline payloads. List joining follows the [Firebase Rules List reference](https://firebase.google.com/docs/reference/rules/rules.List#join).
The callable's new-upload count limit remains five (one for profiles). Nested
Marketplace requests and unrelated billing/security/visitor rules are unchanged.

## Authorization and private reads

Every callable uses the existing App Check, verified-phone and canonical-profile
wrapper. Server-read membership, active community, operational resident identity,
resource owner and feature entitlement determine authority. Caller-selected roles,
community IDs, bucket names and paths grant no access.

| Attached asset | Read audience                                                                                                                                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apartment      | Operational Resident in the record's exact active building/community; assigned active Admin.                                                                                                                              |
| Profile        | Operational same-community residents for existing avatar use; assigned active Admin. Resident owner must still be operational. Old copied references resolve to the current profile pointer or fail closed after removal. |
| Wall           | Operational same-community resident or assigned active Admin, with current Community Wall entitlement.                                                                                                                    |
| Complaint      | Current operational complaint owner or assigned active Admin; unrelated residents denied.                                                                                                                                 |
| Marketplace    | Current operational owner/same-building resident or assigned active Admin, with current Marketplace entitlement.                                                                                                          |

Owner-only unpublished previews retain Phase 1 authority, including owned draft
expiry. All private reads verify the current pointer and pinned object metadata
before and after I/O; asset identity is rechecked as well as generation/hash.
Dual-role Admin identities preserve their valid assigned-Admin read contract.
Expired/missing phone sessions, withdrawn membership, wrong tenant/building,
changed ownership, unavailable entitlement, missing files and malformed private
responses fail closed. No public download URL/token is requested or persisted.

`readStorageImage` adds the authorized asset DTO and optional `knownAssetId`
alongside `knownGeneration`. A matching immutable image receives an authorized
header-only renewal without another byte download. Profile redirects explicitly
return the resolved current asset identity.

## Cache, errors and bounded memory

The new Resident provider follows the Admin reader's authenticated callable and
bounded-memory approach. It serializes byte reads, keeps at most three raw entries
and 20 MiB, expires them after 60 seconds, and does not cache failures. A visible
image renews authorization without downloading unchanged bytes. Rebuilds do not
restart reads, and off-screen queued requests are cancelled before byte I/O.
Decoded dimensions are bounded to 1024 per side; animated images use their codec
and release it off-screen. Visible completers retain asset metadata rather than
another unbounded raw-byte cache. No private disk cache is used.

Firebase session/token, canonical profile and selected-community changes
invalidate raw/private Flutter image-cache entries and pending responses. Visible
private pixels are replaced with a blank frame synchronously on invalidation.
Permission/missing/session errors use existing error/fallback presentation;
DecorationImage/CircleAvatar failures are handled without uncaught framework
exceptions. Explicit Image error builders still receive a generic error.

## Cleanup and recovery

New Resident cleanup exports are local and **undeployed**. A 15-minute scheduler
scans at most 100 journal records and 100 staging objects per run with persisted
cursors. Ready/unbound attempts expire after the reservation plus one-hour grace;
owned drafts expire after 24 hours. Retired assets are claimed transactionally as
`deleting`; attachments cannot race a claimed asset back into use. Cleanup never
removes a still-attached current private asset. It validates canonical namespace,
UUID/owner/tenant binding and pinned private hash/generation, deletes exact
object generations, and journals failures for retry. Invalid/partial staging
objects remain reclaimable without treating them as valid image uploads.

The staging sweep removes canonical unreserved or replayed staging objects older
than 24 hours, including recreated staging copies of otherwise attached assets;
it leaves the permanent attachment intact. Unknown bindings are counted for
review. No legacy URL is fetched/deleted and no financial-evidence prefix is
included. New reservation requests are limited to 30 per UID per 15 minutes;
direct staging abuse still needs bucket-level monitoring/quota controls.

## Focused validation

All storage is mocked or the localhost `demo-hominode-storage-images` emulator.
No real authentication, customer images, emergency services or external uploads
were used. Tests explicitly guard emulator hosts against production addresses.

| Check                                                                                                          | Result                                                                             |
| -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Resident upload adapter, external-upload guard, operations, private reader and real Wall/complaint modal tests | **51 passed, 0 failed**                                                            |
| Admin Phase 2A upload/service/cache/modal regressions                                                          | **40 passed, 0 failed**                                                            |
| Image foundation, Admin apartment and Resident contract backend unit tests                                     | **54 passed, 0 failed**                                                            |
| Storage/Firestore security and integration emulator tests                                                      | **34 passed, 0 failed, 0 skipped**                                                 |
| New/reworked upload/reader services and focused tests, scoped Flutter analysis (10 files)                      | Clean                                                                              |
| All 31 changed Resident Dart files, scoped Flutter analysis                                                    | 0 errors; 4 pre-existing warnings and 209 pre-existing lint infos; command exits 1 |
| Admin helper/reader and focused tests, scoped analysis (4 files)                                               | Clean                                                                              |
| Dart formatting (31 files), scoped JS Prettier, Node syntax                                                    | Passed                                                                             |
| `git diff --check`                                                                                             | Passed                                                                             |

The four retained warnings are the unused complaint `cleanNumber`, and Marketplace
product-detail `_currentUserId`, `sellerName`, `_viewSellerContact`. Every remaining
diagnostic's source line also exists in HEAD; unrelated print/deprecation/async
lint cleanup was not mixed into this task. No diagnostics were suppressed.

Security cases include foreign resident/resource/community, revoked/expired
identity, entitlement failure, unauthorized delete/read, size/MIME rejection,
revision conflicts, stale reads, atomic publication, failed finalize/save retry,
profile-pointer races/redirects, cleanup retry/generation safety and forged client
references. Widget tests decode synthetic private pixels, assert cache eviction
and logout blanking, exercise lost replies and verify real modal retry behavior
at 390 × 844. Installed-device flows were not visually inspected.

Scoped credential checks found no new private-key/secret literals in changed
files. One historical-token-URL fixture uses `example.invalid` in a legacy-reader
test; it is synthetic and is never requested. Old released clients remain outside
this source change's control. Current CloudinaryService upload/delete methods
continue to reject before network I/O, including legacy helpers and retries.
The unused generic upload example has not been redesigned or reactivated.

## Remaining release gates and next verification

1. Verify/update **other clients** that consume Resident image fields (Admin/Web
   profile, Wall, complaint and Marketplace readers) before publishing opaque
   references. None was broadly audited or changed here. Server-side assigned
   Admin audiences are supported; Admin non-apartment reader integration remains
   outside this phase. Retire/upgrade incompatible installed clients. The source
   guards cannot disable an already released Cloudinary binary; external-preset
   retirement requires separate owner authorization.
2. Agree the accepted-media decoder/dimension/frame/resource policy. Server
   validation remains Phase 1's bounded signature/header validation, not a full
   decoder or malware scanner. Do not represent this as a solved production gate.
3. Verify App Check registration/enforcement on real staging clients, private
   bucket IAM/public-access prevention/ACLs, callable/scheduler least-privilege
   IAM, and staging quotas/monitoring. Review cleanup backlog and error counts
   with synthetic staging objects; do not use customer files.
4. Define draft/receipt/journal retention (including profile redirect lookup),
   operational alerting and abuse controls for draft/staging creation. Current
   file reclamation is implemented; metadata TTL/policy and production limits are
   not provisioned by this change.
5. Drive all five installed Resident flows plus Admin apartment replacement with
   synthetic staging accounts: legacy/private display, failure/retry, simultaneous
   edits, logout, community switch, revocation and slow/offline sessions. Compare
   existing screen proportions at normal/enlarged text. Automated widget/rules
   checks are not visual acceptance.
6. Only after those gates, obtain a separately approved coordinated
   rules/callables/schedulers/client rollout. No production rollout, historical
   file migration or deployment is authorized by this implementation.

## Exact Phase 2B files

- `firestore.rules`
- `functions/src/apartment_images.js`
- `functions/src/index.js`
- `functions/src/resident_images.js`
- `functions/src/storage_images.js`
- `functions/test/apartmentImages.unit.test.js`
- `functions/test/residentImages.unit.test.js`
- `functions/test/storageImages.emulator.test.js`
- `resident_app/lib/comments_screen.dart`
- `resident_app/lib/community_wall_screen.dart`
- `resident_app/lib/dashboard_screen.dart`
- `resident_app/lib/profile_screen.dart`
- `resident_app/lib/src/components/avatar_picker.dart`
- `resident_app/lib/src/components/photo_upload_widget.dart`
- `resident_app/lib/src/components/post_card.dart`
- `resident_app/lib/src/modals/add_post_modal.dart`
- `resident_app/lib/src/modals/complaint_detail_modal.dart`
- `resident_app/lib/src/modals/create_complaint_modal.dart`
- `resident_app/lib/src/models/listing_model.dart`
- `resident_app/lib/src/screens/edit_profile_screen.dart`
- `resident_app/lib/src/screens/marketplace_create_listing_screen.dart`
- `resident_app/lib/src/screens/marketplace_edit_listing_screen.dart`
- `resident_app/lib/src/screens/marketplace_product_detail_screen.dart`
- `resident_app/lib/src/screens/marketplace_screen.dart`
- `resident_app/lib/src/screens/marketplace_screen_enhanced.dart`
- `resident_app/lib/src/screens/marketplace_your_product_detail_screen.dart`
- `resident_app/lib/src/screens/messages_screen_enhanced.dart`
- `resident_app/lib/src/services/apartment_images_service.dart`
- `resident_app/lib/src/services/complaint_image_service.dart`
- `resident_app/lib/src/services/firebase_image_upload_service.dart`
- `resident_app/lib/src/services/listing_firestore_service.dart`
- `resident_app/lib/src/services/post_firestore_service.dart`
- `resident_app/lib/src/services/profile_image_service.dart`
- `resident_app/lib/src/services/resident_image_operations.dart`
- `resident_app/lib/src/services/resident_private_images.dart`
- `resident_app/lib/src/services/tenant_resolution_service.dart`
- `resident_app/test/resident_image_modals_test.dart`
- `resident_app/test/resident_image_operations_test.dart`
- `resident_app/test/resident_private_images_test.dart`
- `docs/FIREBASE_STORAGE_PHASE_2B.md`
