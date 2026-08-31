const {randomUUID} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError, verifiedPhoneAuth} = require("./register_resident");
const {normalizePhone} = require("./resident_bulk_import");
const {residentOnboardingId} = require("./resident_import_ids");
const {AUDIT_ACTIONS, writeAuditLogBestEffort} = require("./audit_log");

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

function validateLifecycleInput(data, {allowReason = false} = {}) {
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
  return {communityId, userId, reason};
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

function validateSingleOnboardingInput(data, community) {
  const allowed = new Set([
    "communityId",
    "residentName",
    "phoneNumber",
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
  const rawCountryCode = clean(community?.phoneCountryCode || community?.countryCode).toUpperCase();
  const countryCode = /^[A-Z]{2}$/.test(rawCountryCode) ? rawCountryCode : null;
  let phoneNumber;
  try {
    phoneNumber = normalizePhone(data.phoneNumber, countryCode);
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

async function approveResidentRegistrationCore({db, auth, data}) {
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
    const safelyVacant = flat.status === "vacant" && occupant.uid == null;
    const sameResidentRetry = flat.status === "occupied" &&
      occupant.uid === input.userId &&
      clean(resident.flatId) === input.flatId &&
      clean(resident.buildingId) === input.buildingId;
    if (!safelyVacant && !sameResidentRetry) {
      throw new RegistrationError(
        "failed-precondition",
        "This unit is not safely vacant for resident approval.",
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
    return {status: "approved", isActive: active, identityVerificationRequired: false};
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

function buildingOccupancyUpdate(flatSnapshot, {targetFlatId, targetStatus, timestamp}) {
  let occupied = 0;
  let vacant = 0;
  for (const doc of flatSnapshot.docs) {
    const status = doc.id === targetFlatId ? targetStatus : clean(doc.data()?.status);
    if (status === "occupied") occupied += 1;
    if (status === "vacant") vacant += 1;
  }
  const total = flatSnapshot.docs.length;
  return {
    occupied,
    vacant,
    occupancyRate: total > 0 ? Math.round((occupied / total) * 100) : 0,
    updatedAt: timestamp,
  };
}

async function rejectResidentRegistrationCore({db, auth, data}) {
  const input = validateLifecycleInput(data, {allowReason: true});
  const actor = await requireOperationalAdmin(db, auth, input.communityId);
  const userRef = db.collection("users").doc(input.userId);
  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const resident = userSnapshot.data();
    if (!userSnapshot.exists || resident?.role !== "resident" ||
        resident?.communityId !== input.communityId) {
      throw new RegistrationError("permission-denied", "Resident is outside the authorized community.");
    }
    if (resident.approvalStatus !== "pending" || resident.isActive !== false) {
      throw new RegistrationError(
        "failed-precondition",
        "Only an inactive pending resident registration can be rejected.",
      );
    }

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
      const occupant = resolveFlatOccupant(flat);
      if (occupant.uid === input.userId) {
        if (!["vacant", "occupied"].includes(flat.status)) {
          throw new RegistrationError("failed-precondition", "Stale unit occupancy cannot be reconciled safely.");
        }
        if (sameFlatSnapshot.docs.some((doc) => doc.id !== input.userId)) {
          throw new RegistrationError(
            "failed-precondition",
            "Stale unit occupancy conflicts with another resident assignment.",
          );
        }
        transaction.update(flatRef, vacantFlatUpdate(FieldValue.serverTimestamp()));
        staleOccupantCleared = true;
      }
    }

    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      approvalStatus: "rejected",
      isActive: false,
      status: "rejected",
      rejectedAt: timestamp,
      rejectedBy: actor.uid,
      rejectedReason: input.reason || null,
      updatedAt: timestamp,
    });
    return {status: "rejected", staleOccupantCleared};
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentReject,
    targetId: input.userId,
    summary: "Resident registration rejected.",
    metadata: {
      previousStatus: "pending",
      newStatus: "rejected",
      reasonProvided: Boolean(input.reason),
      staleOccupantCleared: result.staleOccupantCleared,
    },
  });
  return result;
}

async function deactivateResidentCore({db, auth, data}) {
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
        residentOccupancyState(resident, {communityId: input.communityId, flatId}) !== "active") {
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
    const timestamp = FieldValue.serverTimestamp();
    transaction.update(userRef, {
      isActive: false,
      status: "inactive",
      occupancyStatus: "suspended",
      deactivatedAt: timestamp,
      deactivatedBy: actor.uid,
      updatedAt: timestamp,
    });
    return {status: "inactive", occupancyStatus: "suspended", occupantRetained: true};
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentDeactivate,
    targetId: input.userId,
    summary: "Resident access deactivated.",
    metadata: {previousStatus: "active", newStatus: "inactive"},
  });
  return result;
}

async function reactivateResidentCore({db, auth, data}) {
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
    return {status: "active", occupancyStatus: "current"};
  });
  await auditResidentAction({
    db,
    actorUid: actor.uid,
    communityId: input.communityId,
    action: AUDIT_ACTIONS.residentReactivate,
    targetId: input.userId,
    summary: "Resident access reactivated.",
    metadata: {previousStatus: "inactive", newStatus: "active"},
  });
  return result;
}

async function reassignResidentCore({db, auth, data}) {
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
    return {status: "active", occupancyStatus: "current", userId: input.userId};
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

async function createResidentOnboardingCore({db, auth, data}) {
  const requestedCommunityId = clean(data?.communityId);
  if (!requestedCommunityId) {
    throw new RegistrationError("invalid-argument", "Community is required.");
  }
  const actor = await requireOperationalAdmin(db, auth, requestedCommunityId);
  const input = validateSingleOnboardingInput(data, actor.community);
  const onboardingId = residentOnboardingId(input.communityId, input.phoneNumber);
  const onboardingRef = db.collection("residentOnboarding").doc(onboardingId);
  const phoneQuery = db.collection("users")
    .where("communityId", "==", input.communityId)
    .where("phoneNumber", "==", input.phoneNumber);
  const legacyPhoneQuery = db.collection("users")
    .where("communityId", "==", input.communityId)
    .where("phone", "==", input.phoneNumber);
  return db.runTransaction(async (transaction) => {
    const [onboardingSnapshot, phoneUsers, legacyPhoneUsers] = await Promise.all([
      transaction.get(onboardingRef),
      transaction.get(phoneQuery),
      transaction.get(legacyPhoneQuery),
    ]);
    if (phoneUsers.docs.length > 0 || legacyPhoneUsers.docs.length > 0) {
      throw new RegistrationError("already-exists", "A resident profile already uses this phone in the community.");
    }
    if (onboardingSnapshot.exists) {
      const existing = onboardingSnapshot.data();
      if (existing?.communityId === input.communityId &&
          existing?.creationSource === "admin_single_onboarding" &&
          existing?.status === "pending_registration" &&
          existing?.claimedByUid == null &&
          existing?.residentName === input.residentName &&
          existing?.residentType === input.residentType &&
          (existing?.email ?? null) === input.email) {
        return {onboardingId, status: "pending_registration", idempotent: true};
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
    return {onboardingId, status: "pending_registration", idempotent: false};
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
  const result = await db.runTransaction(async (transaction) => {
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

async function moveOutResidentCore({db, auth, data}) {
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
    return {status: "moved_out", occupantCleared: true};
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
  submitResidentIdentityProofCore,
  getResidentIdentityProofUrlCore,
  reviewResidentIdentityProofCore,
  moveOutResidentCore,
};
