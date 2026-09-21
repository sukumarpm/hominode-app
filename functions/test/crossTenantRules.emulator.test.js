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
    set("communities", "community-a", { name: "A", isActive: true });
    set("communities", "community-b", { name: "B", isActive: true });
    set("communities", "community-off", { name: "Off", isActive: false });
    set("admins", "admin-a", { uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["community-a"] });
    set("admins", "admin-b", { uid: "admin-b", role: "admin", isActive: true, authorizedCommunityIds: ["community-b"] });
    set("admins", "super", { uid: "super", role: "superAdmin", isActive: true });
    set("admins", "admin-off", { uid: "admin-off", role: "admin", isActive: true, authorizedCommunityIds: ["community-off"] });
    set("securityStaff", "security-a", { uid: "security-a", role: "security", isActive: true, communityId: "community-a", gateId: "gate-a" });
    set("buildings", "building-a", { communityId: "community-a", name: "A", buildingName: "A", floors: 5, flatsPerFloor: 4, totalFlats: 20, occupied: 1, vacant: 19, occupancyRate: 5 });
    set("buildings", "building-b", { communityId: "community-b", name: "B", buildingName: "B", floors: 3, flatsPerFloor: 4, totalFlats: 12, occupied: 1, vacant: 11, occupancyRate: 8 });
    set("buildings", "building-off", { communityId: "community-off", name: "Off", buildingName: "Off", floors: 1, flatsPerFloor: 1, totalFlats: 1, occupied: 1, vacant: 0, occupancyRate: 100 });
    set("users", "resident-a", { uid: "resident-a", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-a" });
    set("users", "resident-b", { uid: "resident-b", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-b", buildingId: "building-b", flatId: "flat-b" });
    set("users", "resident-off", { uid: "resident-off", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-off", buildingId: "building-off", flatId: "flat-off" });
    set("users", "tenant-unverified", { uid: "tenant-unverified", role: "resident", residentType: "tenant", ownershipType: "tenant", identityVerified: false, identityVerificationStatus: "verification_required", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-tu" });
    set("users", "tenant-pending", { uid: "tenant-pending", role: "resident", residentType: "tenant", ownershipType: "tenant", identityVerified: false, identityVerificationStatus: "pending", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-tp" });
    set("users", "tenant-verified", { uid: "tenant-verified", role: "resident", residentType: "tenant", ownershipType: "tenant", identityVerified: true, identityVerificationStatus: "verified", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-tv" });
    set("users", "resident-inactive", { uid: "resident-inactive", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: false, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-ri" });
    set("users", "resident-pending", { uid: "resident-pending", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: false, approvalStatus: "pending", communityId: "community-a", buildingId: "building-a", flatId: "flat-rp" });
    set("users", "resident-mismatch", { uid: "resident-mismatch", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "not_required", isActive: true, approvalStatus: "approved", communityId: "community-a", buildingId: "building-a", flatId: "flat-mismatch" });
    set("users", "resident-review", { uid: "resident-review", role: "resident", residentType: "owner", ownershipType: "owner", identityVerified: false, identityVerificationStatus: "verification_required", isActive: false, approvalStatus: "pending", communityId: "community-a" });
    set("flats", "flat-a", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "resident-a" });
    set("flats", "flat-b", { communityId: "community-b", buildingId: "building-b", status: "occupied", residentUserId: "resident-b" });
    set("flats", "flat-off", { communityId: "community-off", buildingId: "building-off", status: "occupied", residentUserId: "resident-off" });
    set("flats", "flat-tu", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "tenant-unverified" });
    set("flats", "flat-tp", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "tenant-pending" });
    set("flats", "flat-tv", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "tenant-verified" });
    set("flats", "flat-ri", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "resident-inactive" });
    set("flats", "flat-rp", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "resident-pending" });
    set("flats", "flat-mismatch", { communityId: "community-a", buildingId: "building-a", status: "occupied", residentUserId: "somebody-else" });
    set("bills", "bill-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", amount: 100, status: "pending" });
    set("bills", "bill-tv", { communityId: "community-a", buildingId: "building-a", flatId: "flat-tv", amount: 150, userId: "tenant-verified" });
    set("bills", "bill-b", { communityId: "community-b", buildingId: "building-b", flatId: "flat-b", amount: 200 });
    set("visitors", "visitor-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", hostUserId: "resident-a", visitorName: "Guest A", purpose: "Visit", status: "expected", isApproved: false, approvedBy: null, approvedAt: null, actualArrival: null, departure: null });
    set("visitors", "visitor-approved-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", hostUserId: "resident-a", visitorName: "Approved Guest", purpose: "Visit", status: "approved", isApproved: true, approvedBy: "admin-a", approvedAt: new Date(), actualArrival: null, departure: null });
    set("visitors", "visitor-b", { communityId: "community-b", buildingId: "building-b", flatId: "flat-b", hostUserId: "resident-b", visitorName: "Guest B", purpose: "Visit", status: "expected", isApproved: false, approvedBy: null, approvedAt: null, actualArrival: null, departure: null });
    set("complaints", "complaint-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", userId: "resident-a", residentId: "resident-a", title: "Own complaint", status: "pending" });
    set("complaints", "complaint-tv", { communityId: "community-a", buildingId: "building-a", flatId: "flat-tv", userId: "tenant-verified", residentId: "tenant-verified", title: "Other resident complaint", status: "pending" });
    set("complaints", "complaint-b", { communityId: "community-b", buildingId: "building-b", flatId: "flat-b", userId: "resident-b", residentId: "resident-b", title: "Community B complaint", status: "pending" });
    set("complaints", "complaint-missing-community", { buildingId: "building-a", flatId: "flat-a", userId: "resident-a", residentId: "resident-a", title: "Missing tenant", status: "pending" });
    set("complaints", "complaint-conflicting-owner", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", userId: "tenant-verified", residentId: "resident-a", title: "Conflicting owner", status: "pending" });
    set("notices", "notice-global-a", { communityId: "community-a", targetFlats: [], title: "Community A", status: "published" });
    set("notices", "notice-legacy-global-a", { communityId: "community-a", title: "Legacy Community A", status: "published" });
    set("notices", "notice-flat-a", { communityId: "community-a", targetFlats: ["flat-a"], title: "Flat A", status: "published" });
    set("notices", "notice-flat-tv", { communityId: "community-a", targetFlats: ["flat-tv"], title: "Flat TV", status: "published" });
    set("notices", "notice-global-b", { communityId: "community-b", targetFlats: [], title: "Community B", status: "published" });
    set("notices", "notice-draft-a", { communityId: "community-a", targetFlats: [], title: "Draft", status: "draft", isActive: false });
    set("notices", "notice-expired-a", { communityId: "community-a", targetFlats: [], title: "Expired", status: "published", expiryDate: new Date("2020-01-01T00:00:00Z") });
    set("gates", "gate-a", { communityId: "community-a", gateName: "Gate A", workingStatus: "active" });
    set("gates", "gate-b", { communityId: "community-b", gateName: "Gate B", workingStatus: "active" });
    set("amenities", "amenity-a", { communityId: "community-a", buildingId: "building-a", name: "Clubhouse", isActive: true });
    set("bookings", "booking-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", userId: "resident-a", status: "confirmed" });
    set("amenityBookings", "amenity-booking-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", userId: "resident-a", status: "confirmed" });
    set("amenity_bookings", "legacy-amenity-booking-a", { communityId: "community-a", buildingId: "building-a", flatId: "flat-a", userId: "resident-a", status: "confirmed" });
    set("notifications", "notification-a", { communityId: "community-a", recipientId: "resident-a", audience: "resident", role: "resident", appId: "resident", title: "Private A", message: "Resident A only", type: "general", priority: "medium", isRead: false, createdAt: new Date(), updatedAt: new Date() });
    set("notifications", "notification-b", { communityId: "community-b", recipientId: "resident-b", audience: "resident", role: "resident", appId: "resident", title: "Private B", message: "Resident B only", type: "payment", priority: "high", isRead: false, createdAt: new Date(), updatedAt: new Date() });
    set("notifications", "notification-admin-a", { communityId: "community-a", recipientId: "admin-a", audience: "admin", role: "admin", appId: "admin", title: "Admin A", message: "Admin A only", type: "general", priority: "medium", isRead: false, createdAt: new Date(), updatedAt: new Date() });
    set("notifications", "notification-security-a", { communityId: "community-a", recipientId: "security-a", audience: "security", role: "security", appId: "security", title: "Security A", message: "Security A only", type: "security", priority: "high", isRead: false, createdAt: new Date(), updatedAt: new Date() });
    set("auditLogs", "audit-a", { actorUid: "admin-a", actorRole: "admin", communityId: "community-a", action: "resident.approve", targetType: "resident", targetId: "resident-a", timestamp: new Date(), summary: "Resident registration approved." });
    await batch.commit();
  });
});

test.after(async () => {
  if (environment) await environment.cleanup();
});

function dbFor(uid) {
  return environment.authenticatedContext(uid).firestore();
}

test("ordinary admins remain confined to authorized active communities", { skip: !enabled }, async () => {
  await assertSucceeds(dbFor("admin-a").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("admin-a").collection("bills").doc("bill-b").get());
  await assertFails(dbFor("admin-b").collection("bills").doc("bill-a").update({ amount: 1 }));
  await assertFails(dbFor("admin-off").collection("bills").doc("missing").set({ communityId: "community-off", amount: 1 }));
});

test("residents cannot cross tenant or flat boundaries", { skip: !enabled }, async () => {
  await assertSucceeds(dbFor("resident-a").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("resident-a").collection("bills").doc("bill-b").get());
  await assertFails(dbFor("resident-b").collection("visitors").doc("visitor-a").get());
  await assertFails(dbFor("resident-a").collection("visitors").doc("visitor-a").update({ communityId: "community-b" }));
});

test("resident ownership is required for writes", { skip: !enabled }, async () => {
  const ownVisitor = dbFor("resident-a").collection("visitors").doc("new-own");
  const expectedVisitor = {
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-a",
    hostUserId: "resident-a",
    visitorName: "Guest",
    status: "expected",
    isApproved: false,
    approvedBy: null,
    approvedAt: null,
    actualArrival: null,
    departure: null,
  };
  await assertSucceeds(ownVisitor.set(expectedVisitor));
  await assertFails(dbFor("resident-a").collection("visitors").doc("new-forged").set({ ...expectedVisitor, hostUserId: "resident-b" }));
  await assertFails(dbFor("resident-a").collection("bills").doc("bill-a").update({ amount: 0 }));
  await assertSucceeds(dbFor("resident-a").collection("familyMembers").doc("family-a").set({ communityId: "community-a", userId: "resident-a", name: "Member" }));
  await assertFails(dbFor("resident-b").collection("familyMembers").doc("family-forged").set({ communityId: "community-a", userId: "resident-b", name: "Member" }));
});

test("verified tenant can create own expected visitor", { skip: !enabled }, async () => {
  const visitor = dbFor("tenant-verified")
    .collection("visitors")
    .doc("tenant-own-visitor");

  await assertSucceeds(visitor.set({
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-tv",
    hostUserId: "tenant-verified",
    visitorName: "Tenant Guest",
    purpose: "Visit",
    status: "expected",
    isApproved: false,
    approvedBy: null,
    approvedAt: null,
    actualArrival: null,
    departure: null,
  }));
});

test("resident payments and amenity bookings are read-only for V1", { skip: !enabled }, async () => {
  const resident = dbFor("resident-a");
  await assertSucceeds(resident.collection("bills").doc("bill-a").get());
  await assertFails(resident.collection("bills").doc("bill-a").update({
    status: "paid",
    paidAt: new Date(),
    paymentMethod: "UPI",
    transactionId: "MOCK-UPI-forged",
    paymentMode: "mock",
  }));

  const bookingCollections = ["bookings", "amenityBookings", "amenity_bookings"];
  const existingIds = ["booking-a", "amenity-booking-a", "legacy-amenity-booking-a"];
  for (let index = 0; index < bookingCollections.length; index += 1) {
    const collection = resident.collection(bookingCollections[index]);
    await assertSucceeds(collection.doc(existingIds[index]).get());
    await assertFails(collection.doc(`resident-created-${index}`).set({
      communityId: "community-a",
      buildingId: "building-a",
      flatId: "flat-a",
      userId: "resident-a",
      status: "pending",
    }));
    await assertFails(collection.doc(existingIds[index]).update({ status: "cancelled" }));
    await assertFails(collection.doc(existingIds[index]).delete());
  }

  await assertSucceeds(dbFor("admin-a").collection("bills").doc("bill-a").update({
    status: "paid",
    paidAt: new Date(),
    paymentMethod: "Cash",
    transactionId: "ADMIN-RECORDED",
  }));
  await assertSucceeds(dbFor("admin-a").collection("amenityBookings").doc("admin-created-booking").set({
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-a",
    userId: "resident-a",
    status: "confirmed",
  }));
});

test("building edits preserve structural fields after creation", { skip: !enabled }, async () => {
  const building = dbFor("admin-a").collection("buildings").doc("building-a");
  await assertSucceeds(building.update({ name: "Tower A", buildingName: "Tower A" }));
  await assertSucceeds(building.update({ occupied: 2, vacant: 18, occupancyRate: 10 }));
  await assertFails(building.update({ floors: 6 }));
  await assertFails(building.update({ flatsPerFloor: 5 }));
  await assertFails(building.update({ totalFlats: 25 }));
  await assertFails(dbFor("admin-b").collection("buildings").doc("building-a").update({ name: "Forged" }));
});

test("visitor approval and gate state remain Admin/Security-only", { skip: !enabled }, async () => {
  const residentVisitor = dbFor("resident-a").collection("visitors").doc("visitor-a");
  await assertSucceeds(residentVisitor.update({ visitorName: "Updated guest" }));
  await assertFails(residentVisitor.update({ status: "inside" }));
  await assertFails(residentVisitor.update({ isApproved: true }));
  await assertFails(residentVisitor.update({ approvedAt: new Date() }));
  await assertFails(residentVisitor.update({ rejectedAt: new Date() }));
  await assertFails(residentVisitor.update({ actualArrival: new Date() }));
  await assertFails(residentVisitor.update({ departure: new Date() }));
  await assertFails(residentVisitor.update({ hostUserId: "tenant-verified" }));
  await assertFails(residentVisitor.update({ communityId: "community-b" }));
  await assertFails(residentVisitor.update({ buildingId: "building-b" }));
  await assertFails(residentVisitor.update({ flatId: "flat-tv" }));
  await assertSucceeds(dbFor("resident-a").collection("visitors").doc("resident-cancelled").set({
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-a",
    hostUserId: "resident-a",
    visitorName: "Cancelled guest",
    status: "expected",
    isApproved: false,
    approvedBy: null,
    approvedAt: null,
    actualArrival: null,
    departure: null,
  }));
  await assertSucceeds(dbFor("resident-a").collection("visitors").doc("resident-cancelled").delete());
  await assertFails(dbFor("resident-a").collection("visitors").doc("visitor-approved-a").delete());
  await assertFails(dbFor("resident-a").collection("visitors").doc("self-approved").set({
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-a",
    hostUserId: "resident-a",
    status: "expected",
    isApproved: true,
    approvedBy: "resident-a",
    approvedAt: new Date(),
    actualArrival: null,
    departure: null,
  }));

  await assertSucceeds(dbFor("admin-a").collection("visitors").doc("visitor-a").update({
    isApproved: true,
    approvedAt: new Date(),
  }));
  await assertFails(dbFor("admin-a").collection("visitors").doc("visitor-a").update({ hostUserId: "tenant-verified" }));
  await assertSucceeds(dbFor("security-a").collection("visitors").doc("visitor-a").update({
    status: "inside",
    actualArrival: new Date(),
  }));
  await assertFails(dbFor("security-a").collection("visitors").doc("visitor-a").update({ flatId: "flat-tv" }));
  await assertFails(dbFor("admin-a").collection("visitors").doc("visitor-b").update({ isApproved: true }));
  await assertFails(dbFor("security-a").collection("visitors").doc("visitor-b").update({ status: "inside" }));
});

test("complaints are resident-owner-only and Admin tenant-scoped", { skip: !enabled }, async () => {
  const complaints = dbFor("resident-a").collection("complaints");
  await assertSucceeds(complaints.doc("complaint-a").get());
  await assertFails(complaints.doc("complaint-tv").get());
  await assertFails(complaints.doc("complaint-b").get());
  await assertFails(complaints.doc("complaint-missing-community").get());
  await assertFails(complaints.doc("complaint-conflicting-owner").get());
  await assertSucceeds(
    complaints
      .where("communityId", "==", "community-a")
      .where("userId", "==", "resident-a")
      .get(),
  );
  await assertFails(complaints.where("userId", "==", "resident-a").get());
  await assertFails(complaints.where("communityId", "==", "community-a").get());
  await assertSucceeds(complaints.doc("resident-created").set({
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-a",
    userId: "resident-a",
    residentId: "resident-a",
    title: "Created by resident",
    status: "pending",
  }));
  await assertFails(complaints.doc("forged-flat").set({
    communityId: "community-a",
    buildingId: "building-a",
    flatId: "flat-tv",
    userId: "resident-a",
    residentId: "resident-a",
    title: "Forged flat",
    status: "pending",
  }));
  await assertSucceeds(complaints.doc("complaint-a").update({
    imageUrl: "https://example.invalid/own-image",
    imageUploadedBy: "resident-a",
    updatedAt: new Date(),
  }));
  await assertFails(complaints.doc("complaint-a").update({ status: "resolved" }));
  await assertFails(complaints.doc("complaint-a").update({ description: "tampered" }));
  await assertSucceeds(dbFor("admin-a").collection("complaints").doc("complaint-a").update({ status: "inProgress" }));
  await assertFails(dbFor("admin-a").collection("complaints").doc("complaint-a").update({ residentId: "tenant-verified" }));
  await assertFails(dbFor("admin-b").collection("complaints").doc("complaint-a").update({ status: "resolved" }));
});

test("notices enforce community and flat targeting with resident-owned read markers", { skip: !enabled }, async () => {
  const notices = dbFor("resident-a").collection("notices");
  await assertSucceeds(notices.doc("notice-global-a").get());
  await assertSucceeds(notices.doc("notice-legacy-global-a").get());
  await assertSucceeds(notices.doc("notice-flat-a").get());
  await assertFails(notices.doc("notice-flat-tv").get());
  await assertFails(notices.doc("notice-global-b").get());
  await assertFails(notices.doc("notice-draft-a").get());
  await assertFails(notices.doc("notice-expired-a").get());
  await assertFails(
    notices
      .where("communityId", "==", "community-a")
      .where("targetFlats", "array-contains", "flat-a")
      .get(),
  );
  await assertFails(
    notices
      .where("communityId", "==", "community-a")
      .where("targetFlats", "==", [])
      .get(),
  );
  await assertFails(notices.where("communityId", "==", "community-a").get());
  await assertFails(notices.doc("forged-notice").set({ communityId: "community-a", targetFlats: [], title: "Forged" }));
  await assertFails(notices.doc("notice-global-a").update({ title: "Tampered" }));
  await assertFails(notices.doc("notice-global-a").delete());

  const marker = notices.doc("notice-flat-a").collection("readBy").doc("resident-a");
  await assertSucceeds(marker.set({ userId: "resident-a", readAt: new Date() }));
  await assertSucceeds(marker.get());
  await assertSucceeds(marker.update({ readAt: new Date() }));
  await assertFails(notices.doc("notice-flat-a").collection("readBy").doc("tenant-verified").set({ userId: "tenant-verified", readAt: new Date() }));
  await assertFails(notices.doc("notice-flat-tv").collection("readBy").doc("resident-a").set({ userId: "resident-a", readAt: new Date() }));
  await assertFails(dbFor("admin-a").collection("notices").doc("notice-flat-a").collection("readBy").doc("resident-a").get());
  await assertSucceeds(marker.delete());

  const adminNotice = dbFor("admin-a").collection("notices").doc("admin-notice-a");
  await assertSucceeds(dbFor("admin-a").collection("notices").where("communityId", "==", "community-a").get());
  await assertSucceeds(adminNotice.set({ communityId: "community-a", targetFlats: [], title: "Admin notice" }));
  await assertSucceeds(adminNotice.update({ title: "Updated admin notice" }));
  await assertSucceeds(adminNotice.delete());
  await assertFails(dbFor("admin-b").collection("notices").doc("notice-global-a").update({ title: "Cross tenant" }));
});

test("gate definitions are Admin-only and assigned Security access is read-only", { skip: !enabled }, async () => {
  const residentGate = dbFor("resident-a").collection("gates").doc("gate-a");
  await assertFails(residentGate.get());
  await assertFails(residentGate.update({ gateName: "Tampered" }));
  await assertFails(dbFor("resident-a").collection("gates").doc("forged-gate").set({ communityId: "community-a", gateName: "Forged" }));
  await assertFails(residentGate.delete());

  await assertSucceeds(dbFor("security-a").collection("gates").doc("gate-a").get());
  await assertFails(dbFor("security-a").collection("gates").doc("gate-b").get());
  await assertFails(dbFor("security-a").collection("gates").doc("gate-a").update({ workingStatus: "inactive" }));

  const adminGate = dbFor("admin-a").collection("gates").doc("admin-gate-a");
  await assertSucceeds(adminGate.set({ communityId: "community-a", gateName: "Admin Gate" }));
  await assertSucceeds(adminGate.update({ workingStatus: "active" }));
  await assertSucceeds(adminGate.delete());
  await assertFails(dbFor("admin-b").collection("gates").doc("gate-a").update({ workingStatus: "inactive" }));
});

test("amenity definitions no longer inherit broad resident writes", { skip: !enabled }, async () => {
  const amenity = dbFor("resident-a").collection("amenities").doc("amenity-a");
  await assertSucceeds(amenity.get());
  await assertFails(amenity.update({ name: "Tampered" }));
  await assertFails(amenity.delete());
  await assertFails(dbFor("resident-a").collection("amenities").doc("forged-amenity").set({ communityId: "community-a", buildingId: "building-a", name: "Forged" }));
  await assertSucceeds(dbFor("admin-a").collection("amenities").doc("amenity-a").update({ name: "Updated clubhouse" }));
  await assertFails(dbFor("admin-b").collection("amenities").doc("amenity-a").update({ name: "Cross tenant" }));
});

test("amenity Admin writes retain Flutter fields and allow same-community buildings", { skip: !enabled }, async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("buildings").doc("amenity-building-a2").set({ communityId: "community-a" });
  });
  const amenity = dbFor("admin-a").collection("amenities").doc("flutter-amenity");
  const flutterFields = {
    communityId: "community-a", buildingId: "building-a", buildingName: "A",
    name: "Pool", type: "Recreation", isFree: true, pricePerDay: 0,
    description: null, iconName: "pool", imageUrl: null,
    timeSlots: null, isAvailable: true,
    adminId: "admin-a", adminName: "Admin A", adminEmail: "", organization: "",
    maxCapacity: 1, allowMultipleBookings: false, bookingDurations: ["1 hour"],
    hasSubscriptionPackages: false, subscriptionPackages: {},
    createdAt: new Date(), updatedAt: new Date(),
  };
  await assertSucceeds(amenity.set(flutterFields));
  await assertSucceeds(amenity.update({
    name: "Updated pool", buildingId: "amenity-building-a2", buildingName: "A2",
    isAvailable: false, timeSlots: ["6:00 AM - 7:00 AM"],
    maxCapacity: 10, allowMultipleBookings: true,
    hasSubscriptionPackages: true, subscriptionPackages: { Weekly: 500 },
    updatedAt: new Date(),
  }));
  await assertSucceeds(amenity.update({ isAvailable: true }));
  assert.equal((await amenity.get()).data().adminId, "admin-a");
  await assertSucceeds(amenity.delete());
});

test("amenity writes reject cross-community Admins", { skip: !enabled }, async () => {
  const amenities = dbFor("admin-b").collection("amenities");
  await assertFails(amenities.doc("cross-community-amenity").set({
    communityId: "community-a", buildingId: "building-a", name: "Forged",
  }));
  await assertFails(amenities.doc("amenity-a").update({ isAvailable: false }));
  await assertFails(amenities.doc("amenity-a").delete());
});

test("amenity communityId is immutable even for an Admin authorized in both communities", { skip: !enabled }, async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("admins").doc("amenity-admin-ab").set({
      uid: "amenity-admin-ab", role: "admin", isActive: true,
      authorizedCommunityIds: ["community-a", "community-b"],
    });
  });
  for (const uid of ["admin-a", "amenity-admin-ab"]) {
    const amenity = dbFor(uid).collection("amenities").doc("amenity-a");
    await assertFails(amenity.update({ communityId: "community-b" }));
    await assertFails(amenity.update({ communityId: "community-b", buildingId: "building-b" }));
    await assertFails(amenity.set({ buildingId: "building-a", name: "Missing community" }));
  }
});

test("amenity create and update require an existing building in the same community", { skip: !enabled }, async () => {
  const amenities = dbFor("admin-a").collection("amenities");
  const invalidBuildings = [
    { buildingId: "building-b" }, { buildingId: "missing-building" },
    { buildingId: "" }, { buildingId: null }, { buildingId: 123 }, {},
  ];
  for (const [index, building] of invalidBuildings.entries()) {
    const data = { communityId: "community-a", name: "Invalid building", ...building };
    await assertFails(amenities.doc(`invalid-building-${index}`).set(data));
    // A replacement also verifies that removing buildingId is rejected on update.
    await assertFails(amenities.doc("amenity-a").set(data));
  }
  await assertFails(amenities.doc("amenity-a").update({ buildingId: "building-b" }));
});

test("amenity writes reject inactive and revoked Admins using their current profile", { skip: !enabled }, async () => {
  const uid = "amenity-admin-revoked";
  const profile = { uid, role: "admin", isActive: true, authorizedCommunityIds: ["community-a"] };
  const setProfile = (data) => environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("admins").doc(uid).set(data);
  });
  await setProfile(profile);
  const amenities = dbFor(uid).collection("amenities");
  const data = {
    communityId: "community-a",
    buildingId: "building-a",
    name: "Admin amenity",
    isFree: true,
    pricePerDay: 0,
  };
  const amenity = amenities.doc("revoked-admin-amenity");
  await assertSucceeds(amenity.set(data));
  for (const changes of [
    { isActive: false },
    { authorizedCommunityIds: ["community-b"] },
    { authorizedCommunityIds: [] },
  ]) {
    await setProfile({ ...profile, ...changes });
    await assertFails(amenities.doc("revoked-admin-create").set(data));
    await assertFails(amenity.update({ isAvailable: false }));
    await assertFails(amenity.delete());
  }
});

test("amenity writes preserve role restrictions and inactive-community denial", { skip: !enabled }, async () => {
  const data = { communityId: "community-a", buildingId: "building-a", name: "Restricted" };
  for (const db of [dbFor("super"), dbFor("security-a"), environment.unauthenticatedContext().firestore()]) {
    await assertFails(db.collection("amenities").doc("restricted-amenity").set(data));
    await assertFails(db.collection("amenities").doc("amenity-a").update({ isAvailable: false }));
    await assertFails(db.collection("amenities").doc("amenity-a").delete());
  }
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("amenities").doc("amenity-off").set({
      communityId: "community-off", buildingId: "building-off", name: "Inactive community",
    });
  });
  const amenities = dbFor("admin-off").collection("amenities");
  await assertFails(amenities.doc("inactive-community-create").set({
    communityId: "community-off", buildingId: "building-off", name: "Inactive community",
  }));
  await assertFails(amenities.doc("amenity-off").update({ isAvailable: false }));
  await assertFails(amenities.doc("amenity-off").delete());
});
test("amenity pricing supports legacy, flat, free, and resident-type modes", { skip: !enabled }, async () => {
  const amenities = dbFor("admin-a").collection("amenities");

  const base = {
    communityId: "community-a",
    buildingId: "building-a",
    name: "Pricing Test Facility",
    type: "Gym",
    isAvailable: true,
  };

  // Legacy free.
  await assertSucceeds(amenities.doc("pricing-legacy-free").set({
    ...base,
    isFree: true,
    pricePerDay: 0,
  }));

  // Legacy paid.
  await assertSucceeds(amenities.doc("pricing-legacy-paid").set({
    ...base,
    isFree: false,
    pricePerDay: 125.5,
  }));

  // New free mode.
  await assertSucceeds(amenities.doc("pricing-free").set({
    ...base,
    isFree: true,
    pricingMode: "free",
    pricePerDay: 0,
  }));

  await assertFails(amenities.doc("pricing-free-invalid").set({
    ...base,
    isFree: true,
    pricingMode: "free",
    pricePerDay: 100,
  }));

  // Flat pricing.
  await assertSucceeds(amenities.doc("pricing-flat").set({
    ...base,
    isFree: false,
    pricingMode: "flat",
    pricePerDay: 125.5,
  }));

  await assertFails(amenities.doc("pricing-flat-negative").set({
    ...base,
    isFree: false,
    pricingMode: "flat",
    pricePerDay: -1,
  }));

  await assertFails(amenities.doc("pricing-flat-string").set({
    ...base,
    isFree: false,
    pricingMode: "flat",
    pricePerDay: "100",
  }));

  // Owner / Tenant pricing.
  await assertSucceeds(amenities.doc("pricing-resident-type").set({
    ...base,
    isFree: false,
    pricingMode: "resident_type",
    pricePerDay: 0,
    ownerPricePerDay: 100,
    tenantPricePerDay: 150,
  }));

  await assertFails(amenities.doc("pricing-no-owner").set({
    ...base,
    isFree: false,
    pricingMode: "resident_type",
    pricePerDay: 0,
    tenantPricePerDay: 150,
  }));

  await assertFails(amenities.doc("pricing-no-tenant").set({
    ...base,
    isFree: false,
    pricingMode: "resident_type",
    pricePerDay: 0,
    ownerPricePerDay: 100,
  }));

  await assertFails(amenities.doc("pricing-negative-owner").set({
    ...base,
    isFree: false,
    pricingMode: "resident_type",
    pricePerDay: 0,
    ownerPricePerDay: -1,
    tenantPricePerDay: 150,
  }));

  await assertFails(amenities.doc("pricing-negative-tenant").set({
    ...base,
    isFree: false,
    pricingMode: "resident_type",
    pricePerDay: 0,
    ownerPricePerDay: 100,
    tenantPricePerDay: -1,
  }));

  await assertFails(amenities.doc("pricing-resident-type-flat-price").set({
    ...base,
    isFree: false,
    pricingMode: "resident_type",
    pricePerDay: 50,
    ownerPricePerDay: 100,
    tenantPricePerDay: 150,
  }));

  await assertFails(amenities.doc("pricing-invalid-mode").set({
    ...base,
    isFree: false,
    pricingMode: "special",
    pricePerDay: 100,
  }));

  // Update from legacy pricing to resident-type pricing.
  const editable = amenities.doc("pricing-update");

  await assertSucceeds(editable.set({
    ...base,
    isFree: false,
    pricePerDay: 100,
    description: "Legacy facility",
  }));

  // Non-pricing edit remains valid.
  await assertSucceeds(editable.update({
    description: "Updated description",
  }));

  // Invalid pricing update is rejected.
  await assertFails(editable.update({
    pricePerDay: -10,
  }));

  // Valid conversion to differentiated pricing.
  await assertSucceeds(editable.update({
    pricingMode: "resident_type",
    pricePerDay: 0,
    ownerPricePerDay: 100,
    tenantPricePerDay: 150,
  }));

  await assertFails(editable.update({
    tenantPricePerDay: -50,
  }));

  // Existing very old facility with no pricing fields should still allow
  // an unrelated edit.
  await assertSucceeds(
    dbFor("admin-a")
      .collection("amenities")
      .doc("amenity-a")
      .update({ description: "Legacy facility description" }),
  );
});
test("superAdmin has registry access but no operational access", { skip: !enabled }, async () => {
  await assertSucceeds(dbFor("super").collection("communities").get());
  await assertSucceeds(dbFor("super").collection("admins").get());
  await assertFails(dbFor("super").collection("bills").doc("bill-a").get());
});

test("inactive communities fail closed", { skip: !enabled }, async () => {
  await assertFails(dbFor("resident-off").collection("events").where("communityId", "==", "community-off").get());
});

test("unverified, pending-proof, inactive, and pending residents cannot use operational data", { skip: !enabled }, async () => {
  await assertFails(dbFor("tenant-unverified").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("tenant-pending").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("resident-inactive").collection("bills").doc("bill-a").get());
  await assertFails(dbFor("resident-pending").collection("bills").doc("bill-a").get());
  await assertSucceeds(dbFor("tenant-verified").collection("bills").doc("bill-tv").get());
});

test("restricted residents retain only their own profile access", { skip: !enabled }, async () => {
  await assertSucceeds(dbFor("tenant-unverified").collection("users").doc("tenant-unverified").get());
  await assertFails(dbFor("tenant-unverified").collection("users").doc("resident-a").get());
  await assertFails(dbFor("tenant-unverified").collection("users").doc("tenant-unverified").update({ name: "Bypass" }));
  await assertFails(dbFor("tenant-unverified").collection("users").doc("tenant-unverified").collection("private").doc("bypass").set({ value: true }));
});

test("Admin clients cannot forge resident type or identity verification", { skip: !enabled }, async () => {
  await assertFails(dbFor("admin-a").collection("users").doc("tenant-unverified").update({ identityVerified: true, identityVerificationStatus: "verified" }));
  await assertFails(dbFor("admin-a").collection("users").doc("tenant-unverified").update({ residentType: "owner", ownershipType: "owner" }));
});

test("Admin clients cannot bypass trusted occupancy transitions", { skip: !enabled }, async () => {
  const unlinkedFlat = dbFor("admin-a").collection("flats").doc("flat-status-test");
  await assertSucceeds(unlinkedFlat.set({
    communityId: "community-a",
    buildingId: "building-a",
    status: "vacant",
  }));
  await assertSucceeds(unlinkedFlat.update({ status: "maintenance" }));
  await assertFails(unlinkedFlat.update({ buildingId: "building-b" }));
  await assertFails(unlinkedFlat.update({ status: "occupied" }));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({ status: "maintenance" }));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({ status: "vacant" }));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({ residentUserId: "tenant-verified" }));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({ residentUid: null }));
  await assertFails(dbFor("admin-a").collection("flats").doc("flat-a").update({ residentIds: ["tenant-verified"] }));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-review").update({ approvalStatus: "approved", isActive: true, flatId: "flat-a" }));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-a").update({ isActive: false, status: "inactive", occupancyStatus: "suspended" }));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-inactive").update({ isActive: true, status: "active", occupancyStatus: "current" }));
  await assertFails(dbFor("admin-a").collection("flats").doc("forged-occupied").set({ communityId: "community-a", buildingId: "building-a", residentUserId: "resident-review" }));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-review").update({ approvalStatus: "rejected", isActive: false, rejectedAt: new Date(), rejectedBy: "admin-a", updatedAt: new Date() }));
  await assertFails(dbFor("admin-a").collection("users").doc("forged-resident").set({ role: "resident", communityId: "community-a", approvalStatus: "pending", isActive: false }));
  await assertFails(dbFor("admin-a").collection("residentOnboarding").doc("forged-onboarding").set({ communityId: "community-a", phoneNumber: "+639171100000", status: "pending_registration" }));
});

test("private notification reads require the canonical recipient and audience", { skip: !enabled }, async () => {
  await assertSucceeds(dbFor("resident-a").collection("notifications").doc("notification-a").get());
  await assertFails(dbFor("resident-a").collection("notifications").doc("notification-b").get());
  await assertFails(dbFor("resident-a").collection("notifications").doc("notification-admin-a").get());
  await assertSucceeds(dbFor("admin-a").collection("notifications").doc("notification-admin-a").get());
  await assertFails(dbFor("admin-a").collection("notifications").doc("notification-a").get());
  await assertSucceeds(dbFor("security-a").collection("notifications").doc("notification-security-a").get());
});

test("resident notification lists must include recipient, community, and audience", { skip: !enabled }, async () => {
  const notifications = dbFor("resident-a").collection("notifications");
  await assertFails(notifications.where("communityId", "==", "community-a").get());
  await assertSucceeds(
    notifications
      .where("communityId", "==", "community-a")
      .where("recipientId", "==", "resident-a")
      .where("audience", "==", "resident")
      .where("role", "==", "resident")
      .where("appId", "==", "resident")
      .get(),
  );
});

test("clients cannot write device tokens or forge notification delivery", { skip: !enabled }, async () => {
  await assertFails(dbFor("resident-a").collection("notificationDevices").doc("forged").set({
    uid: "resident-a",
    token: "forged-token",
    communityId: "community-a",
  }));
  await assertFails(dbFor("admin-a").collection("notifications").doc("forged").set({
    communityId: "community-a",
    recipientId: "resident-a",
    audience: "resident",
    role: "resident",
    appId: "resident",
  }));
  await assertSucceeds(dbFor("resident-a").collection("notifications").doc("notification-a").update({
    isRead: true,
    readAt: new Date(),
    updatedAt: new Date(),
  }));
  await assertFails(dbFor("resident-a").collection("notifications").doc("notification-a").update({
    message: "tampered",
  }));
});

test("legal acceptance is backend-owned on every canonical profile", { skip: !enabled }, async () => {
  const forgedAcceptance = {
    termsVersion: "forged",
    privacyVersion: "forged",
    acceptedAt: new Date(),
  };
  await assertFails(dbFor("resident-a").collection("users").doc("resident-a").update({
    legalAcceptance: forgedAcceptance,
  }));
  await assertFails(dbFor("admin-a").collection("users").doc("resident-a").update({
    legalAcceptance: forgedAcceptance,
  }));
  await assertFails(dbFor("admin-a").collection("admins").doc("admin-a").update({
    legalAcceptance: forgedAcceptance,
  }));
  await assertFails(dbFor("security-a").collection("securityStaff").doc("security-a").update({
    legalAcceptance: forgedAcceptance,
  }));
});

test("critical audit logs are inaccessible and immutable to every client role", { skip: !enabled }, async () => {
  for (const uid of ["resident-a", "admin-a", "super", "security-a"]) {
    const auditLog = dbFor(uid).collection("auditLogs").doc("audit-a");
    await assertFails(auditLog.get());
    await assertFails(auditLog.update({ summary: "tampered" }));
    await assertFails(auditLog.delete());
    await assertFails(dbFor(uid).collection("auditLogs").doc("forged").set({
      actorUid: uid,
      communityId: "community-a",
      action: "forged",
    }));
  }
});

test("notification recipients may delete only their own private inbox records", { skip: !enabled }, async () => {
  await assertFails(dbFor("resident-b").collection("notifications").doc("notification-a").delete());
  await assertFails(dbFor("admin-a").collection("notifications").doc("notification-a").delete());
  await assertSucceeds(dbFor("resident-a").collection("notifications").doc("notification-a").delete());
});


test("building and canonical unit deletion require the trusted lifecycle callable", { skip: !enabled }, async () => {
  await assertFails(dbFor("admin-a").collection("buildings").doc("building-a").delete());
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("flats").doc("deletion-vacant").set({ communityId: "community-a", buildingId: "building-a", status: "vacant" });
  });
  await assertFails(dbFor("admin-a").collection("flats").doc("deletion-vacant").delete());
  await assertFails(dbFor("admin-a").collection("flats").doc("orphan-unit").set({ communityId: "community-a", buildingId: "deleted-building", status: "vacant" }));
  await assertFails(dbFor("admin-a").collection("flats").doc("foreign-parent-unit").set({ communityId: "community-a", buildingId: "building-b", status: "vacant" }));
});


test.describe("content authorization and immutable tenant scope", {skip: !enabled}, () => {
  const test = require('node:test');
  const fs = require('node:fs');
  const path = require('node:path');
  const {assertFails, assertSucceeds, initializeTestEnvironment} = require('@firebase/rules-unit-testing');
  const {deleteField, setLogLevel} = require('firebase/firestore');
  const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  let env;
  const db = uid => env.authenticatedContext(uid).firestore();
  const ref = (uid, collection, id = 'record') => db(uid).collection(collection).doc(id);
  const scoped = {communityId: 'a', buildingId: 'ba', flatId: 'fa'};
  const owned = {...scoped, authorId: 'ra', content: 'Original'};
  const contentCollections = ['posts', 'community_wall', 'listings', 'marketplace'];
  const officialCollections = ['parcels', 'staff', 'parkingSlots', 'parking_violations', 'vendors', 'broadcasts', 'events_announcements', 'events', 'announcements', 'posters', 'pinnedPosts'];
  const check = (name, fn) => test(name, {skip: !enabled}, fn);

  test.before(async () => {
    if (!enabled) return;
    setLogLevel('silent');
    env = await initializeTestEnvironment({projectId: 'demo-hominode-content-authorization', firestore: {
      host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    }});
  });
  // Fresh fixtures keep earlier mutations from masking later authorization failures.
  test.beforeEach(async () => {
    if (!enabled) return;
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async context => {
      const batch = context.firestore().batch();
      const put = (p, value) => batch.set(context.firestore().doc(p), value);
      for (const c of ['a', 'b']) {
        put(`communities/${c}`, {isActive: true});
        put(`buildings/b${c}`, {communityId: c});
        put(`flats/f${c}`, {communityId: c, buildingId: `b${c}`});
      }
      put('buildings/ba2', {communityId: 'a'});
      put('flats/fa2', {communityId: 'a', buildingId: 'ba2'});
      for (const [uid, communityId] of [['ra', 'a'], ['ra2', 'a'], ['rb', 'b']]) {
        put(`users/${uid}`, {uid, communityId, role: 'resident', residentType: 'owner', ownershipType: 'owner', isActive: true, approvalStatus: 'approved', buildingId: `b${communityId}`, flatId: `f${communityId}`});
      }
      for (const [uid, ids] of [['aa', ['a']], ['aa2', ['a']], ['ab', ['b']], ['multi', ['a', 'b']]]) {
        put(`admins/${uid}`, {uid, role: 'admin', isActive: true, authorizedCommunityIds: ids});
      }
      put('securityStaff/sa', {uid: 'sa', role: 'security', isActive: true, communityId: 'a', gateId: 'gate'});
      put('gates/gate', {communityId: 'a'});
      put('visitors/visitor', {...scoped, status: 'expected', isApproved: false, hostUserId: 'ra'});
      put('chats/private', {...scoped, participantIds: ['ra', 'aa'], participants: ['ra', 'aa'], lastMessage: 'Private'});
      put('chats/private/messages/message', {senderId: 'ra', message: 'Private message'});
      put('chats/admin-schema', {communityId: 'a', participants: ['ra', 'aa'], adminId: 'aa', residentId: 'ra'});
      put('chats/legacy', {participantIds: ['ra', 'ra2'], participants: ['ra', 'ra2'], flatId: 'fa'});
      put('messages/message', {communityId: 'a', chatId: 'private', senderId: 'ra', message: 'Private'});
      for (const c of contentCollections) put(`${c}/record`, owned);
      for (const c of ['documents', 'apartmentImages']) put(`${c}/record`, {...scoped, createdBy: 'aa', title: 'Original'});
      for (const c of officialCollections) put(`${c}/record`, {...scoped, title: 'Official', residentId: 'ra'});
      put('events_announcements/announcement', {...scoped, type: 'announcement', title: 'Official announcement'});
      put('marketplaces/record', {...scoped, sellerId: 'ra', status: 'active'});
      put('marketplaces/record/requests/request', {requesterId: 'ra2', status: 'pending'});
      put('marketplaceRequests/record', {...scoped, productId: 'record', requestUserId: 'ra2', productOwnerId: 'ra', status: 'pending'});
      await batch.commit();
    });
  });
  test.after(async () => { if (env) await env.cleanup(); });

  check('nonparticipants cannot read chats or nested/top-level messages, including tenant admins', async () => {
    for (const uid of ['ra2', 'rb', 'aa2', 'ab', 'sa']) {
      await assertFails(ref(uid, 'chats', 'private').get());
      await assertFails(ref(uid, 'chats', 'private').collection('messages').doc('message').get());
      await assertFails(ref(uid, 'messages', 'message').get());
    }
  });
  check('nonparticipants cannot update a chat or inject either participant alias', async () => {
    for (const uid of ['ra2', 'aa2', 'rb']) {
      await assertFails(ref(uid, 'chats', 'private').update({lastMessage: 'Hijacked'}));
      for (const field of ['participants', 'participantIds']) await assertFails(ref(uid, 'chats', 'private').update({[field]: ['ra', uid]}));
    }
  });
  check('participants retain reads, queries, messages and metadata updates in both current chat schemas', async () => {
    for (const uid of ['ra', 'aa']) for (const id of ['private', 'admin-schema']) {
      await assertSucceeds(ref(uid, 'chats', id).get());
      await assertSucceeds(ref(uid, 'chats', id).update({lastMessage: 'Hello'}));
      await assertSucceeds(ref(uid, 'chats', id).collection('messages').doc(uid).set({senderId: uid, message: 'Hello'}));
      await assertSucceeds(ref(uid, 'chats', id).collection('messages').get());
    }
    await assertSucceeds(db('aa').collection('chats').where('communityId', '==', 'a').where('participants', 'array-contains', 'aa').get());
    await assertSucceeds(db('ra').collection('chats').where('participantIds', 'array-contains', 'ra').get());
    await assertSucceeds(ref('ra2', 'chats', 'legacy').update({lastMessage: 'Legacy preserved'}));
  });
  check('participant arrays, tenant, and message sender cannot be reassigned or removed', async () => {
    for (const field of ['participants', 'participantIds', 'communityId']) await assertFails(ref('ra', 'chats', 'private').update({[field]: deleteField()}));
    await assertFails(ref('ra', 'chats', 'private').update({participants: ['ra', 'rb']}));
    await assertFails(ref('aa', 'chats', 'private').collection('messages').doc('message').update({senderId: 'aa'}));
  });
  check('legacy resident and current admin chat creation succeeds; foreign references fail', async () => {
    await assertSucceeds(ref('ra', 'chats', 'new-resident').set({participantIds: ['ra', 'ra2'], participants: ['ra', 'ra2'], flatId: 'fa'}));
    await assertSucceeds(ref('aa', 'chats', 'new-admin').set({communityId: 'a', participants: ['aa', 'ra'], buildingId: '', residentId: 'ra', adminId: 'aa'}));
    await assertFails(ref('ra', 'chats', 'bad-reference').set({participantIds: ['ra'], communityId: 'a', flatId: 'fb'}));
  });
  for (const c of officialCollections) check(`official ${c}: resident writes denied; admin CRUD and resident reads preserved`, async () => {
    await assertSucceeds(ref('ra', c).get());
    await assertSucceeds(db('ra').collection(c).where('communityId', '==', 'a').get());
    await assertFails(ref('ra', c, 'forged').set({...scoped, userId: 'ra'}));
    await assertFails(ref('ra', c).update({title: 'Forged'}));
    await assertFails(ref('ra', c).delete());
    for (const uid of ['sa', 'ab']) await assertFails(ref(uid, c).update({title: 'Forged'}));
    await assertSucceeds(ref('aa', c, 'new').set({...scoped, title: 'New'}));
    await assertSucceeds(ref('aa', c).update({title: 'Updated', residentId: 'ra2'}));
    await assertFails(ref('multi', c).update({communityId: 'b'}));
    await assertFails(ref('aa', c).update({communityId: deleteField()}));
    await assertSucceeds(ref('aa', c, 'new').delete());
  });
  check('canonical mixed collection announcement is not resident-editable', async () => {
    await assertFails(ref('ra', 'events_announcements', 'announcement').update({title: 'Forged'}));
    await assertSucceeds(ref('aa', 'events_announcements', 'announcement').update({title: 'Updated'}));
  });
  for (const c of [...contentCollections, 'documents', 'apartmentImages', 'marketplaces']) {
    const actor = ['documents', 'apartmentImages'].includes(c) ? 'aa' : 'ra';
    check(`${c}: tenant reassignment/removal and ownership alias injection denied; legitimate edits succeed`, async () => {
      for (const uid of [actor, 'multi']) {
        await assertFails(ref(uid, c).update({communityId: 'b'}));
        await assertFails(ref(uid, c).update({communityId: deleteField()}));
        for (const field of ['ownerId', 'userId', 'uid', 'authorId', 'residentId', 'sellerId', 'createdBy', 'firebaseAuthUid']) await assertFails(ref(uid, c).update({[field]: 'rb'}));
      }
      const ownerField = c === 'marketplaces' ? 'sellerId' : actor === 'aa' ? 'createdBy' : 'authorId';
      await assertFails(ref(actor, c).update({[ownerField]: deleteField()}));
      await assertSucceeds(ref(actor, c).update({title: 'Legitimate edit'}));
      if (c !== 'marketplaces') await assertSucceeds(ref('aa', c).update({title: 'Moderated'}));
    });
    check(`${c}: foreign/missing building and unit references denied on create/update`, async () => {
      const payload = c === 'marketplaces' ? {...scoped, sellerId: 'ra'} : actor === 'aa' ? {...scoped, createdBy: 'aa'} : owned;
      for (const patch of [{buildingId: 'bb'}, {flatId: 'fb'}, {buildingId: 'missing'}, {flatId: 'missing'}, {flatId: 'fa2'}]) {
        await assertFails(ref(actor, c).update(patch));
        await assertFails(ref(actor, c, 'bad').set({...payload, ...patch}));
      }
      await assertSucceeds(ref(actor, c, 'new').set(payload));
    });
  }
  check('legacy building-scoped posts/listings preserve creation/edit/delete without communityId', async () => {
    for (const c of ['posts', 'community_wall', 'listings', 'marketplaces']) {
      const owner = c === 'marketplaces' ? {sellerId: 'ra'} : {authorId: 'ra'};
      await assertSucceeds(ref('ra', c, 'legacy').set({...owner, buildingId: 'ba', flatId: 'fa', title: 'Legacy'}));
      await assertSucceeds(ref('ra', c, 'legacy').update({title: 'Updated'}));
      await assertFails(ref('ra', c, 'legacy').update({communityId: 'b'}));
      await assertFails(ref('ra', c, 'legacy').update({buildingId: 'bb', flatId: 'fb'}));
      await assertFails(ref('ra', c, 'legacy').update({buildingId: deleteField(), flatId: deleteField()}));
      await assertSucceeds(ref('ra', c, 'legacy').delete());
    }
  });
  check('resident content creation cannot impersonate another owner', async () => {
    await assertFails(ref('ra', 'marketplaces', 'forged-alias').set({sellerId: 'ra', userId: 'rb', buildingId: 'ba'}));
    for (const c of contentCollections) {
      await assertFails(ref('ra', c, 'forged').set({...owned, authorId: 'ra2'}));
      await assertFails(ref('ra', c, 'conflict').set({...owned, userId: 'ra2'}));
    }
  });
  check('admin can retarget documents/images within the same community', async () => {
    for (const c of ['documents', 'apartmentImages']) await assertSucceeds(ref('aa', c).update({buildingId: 'ba2', flatId: 'fa2'}));
  });
  check('marketplace seller responses preserve requester identity', async () => {
    const request = ref('ra', 'marketplaces').collection('requests').doc('request');
    await assertSucceeds(request.update({status: 'accepted'}));
    await assertFails(request.update({requesterId: 'rb'}));
    await assertFails(request.update({requesterId: deleteField()}));
    await assertSucceeds(ref('ra', 'marketplaceRequests').update({status: 'accepted'}));
    await assertFails(ref('ra', 'marketplaceRequests').update({requestUserId: 'rb'}));
    await assertFails(ref('rb', 'marketplaceRequests').get());
  });
  check('resident-owned fallback records reject other residents edits', async () => {
    for (const [c, owner] of [['marketplace', 'sellerId'], ['reports', 'reportedBy'], ['requests', 'requesterId']]) {
      await assertSucceeds(ref('ra', c, 'native-owner').set({...scoped, [owner]: 'ra'}));
      await assertSucceeds(ref('ra', c, 'native-owner').update({content: 'Edited'}));
      await assertFails(ref('ra2', c, 'native-owner').update({content: 'Hijacked'}));
      await assertFails(ref('ra', c, 'native-owner').update({[owner]: 'rb'}));
    }
    for (const c of ['comments', 'reports', 'requests', 'readBy']) {
      await assertSucceeds(ref('ra', c).set({...owned, userId: 'ra'}));
      await assertSucceeds(ref('ra', c).update({content: 'Edited'}));
      await assertFails(ref('ra2', c).update({content: 'Hijacked'}));
      await assertFails(ref('ra', c).update({communityId: 'b'}));
      await assertSucceeds(ref('aa', c).update({content: 'Reviewed'}));
    }
  });
  check('Security visitor and assigned-gate access remains unchanged', async () => {
    await assertSucceeds(ref('sa', 'visitors', 'visitor').get());
    await assertSucceeds(ref('sa', 'visitors', 'visitor').update({status: 'inside', isApproved: true}));
    await assertSucceeds(ref('sa', 'gates', 'gate').get());
  });

  check('a resident moved to another community cannot edit old building-scoped content', async () => {
    await assertSucceeds(ref('ra', 'posts', 'legacy').set({authorId: 'ra', buildingId: 'ba', content: 'Old tenant'}));
    await env.withSecurityRulesDisabled(context => context.firestore().doc('users/ra').update({communityId: 'b', buildingId: 'bb', flatId: 'fb'}));
    await assertFails(ref('ra', 'posts', 'legacy').update({content: 'Cross-tenant edit'}));
    await assertFails(ref('ra', 'marketplaces').update({status: 'sold'}));
  });
});
