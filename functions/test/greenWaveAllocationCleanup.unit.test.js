"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { TARGET, verifyEvidence, inspectOrApply } = require("../scripts/cleanup-green-wave-unit-allocation");
const time = (n) => Timestamp.fromMillis(n);
function evidence() {
  const step = {requestId: TARGET.requestId, uid: TARGET.uid, status: "completed"};
  return {
    community: {name: "Green Wave Residences", isActive: true, isDemoData: true},
    request: {...step, sourceApp: "resident", communityId: "GREEN-WAVE", communityScopeVerified: true,
      completionVerified: true, authUidDeleted: TARGET.uid, residentProfilePath: `users/${TARGET.uid}`, completedAt: time(3000)},
    cleanup: {...step, completedAt: time(2000), memberships: [{collection: "flats", id: TARGET.flatId, communityId: "GREEN-WAVE"}]},
    profileStep: {...step, communityId: "GREEN-WAVE", verifiedAbsent: true},
    authStep: {...step, verifiedAbsent: true, operationStarted: true},
    unit: {communityId: "GREEN-WAVE", buildingId: TARGET.buildingId, flatLabel: TARGET.label, status: "occupied",
      ownershipType: "owner", residentUserId: null, residentId: null, updatedAt: time(1000)},
    profileExists: false,
  };
}

test("cleanup requires affirmative completed deletion and original owner allocation evidence", () => {
  assert.doesNotThrow(() => verifyEvidence(evidence()));
  for (const mutate of [
    (e) => {e.profileExists = true;},
    (e) => {e.request.status = "pending_review";},
    (e) => {e.request.completionVerified = false;},
    (e) => {e.request.processingBlockers = ["outstanding dues"];},
    (e) => {e.request.reconciliationReason = "unknown ownership";},
    (e) => {e.request.communityId = "OTHER";},
    (e) => {e.cleanup.memberships = [];},
    (e) => {e.profileStep.status = "deleting";},
    (e) => {e.authStep.verifiedAbsent = false;},
    (e) => {delete e.unit.ownershipType;},
    (e) => {e.unit.ownershipType = "tenant";},
    (e) => {e.unit.updatedAt = time(4000);},
    (e) => {e.unit.residentUserId = "active-resident";},
    (e) => {e.unit.residentIds = [TARGET.uid, "other-resident"];},
    (e) => {e.unit.reservedOnboardingId = "pending-registration";},
    (e) => {e.unit.status = "maintenance";},
  ]) {
    const e = evidence(); mutate(e);
    assert.throws(() => verifyEvidence(e));
  }
});

function fixture({reverseAssignment = false, authExists = false, changeBeforeRead = false} = {}) {
  const e = evidence();
  const requestPath = `accountDeletionRequests/${TARGET.requestId}`;
  const values = new Map([
    ["communities/GREEN-WAVE", e.community], [requestPath, e.request],
    [`${requestPath}/processing/membershipAndBookingCleanup`, e.cleanup],
    [`${requestPath}/processing/residentProfile`, e.profileStep], [`${requestPath}/processing/firebaseAuth`, e.authStep],
    [`flats/${TARGET.flatId}`, e.unit],
    [`buildings/${TARGET.buildingId}`, {communityId: "GREEN-WAVE", name: "Nova", occupied: 1, vacant: 0, reserved: 0}],
    ["payments/history", {flatId: TARGET.flatId, status: "paid"}],
  ]);
  const writes = []; let options;
  const snap = (path) => ({id: path.split("/").at(-1), exists: values.has(path), data: () => values.get(path)});
  const collection = (path, filters = []) => ({path, filters,
    doc: (id) => ({path: `${path}/${id}`, collection: (name) => collection(`${path}/${id}/${name}`)}),
    where: (field, op, value) => collection(path, [...filters, {field, value}]),
    limit() {return this;},
  });
  const db = {collection, async runTransaction(fn, config) {
    options = config;
    if (changeBeforeRead) e.unit.residentUserId = "new-resident";
    return fn({get: async (ref) => {
      if (!ref.filters) return snap(ref.path);
      const docs = [...values].filter(([path, row]) => path.startsWith(`${ref.path}/`) &&
        !path.slice(ref.path.length + 1).includes("/") && ref.filters.every(({field, value}) => row[field] === value))
        .map(([path]) => snap(path));
      if (reverseAssignment && ref.path === "users") docs.push({id: "other", data: () => ({flatId: TARGET.flatId})});
      return {docs, empty: docs.length === 0};
    }, update: (ref, patch) => {
      assert.notEqual(config.readOnly, true, "dry-run must not write");
      writes.push({path: ref.path, patch});
      values.set(ref.path, {...values.get(ref.path), ...patch});
    }});
  }};
  const auth = {async getUser() {if (authExists) return {uid: TARGET.uid}; throw Object.assign(Error("absent"), {code: "auth/user-not-found"});}};
  return {db, auth, values, writes, options: () => options};
}

test("default dry-run uses a read-only transaction and displays the proposed change without writes", async () => {
  const f = fixture(); const result = await inspectOrApply(f);
  assert.equal(result.affectedUnits, 1);
  assert.equal(result.label, "N016");
  assert.equal(result.countersAfter.occupied, 0);
  assert.equal(result.countersAfter.vacant, 1);
  assert.equal(result.writes, 0);
  assert.equal(f.options().readOnly, true);
  assert.deepEqual(f.writes, []);
});

test("explicit apply changes just unit status and building counters, and repetition writes nothing", async () => {
  const f = fixture();
  assert.equal((await inspectOrApply({...f, apply: true})).writes, 2);
  assert.deepEqual(f.writes.map((w) => w.path), [`flats/${TARGET.flatId}`, `buildings/${TARGET.buildingId}`]);
  assert.deepEqual(f.values.get("payments/history"), {flatId: TARGET.flatId, status: "paid"});
  assert.equal(f.values.get(`buildings/${TARGET.buildingId}`).name, "Nova");
  assert.equal((await inspectOrApply({...f, apply: true})).affectedUnits, 0);
  assert.equal(f.writes.length, 2);
});

test("reverse assignments, recreated Auth accounts, and reassignment at processing time prevent writes", async () => {
  for (const options of [{reverseAssignment: true}, {authExists: true}, {changeBeforeRead: true}]) {
    const f = fixture(options);
    await assert.rejects(inspectOrApply({...f, apply: true}));
    assert.deepEqual(f.writes, []);
  }
});
