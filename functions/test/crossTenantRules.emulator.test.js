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
    set("buildings", "building-a", {communityId: "community-a", name: "A"});
    set("buildings", "building-b", {communityId: "community-b", name: "B"});
    set("buildings", "building-off", {communityId: "community-off", name: "Off"});
    set("users", "resident-a", {uid: "resident-a", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-a"});
    set("users", "resident-b", {uid: "resident-b", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-b", buildingId: "building-b", flatId: "flat-b"});
    set("users", "resident-off", {uid: "resident-off", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-off", buildingId: "building-off", flatId: "flat-off"});
    set("users", "tenant-unverified", {uid: "tenant-unverified", role: "resident", residentType: "tenant", ownershipType: "tenant", identityVerified: false, identityVerificationStatus: "verification_required", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-tu"});
    set("users", "tenant-pending", {uid: "tenant-pending", role: "resident", residentType: "tenant", ownershipType: "tenant", identityVerified: false, identityVerificationStatus: "pending", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-tp"});
    set("users", "tenant-verified", {uid: "tenant-verified", role: "resident", residentType: "tenant", ownershipType: "tenant", identityVerified: true, identityVerificationStatus: "verified", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-tv"});
    set("users", "resident-inactive", {uid: "resident-inactive", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: false, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-ri"});
    set("users", "resident-pending", {uid: "resident-pending", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: false, approvalStatus: "pending", communityId: "community-a", buildingId: "building-a", flatId: "flat-rp"});
    set("users", "resident-mismatch", {uid: "resident-mismatch", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-mismatch"});
    set("users", "resident-review", {uid: "resident-review", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "verification_required", isActive: false, approvalStatus: "pending", communityId: "community-a"});
    set("flats", "flat-a", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "resident-a"});
    set("flats", "flat-b", {communityId: "community-b", buildingId: "building-b", status: "occupied", residentUserId: "resident-b"});
    set("flats", "flat-off", {communityId: "community-off", buildingId: "building-off", status: "occupied", residentUserId: "resident-off"});
    set("flats", "flat-tu", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "tenant-unverified"});
    set("flats", "flat-tp", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "tenant-pending"});
    set("flats", "flat-tv", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "tenant-verified"});
    set("flats", "flat-ri", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "resident-inactive"});
    set("flats", "flat-rp", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "resident-pending"});
    set("flats", "flat-mismatch", {communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "somebody-else"});
    set("bills", "bill-a", {communityId: "community-a", buildingId: "building-a", flatId: "flat-a", amount: 100});
    set("bills", "bill-tv", {communityId: "community-a", buildingId: "building-a", flatId: "flat-tv", amount: 150, userId: "tenant-verified"});
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

test("unverified, pending-proof, inactive, and pending residents cannot use operational data", {skip: !enabled}, async () => {
  await assertFails(dbFor("tenant-unverified").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("tenant-pending").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("resident-inactive").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("resident-pending").collection("bills").doc("bill-a").get());
  await assertSucceeds(dbFor("tenant-verified").collection("bills").doc("bill-tv").get());
});

test("restricted residents retain only their own profile access", {skip: !enabled}, async () => {
  await assertSucceeds(dbFor("tenant-unverified").collection("users").doc("tenant-unverified").get());
  await assertFails(dbFor("tenant-unverified").collection("users").doc("resident-a").get());
  await assertFails(dbFor("tenant-unverified").collection("users").doc("tenant-unverified").update({name: "Bypass"}));
  await assertFails(dbFor("tenant-unverified").collection("users").doc("tenant-unverified").collection("private").doc("bypass").set({value: true}));
});

test("Admin clients cannot forge resident type or identity verification", {skip: !enabled}, async () => {
  await assertFails(dbFor("admin-a").collection("users").doc("tenant-unverified").update({identityVerified: true, identityVerificationStatus: "verified"}));
  await assertFails(dbFor("admin-a").collection("users").doc("tenant-unverified").update({residentType: "owner", ownershipType: "owner"}));
});

test("Admin clients cannot bypass trusted occupancy transitions", {skip: !enabled}, async () => {
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({residentUserId: "tenant-verified"}));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({residentUid: null}));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({residentIds: ["tenant-verified"]}));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-review").update({approvalStatus: "approved", isActive: true, flatId: "flat-a"}));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-a").update({isActive: false, status: "inactive", occupancyStatus: "suspended"}));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-inactive").update({isActive: true, status: "active", occupancyStatus: "current"}));
  await assertFails(dbFor("admin-a").collection("flats").doc("forged-occupied").set({communityId: "community-a", buildingId: "building-a", residentUserId: "resident-review"}));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-review").update({approvalStatus: "rejected", isActive: false, rejectedAt: new Date(), rejectedBy: "admin-a", updatedAt: new Date()}));
  await assertFails(dbFor("admin-a").collection("users").doc("forged-resident").set({role: "resident", communityId: "community-a", approvalStatus: "pending", isActive: false}));
  await assertFails(dbFor("admin-a").collection("residentOnboarding").doc("forged-onboarding").set({communityId: "community-a", phoneNumber: "+639171100000", status: "pending_registration"}));
});
