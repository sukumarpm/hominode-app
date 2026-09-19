const { FieldValue } = require("firebase-admin/firestore");
const { RegistrationError } = require("./register_resident");

const PUBLIC_STATS_COLLECTION = "publicPlatformStats";
const PUBLIC_STATS_DOCUMENT = "current";
const SCHEMA_VERSION = 1;

async function requireActiveSuperAdmin(db, auth) {
  if (!auth?.uid) {
    throw new RegistrationError(
      "unauthenticated",
      "Authentication is required."
    );
  }

  const adminSnapshot = await db.collection("admins").doc(auth.uid).get();
  const admin = adminSnapshot.data();

  if (
    !adminSnapshot.exists ||
    admin?.role !== "superAdmin" ||
    admin?.isActive !== true
  ) {
    throw new RegistrationError(
      "permission-denied",
      "Only an active Super Admin may refresh public platform statistics."
    );
  }
}

async function refreshPublicPlatformStatsCore({ db, auth }) {
  await requireActiveSuperAdmin(db, auth);

  // Active communities are the source of truth for all people counters.
  const communitySnapshot = await db
    .collection("communities")
    .where("isActive", "==", true)
    .get();

  const activeCommunityIds = new Set(
    communitySnapshot.docs.map((doc) => doc.id)
  );

  const [
    residentSnapshot,
    securitySnapshot,
    visitorSnapshot,
    complaintSnapshot,
    bookingSnapshot,
  ] = await Promise.all([
    db.collection("users").where("role", "==", "resident").get(),
    db.collection("securityStaff").where("role", "==", "security").get(),
    db.collection("visitors").get(),
    db.collection("complaints").get(),
    db.collection("bookings").get(),
  ]);

  const activeResidents = residentSnapshot.docs.filter((doc) => {
    const data = doc.data();

    return (
      data.isActive === true &&
      data.approvalStatus === "approved" &&
      typeof data.communityId === "string" &&
      activeCommunityIds.has(data.communityId)
    );
  }).length;

  const activeSecurityStaff = securitySnapshot.docs.filter((doc) => {
    const data = doc.data();

    return (
      data.isActive === true &&
      typeof data.communityId === "string" &&
      activeCommunityIds.has(data.communityId)
    );
  }).length;

  const visitorsProcessed = visitorSnapshot.docs.filter((doc) => {
    const status = String(doc.data().status || "").toLowerCase();
    return status === "completed" || status === "departed";
  }).length;

  const resolvedComplaints = complaintSnapshot.docs.filter((doc) => {
    const status = String(doc.data().status || "").toLowerCase();

    return (
      status === "completed" ||
      status === "resolved" ||
      status === "closed"
    );
  }).length;

  const countedBookingStatuses = new Set([
    "pending",
    "confirmed",
    "approved",
    "completed",
    "expired",
  ]);

  const facilityBookings = bookingSnapshot.docs.filter((doc) => {
    const status = String(doc.data().status || "").toLowerCase();
    return countedBookingStatuses.has(status);
  }).length;

  const stats = {
    activeCommunities: activeCommunityIds.size,
    activeResidents,
    activeSecurityStaff,
    visitorsProcessed,
    resolvedComplaints,
    facilityBookings,
    schemaVersion: SCHEMA_VERSION,
    updatedAt: FieldValue.serverTimestamp(),
  };

  await db
    .collection(PUBLIC_STATS_COLLECTION)
    .doc(PUBLIC_STATS_DOCUMENT)
    .set(stats, { merge: false });

  return {
    success: true,
    stats: {
      activeCommunities: activeCommunityIds.size,
      activeResidents,
      activeSecurityStaff,
      visitorsProcessed,
      resolvedComplaints,
      facilityBookings,
      schemaVersion: SCHEMA_VERSION,
    },
  };
}

module.exports = {
  PUBLIC_STATS_COLLECTION,
  PUBLIC_STATS_DOCUMENT,
  SCHEMA_VERSION,
  refreshPublicPlatformStatsCore,
};
