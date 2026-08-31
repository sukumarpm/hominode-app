const {RegistrationError} = require("./register_resident");
const {APP_CONTEXTS} = require("./notifications");

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireResidentApp(app) {
  const context = APP_CONTEXTS[normalizedString(app?.appId)];
  if (!context || context.role !== "resident" || context.appId !== "resident") {
    throw new RegistrationError(
      "failed-precondition",
      "The Resident application is required.",
    );
  }
}

function identityVerified(profile) {
  return profile?.identityVerified === true &&
    profile?.identityVerificationStatus === "verified";
}

function residentIdentityEligible(profile, community) {
  const residentType = normalizedString(
    profile?.residentType ?? profile?.ownershipType,
  );
  if (residentType === "owner") {
    return community?.ownerIdentityVerificationRequired !== true ||
      identityVerified(profile);
  }
  return residentType === "tenant" && identityVerified(profile);
}

function timestampMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number.isFinite(value) ? value : null;
}

function noticeVisibleToResident(data, flatId, nowMillis = Date.now()) {
  if (data?.isActive !== true && data?.status !== "published") return false;

  const targetFlats = Array.isArray(data?.targetFlats) ? data.targetFlats : [];
  if (targetFlats.length > 0 && !targetFlats.includes(flatId)) return false;

  const expiresAt = timestampMillis(data?.expiryDate ?? data?.expiresAt);
  return expiresAt == null || nowMillis <= expiresAt;
}

async function getResidentNoticeIdsCore({db, auth, app}) {
  const uid = normalizedString(auth?.uid);
  if (!uid) {
    throw new RegistrationError("unauthenticated", "Authentication is required.");
  }
  requireResidentApp(app);

  const profileSnapshot = await db.collection("users").doc(uid).get();
  const profile = profileSnapshot.data();
  const communityId = normalizedString(profile?.communityId);
  const flatId = normalizedString(profile?.flatId);
  const profileValid = profileSnapshot.exists && profile?.uid === uid &&
    profile?.role === "resident" && profile?.approvalStatus === "approved" &&
    profile?.isActive === true &&
    (profile?.status == null || profile.status === "active") &&
    communityId && flatId;
  if (!profileValid) {
    throw new RegistrationError(
      "permission-denied",
      "An active approved Resident profile with a flat is required.",
    );
  }

  const communitySnapshot = await db
    .collection("communities")
    .doc(communityId)
    .get();
  const community = communitySnapshot.data();
  if (!communitySnapshot.exists || community?.isActive !== true ||
      !residentIdentityEligible(profile, community)) {
    throw new RegistrationError(
      "permission-denied",
      "The Resident community or identity state is not eligible.",
    );
  }

  const noticeSnapshot = await db
    .collection("notices")
    .where("communityId", "==", communityId)
    .get();
  const noticeIds = noticeSnapshot.docs
    .filter((document) => noticeVisibleToResident(document.data(), flatId))
    .map((document) => document.id);

  return {communityId, flatId, noticeIds};
}

module.exports = {
  getResidentNoticeIdsCore,
  noticeVisibleToResident,
  residentIdentityEligible,
};
