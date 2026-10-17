const test = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {Timestamp, getFirestore} = require("firebase-admin/firestore");
const {credentialHash} = require("../src/visitor_credentials");
const {
  MAX_MANUAL_ATTEMPTS_PER_WINDOW,
  verifyVisitorCredentialCore,
} = require("../src/visitor_verification");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = "demo-hominode-sec006";
const hmacKey = "synthetic-emulator-hmac-key-at-least-32-bytes";
const phoneNumber = "+639170000000";
let app;
let db;

test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId}, `sec006-${randomUUID()}`);
  db = getFirestore(app);
});

test.after(async () => {
  if (app) await app.delete();
});

async function seedGateVisitor({approved = false} = {}) {
  const suffix = randomUUID();
  const securityUid = `security-${suffix}`;
  const communityId = `community-${suffix}`;
  const visitorId = `visitor-${suffix}`;
  const qrToken = `qr-${suffix}-opaque-test-token`;
  const manualCode = `MANUAL${suffix.replaceAll("-", "").slice(0, 12).toUpperCase()}`;
  const now = Date.now();
  const validFrom = Timestamp.fromMillis(now - 60_000);
  const expiresAt = Timestamp.fromMillis(now + 60_000);
  const auth = {uid: securityUid, token: {
    phone_number: phoneNumber,
    firebase: {sign_in_provider: "phone"},
  }};
  const qrHash = credentialHash(hmacKey, "qr", qrToken);
  const manualHash = credentialHash(hmacKey, "manual", manualCode);

  await Promise.all([
    db.collection("communities").doc(communityId).set({isActive: true}),
    db.collection("securityStaff").doc(securityUid).set({
      uid: securityUid, role: "security", isActive: true,
      communityId, phoneNumber,
    }),
    db.collection("visitors").doc(visitorId).set({
      communityId, hostUserId: `resident-${suffix}`, hostName: "Synthetic Host",
      visitorName: "Synthetic Guest", flatId: "flat-test", flatLabel: "A-101",
      purpose: "Emulator integration test", expectedArrival: Timestamp.fromMillis(now),
      status: approved ? "approved" : "expected", isApproved: approved,
      approvedBy: approved ? "admin-test" : null,
      approvedAt: approved ? Timestamp.fromMillis(now - 1000) : null,
      actualArrival: null, departure: null,
    }),
    db.collection("visitorHostCredentials").doc(visitorId).set({
      hostUserId: `resident-${suffix}`, communityId, qrToken, manualCode,
      credentialVersion: 1, validFrom, expiresAt,
    }),
    db.collection("visitorGateCredentialIndex").doc(qrHash).set({
      visitorId, communityId, credentialType: "qr", credentialVersion: 1,
      validFrom, expiresAt,
    }),
    db.collection("visitorGateCredentialIndex").doc(manualHash).set({
      visitorId, communityId, credentialType: "manual", credentialVersion: 1,
      validFrom, expiresAt,
    }),
  ]);
  return {auth, communityId, visitorId, qrToken};
}

test("Firestore transactions admit one concurrent credential check-in and preserve same-operation result", {
  skip: !enabled,
}, async () => {
  const fixture = await seedGateVisitor();
  const now = Date.now;
  const attempts = await Promise.allSettled([
    verifyVisitorCredentialCore({db, auth: fixture.auth, hmacKey,
      data: {qrToken: fixture.qrToken, operationId: "concurrent-operation-0001"}, now})
      .then((value) => ({operationId: "concurrent-operation-0001", value})),
    verifyVisitorCredentialCore({db, auth: fixture.auth, hmacKey,
      data: {qrToken: fixture.qrToken, operationId: "concurrent-operation-0002"}, now})
      .then((value) => ({operationId: "concurrent-operation-0002", value})),
  ]);
  assert.equal(attempts.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(attempts.filter((result) => result.status === "rejected").length, 1);

  const winner = attempts.find((result) => result.status === "fulfilled").value;
  const retry = await verifyVisitorCredentialCore({db, auth: fixture.auth, hmacKey,
    data: {qrToken: fixture.qrToken,
      operationId: winner.operationId}, now});
  assert.equal(retry.idempotent, true);
  assert.equal(retry.visitorId, fixture.visitorId);
  const visitor = (await db.collection("visitors").doc(fixture.visitorId).get()).data();
  assert.equal(visitor.status, "inside");
  assert.equal(visitor.checkedInBy, fixture.auth.uid);
  const events = await db.collection("visitorGateEvents").where("visitorId", "==", fixture.visitorId).get();
  assert.equal(events.size, 1);
});

test("Firestore transactions enforce manual-code rate limit under concurrent attempts", {
  skip: !enabled,
}, async () => {
  const fixture = await seedGateVisitor();
  const attempts = Array.from({length: MAX_MANUAL_ATTEMPTS_PER_WINDOW + 2}, (_, index) =>
    verifyVisitorCredentialCore({db, auth: fixture.auth, hmacKey,
      data: {manualCode: "UNKNOWN-CODE-123", operationId: `manual-attempt-${String(index).padStart(4, "0")}`},
    }).then(() => ({success: true}), (error) => ({success: false, code: error.code})));
  const results = await Promise.all(attempts);
  assert.equal(results.filter((result) => result.success).length, 0);
  assert.equal(results.filter((result) => result.code === "permission-denied").length,
    MAX_MANUAL_ATTEMPTS_PER_WINDOW);
  assert.equal(results.filter((result) => result.code === "resource-exhausted").length, 2);
  assert.equal(results.filter((result) => !["permission-denied", "resource-exhausted"].includes(result.code)).length, 0);
  const limits = await db.collection("visitorGateRateLimits").where("securityUid", "==", fixture.auth.uid).get();
  assert.equal(limits.size, 1);
  assert.equal(limits.docs[0].data().attempts, MAX_MANUAL_ATTEMPTS_PER_WINDOW);
  const visitor = (await db.collection("visitors").doc(fixture.visitorId).get()).data();
  assert.equal(visitor.status, "expected");
});
