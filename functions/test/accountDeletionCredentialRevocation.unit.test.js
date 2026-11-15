const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { HttpsError } = require("firebase-functions/v2/https");
const { revokeResidentVisitorCredentialsCore, reviewAccountDeletionEligibilityCore } = require("../src/account_deletion_requests");
const { checkoutVisitorsCore } = require("../src/security_visitor_workflow");

function fixture({ failCommit = false, mismatch = false } = {}) {
  const docs = new Map();
  const writes = [];
  let shouldFailCommit = failCommit;
  let transactionCount = 0;
  let failAtTransaction = null;
  const key = (c, id) => `${c}/${id}`;
  const initial = {
    "securityStaff/security-1": { uid: "security-1", role: "security", isActive: true, communityId: "C1", phoneNumber: "+15555550124" },
    "communities/C1": { isActive: true },
    "accountDeletionRequests/r1": { uid: "resident-1", status: "pending_review" },
    "users/resident-1": { uid: "resident-1", role: "resident", communityId: "C1", approvalStatus: "approved" },
    "visitors/v1": { hostUserId: "resident-1", residentId: "resident-1", communityId: "C1", status: "approved", isApproved: true, expectedArrival: new Date(Date.now() + 60_000), visitorName: "Guest", checkedInAt: 123 },
    "visitors/v2": { hostUserId: "resident-1", residentId: "resident-1", communityId: "C2", status: "completed", visitorName: "Other guest", actualArrival: new Date(Date.now() - 120_000), departure: new Date(Date.now() - 60_000), checkedOutBy: "security-2" },
    "visitors/foreign": { hostUserId: "someone-else", residentId: "someone-else", communityId: "C1", status: "approved" },
    "visitorHostCredentials/v1": { hostUserId: mismatch ? "other" : "resident-1", communityId: "C1", qrToken: "secret" },
    "visitorHostCredentials/v2": { hostUserId: "resident-1", communityId: "C2", manualCode: "secret2" },
    "visitorGateCredentialIndex/hash1": { visitorId: "v1", hostUserId: "resident-1", communityId: "C1", credentialType: "qr" },
    "visitorGateCredentialIndex/hash2": { visitorId: "v1", hostUserId: "resident-1", communityId: "C1", credentialType: "manual" },
    "visitorGateCredentialIndex/hash3": { visitorId: "v2", hostUserId: "resident-1", communityId: "C2", credentialType: "qr" },
    "visitorGateCredentialIndex/foreignHash": { visitorId: "foreign", communityId: "C1" },
    "auditLogs/a1": { actorUid: "resident-1", action: "visit", summary: "Preserve" },
  };
  for (const [k, v] of Object.entries(initial)) docs.set(k, structuredClone(v));
  const ref = (collectionName, id) => ({ collectionName, id, get: async () => snap(collectionName, id), collection(name) { return { doc(childId) { return ref(`${collectionName}/${id}/${name}`, childId); } }; } });
  const snap = (collectionName, id) => ({ exists: docs.has(key(collectionName, id)), id, ref: ref(collectionName, id), data: () => docs.get(key(collectionName, id)) });
  const query = (collection, field, value) => ({ collection, field, value, async get() { const found = [...docs.entries()].filter(([k, v]) => k.startsWith(`${collection}/`) && v[field] === value); return { docs: found.map(([k]) => snap(collection, k.slice(collection.length + 1))), size: found.length, empty: !found.length }; } });
  const db = { docs, writes, collection(c) { return { doc(id) { return ref(c, id); }, where(field, _op, value) { return query(c, field, value); } }; }, async runTransaction(fn) {
    transactionCount++;
    const pending = [];
    const tx = {
      async get(target) { if (target.field) { const result = await target.get(); return result; } return snap(target.collectionName, target.id); },
      delete(target) { pending.push({ op: "delete", target }); },
      update(target, value) { pending.push({ op: "update", target, value }); },
      set(target, value) { pending.push({ op: "set", target, value }); },
      create(target, value) { pending.push({ op: "create", target, value }); },
    };
    const outcome = await fn(tx);
    if (shouldFailCommit || transactionCount === failAtTransaction) throw new Error("injected commit failure");
    for (const item of pending) {
      const k = key(item.target.collectionName, item.target.id);
      if (item.op === "delete") docs.delete(k);
      else if (item.op === "create") {
        if (docs.has(k)) throw new Error("already_exists");
        docs.set(k, item.value);
      } else {
        const value = {...item.value};
        if (item.op === "update" && value.departure != null) value.departure = new Date();
        docs.set(k, { ...docs.get(k), ...value });
      }
      writes.push(item.op);
    }
    return outcome;
  } };
  return { db, key, failCommit(value) { shouldFailCommit = value; }, failTransactionAt(value) { failAtTransaction = value; } };
}
const call = (f) => revokeResidentVisitorCredentialsCore({ db: f.db, data: { requestId: "r1" } });

test("revokes active credential and all hash indexes; preserves visitor/audit history", async () => {
  const f = fixture();
  const before = f.db.docs.get("visitors/v1");
  await call(f);
  const progress = f.db.docs.get("accountDeletionRequests/r1/visitorCredentialRevocations/v1");
  assert.equal(f.db.docs.has("visitorHostCredentials/v1"), false);
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/hash1"), false);
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/hash2"), false);
  assert.equal(f.db.docs.get("visitors/v1").visitorName, before.visitorName);
  assert.equal(f.db.docs.get("visitors/v1").checkedInAt, before.checkedInAt);
  assert.equal(f.db.docs.get("visitors/v1").credentialRevokedBy, "system:account-deletion");
  assert.equal(f.db.docs.get("visitors/v1").status, "cancelled");
  assert.equal(f.db.docs.get("visitors/v1").isApproved, false);
  assert.equal(f.db.docs.get("visitors/v1").cancelledBy, "system:account-deletion");
  assert.equal(progress.uid, "resident-1");
  assert.equal(progress.communityId, "C1");
  assert.equal(progress.visitorId, "v1");
  assert.equal(progress.status, "completed");
  assert.equal(progress.complete, true);
  assert.equal(f.db.docs.has("auditLogs/a1"), true);
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/foreignHash"), true);
});

test("second execution is idempotent and leaves unrelated communities untouched", async () => {
  const f = fixture();
  const first = await call(f); const second = await call(f);
  assert.equal(f.db.docs.has("visitorHostCredentials/v1"), false);
  assert.equal(f.db.docs.has("visitorHostCredentials/v2"), false);
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/hash3"), false);
  assert.equal(f.db.docs.has("visitors/foreign"), true);
  assert.equal(first.complete, true);
  assert.equal(second.complete, true);
  assert.equal(second.revoked.find((item) => item.visitorId === "v1").idempotent, true);
});

test("internal cleanup rejects missing requests and client execution claims", async () => {
  const f = fixture();
  await assert.rejects(revokeResidentVisitorCredentialsCore({ db: f.db, data: { requestId: "missing" } }), HttpsError);
  await assert.rejects(revokeResidentVisitorCredentialsCore({ db: f.db, data: { requestId: "r1", uid: "arbitrary" } }), HttpsError);
});

test("ownership mismatch blocks without touching credential or indexes", async () => {
  const f = fixture({ mismatch: true });
  const before = [...f.db.docs.entries()].filter(([key]) => key.includes("v1") || key.includes("hash1") || key.includes("hash2"));
  const result = await call(f);
  assert.equal(result.blockers.length, 1);
  assert.deepEqual([...f.db.docs.entries()].filter(([key]) => key.includes("v1") || key.includes("hash1") || key.includes("hash2")), before);
});

test("legacy residentId link is sufficient only when credential and community independently match", async () => {
  const f = fixture();
  f.db.docs.set("visitors/legacy", { residentId: "resident-1", communityId: "C1", status: "expected", isApproved: false, expectedArrival: new Date(Date.now() + 60_000), visitHistory: [10] });
  f.db.docs.set("visitorHostCredentials/legacy", { hostUserId: "resident-1", communityId: "C1", qrToken: "private" });
  f.db.docs.set("visitorGateCredentialIndex/legacyHash", { visitorId: "legacy", communityId: "C1", credentialType: "qr" });
  const result = await call(f);
  assert.equal(result.complete, true);
  assert.equal(f.db.docs.has("visitorHostCredentials/legacy"), false);
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/legacyHash"), false);
  assert.equal(f.db.docs.get("visitors/legacy").residentId, "resident-1");
  assert.equal(f.db.docs.get("visitors/legacy").status, "cancelled");
  assert.deepEqual(f.db.docs.get("visitors/legacy").visitHistory, [10]);
  assert.equal(f.db.docs.get("accountDeletionRequests/r1/visitorCredentialRevocations/legacy").complete, true);
});

test("physically checked-in visitor remains blocked and is never marked checked out by deletion cleanup", async () => {
  const f = fixture();
  Object.assign(f.db.docs.get("visitors/v1"), {status: "inside", actualArrival: new Date(Date.now() - 30_000), departure: null});
  const result = await call(f);
  const visitor = f.db.docs.get("visitors/v1");
  assert.equal(result.complete, false);
  assert.ok(result.blockers.some((item) => item.visitorId === "v1" && /Security checkout/ .test(item.reason)));
  assert.equal(visitor.status, "inside");
  assert.equal(visitor.departure, null);
  assert.equal(visitor.checkedOutBy, undefined);
  assert.equal(visitor.credentialRevokedBy, "sa");
  assert.equal(f.db.docs.get("accountDeletionRequests/r1/visitorCredentialRevocations/v1").visitorDisposition, "checked_in");
  const report = await reviewAccountDeletionEligibilityCore({db: f.db, auth: f.auth, data: {requestId: "r1"}});
  assert.equal(report.eligible, false);
  assert.equal(report.deletionPerformed, false);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "checkedInVisitors"));
});

test("verified Security checkout removes the active visit dependency while preserving history", async () => {
  const f = fixture();
  Object.assign(f.db.docs.get("visitors/v1"), {status: "inside", isApproved: true, actualArrival: new Date(Date.now() - 120_000), departure: null});
  f.db.docs.delete("visitorHostCredentials/v1");
  f.db.docs.delete("visitorGateCredentialIndex/hash1");
  f.db.docs.delete("visitorGateCredentialIndex/hash2");
  const checkout = await checkoutVisitorsCore({db: f.db, auth: {uid: "security-1", token: {phone_number: "+15555550124", firebase: {sign_in_provider: "phone"}}}, data: {visitorIds: ["v1"], operationId: "checkout-operation-001"}});
  assert.equal(checkout.succeeded, 1);
  assert.equal(f.db.docs.get("visitors/v1").status, "completed");
  assert.equal(f.db.docs.get("visitors/v1").checkedOutBy, "security-1");
  assert.ok(f.db.docs.get("visitors/v1").departure);
  const report = await reviewAccountDeletionEligibilityCore({db: f.db, auth: f.auth, data: {requestId: "r1"}});
  assert.equal(report.eligible, false);
  assert.equal(report.visitorLifecycle.find((item) => item.visitorId === "v1").classification, "verified_completed_history");
  assert.equal(report.unresolvedChecks.some((item) => item.check === "checkedInVisitors"), false);
  assert.equal(report.unresolvedChecks.some((item) => item.check === "futureVisitors"), false);
  assert.equal(report.unresolvedChecks.some((item) => item.check === "ambiguousVisitorState"), false);
  assert.ok(report.coverage.preservedHistoricalReferences.some((item) => item.type === "historical_visitors"));
  assert.equal(f.db.docs.get("visitors/v1").checkedOutBy, "security-1");
});

test("unsupported or inconsistent visitor lifecycle remains blocked without false cancellation", async () => {
  const f = fixture();
  Object.assign(f.db.docs.get("visitors/v1"), {status: "arrived", actualArrival: null});
  const beforeCredential = structuredClone(f.db.docs.get("visitorHostCredentials/v1"));
  const result = await call(f);
  assert.equal(result.complete, false);
  assert.ok(result.blockers.some((item) => item.visitorId === "v1" && /unsupported or inconsistent/.test(item.reason)));
  assert.deepEqual(f.db.docs.get("visitorHostCredentials/v1"), beforeCredential);
  assert.equal(f.db.docs.get("visitors/v1").status, "arrived");
  assert.equal(f.db.docs.get("visitors/v1").departure, undefined);
});

test("owner index with an unknown visitor relationship remains blocked", async () => {
  const f = fixture();
  f.db.docs.set("visitorGateCredentialIndex/orphan", { visitorId: "missing-visitor", hostUserId: "resident-1", communityId: "C1" });
  const result = await call(f);
  assert.equal(result.complete, false);
  assert.ok(result.blockers.some((item) => item.visitorId === "missing-visitor"));
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/orphan"), true);
  assert.equal(f.db.docs.has("accountDeletionRequests/r1/visitorCredentialRevocations/missing-visitor"), false);
});

test("injected transaction failure records no false progress and retry completes", async () => {
  const f = fixture({ failCommit: true });
  const before = [...f.db.docs.entries()].map(([k, v]) => [k, structuredClone(v)]);
  await assert.rejects(call(f));
  assert.deepEqual([...f.db.docs.entries()], before);
  f.failCommit(false);
  await call(f);
  assert.equal(f.db.docs.has("visitorHostCredentials/v1"), false);
  assert.equal(f.db.docs.has("visitorGateCredentialIndex/hash1"), false);
  assert.equal(f.db.docs.get("accountDeletionRequests/r1/visitorCredentialRevocations/v1").complete, true);
});

test("partial visitor failure preserves completed cancellation progress and retries remaining visitor", async () => {
  const f = fixture();
  f.failTransactionAt(2);
  await assert.rejects(call(f));
  assert.equal(f.db.docs.get("visitors/v1").status, "cancelled");
  assert.equal(f.db.docs.has("visitorHostCredentials/v1"), false);
  assert.equal(f.db.docs.get("accountDeletionRequests/r1/visitorCredentialRevocations/v1").complete, true);
  assert.equal(f.db.docs.has("visitorHostCredentials/v2"), true);
  assert.equal(f.db.docs.has("accountDeletionRequests/r1/visitorCredentialRevocations/v2"), false);
  f.failTransactionAt(null);
  const retried = await call(f);
  assert.equal(retried.complete, true);
  assert.equal(retried.revoked.find((item) => item.visitorId === "v1").idempotent, true);
  assert.equal(f.db.docs.get("visitors/v2").status, "completed");
  assert.equal(f.db.docs.has("visitorHostCredentials/v2"), false);
  assert.equal(f.db.docs.get("accountDeletionRequests/r1/visitorCredentialRevocations/v2").complete, true);
});

test("missing credentials without matching request progress remain blocked", async () => {
  const f = fixture();
  f.db.docs.delete("visitorHostCredentials/v1");
  f.db.docs.delete("visitorGateCredentialIndex/hash1");
  f.db.docs.delete("visitorGateCredentialIndex/hash2");
  const result = await call(f);
  assert.equal(result.complete, false);
  assert.match(result.blockers.find((item) => item.visitorId === "v1").reason, /no matching request-scoped/);
  assert.equal(f.db.docs.has("visitors/v1"), true);
  assert.equal(f.db.docs.has("accountDeletionRequests/r1/visitorCredentialRevocations/v1"), false);
});

test("eligibility recognizes only request-bound completed revocation and keeps unrelated blockers", async () => {
  const f = fixture();
  const first = await call(f);
  assert.equal(first.complete, true);
  f.db.docs.delete("visitorHostCredentials/v1");
  f.db.docs.delete("visitorGateCredentialIndex/hash1");
  f.db.docs.delete("visitorGateCredentialIndex/hash2");
  f.db.docs.set("visitorHostCredentials/v2", { hostUserId: "resident-1", communityId: "C2" });
  f.db.docs.set("visitorGateCredentialIndex/hash3", { visitorId: "v2", hostUserId: "resident-1", communityId: "C2" });
  const report = await reviewAccountDeletionEligibilityCore({ db: f.db, auth: f.auth, data: { requestId: "r1" } });
  assert.equal(report.eligible, false);
  assert.equal(report.deletionPerformed, false);
  assert.equal(report.visitorCredentials.find((item) => item.visitorId === "v1").revocationCompleted, true);
  assert.equal(report.unresolvedChecks.some((item) => item.check === "missingCredentialWithoutProgress"), false);
  assert.equal(report.unresolvedChecks.some((item) => item.check === "activeCredential"), true); // v2 remains active
  assert.equal(f.db.docs.has("accountDeletionRequests/r1/visitorCredentialRevocations/v1"), true);
});

test("eligibility does not accept missing credential/index records without matching progress", async () => {
  const f = fixture();
  f.db.docs.delete("visitorHostCredentials/v1");
  f.db.docs.delete("visitorGateCredentialIndex/hash1");
  f.db.docs.delete("visitorGateCredentialIndex/hash2");
  const report = await reviewAccountDeletionEligibilityCore({ db: f.db, auth: f.auth, data: { requestId: "r1" } });
  assert.equal(report.eligible, false);
  assert.equal(report.visitorCredentials.find((item) => item.visitorId === "v1").revocationCompleted, false);
  assert.ok(report.unresolvedChecks.some((item) => item.check === "missingCredentialWithoutProgress"));
  assert.equal(f.db.writes.length, 0);
});

test("credential cleanup is backend-only with no public callable export", async () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.doesNotMatch(source, /exports\.revokeResidentVisitorCredentialsForDeletion\s*=/);
});
