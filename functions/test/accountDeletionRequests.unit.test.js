const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { HttpsError } = require("firebase-functions/v2/https");
const {
  submitAccountDeletionRequestCore,
  getAccountDeletionRequestStatusCore,
} = require("../src/account_deletion_requests");

function dbMock() {
  const records = new Map();
  return {
    records,
    collection(name) {
      if (name !== "accountDeletionRequests") return { doc(id) { return { id, async get() { return { id, exists: false, data: () => undefined }; } }; } };
      return {
        doc(id) { return { id, async get() { const data = records.get(id); return { id, exists: !!data, data: () => data }; } }; },
        where(field, op, value) { assert.equal(op, "=="); return { async get() { const docs = [...records.entries()].filter(([, v]) => v[field] === value).map(([id, data]) => ({ id, data: () => data })); return { docs, empty: !docs.length }; } }; },
      };
    },
    async runTransaction(fn) {
      return fn({
        async get(ref) { if (ref.id) { const data = records.get(ref.id); return { exists: !!data, data: () => data }; } return ref.get(); },
        set(ref, data) { records.set(ref.id, data); },
        update(ref, data) { records.set(ref.id, { ...records.get(ref.id), ...data }); },
      });
    },
  };
}
const auth = (uid, auth_time = 1000) => ({ uid, token: { auth_time } });
const now = 1_200_000;

test("submission creates a minimal request for profileless authenticated UID", async () => {
  const db = dbMock();
  const result = await submitAccountDeletionRequestCore({ db, auth: auth("profileless"), data: { sourceApp: "resident", uid: "other", role: "admin" }, now });
  assert.equal(result.status, "pending_review");
  assert.equal([...db.records.values()][0].uid, "profileless");
  assert.equal([...db.records.values()][0].role, undefined);
});

test("rejects unauthenticated and stale, missing, future or malformed auth_time", async () => {
  const db = dbMock();
  for (const candidate of [null, auth("u", 899), { uid: "u", token: {} }, auth("u", 1201), auth("u", "1200")]) {
    await assert.rejects(submitAccountDeletionRequestCore({ db, auth: candidate, data: { sourceApp: "admin" }, now }), HttpsError);
  }
});

test("duplicate active submission is idempotent and client UID is ignored", async () => {
  const db = dbMock();
  const args = { db, auth: auth("owner"), data: { sourceApp: "security", uid: "victim" }, now };
  const first = await submitAccountDeletionRequestCore(args);
  const second = await submitAccountDeletionRequestCore(args);
  assert.equal(first.requestId, second.requestId);
  assert.equal(second.idempotent, true);
  assert.equal([...db.records.values()].some((record) => record.uid === "victim"), false);
});

test("status lookup is scoped to authenticated UID", async () => {
  const db = dbMock();
  await submitAccountDeletionRequestCore({ db, auth: auth("owner"), data: { sourceApp: "admin" }, now });
  const owned = (await getAccountDeletionRequestStatusCore({ db, auth: auth("owner") })).request;
  assert.equal(owned.status, "pending_verification");
  assert.equal((await getAccountDeletionRequestStatusCore({ db, auth: auth("other") })).request, null);
});

test("exports enforce App Check and rules deny direct client access", () => {
  const index = fs.readFileSync(require.resolve("../src/index"), "utf8");
  const rules = fs.readFileSync(require.resolve("../../firestore.rules"), "utf8");
  assert.match(index, /exports\.submitAccountDeletionRequest = accountDeletionCallable/);
  assert.match(index, /exports\.getAccountDeletionRequestStatus = accountDeletionCallable/);
  const reassessmentExport = index.match(/exports\.reassessAccountDeletionRequest = accountDeletionCallable\(([\s\S]*?)\);/);
  assert.ok(reassessmentExport);
  assert.doesNotMatch(reassessmentExport[1], /,\s*true\s*$/);
  assert.match(index, /onCall\(\{ region: REGION, enforceAppCheck: true \}/);
  assert.match(rules, /match \/accountDeletionRequests\/\{requestId\}[\s\S]*?allow read, write: if false;/);
});
