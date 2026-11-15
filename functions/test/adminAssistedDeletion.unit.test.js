const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { sosStore } = require("./helpers/sos_store");
const { APP_CONTEXTS } = require("../src/notifications");
const {
  createAdminAssistedDeletionRequestCore: create,
  verifyAdminAssistedDeletionRequestCore: verify,
} = require("../src/account_deletion_assisted");
const {
  hasResidentDeletionVerification,
} = require("../src/account_deletion_verification");
const {
  attemptAccountDeletionRequestCore,
  initialRetry,
  retryDelay,
} = require("../src/account_deletion_retry");
const {
  coordinateAccountDeletionFulfillmentCore: coordinate,
  reviewAccountDeletionEligibilityCore: eligibility,
  listCommunityDeletionRequestsCore: list,
  financialHandoverEvidence,
  recordDeletionFinancialReviewCore: handover,
  reassessAccountDeletionRequestCore: reassess,
  submitAccountDeletionRequestCore: submit,
  getAccountDeletionRequestStatusCore: status,
} = require("../src/account_deletion_requests");
const phone = "+639170000000";
const app = {
  appId: Object.keys(APP_CONTEXTS).find(
    (key) => APP_CONTEXTS[key].role === "admin",
  ),
};
const auth = (uid = "admin", seconds = Math.floor(Date.now() / 1000)) => ({
  uid,
  token: {
    phone_number: phone,
    auth_time: seconds,
    firebase: { sign_in_provider: "phone" },
  },
});

// Add hierarchical references and collection-group reads to the existing small transaction store.
function store() {
  const db = sosStore(),
    collection = db.collection.bind(db);
  db.collection = (name) => {
    const c = collection(name);
    return {
      ...c,
      doc: (id) => {
        const ref = c.doc(id);
        return {
          ...ref,
          collection: (sub) => db.collection(`${ref.path}/${sub}`),
        };
      },
    };
  };
  db.collectionGroup = (name) => {
    const query = (filters = [], cap = Infinity) => ({
      where: (f, op, v) => query([...filters, [f, op, v]], cap),
      limit: (n) => query(filters, n),
      get: async () => ({
        docs: [...db.values]
          .filter(
            ([path, row]) =>
              path.split("/").at(-2) === name &&
              filters.every(([f, op, v]) =>
                op === "array-contains" ? row[f]?.includes(v) : row[f] === v,
              ),
          )
          .slice(0, cap)
          .map(([path, row]) => ({
            id: path.split("/").at(-1),
            ref: {
              path,
              parent: {
                parent: db
                  .collection(path.split("/")[0])
                  .doc(path.split("/")[1]),
              },
            },
            data: () => row,
          })),
      }),
    });
    return query();
  };
  return db;
}
async function fixture() {
  const db = store();
  await db
    .collection("communities")
    .doc("A")
    .set({ isActive: true, name: "Community A" });
  await db.collection("communities").doc("B").set({ isActive: true });
  for (const [uid, community] of [
    ["admin", "A"],
    ["other-admin", "B"],
    ["verifier", "A"],
  ])
    await db
      .collection("admins")
      .doc(uid)
      .set({
        uid,
        phoneNumber: phone,
        role: "admin",
        isActive: true,
        authorizedCommunityIds: [community],
      });
  await db.collection("users").doc("resident").set({
    uid: "resident",
    phoneNumber: phone,
    name: "Resident",
    role: "resident",
    communityId: "A",
    buildingId: "building",
    flatId: "flat",
    flatLabel: "N016",
    residentType: "owner",
    isActive: true,
    approvalStatus: "approved",
  });
  await db
    .collection("buildings")
    .doc("building")
    .set({ communityId: "A", totalFlats: 1, occupied: 1, vacant: 0 });
  await db.collection("flats").doc("flat").set({
    communityId: "A",
    buildingId: "building",
    status: "occupied",
    residentUserId: "resident",
  });
  const data = {
    residentUid: "resident",
    communityId: "A",
    supportCaseReference: "CASE-123",
    verificationMethod: "in_person_with_community_records",
    verificationEvidenceReference: "EVIDENCE-456",
    verificationNotes:
      "Identity and occupancy records checked independently; explicit deletion consent recorded.",
    consentAttested: true,
  };
  const f = { db, data, bucket: { getFiles: async () => [[], null] } };
  f.create = (patch = {}, context = {}) =>
    create({ db, app, auth: auth(), data: { ...data, ...patch }, ...context });
  f.verify = (request, patch = {}, context = {}) =>
    verify({
      db,
      app,
      auth: auth("verifier"),
      data: {
        requestId: request.requestId,
        intakeDigest: request.intakeDigest,
        identityConfirmed: true,
        consentConfirmed: true,
        ...patch,
      },
      ...context,
    });
  let exists = true,
    interrupt = false;
  f.authService = {
    getUser: async (uid) => {
      assert.equal(uid, "resident");
      if (!exists)
        throw Object.assign(Error("Absent"), { code: "auth/user-not-found" });
      return { uid };
    },
    deleteUser: async (uid) => {
      assert.equal(uid, "resident");
      assert.equal(db.values.has("users/resident"), false, "Auth must be last");
      assert.equal(db.values.get("flats/flat").residentUserId, null);
      assert.equal(db.values.get("flats/flat").status, "vacant");
      exists = false;
      if (interrupt) {
        interrupt = false;
        throw Object.assign(Error("Interrupted after deleting Auth"), {
          code: "auth/internal-error",
        });
      }
    },
  };
  f.interruptAuth = () => {
    interrupt = true;
  };
  f.authExists = () => exists;
  f.attempt = (request) =>
    attemptAccountDeletionRequestCore({
      db,
      bucket: f.bucket,
      firebaseAuth: f.authService,
      requestId: request.requestId,
    });
  return f;
}

test("authorized intake is pending, immutable, auditable and idempotent; verifier uses a fresh independently scoped session", async () => {
  const f = await fixture();
  const [a, b] = await Promise.all([f.create(), f.create()]);
  assert.equal(a.requestId, b.requestId);
  assert.equal([a, b].filter((r) => r.idempotent).length, 1);
  const path = `accountDeletionRequests/${a.requestId}`,
    pending = f.db.values.get(path);
  assert.equal(pending.sourceApp, "admin_assisted");
  assert.equal(pending.status, "pending_assisted_verification");
  assert.equal(pending.retry, undefined);
  assert.equal(pending.verificationCompletedAt, undefined);
  assert.equal(hasResidentDeletionVerification(pending), false);
  const pendingStatus = await status({ db: f.db, auth: { uid: "resident" } });
  assert.equal(pendingStatus.request.status, "pending_assisted_verification");
  assert.equal(pendingStatus.request.financialStatus, null);
  const result = await f.verify(a);
  assert.equal(result.processingStatus, "queued");
  const verified = f.db.values.get(path);
  assert.equal(hasResidentDeletionVerification(verified), true);
  assert.equal(
    (await status({ db: f.db, auth: { uid: "resident" } })).request
      .financialStatus,
    "zero_dues_automatic_processing",
  );
  assert.equal(verified.assistedIntake.initiatedBy, "admin");
  assert.equal(verified.assistedVerification.verifiedBy, "verifier");
  assert.equal(verified.assistedVerification.consentConfirmed, true);
  assert.ok(verified.assistedVerification.verifiedAt.toMillis() > 0);
  assert.equal((await f.verify(a)).idempotent, true);
  assert.equal((await f.create()).idempotent, true);
  assert.equal((await f.db.collection("auditLogs").get()).docs.length, 2);
  const queue = await list({
    db: f.db,
    auth: auth(),
    data: { communityId: "A" },
  });
  assert.equal(queue.requests[0].verificationStatus, "verified");
  assert.equal(queue.requests[0].sourceApp, "admin_assisted");
});

test("pending assisted requests cannot enter eligibility, coordinator, reassessment or financial handover", async () => {
  const f = await fixture(),
    request = await f.create();
  const context = {
    db: f.db,
    bucket: f.bucket,
    firebaseAuth: f.authService,
    data: { requestId: request.requestId },
  };
  assert.equal((await eligibility(context)).eligible, false);
  const result = await coordinate(context);
  assert.equal(result.status, "blocked");
  assert.equal(result.deletionPerformed, false);
  assert.equal(f.authExists(), true);
  assert.equal(f.db.values.get("flats/flat").status, "occupied");
  await assert.rejects(reassess({ ...context, auth: auth() }), {
    code: "failed-precondition",
  });
  await assert.rejects(
    handover({
      ...context,
      auth: auth(),
      data: {
        requestId: request.requestId,
        finding: "verified_handover",
        note: "Identity verification is still pending.",
        evidenceDigest: "a".repeat(64),
        retainFinancialRecords: true,
      },
    }),
    { code: "failed-precondition" },
  );
  // Adding retry metadata or a bare verified timestamp cannot bypass provenance.
  const record = f.db.values.get(
    `accountDeletionRequests/${request.requestId}`,
  );
  Object.assign(record, {
    retry: initialRetry(Date.now()),
    verificationCompletedAt: new Date(1),
  });
  assert.equal((await f.attempt(request)).status, "not_due");
  assert.equal(f.authExists(), true);
});

test("consent, independent evidence and supported verification method are mandatory; raw images and execution claims are rejected", async () => {
  const f = await fixture();
  for (const patch of [
    { consentAttested: false },
    { consentAttested: undefined },
    { verificationMethod: "email_only" },
    { verificationEvidenceReference: f.data.supportCaseReference },
    { verificationEvidenceReference: "" },
    { verificationNotes: "data:image/png;base64,secret" },
    { verificationNotes: "a".repeat(200) },
    { eligible: true },
    { verificationCompletedAt: new Date() },
    { sourceApp: "resident" },
  ])
    await assert.rejects(f.create(patch), { code: "invalid-argument" });
  const request = await f.create();
  for (const patch of [
    { identityConfirmed: false },
    { consentConfirmed: false },
    { consentConfirmed: undefined },
    { verifiedBy: "attacker" },
    { intakeDigest: "b".repeat(64) },
  ])
    await assert.rejects(f.verify(request, patch));
  assert.equal(
    f.db.values.get(`accountDeletionRequests/${request.requestId}`).retry,
    undefined,
  );
  await assert.rejects(
    f.create({ verificationEvidenceReference: "CHANGED-EVIDENCE" }),
    { code: "already-exists" },
  );
});

test("unauthorized, stale, non-phone, wrong-app, inactive and cross-community Admin actions fail closed", async () => {
  const f = await fixture();
  for (const context of [
    { auth: null },
    { auth: auth("resident") },
    { auth: auth("other-admin") },
    { auth: auth("admin", 1) },
    {
      auth: {
        ...auth(),
        token: { ...auth().token, firebase: { sign_in_provider: "password" } },
      },
    },
    {
      app: {
        appId: Object.keys(APP_CONTEXTS).find(
          (key) => APP_CONTEXTS[key].role === "resident",
        ),
      },
    },
  ])
    await assert.rejects(f.create({}, context));
  const request = await f.create();
  await assert.rejects(f.verify(request, {}, { auth: auth("other-admin") }), {
    code: "permission-denied",
  });
  await assert.rejects(f.verify(request, {}, { auth: auth("resident") }), {
    code: "permission-denied",
  });
  f.db.values.get("admins/admin").isActive = false;
  await assert.rejects(f.create(), { code: "permission-denied" });
  f.db.values.get("users/resident").communityId = "B";
  await assert.rejects(f.verify(request), { code: "failed-precondition" });
});

test("financial blockers remain mandatory and zero-balance verified handover reuses the existing coordinator and Auth-last cleanup", async () => {
  const f = await fixture();
  const request = await f.create();
  await f.verify(request);
  await f.db.collection("bills").doc("bill").set({
    communityId: "A",
    residentId: "resident",
    flatId: "flat",
    amount: 100,
    month: 10,
    year: 2026,
    status: "pending",
  });
  const blocked = await f.attempt(request);
  assert.equal(blocked.status, "blocked");
  assert.equal(f.authExists(), true);
  assert.equal(f.db.values.get("flats/flat").status, "occupied");
  const record = f.db.values.get(
    `accountDeletionRequests/${request.requestId}`,
  );
  assert.equal(record.financialReviewRequired, true);
  const bill = f.db.values.get("bills/bill");
  bill.status = "paid";
  bill.paidAt = new Date();
  const evidence = await financialHandoverEvidence({
    db: f.db,
    requestId: request.requestId,
    uid: "resident",
    communityId: "A",
  });
  await handover({
    db: f.db,
    auth: auth(),
    data: {
      requestId: request.requestId,
      finding: "verified_handover",
      note: "Settled balance and retained billing records independently reviewed.",
      evidenceDigest: evidence.digest,
      retainFinancialRecords: true,
    },
  });
  const completed = await f.attempt(request);
  assert.equal(completed.status, "completed", JSON.stringify(completed));
  assert.equal(f.authExists(), false);
  assert.equal(f.db.values.has("users/resident"), false);
  assert.equal(f.db.values.get("bills/bill").flatId, "flat");
  assert.equal(f.db.values.get("buildings/building").vacant, 1);
  assert.equal((await f.verify(request)).idempotent, true);
  assert.equal((await f.create()).status, "completed");
  assert.equal((await f.db.collection("auditLogs").get()).docs.length, 2);
});

test("retry/recovery resumes assisted Auth-last interruption from the existing durable evidence", async () => {
  const f = await fixture(),
    request = await f.create();
  await f.verify(request);
  f.interruptAuth();
  const interrupted = await f.attempt(request);
  assert.equal(
    interrupted.status,
    "reconciliation_required",
    JSON.stringify(interrupted),
  );
  const record = f.db.values.get(
    `accountDeletionRequests/${request.requestId}`,
  );
  assert.equal(record.retry.state, "queued");
  const result = await attemptAccountDeletionRequestCore({
    db: f.db,
    bucket: f.bucket,
    firebaseAuth: f.authService,
    requestId: request.requestId,
    now: Date.now() + retryDelay(1) + 1000,
  });
  assert.equal(result.status, "completed", JSON.stringify(result));
  assert.equal(record.assistedIntake.initiatedBy, "admin");
});

test("ordinary sourceApp admin/web is not assisted verification and Resident reauthentication cannot promote an assisted intake", async () => {
  const f = await fixture(),
    request = await f.create();
  const record = f.db.values.get(
    `accountDeletionRequests/${request.requestId}`,
  );
  for (const sourceApp of ["admin", "web"]) {
    const forged = {
      ...record,
      sourceApp,
      verificationCompletedAt: new Date(1),
    };
    assert.equal(hasResidentDeletionVerification(forged), false);
  }
  await assert.rejects(
    submit({
      db: f.db,
      auth: auth("resident", 1),
      data: { sourceApp: "resident" },
    }),
    { code: "failed-precondition" },
  );
  const status = await submit({
    db: f.db,
    auth: auth("resident"),
    data: { sourceApp: "resident" },
  });
  assert.equal(status.status, "pending_assisted_verification");
  assert.equal(record.assistedVerification, undefined);
  assert.equal(record.retry, undefined);
});

test("canonical role ambiguity and existing unverified request conflicts do not create parallel deletion engines", async () => {
  const f = await fixture();
  await f.db
    .collection("securityStaff")
    .doc("resident")
    .set({ role: "security", communityId: "A" });
  await assert.rejects(f.create(), { code: "failed-precondition" });
  await f.db.collection("securityStaff").doc("resident").delete();
  await f.db.collection("accountDeletionRequests").doc("existing").set({
    requestId: "existing",
    uid: "resident",
    sourceApp: "web",
    communityId: "A",
    status: "pending_verification",
  });
  await assert.rejects(f.create(), { code: "failed-precondition" });
  assert.equal(
    (await f.db.collection("accountDeletionRequests").get()).docs.length,
    1,
  );
});

test("App Check/canonical phone wrappers and private Firestore request rules remain enforced", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  for (const name of [
    "createAdminAssistedDeletionRequest",
    "verifyAdminAssistedDeletionRequest",
  ])
    assert.match(source, new RegExp(`exports\\.${name} = appCheckedCallable`));
  const rules = fs.readFileSync(
    require("node:path").join(__dirname, "../../firestore.rules"),
    "utf8",
  );
  assert.match(
    rules,
    /match \/accountDeletionRequests\/\{requestId\} \{\s*allow read, write: if false;/,
  );
});

test("verified assisted provenance is bound to UID, community, immutable evidence and both consent checks", async () => {
  const f = await fixture(),
    request = await f.create();
  await f.verify(request);
  const source = f.db.values.get(
    `accountDeletionRequests/${request.requestId}`,
  );
  for (const mutate of [
    (r) => {
      r.sourceApp = "resident";
    },
    (r) => {
      r.sourceApp = "admin";
    },
    (r) => {
      delete r.assistedVerification;
    },
    (r) => {
      r.assistedIntake.consentAttested = false;
    },
    (r) => {
      r.assistedIntake.verificationNotes =
        "Changed evidence after verification.";
    },
    (r) => {
      r.assistedVerification.identityConfirmed = false;
    },
    (r) => {
      r.assistedVerification.consentConfirmed = false;
    },
    (r) => {
      r.assistedVerification.uid = "other";
    },
    (r) => {
      r.assistedVerification.communityId = "B";
    },
    (r) => {
      r.assistedVerification.intakeDigest = "b".repeat(64);
    },
    (r) => {
      r.verificationCompletedAt = new Date(Date.now() + 60000);
    },
    (r) => {
      r.assistedVerification.verifiedAt = new Date(1);
    },
  ]) {
    const draft = {
      ...source,
      assistedIntake: { ...source.assistedIntake },
      assistedVerification: { ...source.assistedVerification },
    };
    mutate(draft);
    assert.equal(hasResidentDeletionVerification(draft), false);
  }
});

test("existing verified Resident requests are reused without changing their origin or creating an assisted intake", async () => {
  const f = await fixture();
  await f.db
    .collection("accountDeletionRequests")
    .doc("existing")
    .set({
      requestId: "existing",
      uid: "resident",
      communityId: "A",
      sourceApp: "resident",
      communityScopeVerified: true,
      verificationCompletedAt: new Date(1),
      status: "pending_review",
    });
  const result = await f.create();
  assert.equal(result.requestId, "existing");
  assert.equal(result.existingVerifiedRequest, true);
  assert.equal(result.sourceApp, "resident");
  assert.equal(
    (await f.db.collection("accountDeletionRequests").get()).docs.length,
    1,
  );
  assert.equal((await f.db.collection("auditLogs").get()).docs.length, 0);
  await assert.rejects(
    f.verify({ requestId: "existing", intakeDigest: "a".repeat(64) }),
    { code: "failed-precondition" },
  );
});
