const test = require("node:test");
const assert = require("node:assert/strict");
const {validateTenantMetadata, updateCommunityCore, setCommunityActiveCore} = require("../src/tenant_management");

const auth = {uid: "super-1", token: {phone_number: "+15550000001", firebase: {sign_in_provider: "phone"}}};

function fakeDb(seed) {
  const values = new Map(Object.entries(seed));
  const snapshot = (path) => ({id: path.split("/").pop(), exists: values.has(path), data: () => values.get(path)});
  const doc = (name, id) => ({path: `${name}/${id}`, get: async () => snapshot(`${name}/${id}`), update: async (changes) => values.set(`${name}/${id}`, {...values.get(`${name}/${id}`), ...changes})});
  return {values, collection: (name) => ({doc: (id) => doc(name, id), where: (field, _op, expected) => ({limit: () => ({get: async () => ({docs: [...values.entries()].filter(([path, data]) => path.startsWith(`${name}/`) && data[field] === expected).map(([path]) => snapshot(path))})})})}), runTransaction: async (callback) => callback({get: async (ref) => snapshot(ref.path), set: (ref, data) => values.set(ref.path, data), update: (ref, changes) => values.set(ref.path, {...values.get(ref.path), ...changes}), delete: (ref) => values.delete(ref.path)})};
}

const superSeed = {"admins/super-1": {uid: "super-1", role: "superAdmin", isActive: true}, "communities/GV": {name: "Green Valley", slug: "green-valley", websitePath: "green-valley", isActive: true}};

test("tenant validation normalizes defaults and rejects non-canonical slug", () => {
  const result = validateTenantMetadata({name: "Green Valley", slug: "green-valley"});
  assert.equal(result.websitePath, "green-valley");
  assert.equal(result.databaseId, "(default)");
  assert.throws(() => validateTenantMetadata({name: "Green Valley", slug: "Green Valley"}), {code: "invalid-argument"});
});

test("duplicate slug and websitePath are rejected", async () => {
  const db = fakeDb({...superSeed, "communities/OTHER": {slug: "taken", websitePath: "taken-path"}});
  await assert.rejects(updateCommunityCore({db, auth, data: {communityId: "GV", name: "Green Valley", slug: "taken", websitePath: "new-path"}}), {code: "already-exists"});
  await assert.rejects(updateCommunityCore({db, auth, data: {communityId: "GV", name: "Green Valley", slug: "new-slug", websitePath: "taken-path"}}), {code: "already-exists"});
});

test("superAdmin edits metadata and changes active status", async () => {
  const db = fakeDb(superSeed);
  await updateCommunityCore({db, auth, data: {communityId: "GV", name: "Green Valley Prime", slug: "green-valley-prime", websitePath: "green-valley-prime", databaseId: "(default)", brandName: "GV Prime"}});
  assert.equal(db.values.get("communities/GV").name, "Green Valley Prime");
  assert.equal(db.values.get("communities/GV").brandName, "GV Prime");
  await setCommunityActiveCore({db, auth, data: {communityId: "GV", isActive: false}});
  assert.equal(db.values.get("communities/GV").isActive, false);
  await setCommunityActiveCore({db, auth, data: {communityId: "GV", isActive: true}});
  assert.equal(db.values.get("communities/GV").isActive, true);
});

test("ordinary admin cannot mutate tenant registry", async () => {
  const db = fakeDb({...superSeed, "admins/super-1": {uid: "super-1", role: "admin", isActive: true}});
  await assert.rejects(setCommunityActiveCore({db, auth, data: {communityId: "GV", isActive: false}}), {code: "permission-denied"});
});
