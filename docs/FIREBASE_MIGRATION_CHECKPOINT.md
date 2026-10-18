# Firebase migration finish and Release 1 checkpoint — 2026-10-18

**Source migration: COMPLETE. Production rollout: BLOCKED pending the gates below.**
All work is local. No production service/file operations, historical-image access,
Cloudinary requests, deployments, pushes, branch switching or history rewriting.

## Migration scope

- Admin apartments and Resident profile, Community Wall, complaint and Marketplace
  create/edit flows use authenticated Firebase staging, server finalization and
  atomic attachment. Replacement retires old bytes after metadata commits;
  deletion and abandoned-upload recovery use generation-pinned server cleanup.
- Private readers retain authorization renewal, bounded caches and session/tenant
  invalidation. Admin complaint attachments use the authorized private reader.
  Historical Cloudinary/Firebase URL display remains unchanged. No historical
  image was downloaded, investigated or migrated.
- The shipping consumers handle the reference types they receive. Existing Web
  URL galleries remain covered; no unused Web private viewer was introduced.
  Security has no shipping upload/network-image consumer. Legacy external upload
  and deletion helpers reject before HTTP; no shipping external fallback exists.
- The only application correction in this follow-up is automatic date/time in
  the existing Add Apartment Image form. Both fields remain in place and read-only;
  no picker is required. Display values use the local form-open timestamp and
  existing locale time formatting. The server's authoritative `createdAt` remains
  automatic. Replacement preserves original timestamps/metadata and ordering.
  The approved Home/dashboard design was not changed.

## Essential validation

| Check                                                       | Final result                                                             |
| ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| Storage, apartment and Resident backend unit contracts      | 56 passed, 0 failed                                                      |
| Storage/Firestore security emulators                        | 35 passed, 0 failed, 0 skipped                                           |
| Admin upload/private-reader/attachments/startup/form checks | 47 passed in total: 44 existing checks plus 3 form checks on rerun       |
| Resident upload/private-reader/real-modal checks            | 51 passed, 0 failed                                                      |
| Admin Web data/query regressions                            | 15 passed, 0 failed                                                      |
| Resident Web data/query regressions                         | 9 passed, 0 failed                                                       |
| Both Web TypeScript checks                                  | Passed                                                                   |
| Functions production syntax                                 | Six affected modules passed `node --check`                               |
| Scoped Flutter analysis                                     | Admin: 0 errors, 5 existing warnings, 17 existing infos; Resident: clean |
| Two changed Dart files formatting                           | Passed                                                                   |
| Current proposed checkpoint secret checks                   | Zero findings; values never printed                                      |
| `git diff --check`                                          | Passed in all three repositories                                         |

The first Admin run encountered a new test compilation error: `TextFormField`
does not expose `readOnly`/`onTap` getters. The test now checks its rendered
`TextField` controls; all three form tests pass, including automatic values,
replacement preservation and retry. The other 44 Admin checks passed unchanged.
All retained analyzer diagnostics refer to code already present in HEAD.
No unrelated full suites or production builds were repeated.

Emulators used **`demo-hominode-storage-images`** for CLI, Firestore, Storage and
the synthetic bucket, with single-project mode enabled and localhost guards.
Automated coverage includes tenant/owner denial, MIME/size/signature validation,
PNG trailer truncation, replacement/deletion, metadata consistency, retry and
expired/revoked sessions. Logs/manifests are in
`/tmp/firebase-migration-finish-and-checkpoint/`.

## Critical production gates and Firebase prerequisites

1. Confirm owner revocation of the exposed Cloudinary private credential.
   The current source contains none of that value, but development ancestry is
   contaminated. Never push the root development branch or use it as a new
   publication branch's parent. A clean new branch does not erase prior exposure
   already present on GitHub; remote remediation remains an owner task.
2. Verify real Android/iOS/web App Check providers/identities and manually register
   approved emulator debug tokens. Release clients must retain real attestation.
   Keep callable Auth/App Check/canonical-profile/membership/ownership/entitlement
   enforcement; Console rejection is not permission to disable checks.
3. Verify private bucket public-access prevention, ACL/IAM, least-privilege runtime
   and scheduler identities, permitted callable invocation and Storage App Check.
   No public reader/token capability may expose `private_images`. Do not change
   existing historical URL delivery or financial-evidence rules.
4. Validate the deployed **Linux Node 22** artifact with `npm ci --include=optional`
   and synthetic media contracts before release. Sharp 0.35.5 and matching Linux
   x64/libvips optional packages are pinned with integrity in the lockfile;
   Node engines are compatible. This Mac has no Linux/container runtime, so native
   Linux execution and load/memory acceptance remain unverified. Do not copy Mac
   `node_modules` to Linux. Decoder limits remain 10 MiB, 40 MP, one frame and
   10 seconds, with bounded cache/workers and callable concurrency one.
5. Approve quotas/abuse monitoring and staging/draft creation limits. Reservation
   quotas do not bound all direct staging bytes or draft creation. Review cleanup
   backlog/alerts, 24-hour staging/draft policy and journal/receipt retention.
   Do not TTL active attachments or profile redirect journals. Production schedules
   and metadata retention are not configured by this task.
6. Complete synthetic-account installed-device acceptance and signed release
   builds. Automated emulator/widget results do not establish visual acceptance,
   real App Check success, or production readiness.

## Exact coordinated deployment order — not executed

1. Close credential/publication and synthetic staging acceptance gates; verify
   Console/IAM/App Check, budgets, retention and Linux/signed-client artifacts.
2. Stage additive Functions first with new upload/commit invocation gated:
   `prepareStorageImageUpload`, `completeStorageImageUpload`, `readStorageImage`,
   `saveApartmentImage`, `deleteApartmentImage`, `createResidentImageDraft`,
   `commitResidentImages`. Repeat only in a separately approved production rollout.
3. Install matching private Storage/Firestore Rules before enabling new references;
   verify denied direct/public/foreign reads. Preserve unrelated rules.
4. Distribute compatible Admin/Resident readers to internal Android/TestFlight;
   verify upgrades and gate incompatible old clients before producing new refs.
5. Enable uploads/attachment commits only after rules/readers pass. Release the
   canonical phone writer and entitlement resolver with compatible clients;
   do not reseed subscriptions or migrate existing image URLs.
6. Enable `cleanupApartmentImages` and `cleanupResidentImages` only after explicit
   IAM/prefix/age/retention/backlog review and synthetic cleanup acceptance.
7. Release each Web separately from its own repository and explicit Hosting target:
   `hominode_app` for Admin, `hominode_prod` for Resident. Avoid broad root deploys.

Rollback pauses new publication/cleanup where needed and retains private readers,
compatible metadata and legacy display. Never restore an external upload fallback.

## Checkpoint and publication records

The original 13 local Release 1 commits remain ancestors on their original
branches. The exact pending-file manifest is checkpointed in logical shared,
backend/rules, Admin, Resident and documentation groups, plus one group per Web.
The six excluded seed scripts/backup images remain local, untracked and byte-identical.
Exact new commit IDs and snapshot verification are recorded alongside the manifest
in `/tmp/firebase-migration-finish-and-checkpoint/`; this document's own commit ID
is recorded there to avoid a self-referential file hash.

Publication commands and the independent sanitized snapshot are recorded in
`publication-plan.md` in that same directory. No push is authorized or executed.
Web publication must remain a normal fast-forward after refreshing remote tips.

## Emulator acceptance and TestFlight preparation

The automated migration checks are ready. Next use synthetic staging accounts on
installed clients, with separately approved staging configuration: all five upload
features, private/legacy display, replace/delete, interrupted upload/retry, logout,
tenant switch, revoked/expired sessions and normal/enlarged text. Preserve approved
Home proportions. Never use real customer files or emergency endpoints.

For TestFlight, verify bundle/team/signing and iOS deployment settings, release
App Check App Attest registration, increment approved version/build numbers,
produce/validate a signed release archive, and distribute internally only after
coordinated staging backend/rules acceptance. Those signing/upload/production
configuration steps are not performed here.
