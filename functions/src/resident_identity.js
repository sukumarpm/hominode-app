const {randomUUID} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError, verifiedPhoneAuth} = require("./register_resident");

const VERIFICATION_STATUSES = new Set([
  "verification_required",
  "pending",
  "verified",
  "rejected",
  "not_required",
]);
const RESIDENT_TYPES = new Set(["owner", "tenant"]);
const MAX_PROOF_BYTES = 5 * 1024 * 1024;
const PROOF_CONTENT_TYPES = new Set(["image/jpeg", "image/png"]);

const clean = (value) => typeof value === "string" ? value.trim() : "";

function canonicalResidentType(profile) {
  const residentType = clean(profile?.residentType).toLowerCase();
  const ownershipType = clean(profile?.ownershipType).toLowerCase();
  if (residentType && !RESIDENT_TYPES.has(residentType)) return null;
  if (ownershipType && !RESIDENT_TYPES.has(ownershipType)) return null;
  if (residentType && ownershipType && residentType !== ownershipType) return null;
  return residentType || ownershipType || null;
}

function declaredResidentType(profile) {
  const value = clean(profile?.declaredResidentType).toLowerCase();
  return RESIDENT_TYPES.has(value) ? value : null;
}

function trustedResidentType(profile) {
  const canonical = canonicalResidentType(profile);
  const declared = declaredResidentType(profile);
  const hasCanonicalFields = clean(profile?.residentType) ||
    clean(profile?.ownershipType);
  const hasDeclaredField = clean(profile?.declaredResidentType);
  if ((hasCanonicalFields && !canonical) ||
      (hasDeclaredField && !declared)) return null;
  if (canonical && declared && canonical !== declared) return null;
  return canonical || declared || null;
}

function verificationStatus(profile) {
  const status = clean(profile?.identityVerificationStatus).toLowerCase();
  if (VERIFICATION_STATUSES.has(status)) return status;
  return profile?.identityVerified === true ? "verified" : "verification_required";
}

function ownerVerificationRequired(community) {
  return community?.ownerIdentityVerificationRequired === true;
}

function identityVerificationRequired(residentType, community) {
  if (residentType === "tenant") return true;
  if (residentType === "owner") return ownerVerificationRequired(community);
  return true;
}

function identityIsVerified(profile) {
  return profile?.identityVerified === true && verificationStatus(profile) === "verified";
}

function resolveFlatOccupant(flat) {
  const data = flat && typeof flat === "object" ? flat : {};
  const pointers = [];
  for (const field of ["residentUserId", "residentUid"]) {
    if (!(field in data) || data[field] == null || data[field] === "") continue;
    const value = clean(data[field]);
    if (!value) {
      throw new RegistrationError("failed-precondition", `Flat ${field} is malformed.`);
    }
    pointers.push({field, value});
  }
  if ("residentIds" in data && data.residentIds != null) {
    if (!Array.isArray(data.residentIds) || data.residentIds.length > 1) {
      throw new RegistrationError("failed-precondition", "Flat residentIds is ambiguous.");
    }
    if (data.residentIds.length === 1) {
      const value = clean(data.residentIds[0]);
      if (!value) {
        throw new RegistrationError("failed-precondition", "Flat residentIds is malformed.");
      }
      pointers.push({field: "residentIds", value});
    }
  }
  const values = new Set(pointers.map(({value}) => value));
  if (values.size > 1) {
    throw new RegistrationError("failed-precondition", "Flat occupant references conflict.");
  }
  const uid = pointers[0]?.value ?? null;
  return {
    uid,
    usesCanonicalField: pointers.some(({field}) => field === "residentUserId"),
    needsCanonicalization: uid != null &&
      (pointers.some(({field}) => field !== "residentUserId") ||
       !pointers.some(({field}) => field === "residentUserId")),
  };
}

function residentOccupancyState(profile, {communityId, flatId}) {
  if (!profile || profile.role !== "resident" ||
      clean(profile.communityId) !== communityId ||
      !canonicalResidentType(profile)) {
    return "ambiguous";
  }
  const movedOut = profile.occupancyStatus === "moved_out" || profile.status === "moved_out";
  const assignedFlatId = clean(profile.flatId) || (movedOut ? clean(profile.previousFlatId) : "");
  if (assignedFlatId !== flatId) return "ambiguous";
  if (profile.isActive === false || movedOut || profile.status === "inactive") return "inactive";
  if (profile.isActive === true && profile.approvalStatus === "approved" &&
      (!clean(profile.status) || profile.status === "active") &&
      (!clean(profile.occupancyStatus) || profile.occupancyStatus === "current")) {
    return "active";
  }
  return "ambiguous";
}

function validateBuildingAndFlat({buildingSnapshot, flatSnapshot, communityId, buildingId}) {
  if (!buildingSnapshot.exists || buildingSnapshot.data()?.communityId !== communityId ||
      !flatSnapshot.exists || flatSnapshot.data()?.communityId !== communityId ||
      flatSnapshot.data()?.buildingId !== buildingId) {
    throw new RegistrationError("permission-denied", "Building or unit is outside the authorized community.");
  }
}

function isResidentProofPath(path, communityId, residentId) {
  const prefix = `residentIdentityProofs/${communityId}/${residentId}/`;
  return path.startsWith(prefix) &&
    path.length > prefix.length &&
    !path.slice(prefix.length).includes("/");
}

function operationalAccessFailure(profile, community) {
  if (profile?.role !== "resident") return "wrong-role";
  if (profile?.approvalStatus !== "approved") return "not-approved";
  if (profile?.isActive !== true || (clean(profile?.status) && profile.status !== "active")) {
    return "inactive";
  }
  if (!clean(profile?.communityId) || profile.communityId !== community?.id || community?.isActive !== true) {
    return "wrong-community";
  }
  const type = canonicalResidentType(profile);
  if (!type) return "resident-type-ambiguous";
  if (identityVerificationRequired(type, community) && !identityIsVerified(profile)) {
    return "identity-verification-required";
  }
  return null;
}

async function requireOperationalAdmin(db, auth, communityId) {
  const {uid} = verifiedPhoneAuth(auth);
  const adminSnapshot = await db.collection("admins").doc(uid).get();
  const admin = adminSnapshot.data();
  if (!adminSnapshot.exists || admin?.uid !== uid || admin?.role !== "admin" ||
      admin?.isActive !== true || !Array.isArray(admin?.authorizedCommunityIds) ||
      !admin.authorizedCommunityIds.includes(communityId)) {
    throw new RegistrationError("permission-denied", "An authorized active Admin is required.");
  }
  const communitySnapshot = await db.collection("communities").doc(communityId).get();
  if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "Community is inactive or unavailable.");
  }
  return {uid, community: {id: communityId, ...communitySnapshot.data()}};
}

function validateApprovalInput(data) {
  const allowed = new Set(["communityId", "userId", "buildingId", "flatId", "residentType"]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "A valid resident approval request is required.");
  }
  const result = Object.fromEntries([...allowed].map((key) => [key, clean(data[key])]));
  result.residentType = result.residentType.toLowerCase();
  if (!result.communityId || !result.userId || !result.buildingId || !result.flatId ||
      !RESIDENT_TYPES.has(result.residentType)) {
    throw new RegistrationError("invalid-argument", "Community, resident, building, unit, and resident type are required.");
  }
  return result;
}

async function approveResidentRegistrationCore({db, auth, data}) {
  const input = validateApprovalInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const buildingRef = db.collection("buildings").doc(input.buildingId);
  const flatRef = db.collection("flats").doc(input.flatId);
  const sameFlatQuery = db.collection("users")
    .where("communityId", "==", input.communityId)
    .where("flatId", "==", input.flatId);

  return db.runTransaction(async (transaction) => {
    const [userSnapshot, buildingSnapshot, flatSnapshot, sameFlatSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(buildingRef),
      transaction.get(flatRef),
      transaction.get(sameFlatQuery),
    ]);
    if (!userSnapshot.exists || userSnapshot.data()?.role !== "resident") {
      throw new RegistrationError("not-found", "Pending resident registration was not found.");
    }
    const resident = userSnapshot.data();
    if (resident.communityId !== input.communityId || resident.approvalStatus !== "pending" || resident.isActive !== false) {
      throw new RegistrationError("failed-precondition", "Only an inactive pending resident in this community can be approved.");
    }
    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId: input.buildingId,
    });
    const trustedType = trustedResidentType(resident);
    if (!trustedType) {
      throw new RegistrationError(
        "failed-precondition",
        "Resident type fields are missing, invalid, or conflicting.",
      );
    }
    if (trustedType !== input.residentType) {
      throw new RegistrationError(
        "failed-precondition",
        "The registered resident type cannot be changed during approval.",
      );
    }
    const flat = flatSnapshot.data();
    const occupant = resolveFlatOccupant(flat);
    if (!["vacant", "occupied"].includes(flat.status)) {
      throw new RegistrationError("failed-precondition", "This unit is unavailable for resident assignment.");
    }
    if (!occupant.uid && flat.status === "occupied") {
      throw new RegistrationError("failed-precondition", "This unit is marked occupied without a valid occupant reference.");
    }
    for (const doc of sameFlatSnapshot.docs) {
      if (doc.id === input.userId) continue;
      const state = residentOccupancyState(doc.data(), {
        communityId: input.communityId,
        flatId: input.flatId,
      });
      if (state === "active") {
        throw new RegistrationError("failed-precondition", "This unit already has an active resident occupant.");
      }
      if (state === "ambiguous") {
        throw new RegistrationError("failed-precondition", "This unit has ambiguous resident assignment data.");
      }
    }
    if (occupant.uid && occupant.uid !== input.userId) {
      const occupantSnapshot = await transaction.get(db.collection("users").doc(occupant.uid));
      if (!occupantSnapshot.exists) {
        throw new RegistrationError("failed-precondition", "This unit references an unknown resident occupant.");
      }
      const state = residentOccupancyState(occupantSnapshot.data(), {
        communityId: input.communityId,
        flatId: input.flatId,
      });
      if (state === "active") {
        throw new RegistrationError("failed-precondition", "This unit already has an active resident occupant.");
      }
      if (state !== "inactive") {
        throw new RegistrationError("failed-precondition", "This unit occupant reference is ambiguous.");
      }
    }
    const required = identityVerificationRequired(trustedType, actor.community);
    const verified = identityIsVerified(resident);
    if (required && !verified) {
      throw new RegistrationError(
        "failed-precondition",
        "Identity proof must be uploaded and verified before this resident can be approved.",
      );
    }
    const active = true;
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      residentType: trustedType,
      ownershipType: trustedType,
      approvalStatus: "approved",
      isActive: active,
      status: "active",
      identityVerified: verified,
      identityVerificationStatus: required
        ? "verified"
        : (verified ? "verified" : "not_required"),
      buildingId: input.buildingId,
      buildingName: clean(buildingSnapshot.data()?.buildingName || buildingSnapshot.data()?.name) || null,
      flatId: input.flatId,
      unitId: clean(flatSnapshot.data()?.unitId || flatSnapshot.data()?.flatId) || input.flatId,
      flatLabel: clean(flatSnapshot.data()?.flatLabel || flatSnapshot.data()?.flatId) || input.flatId,
      occupancyStatus: "current",
      approvedAt: timestamp,
      approvedBy: actor.uid,
      updatedAt: timestamp,
    });
    transaction.update(flatRef, {
      status: "occupied",
      residentUserId: input.userId,
      residentUid: FieldValue.delete(),
      residentIds: FieldValue.delete(),
      residentId: resident.residentId ?? null,
      residentName: resident.name ?? resident.fullName ?? null,
      ownershipType: trustedType,
      updatedAt: timestamp,
    });
    return {status: "approved", isActive: active, identityVerificationRequired: false};
  });
}

function decodeProof(data) {
  const allowed = new Set(["contentType", "base64"]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "A valid identity proof is required.");
  }
  const contentType = clean(data.contentType).toLowerCase();
  const encoded = clean(data.base64);
  if (!PROOF_CONTENT_TYPES.has(contentType) || !encoded || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) {
    throw new RegistrationError("invalid-argument", "Identity proof must be a JPEG or PNG image.");
  }
  const bytes = Buffer.from(encoded, "base64");
  if (bytes.length < 1 || bytes.length > MAX_PROOF_BYTES || bytes.toString("base64").replace(/=+$/, "") !== encoded.replace(/=+$/, "")) {
    throw new RegistrationError("invalid-argument", "Identity proof must be no larger than 5 MB.");
  }
  const isJpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const isPng = bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  if ((contentType === "image/jpeg" && !isJpeg) || (contentType === "image/png" && !isPng)) {
    throw new RegistrationError("invalid-argument", "Identity proof content does not match its image type.");
  }
  return {contentType, bytes};
}

async function submitResidentIdentityProofCore({db, bucket, auth, data}) {
  const identity = verifiedPhoneAuth(auth);
  if (!bucket) throw new RegistrationError("failed-precondition", "Identity proof storage is unavailable.");
  const proof = decodeProof(data);
  const userRef = db.collection("users").doc(identity.uid);
  const userSnapshot = await userRef.get();
  const resident = userSnapshot.data();
  if (!userSnapshot.exists || resident?.role !== "resident" || resident?.phoneNumber !== identity.phoneNumber) {
    throw new RegistrationError("permission-denied", "A matching resident profile is required.");
  }
  const type = trustedResidentType(resident);
  if (!type || !clean(resident.communityId)) {
    throw new RegistrationError(
      "failed-precondition",
      "Resident type is ambiguous or community is not configured.",
    );
  }
  if (verificationStatus(resident) === "verified") {
    throw new RegistrationError(
      "failed-precondition",
      "A verified identity proof cannot be replaced through the standard upload flow.",
    );
  }
  if (!["pending", "approved"].includes(resident.approvalStatus)) {
    throw new RegistrationError("failed-precondition", "Identity proof cannot be submitted for this resident state.");
  }
  const communitySnapshot = await db.collection("communities").doc(resident.communityId).get();
  if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "Community is inactive or unavailable.");
  }
  const extension = proof.contentType === "image/png" ? "png" : "jpg";
  const path = `residentIdentityProofs/${resident.communityId}/${identity.uid}/${randomUUID()}.${extension}`;
  await bucket.file(path).save(proof.bytes, {
    resumable: false,
    metadata: {contentType: proof.contentType, cacheControl: "private, no-store"},
  });
  let previousPath = "";
  await db.runTransaction(async (transaction) => {
    const currentSnapshot = await transaction.get(userRef);
    const current = currentSnapshot.data();
    if (!currentSnapshot.exists || current?.role !== "resident" ||
        current?.phoneNumber !== identity.phoneNumber ||
        current?.communityId !== resident.communityId) {
      throw new RegistrationError("permission-denied", "A matching resident profile is required.");
    }
    if (verificationStatus(current) === "verified") {
      throw new RegistrationError(
        "failed-precondition",
        "A verified identity proof cannot be replaced through the standard upload flow.",
      );
    }
    previousPath = clean(current.identityProofStoragePath);
    transaction.update(userRef, {
      identityProofStoragePath: path,
      identityProofContentType: proof.contentType,
      identityProofUploadedAt: FieldValue.serverTimestamp(),
      identityVerificationStatus: "pending",
      identityVerified: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  if (previousPath !== path &&
      isResidentProofPath(previousPath, resident.communityId, identity.uid)) {
    try {
      await bucket.file(previousPath).delete({ignoreNotFound: true});
    } catch (error) {
      console.warn("Previous resident identity proof cleanup failed.", {
        communityId: resident.communityId,
        residentId: identity.uid,
        error: error?.message,
      });
    }
  }
  return {status: "pending"};
}

function validateAdminProofInput(data, {review = false} = {}) {
  const allowed = new Set(review ? ["communityId", "userId", "decision", "reason"] : ["communityId", "userId"]);
  if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "A valid identity review request is required.");
  }
  const communityId = clean(data.communityId);
  const userId = clean(data.userId);
  const decision = clean(data.decision).toLowerCase();
  const reason = clean(data.reason).slice(0, 500);
  if (!communityId || !userId || (review && !["verified", "rejected"].includes(decision))) {
    throw new RegistrationError("invalid-argument", "Community, resident, and a valid decision are required.");
  }
  return {communityId, userId, decision, reason};
}

async function getResidentIdentityProofUrlCore({db, bucket, auth, data}) {
  const input = validateAdminProofInput(data);
  await requireOperationalAdmin(db, auth, input.communityId);
  const snapshot = await db.collection("users").doc(input.userId).get();
  const resident = snapshot.data();
  if (!snapshot.exists || resident?.role !== "resident" || resident?.communityId !== input.communityId) {
    throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
  }
  const path = clean(resident.identityProofStoragePath);
  if (!path.startsWith(`residentIdentityProofs/${input.communityId}/${input.userId}/`)) {
    throw new RegistrationError("not-found", "Identity proof was not found.");
  }
  const [url] = await bucket.file(path).getSignedUrl({action: "read", expires: Date.now() + 10 * 60 * 1000});
  return {url, contentType: clean(resident.identityProofContentType)};
}

async function reviewResidentIdentityProofCore({db, auth, data}) {
  const input = validateAdminProofInput(data, {review: true});
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const resident = snapshot.data();
    if (!snapshot.exists || resident?.role !== "resident" || resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (verificationStatus(resident) !== "pending" || !clean(resident.identityProofStoragePath)) {
      throw new RegistrationError("failed-precondition", "Only a pending uploaded identity proof can be reviewed.");
    }
    const canonicalType = canonicalResidentType(resident);
    const type = trustedResidentType(resident);
    if (!type) throw new RegistrationError("failed-precondition", "Resident type is ambiguous.");
    const verified = input.decision === "verified";
    const required = identityVerificationRequired(type, actor.community);
    let canRemainActive = false;
    if (resident.approvalStatus === "approved" && canonicalType != null &&
        (verified || !required)) {
      const flatId = clean(resident.flatId);
      const buildingId = clean(resident.buildingId);
      if (flatId && buildingId) {
        const flatSnapshot = await transaction.get(db.collection("flats").doc(flatId));
        const buildingSnapshot = await transaction.get(db.collection("buildings").doc(buildingId));
        validateBuildingAndFlat({
          buildingSnapshot,
          flatSnapshot,
          communityId: input.communityId,
          buildingId,
        });
        canRemainActive = resolveFlatOccupant(flatSnapshot.data()).uid === input.userId;
      }
    }
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      identityVerificationStatus: input.decision,
      identityVerified: verified,
      isActive: canRemainActive,
      status: canRemainActive ? "active" : "inactive",
      identityVerificationReviewedAt: timestamp,
      identityVerificationReviewedBy: actor.uid,
      identityVerificationRejectionReason: verified ? null : input.reason || null,
      updatedAt: timestamp,
    });
    return {status: input.decision};
  });
}

async function moveOutResidentCore({db, auth, data}) {
  const input = validateAdminProofInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  return db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || resident?.role !== "resident" || resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    const flatId = clean(resident.flatId);
    if (!flatId) throw new RegistrationError("failed-precondition", "Resident has no current unit assignment.");
    const flatRef = db.collection("flats").doc(flatId);
    const flatSnapshot = await transaction.get(flatRef);
    const flat = flatSnapshot.data();
    const buildingId = clean(resident.buildingId);
    if (!flatSnapshot.exists || !buildingId) {
      throw new RegistrationError("failed-precondition", "Resident unit assignment is incomplete.");
    }
    const buildingSnapshot = await transaction.get(db.collection("buildings").doc(buildingId));
    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId,
    });
    const type = canonicalResidentType(resident);
    if (!type) throw new RegistrationError("failed-precondition", "Resident type is invalid or ambiguous.");
    const occupant = resolveFlatOccupant(flat);
    const clearsOccupant = occupant.uid === input.userId;
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      isActive: false,
      status: "inactive",
      occupancyStatus: "moved_out",
      previousFlatId: flatId,
      previousUnitId: resident.unitId ?? null,
      previousFlatLabel: resident.flatLabel ?? null,
      previousBuildingId: buildingId,
      previousBuildingName: resident.buildingName ?? null,
      flatId: null,
      unitId: null,
      flatLabel: null,
      buildingId: null,
      buildingName: null,
      movedOutAt: timestamp,
      movedOutBy: actor.uid,
      updatedAt: timestamp,
    });
    if (clearsOccupant) {
      transaction.update(flatRef, {
        status: "vacant",
        residentUserId: null,
        residentUid: FieldValue.delete(),
        residentIds: FieldValue.delete(),
        residentId: null,
        residentName: null,
        ownershipType: null,
        updatedAt: timestamp,
      });
    }
    return {status: "moved_out", occupantCleared: clearsOccupant};
  });
}

module.exports = {
  VERIFICATION_STATUSES,
  canonicalResidentType,
  trustedResidentType,
  verificationStatus,
  ownerVerificationRequired,
  identityVerificationRequired,
  identityIsVerified,
  resolveFlatOccupant,
  residentOccupancyState,
  validateBuildingAndFlat,
  isResidentProofPath,
  operationalAccessFailure,
  approveResidentRegistrationCore,
  submitResidentIdentityProofCore,
  getResidentIdentityProofUrlCore,
  reviewResidentIdentityProofCore,
  moveOutResidentCore,
};
