const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { randomUUID } = require("node:crypto");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");
const {
  createVisitorInvitationCore,
  getVisitorCredentialsCore,
} = require("../src/visitor_credentials");
const { verifyVisitorCredentialCore } = require("../src/visitor_verification");
const {
  resolveVisitorQrCore,
  transitionVisitorFromQrCore,
} = require("../src/visitor_gate");
const { checkoutVisitorsCore, denyVisitorEntryCore, listSecurityVisitorsCore } = require("../src/security_visitor_workflow");
const { dispatchVisitorDecisionCore } = require("../src/visitor_notifications");
const { notificationAudienceKey } = require("../src/notifications");
const {
  getCommunityVisitorPolicyCore,
  updateCommunityVisitorPolicyCore,
  decideVisitorInvitationCore,
  mutateResidentVisitorCore,
  getVisitorPolicyHistoryCore,
  getResidentVisitorContextCore,
} = require("../src/visitor_policy_management");

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = "demo-hominode-visitor-policy";
const hmacKey = "synthetic-policy-test-key-at-least-32-bytes";
const phone = "+639170000000";
const auth = (uid) => ({
  uid,
  token: { phone_number: phone, firebase: { sign_in_provider: "phone" } },
});
const policy = (extra = {}) => ({
  schemaVersion: 1,
  enabled: true,
  timeZone: "Asia/Manila",
  approvalMode: "resident_authorized",
  emergency: null,
  pets: { mode: "allowed", normalMode: "allowed", restriction: null },
  ...extra,
});
let app, env, db;
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
  app = initializeApp({ projectId }, `visitor-policy-${randomUUID()}`);
  db = getFirestore(app);
});
test.after(async () => {
  if (app) await deleteApp(app);
  if (env) await env.cleanup();
});

async function fixture({
  mode = "resident_authorized",
  role = "owner",
  enforce = true,
} = {}) {
  const suffix = randomUUID(),
    communityId = `C-${suffix}`,
    host = `h-${suffix}`;
  const admin = `a-${suffix}`,
    security = `s-${suffix}`,
    flat = `f-${suffix}`,
    other = `o-${suffix}`;
  const communityRef = db.collection("communities").doc(communityId);
  const batch = db.batch();
  batch.set(communityRef, {
    isActive: true,
    timeZone: "Asia/Manila",
    visitorPolicyRolloutReady: true,
  });
  batch.set(db.collection("users").doc(host), {
    uid: host,
    role: "resident",
    communityId,
    flatId: flat,
    phoneNumber: phone,
    approvalStatus: "approved",
    isActive: true,
    status: "active",
    residentType: role,
    ownershipType: role,
    identityVerified: true,
    identityVerificationStatus: "verified",
    name: "Policy Host",
  });
  batch.set(db.collection("flats").doc(flat), {
    communityId,
    status: "occupied",
    residentUserId: host,
    flatLabel: "N014",
  });
  batch.set(db.collection("admins").doc(admin), {
    uid: admin,
    role: "admin",
    isActive: true,
    phoneNumber: phone,
    authorizedCommunityIds: [communityId],
  });
  batch.set(db.collection("admins").doc(other), {
    uid: other,
    role: "admin",
    isActive: true,
    phoneNumber: phone,
    authorizedCommunityIds: ["OTHER"],
  });
  batch.set(db.collection("securityStaff").doc(security), {
    uid: security,
    role: "security",
    phoneNumber: phone,
    communityId,
    isActive: true,
  });
  await batch.commit();
  const configure = (value, expectedRevision = 0) =>
    updateCommunityVisitorPolicyCore({
      db,
      auth: auth(admin),
      data: {
        communityId,
        policy: value,
        expectedRevision,
        reason: "Test policy decision",
      },
    });
  if (enforce) await configure(policy({ approvalMode: mode }));
  const create = (extra = {}) =>
    createVisitorInvitationCore({
      db,
      auth: auth(host),
      hmacKey,
      data: {
        visitorName: "Policy Guest",
        purpose: "Visit",
        expectedArrival: Date.now(),
        ...extra,
      },
    });
  const get = (visitorId) =>
    db
      .collection("visitors")
      .doc(visitorId)
      .get()
      .then((snapshot) => snapshot.data());
  const retrieve = (visitorId) =>
    getVisitorCredentialsCore({
      db,
      auth: auth(host),
      hmacKey,
      data: { visitorId },
    });
  const secret = (visitorId) =>
    db
      .collection("visitorHostCredentials")
      .doc(visitorId)
      .get()
      .then((snapshot) => snapshot.data());
  const verify = (credential, operationId = randomUUID()) =>
    verifyVisitorCredentialCore({
      db,
      auth: auth(security),
      hmacKey,
      data: { ...credential, operationId },
    });
  const decide = (
    visitorId,
    action = "approve",
    expectedRevision = 1,
    actor = admin,
  ) =>
    decideVisitorInvitationCore({
      db,
      auth: auth(actor),
      data: { communityId, visitorId, action, expectedRevision },
    });
  const mutate = (visitorId, action, expectedRevision = 1, extra = {}) =>
    mutateResidentVisitorCore({
      db,
      auth: auth(host),
      hmacKey,
      data: { visitorId, action, expectedRevision, ...extra },
    });
  const client = (uid) =>
    env.authenticatedContext(uid, auth(uid).token).firestore();
  return {
    communityId,
    communityRef,
    host,
    admin,
    other,
    security,
    flat,
    create,
    get,
    retrieve,
    secret,
    verify,
    decide,
    mutate,
    configure,
    client,
  };
}

for (const mode of [
  "resident_authorized",
  "tenant_approval_required",
  "all_approval_required",
]) {
  for (const role of ["owner", "tenant"]) {
    test(
      `${mode}/${role}: issuance, retrieval, captured QR/manual and Admin authorization`,
      { skip: !enabled },
      async () => {
        const f = await fixture({ mode, role }),
          issued = await f.create();
        const visitor = await f.get(issued.visitorId),
          secret = await f.secret(issued.visitorId);
        const pending =
          mode === "all_approval_required" ||
          (mode === "tenant_approval_required" && role === "tenant");
        assert.equal(
          visitor.authorizationState,
          pending ? "pending_admin" : "auto_authorized",
        );
        assert.equal(visitor.status, "expected");
        assert.equal(visitor.isApproved, false);
        assert.equal("qrToken" in visitor, false);
        assert.equal("manualCode" in visitor, false);
        if (pending) {
          assert.equal(issued.qrToken, undefined);
          assert.equal(issued.visitorPassCode, undefined);
          await assert.rejects(f.retrieve(issued.visitorId));
          for (const credential of [
            { qrToken: secret.qrToken },
            { manualCode: secret.manualCode },
          ])
            await assert.rejects(f.verify(credential));
          await assert.rejects(
            resolveVisitorQrCore({
              db,
              auth: auth(f.security),
              hmacKey,
              data: { qrToken: secret.qrToken },
            }),
          );
          await assert.rejects(
            transitionVisitorFromQrCore({
              db,
              auth: auth(f.security),
              hmacKey,
              data: {
                visitorId: issued.visitorId,
                qrToken: secret.qrToken,
                action: "approve",
              },
            }),
          );
          await f.decide(issued.visitorId);
        }
        const credentials = await f.retrieve(issued.visitorId);
        assert.equal(credentials.qrToken, secret.qrToken);
        const before = await f.get(issued.visitorId),
          result = await f.verify({ qrToken: credentials.qrToken });
        assert.equal(result.status, "inside");
        assert.equal(result.bringingPet, false);
        const after = await f.get(issued.visitorId);
        assert.equal(after.authorizationState, before.authorizationState);
        assert.equal(after.approvedBy, pending ? f.admin : null);
        assert.equal(after.checkedInBy, f.security);
      },
    );
  }
}
test(
  "manual entry preserves check-in, notification dispatch and retry idempotence",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      issued = await f.create(),
      secret = await f.retrieve(issued.visitorId);
    const ref = db.collection("visitors").doc(issued.visitorId);
    const before = await ref.get(),
      op = randomUUID();
    const result = await f.verify({ manualCode: secret.visitorPassCode }, op);
    assert.equal(result.verificationMethod, "manual");
    assert.equal(
      (await f.verify({ manualCode: secret.visitorPassCode }, op)).idempotent,
      true,
    );
    const after = await ref.get();
    const token = `policy-device-${randomUUID()}`;
    await db
      .collection("notificationDevices")
      .doc(randomUUID())
      .set({
        audienceKey: notificationAudienceKey({
          appId: "resident",
          role: "resident",
          communityId: f.communityId,
          uid: f.host,
        }),
        uid: f.host,
        communityId: f.communityId,
        appId: "resident",
        role: "resident",
        active: true,
        token,
      });
    // Use the existing dispatcher and Firebase emulator; messaging is the only fake.
    const messages = [];
    const messaging = {
      sendEachForMulticast: async (value) => {
        messages.push(value);
        return { responses: value.tokens.map(() => ({ success: true })) };
      },
    };
    const args = {
      db,
      messaging,
      event: {
        id: randomUUID(),
        params: { visitorId: issued.visitorId },
        data: { before, after },
      },
    };
    await dispatchVisitorDecisionCore(args);
    await dispatchVisitorDecisionCore(args);
    const notifications = await db
      .collection("notifications")
      .where("recipientId", "==", f.host)
      .get();
    assert.equal(notifications.size, 1);
    assert.equal(notifications.docs[0].data().eventType, "visitor_checked_in");
    assert.equal(messages.length, 1);
    assert.deepEqual(messages[0].tokens, [token]);
    await assert.rejects(f.verify({ qrToken: "not-a-valid-credential" }));
    await checkoutVisitorsCore({
      db,
      auth: auth(f.security),
      data: { visitorIds: [issued.visitorId], operationId: randomUUID() },
    });
    assert.equal(
      (await f.verify({ manualCode: secret.visitorPassCode }, op)).idempotent,
      true,
    );
    assert.equal((await f.get(issued.visitorId)).status, "completed");
    const receipt = await f.verify({ manualCode: secret.visitorPassCode }, op);
    assert.equal(receipt.currentStatus, "completed");
    assert.ok(receipt.processedAt > 0);
    assert.equal(receipt.processedAt, result.processedAt);
    assert.ok(receipt.actualArrival > 0);
    assert.ok(receipt.departure >= receipt.actualArrival);
  },
);
test(
  "reject, revoke and Resident cancellation invalidate both captured credentials",
  { skip: !enabled },
  async () => {
    for (const action of ["reject", "revoke", "cancel"]) {
      const f = await fixture(),
        issued = await f.create(),
        secret = await f.secret(issued.visitorId);
      if (action === "cancel") await f.mutate(issued.visitorId, "cancel");
      else await f.decide(issued.visitorId, action);
      await assert.rejects(f.retrieve(issued.visitorId));
      for (const credential of [
        { qrToken: secret.qrToken },
        { manualCode: secret.manualCode },
      ])
        await assert.rejects(f.verify(credential));
    }
  },
);
test(
  "existing passes require approval during emergency; pending invitations follow current policy",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      issued = await f.create(),
      credentials = await f.retrieve(issued.visitorId);
    const start = Date.now() - 1000,
      end = Date.now() + 60_000;
    await f.configure(policy({ emergency: { startAt: start, endAt: end } }), 1);
    const pending = await f.create();
    assert.equal(pending.authorizationState, "pending_admin");
    await assert.rejects(f.verify({ qrToken: credentials.qrToken }), {
      code: "failed-precondition",
    });
    await f.configure(
      policy({ emergency: { startAt: start - 100_000, endAt: start } }),
      2,
    );
    assert.equal((await f.retrieve(pending.visitorId)).qrToken.length, 43);
    assert.equal((await f.create()).qrToken.length, 43);
  },
);
test(
  "legacy records of every age follow the current policy; pending follows relaxed policy",
  { skip: !enabled },
  async () => {
    const f = await fixture();
    const legacyId = `legacy-${randomUUID()}`;
    const base = {
      communityId: f.communityId,
      hostUserId: f.host,
      flatId: f.flat,
      status: "expected",
      isApproved: false,
      expectedArrival: Timestamp.now(),
      createdAt: Timestamp.fromMillis(1),
    };
    const ref = db.collection("visitors").doc(legacyId);
    await ref.set(base);
    const args = {
      db,
      auth: auth(f.security),
      data: { legacyVisitorId: legacyId },
    };
    assert.equal((await resolveVisitorQrCore(args)).visitorId, legacyId);
    await ref.update({ createdAt: Timestamp.now() });
    assert.equal((await resolveVisitorQrCore(args)).visitorId, legacyId);
    await f.configure(policy({approvalMode: 'all_approval_required'}), 1);
    await assert.rejects(resolveVisitorQrCore(args), {code: 'failed-precondition'});
    await f.configure(policy(), 2);
    await ref.update({
      createdAt: Timestamp.fromMillis(1),
      authorizationManaged: true,
      authorizationState: "pending_admin",
    });
    assert.equal((await resolveVisitorQrCore(args)).visitorId, legacyId);
    await ref.update({ authorizationState: "rejected", status: "rejected" });
    await assert.rejects(resolveVisitorQrCore(args), {
      code: "failed-precondition",
    });
  },
);
test(
  "pet policy: older/no-pet clients, bool validation, previously issued pass and rescheduling",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      petPass = await f.create({ bringingPet: true });
    const secret = await f.secret(petPass.visitorId);
    const prohibited = policy({
      pets: {
        mode: "not_allowed",
        normalMode: "not_allowed",
        restriction: null,
      },
    });
    await f.configure(prohibited, 1);
    const message =
      "Pets are not permitted for this visit. You may continue without a pet.";
    await assert.rejects(f.create({ bringingPet: true }), { message });
    await assert.rejects(f.verify({ qrToken: secret.qrToken }), { message });
    await assert.rejects(f.retrieve(petPass.visitorId), { message });
    const noPet = await f.create();
    assert.equal((await f.get(noPet.visitorId)).bringingPet, false);
    assert.equal((await f.verify({ qrToken: noPet.qrToken })).status, "inside");
    for (const value of ["false", 1, null])
      await assert.rejects(f.create({ bringingPet: value }), {
        code: "invalid-argument",
      });
    const context = await getResidentVisitorContextCore({
      db,
      auth: auth(f.host),
      data: { expectedArrival: Date.now() + 1000 },
    });
    assert.equal(context.petPermitted, false);
    assert.equal(context.pets, undefined);
    await f.mutate(petPass.visitorId, "reschedule", 1, {
      bringingPet: false,
      expectedArrival: Date.now() + 1000,
    });
    assert.equal(
      (await f.verify({ manualCode: secret.manualCode })).status,
      "inside",
    );
  },
);
test(
  "rescheduling updates all private validity windows and re-evaluates mandatory authorization",
  { skip: !enabled },
  async () => {
    const f = await fixture({ mode: "all_approval_required" }),
      issued = await f.create();
    await f.decide(issued.visitorId);
    const oldSecret = await f.retrieve(issued.visitorId);
    await f.mutate(issued.visitorId, "reschedule", 2, {
      expectedArrival: Date.now() + 3600_000,
    });
    const visitor = await f.get(issued.visitorId),
      secret = await f.secret(issued.visitorId);
    assert.equal(visitor.authorizationState, "pending_admin");
    assert.equal(visitor.approvedBy, null);
    assert.equal(
      visitor.credentialValidFrom.toMillis(),
      secret.validFrom.toMillis(),
    );
    await assert.rejects(f.verify({ qrToken: oldSecret.qrToken }));
    await f.decide(issued.visitorId, "approve", 3);
    assert.equal(
      (await f.verify({ manualCode: secret.manualCode })).status,
      "inside",
    );
  },
);
test(
  "temporary pet windows cover overlapping passes and resume automatically",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      now = Date.now(),
      day = 24 * 3600_000;
    await f.configure(
      policy({
        pets: {
          mode: "temporarily_restricted",
          normalMode: "allowed",
          restriction: { startAt: now + day, endAt: now + 2 * day },
        },
      }),
      1,
    );
    await assert.rejects(
      f.create({ bringingPet: true, expectedArrival: now + 1000 }),
    );
    const after = await f.create({
      bringingPet: true,
      expectedArrival: now + 3 * day + 1000,
    });
    assert.equal((await f.get(after.visitorId)).bringingPet, true);
    const noPet = await f.create({
      bringingPet: false,
      expectedArrival: now + day + 1000,
    });
    assert.ok(noPet.visitorId);
    await f.configure(
      policy({
        pets: {
          mode: "temporarily_restricted",
          normalMode: "allowed",
          restriction: { startAt: now - 3 * day, endAt: now - day - 1000 },
        },
      }),
      2,
    );
    const expired = await f.create({ bringingPet: true });
    assert.equal(
      (await f.verify({ qrToken: expired.qrToken })).bringingPet,
      true,
    );
  },
);
test(
  "saving a relaxed policy releases pending invitations; stricter saves recheck every invitation",
  { skip: !enabled },
  async () => {
    const f = await fixture({ mode: "all_approval_required" }),
      pending = await f.create();
    await f.configure(
      policy({ approvalMode: "resident_authorized" }),
      1,
    );
    const compatible = await f.create();
    assert.equal((await f.retrieve(pending.visitorId)).qrToken.length, 43);
    await f.configure(policy({ approvalMode: "all_approval_required" }), 2);
    await assert.rejects(f.verify({ qrToken: compatible.qrToken }), {
      code: "failed-precondition",
    });
    await assert.rejects(f.retrieve(pending.visitorId), {
      code: "failed-precondition",
    });
  },
);
test(
  "Admin policy authority, rollout lock, optimistic revisions and append-only audit",
  { skip: !enabled },
  async () => {
    const f = await fixture({ enforce: false });
    await f.communityRef.update({ visitorPolicyRolloutReady: false });
    await assert.rejects(f.configure(policy()), {
      code: "failed-precondition",
    });
    await assert.rejects(
      updateCommunityVisitorPolicyCore({
        db,
        auth: auth(f.other),
        data: {
          communityId: f.communityId,
          policy: policy(),
          expectedRevision: 0,
        },
      }),
      { code: "permission-denied" },
    );
    await f.configure(policy({ enabled: false }));
    const result = await getCommunityVisitorPolicyCore({
      db,
      auth: auth(f.admin),
      data: { communityId: f.communityId },
    });
    assert.equal(result.rolloutReady, false);
    assert.equal(result.policy.revision, 1);
    await f.communityRef.update({ visitorPolicyRolloutReady: true });
    await f.configure(policy(), 1);
    await assert.rejects(f.configure(policy(), 0), {code: 'aborted'});
    const issued = await f.create();
    await f.decide(issued.visitorId, "approve");
    const history = await getVisitorPolicyHistoryCore({
      db,
      auth: auth(f.admin),
      data: { communityId: f.communityId },
    });
    assert.equal(history.events.length, 4);
    assert.ok(
      history.events.every(
        (event) => event.communityId === f.communityId && event.timestamp > 0,
      ),
    );
    const serialized = JSON.stringify(history);
    assert.equal(serialized.includes(issued.qrToken), false);
    assert.equal(serialized.includes("manualCode"), false);
    await assert.rejects(
      getVisitorPolicyHistoryCore({
        db,
        auth: auth(f.other),
        data: { communityId: f.communityId },
      }),
    );
    await assertFails(
      f
        .client(f.admin)
        .collection("auditLogs")
        .doc(history.events[0].id)
        .update({ actorUid: f.other }),
    );
  },
);
test(
  "transaction authority rejects inactive, conflicting identity, invalid unit and foreign Admin decisions",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      profile = db.collection("users").doc(f.host);
    await profile.update({
      identityVerified: false,
      identityVerificationStatus: "not_required",
    });
    const exempt = await f.create();
    assert.equal(
      (await f.get(exempt.visitorId)).visitorPolicySnapshot.identityBasis,
      "community_owner_exemption",
    );
    await f.communityRef.update({ ownerIdentityVerificationRequired: true });
    await assert.rejects(f.create());
    await f.communityRef.update({ ownerIdentityVerificationRequired: false });
    await profile.update({ ownershipType: "tenant" });
    await assert.rejects(f.create());
    await profile.update({ ownershipType: "owner", isActive: false });
    await assert.rejects(f.create());
    await profile.update({ isActive: true });
    await db
      .collection("flats")
      .doc(f.flat)
      .update({ residentUserId: "different-host" });
    await assert.rejects(f.create());
    await assert.rejects(f.decide(exempt.visitorId, "approve", 1, f.other));
  },
);
test(
  "rules protect strict authorization, pet declarations, cancellation, reschedule and private credentials",
  { skip: !enabled },
  async () => {
    const f = await fixture({ mode: "all_approval_required" }),
      issued = await f.create();
    const admin = f
      .client(f.admin)
      .collection("visitors")
      .doc(issued.visitorId);
    const host = f.client(f.host).collection("visitors").doc(issued.visitorId);
    await assertSucceeds(admin.get());
    await assertSucceeds(host.get());
    await assertFails(
      f.client(f.other).collection("visitors").doc(issued.visitorId).get(),
    );
    await assertFails(
      f
        .client(f.admin)
        .collection("communities")
        .doc(f.communityId)
        .update({ visitorPolicyRolloutReady: true }),
    );
    await assertFails(
      admin.update({
        status: "approved",
        isApproved: true,
        approvedBy: f.admin,
        approvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      host.update({ bringingPet: false, updatedAt: serverTimestamp() }),
    );
    await assertFails(
      host.update({
        expectedArrival: new Date(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      host.update({
        authorizationState: "auto_authorized",
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(host.delete());
    await assertFails(admin.delete());
    await assertFails(
      f
        .client(f.security)
        .collection("visitorHostCredentials")
        .doc(issued.visitorId)
        .get(),
    );
    await assertFails(
      f
        .client(f.host)
        .collection("visitorHostCredentials")
        .doc(issued.visitorId)
        .get(),
    );
    await f.decide(issued.visitorId);
    const secret = await f.retrieve(issued.visitorId);
    await f.verify({ qrToken: secret.qrToken });
    await assertSucceeds(
      admin.update({
        status: "completed",
        departure: serverTimestamp(),
        checkedOutBy: f.admin,
        updatedAt: serverTimestamp(),
      }),
    );
  },
);
test(
  "managed entry rechecks the current host account and canonical unit",
  { skip: !enabled },
  async () => {
    const f = await fixture(),
      issued = await f.create();
    const profile = db.collection("users").doc(f.host),
      flat = db.collection("flats").doc(f.flat);
    await profile.update({ isActive: false });
    await assert.rejects(f.verify({ qrToken: issued.qrToken }));
    await assert.rejects(f.decide(issued.visitorId));
    await assert.rejects(
      resolveVisitorQrCore({
        db,
        auth: auth(f.security),
        hmacKey,
        data: { qrToken: issued.qrToken },
      }),
    );
    await profile.update({ isActive: true });
    await flat.update({ residentUserId: "new-occupant" });
    await assert.rejects(f.verify({ manualCode: issued.visitorPassCode }));
    await assert.rejects(
      transitionVisitorFromQrCore({
        db,
        auth: auth(f.security),
        hmacKey,
        data: {
          visitorId: issued.visitorId,
          qrToken: issued.qrToken,
          action: "approve",
        },
      }),
    );
    await flat.update({ residentUserId: f.host });
    assert.equal(
      (await f.verify({ qrToken: issued.qrToken })).status,
      "inside",
    );
  },
);
test(
  "concurrent approval and check-in serialize; concurrent revoke cannot leave an unauthorized arrival",
  { skip: !enabled },
  async () => {
    for (const action of ["approve", "revoke"]) {
      const f = await fixture({
        mode:
          action === "approve"
            ? "all_approval_required"
            : "resident_authorized",
      });
      const issued = await f.create(),
        secret = await f.secret(issued.visitorId);
      const outcomes = await Promise.allSettled([
        f.decide(issued.visitorId, action),
        f.verify({ qrToken: secret.qrToken }),
      ]);
      const visitor = await f.get(issued.visitorId);
      if (action === "approve") {
        assert.equal(outcomes[0].status, "fulfilled");
        assert.equal(visitor.authorizationState, "admin_authorized");
        if (outcomes[1].status === "rejected")
          await f.verify({ qrToken: secret.qrToken });
      } else if (visitor.status === "inside") {
        assert.equal(visitor.authorizationState, "auto_authorized");
        assert.equal(outcomes[0].status, "rejected");
      } else {
        assert.equal(visitor.authorizationState, "revoked");
        assert.equal(outcomes[1].status, "rejected");
      }
    }
  },
);

test(
  "scheduled policy saves preserve revisions and replace pending schedules",
  { skip: !enabled },
  async () => {
    const f = await fixture({ enforce: false });
    const { resolveEffectiveVisitorPolicy } =
      require("../src/visitor_policy_resolver");

    const future = Date.now() + 60 * 60 * 1000;

    const save = (value, expectedRevision, effectiveAt) =>
      updateCommunityVisitorPolicyCore({
        db,
        auth: auth(f.admin),
        data: {
          communityId: f.communityId,
          policy: value,
          expectedRevision,
          ...(effectiveAt == null ? {} : { effectiveAt }),
        },
      });

    const first = await save(policy(), 0);
    assert.equal(first.revision, 1);
    assert.equal(first.scheduled, false);

    const scheduled = await save(
      policy({ approvalMode: "all_approval_required" }),
      1,
      future,
    );
    assert.equal(scheduled.revision, 2);
    assert.equal(scheduled.scheduled, true);

    let community = (await f.communityRef.get()).data();

    assert.equal(
      resolveEffectiveVisitorPolicy(community, future - 1).approvalMode,
      "resident_authorized",
    );
    assert.equal(
      resolveEffectiveVisitorPolicy(community, future).approvalMode,
      "all_approval_required",
    );

    await assert.rejects(
      save(policy(), 1),
      { code: "aborted" },
    );

    const replacement = await save(
      policy({ approvalMode: "tenant_approval_required" }),
      2,
      future + 1000,
    );

    assert.equal(replacement.revision, 3);

    community = (await f.communityRef.get()).data();

    assert.equal(
      resolveEffectiveVisitorPolicy(community, future).approvalMode,
      "resident_authorized",
    );
    assert.equal(
      resolveEffectiveVisitorPolicy(community, future + 1000).approvalMode,
      "tenant_approval_required",
    );
  },
);

// Use the real callable cores, stored schedules, credentials, and rules. The
// injected clock is server-owned; it is never accepted from callable data.
async function schedule(f, value, effectiveAt, expectedRevision = 1) {
  return updateCommunityVisitorPolicyCore({
    db, auth: auth(f.admin),
    data: { communityId: f.communityId, policy: value, effectiveAt, expectedRevision },
  });
}
function accessAt(f, visitorId, secret, time) {
  const args = { db, hmacKey, now: () => time };
  const security = { ...args, auth: auth(f.security) };
  return {
    retrieve: () => getVisitorCredentialsCore({ ...args, auth: auth(f.host), data: { visitorId } }),
    resolve: () => resolveVisitorQrCore({ ...security, data: { qrToken: secret.qrToken } }),
    qr: () => verifyVisitorCredentialCore({ ...security, data: { qrToken: secret.qrToken, operationId: randomUUID() } }),
    manual: () => verifyVisitorCredentialCore({ ...security, data: { manualCode: secret.manualCode, operationId: randomUUID() } }),
    transition: () => transitionVisitorFromQrCore({ ...security, data: { visitorId, qrToken: secret.qrToken, action: "approve" } }),
  };
}
async function assertAccessDenied(access, code) {
  for (const [path, invoke] of Object.entries(access)) {
    await assert.rejects(invoke(), code ? { code } : undefined, path);
  }
}

for (const [mode, role] of [["all_approval_required", "owner"], ["tenant_approval_required", "tenant"]]) {
  test(`scheduled ${mode} enforces captured credentials at the community-local boundary`, { skip: !enabled }, async (t) => {
    const f = await fixture({ role });
    // 09:00 Manila is 01:00 UTC, independent of the server's local zone.
    const effectiveAt = Date.parse("2026-11-20T09:00:00+08:00");
    assert.equal(effectiveAt, Date.UTC(2026, 10, 20, 1));
    t.mock.method(Date, "now", () => effectiveAt - 3600_000);
    const issued = await f.create({ expectedArrival: effectiveAt });
    const secret = await f.secret(issued.visitorId);
    await schedule(f, policy({ approvalMode: mode }), effectiveAt);
    const before = accessAt(f, issued.visitorId, secret, effectiveAt - 1);
    assert.equal((await before.retrieve()).qrToken, secret.qrToken);
    assert.equal((await before.resolve()).visitorId, issued.visitorId);
    for (const path of ["qr", "manual", "transition"]) {
      const early = await f.create({ expectedArrival: effectiveAt });
      const earlyAccess = accessAt(f, early.visitorId, await f.secret(early.visitorId), effectiveAt - 1);
      assert.equal((await earlyAccess[path]()).status, "inside");
    }
    for (const time of [effectiveAt, effectiveAt + 1]) {
      await assertAccessDenied(accessAt(f, issued.visitorId, secret, time), "failed-precondition");
    }
    assert.equal((await f.get(issued.visitorId)).authorizationState, "auto_authorized");
    await decideVisitorInvitationCore({db, auth: auth(f.admin), now: () => effectiveAt,
      data: {communityId: f.communityId, visitorId: issued.visitorId, action: 'approve', expectedRevision: 1}});
    const after = accessAt(f, issued.visitorId, secret, effectiveAt);
    assert.equal((await after.retrieve()).qrToken, secret.qrToken);
    assert.equal((await after.resolve()).visitorId, issued.visitorId);
    assert.equal((await after.qr()).status, "inside");
  });
}

test("scheduled first enforcement evaluates all legacy records identically under current policy", { skip: !enabled }, async () => {
  const f = await fixture({ enforce: false });
  const effectiveAt = Date.now() + 3600_000;
  await schedule(f, policy(), effectiveAt, 0);
  const base = {
    communityId: f.communityId, hostUserId: f.host, residentId: f.host, flatId: f.flat,
    status: "expected", isApproved: false, expectedArrival: Timestamp.fromMillis(effectiveAt),
  };
  for (const createdAt of [effectiveAt - 1, effectiveAt, effectiveAt + 1, null]) {
    const ref = db.collection("visitors").doc();
    await ref.set({ ...base, ...(createdAt == null ? {} : { createdAt: Timestamp.fromMillis(createdAt) }) });
    const resolve = () => resolveVisitorQrCore({
      db, auth: auth(f.security), data: { legacyVisitorId: ref.id }, now: () => effectiveAt,
    });
    assert.equal((await resolve()).visitorId, ref.id);

    // Also cover migrated legacy records with private QR/manual credentials.
    const issued = await f.create({ expectedArrival: effectiveAt });
    await db.collection("visitors").doc(issued.visitorId).update({
      visitorPolicySnapshot: FieldValue.delete(),
      createdAt: createdAt == null ? null : Timestamp.fromMillis(createdAt),
    });
    const access = accessAt(f, issued.visitorId, await f.secret(issued.visitorId), effectiveAt);
    assert.equal((await access.retrieve()).qrToken, issued.qrToken);
    assert.equal((await access.resolve()).visitorId, issued.visitorId);
    // Tighten the effective policy: neither creation date nor missing snapshot
    // exempts these same old records from current approval requirements.
    await f.communityRef.update({'scheduledVisitorPolicy.policy.approvalMode': 'all_approval_required'});
    await assert.rejects(resolve(), {code: 'failed-precondition'});
    await assertAccessDenied(access, 'failed-precondition');
    await f.communityRef.update({'scheduledVisitorPolicy.policy.approvalMode': 'resident_authorized'});
  }
});

test("host eligibility is rechecked when scheduled first enforcement activates", { skip: !enabled }, async () => {
  for (const invalid of ["inactive", "unit", "identity"]) {
    const f = await fixture({ enforce: false });
    const effectiveAt = Date.now() + 3600_000;
    const issued = await f.create({ expectedArrival: effectiveAt });
    const secret = await f.secret(issued.visitorId);
    await schedule(f, policy(), effectiveAt, 0);
    assert.equal((await f.get(issued.visitorId)).authorizationManaged, undefined);
    assert.equal((await accessAt(f, issued.visitorId, secret, effectiveAt - 1).resolve()).visitorId, issued.visitorId);
    if (invalid === "inactive") await db.collection("users").doc(f.host).update({ isActive: false });
    if (invalid === "unit") await db.collection("flats").doc(f.flat).update({ residentUserId: "replacement" });
    if (invalid === "identity") {
      await f.communityRef.update({ ownerIdentityVerificationRequired: true });
      await db.collection("users").doc(f.host).update({ identityVerified: false, identityVerificationStatus: "not_required" });
    }
    await assertAccessDenied(accessAt(f, issued.visitorId, secret, effectiveAt), "permission-denied");
  }
});

test("scheduled first enforcement closes legacy client writes at request.time", { skip: !enabled }, async () => {
  const f = await fixture({ enforce: false });
  const issued = await f.create();
  const host = f.client(f.host).collection("visitors").doc(issued.visitorId);
  const admin = f.client(f.admin).collection("visitors").doc(issued.visitorId);
  const effectiveAt = Date.now() + 3600_000;
  await schedule(f, policy(), effectiveAt, 0);
  await assertSucceeds(host.update({ purpose: "Before activation", updatedAt: serverTimestamp() }));
  // Move only the stored schedule boundary; rules use emulator request.time.
  await f.communityRef.update({ "scheduledVisitorPolicy.effectiveAt": Timestamp.fromMillis(Date.now() - 1000) });
  await assertFails(host.update({ purpose: "After activation", updatedAt: serverTimestamp() }));
  await assertFails(admin.update({ status: "approved", isApproved: true, approvedBy: f.admin,
    approvedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertFails(host.delete());
  await assertFails(admin.delete());
});

test("terminal authorization and gate denials survive relaxed policy saves and enforcement OFF", { skip: !enabled }, async () => {
  for (const action of ["reject", "revoke", "cancel", "gate-deny"]) {
    const f = await fixture();
    const issued = await f.create();
    const secret = await f.secret(issued.visitorId);
    if (action === "cancel") await f.mutate(issued.visitorId, "cancel");
    else if (action === "gate-deny") await denyVisitorEntryCore({ db, auth: auth(f.security),
      data: { visitorId: issued.visitorId, reason: "Denied at gate", operationId: randomUUID() } });
    else await f.decide(issued.visitorId, action);
    await f.configure(policy({ approvalMode: "all_approval_required" }), 1);
    await f.configure(policy(), 2);
    await assertAccessDenied(accessAt(f, issued.visitorId, secret, Date.now()));
    await f.configure(policy({enabled: false}), 3);
    await assertAccessDenied(accessAt(f, issued.visitorId, secret, Date.now()));
    await assert.rejects(f.decide(issued.visitorId, "approve", 2));
    await assert.rejects(f.mutate(issued.visitorId, "reschedule", 2, { expectedArrival: Date.now() + 1000 }));
  }
});

test("forged authorization metadata cannot enter through client rules or trusted callable writes", { skip: !enabled }, async () => {
  const f = await fixture({ mode: "all_approval_required" });
  const issued = await f.create();
  const secret = await f.secret(issued.visitorId);
  const forged = { authorizationManaged: true, authorizationState: "admin_authorized",
    authorizationActorUid: f.admin, approvedBy: f.admin, approvedAt: serverTimestamp(),
    authorizationUpdatedAt: serverTimestamp(), authorizationRevision: 99, isApproved: true, status: "approved",
    visitorPolicySnapshot: { schemaVersion: 1, enforced: false } };
  for (const actor of [f.host, f.security, f.admin, f.other]) {
    const visitors = f.client(actor).collection("visitors");
    await assertFails(visitors.doc().set({ communityId: f.communityId, hostUserId: f.host,
      residentId: f.host, flatId: f.flat, expectedArrival: new Date(), ...forged }));
    for (const [field, value] of Object.entries(forged)) {
      await assertFails(visitors.doc(issued.visitorId).update({ [field]: value, updatedAt: serverTimestamp() }));
    }
  }
  for (const [field, value] of Object.entries({ authorizationState: "admin_authorized", approvedBy: f.admin,
    authorizationManaged: true, visitorPolicySnapshot: { schemaVersion: 1, enforced: false } })) {
    await assert.rejects(f.create({ [field]: value }), { code: "invalid-argument" });
  }
  // Unknown authorization metadata is ignored by explicit server construction.
  const attempt = await f.create({ authorizationActorUid: f.admin, authorizationUpdatedAt: 1,
    authorizationReason: "Forged", adminApproved: true, hostApproval: { approvedBy: f.admin } });
  const stored = await f.get(attempt.visitorId);
  assert.equal(stored.authorizationState, "pending_admin");
  for (const field of ["authorizationActorUid", "authorizationUpdatedAt", "authorizationReason", "adminApproved", "hostApproval"]) {
    assert.equal(Object.hasOwn(stored, field), false, field);
  }
  await assertAccessDenied(accessAt(f, attempt.visitorId, await f.secret(attempt.visitorId), Date.now()));
  for (const actor of [f.host, f.security, f.other]) {
    await assert.rejects(f.decide(issued.visitorId, "approve", 1, actor), { code: "permission-denied" });
  }
  await assert.rejects(decideVisitorInvitationCore({ db, auth: auth(f.admin), data: {
    communityId: f.communityId, visitorId: issued.visitorId, action: "approve", expectedRevision: 1,
    authorizationActorUid: f.other,
  } }), { code: "invalid-argument" });
  await assertAccessDenied(accessAt(f, issued.visitorId, secret, Date.now()));
  await f.decide(issued.visitorId);
  const approved = await f.get(issued.visitorId);
  assert.equal(approved.authorizationActorUid, f.admin);
  assert.equal(approved.approvedBy, f.admin);
  const audit = await db.collection("auditLogs").where("targetId", "==", issued.visitorId)
    .where("action", "==", "visitor.approve").get();
  assert.equal(audit.size, 1);
  assert.equal(audit.docs[0].data().actorUid, f.admin);
  assert.equal((await f.verify({ qrToken: secret.qrToken })).status, "inside");
});

test("already-inside visitors retain arrival, retry idempotence and checkout after scheduled restrictions", { skip: !enabled }, async () => {
  const f = await fixture();
  const issued = await f.create({ bringingPet: true });
  const op = randomUUID();
  await f.verify({ qrToken: issued.qrToken }, op);
  const before = await f.get(issued.visitorId);
  await schedule(f, policy({ approvalMode: "all_approval_required", pets: {
    mode: "not_allowed", normalMode: "not_allowed", restriction: null,
  } }), Date.now() + 3600_000);
  await f.communityRef.update({ "scheduledVisitorPolicy.effectiveAt": Timestamp.fromMillis(Date.now() - 1000) });
  await db.collection("users").doc(f.host).update({ isActive: false });
  assert.equal((await f.verify({ qrToken: issued.qrToken }, op)).idempotent, true);
  const list = await listSecurityVisitorsCore({ db, auth: auth(f.security), data: { category: "inside" } });
  assert.equal(list.visitors.some((v) => v.visitorId === issued.visitorId), true);
  const after = await f.get(issued.visitorId);
  assert.equal(after.status, "inside");
  assert.equal(after.actualArrival.toMillis(), before.actualArrival.toMillis());
  await assert.rejects(f.verify({ qrToken: issued.qrToken }));
  const result = await checkoutVisitorsCore({ db, auth: auth(f.security),
    data: { visitorIds: [issued.visitorId], operationId: randomUUID() } });
  assert.equal(result.succeeded, 1);
  assert.equal((await f.get(issued.visitorId)).status, "completed");
});

test("legacy client approval cannot manufacture server Admin authorization before scheduled enforcement", { skip: !enabled }, async () => {
  const f = await fixture({ enforce: false });
  const issued = await f.create();
  const secret = await f.secret(issued.visitorId);
  const fake = { authorizationState: "admin_authorized", authorizationActorUid: f.admin,
    authorizationManaged: true, authorizationRevision: 1 };
  for (const actor of [f.host, f.admin, f.security]) {
    const ref = f.client(actor).collection("visitors").doc(issued.visitorId);
    await assertFails(ref.update({ ...fake, approvedBy: f.admin, updatedAt: serverTimestamp() }));
    await assertFails(ref.update({ visitorPolicySnapshot: { schemaVersion: 1, enforced: false }, updatedAt: serverTimestamp() }));
  }
  // A genuine legacy Admin client approval has its old attribution, but does
  // not acquire the server-managed authorization state by matching fields.
  await assertSucceeds(f.client(f.admin).collection("visitors").doc(issued.visitorId).update({
    status: "approved", isApproved: true, approvedBy: f.admin,
    approvedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  const effectiveAt = Date.now() + 3600_000;
  await schedule(f, policy({ approvalMode: "all_approval_required" }), effectiveAt, 0);
  await assertAccessDenied(accessAt(f, issued.visitorId, secret, effectiveAt), "failed-precondition");
});

test("Admin load/save contract replaces pending schedules with the current write revision", { skip: !enabled }, async () => {
  const f = await fixture({ enforce: false });
  let clock = Date.now();
  const load = () => getCommunityVisitorPolicyCore({ db, auth: auth(f.admin),
    data: { communityId: f.communityId }, now: () => clock });
  const save = (value, expectedRevision, effectiveAt) => updateCommunityVisitorPolicyCore({ db,
    auth: auth(f.admin), now: () => clock,
    data: { communityId: f.communityId, policy: value, expectedRevision,
      ...(effectiveAt == null ? {} : { effectiveAt }) } });
  let loaded = await load();
  assert.equal(loaded.writeRevision, 0);
  assert.equal(loaded.timeZone, "Asia/Manila");
  assert.equal(loaded.pendingSchedule, null);
  await save(policy(), loaded.writeRevision);
  loaded = await load();
  assert.equal(loaded.policy.enabled, true);
  assert.equal(loaded.policy.revision, 1);
  const future = clock + 3600_000;
  await save(policy({ approvalMode: "all_approval_required" }), loaded.writeRevision, future);
  loaded = await load();
  assert.equal(loaded.policy.revision, 1);
  assert.equal(loaded.policy.approvalMode, "resident_authorized");
  assert.equal(loaded.writeRevision, 2);
  assert.deepEqual(loaded.pendingSchedule, { revision: 2, effectiveAt: future,
    policy: policy({ approvalMode: "all_approval_required" }) });
  await save(policy({ approvalMode: "tenant_approval_required" }), loaded.writeRevision, future + 60_000);
  await assert.rejects(save(policy(), loaded.writeRevision, future), { code: "aborted" });
  loaded = await load();
  assert.equal(loaded.writeRevision, 3);
  assert.equal(loaded.pendingSchedule.effectiveAt, future + 60_000);
  clock = future + 60_000;
  loaded = await load();
  assert.equal(loaded.policy.approvalMode, "tenant_approval_required");
  assert.equal(loaded.policy.revision, 3);
  assert.equal(loaded.writeRevision, 3);
  assert.equal(loaded.pendingSchedule, null);
  await save(policy({ approvalMode: "all_approval_required" }), loaded.writeRevision, clock + 3600_000);
  loaded = await load();
  await save(policy(), loaded.writeRevision);
  loaded = await load();
  assert.equal(loaded.writeRevision, 5);
  assert.equal(loaded.policy.revision, 5);
  assert.equal(loaded.pendingSchedule, null);
  assert.equal((await f.communityRef.get()).data().scheduledVisitorPolicy, undefined);
});

test("scheduled saves require future instants, canonical community zone and current rollout readiness", { skip: !enabled }, async () => {
  const f = await fixture({ enforce: false });
  const clock = Date.now();
  const save = (effectiveAt, value = policy()) => updateCommunityVisitorPolicyCore({ db,
    auth: auth(f.admin), now: () => clock,
    data: { communityId: f.communityId, policy: value, expectedRevision: 0, effectiveAt } });
  for (const effectiveAt of [clock - 1, clock, NaN, "2026-11-20T09:00", -1]) {
    await assert.rejects(save(effectiveAt), { code: "invalid-argument" });
  }
  await assert.rejects(save(clock + 1000, policy({ timeZone: "Europe/London" })), { code: "failed-precondition" });
  await f.communityRef.update({ visitorPolicyRolloutReady: false });
  const blocked = await getCommunityVisitorPolicyCore({ db, auth: auth(f.admin), data: { communityId: f.communityId } });
  assert.equal(blocked.rolloutReady, false);
  await assert.rejects(save(clock + 3600_000), { code: "failed-precondition" });
  await assert.rejects(f.configure(policy()), { code: "failed-precondition" });
  assert.equal((await f.communityRef.get()).data().visitorPolicy, undefined);
});

test("policy response and pending metadata are scoped to the authorized Community Admin", { skip: !enabled }, async () => {
  const f = await fixture();
  await schedule(f, policy({ approvalMode: "all_approval_required" }), Date.now() + 3600_000);
  for (const actor of [f.other, f.host, f.security]) {
    await assert.rejects(getCommunityVisitorPolicyCore({ db, auth: auth(actor),
      data: { communityId: f.communityId } }), { code: "permission-denied" });
  }
});

test("Resident pass deadlines hide at scheduled enforcement and retry a denied pass at emergency expiry", {skip: !enabled}, async () => {
  const f = await fixture();
  const effectiveAt = Date.now() + 3600_000;
  const issued = await f.create({expectedArrival: effectiveAt});
  await schedule(f, policy({emergency: {startAt: effectiveAt, endAt: effectiveAt + 1000}}), effectiveAt);
  const retrieve = (time, actor = f.host) => getVisitorCredentialsCore({db, auth: auth(actor), hmacKey,
    data: {visitorId: issued.visitorId}, now: () => time});
  const before = await retrieve(effectiveAt - 1);
  assert.equal(before.serverTime, effectiveAt - 1);
  assert.equal(before.revalidateAt, effectiveAt);
  await assert.rejects(retrieve(effectiveAt), (error) => {
    assert.equal(error.code, "failed-precondition");
    assert.deepEqual(error.details, {serverTime: effectiveAt, revalidateAt: effectiveAt + 1000});
    assert.equal(JSON.stringify(error.details).includes(before.qrToken), false);
    return true;
  });
  const context = await getResidentVisitorContextCore({db, auth: auth(f.host),
    data: {expectedArrival: effectiveAt + 1000}, now: () => effectiveAt});
  assert.equal(context.revalidateAt, effectiveAt + 1000);
  assert.equal((await retrieve(effectiveAt + 1000)).qrToken, before.qrToken);
  await assert.rejects(retrieve(effectiveAt, f.other), (error) => {
    assert.equal(error.details, undefined);
    return true;
  });
});

// Phase 2A.4: stored snapshots are audit history; every access path evaluates
// the same effective community policy without migrating existing visitors.
test('old Admin approval cannot survive a policy revision; reapproval binds the current revision', {skip: !enabled}, async () => {
  const f = await fixture({mode: 'all_approval_required'});
  const issued = await f.create();
  await f.decide(issued.visitorId);
  const secret = await f.secret(issued.visitorId);
  assert.equal((await f.get(issued.visitorId)).authorizationPolicyRevision, 1);
  await f.configure(policy({approvalMode: 'all_approval_required'}), 1);
  await assertAccessDenied(accessAt(f, issued.visitorId, secret, Date.now()), 'failed-precondition');
  const unchanged = await f.get(issued.visitorId);
  assert.equal(unchanged.status, 'approved');
  assert.equal(unchanged.actualArrival, null);
  assert.equal(unchanged.visitorPolicySnapshot.revision, 1);
  await f.decide(issued.visitorId, 'approve', 2);
  assert.equal((await f.get(issued.visitorId)).authorizationPolicyRevision, 2);
  assert.equal((await f.retrieve(issued.visitorId)).qrToken, secret.qrToken);
  assert.equal((await f.verify({manualCode: secret.manualCode})).currentStatus, 'inside');
});

test('emergency start invalidates earlier Admin approval even within the same policy revision', {skip: !enabled}, async () => {
  const f = await fixture({enforce: false});
  const start = Date.now() + 3600_000, end = start + 1000;
  await f.configure(policy({approvalMode: 'all_approval_required', emergency: {startAt: start, endAt: end}}));
  const issued = await f.create({expectedArrival: start});
  await f.decide(issued.visitorId);
  const secret = await f.secret(issued.visitorId);
  assert.equal((await accessAt(f, issued.visitorId, secret, start - 1).retrieve()).qrToken, secret.qrToken);
  await assertAccessDenied(accessAt(f, issued.visitorId, secret, start), 'failed-precondition');
  await decideVisitorInvitationCore({db, auth: auth(f.admin), now: () => start,
    data: {communityId: f.communityId, visitorId: issued.visitorId, action: 'approve', expectedRevision: 2}});
  assert.equal((await accessAt(f, issued.visitorId, secret, start).retrieve()).qrToken, secret.qrToken);
  assert.equal((await accessAt(f, issued.visitorId, secret, start).manual()).currentStatus, 'inside');
});

test('scheduled revisions require fresh approval at activation for QR, manual and legacy routes', {skip: !enabled}, async () => {
  const f = await fixture({mode: 'all_approval_required'});
  const at = Date.now() + 3600_000;
  const issued = await f.create({expectedArrival: at});
  await f.decide(issued.visitorId);
  const secret = await f.secret(issued.visitorId);
  await schedule(f, policy({approvalMode: 'all_approval_required'}), at);
  assert.equal((await accessAt(f, issued.visitorId, secret, at - 1).retrieve()).qrToken, secret.qrToken);
  for (const time of [at, at + 1]) await assertAccessDenied(accessAt(f, issued.visitorId, secret, time), 'failed-precondition');
  await decideVisitorInvitationCore({db, auth: auth(f.admin), now: () => at,
    data: {communityId: f.communityId, visitorId: issued.visitorId, action: 'approve', expectedRevision: 2}});
  assert.equal((await f.get(issued.visitorId)).authorizationPolicyRevision, 2);
  assert.equal((await accessAt(f, issued.visitorId, secret, at).qr()).currentStatus, 'inside');
});

test('Admin approval cannot override current pet restrictions, including older approved passes', {skip: !enabled}, async () => {
  const f = await fixture({mode: 'all_approval_required'});
  const issued = await f.create({bringingPet: true});
  await f.decide(issued.visitorId);
  const secret = await f.secret(issued.visitorId);
  await f.configure(policy({pets: {mode: 'not_allowed', normalMode: 'not_allowed', restriction: null}}), 1);
  await assert.rejects(f.decide(issued.visitorId, 'approve', 2), {message: 'Pets are not permitted for this visit. You may continue without a pet.'});
  await assertAccessDenied(accessAt(f, issued.visitorId, secret, Date.now()), 'failed-precondition');
  assert.equal((await f.get(issued.visitorId)).authorizationRevision, 2);
});

test('disabled historical policies do not exempt the current host from eligibility checks', {skip: !enabled}, async () => {
  const f = await fixture({enforce: false});
  const issued = await f.create();
  const secret = await f.secret(issued.visitorId);
  await db.collection('users').doc(f.host).update({isActive: false});
  await assertAccessDenied(accessAt(f, issued.visitorId, secret, Date.now()), 'permission-denied');
});

test('policy saves need readiness, enforce immediately or on schedule, and deny Super Admin control', {skip: !enabled}, async () => {
  const f = await fixture({enforce: false});
  await f.communityRef.update({visitorPolicyRolloutReady: false});
  await assert.rejects(f.configure(policy()), {code: 'failed-precondition'});
  await assert.rejects(schedule(f, policy(), Date.now() + 3600_000, 0), {code: 'failed-precondition'});
  await f.configure(policy({enabled: false}));
  assert.equal((await f.communityRef.get()).data().visitorPolicy.enabled, false);
  await f.communityRef.update({visitorPolicyRolloutReady: true});
  await f.configure(policy({approvalMode: 'all_approval_required'}), 1);
  assert.equal((await f.create()).credentialsAvailable, false);
  await db.collection('admins').doc(f.admin).update({role: 'superAdmin'});
  await assert.rejects(f.configure(policy(), 1), {code: 'permission-denied'});
  await assert.rejects(getCommunityVisitorPolicyCore({db, auth: auth(f.admin), data: {communityId: f.communityId}}), {code: 'permission-denied'});
});

test('clients cannot forge the current-policy approval stamp', {skip: !enabled}, async () => {
  const f = await fixture({enforce: false});
  const issued = await f.create();
  await assert.rejects(f.create({authorizationPolicyRevision: 1}), {code: 'invalid-argument'});
  for (const uid of [f.host, f.admin, f.security]) {
    await assertFails(f.client(uid).collection('visitors').doc(issued.visitorId).update({authorizationPolicyRevision: 1}));
  }
});

for (const targetEnabled of [true, false]) {
  for (const scheduled of [false, true]) {
    test(`enforcement toggle ${targetEnabled ? 'ON' : 'OFF'} ${scheduled ? 'scheduled' : 'immediate'} is audited and follows server time`, {skip: !enabled}, async () => {
      const f = await fixture({enforce: !targetEnabled, mode: 'all_approval_required'});
      const revision = targetEnabled ? 0 : 1;
      const clock = Date.now(), at = scheduled ? clock + 1000 : clock;
      if (!targetEnabled) await f.communityRef.update({visitorPolicyRolloutReady: false});
      const result = await updateCommunityVisitorPolicyCore({db, auth: auth(f.admin), now: () => clock,
        data: {communityId: f.communityId, policy: policy({enabled: targetEnabled, approvalMode: 'all_approval_required'}),
          expectedRevision: revision, ...(scheduled ? {effectiveAt: at} : {})}});
      assert.equal(result.enabled, targetEnabled);
      assert.equal(result.scheduled, scheduled);
      const load = time => getCommunityVisitorPolicyCore({db, auth: auth(f.admin), now: () => time, data: {communityId: f.communityId}});
      if (scheduled) assert.equal((await load(at - 1)).policy.enabled, !targetEnabled);
      assert.equal((await load(at)).policy.enabled, targetEnabled);
      assert.equal((await load(at + 1)).policy.enabled, targetEnabled);
      const audits = await db.collection('auditLogs').where('targetId', '==', f.communityId).get();
      const event = audits.docs.map(doc => doc.data()).find(doc => doc.after?.revision === revision + 1);
      assert.equal(event.actorUid, f.admin);
      assert.equal(event.after.enabled, targetEnabled);
      await assert.rejects(updateCommunityVisitorPolicyCore({db, auth: auth(f.admin), now: () => clock,
        data: {communityId: f.communityId, policy: policy({enabled: targetEnabled}), expectedRevision: revision}}), {code: 'aborted'});
    });
  }
}

test('enforcement toggle OFF restores baseline for pending visits without reviving invalid credentials', {skip: !enabled}, async () => {
  const f = await fixture({mode: 'all_approval_required'});
  const pending = await f.create();
  const secret = await f.secret(pending.visitorId);
  await assertAccessDenied(accessAt(f, pending.visitorId, secret, Date.now()), 'failed-precondition');
  await f.communityRef.update({visitorPolicyRolloutReady: false});
  await f.configure(policy({enabled: false, approvalMode: 'all_approval_required'}), 1);
  assert.equal((await f.retrieve(pending.visitorId)).qrToken, secret.qrToken);
  assert.equal((await f.verify({manualCode: secret.manualCode})).currentStatus, 'inside');
  const expired = await f.create();
  await db.collection('visitors').doc(expired.visitorId).update({expectedArrival: Timestamp.fromMillis(Date.now() - 3 * 86400000)});
  await assertAccessDenied(accessAt(f, expired.visitorId, await f.secret(expired.visitorId), Date.now()));
  await assert.rejects(f.verify({qrToken: 'Z'.repeat(43)}));
});
