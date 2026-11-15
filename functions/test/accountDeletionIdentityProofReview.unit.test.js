const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { cleanupApprovedResidentIdentityProofCore } = require("../src/account_deletion_requests");

function fixture({ legalHold = false, objectExists = true } = {}) {
  const docs = new Map([
    ["accountDeletionRequests/r1", { uid: "resident", requestId: "r1", sourceApp: "resident", communityId: "C1", communityScopeVerified: true, status: "deletion_in_progress", ...(legalHold ? { legalHoldStatus: "active" } : {}) }],
    ["users/resident", { uid: "resident", role: "resident", communityId: "C1", identityProofStoragePath: "residentIdentityProofs/C1/resident/proof.jpg" }],
  ]);
  const ref = (c, id) => ({ collectionName: c, id, path: `${c}/${id}`, get: async () => ({ exists: docs.has(`${c}/${id}`), data: () => docs.get(`${c}/${id}`) }), set: async (value, options = {}) => docs.set(`${c}/${id}`, options.merge ? { ...docs.get(`${c}/${id}`), ...value } : value), collection: (sub) => ({ doc: (sid) => ref(`${c}/${id}/${sub}`, sid) }) });
  const db = {
    collection: (c) => ({ doc: (id) => ref(c, id) }),
    runTransaction: async (fn) => fn({
      get: async (r) => ({ exists: docs.has(`${r.collectionName}/${r.id}`), data: () => docs.get(`${r.collectionName}/${r.id}`) }),
      set: (r, value, options = {}) => docs.set(`${r.collectionName}/${r.id}`, options.merge ? { ...docs.get(`${r.collectionName}/${r.id}`), ...value } : value),
    }),
  };
  let exists = objectExists;
  let deletedGeneration;
  const bucket = { file: (path) => ({ getMetadata: async () => { if (!exists) throw Object.assign(Error("missing"), { code: 404 }); return [{ generation: "g1", name: path }]; }, delete: async (options) => { deletedGeneration = options.ifGenerationMatch; exists = false; } }) };
  return { db, bucket, docs, get exists() { return exists; }, get deletedGeneration() { return deletedGeneration; } };
}
const eligibilityReport = { requestId: "r1", uid: "resident", eligible: true, deletionPerformed: false };
const cleanup = (f, report = eligibilityReport) => cleanupApprovedResidentIdentityProofCore({ ...f, requestId: "r1", eligibilityReport: report });

test("owned identity proof is deleted automatically with request-bound, generation-pinned progress", async () => {
  const f = fixture();
  const result = await cleanup(f);
  assert.equal(result.deleted, true);
  assert.equal(f.exists, false);
  assert.equal(f.deletedGeneration, "g1");
  const progress = f.docs.get("accountDeletionRequests/r1/processing/identityProof");
  assert.equal(progress.status, "completed");
  assert.equal(progress.requestId, "r1");
  assert.equal(progress.storageGeneration, "g1");
  assert.equal((await cleanup(f)).idempotent, true);
});

test("legal hold, changed identity, missing object and stale eligibility fail closed", async () => {
  await assert.rejects(cleanup(fixture({ legalHold: true })), /legal hold/i);
  await assert.rejects(cleanup(fixture(), { ...eligibilityReport, eligible: false }));
  const missing = fixture({ objectExists: false });
  await assert.rejects(cleanup(missing));
  const changed = fixture();
  changed.docs.set("users/resident", { uid: "resident", role: "resident", communityId: "C2", identityProofStoragePath: "residentIdentityProofs/C1/resident/proof.jpg" });
  await assert.rejects(cleanup(changed));
});

test("Admin identity-proof retention-review callable is removed", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.doesNotMatch(source, /recordAccountDeletionIdentityProofReview/);
});
