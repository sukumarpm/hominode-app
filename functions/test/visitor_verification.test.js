const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {credentialHash} = require("../src/visitor_credentials");
const {
  MAX_MANUAL_ATTEMPTS_PER_WINDOW,
  verifyVisitorCredentialCore,
} = require("../src/visitor_verification");

const now = Date.UTC(2026, 9, 10, 4, 0);
const hmacKey = "test-only-hmac-key-that-is-at-least-32-bytes-long";
const qrToken = "opaque-visitor-qr-token-that-is-not-for-logs";
const manualCode = "ABCD-EFGH-JKLM";
const securityAuth = {uid: "security-1", token: {
  phone_number: "+639170000000", firebase: {sign_in_provider: "phone"},
}};

function seededVisitor(overrides = {}) {
  return {
    communityId: "community-a", hostUserId: "resident-1", hostName: "Host",
    visitorName: "Guest", flatId: "flat-1", flatLabel: "A-101", purpose: "Visit",
    expectedArrival: new Date(now), status: "expected", isApproved: false,
    approvedBy: null, approvedAt: null, actualArrival: null, departure: null,
    ...overrides,
  };
}

function makeDb({visitor = seededVisitor(), communityId = "community-a", security = {}} = {}) {
  const store = {
    securityStaff: {"security-1": {
      uid: "security-1", phoneNumber: securityAuth.token.phone_number,
      role: "security", isActive: true, communityId, ...security,
    }},
    communities: {[communityId]: {isActive: true}},
    visitors: {"visitor-1": visitor},
    visitorHostCredentials: {"visitor-1": {
      hostUserId: visitor.hostUserId, communityId: visitor.communityId,
      qrToken, manualCode: "ABCDEFGHJKLM", credentialVersion: 1,
      validFrom: new Date(now - 60_000), expiresAt: new Date(now + 60_000),
    }},
    visitorGateCredentialIndex: {}, visitorGateOperations: {},
    visitorGateEvents: {}, visitorGateRateLimits: {},
  };
  for (const [type, value] of [["qr", qrToken], ["manual", "ABCDEFGHJKLM"]]) {
    store.visitorGateCredentialIndex[credentialHash(hmacKey, type, value)] = {
      visitorId: "visitor-1", communityId: visitor.communityId,
      credentialType: type, credentialVersion: 1,
      validFrom: new Date(now - 60_000), expiresAt: new Date(now + 60_000),
    };
  }

  let transactionTail = Promise.resolve();
  const ref = (collection, id) => ({collection, id,
    get: async () => snapshot(store[collection]?.[id]),
  });
  const db = {
    store,
    collection(name) { return {doc: (id) => ref(name, id)}; },
    async runTransaction(callback) {
      if (typeof db.beforeNextTransaction === "function") {
        const before = db.beforeNextTransaction;
        db.beforeNextTransaction = null;
        await before();
      }
      let release;
      const previous = transactionTail;
      transactionTail = new Promise((resolve) => { release = resolve; });
      await previous;
      const writes = [];
      const transaction = {
        get: async (document) => snapshot(store[document.collection]?.[document.id]),
        create: (document, value) => writes.push({kind: "create", document, value}),
        set: (document, value) => writes.push({kind: "set", document, value}),
        update: (document, patch) => writes.push({kind: "update", document, patch}),
      };
      try {
        const result = await callback(transaction);
        for (const write of writes) {
          const collection = store[write.document.collection] ||= {};
          if (write.kind === "create") {
            if (collection[write.document.id]) throw new Error("already-exists");
            collection[write.document.id] = {...write.value};
          } else if (write.kind === "set") {
            collection[write.document.id] = {...write.value};
          } else {
            if (!collection[write.document.id]) throw new Error("not-found");
            Object.assign(collection[write.document.id], write.patch);
          }
        }
        return result;
      } finally {
        release();
      }
    },
  };
  return db;
}

function snapshot(value) {
  const copy = value == null ? undefined : {...value};
  return {exists: value != null, data: () => copy};
}

function request(data, db = makeDb(), options = {}) {
  return verifyVisitorCredentialCore({db, auth: options.auth || securityAuth, data,
    hmacKey, now: options.now || (() => now)});
}

test("valid pending QR checks in atomically without changing optional Admin approval", async () => {
  const db = makeDb();
  const result = await request({qrToken, operationId: "operation-qr-000001"}, db);
  assert.equal(result.status, "inside");
  assert.equal(result.verificationMethod, "qr");
  assert.equal(db.store.visitors["visitor-1"].status, "inside");
  assert.equal(db.store.visitors["visitor-1"].isApproved, false);
  assert.equal(db.store.visitors["visitor-1"].approvedBy, null);
  assert.equal(db.store.visitors["visitor-1"].approvedAt, null);
  assert.equal(db.store.visitors["visitor-1"].checkedInBy, securityAuth.uid);
  assert.ok(db.store.visitors["visitor-1"].actualArrival);
  assert.equal(Object.keys(db.store.visitorGateEvents).length, 1);
});

test("valid normalized manual code checks in through the same path", async () => {
  const db = makeDb();
  const result = await request({manualCode, operationId: "operation-code-00001"}, db);
  assert.equal(result.status, "inside");
  assert.equal(result.verificationMethod, "manual");
  assert.equal(db.store.visitors["visitor-1"].verificationMethod, "manual");
});

test("Admin-approved visits remain eligible and approval metadata is preserved", async () => {
  const approvedAt = new Date(now - 1000);
  const approvedBy = "admin-5";
  const db = makeDb({visitor: seededVisitor({
    status: "approved", isApproved: true, approvedBy, approvedAt,
  })});
  await request({qrToken, operationId: "operation-approved-01"}, db);
  assert.equal(db.store.visitors["visitor-1"].isApproved, true);
  assert.equal(db.store.visitors["visitor-1"].approvedBy, approvedBy);
  assert.equal(db.store.visitors["visitor-1"].approvedAt, approvedAt);
});

test("a Security-denied invitation cannot later enter through the unified or legacy QR path", async () => {
  const db = makeDb({visitor: seededVisitor({gateAccessStatus: "denied",
    gateEntryDeniedAt: new Date(now - 1000), gateEntryDeniedBy: "security-1",
    gateEntryDenialReason: "No valid ID"})});
  await assert.rejects(request({qrToken, operationId: "operation-denial-block-01"}, db));
  const {transitionVisitorFromQrCore} = require("../src/visitor_gate");
  await assert.rejects(transitionVisitorFromQrCore({db, auth: securityAuth,
    data: {qrToken, visitorId: "visitor-1", action: "approve"}, hmacKey, now: () => now}));
  assert.equal(db.store.visitors["visitor-1"].status, "expected");
  assert.equal(db.store.visitors["visitor-1"].actualArrival, null);
});

test("invalid, expired, wrong-community, rejected, cancelled, inside and completed visitors are denied", async () => {
  await assert.rejects(request({qrToken: "unknown-token", operationId: "operation-invalid-01"}),
    (error) => error.code === "permission-denied");
  const expired = makeDb();
  expired.store.visitorGateCredentialIndex[credentialHash(hmacKey, "qr", qrToken)].expiresAt = new Date(now - 1);
  await assert.rejects(request({qrToken, operationId: "operation-expired-01"}, expired));
  await assert.rejects(request({qrToken, operationId: "operation-community-01"},
    makeDb({visitor: seededVisitor({communityId: "community-b"})})));
  for (const state of [
    {status: "rejected", isApproved: false}, {status: "cancelled", isApproved: false},
    {status: "inside", isApproved: false, actualArrival: new Date(now)},
    {status: "completed", isApproved: false, departure: new Date(now)},
  ]) {
    await assert.rejects(request({qrToken, operationId: `operation-state-${state.status}-01`},
      makeDb({visitor: seededVisitor(state)})));
  }
});

test("same operation retry is idempotent and concurrent different operations consume once", async () => {
  const db = makeDb();
  const data = {qrToken, operationId: "operation-retry-0001"};
  const first = await request(data, db);
  const retry = await request(data, db);
  assert.equal(first.idempotent, false);
  assert.equal(retry.idempotent, true);
  assert.equal(Object.keys(db.store.visitorGateEvents).length, 1);

  const raceDb = makeDb();
  const attempts = await Promise.allSettled([
    request({qrToken, operationId: "operation-race-000001"}, raceDb),
    request({qrToken, operationId: "operation-race-000002"}, raceDb),
  ]);
  assert.equal(attempts.filter((item) => item.status === "fulfilled").length, 1);
  assert.equal(attempts.filter((item) => item.status === "rejected").length, 1);
  assert.equal(Object.keys(raceDb.store.visitorGateEvents).length, 1);
});

test("manual guessing is rate-limited across new operation IDs by Security and community", async () => {
  const db = makeDb();
  for (let attempt = 0; attempt < MAX_MANUAL_ATTEMPTS_PER_WINDOW; attempt++) {
    await assert.rejects(request({manualCode: "BAD-CODE-0000", operationId: `operation-guess-${String(attempt).padStart(4, "0")}`}, db));
  }
  await assert.rejects(request({manualCode: "BAD-CODE-0000", operationId: "operation-guess-final-01"}, db),
    (error) => error.code === "resource-exhausted");
  assert.equal(Object.keys(db.store.visitorGateRateLimits).length, 1);
});

test("a successful manual operation can be safely retried even when the attempt limit is reached", async () => {
  const db = makeDb();
  for (let attempt = 0; attempt < MAX_MANUAL_ATTEMPTS_PER_WINDOW - 1; attempt++) {
    await assert.rejects(request({manualCode: "BAD-CODE-0000", operationId: `operation-pre-${String(attempt).padStart(4, "0")}`}, db));
  }
  const successRequest = {manualCode, operationId: "operation-last-allowed-01"};
  const success = await request(successRequest, db);
  const retry = await request(successRequest, db);
  assert.equal(success.status, "inside");
  assert.equal(retry.idempotent, true);
  assert.equal(db.store.visitorGateRateLimits[Object.keys(db.store.visitorGateRateLimits)[0]].attempts,
    MAX_MANUAL_ATTEMPTS_PER_WINDOW);
});

test("disabled, reassigned and phone-mismatched Security identities cannot check in", async () => {
  await assert.rejects(request({qrToken, operationId: "operation-disabled-01"},
    makeDb({security: {isActive: false}})));
  await assert.rejects(request({qrToken, operationId: "operation-reassigned-01"},
    makeDb({security: {communityId: "community-b"}})));
  const mismatchedAuth = {...securityAuth, token: {...securityAuth.token, phone_number: "+639170000099"}};
  await assert.rejects(request({qrToken, operationId: "operation-phone-00001"}, makeDb(), {auth: mismatchedAuth}));
  const changedDuringRequest = makeDb();
  changedDuringRequest.beforeNextTransaction = async () => {
    changedDuringRequest.store.securityStaff["security-1"].communityId = "community-b";
    changedDuringRequest.store.communities["community-b"] = {isActive: true};
  };
  await assert.rejects(request({qrToken, operationId: "operation-race-auth-01"}, changedDuringRequest));
});

test("response and persisted audit/operation records contain no credentials or HMAC indexes", async () => {
  const db = makeDb();
  const result = await request({qrToken, operationId: "operation-sanitize-01"}, db);
  const serialized = JSON.stringify({result, operations: db.store.visitorGateOperations,
    events: db.store.visitorGateEvents});
  assert.equal(serialized.includes(qrToken), false);
  assert.equal(serialized.includes("ABCDEFGHJKLM"), false);
  assert.equal(serialized.includes(credentialHash(hmacKey, "qr", qrToken)), false);
  assert.equal("credentialHash" in result, false);
  assert.equal("qrToken" in result, false);
  assert.equal("manualCode" in result, false);
});

test("malformed credential contract is rejected and legacy SEC-003 APIs remain separate", async () => {
  await assert.rejects(request({qrToken, manualCode, operationId: "operation-both-000001"}));
  await assert.rejects(request({qrToken}, makeDb()));
  const {resolveVisitorQrCore, transitionVisitorFromQrCore} = require("../src/visitor_gate");
  assert.equal(typeof resolveVisitorQrCore, "function");
  assert.equal(typeof transitionVisitorFromQrCore, "function");
});

test("callable export enforces App Check in the existing Functions region and uses the HMAC secret", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  const callable = source.match(/exports\.verifyVisitorCredential = onCall\(\{([\s\S]*?)\}, async \(request\)/);
  assert.ok(callable);
  assert.match(callable[1], /region:\s*REGION/);
  assert.match(callable[1], /enforceAppCheck:\s*true/);
  assert.match(callable[1], /VISITOR_CREDENTIAL_HMAC_KEY/);
  assert.match(source, /const REGION = "asia-southeast1"/);
});
