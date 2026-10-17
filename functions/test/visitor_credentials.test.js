const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createVisitorInvitationCore, credentialHash, getVisitorCredentialsCore,
  normalizeManualCode, planLegacyCredentialMigration, visitorEligible,
} = require("../src/visitor_credentials");
const {assertMigrationMode, run: runCredentialMigration} = require("../scripts/migrate_visitor_credentials");

const now = Date.now();
const key = "test-only-hmac-key-that-is-at-least-32-bytes-long";
const auth = {uid: "resident-1", token: {phone_number: "+639171234567", firebase: {sign_in_provider: "phone"}}};
const profile = {uid: auth.uid, role: "resident", phoneNumber: auth.token.phone_number,
  approvalStatus: "approved", isActive: true, communityId: "community-1", flatId: "flat-1",
  flatLabel: "N-014", name: "Resident One", residentType: "owner"};

function dbFixture({community = {isActive: true}, flat = {communityId: "community-1", flatLabel: "N-014", status: "occupied", residentUserId: auth.uid}, visitor} = {}) {
  const docs = {users: {[auth.uid]: {...profile}}, communities: {"community-1": community}, flats: {"flat-1": flat},
    visitors: visitor ? {"visitor-1": visitor} : {}, visitorHostCredentials: {}, visitorGateCredentialIndex: {}};
  let nextId = 0;
  const ref = (name, id) => ({__name: name, id, get: async () => ({exists: docs[name]?.[id] != null, data: () => docs[name]?.[id]}),
    create: (value) => {docs[name] ??= {}; if (docs[name][id]) throw Error("already_exists"); docs[name][id] = value;},
    set: (value) => {docs[name] ??= {}; docs[name][id] = value;}});
  return {docs, collection(name) { return {doc(id) { return ref(name, id ?? `auto-${++nextId}`); }}; },
    async runTransaction(callback) { return callback({
      get: async (r) => ({exists: docs[r.__name]?.[r.id] != null, data: () => docs[r.__name]?.[r.id]}),
      create: (r, value) => r.create(value), set: (r, value) => r.set(value),
    }); }};
}

test("resident invitation stores credentials privately and ignores forged host scope", async () => {
  const db = dbFixture();
  const input = {visitorName: "Guest", purpose: "Visit", expectedArrival: now + 60_000};
  const result = await createVisitorInvitationCore({db, auth, hmacKey: key, now: () => now, data: input});
  const stored = db.docs.visitors[result.visitorId];
  const secret = db.docs.visitorHostCredentials[result.visitorId];
  assert.equal(stored.hostUserId, auth.uid);
  assert.equal(stored.communityId, "community-1");
  assert.equal(stored.flatId, "flat-1");
  assert.equal(stored.status, "expected");
  assert.equal(stored.isApproved, false);
  assert.equal(stored.actualArrival, null);
  assert.equal("qrToken" in stored, false);
  assert.equal("visitorPassCode" in stored, false);
  assert.equal(secret.qrToken, result.qrToken);
  assert.equal(secret.manualCode, result.visitorPassCode.replaceAll("-", ""));
  assert.equal(Object.keys(db.docs.visitorGateCredentialIndex).length, 2);
  assert.equal(db.docs.visitorGateCredentialIndex[credentialHash(key, "qr", result.qrToken)].visitorId, result.visitorId);
  await assert.rejects(createVisitorInvitationCore({db, auth, hmacKey: key, now: () => now,
    data: {...input, status: "approved", isApproved: true, approvedBy: "attacker",
      actualArrival: now, checkedInBy: "attacker", qrToken: "forged"}}), {code: "invalid-argument"});
  await assert.rejects(createVisitorInvitationCore({db, auth, hmacKey: key, now: () => now,
    data: {...input, hostUserId: "attacker", communityId: "other", flatId: "foreign-flat"}}));
});

test("creation rejects inactive community, wrong phone, unauthorized profile and foreign flat", async () => {
  const request = {visitorName: "Guest", purpose: "Visit", expectedArrival: now + 60_000};
  await assert.rejects(createVisitorInvitationCore({db: dbFixture({community: {isActive: false}}), auth, hmacKey: key, data: request}));
  await assert.rejects(createVisitorInvitationCore({db: dbFixture({flat: {communityId: "other", status: "occupied", residentUserId: auth.uid}}), auth, hmacKey: key, data: request}));
  await assert.rejects(createVisitorInvitationCore({db: dbFixture(), auth: {...auth, token: {...auth.token, phone_number: "+1"}}, hmacKey: key, data: request}));
  const unapproved = dbFixture(); unapproved.docs.users[auth.uid].approvalStatus = "pending";
  await assert.rejects(createVisitorInvitationCore({db: unapproved, auth, hmacKey: key, data: request}));
  const unverifiedTenant = dbFixture();
  unverifiedTenant.docs.users[auth.uid].residentType = "tenant";
  await assert.rejects(createVisitorInvitationCore({db: unverifiedTenant, auth, hmacKey: key, data: request}));
  const verifiedTenant = dbFixture();
  Object.assign(verifiedTenant.docs.users[auth.uid], {
    residentType: "tenant", identityVerified: true, identityVerificationStatus: "verified",
  });
  const created = await createVisitorInvitationCore({db: verifiedTenant, auth, hmacKey: key, data: request});
  assert.ok(created.visitorId);
});

test("host retrieval returns persisted credentials only to the matching host", async () => {
  const qrToken = "persisted-token";
  const visitor = {hostUserId: auth.uid, communityId: "community-1", status: "expected", isApproved: false,
    expectedArrival: new Date(now + 60_000), actualArrival: null, departure: null};
  const db = dbFixture({visitor});
  db.docs.visitorHostCredentials["visitor-1"] = {hostUserId: auth.uid, communityId: "community-1", qrToken, manualCode: "ABCDEFGHJKLM"};
  for (const [type, value] of [["qr", qrToken], ["manual", "ABCDEFGHJKLM"]]) {
    db.docs.visitorGateCredentialIndex[credentialHash(key, type, value)] = {
      visitorId: "visitor-1", communityId: "community-1", credentialType: type, credentialVersion: 1,
    };
  }
  const result = await getVisitorCredentialsCore({db, auth, data: {visitorId: "visitor-1"}, hmacKey: key});
  assert.deepEqual(result, {qrToken, visitorPassCode: "ABCDEFGHJKLM"});
  const reopened = await getVisitorCredentialsCore({db, auth, data: {visitorId: "visitor-1"}, hmacKey: key});
  assert.deepEqual(reopened, result);
  await assert.rejects(getVisitorCredentialsCore({db, auth: {...auth, uid: "other"}, data: {visitorId: "visitor-1"}, hmacKey: key}));
  await assert.rejects(getVisitorCredentialsCore({db, auth, data: {visitorId: "missing"}, hmacKey: key}));
});

test("migrated visitor never falls back to credential fields on the legacy visitor document", async () => {
  const legacy = {
    hostUserId: auth.uid, communityId: "community-1", status: "expected", isApproved: false,
    expectedArrival: new Date(now + 60_000), actualArrival: null, departure: null,
    credentialVersion: 1, qrToken: "legacy-raw-secret", visitorPassCode: "LEGACYCODE12",
  };
  const db = dbFixture({visitor: legacy});
  await assert.rejects(getVisitorCredentialsCore({db, auth, data: {visitorId: "visitor-1"}, hmacKey: key}),
    {code: "failed-precondition"});
});

test("manual credential normalization and HMAC indexing are stable without exposing the input", () => {
  assert.equal(normalizeManualCode("abcd-efgh jklm"), "ABCDEFGHJKLM");
  assert.equal(credentialHash(key, "manual", "abcd-efgh jklm"), credentialHash(key, "manual", "ABCDEFGHJKLM"));
  assert.notEqual(credentialHash(key, "manual", "ABCDEFGHJKLM"), credentialHash(key, "qr", "ABCDEFGHJKLM"));
});

test("credential issuance fails closed when the HMAC secret is missing or too short", async () => {
  await assert.rejects(createVisitorInvitationCore({db: dbFixture(), auth, hmacKey: "",
    now: () => now, data: {visitorName: "Guest", purpose: "Visit", expectedArrival: now + 60_000}}),
  {code: "failed-precondition"});
  assert.throws(() => credentialHash("short", "qr", "opaque-test-token"),
    {code: "failed-precondition"});
});

test("credential collision retries are bounded and reserve unique indexes", async () => {
  const db = dbFixture();
  const occupiedHash = credentialHash(key, "manual", "COLLIDEDCODE1");
  db.docs.visitorGateCredentialIndex[occupiedHash] = {visitorId: "other-visitor"};
  const qr = ["qr-first", "qr-second"];
  const codes = ["COLLIDEDCODE1", "UNIQUECODE123"];
  const result = await createVisitorInvitationCore({db, auth, hmacKey: key, now: () => now,
    makeQrToken: () => qr.shift(), makeManualCode: () => codes.shift(),
    data: {visitorName: "Guest", purpose: "Visit", expectedArrival: now + 60_000}});
  assert.equal(result.qrToken, "qr-second");
  assert.equal(Object.keys(db.docs.visitorGateCredentialIndex).length, 3);
  assert.equal(db.docs.visitorGateCredentialIndex[credentialHash(key, "manual", "UNIQUECODE123")].visitorId, result.visitorId);
});

test("migration skips terminal, expired and hostless records and plans idempotent legacy transfer", () => {
  const base = {hostUserId: auth.uid, communityId: "community-1", status: "expected", isApproved: false,
    expectedArrival: new Date(now + 60_000), qrToken: "A".repeat(43), visitorPassCode: "ABCD-EFGH"};
  const plan = planLegacyCredentialMigration({visitorId: "visitor-1", visitor: base, hmacKey: key, now});
  assert.equal(plan.action, "migrate");
  assert.equal(plan.qrToken, base.qrToken);
  assert.equal(plan.manualCode, "ABCDEFGH");
  assert.equal(plan.qrHash, credentialHash(key, "qr", base.qrToken));
  assert.equal(planLegacyCredentialMigration({visitorId: "x", visitor: {...base, status: "completed"}, hmacKey: key, now}).reason, "terminal_visit");
  assert.equal(planLegacyCredentialMigration({visitorId: "x", visitor: {...base, hostUserId: null}, hmacKey: key, now}).reason, "missing_host_or_community");
  assert.equal(planLegacyCredentialMigration({visitorId: "x", visitor: {...base, expectedArrival: new Date(now - 3 * 86400000)}, hmacKey: key, now}).reason, "expired_or_ineligible");
  assert.equal(visitorEligible({...base, status: "rejected"}, now), false);
  const missingLegacySecrets = planLegacyCredentialMigration({
    visitorId: "missing-secrets", visitor: {...base, qrToken: null, visitorPassCode: null}, hmacKey: key, now,
  });
  assert.equal(missingLegacySecrets.action, "migrate");
  assert.ok(missingLegacySecrets.qrToken);
  assert.equal(missingLegacySecrets.manualCode.length, 12);
});

test("migration dry-run is read-only and apply is idempotent without deleting legacy fields", async () => {
  const documents = {
  visitors: {legacy: {hostUserId: auth.uid, communityId: "community-1",
    status: "expected", isApproved: false, expectedArrival: new Date(Date.now() + 60_000),
    qrToken: "legacy-token", visitorPassCode: "ABCD-EFGH"}}, visitorHostCredentials: {},
  visitorGateCredentialIndex: {},
  users: {[auth.uid]: {...profile, status: "active"}},
  communities: {"community-1": {isActive: true}},
  flats: {"flat-1": {communityId: "community-1", status: "occupied", residentUserId: auth.uid}},
  };
  const makeRef = (name, id) => ({name, id,
    get: async () => ({exists: documents[name]?.[id] != null, data: () => documents[name]?.[id]}),
    update: async (data) => Object.assign(documents[name][id], data),
  });
  const db = {
    collection(name) { return {
      doc: (id) => makeRef(name, id),
      get: async () => ({docs: Object.entries(documents[name] || {}).map(([id, data]) => ({id, data: () => data}))}),
    }; },
    async runTransaction(fn) { return fn({
      get: async (ref) => ({exists: documents[ref.name]?.[ref.id] != null, data: () => documents[ref.name]?.[ref.id]}),
      create: (ref, data) => { documents[ref.name] ??= {}; if (documents[ref.name][ref.id]) throw Error("already_exists"); documents[ref.name][ref.id] = data; },
      set: (ref, data) => { documents[ref.name] ??= {}; documents[ref.name][ref.id] = data; },
      update: (ref, data) => Object.assign(documents[ref.name][ref.id], data),
    }); },
  };
  const dry = await runCredentialMigration({db, hmacKey: key, apply: false});
  assert.equal(dry.counts.ready, 1);
  assert.equal(dry.counts.legacySunsetEligible, 1);
  assert.equal(dry.counts.invalidQrTokens, 1);
  assert.equal(documents.visitorHostCredentials.legacy, undefined);
  assert.doesNotMatch(JSON.stringify(dry), /legacy-token|ABCD-EFGH|qrHash|manualHash/);
  await runCredentialMigration({db, hmacKey: key, apply: true});
  assert.ok(documents.visitorHostCredentials.legacy);
  assert.equal(documents.visitors.legacy.qrToken, "legacy-token");
  assert.equal(documents.visitors.legacy.visitorPassCode, "ABCD-EFGH");
  assert.equal(documents.visitors.legacy.credentialVersion, 1);
  assert.ok(documents.visitors.legacy.legacyCredentialSunsetAt);
  const secondApply = await runCredentialMigration({db, hmacKey: key, apply: true});
  assert.equal(secondApply.counts.alreadyMigrated, 1);
});

test("migration reports missing hosts, terminal records, and duplicate manual credentials without secrets", async () => {
  const arrival = new Date(Date.now() + 60_000);
  const visitorDoc = (hostUserId, qrToken, visitorPassCode) => ({
    hostUserId, residentId: hostUserId, communityId: "community-1", status: "expected",
    isApproved: false, expectedArrival: arrival, qrToken, visitorPassCode,
  });
  const documents = {
    visitors: {
      first: visitorDoc(auth.uid, "A".repeat(43), "ABCDEFGHJKLM"),
      duplicate: visitorDoc(auth.uid, "B".repeat(43), "ABCDEFGHJKLM"),
      missing: visitorDoc("absent-resident", "C".repeat(43), "QRSTUVWX2345"),
      terminal: {...visitorDoc(auth.uid, "D".repeat(43), "BCDEFGHJKLMN"), status: "completed"},
    },
    users: {[auth.uid]: {...profile, status: "active"}},
    communities: {"community-1": {isActive: true}},
    flats: {"flat-1": {communityId: "community-1", status: "occupied", residentUserId: auth.uid}},
    visitorHostCredentials: {}, visitorGateCredentialIndex: {},
  };
  const db = {
    collection(name) { return {doc: (id) => ({get: async () => ({exists: documents[name]?.[id] != null,
      data: () => documents[name]?.[id]})}), get: async () => ({docs: Object.entries(documents[name] || {})
      .map(([id, data]) => ({id, data: () => data}))})}; },
  };
  const result = await runCredentialMigration({db, hmacKey: key, apply: false});
  assert.equal(result.counts.missingHosts, 1);
  assert.equal(result.counts.terminalRecords, 1);
  assert.equal(result.counts.duplicateManualCodes, 2);
  assert.doesNotMatch(JSON.stringify(result), /ABCDEFGHJKLM|QRSTUVWX2345|qrHash|manualHash/);
  assert.ok(result.discrepancies.some((item) => item.issue === "duplicate_manual_code_will_be_reissued"));
});

test("migration skips hosts that cannot retrieve credentials through verified phone auth", async () => {
  const visitor = {hostUserId: auth.uid, residentId: auth.uid, communityId: "community-1",
    status: "expected", isApproved: false, expectedArrival: new Date(Date.now() + 60_000),
    qrToken: "A".repeat(43), visitorPassCode: "ABCDEFGHJKLM"};
  const documents = {
    visitors: {visitor}, visitorHostCredentials: {}, visitorGateCredentialIndex: {},
    users: {[auth.uid]: {...profile, phoneNumber: null, status: "active"}},
    communities: {"community-1": {isActive: true}},
    flats: {"flat-1": {communityId: "community-1", status: "occupied", residentUserId: auth.uid}},
  };
  const db = {collection(name) { return {
    doc: (id) => ({get: async () => ({exists: documents[name]?.[id] != null,
      data: () => documents[name]?.[id]})}),
    get: async () => ({docs: Object.entries(documents[name] || {}).map(([id, data]) => ({id, data: () => data}))}),
  }; }};
  const result = await runCredentialMigration({db, hmacKey: key, apply: false});
  assert.equal(result.counts.invalidHosts, 1);
  assert.equal(result.counts.ready, 0);
  assert.ok(result.discrepancies.some((item) => item.issue === "host_profile_not_eligible"));
  assert.doesNotMatch(JSON.stringify(result), /ABCDEFGHJKLM|A{43}/);
});

test("production apply is blocked inside this migration script", () => {
  assert.doesNotThrow(() => assertMigrationMode({project: "hominode-prod", apply: false}));
  assert.throws(() => assertMigrationMode({project: "hominode-prod", apply: true}), /separately reviewed/);
  assert.doesNotThrow(() => assertMigrationMode({project: "demo-hominode-finance", apply: true}));
});

test("migration reports conflicting existing credential indexes without exposing their values", async () => {
  const qrToken = "Z".repeat(43);
  const visitor = {hostUserId: auth.uid, residentId: auth.uid, communityId: "community-1",
    status: "expected", isApproved: false, expectedArrival: new Date(Date.now() + 60_000),
    qrToken, visitorPassCode: "ABCDEFGHJKLM"};
  const qrHash = credentialHash(key, "qr", qrToken);
  const documents = {
    visitors: {conflict: visitor}, visitorHostCredentials: {},
    visitorGateCredentialIndex: {[qrHash]: {visitorId: "different-visitor", communityId: "community-1",
      credentialType: "qr", credentialVersion: 1}},
    users: {[auth.uid]: {...profile, status: "active"}},
    communities: {"community-1": {isActive: true}},
    flats: {"flat-1": {communityId: "community-1", status: "occupied", residentUserId: auth.uid}},
  };
  const db = {collection(name) { return {
    doc: (id) => ({get: async () => ({exists: documents[name]?.[id] != null, data: () => documents[name]?.[id]})}),
    get: async () => ({docs: Object.entries(documents[name] || {}).map(([id, data]) => ({id, data: () => data}))}),
  }; }};
  const result = await runCredentialMigration({db, hmacKey: key, apply: false});
  assert.equal(result.counts.conflicts, 1);
  assert.equal(result.counts.conflictingIndexes, 1);
  assert.doesNotMatch(JSON.stringify(result), new RegExp(qrToken));
  assert.doesNotMatch(JSON.stringify(result), new RegExp(qrHash));
});
