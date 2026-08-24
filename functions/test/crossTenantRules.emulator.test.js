const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let environment;

test.before(async () => {
  if (!enabled) return;
  environment = await initializeTestEnvironment({
    projectId: "demo-hominode-security",
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
    set("communities", "community-a", {name: "A", isActive: true});
    set("communities", "community-b", {name: "B", isActive: true});
    set("communities", "community-off", {name: "Off", isActive: false});
    set("admins", "admin-a", {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["community-a"]});
    set("admins", "admin-b", {uid: "admin-b", role: "admin", isActive: true, authorizedCommunityIds: ["community-b"]});
    set("admins", "super", {uid: "super", role: "superAdmin", isActive: true});
    set("admins", "admin-off", {uid: "admin-off", role: "admin", isActive: true, authorizedCommunityIds: ["community-off"]});
    set("users", "resident-a", {uid: "resident-a", role: "resident", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-a"});
    set("users", "resident-b", {uid: "resident-b", role: "resident", isActive: true, approvalStatus: "approved", communityId: "community-b", buildingId: "building-b", flatId: "flat-b"});
    set("users", "resident-off", {uid: "resident-off", role: "resident", isActive: true, approvalStatus: "approved", communityId: "community-off", buildingId: "building-off", flatId: "flat-off"});
    set("bills", "bill-a", {communityId: "community-a", buildingId: "building-a", flatId: "flat-a", amount: 100});
    set("bills", "bill-b", {communityId: "community-b", buildingId: "building-b", flatId: "flat-b", amount: 200});
    set("visitors", "visitor-a", {communityId: "community-a", buildingId: "building-a", flatId: "flat-a", hostUserId: "resident-a"});
    await batch.commit();
  });
});

test.after(async () => {
  if (environment) await environment.cleanup();
});

function dbFor(uid) {
  return environment.authenticatedContext(uid).firestore();
}

test("ordinary admins remain confined to authorized active communities", {skip: !enabled}, async () => {
  await assertSucceeds(dbFor("admin-a").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("admin-a").collection("bills").doc("bill-b").get());
  await assertFails(dbFor("admin-b").collection("bills").doc("bill-a").update({amount: 1}));
  await assertFails(dbFor("admin-off").collection("bills").doc("missing").set({communityId: "community-off", amount: 1}));
});

test("residents cannot cross tenant or flat boundaries", {skip: !enabled}, async () => {
  await assertSucceeds(dbFor("resident-a").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("resident-a").collection("bills").doc("bill-b").get());
  await assertFails(dbFor("resident-b").collection("visitors").doc("visitor-a").get());
  await assertFails(dbFor("resident-a").collection("visitors").doc("visitor-a").update({communityId: "community-b"}));
});

test("resident ownership is required for writes", {skip: !enabled}, async () => {
  const ownVisitor = dbFor("resident-a").collection("visitors").doc("new-own");
  await assertSucceeds(ownVisitor.set({communityId: "community-a", buildingId: "building-a", flatId: "flat-a", hostUserId: "resident-a"}));
  await assertFails(dbFor("resident-a").collection("visitors").doc("new-forged").set({communityId: "community-a", buildingId: "building-a", flatId: "flat-a", hostUserId: "resident-b"}));
  await assertFails(dbFor("resident-a").collection("bills").doc("bill-a").update({amount: 0}));
  await assertSucceeds(dbFor("resident-a").collection("familyMembers").doc("family-a").set({communityId: "community-a", userId: "resident-a", name: "Member"}));
  await assertFails(dbFor("resident-b").collection("familyMembers").doc("family-forged").set({communityId: "community-a", userId: "resident-b", name: "Member"}));
});

test("superAdmin has registry access but no operational access", {skip: !enabled}, async () => {
  await assertSucceeds(dbFor("super").collection("communities").get());
  await assertSucceeds(dbFor("super").collection("admins").get());
  await assertFails(dbFor("super").collection("bills").doc("bill-a").get());
});

test("inactive communities fail closed", {skip: !enabled}, async () => {
  await assertFails(dbFor("resident-off").collection("events").where("communityId", "==", "community-off").get());
});
