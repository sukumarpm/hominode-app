const { normalizeLabel, unitLabel, assertSafelyVacant } = require('./unit_schema');
const { randomUUID } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { RegistrationError, verifiedPhoneAuth } = require("./register_resident");
const { normalizePhone, normalizeResidentOnboardingPhone } = require("./resident_bulk_import");
const { residentOnboardingId } = require("./resident_import_ids");
const { AUDIT_ACTIONS, writeAuditLogBestEffort } = require("./audit_log");

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
const SYSTEM_BILLING_ACTOR_ID = "system:billing-scheduler";

const clean = (value) => typeof value === "string" ? value.trim() : "";

async function auditResidentAction({
  db,
  actorUid,
  communityId,
  action,
  targetId,
  summary,
  metadata,
}) {
  await writeAuditLogBestEffort({
    db,
    actorUid,
    actorRole: "admin",
    communityId,
    action,
    targetType: "resident",
    targetId,
    summary,
    metadata,
  });
}

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
  return "verification_required";
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
    pointers.push({ field, value });
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
      pointers.push({ field: "residentIds", value });
    }
  }
  const values = new Set(pointers.map(({ value }) => value));
  if (values.size > 1) {
    throw new RegistrationError("failed-precondition", "Flat occupant references conflict.");
  }
  const uid = pointers[0]?.value ?? null;
  return {
    uid,
    usesCanonicalField: pointers.some(({ field }) => field === "residentUserId"),
    needsCanonicalization: uid != null &&
      (pointers.some(({ field }) => field !== "residentUserId") ||
        !pointers.some(({ field }) => field === "residentUserId")),
  };
}

function residentOccupancyState(profile, { communityId, flatId }) {
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

function validateBuildingAndFlat({ buildingSnapshot, flatSnapshot, communityId, buildingId }) {
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

async function requireOperationalAdmin(db, auth, communityId, transaction) {
  const { uid } = verifiedPhoneAuth(auth);
  const read = (ref) => transaction ? transaction.get(ref) : ref.get();
  const adminSnapshot = await read(db.collection("admins").doc(uid));
  const admin = adminSnapshot.data();
  if (!adminSnapshot.exists || admin?.uid !== uid || admin?.role !== "admin" ||
    admin?.isActive !== true || !Array.isArray(admin?.authorizedCommunityIds) ||
    !admin.authorizedCommunityIds.includes(communityId)) {
    throw new RegistrationError("permission-denied", "An authorized active Admin is required.");
  }
  const communitySnapshot = await read(db.collection("communities").doc(communityId));
  if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "Community is inactive or unavailable.");
  }
  return { uid, community: { id: communityId, ...communitySnapshot.data() } };
}

async function requireOperationalBillingSystem(db, communityId, transaction) {
  if (typeof communityId !== "string" || !communityId.trim() || communityId !== communityId.trim() ||
    Buffer.byteLength(communityId, "utf8") > 128 || /[\/\u0000-\u001f\u007f]/.test(communityId) ||
    [".", ".."].includes(communityId) || /^__.*__$/.test(communityId)) {
    throw new RegistrationError("invalid-argument", "A billing community is required.");
  }
  const communityRef = db.collection("communities").doc(communityId);
  const communitySnapshot = transaction ? await transaction.get(communityRef) : await communityRef.get();
  if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
    throw new RegistrationError("failed-precondition", "Community is inactive or unavailable.");
  }
  return { uid: SYSTEM_BILLING_ACTOR_ID, community: { ...communitySnapshot.data(), id: communityId } };
}

function operationalBillingSystemAuthority(db, _auth, communityId, transaction) {
  return requireOperationalBillingSystem(db, communityId, transaction);
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

function validateLifecycleInput(data, { allowReason = false } = {}) {
  const allowed = new Set(["communityId", "userId", ...(allowReason ? ["reason"] : [])]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
    Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "A valid resident lifecycle request is required.");
  }
  const communityId = clean(data.communityId);
  const userId = clean(data.userId);
  const reason = clean(data.reason).slice(0, 500);
  if (!communityId || !userId) {
    throw new RegistrationError("invalid-argument", "Community and resident are required.");
  }
  return { communityId, userId, reason };
}

function validateReassignmentInput(data) {
  const allowed = new Set(["communityId", "userId", "buildingId", "flatId"]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
    Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "A valid resident reassignment request is required.");
  }
  const result = Object.fromEntries([...allowed].map((key) => [key, clean(data[key])]));
  if (!result.communityId || !result.userId || !result.buildingId || !result.flatId) {
    throw new RegistrationError("invalid-argument", "Community, resident, building, and unit are required.");
  }
  return result;
}

function validateSingleOnboardingInput(data) {
  const allowed = new Set([
    "communityId",
    "residentName",
    "phoneNumber",
    "phoneCountryCode",
    "email",
    "residentType",
    "familyMembers",
    "buildingReference",
    "unitReference",
  ]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
    Object.keys(data).some((key) => !allowed.has(key))) {
    throw new RegistrationError("invalid-argument", "A valid resident onboarding request is required.");
  }
  const communityId = clean(data.communityId);
  const residentName = clean(data.residentName);
  const residentType = clean(data.residentType).toLowerCase();
  const email = clean(data.email).toLowerCase() || null;
  const familyMembers = data.familyMembers == null ? null : data.familyMembers;
  const buildingReference = clean(data.buildingReference) || null;
  const unitReference = clean(data.unitReference) || null;
  if (!communityId || residentName.length < 2 || residentName.length > 120 ||
    !RESIDENT_TYPES.has(residentType)) {
    throw new RegistrationError("invalid-argument", "Community, resident name, and resident type are required.");
  }
  if (email && (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
    throw new RegistrationError("invalid-argument", "Enter a valid email address.");
  }
  if (familyMembers != null && (!Number.isInteger(familyMembers) ||
    familyMembers < 1 || familyMembers > 100)) {
    throw new RegistrationError("invalid-argument", "Family members must be an integer from 1 to 100.");
  }
  if ((buildingReference?.length ?? 0) > 120 || (unitReference?.length ?? 0) > 120) {
    throw new RegistrationError("invalid-argument", "Building or unit reference is too long.");
  }
  const rawCountryCode = clean(data.phoneCountryCode).toUpperCase();
  const countryCode = /^[A-Z]{2}$/.test(rawCountryCode) ? rawCountryCode : null;
  let phoneNumber;
  try {
    phoneNumber = normalizeResidentOnboardingPhone(data.phoneNumber, countryCode);
  } catch (_) {
    throw new RegistrationError("invalid-argument", "Enter a valid resident phone number.");
  }
  return {
    communityId,
    residentName,
    phoneNumber,
    email,
    residentType,
    familyMembers,
    buildingReference,
    unitReference,
  };
}

async function approveResidentRegistrationCore({ db, auth, data }) {
  const input = validateApprovalInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const buildingRef = db.collection("buildings").doc(input.buildingId);
  const flatRef = db.collection("flats").doc(input.flatId);
  const sameFlatQuery = db.collection("users")
    .where("communityId", "==", input.communityId)
    .where("flatId", "==", input.flatId);
  const buildingFlatsQuery = db.collection("flats")
    .where("communityId", "==", input.communityId)
    .where("buildingId", "==", input.buildingId);

  const result = await db.runTransaction(async (transaction) => {
    const [userSnapshot, buildingSnapshot, flatSnapshot, sameFlatSnapshot, buildingFlatsSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(buildingRef),
      transaction.get(flatRef),
      transaction.get(sameFlatQuery),
      transaction.get(buildingFlatsQuery),
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

    const residentPhone =
      clean(resident.phoneNumber) ||
      clean(resident.phone);

    const expectedOnboardingId = residentPhone
      ? residentOnboardingId(input.communityId, residentPhone)
      : "";

    const safelyVacant =
      flat.status === "vacant" &&
      occupant.uid == null &&
      !clean(flat.reservedOnboardingId);

    const matchingReservation =
      flat.status === "reserved" &&
      occupant.uid == null &&
      expectedOnboardingId &&
      clean(flat.reservedOnboardingId) === expectedOnboardingId &&
      clean(resident.flatId) === input.flatId &&
      clean(resident.buildingId) === input.buildingId;

    const sameResidentRetry =
      flat.status === "occupied" &&
      occupant.uid === input.userId &&
      clean(resident.flatId) === input.flatId &&
      clean(resident.buildingId) === input.buildingId;

    if (!safelyVacant && !matchingReservation && !sameResidentRetry) {
      throw new RegistrationError(
        "failed-precondition",
        "This unit is not available or reserved for this resident.",
      );
    }
    if (sameFlatSnapshot.docs.some((doc) => doc.id !== input.userId)) {
      throw new RegistrationError(
        "failed-precondition",
        "This unit already has resident assignment data that must be resolved first.",
      );
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

      // Clear reservation metadata
      reservedOnboardingId: FieldValue.delete(),
      reservedForName: FieldValue.delete(),
      reservedForPhone: FieldValue.delete(),
      reservedResidentType: FieldValue.delete(),
      reservedBy: FieldValue.delete(),
      reservedAt: FieldValue.delete(),

      // Set real resident occupancy
      residentUserId: input.userId,
      residentUid: FieldValue.delete(),
      residentIds: FieldValue.delete(),
      residentId: resident.residentId ?? null,
      residentName: resident.name ?? resident.fullName ?? null,
      ownershipType: trustedType,
      updatedAt: timestamp,
    });
    transaction.update(buildingRef, buildingOccupancyUpdate(buildingFlatsSnapshot, {
      targetFlatId: input.flatId,
      targetStatus: "occupied",
      timestamp,
    }));
    return { status: "approved", isActive: active, identityVerificationRequired: false };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentApprove,
    targetId: input.userId,
    summary: "Resident registration approved.",
    metadata: {
      previousStatus: "pending",
      newStatus: "approved",
      buildingId: input.buildingId,
      flatId: input.flatId,
      residentType: input.residentType,
    },
  });
  return result;
}

function vacantFlatUpdate(timestamp) {
  return {
    status: "vacant",
    residentUserId: null,
    residentUid: FieldValue.delete(),
    residentIds: FieldValue.delete(),
    residentId: null,
    residentName: null,
    ownershipType: null,
    updatedAt: timestamp,
  };
}

function buildingOccupancyUpdate(
  flatSnapshot,
  { targetFlatId, targetStatus, timestamp },
) {
  let occupied = 0;
  let reserved = 0;
  let vacant = 0;

  for (const doc of flatSnapshot.docs) {
    const status =
      doc.id === targetFlatId
        ? targetStatus
        : clean(doc.data()?.status);

    if (status === "occupied") occupied += 1;
    if (status === "reserved") reserved += 1;
    if (status === "vacant") vacant += 1;
  }

  const total = flatSnapshot.docs.length;

  return {
    occupied,
    reserved,
    vacant,
    occupancyRate:
      total > 0
        ? Math.round((occupied / total) * 100)
        : 0,
    updatedAt: timestamp,
  };
}

// Admin creation may have provisioned the unit before mandatory identity approval.
// Legacy admin_direct profiles used approvalStatus=approved at creation time.
function adminRegistrationAwaitingIdentity(resident, community) {
  const type = trustedResidentType(resident);
  return resident?.creationSource === "admin_direct" &&
    ["pending", "approved"].includes(resident.approvalStatus) &&
    typeof resident.isActive === "boolean" && resident.identityVerified === false &&
    ["verification_required", "pending", "rejected"].includes(resident.identityVerificationStatus) &&
    resident.registrationCompletedAt == null &&
    !["deleted", "completed", "rejected"].includes(resident.status) &&
    !["moved_out", "suspended", "rejected"].includes(resident.occupancyStatus) &&
    type != null && identityVerificationRequired(type, community);
}

function rejectingRegistrationAllowed(resident, community) {
  if (!resident || resident.identityVerified === true || resident.identityVerificationStatus === "verified" ||
      resident.registrationCompletedAt != null || ["deleted", "completed"].includes(resident.status)) return false;
  return adminRegistrationAwaitingIdentity(resident, community) ||
    (resident.creationSource !== "admin_direct" && resident.approvalStatus === "pending" && resident.isActive === false);
}

// New eligibility is broader than the old inactive-pending-only contract, so
// apply the existing financial review checks before releasing an allocated unit.
async function assertAdminRegistrationCanBeCancelled(db, transaction, uid, communityId) {
  // Lazy import avoids the account-deletion module's identity-helper dependency.
  const { financialHandoverEvidence } = require("./account_deletion_requests");
  const evidence = await financialHandoverEvidence({db, tx: transaction, uid, communityId, requestId: `registration:${uid}`});
  if (evidence.outstandingMinor !== 0) throw new RegistrationError("failed-precondition", "Outstanding dues must be settled before registration rejection.");
  const deletions = await transaction.get(db.collection("accountDeletionRequests").where("uid", "==", uid).limit(1));
  if (deletions.docs.length) throw new RegistrationError("failed-precondition", "An account-deletion request already exists; use that workflow instead.");
  await assertNoActiveSos(db, transaction, uid, communityId, "rejecting registration");
}

function releaseAdminRegistrationAssignment({transaction, flat, flatRef, resident, userId, sameFlatSnapshot, buildingRef, buildingFlatsSnapshot}) {
  const pointers = ["residentUserId", "residentUid", "residentId"];
  const owns = (field, value) => value === userId || field === "residentId" && clean(resident.residentId) && value === resident.residentId;
  if (pointers.some((field) => flat[field] != null && typeof flat[field] !== "string") ||
      flat.residentIds != null && (!Array.isArray(flat.residentIds) || flat.residentIds.some((id) => typeof id !== "string" || !id))) {
    throw new RegistrationError("failed-precondition", "Unit assignment references are malformed.");
  }
  const mine = pointers.filter((field) => owns(field, flat[field]));
  const inList = flat.residentIds?.includes(userId);
  if (!mine.length && !inList) return false; // Already released or reassigned; never vacate a new occupant.
  if (!["occupied", "vacant"].includes(flat.status) || clean(flat.reservedOnboardingId)) {
    throw new RegistrationError("failed-precondition", "Conflicting unit status or reservation must be resolved first.");
  }
  const others = pointers.some((field) => clean(flat[field]) && !owns(field, flat[field])) ||
    flat.residentIds?.some((id) => id !== userId) || sameFlatSnapshot.docs.some((doc) => doc.id !== userId);
  if (others && flat.status !== "occupied") throw new RegistrationError("failed-precondition", "Shared assignment status is inconsistent.");
  const timestamp = FieldValue.serverTimestamp();
  const patch = {updatedAt: timestamp};
  for (const field of mine) patch[field] = null;
  if (inList) patch.residentIds = flat.residentIds.filter((id) => id !== userId);
  if (!others) Object.assign(patch, {status: "vacant", residentName: null, ownershipType: null});
  transaction.update(flatRef, patch);
  transaction.update(buildingRef, buildingOccupancyUpdate(buildingFlatsSnapshot, {targetFlatId: flatRef.id, targetStatus: patch.status || flat.status, timestamp}));
  return true;
}

async function rejectResidentRegistrationCore({ db, auth, data }) {
  const input = validateLifecycleInput(data, { allowReason: true });
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const result = await db.runTransaction(async (transaction) => {
    const currentActor = await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || resident?.role !== "resident" ||
      resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (resident.approvalStatus === "rejected" && resident.isActive === false) {
      return { status: "rejected", staleOccupantCleared: false, idempotent: true };
    }
    if (!rejectingRegistrationAllowed(resident, currentActor.community)) {
      throw new RegistrationError("failed-precondition", "Only a registration awaiting approval can be finally rejected; verified Residents must use their normal account lifecycle.");
    }
    const adminAwaiting = adminRegistrationAwaitingIdentity(resident, currentActor.community);
    if (adminAwaiting) await assertAdminRegistrationCanBeCancelled(db, transaction, input.userId, input.communityId);

    let staleOccupantCleared = false;
    const flatId = clean(resident.flatId);
    const buildingId = clean(resident.buildingId);
    if (flatId || buildingId) {
      if (!flatId || !buildingId) {
        throw new RegistrationError("failed-precondition", "Pending resident assignment data is incomplete.");
      }
      const flatRef = db.collection("flats").doc(flatId);
      const sameFlatQuery = db.collection("users")
        .where("communityId", "==", input.communityId)
        .where("flatId", "==", flatId);
      const [flatSnapshot, buildingSnapshot, sameFlatSnapshot, buildingFlatsSnapshot] = await Promise.all([
        transaction.get(flatRef),
        transaction.get(db.collection("buildings").doc(buildingId)),
        transaction.get(sameFlatQuery),
        transaction.get(db.collection("flats").where("communityId", "==", input.communityId).where("buildingId", "==", buildingId)),
      ]);
      validateBuildingAndFlat({
        buildingSnapshot,
        flatSnapshot,
        communityId: input.communityId,
        buildingId,
      });
      const flat = flatSnapshot.data();
      if (adminAwaiting && flat.status !== "reserved") {
        staleOccupantCleared = releaseAdminRegistrationAssignment({transaction, flat, flatRef, resident, userId: input.userId,
          sameFlatSnapshot, buildingRef: db.collection("buildings").doc(buildingId), buildingFlatsSnapshot});
      } else {
        const occupant = resolveFlatOccupant(flat);
        const phone = clean(resident.phoneNumber) || clean(resident.phone);
        const onboardingId = phone ? residentOnboardingId(input.communityId, phone) : "";
        const matchingReservation = flat.status === "reserved" && occupant.uid == null &&
          onboardingId && clean(flat.reservedOnboardingId) === onboardingId;
        const matchingLegacyOccupant = occupant.uid == null && clean(flat.residentId) &&
          (flat.residentId === input.userId || flat.residentId === resident.residentId);
        if (occupant.uid === input.userId || matchingLegacyOccupant || matchingReservation) {
          if (clean(flat.residentId) && flat.residentId !== input.userId && flat.residentId !== resident.residentId) {
            throw new RegistrationError("failed-precondition", "Unit residentId belongs to another resident.");
          }
          if (!matchingReservation && (!["vacant", "occupied"].includes(flat.status) || clean(flat.reservedOnboardingId))) {
            throw new RegistrationError("failed-precondition", "Stale unit occupancy cannot be reconciled safely.");
          }
          if (sameFlatSnapshot.docs.some((doc) => doc.id !== input.userId)) {
            throw new RegistrationError("failed-precondition", "Stale unit occupancy conflicts with another resident assignment.");
          }
          const timestamp = FieldValue.serverTimestamp();
          if (matchingReservation) {
            const onboardingRef = db.collection("residentOnboarding").doc(onboardingId);
            const onboardingSnapshot = await transaction.get(onboardingRef);
            if (onboardingSnapshot.exists) {
              const onboarding = onboardingSnapshot.data();
              if (onboarding.communityId !== input.communityId || onboarding.flatId !== flatId ||
                  onboarding.buildingId !== buildingId || onboarding.claimedByUid !== input.userId) {
                throw new RegistrationError("failed-precondition", "Reservation ownership changed before rejection.");
              }
              transaction.update(onboardingRef, {
                status: "rejected", approvalStatus: "rejected", flatId: FieldValue.delete(),
                buildingId: FieldValue.delete(), unitId: FieldValue.delete(), flatLabel: FieldValue.delete(),
                buildingReference: FieldValue.delete(), unitReference: FieldValue.delete(), updatedAt: timestamp,
              });
            }
          }
          transaction.update(flatRef, {
            ...vacantFlatUpdate(timestamp),
            ...Object.fromEntries(["reservedOnboardingId", "reservedForName", "reservedForPhone",
              "reservedResidentType", "reservedBy", "reservedAt"].map((field) => [field, FieldValue.delete()])),
          });
          transaction.update(db.collection("buildings").doc(buildingId), buildingOccupancyUpdate(
            buildingFlatsSnapshot, { targetFlatId: flatId, targetStatus: "vacant", timestamp },
          ));
          staleOccupantCleared = true;
        }
      }
    }

    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      approvalStatus: "rejected",
      isActive: false,
      status: "rejected",
      occupancyStatus: "rejected",
      flatId: FieldValue.delete(),
      buildingId: FieldValue.delete(),
      unitId: FieldValue.delete(),
      flatLabel: FieldValue.delete(),
      rejectedAt: timestamp,
      rejectedBy: actor.uid,
      rejectedReason: input.reason || null,
      updatedAt: timestamp,
    });
    return { status: "rejected", staleOccupantCleared, previousStatus: resident.approvalStatus };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentReject,
    targetId: input.userId,
    summary: "Resident registration rejected.",
    metadata: {
      previousStatus: result.previousStatus || "rejected",
      newStatus: "rejected",
      reasonProvided: Boolean(input.reason),
      staleOccupantCleared: result.staleOccupantCleared,
    },
  });
  return result;
}

async function deactivateResidentCore({ db, auth, data }) {
  const input = validateLifecycleInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || resident?.role !== "resident" ||
      resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    const flatId = clean(resident.flatId);
    const buildingId = clean(resident.buildingId);
    if (!flatId || !buildingId ||
      residentOccupancyState(resident, { communityId: input.communityId, flatId }) !== "active") {
      throw new RegistrationError("failed-precondition", "Only a valid active resident can be deactivated.");
    }
    const [flatSnapshot, buildingSnapshot] = await Promise.all([
      transaction.get(db.collection("flats").doc(flatId)),
      transaction.get(db.collection("buildings").doc(buildingId)),
    ]);
    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId,
    });
    const flat = flatSnapshot.data();
    if (flat.status !== "occupied" || resolveFlatOccupant(flat).uid !== input.userId) {
      throw new RegistrationError(
        "failed-precondition",
        "Resident cannot be suspended because the unit occupant does not match.",
      );
    }
    await assertNoActiveSos(
      db,
      transaction,
      input.userId,
      input.communityId,
      "deactivating the resident",
    );
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      isActive: false,
      status: "inactive",
      occupancyStatus: "suspended",
      deactivatedAt: timestamp,
      deactivatedBy: actor.uid,
      updatedAt: timestamp,
    });
    return { status: "inactive", occupancyStatus: "suspended", occupantRetained: true };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentDeactivate,
    targetId: input.userId,
    summary: "Resident access deactivated.",
    metadata: { previousStatus: "active", newStatus: "inactive" },
  });
  return result;
}

async function reactivateResidentCore({ db, auth, data }) {
  const input = validateLifecycleInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || resident?.role !== "resident" ||
      resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (resident.approvalStatus !== "approved" || resident.isActive !== false ||
      clean(resident.status) !== "inactive" ||
      clean(resident.occupancyStatus) !== "suspended") {
      throw new RegistrationError("failed-precondition", "Only a suspended approved resident can be reactivated.");
    }
    const residentType = trustedResidentType(resident);
    if (!residentType ||
      (identityVerificationRequired(residentType, actor.community) && !identityIsVerified(resident))) {
      throw new RegistrationError(
        "failed-precondition",
        "Resident identity and owner or tenant eligibility must be valid before reactivation.",
      );
    }
    const flatId = clean(resident.flatId);
    const buildingId = clean(resident.buildingId);
    if (!flatId || !buildingId) {
      throw new RegistrationError("failed-precondition", "Resident has no current unit assignment.");
    }
    const flatRef = db.collection("flats").doc(flatId);
    const sameFlatQuery = db.collection("users")
      .where("communityId", "==", input.communityId)
      .where("flatId", "==", flatId);
    const [flatSnapshot, buildingSnapshot, sameFlatSnapshot] = await Promise.all([
      transaction.get(flatRef),
      transaction.get(db.collection("buildings").doc(buildingId)),
      transaction.get(sameFlatQuery),
    ]);
    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId,
    });
    const flat = flatSnapshot.data();
    if (flat.status !== "occupied" || resolveFlatOccupant(flat).uid !== input.userId) {
      throw new RegistrationError(
        "failed-precondition",
        "Resident cannot be reactivated because the unit occupant does not match.",
      );
    }
    for (const doc of sameFlatSnapshot.docs) {
      if (doc.id === input.userId) continue;
      const otherState = residentOccupancyState(doc.data(), {
        communityId: input.communityId,
        flatId,
      });
      if (otherState === "active") {
        throw new RegistrationError("failed-precondition", "This unit already has an active resident occupant.");
      }
      if (otherState === "ambiguous") {
        throw new RegistrationError("failed-precondition", "This unit has ambiguous resident assignment data.");
      }
    }
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      residentType,
      ownershipType: residentType,
      isActive: true,
      status: "active",
      occupancyStatus: "current",
      reactivatedAt: timestamp,
      reactivatedBy: actor.uid,
      updatedAt: timestamp,
    });
    return { status: "active", occupancyStatus: "current" };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentReactivate,
    targetId: input.userId,
    summary: "Resident access reactivated.",
    metadata: { previousStatus: "inactive", newStatus: "active" },
  });
  return result;
}

async function reassignResidentCore({ db, auth, data, transactionExtras }) {
  const input = validateReassignmentInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const buildingRef = db.collection("buildings").doc(input.buildingId);
  const flatRef = db.collection("flats").doc(input.flatId);
  const sameFlatQuery = db.collection("users")
    .where("communityId", "==", input.communityId)
    .where("flatId", "==", input.flatId);
  const buildingFlatsQuery = db.collection("flats")
    .where("communityId", "==", input.communityId)
    .where("buildingId", "==", input.buildingId);

  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || clean(resident?.uid) !== input.userId ||
      resident?.role !== "resident" ||
      resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (resident.approvalStatus !== "approved" || resident.isActive !== false ||
      clean(resident.status) !== "inactive" ||
      clean(resident.occupancyStatus) !== "moved_out" ||
      clean(resident.flatId) || clean(resident.buildingId)) {
      throw new RegistrationError(
        "failed-precondition",
        "Only a previously moved-out resident without a current assignment can be reassigned.",
      );
    }
    const residentType = trustedResidentType(resident);
    if (!residentType ||
      (identityVerificationRequired(residentType, actor.community) && !identityIsVerified(resident))) {
      throw new RegistrationError(
        "failed-precondition",
        "Resident identity and owner or tenant eligibility must be valid before reassignment.",
      );
    }
    const phoneNumber = clean(resident.phoneNumber || resident.phone);
    if (!phoneNumber) {
      throw new RegistrationError("failed-precondition", "Resident phone identity is missing.");
    }
    const phoneQuery = db.collection("users")
      .where("communityId", "==", input.communityId)
      .where("phoneNumber", "==", phoneNumber);
    const legacyPhoneQuery = db.collection("users")
      .where("communityId", "==", input.communityId)
      .where("phone", "==", phoneNumber);
    const [buildingSnapshot, flatSnapshot, sameFlatSnapshot, phoneUsers, legacyPhoneUsers, buildingFlatsSnapshot] =
      await Promise.all([
        transaction.get(buildingRef),
        transaction.get(flatRef),
        transaction.get(sameFlatQuery),
        transaction.get(phoneQuery),
        transaction.get(legacyPhoneQuery),
        transaction.get(buildingFlatsQuery),
      ]);
    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId: input.buildingId,
    });

    const flat = flatSnapshot.data();
    const occupant = resolveFlatOccupant(flat);
    if (flat.status !== "vacant" || occupant.uid != null) {
      throw new RegistrationError("failed-precondition", "This unit is not safely vacant.");
    }
    if (sameFlatSnapshot.docs.some((doc) => doc.id !== input.userId)) {
      throw new RegistrationError(
        "failed-precondition",
        "This unit already has resident assignment data that must be resolved first.",
      );
    }
    const duplicatePhoneProfiles = new Map();
    for (const doc of [...phoneUsers.docs, ...legacyPhoneUsers.docs]) {
      if (doc.id !== input.userId) duplicatePhoneProfiles.set(doc.id, doc.data());
    }
    if ([...duplicatePhoneProfiles.values()].some((profile) =>
      profile?.role === "resident" && profile?.communityId === input.communityId &&
      profile?.approvalStatus === "approved" && profile?.isActive === true)) {
      throw new RegistrationError(
        "failed-precondition",
        "Another active resident profile uses this phone identity.",
      );
    }
    await assertNoActiveSos(
      db,
      transaction,
      input.userId,
      input.communityId,
      "reassigning the resident",
    );
    assertSafelyVacant(flat);
    const extraWrites = transactionExtras ? await transactionExtras(transaction) : null;
    const timestamp = FieldValue.serverTimestamp();
    const building = buildingSnapshot.data();
    transaction.update(userRef, {
      residentType,
      ownershipType: residentType,
      isActive: true,
      status: "active",
      occupancyStatus: "current",
      buildingId: input.buildingId,
      buildingName: clean(building?.buildingName || building?.name) || null,
      flatId: input.flatId,
      unitId: clean(flat?.unitId || flat?.flatId) || input.flatId,
      flatLabel: clean(flat?.flatLabel || flat?.flatId) || input.flatId,
      reassignedAt: timestamp,
      reassignedBy: actor.uid,
      reactivatedAt: timestamp,
      reactivatedBy: actor.uid,
      reassignmentCount: FieldValue.increment(1),
      updatedAt: timestamp,
    });
    transaction.update(flatRef, {
      status: "occupied",
      residentUserId: input.userId,
      residentUid: FieldValue.delete(),
      residentIds: FieldValue.delete(),
      residentId: resident.residentId ?? null,
      residentName: resident.name ?? resident.fullName ?? null,
      ownershipType: residentType,
      updatedAt: timestamp,
    });
    transaction.update(buildingRef, buildingOccupancyUpdate(buildingFlatsSnapshot, {
      targetFlatId: input.flatId,
      targetStatus: "occupied",
      timestamp,
    }));
    if (extraWrites) extraWrites();
    return { status: "active", occupancyStatus: "current", userId: input.userId };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentReassign,
    targetId: input.userId,
    summary: "Moved-out resident reassigned to a unit.",
    metadata: {
      previousStatus: "moved_out",
      newStatus: "active",
      buildingId: input.buildingId,
      flatId: input.flatId,
    },
  });
  return result;
}

function validateOnboardingAssignmentInput(data) {
  const communityId = clean(data?.communityId);
  const onboardingId = clean(data?.onboardingId);
  const buildingId = clean(data?.buildingId);
  const flatId = clean(data?.flatId);

  if (!communityId || !onboardingId || !buildingId || !flatId) {
    throw new RegistrationError(
      "invalid-argument",
      "Community, onboarding resident, building, and unit are required.",
    );
  }

  return {
    communityId,
    onboardingId,
    buildingId,
    flatId,
  };
}
async function listAssignableResidentOnboardingsCore({ db, auth, data }) {
  const communityId = clean(data?.communityId);

  if (!communityId) {
    throw new RegistrationError(
      "invalid-argument",
      "Community is required.",
    );
  }

  await requireOperationalAdmin(db, auth, communityId);

  const snapshot = await db
    .collection("residentOnboarding")
    .where("communityId", "==", communityId)
    .where("approvalStatus", "==", "pending")
    .get();

  const residents = snapshot.docs
    .map((doc) => {
      const value = doc.data();

      return {
        id: doc.id,
        residentName: clean(value?.residentName),
        phoneNumber: clean(value?.phoneNumber),
        residentType: clean(value?.residentType),
        status: clean(value?.status),
        claimedByUid: value?.claimedByUid ?? null,
        buildingReference: clean(value?.buildingReference),
        unitReference: clean(value?.unitReference),
      };
    })
    .filter((resident) =>
      resident.status === "pending_registration" &&
      resident.claimedByUid == null &&
      !resident.buildingReference &&
      !resident.unitReference
    );

  return {
    residents,
  };
}
async function assignResidentOnboardingToFlatCore({ db, auth, data }) {
  const input = validateOnboardingAssignmentInput(data);

  const actor = await requireOperationalAdmin(
    db,
    auth,
    input.communityId,
  );

  const onboardingRef = db
    .collection("residentOnboarding")
    .doc(input.onboardingId);

  const buildingRef = db
    .collection("buildings")
    .doc(input.buildingId);

  const flatRef = db
    .collection("flats")
    .doc(input.flatId);
  const buildingFlatsQuery = db
    .collection("flats")
    .where("communityId", "==", input.communityId)
    .where("buildingId", "==", input.buildingId);

  return db.runTransaction(async (transaction) => {
    const [
      onboardingSnapshot,
      buildingSnapshot,
      flatSnapshot,
      buildingFlatsSnapshot,
    ] = await Promise.all([
      transaction.get(onboardingRef),
      transaction.get(buildingRef),
      transaction.get(flatRef),
      transaction.get(buildingFlatsQuery),
    ]);

    if (!onboardingSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Resident onboarding record was not found.",
      );
    }

    const onboarding = onboardingSnapshot.data();

    if (
      onboarding?.communityId !== input.communityId ||
      onboarding?.approvalStatus !== "pending" ||
      onboarding?.status !== "pending_registration" ||
      onboarding?.claimedByUid != null
    ) {
      throw new RegistrationError(
        "failed-precondition",
        "Only an unclaimed pending onboarding resident can be assigned.",
      );
    }

    if (
      clean(onboarding?.buildingReference) ||
      clean(onboarding?.unitReference)
    ) {
      throw new RegistrationError(
        "failed-precondition",
        "This onboarding resident is already assigned to a unit.",
      );
    }

    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId: input.buildingId,
    });

    const flat = flatSnapshot.data();
    const occupant = resolveFlatOccupant(flat);

    if (flat?.status !== "vacant" || occupant.uid != null) {
      throw new RegistrationError(
        "failed-precondition",
        "This unit is not safely vacant.",
      );
    }

    assertSafelyVacant(flat);

    const buildingReference =
      clean(buildingSnapshot.data()?.buildingName) ||
      clean(buildingSnapshot.data()?.name) ||
      input.buildingId;

    const unitReference =
      clean(flat?.flatLabel) ||
      clean(flat?.flatId) ||
      clean(flat?.unitId) ||
      input.flatId;

    const timestamp = FieldValue.serverTimestamp();

    transaction.update(onboardingRef, {
      buildingReference,
      unitReference,
      buildingId: input.buildingId,
      buildingName: buildingReference,
      flatId: input.flatId,
      unitId:
        clean(flat?.unitId) ||
        clean(flat?.flatId) ||
        input.flatId,
      flatLabel:
        clean(flat?.flatLabel) ||
        clean(flat?.flatId) ||
        unitReference,
      updatedAt: timestamp,
    });

    transaction.update(flatRef, {
      status: "reserved",
      reservedOnboardingId: input.onboardingId,
      reservedForName: clean(onboarding?.residentName) || null,
      reservedForPhone: clean(onboarding?.phoneNumber) || null,
      reservedResidentType: clean(onboarding?.residentType) || null,
      reservedBy: actor.uid,
      reservedAt: timestamp,
      updatedAt: timestamp,
    });
    transaction.update(
      buildingRef,
      buildingOccupancyUpdate(
        buildingFlatsSnapshot,
        {
          targetFlatId: input.flatId,
          targetStatus: "reserved",
          timestamp,
        },
      ),
    );

    return {
      status: "assigned",
      onboardingId: input.onboardingId,
      buildingReference,
      unitReference,
    };
  });
}
async function renameUnitCore({ db, auth, data }) {
  const communityId = clean(data?.communityId);
  const buildingId = clean(data?.buildingId);
  const flatId = clean(data?.flatId);
  const newLabel = clean(data?.newLabel);

  if (!communityId || !buildingId || !flatId || !newLabel || newLabel.length > 120) {
    throw new RegistrationError(
      "invalid-argument",
      "Community, building, unit, and new unit name are required."
    );
  }

  await requireOperationalAdmin(
    db,
    auth,
    communityId
  );

  const flatRef = db.collection("flats").doc(flatId);

  return db.runTransaction(async (transaction) => {
    // ---------------------------------------------------------
    // STEP 1: ALL READS FIRST
    // ---------------------------------------------------------

    const flatSnapshot = await transaction.get(flatRef);

    if (!flatSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Unit not found."
      );
    }

    const flat = flatSnapshot.data();

    if (
      flat?.communityId !== communityId ||
      flat?.buildingId !== buildingId
    ) {
      throw new RegistrationError(
        "permission-denied",
        "Unit does not belong to the selected building/community."
      );
    }

    const oldLabel = clean(
      flat?.flatLabel ||
      flat?.flatId ||
      flat?.unitId
    );

    const duplicateQuery = db
      .collection("flats")
      .where("communityId", "==", communityId)
      .where("buildingId", "==", buildingId);

    const onboardingQuery = db
      .collection("residentOnboarding")
      .where("communityId", "==", communityId)
      .where("buildingId", "==", buildingId)
      .where("flatId", "==", flatId);

    const usersQuery = db
      .collection("users")
      .where("communityId", "==", communityId)
      .where("flatId", "==", flatId);

    const [
      duplicateSnapshot,
      onboardingSnapshot,
      usersSnapshot,
    ] = await Promise.all([
      transaction.get(duplicateQuery),
      transaction.get(onboardingQuery),
      transaction.get(usersQuery),
    ]);

    const duplicateExists = duplicateSnapshot.docs.some(
      (doc) => doc.id !== flatId && normalizeLabel(unitLabel(doc.data())) === normalizeLabel(newLabel)
    );

    if (duplicateExists) {
      throw new RegistrationError(
        "already-exists",
        `Another unit in this building already uses "${newLabel}".`
      );
    }

    // ---------------------------------------------------------
    // STEP 2: WRITES ONLY AFTER ALL READS
    // ---------------------------------------------------------

    if (1 + onboardingSnapshot.docs.length + usersSnapshot.docs.length > 500) {
      throw new RegistrationError('resource-exhausted', 'Unit rename exceeds the 500-write atomic limit.');
    }
    transaction.update(flatRef, {
      unitLabelNormalized: normalizeLabel(newLabel),
      flatLabel: newLabel,
      flatId: newLabel,
      unitId: newLabel,
      updatedAt: FieldValue.serverTimestamp(),
    });

    for (const doc of onboardingSnapshot.docs) {
      transaction.update(doc.ref, {
        flatLabel: newLabel,
        unitId: newLabel,
        unitReference: newLabel,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    for (const doc of usersSnapshot.docs) {
      transaction.update(doc.ref, {
        flatLabel: newLabel,
        unitId: newLabel,
        unitReference: newLabel,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      success: true,
      flatId,
      oldLabel,
      newLabel,
      onboardingUpdated: onboardingSnapshot.size,
      usersUpdated: usersSnapshot.size,
    };
  });
}

async function assertNoActiveSos(
  db,
  transaction,
  userId,
  communityId,
  action,
) {
  const activeRef = db.collection("sosActive").doc(userId);
  const activeSnapshot = await transaction.get(activeRef);

  if (!activeSnapshot.exists) return;

  const active = activeSnapshot.data();

  if (
    clean(active?.residentUid) !== userId ||
    clean(active?.communityId) !== communityId ||
    !clean(active?.alertId)
  ) {
    throw new RegistrationError(
      "failed-precondition",
      "The resident has an inconsistent active emergency record. Resolve the SOS before continuing.",
    );
  }

  throw new RegistrationError(
    "failed-precondition",
    `The resident has an active SOS. Resolve or cancel the emergency before ${action}.`,
  );
}

async function cancelResidentOnboardingReservationCore({ db, auth, data }) {
  const input = validateOnboardingAssignmentInput(data);

  await requireOperationalAdmin(
    db,
    auth,
    input.communityId,
  );

  const onboardingRef = db
    .collection("residentOnboarding")
    .doc(input.onboardingId);

  const buildingRef = db
    .collection("buildings")
    .doc(input.buildingId);

  const flatRef = db
    .collection("flats")
    .doc(input.flatId);

  const buildingFlatsQuery = db
    .collection("flats")
    .where("communityId", "==", input.communityId)
    .where("buildingId", "==", input.buildingId);

  return db.runTransaction(async (transaction) => {
    const [
      onboardingSnapshot,
      buildingSnapshot,
      flatSnapshot,
      buildingFlatsSnapshot,
    ] = await Promise.all([
      transaction.get(onboardingRef),
      transaction.get(buildingRef),
      transaction.get(flatRef),
      transaction.get(buildingFlatsQuery),
    ]);

    if (!onboardingSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Resident onboarding record was not found.",
      );
    }

    const onboarding = onboardingSnapshot.data();

    if (
      onboarding?.communityId !== input.communityId ||
      onboarding?.approvalStatus !== "pending" ||
      onboarding?.status !== "pending_registration" ||
      onboarding?.claimedByUid != null
    ) {
      throw new RegistrationError(
        "failed-precondition",
        "Only an unclaimed pending onboarding reservation can be cancelled.",
      );
    }

    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId: input.buildingId,
    });

    const flat = flatSnapshot.data();
    const occupant = resolveFlatOccupant(flat);

    const reservationMatches =
      flat?.status === "reserved" &&
      occupant.uid == null &&
      clean(flat?.reservedOnboardingId) === input.onboardingId &&
      clean(onboarding?.buildingId) === input.buildingId &&
      clean(onboarding?.flatId) === input.flatId;

    if (!reservationMatches) {
      throw new RegistrationError(
        "failed-precondition",
        "The unit reservation does not match this pending onboarding resident.",
      );
    }

    const timestamp = FieldValue.serverTimestamp();

    transaction.update(onboardingRef, {
      buildingReference: FieldValue.delete(),
      unitReference: FieldValue.delete(),

      buildingId: FieldValue.delete(),
      buildingName: FieldValue.delete(),

      flatId: FieldValue.delete(),
      unitId: FieldValue.delete(),
      flatLabel: FieldValue.delete(),

      updatedAt: timestamp,
    });

    // Release the reserved unit.
    transaction.update(flatRef, {
      status: "vacant",

      residentId: null,
      residentName: null,
      residentUserId: null,

      reservedOnboardingId: FieldValue.delete(),
      reservedForName: FieldValue.delete(),
      reservedResidentType: FieldValue.delete(),
      reservedBy: FieldValue.delete(),
      reservedAt: FieldValue.delete(),
      reservedForPhone: FieldValue.delete(),

      updatedAt: timestamp,
    });

    // Recalculate building occupancy/reservation counters.
    transaction.update(
      buildingRef,
      buildingOccupancyUpdate(
        buildingFlatsSnapshot,
        {
          targetFlatId: input.flatId,
          targetStatus: "vacant",
          timestamp,
        },
      ),
    );

    return {
      status: "released",
      onboardingId: input.onboardingId,
      buildingId: input.buildingId,
      flatId: input.flatId,
    };
  });
}
// Admin provisioning assigns the unit; required identity approval completes onboarding.
// Bind the profile to its Firebase phone UID, but issue no token or OTP claim.
async function createAdminResidentCore({ db, authAdmin, auth, data }) {
  const {buildingId, flatId, ...contact} = data ?? {};
  const input = validateSingleOnboardingInput(contact);
  if (typeof buildingId !== "string" || !buildingId.trim() || typeof flatId !== "string" || !flatId.trim()) {
    throw new RegistrationError("invalid-argument", "Select a building and unit for this resident.");
  }
  await requireOperationalAdmin(db, auth, input.communityId);
  const buildingRef = db.collection("buildings").doc(buildingId.trim());
  const flatRef = db.collection("flats").doc(flatId.trim());
  const scoped = (name) => db.collection(name).where("communityId", "==", input.communityId);
  async function preflight(tx, uid = null) {
    const read = (ref) => tx ? tx.get(ref) : ref.get();
    const [actor, building, flat, users, pending, flats, ...profiles] = await Promise.all([
      requireOperationalAdmin(db, auth, input.communityId, tx), read(buildingRef), read(flatRef),
      read(scoped("users")), read(scoped("residentOnboarding")),
      read(scoped("flats").where("buildingId", "==", buildingId.trim())),
      ...(uid ? ["users", "admins", "securityStaff"].map((name) => read(db.collection(name).doc(uid))) : []),
    ]);
    validateBuildingAndFlat({buildingSnapshot: building, flatSnapshot: flat, communityId: input.communityId, buildingId: buildingId.trim()});
    if (building.data()?.isActive === false) throw new RegistrationError("failed-precondition", "This building is inactive.");
    const matches = (record) => [record.phoneNumber, record.phone].some((number) => {
      try { return normalizeResidentOnboardingPhone(number, clean(record.phoneCountryCode || data.phoneCountryCode).toUpperCase() || null) === input.phoneNumber; }
      catch (_) { return false; }
    });
    const candidate = !uid ? users.docs.find((doc) => matches(doc.data()) && doc.data()?.creationSource === "admin_direct") : null;
    const targetUid = uid || candidate?.id;
    const existing = profiles[0]?.data() ?? candidate?.data();
    const retry = existing?.creationSource === "admin_direct" && existing.uid === targetUid && existing.role === "resident" &&
      existing.communityId === input.communityId && existing.phoneNumber === input.phoneNumber &&
      existing.buildingId === buildingId.trim() && existing.flatId === flatId.trim() &&
      existing.name === input.residentName && existing.residentType === input.residentType &&
      (existing.email ?? null) === input.email && existing.familyMembers === input.familyMembers;
    if (profiles.slice(1).some((profile) => profile.exists)) throw new RegistrationError("already-exists", "This phone belongs to another account role.");
    if (profiles[0]?.exists && !retry || users.docs.some((doc) => !(retry && doc.id === targetUid) && matches(doc.data())) ||
        pending.docs.some((doc) => matches(doc.data()))) {
      throw new RegistrationError("already-exists", "This resident phone already has a profile or registration. Use the existing resident workflow.");
    }
    if (retry && flat.data()?.status === "occupied" && resolveFlatOccupant(flat.data()).uid === targetUid) return {retry: true, actor};
    if (users.docs.some((doc) => clean(doc.data()?.flatId) === flatId.trim()) ||
        pending.docs.some((doc) => clean(doc.data()?.flatId) === flatId.trim())) {
      throw new RegistrationError("failed-precondition", "This unit already has a resident or reservation.");
    }
    assertSafelyVacant(flat.data());
    if (flat.data()?.status !== "vacant") throw new RegistrationError("failed-precondition", "This unit is not vacant.");
    return {actor, building: building.data(), flat: flat.data(), flats};
  }
  // Follow the existing Admin phone provisioning pattern: resolve or create the
  // Auth UID only after authorization, phone, duplication and unit preflight.
  await preflight(null);
  let user;
  try { user = await authAdmin.getUserByPhoneNumber(input.phoneNumber); }
  catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    try { user = await authAdmin.createUser({phoneNumber: input.phoneNumber, disabled: false}); }
    catch (creationError) {
      if (creationError?.code !== "auth/phone-number-already-exists") throw creationError;
      user = await authAdmin.getUserByPhoneNumber(input.phoneNumber);
    }
  }
  if (!user?.uid || user.phoneNumber !== input.phoneNumber || user.disabled === true) {
    throw new RegistrationError("failed-precondition", "The resident phone account is unavailable.");
  }
  return db.runTransaction(async (tx) => {
    const current = await preflight(tx, user.uid);
    if (current.retry) return {userId: user.uid, status: "created", idempotent: true};
    const timestamp = FieldValue.serverTimestamp();
    const required = identityVerificationRequired(input.residentType, current.actor.community);
    tx.create(db.collection("users").doc(user.uid), {
      uid: user.uid, name: input.residentName, fullName: input.residentName,
      phoneNumber: input.phoneNumber, email: input.email, familyMembers: input.familyMembers,
      communityId: input.communityId, role: "resident", residentType: input.residentType, ownershipType: input.residentType,
      approvalStatus: required ? "pending" : "approved", isActive: !required, status: required ? "pending" : "active", occupancyStatus: "current",
      identityVerified: false, phoneVerified: false, identityVerificationStatus: required ? "verification_required" : "not_required",
      buildingId: buildingId.trim(), buildingName: clean(current.building.buildingName || current.building.name),
      flatId: flatId.trim(), unitId: clean(current.flat.unitId || current.flat.flatId) || flatId.trim(),
      flatLabel: clean(current.flat.flatLabel || current.flat.flatId) || flatId.trim(),
      creationSource: "admin_direct", createdBy: current.actor.uid,
      ...(!required ? {approvedBy: current.actor.uid, approvedAt: timestamp, registrationCompletedAt: timestamp} : {}),
      createdAt: timestamp, updatedAt: timestamp,
    });
    tx.update(flatRef, {status: "occupied", residentUserId: user.uid, residentId: null,
      residentName: input.residentName, ownershipType: input.residentType, updatedAt: timestamp});
    tx.update(buildingRef, buildingOccupancyUpdate(current.flats, {targetFlatId: flatId.trim(), targetStatus: "occupied", timestamp}));
    return {userId: user.uid, status: "created", idempotent: false};
  });
}

async function createResidentOnboardingCore({ db, auth, data }) {
  const requestedCommunityId = clean(data?.communityId);
  if (!requestedCommunityId) {
    throw new RegistrationError("invalid-argument", "Community is required.");
  }
  const actor = await requireOperationalAdmin(db, auth, requestedCommunityId);
  const input = validateSingleOnboardingInput(data);
  const onboardingId = residentOnboardingId(input.communityId, input.phoneNumber);
  const onboardingRef = db.collection("residentOnboarding").doc(onboardingId);
  const usersQuery = db.collection("users")
    .where("communityId", "==", input.communityId);
  const onboardingQuery = db.collection("residentOnboarding")
    .where("communityId", "==", input.communityId);
  const matchesPhone = (record) => [record?.phoneNumber, record?.phone].some((value) => {
    if (!clean(value)) return false;
    try {
      const countryCode = clean(record?.phoneCountryCode || data.phoneCountryCode).toUpperCase();
      return normalizePhone(value, /^[A-Z]{2}$/.test(countryCode) ? countryCode : null) === input.phoneNumber;
    } catch (_) {
      return false;
    }
  });
  return db.runTransaction(async (transaction) => {
    const [onboardingSnapshot, phoneUsers, pendingOnboardings] = await Promise.all([
      transaction.get(onboardingRef),
      transaction.get(usersQuery),
      transaction.get(onboardingQuery),
    ]);
    if (phoneUsers.docs.some((doc) => matchesPhone(doc.data()))) {
      throw new RegistrationError("already-exists", "A resident profile already uses this phone in the community.");
    }
    if (pendingOnboardings.docs.some((doc) => doc.id !== onboardingId && matchesPhone(doc.data()))) {
      throw new RegistrationError("already-exists", "A resident onboarding already uses this phone in the community.");
    }
    // V1 registration intentionally rejects existing resident identities. Adding an
    // owner to another unit needs a separate, explicit membership workflow.
    if (onboardingSnapshot.exists) {
      const existing = onboardingSnapshot.data();
      if (existing?.communityId === input.communityId &&
        existing?.creationSource === "admin_single_onboarding" &&
        existing?.status === "pending_registration" &&
        existing?.claimedByUid == null &&
        existing?.residentName === input.residentName &&
        existing?.residentType === input.residentType &&
        (existing?.email ?? null) === input.email) {
        return { onboardingId, status: "pending_registration", idempotent: true };
      }
      throw new RegistrationError("already-exists", "A resident onboarding already uses this phone in the community.");
    }
    const timestamp = FieldValue.serverTimestamp();
    transaction.create(onboardingRef, {
      communityId: input.communityId,
      residentName: input.residentName,
      phoneNumber: input.phoneNumber,
      email: input.email,
      residentType: input.residentType,
      ownershipType: input.residentType,
      familyMembers: input.familyMembers,
      buildingReference: input.buildingReference,
      unitReference: input.unitReference,
      role: "resident",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "verification_required",
      status: "pending_registration",
      claimedByUid: null,
      creationSource: "admin_single_onboarding",
      createdBy: actor.uid,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    return { onboardingId, status: "pending_registration", idempotent: false };
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
  return { contentType, bytes };
}

async function submitResidentIdentityProofCore({ db, bucket, auth, data }) {
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
    metadata: { contentType: proof.contentType, cacheControl: "private, no-store" },
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
    if (!["pending", "approved"].includes(current.approvalStatus) || ["deleted", "rejected"].includes(current.status)) {
      throw new RegistrationError("failed-precondition", "Identity proof cannot be submitted after registration rejection.");
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
      await bucket.file(previousPath).delete({ ignoreNotFound: true });
    } catch (error) {
      console.warn("Previous resident identity proof cleanup failed.", {
        communityId: resident.communityId,
        residentId: identity.uid,
        error: error?.message,
      });
    }
  }
  return { status: "pending" };
}

function validateAdminProofInput(data, { review = false } = {}) {
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
  return { communityId, userId, decision, reason };
}

async function getResidentIdentityProofUrlCore({ db, bucket, auth, data }) {
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
  const [url] = await bucket.file(path).getSignedUrl({ action: "read", expires: Date.now() + 10 * 60 * 1000 });
  return { url, contentType: clean(resident.identityProofContentType) };
}

async function reviewResidentIdentityProofCore({ db, auth, data }) {
  const input = validateAdminProofInput(data, { review: true });
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const resident = snapshot.data();
    if (!snapshot.exists || resident?.role !== "resident" || resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (!["pending", "approved"].includes(resident.approvalStatus) || ["rejected", "deleted", "completed"].includes(resident.status)) {
      throw new RegistrationError("failed-precondition", "Registration is no longer open for identity review.");
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
    const completesAdminRegistration = resident.creationSource === "admin_direct" && resident.approvalStatus === "pending" && verified;
    if ((resident.approvalStatus === "approved" || completesAdminRegistration) && canonicalType != null &&
      resident.occupancyStatus !== "suspended" &&
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
    if (completesAdminRegistration && !canRemainActive) {
      throw new RegistrationError("failed-precondition", "The registration's unit assignment changed; resolve it before identity approval.");
    }
    if (resident.approvalStatus === "approved" && resident.isActive === true) {
      await assertNoActiveSos(
        db,
        transaction,
        input.userId,
        input.communityId,
        "reviewing the resident identity proof",
      );
    }
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      ...(resident.creationSource === "admin_direct" && verified && canRemainActive
        ? {approvalStatus: "approved", approvedAt: timestamp, approvedBy: actor.uid, registrationCompletedAt: timestamp} : {}),
      identityVerificationStatus: input.decision,
      identityVerified: verified,
      isActive: canRemainActive,
      status: canRemainActive ? "active" : "inactive",
      identityVerificationReviewedAt: timestamp,
      identityVerificationReviewedBy: actor.uid,
      identityVerificationRejectionReason: verified ? null : input.reason || null,
      updatedAt: timestamp,
    });
    return { status: input.decision };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: input.decision === "verified" ?
      AUDIT_ACTIONS.identityApprove : AUDIT_ACTIONS.identityReject,
    targetId: input.userId,
    summary: input.decision === "verified" ?
      "Resident identity verification approved." :
      "Resident identity verification rejected.",
    metadata: {
      previousStatus: "pending",
      newStatus: input.decision,
      reasonProvided: input.decision === "rejected" && Boolean(input.reason),
    },
  });
  return result;
}

async function moveOutResidentCore({ db, auth, data }) {
  const input = validateAdminProofInput(data);
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  let previousFlatId;
  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || resident?.role !== "resident" || resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (resident.approvalStatus !== "approved" || resident.isActive !== true ||
      clean(resident.status) !== "active" ||
      clean(resident.occupancyStatus) !== "current") {
      throw new RegistrationError(
        "failed-precondition",
        "Only an active current resident can be moved out.",
      );
    }
    const flatId = clean(resident.flatId);
    previousFlatId = flatId;
    if (!flatId) throw new RegistrationError("failed-precondition", "Resident has no current unit assignment.");
    const flatRef = db.collection("flats").doc(flatId);
    const flatSnapshot = await transaction.get(flatRef);
    const flat = flatSnapshot.data();
    const buildingId = clean(resident.buildingId);
    if (!flatSnapshot.exists || !buildingId) {
      throw new RegistrationError("failed-precondition", "Resident unit assignment is incomplete.");
    }
    const buildingRef = db.collection("buildings").doc(buildingId);
    const [buildingSnapshot, buildingFlatsSnapshot] = await Promise.all([
      transaction.get(buildingRef),
      transaction.get(db.collection("flats")
        .where("communityId", "==", input.communityId)
        .where("buildingId", "==", buildingId)),
    ]);
    validateBuildingAndFlat({
      buildingSnapshot,
      flatSnapshot,
      communityId: input.communityId,
      buildingId,
    });
    const type = canonicalResidentType(resident);
    if (!type) throw new RegistrationError("failed-precondition", "Resident type is invalid or ambiguous.");
    const occupant = resolveFlatOccupant(flat);
    if (flat.status !== "occupied" || occupant.uid !== input.userId) {
      throw new RegistrationError(
        "failed-precondition",
        "Resident cannot be moved out because the unit occupant does not match.",
      );
    }
    await assertNoActiveSos(
      db,
      transaction,
      input.userId,
      input.communityId,
      "moving the resident out",
    );
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
    transaction.update(flatRef, vacantFlatUpdate(timestamp));
    transaction.update(buildingRef, buildingOccupancyUpdate(buildingFlatsSnapshot, {
      targetFlatId: flatId,
      targetStatus: "vacant",
      timestamp,
    }));
    return { status: "moved_out", occupantCleared: true };
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentMoveOut,
    targetId: input.userId,
    summary: "Resident moved out and unit occupancy cleared.",
    metadata: {
      previousStatus: "active",
      newStatus: "moved_out",
      previousFlatId,
    },
  });
  return result;
}

module.exports = {
  requireOperationalAdmin,
  requireOperationalBillingSystem,
  operationalBillingSystemAuthority,
  SYSTEM_BILLING_ACTOR_ID,
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
  validateLifecycleInput,
  validateReassignmentInput,
  validateSingleOnboardingInput,
  isResidentProofPath,
  operationalAccessFailure,
  approveResidentRegistrationCore,
  rejectResidentRegistrationCore,
  deactivateResidentCore,
  reactivateResidentCore,
  reassignResidentCore,
  createResidentOnboardingCore,
  createAdminResidentCore,
  submitResidentIdentityProofCore,
  getResidentIdentityProofUrlCore,
  reviewResidentIdentityProofCore,
  moveOutResidentCore,
  auditResidentAction,
  assignResidentOnboardingToFlatCore,
  listAssignableResidentOnboardingsCore,
  renameUnitCore,
  cancelResidentOnboardingReservationCore,
};
