const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {assertFails, assertSucceeds, initializeTestEnvironment} = require("@firebase/rules-unit-testing");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let environment;
const config = {
  communityId: "C",
  version: 1,
  directUpi: {enabled: true, vpa: "association@upi", payeeName: "Community Association"},
  updatedBy: "admin-c",
};

test.before(async () => {
  if (!enabled) return;
  environment = await initializeTestEnvironment({
    projectId: "demo-hominode-finance",
    firestore: {
      host: "127.0.0.1",
      port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").pop()),
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = db.batch();
    const set = (collection, id, data) => batch.set(db.collection(collection).doc(id), data);
    set("communities", "C", {isActive: true});
    set("communities", "B", {isActive: true});
    set("admins", "admin-c", {uid: "admin-c", role: "admin", isActive: true, authorizedCommunityIds: ["C"]});
    set("admins", "admin-b", {uid: "admin-b", role: "admin", isActive: true, authorizedCommunityIds: ["B"]});
    set("admins", "super", {uid: "super", role: "superAdmin", isActive: true});
    set("securityStaff", "security-c", {uid: "security-c", role: "security", isActive: true, communityId: "C"});
    set("users", "resident-c", {uid: "resident-c", role: "resident", residentType: "owner", isActive: true, approvalStatus: "approved", communityId: "C"});
    set("users", "resident-b", {uid: "resident-b", role: "resident", residentType: "owner", isActive: true, approvalStatus: "approved", communityId: "B"});
    set("communityPaymentConfigs", "C", config);
    await batch.commit();
  });
});

test.after(async () => {
  if (environment) await environment.cleanup();
});

const dbFor = (uid, claims = {}) => environment.authenticatedContext(uid, claims).firestore();
const run = (name, callback) => test(name, {skip: !enabled}, callback);

run("community payment config get access is limited to authorized community users and Super Admin", async () => {
  for (const uid of ["resident-c", "admin-c", "super"]) {
    const snapshot = await assertSucceeds(dbFor(uid).doc("communityPaymentConfigs/C").get());
    assert.deepEqual(snapshot.data().directUpi, config.directUpi);
  }
  for (const uid of ["resident-b", "admin-b", "security-c", "phone-only"]) {
    await assertFails(dbFor(uid, {firebase: {sign_in_provider: "phone"}}).doc("communityPaymentConfigs/C").get());
  }
  await assertFails(dbFor("admin-c").collection("communityPaymentConfigs").get());
});

run("residents and Admins cannot create, update, or delete community payment config", async () => {
  const target = "communityPaymentConfigs/C";
  for (const uid of ["resident-c", "admin-c"]) {
    const db = dbFor(uid);
    await assertFails(db.doc("communityPaymentConfigs/new").set({...config, communityId: "new"}));
    await assertFails(db.doc(target).update({directUpi: {enabled: false}}));
    await assertFails(db.doc(target).delete());
  }
});
