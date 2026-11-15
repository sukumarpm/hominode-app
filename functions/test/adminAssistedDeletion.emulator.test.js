const test = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const {
  initializeTestEnvironment,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { APP_CONTEXTS } = require("../src/notifications");
const {
  createAdminAssistedDeletionRequestCore: create,
  verifyAdminAssistedDeletionRequestCore: verify,
} = require("../src/account_deletion_assisted");
const {
  attemptAccountDeletionRequestCore: attempt,
  retryDelay,
} = require("../src/account_deletion_retry");
const {
  coordinateAccountDeletionFulfillmentCore: coordinate,
  financialHandoverEvidence,
  recordDeletionFinancialReviewCore: handover,
  listCommunityDeletionRequestsCore: list,
} = require("../src/account_deletion_requests");
const projectId = "demo-hominode-assisted-deletion";
if (
  process.env.GCLOUD_PROJECT !== projectId ||
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  !process.env.FIREBASE_STORAGE_EMULATOR_HOST
)
  throw Error(
    "Firestore/Auth/Storage emulators and the demo-hominode-assisted-deletion project are required.",
  );
let app, db, authService, bucket, environment;
const phone = "+639170000000";
const adminApp = {
  appId: Object.keys(APP_CONTEXTS).find(
    (key) => APP_CONTEXTS[key].role === "admin",
  ),
};
const authenticated = (uid) => ({
  uid,
  token: {
    auth_time: Math.floor(Date.now() / 1000),
    phone_number: phone,
    firebase: { sign_in_provider: "phone" },
  },
});
test.before(async () => {
  app = initializeApp(
    { projectId, storageBucket: `${projectId}.appspot.com` },
    "assisted-deletion-tests",
  );
  db = getFirestore(app);
  authService = getAuth(app);
  bucket = getStorage(app).bucket();
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").pop()),
      rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});
test.after(async () => {
  if (environment) await environment.cleanup();
  if (app) await deleteApp(app);
});
async function fixture() {
  const token = randomUUID(),
    uid = `resident-${token}`,
    admin = `admin-${token}`,
    communityId = `A-${token}`,
    buildingId = `nova-${token}`,
    flatId = `n016-${token}`;
  await authService.createUser({ uid, email: `${uid}@example.invalid` });
  const batch = db.batch();
  batch.set(db.collection("communities").doc(communityId), {
    isActive: true,
    name: "Assisted deletion fixture",
  });
  batch.set(db.collection("admins").doc(admin), {
    uid: admin,
    phoneNumber: phone,
    role: "admin",
    isActive: true,
    authorizedCommunityIds: [communityId],
  });
  batch.set(db.collection("users").doc(uid), {
    uid,
    role: "resident",
    communityId,
    buildingId,
    flatId,
    flatLabel: "N016",
    name: "Synthetic Resident",
    phoneNumber: phone,
    residentType: "owner",
    ownershipType: "owner",
    approvalStatus: "approved",
    isActive: true,
    identityVerificationStatus: "not_required",
  });
  batch.set(db.collection("buildings").doc(buildingId), {
    communityId,
    totalFlats: 1,
    occupied: 1,
    vacant: 0,
  });
  batch.set(db.collection("flats").doc(flatId), {
    communityId,
    buildingId,
    status: "occupied",
    residentUserId: uid,
  });
  await batch.commit();
  const data = {
    residentUid: uid,
    communityId,
    supportCaseReference: `CASE-${token}`,
    verificationMethod: "document_and_community_records",
    verificationEvidenceReference: `EVIDENCE-${token}`,
    verificationNotes:
      "Protected evidence and community records independently checked; explicit deletion consent verified.",
    consentAttested: true,
  };
  const f = { uid, admin, communityId, buildingId, flatId, data };
  f.create = () =>
    create({ db, auth: authenticated(admin), app: adminApp, data });
  f.verify = (request) =>
    verify({
      db,
      auth: authenticated(admin),
      app: adminApp,
      data: {
        requestId: request.requestId,
        intakeDigest: request.intakeDigest,
        identityConfirmed: true,
        consentConfirmed: true,
      },
    });
  f.authLast = {
    getUser: (uid) => authService.getUser(uid),
    deleteUser: async (target) => {
      assert.equal(target, uid);
      assert.equal((await db.collection("users").doc(uid).get()).exists, false);
      assert.equal(
        (await db.collection("flats").doc(flatId).get()).data().status,
        "vacant",
      );
      const processing = await db
        .collection("accountDeletionRequests")
        .doc(f.request.requestId)
        .collection("processing")
        .doc("residentProfile")
        .get();
      assert.equal(processing.data().status, "completed");
      await authService.deleteUser(uid);
    },
  };
  f.attempt = () =>
    attempt({
      db,
      bucket,
      firebaseAuth: f.authLast,
      requestId: f.request.requestId,
    });
  return f;
}

test("pending assisted intake remains non-destructive and clients cannot forge verification or create requests", async () => {
  const f = await fixture();
  const [first, second] = await Promise.all([f.create(), f.create()]);
  f.request = first;
  assert.equal(first.requestId, second.requestId);
  assert.equal([first, second].filter((r) => r.idempotent).length, 1);
  const result = await coordinate({
    db,
    bucket,
    firebaseAuth: f.authLast,
    data: { requestId: first.requestId },
  });
  assert.equal(result.status, "blocked");
  assert.equal((await db.collection("users").doc(f.uid).get()).exists, true);
  assert.equal(
    (await db.collection("flats").doc(f.flatId).get()).data().status,
    "occupied",
  );
  assert.equal((await authService.getUser(f.uid)).uid, f.uid);
  for (const uid of [f.admin, f.uid]) {
    const client = environment
      .authenticatedContext(uid, authenticated(uid).token)
      .firestore();
    await assertFails(
      client
        .collection("accountDeletionRequests")
        .doc(first.requestId)
        .update({ verificationCompletedAt: new Date(), sourceApp: "resident" }),
    );
    await assertFails(
      client
        .collection("accountDeletionRequests")
        .doc(first.requestId)
        .delete(),
    );
    await assertFails(
      client
        .collection("accountDeletionRequests")
        .doc(first.requestId)
        .collection("processing")
        .doc("residentProfile")
        .set({ status: "completed", uid: f.uid }),
    );
    await assertFails(client.collection("users").doc(f.uid).delete());
    await assertFails(
      client
        .collection("accountDeletionRequests")
        .doc(`forged-${uid}`)
        .set({
          uid: f.uid,
          sourceApp: "admin_assisted",
          communityId: f.communityId,
          assistedVerification: { consentConfirmed: true },
        }),
    );
  }
});

test("verified assisted requests use the existing full lifecycle with Auth last, stable duplicates and retained provenance", async () => {
  const f = await fixture();
  f.request = await f.create();
  await f.verify(f.request);
  assert.equal((await f.verify(f.request)).idempotent, true);
  const result = await f.attempt();
  assert.equal(result.status, "completed", JSON.stringify(result));
  await assert.rejects(authService.getUser(f.uid), {
    code: "auth/user-not-found",
  });
  assert.equal(
    (await db.collection("buildings").doc(f.buildingId).get()).data().vacant,
    1,
  );
  const request = (
    await db
      .collection("accountDeletionRequests")
      .doc(f.request.requestId)
      .get()
  ).data();
  assert.equal(request.sourceApp, "admin_assisted");
  assert.equal(request.completionVerified, true);
  assert.equal(request.assistedIntake.initiatedBy, f.admin);
  assert.equal(request.assistedVerification.verifiedBy, f.admin);
  assert.equal(request.assistedVerification.consentConfirmed, true);
  assert.equal((await f.create()).status, "completed");
  assert.equal((await f.verify(f.request)).status, "completed");
  const audits = await db
    .collection("auditLogs")
    .where("targetId", "==", f.uid)
    .get();
  assert.equal(audits.size, 2);
  const queue = await list({
    db,
    auth: authenticated(f.admin),
    data: { communityId: f.communityId },
  });
  assert.equal(queue.requests[0].status, "completed");
  assert.equal(queue.requests[0].resident.displayName, "Synthetic Resident");
});

test("financial dues prevent deletion until verified zero-balance handover; financial history and unit links remain intact", async () => {
  const f = await fixture();
  f.request = await f.create();
  await f.verify(f.request);
  const billRef = db.collection("bills").doc(`bill-${f.uid}`);
  await billRef.set({
    residentId: f.uid,
    communityId: f.communityId,
    flatId: f.flatId,
    buildingId: f.buildingId,
    amount: 100,
    month: 10,
    year: 2026,
    status: "pending",
  });
  assert.equal((await f.attempt()).status, "blocked");
  assert.equal((await f.create()).idempotent, true);
  assert.equal(
    (await db.collection("flats").doc(f.flatId).get()).data().status,
    "occupied",
  );
  assert.equal((await authService.getUser(f.uid)).uid, f.uid);
  await billRef.update({ status: "paid", paidAt: Timestamp.now() });
  const evidence = await financialHandoverEvidence({
    db,
    requestId: f.request.requestId,
    uid: f.uid,
    communityId: f.communityId,
  });
  await handover({
    db,
    auth: authenticated(f.admin),
    data: {
      requestId: f.request.requestId,
      finding: "verified_handover",
      note: "Settled billing records checked and original links retained.",
      evidenceDigest: evidence.digest,
      retainFinancialRecords: true,
    },
  });
  assert.equal((await f.attempt()).status, "completed");
  assert.equal((await billRef.get()).data().flatId, f.flatId);
  assert.equal((await billRef.get()).data().status, "paid");
});

test("assisted deletion recovers after Auth deletion interrupts the response", async () => {
  const f = await fixture();
  f.request = await f.create();
  await f.verify(f.request);
  const interrupted = {
    ...f.authLast,
    deleteUser: async (uid) => {
      await f.authLast.deleteUser(uid);
      throw Object.assign(Error("Synthetic interruption after Auth deletion"), {
        code: "auth/internal-error",
      });
    },
  };
  const result = await attempt({
    db,
    bucket,
    firebaseAuth: interrupted,
    requestId: f.request.requestId,
  });
  assert.equal(
    result.status,
    "reconciliation_required",
    JSON.stringify(result),
  );
  const recovered = await attempt({
    db,
    bucket,
    firebaseAuth: f.authLast,
    requestId: f.request.requestId,
    now: Date.now() + retryDelay(1) + 1000,
  });
  assert.equal(recovered.status, "completed", JSON.stringify(recovered));
  assert.equal(
    (
      await db
        .collection("accountDeletionRequests")
        .doc(f.request.requestId)
        .get()
    ).data().completionVerified,
    true,
  );
});
