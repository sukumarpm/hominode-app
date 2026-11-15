const test = require("node:test");
const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {join} = require("node:path");
const {randomUUID} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {createAdminResidentCore, rejectResidentRegistrationCore, reviewResidentIdentityProofCore,
  submitResidentIdentityProofCore} = require("../src/resident_identity");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = "demo-hominode-registration";
let app, db, environment;
const phoneNumber = "+639171234567";
const auth = (uid) => ({uid, token: {phone_number: phoneNumber, firebase: {sign_in_provider: "phone"}}});
const suite = (name, fn) => test(name, {skip: !enabled}, fn);

test.before(async () => {
  if (!enabled) return;
  app = initializeApp({projectId}, "admin-registration-rejection");
  db = getFirestore(app);
  environment = await initializeTestEnvironment({projectId, firestore: {
    host: "127.0.0.1", port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").pop()),
    rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8"),
  }});
});
test.after(async () => {
  if (environment) await environment.cleanup();
  if (app) await deleteApp(app);
});

async function fixture({legacy = false} = {}) {
  const id = randomUUID();
  const communityId = `community-${id}`, uid = `resident-${id}`, adminId = `admin-${id}`;
  const buildingId = `nova-${id}`, flatId = `n016-${id}`;
  const userRef = db.collection("users").doc(uid), flatRef = db.collection("flats").doc(flatId);
  const buildingRef = db.collection("buildings").doc(buildingId);
  await db.collection("communities").doc(communityId).set({isActive: true});
  await db.collection("admins").doc(adminId).set({uid: adminId, role: "admin", phoneNumber,
    isActive: true, authorizedCommunityIds: [communityId]});
  await buildingRef.set({communityId, name: "Nova", totalFlats: 1, occupied: 0, vacant: 1});
  await flatRef.set({communityId, buildingId, flatLabel: "N016", status: "vacant"});
  // Reuse a stub Auth identity; no test or production Auth accounts are created.
  const authAdmin = {getUserByPhoneNumber: async () => ({uid, phoneNumber, disabled: false}),
    createUser: async () => {throw Error("Existing Auth identity must be reused");},
    deleteUser: async () => {throw Error("Final rejection must retain Auth");}};
  await createAdminResidentCore({db, authAdmin, auth: auth(adminId), data: {
    communityId, residentName: "Synthetic pending registration", phoneNumber, residentType: "tenant",
    familyMembers: 1, buildingId, flatId,
  }});
  assert.equal((await userRef.get()).data().approvalStatus, "pending");
  if (legacy) await userRef.update({approvalStatus: "approved", isActive: true, status: "active"});
  await userRef.update({identityVerificationStatus: "pending",
    identityProofStoragePath: `residentIdentityProofs/${communityId}/${uid}/proof.png`});
  return {communityId, uid, adminId, buildingId, flatId, userRef, flatRef, buildingRef,
    reject: () => rejectResidentRegistrationCore({db, auth: auth(adminId), data: {communityId, userId: uid}}),
    review: (decision) => reviewResidentIdentityProofCore({db, auth: auth(adminId), data: {communityId, userId: uid, decision}})};
}

suite("Admin-created new/legacy N016 fixtures release atomically, preserve history/Auth/profile, and repeat safely", async () => {
  for (const legacy of [false, true]) {
    const f = await fixture({legacy});
    const history = {communityId: f.communityId, residentId: f.uid, flatId: f.flatId,
      buildingId: f.buildingId, amount: 100, month: 10, year: 2026, status: "paid", paidAt: Timestamp.fromMillis(1)};
    const bill = db.collection("bills").doc(randomUUID());
    await bill.set(history);
    assert.equal((await f.reject()).status, "rejected");
    const user = (await f.userRef.get()).data(), flat = (await f.flatRef.get()).data();
    const building = (await f.buildingRef.get()).data();
    assert.equal(user.approvalStatus, "rejected");
    assert.equal(user.isActive, false);
    assert.equal(user.flatId, undefined);
    assert.equal(flat.status, "vacant");
    assert.equal(flat.residentUserId, null);
    assert.equal(building.occupied, 0);
    assert.equal(building.vacant, 1);
    assert.deepEqual((await bill.get()).data(), history);
    await f.flatRef.update({status: "occupied", residentUserId: "new-occupant"});
    assert.equal((await f.reject()).idempotent, true);
    assert.equal((await f.flatRef.get()).data().residentUserId, "new-occupant");
  }
});

suite("Proof rejection retains allocation and resubmission; verification completes approval and blocks final rejection", async () => {
  const f = await fixture();
  await f.review("rejected");
  assert.equal((await f.userRef.get()).data().approvalStatus, "pending");
  assert.equal((await f.flatRef.get()).data().status, "occupied");
  await submitResidentIdentityProofCore({db, auth: auth(f.uid),
    bucket: {file: () => ({save: async () => {}, delete: async () => {}})}, data: {
      contentType: "image/png", base64: Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,1]).toString("base64"),
    }});
  await f.review("verified");
  const user = (await f.userRef.get()).data();
  assert.equal(user.approvalStatus, "approved");
  assert.equal(user.isActive, true);
  assert.ok(user.registrationCompletedAt);
  await assert.rejects(f.reject(), {code: "failed-precondition"});
  assert.equal((await f.flatRef.get()).data().status, "occupied");
});

suite("Shared occupants and reassigned units survive final rejection", async () => {
  for (const shared of [false, true]) {
    const f = await fixture();
    await f.flatRef.update(shared
      ? {residentIds: [f.uid, "other-occupant"], residentUid: "other-occupant"}
      : {residentUserId: "other-occupant"});
    await f.reject();
    const flat = (await f.flatRef.get()).data();
    assert.equal(flat.status, "occupied");
    assert.equal((await f.buildingRef.get()).data().occupied, 1);
    if (shared) {
      assert.equal(flat.residentUserId, null);
      assert.deepEqual(flat.residentIds, ["other-occupant"]);
      assert.equal(flat.residentUid, "other-occupant");
    } else assert.equal(flat.residentUserId, "other-occupant");
  }
});

suite("Financial blockers and cross-community attempts leave registration and unit unchanged", async () => {
  const f = await fixture({legacy: true});
  await db.collection("bills").doc(randomUUID()).set({communityId: f.communityId,
    residentId: f.uid, flatId: f.flatId, amount: 100, month: 10, year: 2026, status: "pending"});
  await assert.rejects(f.reject(), {code: "failed-precondition"});
  await assert.rejects(rejectResidentRegistrationCore({db, auth: auth(f.adminId),
    data: {communityId: "another-community", userId: f.uid}}), {code: "permission-denied"});
  assert.equal((await f.userRef.get()).data().approvalStatus, "approved");
  assert.equal((await f.flatRef.get()).data().status, "occupied");
});

suite("Concurrent verification/final rejection commits only one final state", async () => {
  const f = await fixture();
  const outcomes = await Promise.allSettled([f.review("verified"), f.reject()]);
  assert.equal(outcomes.filter((outcome) => outcome.status === "fulfilled").length, 1);
  const user = (await f.userRef.get()).data(), flat = (await f.flatRef.get()).data();
  if (user.approvalStatus === "approved") {
    assert.equal(user.identityVerified, true);
    assert.equal(flat.status, "occupied");
    assert.equal(flat.residentUserId, f.uid);
  } else {
    assert.equal(user.approvalStatus, "rejected");
    assert.equal(user.isActive, false);
    assert.equal(flat.status, "vacant");
  }
});

suite("Completion marker is server-owned for both Admin and Resident clients", async () => {
  const f = await fixture();
  await f.review("verified");
  for (const uid of [f.adminId, f.uid]) {
    const client = environment.authenticatedContext(uid, auth(uid).token).firestore();
    await assertSucceeds(client.collection("users").doc(f.uid).get());
    await assertFails(client.collection("users").doc(f.uid).update({registrationCompletedAt: null}));
    await assertFails(client.collection("users").doc(f.uid).update({registrationCompletedAt: new Date()}));
  }
});
