const test = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {execFileSync} = require("node:child_process");
const path = require("node:path");
const {initializeApp} = require("firebase-admin/app");
const {Timestamp, getFirestore} = require("firebase-admin/firestore");
const {credentialHash, getVisitorCredentialsCore} = require("../src/visitor_credentials");
const {resolveVisitorQrCore} = require("../src/visitor_gate");
const {verifyVisitorCredentialCore} = require("../src/visitor_verification");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = "demo-hominode-sec006";
const hmacKey = "synthetic-emulator-migration-key-at-least-32-bytes";
const residentPhone = "+639170000000";
const securityPhone = "+639170000001";
let app;
let db;

test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId}, `sec006-migration-${randomUUID()}`);
  db = getFirestore(app);
});

test.after(async () => {
  if (app) await app.delete();
});

function invokeMigration({apply = false} = {}) {
  const script = path.join(__dirname, "..", "scripts", "migrate_visitor_credentials.js");
  const args = [script, `--confirm-project=${projectId}`];
  if (apply) args.push("--apply");
  const output = execFileSync(process.execPath, args, {
    encoding: "utf8",
    env: {
      ...process.env,
      GCLOUD_PROJECT: projectId,
      GOOGLE_CLOUD_PROJECT: projectId,
      FIRESTORE_EMULATOR_HOST: process.env.FIRESTORE_EMULATOR_HOST,
      VISITOR_CREDENTIAL_HMAC_KEY: hmacKey,
    },
  });
  return JSON.parse(output);
}

test("Firestore migration dry-run is sanitized; synthetic apply is idempotent and retires migrated legacy IDs", {
  skip: !enabled,
}, async () => {
  const suffix = randomUUID();
  const residentUid = `resident-${suffix}`;
  const securityUid = `security-${suffix}`;
  const communityId = `community-${suffix}`;
  const flatId = `flat-${suffix}`;
  const visitorId = `visitor-${suffix}`;
  const conflictId = `conflict-${suffix}`;
  const now = Date.now();
  const arrival = Timestamp.fromMillis(now + 60_000);
  const qrToken = `A${"a".repeat(42)}`;
const manualCode = "ABCD-EFGH-JKLM";
  const residentAuth = {uid: residentUid, token: {
    phone_number: residentPhone, firebase: {sign_in_provider: "phone"},
  }};
  const securityAuth = {uid: securityUid, token: {
    phone_number: securityPhone, firebase: {sign_in_provider: "phone"},
  }};
  const collectionDocs = [
    ["communities", communityId, {isActive: true}],
    ["users", residentUid, {
      uid: residentUid, role: "resident", phoneNumber: residentPhone, approvalStatus: "approved",
      status: "active", isActive: true, communityId, flatId, flatLabel: "N-014", name: "Synthetic Host",
      residentType: "owner",
    }],
    ["flats", flatId, {communityId, status: "occupied", residentUserId: residentUid, flatLabel: "N-014"}],
    ["securityStaff", securityUid, {
      uid: securityUid, role: "security", phoneNumber: securityPhone, isActive: true, communityId,
    }],
    ["visitors", visitorId, {
      visitorName: "Synthetic Guest", purpose: "Migration validation", hostUserId: residentUid,
      residentId: residentUid, hostName: "Synthetic Host", communityId, flatId, flatLabel: "N-014",
      status: "expected", isApproved: false, expectedArrival: arrival, actualArrival: null, departure: null,
      qrToken, visitorPassCode: manualCode,
    }],
    ["visitors", `terminal-${suffix}`, {
      visitorName: "Terminal Guest", hostUserId: residentUid, residentId: residentUid, communityId,
      status: "completed", expectedArrival: arrival, actualArrival: Timestamp.fromMillis(now - 60_000),
      qrToken: "invalid-token", visitorPassCode: "bad",
    }],
    ["visitors", `malformed-${suffix}`, {
      visitorName: "Malformed Guest", hostUserId: residentUid, residentId: residentUid, communityId,
      status: "expected", isApproved: false, expectedArrival: arrival, actualArrival: null, departure: null,
      qrToken: "bad-qr", visitorPassCode: "bad-code",
    }],
    ["visitors", `hostless-${suffix}`, {
      visitorName: "Hostless Guest", communityId, status: "expected", isApproved: false,
      expectedArrival: arrival, qrToken: "B".repeat(43), visitorPassCode: "NOPQRSTU2345",
    }],
    ["visitors", conflictId, {
      visitorName: "Conflict Guest", hostUserId: residentUid, residentId: residentUid, communityId,
      status: "expected", isApproved: false, expectedArrival: arrival, actualArrival: null, departure: null,
      qrToken: "C".repeat(43), visitorPassCode: "VWXYZ2345678",
    }],
  ];
  const refs = collectionDocs.map(([collection, id, value]) => db.collection(collection).doc(id));
  await Promise.all(collectionDocs.map(([collection, id, value]) => db.collection(collection).doc(id).set(value)));
  const conflictHash = credentialHash(hmacKey, "qr", "C".repeat(43));
  await db.collection("visitorGateCredentialIndex").doc(conflictHash).set({
    visitorId: `different-${suffix}`, communityId, credentialType: "qr", credentialVersion: 1,
    validFrom: Timestamp.fromMillis(now - 60_000), expiresAt: Timestamp.fromMillis(now + 60_000),
  });

  try {
    const dry = invokeMigration();
    assert.equal(dry.mode, "dry-run");
    assert.equal(dry.project, projectId);
    assert.equal(dry.counts.ready, 2);
    assert.equal(dry.counts.terminalRecords, 1);
    assert.equal(dry.counts.missingHosts, 1);
    assert.equal(dry.counts.invalidQrTokens, 2);
    assert.equal(dry.counts.invalidManualCodes, 2);
    assert.equal(dry.counts.conflicts, 1);
    assert.doesNotMatch(JSON.stringify(dry), /ABCD-EFGH-JKLM|bad-qr|bad-code|credentialHash|[A-C]{43}/);
    assert.equal((await db.collection("visitorHostCredentials").doc(visitorId).get()).exists, false);

    const applied = invokeMigration({apply: true});
    assert.equal(applied.mode, "apply");
    assert.equal(applied.counts.ready, 2);
    assert.equal(applied.counts.conflicts, 1);
    const visitor = (await db.collection("visitors").doc(visitorId).get()).data();
    assert.equal(visitor.credentialVersion, 1);
    assert.ok(visitor.legacyCredentialSunsetAt);
    assert.equal(visitor.qrToken, qrToken);
    assert.equal(visitor.visitorPassCode, manualCode);

    const repeated = invokeMigration({apply: true});
    assert.equal(repeated.counts.alreadyMigrated, 2);
    assert.equal(repeated.counts.conflicts, 1);

    const credentials = await getVisitorCredentialsCore({db, auth: residentAuth,
      data: {visitorId}, hmacKey, now: () => now});
    assert.equal(credentials.qrToken, qrToken);
    assert.equal(credentials.visitorPassCode, manualCode.replaceAll("-", ""));

    await assert.rejects(resolveVisitorQrCore({db, auth: securityAuth,
      data: {legacyVisitorId: visitorId}, hmacKey, now: () => now}), {code: "failed-precondition"});

    const checkedIn = await verifyVisitorCredentialCore({db, auth: securityAuth, hmacKey,
      data: {qrToken, operationId: `migration-${suffix}`}, now: () => now});
    assert.equal(checkedIn.status, "inside");
    assert.equal(checkedIn.visitorId, visitorId);
  } finally {
    await Promise.all(refs.map((ref) => ref.delete()));
    const cleanupCollections = [
      ["visitorHostCredentials", "communityId", communityId],
      ["visitorGateCredentialIndex", "communityId", communityId],
      ["visitorGateOperations", "communityId", communityId],
      ["visitorGateEvents", "communityId", communityId],
      ["visitorGateRateLimits", "securityUid", securityUid],
    ];
    const cleanup = await Promise.all(cleanupCollections.map(async ([name, field, value]) =>
      (await db.collection(name).where(field, "==", value).get()).docs.map((doc) => doc.ref.delete())));
    await Promise.all(cleanup.flat());
    await Promise.all([
      db.collection("communities").doc(communityId).delete(),
      db.collection("users").doc(residentUid).delete(),
      db.collection("flats").doc(flatId).delete(),
      db.collection("securityStaff").doc(securityUid).delete(),
    ]);
  }
});
