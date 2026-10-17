const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  checkoutVisitorsCore,
  denyVisitorEntryCore,
  listSecurityVisitorsCore,
} = require("../src/security_visitor_workflow");

const now = Date.UTC(2026, 9, 11, 3, 0);
const auth = {uid: "security-1", token: {
  phone_number: "+639170000000", firebase: {sign_in_provider: "phone"},
}};
const expected = (overrides = {}) => ({
  communityId: "community-a", hostUserId: "resident-1", hostName: "Host One",
  visitorName: "Guest One", phoneNumber: "+639171111111", flatId: "flat-a1",
  flatLabel: "A-101", purpose: "Delivery", expectedArrival: new Date(now),
  status: "expected", isApproved: false, actualArrival: null, departure: null,
  ...overrides,
});
const inside = (overrides = {}) => expected({
  status: "inside", actualArrival: new Date(now - 60_000), ...overrides,
});

function fakeDb(visitors = {"visitor-1": expected()}) {
  const store = {
    securityStaff: {"security-1": {uid: "security-1", phoneNumber: auth.token.phone_number,
      role: "security", isActive: true, communityId: "community-a"}},
    communities: {"community-a": {isActive: true}},
    visitors, visitorGateOperations: {}, visitorGateEvents: {},
  };
  let transactionTail = Promise.resolve();
  const ref = (collection, id) => ({collection, id,
    get: async () => snapshot(store[collection]?.[id]),
  });
  const db = {
    store,
    collection(name) {
      return {
        doc: (id) => ref(name, id),
        where(field, operator, value) {
          const makeQuery = (filters) => ({
            where(nextField, nextOperator, nextValue) {
              return makeQuery([...filters, [nextField, nextOperator, nextValue]]);
            },
            limit() { return makeQuery(filters); },
            get: async () => ({docs: Object.entries(store[name] || {})
              .filter(([, data]) => filters.every(([key, op, expectedValue]) =>
                op === "==" ? data[key] === expectedValue :
                  op === "in" ? expectedValue.includes(data[key]) :
                    op === "!=" ? data[key] != null && data[key] !== expectedValue : false))
              .map(([id, data]) => ({id, data: () => ({...data})}))}),
          });
          return makeQuery([[field, operator, value]]);
        },
      };
    },
    async runTransaction(callback) {
      let release;
      const previous = transactionTail;
      transactionTail = new Promise((resolve) => { release = resolve; });
      await previous;
      const writes = [];
      const transaction = {
        get: async (document) => snapshot(store[document.collection]?.[document.id]),
        update: (document, patch) => writes.push({kind: "update", document, value: patch}),
        create: (document, value) => writes.push({kind: "create", document, value}),
      };
      try {
        const result = await callback(transaction);
        for (const write of writes) {
          const collection = store[write.document.collection] ||= {};
          if (write.kind === "create") {
            if (collection[write.document.id]) throw new Error("already-exists");
            collection[write.document.id] = {...write.value};
          } else {
            if (!collection[write.document.id]) throw new Error("not-found");
            Object.assign(collection[write.document.id], write.value);
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

test("expected excludes denied invitations and history includes denial markers without credential data", async () => {
  const db = fakeDb({
    expected: expected({isApproved: false, qrToken: "secret-qr", visitorPassCode: "secret-code", credentialHash: "secret-hash"}),
    approvedExpected: expected({status: "approved", isApproved: true}),
    deniedUnapproved: expected({gateAccessStatus: "denied", gateEntryDeniedAt: new Date(now - 1000),
      gateEntryDenialReason: "No valid ID", qrToken: "another-secret"}),
    deniedApproved: expected({isApproved: true, gateEntryDeniedAt: new Date(now - 2000),
      gateEntryDenialReason: "Host approval does not override gate denial"}),
    deniedTimestampOnly: expected({isApproved: true, gateEntryDeniedAt: new Date(now - 3000)}),
    expired: expected({expectedArrival: new Date(now - 48 * 60 * 60 * 1000)}),
    foreign: expected({communityId: "community-b", qrToken: "foreign-secret"}),
    active: inside(),
    completed: expected({status: "completed", actualArrival: new Date(now - 60_000), departure: new Date(now)}),
  });
  const expectedResult = await listSecurityVisitorsCore({db, auth,
    data: {category: "expected"}, now: () => now});
  const insideResult = await listSecurityVisitorsCore({db, auth,
    data: {category: "inside"}, now: () => now});
  const historyResult = await listSecurityVisitorsCore({db, auth,
    data: {category: "completed"}, now: () => now});
  assert.deepEqual(expectedResult.visitors.map((visitor) => visitor.visitorId).sort(),
    ["approvedExpected", "expected"]);
  assert.deepEqual(insideResult.visitors.map((visitor) => visitor.visitorId), ["active"]);
  assert.deepEqual(historyResult.visitors.map((visitor) => visitor.visitorId).sort(),
    ["completed", "deniedApproved", "deniedTimestampOnly", "deniedUnapproved"]);
  assert.equal(historyResult.visitors.find((visitor) => visitor.visitorId === "deniedApproved").adminApproved, true);
  assert.equal(historyResult.visitors.find((visitor) => visitor.visitorId === "deniedUnapproved").adminApproved, false);
  assert.equal(historyResult.visitors.find((visitor) => visitor.visitorId === "deniedApproved").gateEntryDenialReason,
    "Host approval does not override gate denial");
  assert.equal(historyResult.visitors.find((visitor) => visitor.visitorId === "deniedApproved").gateEntryDeniedAt,
    now - 2000);
  const expectedIds = new Set(expectedResult.visitors.map((visitor) => visitor.visitorId));
  const insideIds = new Set(insideResult.visitors.map((visitor) => visitor.visitorId));
  const historyIds = new Set(historyResult.visitors.map((visitor) => visitor.visitorId));
  for (const id of expectedIds) {
    assert.equal(insideIds.has(id) || historyIds.has(id), false, `${id} must not appear in another category`);
  }
  for (const id of historyIds) assert.equal(expectedIds.has(id) || insideIds.has(id), false);

  const serialized = JSON.stringify({expectedResult, insideResult, historyResult});
  for (const secret of ["secret-qr", "secret-code", "secret-hash", "another-secret", "foreign-secret"]) {
    assert.equal(serialized.includes(secret), false);
  }
  for (const field of ["qrToken", "visitorPassCode", "credentialHash", "manualCode"]) {
    assert.equal(Object.hasOwn(expectedResult.visitors[0], field), false);
  }
});

test("visitor list supports inside and completed categories with current state only", async () => {
  const db = fakeDb({
    active: inside(),
    completed: expected({status: "completed", actualArrival: new Date(now - 60_000), departure: new Date(now)}),
    expected: expected(),
  });
  const active = await listSecurityVisitorsCore({db, auth, data: {category: "inside"}, now: () => now});
  const history = await listSecurityVisitorsCore({db, auth, data: {category: "completed"}, now: () => now});
  assert.deepEqual(active.visitors.map((visitor) => visitor.visitorId), ["active"]);
  assert.deepEqual(history.visitors.map((visitor) => visitor.visitorId), ["completed"]);
});

test("Deny Entry requires a reason, is idempotent, audits, and preserves canonical/admin state", async () => {
  const db = fakeDb();
  const request = {visitorId: "visitor-1", reason: "No valid identification", operationId: "deny-operation-0001"};
  const first = await denyVisitorEntryCore({db, auth, data: request, now: () => now});
  const retry = await denyVisitorEntryCore({db, auth, data: request, now: () => now});
  const visitor = db.store.visitors["visitor-1"];
  assert.equal(first.status, "denied");
  assert.equal(first.idempotent, false);
  assert.equal(retry.idempotent, true);
  assert.equal(visitor.status, "expected");
  assert.equal(visitor.isApproved, false);
  assert.equal(visitor.approvedBy, undefined);
  assert.equal(visitor.actualArrival, null);
  assert.equal(visitor.departure, null);
  assert.equal(visitor.gateAccessStatus, "denied");
  assert.equal(visitor.gateEntryDeniedBy, auth.uid);
  assert.equal(Object.keys(db.store.visitorGateEvents).length, 1);
  const event = Object.values(db.store.visitorGateEvents)[0];
  assert.equal(event.eventType, "visitor_entry_denied");
  assert.equal(event.reason, request.reason);
});

test("Deny Entry rejects blank reasons, expired visits, duplicate invitation denials and wrong communities", async () => {
  await assert.rejects(denyVisitorEntryCore({db: fakeDb(), auth,
    data: {visitorId: "visitor-1", reason: "  ", operationId: "deny-operation-0001"}, now: () => now}));
  await assert.rejects(denyVisitorEntryCore({db: fakeDb({"visitor-1": expected({
    expectedArrival: new Date(now - 48 * 60 * 60 * 1000),
  })}), auth, data: {visitorId: "visitor-1", reason: "Expired", operationId: "deny-operation-0002"}, now: () => now}));
  const deniedDb = fakeDb({"visitor-1": expected({gateAccessStatus: "denied", gateEntryDeniedAt: new Date(now)})});
  await assert.rejects(denyVisitorEntryCore({db: deniedDb, auth,
    data: {visitorId: "visitor-1", reason: "Again", operationId: "deny-operation-0003"}, now: () => now}));
  await assert.rejects(denyVisitorEntryCore({db: fakeDb({"visitor-1": expected({communityId: "community-b"})}), auth,
    data: {visitorId: "visitor-1", reason: "Wrong community", operationId: "deny-operation-0004"}, now: () => now}));
});

test("disabled or community-reassigned Security cannot list, deny, or check out", async () => {
  const disabled = fakeDb();
  disabled.store.securityStaff["security-1"].isActive = false;
  await assert.rejects(listSecurityVisitorsCore({db: disabled, auth, data: {category: "expected"}}));
  await assert.rejects(denyVisitorEntryCore({db: disabled, auth,
    data: {visitorId: "visitor-1", reason: "No entry", operationId: "deny-operation-0005"}}));
  await assert.rejects(checkoutVisitorsCore({db: disabled, auth,
    data: {visitorIds: ["visitor-1"], operationId: "checkout-operation-001"}}));
  const reassigned = fakeDb();
  reassigned.store.securityStaff["security-1"].communityId = "community-b";
  await assert.rejects(checkoutVisitorsCore({db: reassigned, auth,
    data: {visitorIds: ["visitor-1"], operationId: "checkout-operation-002"}}));
});

test("single and bulk checkout are independent, transactional and idempotent per visitor", async () => {
  const db = fakeDb({
    one: inside(), two: inside({visitorName: "Guest Two"}),
    alreadyCompleted: expected({status: "completed", actualArrival: new Date(now - 60_000), departure: new Date(now)}),
    foreign: inside({communityId: "community-b"}),
  });
  const request = {visitorIds: ["one", "alreadyCompleted", "foreign"], operationId: "checkout-operation-003"};
  const result = await checkoutVisitorsCore({db, auth, data: request});
  assert.equal(result.succeeded, 1);
  assert.equal(result.failed, 2);
  assert.equal(db.store.visitors.one.status, "completed");
  assert.equal(db.store.visitors.one.checkedOutBy, auth.uid);
  assert.ok(db.store.visitors.one.departure);
  assert.equal(db.store.visitors.two.status, "inside");
  assert.equal(Object.keys(db.store.visitorGateEvents).length, 1);
  const retry = await checkoutVisitorsCore({db, auth, data: request});
  assert.equal(retry.results[0].success, true);
  assert.equal(retry.results[0].idempotent, true);
  assert.equal(db.store.visitors.one.status, "completed");
  assert.equal(Object.keys(db.store.visitorGateEvents).length, 1);
});

test("bulk checkout rejects duplicate IDs and does not accept direct client state payloads", async () => {
  await assert.rejects(checkoutVisitorsCore({db: fakeDb(), auth, data: {
    visitorIds: ["visitor-1", "visitor-1"], operationId: "checkout-operation-004",
  }}));
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  for (const name of ["listSecurityVisitors", "denyVisitorEntry", "checkoutVisitors"]) {
    const callable = source.match(new RegExp(`exports\\.${name} = securityWorkflowCallable\\(([\\s\\S]*?)\\);`));
    assert.ok(callable, `${name} must use the App Check protected callable wrapper`);
  }
});
