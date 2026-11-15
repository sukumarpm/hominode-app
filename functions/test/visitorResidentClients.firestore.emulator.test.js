const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { randomUUID } = require("node:crypto");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  createVisitorInvitationCore,
  getVisitorCredentialsCore,
} = require("../src/visitor_credentials");
const {
  getResidentVisitorContextCore,
  mutateResidentVisitorCore,
  updateCommunityVisitorPolicyCore,
} = require("../src/visitor_policy_management");
const { verifyVisitorCredentialCore } = require("../src/visitor_verification");
const shared = JSON.parse(
  fs.readFileSync(
    `${__dirname}/../../docs/fixtures/resident_visitor_contract.json`,
    "utf8",
  ),
);
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = "demo-hominode-resident-clients";
const key = "synthetic-resident-client-contract-hmac-key";
const phone = "+639170000000";
const auth = (uid) => ({
  uid,
  token: { phone_number: phone, firebase: { sign_in_provider: "phone" } },
});
let db, app, env;
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").pop()),
      rules: fs.readFileSync(`${__dirname}/../../firestore.rules`, "utf8"),
    },
  });
  app = initializeApp({ projectId }, `resident-clients-${randomUUID()}`);
  db = getFirestore(app);
});
test.after(async () => {
  if (app) await deleteApp(app);
  if (env) await env.cleanup();
});
async function fixture({
  enforce = true,
  mode = "resident_authorized",
  role = "owner",
} = {}) {
  const uid = `host-${randomUUID()}`,
    communityId = `C-${randomUUID()}`,
    flatId = `F-${randomUUID()}`,
    admin = `admin-${randomUUID()}`,
    security = `gate-${randomUUID()}`;
  const batch = db.batch();
  batch.set(db.collection("communities").doc(communityId), {
    isActive: true,
    timeZone: "Asia/Manila",
    visitorPolicyRolloutReady: true,
  });
  batch.set(db.collection("users").doc(uid), {
    uid,
    role: "resident",
    phoneNumber: phone,
    isActive: true,
    status: "active",
    approvalStatus: "approved",
    communityId,
    flatId,
    residentType: role,
    ownershipType: role,
    identityVerified: role === "tenant",
    identityVerificationStatus: role === "tenant" ? "verified" : "not_required",
  });
  batch.set(db.collection("flats").doc(flatId), {
    communityId,
    status: "occupied",
    residentUserId: uid,
    flatLabel: "N014",
  });
  batch.set(db.collection("admins").doc(admin), {
    uid: admin,
    role: "admin",
    phoneNumber: phone,
    isActive: true,
    authorizedCommunityIds: [communityId],
  });
  batch.set(db.collection("securityStaff").doc(security), {
    uid: security,
    role: "security",
    phoneNumber: phone,
    isActive: true,
    communityId,
  });
  await batch.commit();
  const config = {
    schemaVersion: 1,
    enabled: enforce,
    timeZone: "Asia/Manila",
    approvalMode: mode,
    emergency: null,
    pets: { mode: "allowed", normalMode: "allowed", restriction: null },
  };
  const configure = (policy, expectedRevision = 0) =>
    updateCommunityVisitorPolicyCore({
      db,
      auth: auth(admin),
      data: { communityId, policy, expectedRevision },
    });
  if (enforce) await configure(config);
  else await db.collection('communities').doc(communityId).update({visitorPolicy: {...config, revision: 1}});
  const arrival = Date.now() + 3600000;
  const create = (extra = {}) =>
    createVisitorInvitationCore({
      db,
      auth: auth(uid),
      hmacKey: key,
      data: { ...shared.create, expectedArrival: arrival, ...extra },
    });
  const get = (id) =>
    db
      .collection("visitors")
      .doc(id)
      .get()
      .then((doc) => doc.data());
  const mutate = (id, action, expectedRevision, extra = {}) =>
    mutateResidentVisitorCore({
      db,
      auth: auth(uid),
      hmacKey: key,
      data: { visitorId: id, action, expectedRevision, ...extra },
    });
  return {
    uid,
    communityId,
    flatId,
    admin,
    security,
    arrival,
    config,
    configure,
    create,
    get,
    mutate,
  };
}
test(
  "Resident cancellation is audited, retains history, rejects replay and invalidates captured QR/manual credentials",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      issued = await f.create(),
      row = await f.get(issued.visitorId);
    assert.equal(row.visitorPolicySnapshot.identityVerified, false);
    assert.equal(
      row.visitorPolicySnapshot.identityBasis,
      "community_owner_exemption",
    );
    await f.mutate(issued.visitorId, "cancel", row.authorizationRevision);
    const cancelled = await f.get(issued.visitorId);
    assert.equal(cancelled.status, "cancelled");
    assert.equal(cancelled.authorizationState, "revoked");
    await assert.rejects(
      f.mutate(issued.visitorId, "cancel", row.authorizationRevision),
      { code: "aborted" },
    );
    await assert.rejects(
      getVisitorCredentialsCore({
        db,
        auth: auth(f.uid),
        hmacKey: key,
        data: { visitorId: issued.visitorId },
      }),
    );
    for (const credential of [
      { qrToken: issued.qrToken },
      { manualCode: issued.visitorPassCode },
    ])
      await assert.rejects(
        verifyVisitorCredentialCore({
          db,
          auth: auth(f.security),
          hmacKey: key,
          data: { ...credential, operationId: randomUUID() },
        }),
      );
    const audits = await db
      .collection("auditLogs")
      .where("targetId", "==", issued.visitorId)
      .get();
    assert.ok(
      audits.docs.some((doc) => doc.data().action === "visitor.cancel"),
    );
    assert.equal(
      JSON.stringify(audits.docs.map((doc) => doc.data())).includes(
        issued.qrToken,
      ),
      false,
    );
  },
);
test(
  "Resident rescheduling reevaluates mandatory approval and pet policy, preserving private indexes and audit history",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      issued = await f.create();
    await f.configure(
      { ...f.config, approvalMode: "all_approval_required" },
      1,
    );
    const changed = await f.mutate(issued.visitorId, "reschedule", 1, {
      expectedArrival: f.arrival + 3600000,
      bringingPet: false,
    });
    assert.equal(changed.authorizationState, "pending_admin");
    const row = await f.get(issued.visitorId),
      secret = (
        await db
          .collection("visitorHostCredentials")
          .doc(issued.visitorId)
          .get()
      ).data();
    assert.equal(
      secret.validFrom.toMillis(),
      row.credentialValidFrom.toMillis(),
    );
    assert.equal(
      secret.expiresAt.toMillis(),
      row.credentialExpiresAt.toMillis(),
    );
    await assert.rejects(
      verifyVisitorCredentialCore({
        db,
        auth: auth(f.security),
        hmacKey: key,
        data: { qrToken: issued.qrToken, operationId: randomUUID() },
      }),
    );
    await f.configure(
      {
        ...f.config,
        pets: {
          mode: "not_allowed",
          normalMode: "not_allowed",
          restriction: null,
        },
      },
      2,
    );
    await assert.rejects(
      f.mutate(issued.visitorId, "reschedule", 2, { bringingPet: true }),
      { message: shared.petMessage },
    );
    assert.equal((await f.get(issued.visitorId)).authorizationRevision, 2);
  },
);
test(
  "verified tenant requires review while an exempt owner is not silently treated as identity-verified",
  { skip: !enabled },
  async () => {
    const f = await fixture({
      mode: "tenant_approval_required",
      role: "tenant",
    });
    const context = await getResidentVisitorContextCore({
      db,
      auth: auth(f.uid),
      data: { expectedArrival: f.arrival },
    });
    assert.equal(context.authorizationState, "pending_admin");
    const issued = await f.create({ bringingPet: false });
    assert.equal(issued.authorizationState, "pending_admin");
    assert.equal(issued.qrToken, undefined);
    await db.collection("users").doc(f.uid).update({ identityVerified: false });
    await assert.rejects(f.create());
    await db
      .collection("users")
      .doc(f.uid)
      .update({ identityVerified: true, isActive: false });
    await assert.rejects(f.create());
    await db.collection("users").doc(f.uid).update({ isActive: true });
    await db
      .collection("flats")
      .doc(f.flatId)
      .update({ residentUserId: "someone-else" });
    await assert.rejects(f.create());
  },
);
test(
  "foreign Resident cannot retrieve or mutate credentials or invitation data",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      foreign = await fixture(),
      issued = await f.create({ bringingPet: false });
    await assert.rejects(
      mutateResidentVisitorCore({
        db,
        auth: auth(foreign.uid),
        hmacKey: key,
        data: {
          ...shared.cancel,
          visitorId: issued.visitorId,
          expectedRevision: 1,
        },
      }),
      { code: "permission-denied" },
    );
    await assert.rejects(
      getVisitorCredentialsCore({
        db,
        auth: auth(foreign.uid),
        hmacKey: key,
        data: { visitorId: issued.visitorId },
      }),
    );
    const client = (uid) =>
      env.authenticatedContext(uid, auth(uid).token).firestore();
    await assertSucceeds(
      client(f.uid).collection("visitors").doc(issued.visitorId).get(),
    );
    await assertFails(
      client(foreign.uid).collection("visitors").doc(issued.visitorId).get(),
    );
    await assertFails(
      client(f.uid).collection("visitors").doc(issued.visitorId).delete(),
    );
    await assertFails(
      client(f.uid)
        .collection("visitorHostCredentials")
        .doc(issued.visitorId)
        .get(),
    );
  },
);
test("saving selected approval/emergency/pet settings respects the enforcement toggle", {skip: !enabled}, async () => {
  const f = await fixture({enforce: false});
  const input = {...f.config, enabled: true, approvalMode: 'all_approval_required',
    emergency: {startAt: Date.now() - 1000, endAt: Date.now() + 3600000},
    pets: {mode: 'not_allowed', normalMode: 'not_allowed', restriction: null}};
  // The fixture seeds historical disabled configuration directly; new Admin
  // saves always enforce, and readiness remains a server-owned prerequisite.
  await f.configure({...input, enabled: false}, 1);
  await f.configure(input, 2);
  const context = await getResidentVisitorContextCore({db, auth: auth(f.uid), data: {expectedArrival: f.arrival}});
  assert.equal(context.authorizationState, 'pending_admin');
  assert.equal(context.petPermitted, false);
  await assert.rejects(f.create({bringingPet: true}), {message: shared.petMessage});
  await assert.rejects(f.create({bringingPet: 'false'}), {code: 'invalid-argument'});
  assert.equal((await f.create({bringingPet: false})).credentialsAvailable, false);
});
