const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError, verifiedPhoneAuth} = require("./register_resident");
const {
  normalizeCommunityId,
  validateCommunityLocationMetadata,
} = require("./tenant_management");
const {AUDIT_ACTIONS, writeAuditLogBestEffort} = require("./audit_log");

function activeAdminProfile(snapshot, uid) {
  const profile = snapshot.data();
  if (!snapshot.exists || profile?.uid !== uid || profile?.isActive !== true) {
    throw new RegistrationError(
      "permission-denied",
      "An active admin profile is required.",
    );
  }
  return profile;
}

function authorizedCommunityIds(profile) {
  const ids = profile?.authorizedCommunityIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    throw new RegistrationError(
      "permission-denied",
      "An active authorized community is required.",
    );
  }
  const normalized = ids.map((id) => typeof id === "string" ? id.trim() : "");
  if (
    normalized.some((id) => !id || id.length > 80 || normalizeCommunityId(id) !== id) ||
    new Set(normalized).size !== normalized.length
  ) {
    throw new RegistrationError(
      "permission-denied",
      "Admin community authorization is invalid.",
    );
  }
  return normalized;
}

async function requireLocationSearchAdmin(db, auth) {
  const {uid} = verifiedPhoneAuth(auth);
  const snapshot = await db.collection("admins").doc(uid).get();
  const profile = activeAdminProfile(snapshot, uid);
  if (profile.role === "superAdmin") return {uid, profile};
  if (profile.role !== "admin") {
    throw new RegistrationError("permission-denied", "An active admin profile is required.");
  }
  const ids = authorizedCommunityIds(profile);
  const communities = await Promise.all(
    ids.map((id) => db.collection("communities").doc(id).get()),
  );
  if (!communities.some((community) => community.exists && community.data()?.isActive === true)) {
    throw new RegistrationError(
      "permission-denied",
      "An active authorized community is required.",
    );
  }
  return {uid, profile};
}

async function requireAuthorizedCommunityAdmin(db, auth, communityId) {
  const {uid} = verifiedPhoneAuth(auth);
  const snapshot = await db.collection("admins").doc(uid).get();
  const profile = activeAdminProfile(snapshot, uid);
  if (profile.role !== "admin") {
    throw new RegistrationError(
      "permission-denied",
      "An active community admin profile is required.",
    );
  }
  if (!authorizedCommunityIds(profile).includes(communityId)) {
    throw new RegistrationError(
      "permission-denied",
      "You are not authorized for this community.",
    );
  }
  return {uid, profile};
}

function validateLocationUpdateInput(data) {
  const allowedKeys = new Set(["communityId", "location"]);
  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    Object.keys(data).some((key) => !allowedKeys.has(key))
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Only communityId and location may be updated.",
    );
  }
  const suppliedCommunityId = typeof data.communityId === "string" ? data.communityId.trim() : "";
  const communityId = normalizeCommunityId(suppliedCommunityId);
  if (!communityId || suppliedCommunityId !== communityId) {
    throw new RegistrationError("invalid-argument", "Enter a valid community ID.");
  }
  if (
    !data.location ||
    typeof data.location !== "object" ||
    Array.isArray(data.location) ||
    typeof data.location.formattedAddress !== "string" ||
    (
      data.location.placeId != null &&
      typeof data.location.placeId !== "string"
    )
  ) {
    throw new RegistrationError("invalid-argument", "Enter a valid community location.");
  }
  const metadata = validateCommunityLocationMetadata({
    locationConfigured: true,
    location: data.location,
  });
  return {communityId, location: metadata.location};
}

async function updateCommunityLocationCore({db, auth, data}) {
  const input = validateLocationUpdateInput(data);
  const {uid} = await requireAuthorizedCommunityAdmin(db, auth, input.communityId);
  const communityRef = db.collection("communities").doc(input.communityId);
  const community = await communityRef.get();
  if (!community.exists || community.data()?.isActive !== true) {
    throw new RegistrationError(
      "failed-precondition",
      "The target community is inactive or unavailable.",
    );
  }
  await communityRef.update({
    locationConfigured: true,
    location: {
      ...input.location,
      updatedAt: FieldValue.serverTimestamp(),
    },
  });
  await writeAuditLogBestEffort({
    db,
    actorUid: uid,
    actorRole: "admin",
    communityId: input.communityId,
    action: AUDIT_ACTIONS.communityLocationUpdate,
    targetType: "community",
    targetId: input.communityId,
    summary: "Community operational location updated.",
    metadata: {
      previouslyConfigured: community.data()?.locationConfigured === true,
      nowConfigured: true,
    },
  });
  return {communityId: input.communityId, updatedBy: uid};
}

module.exports = {
  activeAdminProfile,
  authorizedCommunityIds,
  requireLocationSearchAdmin,
  requireAuthorizedCommunityAdmin,
  validateLocationUpdateInput,
  updateCommunityLocationCore,
};
