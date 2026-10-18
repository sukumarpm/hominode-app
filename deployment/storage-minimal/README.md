# Minimal private-image rollout

Local preparation only; nothing deployed. Use `firebase.storage-minimal.json`,
**not the full root `firebase.json`**, for this rollout. Production deployment
remains blocked on native Linux validation and operational/test-client acceptance.

## Scope and compatibility

The `baseline/` files preserve the captured production rules, with spaces removed
from nine otherwise blank Firestore lines. No rule tokens changed. Original capture
and normalized-file hashes plus ruleset IDs are in `baseline/metadata.json`. They contain
configuration only, not customer records or files. Recheck those live ruleset IDs
before a later deployment; stop and rebase/retest if production has changed.

The deployable files add only:

- Private staging for Admin apartment and Resident profile/Wall/complaint/marketplace
  images, with verified-phone binding, active membership, role/owner namespaces,
  create-only writes, MIME/size/metadata restrictions and tenant isolation.
- Denial of direct client access to permanent private objects/reservations.
- Server-owned managed references/revisions, with protected attachment changes and
  deletion in users, posts, complaints, marketplaces and apartmentImages.

Production authentication helpers, every unrelated match scope, and existing
image-collection read predicates remain identical apart from those blank-line spaces. Existing receipts,
facility/event images, visitor creation/check-in, financial records, event access
and SOS retain their captured production behavior. This is not approval to expand
those older policies, or to introduce legacy authorization into new image APIs.
New image callables independently enforce App Check, canonical phone identity,
membership, role, ownership, current resource pointers and feature entitlements.
Historical Cloudinary/Firebase image URLs are untouched; none was requested.

## Validation and local files

- Backend/media/export/packager and rules-structure tests: **63 passed**.
- Rules emulators: **75 passed, 0 failed, 0 skipped**: 35 existing image cases
  using the minimal variants and 20 compatibility cases against each of captured
  production/minimal rules. Only synthetic localhost data is used.
- The seven callable names/region/App Check options match the clients. Both
  cleanup export dependency bugs are fixed locally but are excluded from rollout.
- The actual Firebase CLI file-selection algorithm excludes scripts, tests,
  environment files, node_modules and debug artifacts. The six local exclusions
  remain outside the package and unchanged.

Logs and checkpoint records: `.firebase/storage-minimal-rollout/` (Git ignored).
Original root rules remain unchanged. The shared Functions source is still needed
for imports, but only the seven listed exports are deployed; no other Functions,
indexes or Hosting targets are selected. Do not run a bare Functions deployment.

## Native Linux gate

Host verification is Darwin Node 22; no Docker/Podman/Colima/Lima/QEMU or usable
Linux container socket was available. **Native Linux execution is not verified.**
Sharp is pinned to 0.35.5, declares Node >=20.9.0, and the lockfile contains the
integrity-pinned Linux x64 native/libvips optional packages. No upgrade was made.
In a separately available isolated Linux x64/glibc Node 22 checkout, run:

```sh
cd functions
npm ci --omit=dev --include=optional
node --test test/storageImages.unit.test.js test/apartmentImages.unit.test.js test/residentImages.unit.test.js
```

Those 56 production-dependency unit contracts exercise real Sharp decoding on
synthetic JPEG/PNG/GIF/WebP, malformed/truncated inputs, signature mismatch,
dimension/frame bounds and attachment/lifecycle authorization. Check memory/load
for 512 MiB instances, concurrency one and decoder timeout before release. Never
copy Mac node_modules to a Linux artifact. Do not use a production Cloud Build
job merely to bypass this uncompleted local gate.

## Project, bucket, IAM and App Check

- Project `hominode-prod` (`551984029668`); default bucket
  `hominode-prod.firebasestorage.app` in US-EAST1; image callables asia-southeast1.
  Clients use that same project/bucket and explicit Functions region.
- First seven image APIs use `storage.objects.get`, `storage.objects.create` and
  `storage.objects.delete` on the image staging/private namespaces. They do not
  need bucket administration, token signing, object ACL changes, or list access.
  Later cleanup needs `storage.objects.list` as well. The current runtime account
  is `551984029668-compute@developer.gserviceaccount.com`, with broad project Editor
  access according to the captured IAM gate. It is functionally sufficient, not
  least privilege. Do not reduce this shared account's permissions and break
  unrelated Functions. Any dedicated image account/grants require separate approval.
- Firestore runtime access requires trusted document/transaction/query access;
  `roles/datastore.user` is a standard scoped alternative to project Editor.
  Server IAM bypasses Rules: client roles/community IDs never grant backend access.
- Firebase callable HTTPS endpoints must be reachable by Firebase SDK clients.
  Standard Gen 2 public invocation uses Cloud Run Invoker for `allUsers`; Auth,
  App Check and authorization remain enforced inside the callable. Firebase user
  tokens are not Google Cloud IAM invocation credentials. Runtime accounts do not
  need Run Invoker or Scheduler roles for these seven APIs. Inspect the actual
  new service policies after an authorized deployment; do not blanket-open others.
- Deployment/build identities need normal scoped Functions deployment and
  service-account actAs/build/artifact permissions. No IAM was changed here.
- Admin and Resident Android Play Integrity/iOS App Attest configurations are
  registered in the captured gate. Register each approved test device's debug
  token manually for tests against real protected APIs. Do not commit tokens,
  bundle debug credentials or use debug providers in release builds.
- Storage App Check is currently UNENFORCED. Validate all existing Storage clients
  before separately approved global enforcement; it can affect receipts and Web
  galleries too. New image callables always retain `enforceAppCheck: true`.
  Verify private bucket/default-object ACL and public-access prevention. Current
  captured grants contain no allUsers/allAuthenticatedUsers; uniform access is
  off and public-access prevention inherited. No bucket policy was changed.

See [Storage permissions](https://docs.cloud.google.com/storage/docs/access-control/iam-permissions),
[Firestore IAM](https://firebase.google.com/docs/firestore/security/iam) and
[callable client contracts](https://firebase.google.com/docs/functions/callable).

## Exact deployment order — commands prepared, not executed

First close Linux/IAM/App Check/client acceptance gates and confirm production
still matches the captured baseline. Keep test uploads bounded; both automatic
cleanup schedules are deliberately absent. Approve orphan cleanup/retention,
quotas and monitoring before general use. Existing bucket soft-delete retention
is seven days; object deletion is not immediate physical erasure.

```sh
cd /Users/sukumarmuthiah/Documents/lyvo1

# Matching image-only rules first. No indexes or broader local rules.
firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only "storage,firestore:rules"

# Only these seven image APIs. No cleanup, billing, visitor, SOS or Hosting.
firebase deploy --project hominode-prod --config firebase.storage-minimal.json --only "functions:prepareStorageImageUpload,functions:completeStorageImageUpload,functions:readStorageImage,functions:saveApartmentImage,functions:deleteApartmentImage,functions:createResidentImageDraft,functions:commitResidentImages"
```

No scheduler deployment command is part of the first rollout. Do not deploy the
canonical phone writer, broader entitlement APIs or financial Functions as part
of these commands. Imported policy helpers are bundled with the selected APIs.
Do not run Firebase deploy dry-run as a supposedly read-only test: the installed
CLI warns it may enable APIs. No deploy or deploy dry-run was executed here.

## Recovery

Stop new calls to the six mutating image APIs via approved per-service invocation
controls; retain `readStorageImage` and compatible client readers. There are no
new cleanup jobs to pause in the first rollout. Never restore external uploads.

Only **before any managed image references have been published**, restore the
captured production rules using the prepared backup configuration, after checking
it still matches the appropriate rollback point:

```sh
firebase deploy --project hominode-prod --config deployment/storage-minimal/rollback.firebase.json --only "storage,firestore:rules"
```

After managed references exist, keep private-reader and managed-pointer protection
and deploy a tested forward fix. Do not blindly restore old rules, delete customer
objects, mutate financial records or roll back clients past private-reader support.

## Emulator acceptance

```sh
cd /Users/sukumarmuthiah/Documents/lyvo1
HOMINODE_STORAGE_RULES_VARIANT=minimal ./functions/node_modules/.bin/firebase emulators:exec --project demo-hominode-storage-images --config firebase.storage-minimal.emulator.json --only firestore,storage 'node --test --test-concurrency=1 functions/test/storageImages.emulator.test.js functions/test/storageMinimalCompatibility.emulator.test.js'
```

For installed-app acceptance, first prepare an isolated debug/test entrypoint:
all Auth, Functions, Firestore and Storage SDKs must use the **same demo project**
and emulator hosts. Android emulator uses 10.0.2.2; iOS simulator uses localhost.
Do not launch current shipping builds as an emulator test: no SDK emulator routing
exists in either app, and the Admin startup App Check gate needs a controlled test
adapter. Real App Check is not emulated or established by these Rules tests.
Route only image APIs in a test Functions harness; do not start unrelated payment,
visitor or SOS triggers against incompletely emulated services. This task did not
modify app bootstrap or add such a harness.

Then use synthetic same/foreign-community accounts and tiny generated images:
apartment upload/read/replace/delete; Resident profile, Wall, complaint and
marketplace create/edit; failed upload/commit retry; legacy placeholder display
without fetching historical images; logout/tenant switch; revoked and expired
sessions; denied cross-user reads. Check original UI at normal/enlarged text and
network logs for zero production/Cloudinary traffic. Never use real SMS/customer
files, payment actions or emergency endpoints in this acceptance run.
