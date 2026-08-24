const test = require("node:test");
const assert = require("node:assert/strict");
const {validateCreateAdminInput, createAdminCore, updateAdminAssignmentsCore, setAdminActiveCore} = require("../src/admin_management");

const auth = {uid: "super-1", token: {phone_number: "+15550000001", firebase: {sign_in_provider: "phone"}}};
function fakeDb(seed) {
  const values = new Map(Object.entries(seed));
  const snapshot = (path) => ({id: path.split("/").pop(), exists: values.has(path), data: () => values.get(path)});
  return {values, collection: (name) => ({doc: (id) => ({path: `${name}/${id}`, get: async () => snapshot(`${name}/${id}`), create: async (data) => {if (values.has(`${name}/${id}`)) throw new Error("exists"); values.set(`${name}/${id}`, data);}, update: async (data) => values.set(`${name}/${id}`, {...values.get(`${name}/${id}`), ...data})})})};
}
function fakeAuthAdmin(existing) {
  return {deleted: [], getUserByPhoneNumber: async () => {if (existing) return existing; throw Object.assign(new Error("missing"), {code: "auth/user-not-found"});}, createUser: async ({phoneNumber}) => ({uid: "new-admin", phoneNumber}), deleteUser: async function(uid) {this.deleted.push(uid);}};
}
const seed = {"admins/super-1": {uid: "super-1", role: "superAdmin", isActive: true}, "communities/A": {name: "Alpha", isActive: true}, "communities/B": {name: "Beta", isActive: true}, "communities/OFF": {name: "Off", isActive: false}};

test("create admin defaults role server-side and supports multiple assignments", async () => {
  const db = fakeDb(seed);
  const result = await createAdminCore({db, auth, authAdmin: fakeAuthAdmin(), data: {phoneNumber: "+15550000002", authorizedCommunityIds: ["A", "B"]}});
  assert.deepEqual(result, {uid: "new-admin", role: "admin"});
  const profile = db.values.get("admins/new-admin");
  assert.equal(profile.role, "admin");
  assert.equal(profile.isActive, true);
  assert.deepEqual(profile.authorizedCommunityIds, ["A", "B"]);
});

test("client cannot request superAdmin role", () => {
  assert.throws(() => validateCreateAdminInput({phoneNumber: "+15550000002", authorizedCommunityIds: ["A"], role: "superAdmin"}), {code: "invalid-argument"});
});

test("invalid, inactive, and duplicate communities are rejected", async () => {
  assert.throws(() => validateCreateAdminInput({phoneNumber: "+15550000002", authorizedCommunityIds: ["A", "A"]}), {code: "invalid-argument"});
  const db = fakeDb(seed);
  await assert.rejects(createAdminCore({db, auth, authAdmin: fakeAuthAdmin(), data: {phoneNumber: "+15550000002", authorizedCommunityIds: ["MISSING"]}}), {code: "failed-precondition"});
  await assert.rejects(createAdminCore({db, auth, authAdmin: fakeAuthAdmin(), data: {phoneNumber: "+15550000002", authorizedCommunityIds: ["OFF"]}}), {code: "failed-precondition"});
});

test("assignments and active state update only ordinary admins", async () => {
  const db = fakeDb({...seed, "admins/admin-1": {uid: "admin-1", phoneNumber: "+15550000002", role: "admin", isActive: true, authorizedCommunityIds: ["A"]}});
  await updateAdminAssignmentsCore({db, auth, data: {uid: "admin-1", authorizedCommunityIds: ["A", "B"]}});
  assert.deepEqual(db.values.get("admins/admin-1").authorizedCommunityIds, ["A", "B"]);
  await setAdminActiveCore({db, auth, data: {uid: "admin-1", isActive: false}});
  assert.equal(db.values.get("admins/admin-1").isActive, false);
  await setAdminActiveCore({db, auth, data: {uid: "admin-1", isActive: true}});
  assert.equal(db.values.get("admins/admin-1").isActive, true);
  await assert.rejects(setAdminActiveCore({db, auth, data: {uid: "super-1", isActive: false}}), {code: "permission-denied"});
});

test("ordinary admin cannot modify its own assignments", async () => {
  const db = fakeDb({...seed, "admins/admin-1": {uid: "admin-1", role: "admin", isActive: true, authorizedCommunityIds: ["A"]}});
  const ordinaryAuth = {uid: "admin-1", token: {phone_number: "+15550000002", firebase: {sign_in_provider: "phone"}}};
  await assert.rejects(updateAdminAssignmentsCore({db, auth: ordinaryAuth, data: {uid: "admin-1", authorizedCommunityIds: ["B"]}}), {code: "permission-denied"});
});
