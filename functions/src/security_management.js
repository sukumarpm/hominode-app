const { FieldValue } = require("firebase-admin/firestore");
const { RegistrationError, verifiedPhoneAuth } = require("./register_resident");
const { normalizeCommunityId } = require("./tenant_management");
const {AUDIT_ACTIONS, writeAuditLogBestEffort} = require("./audit_log");

async function auditSecurityAction({
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
    targetType: "security_staff",
    targetId,
    summary,
    metadata,
  });
}

function optionalString(value, maxLength = 120) {
  if (value == null) return null;

  const normalized = String(value).trim();

  if (!normalized) return null;

  if (normalized.length > maxLength) {
    throw new RegistrationError(
      "invalid-argument",
      "Security staff field is too long."
    );
  }

  return normalized;
}

async function requireActiveCommunityAdmin(db, auth, communityId) {
  const { uid } = verifiedPhoneAuth(auth);

  const adminSnapshot = await db.collection("admins").doc(uid).get();

  if (!adminSnapshot.exists) {
    throw new RegistrationError(
      "permission-denied",
      "An active community admin profile is required."
    );
  }

  const admin = adminSnapshot.data() || {};

  if (
    admin.uid !== uid ||
    admin.role !== "admin" ||
    admin.isActive !== true ||
    !Array.isArray(admin.authorizedCommunityIds) ||
    !admin.authorizedCommunityIds.includes(communityId)
  ) {
    throw new RegistrationError(
      "permission-denied",
      "You are not authorized to manage security staff for this community."
    );
  }

  const communitySnapshot = await db
    .collection("communities")
    .doc(communityId)
    .get();

  if (
    !communitySnapshot.exists ||
    communitySnapshot.data()?.isActive !== true
  ) {
    throw new RegistrationError(
      "failed-precondition",
      "This community is inactive or unavailable."
    );
  }

  return {
    uid,
    admin,
    community: communitySnapshot.data(),
  };
}

function validateCreateSecurityStaffInput(data) {
  const allowedKeys = new Set([
    "communityId",
    "phoneNumber",
    "name",
    "securityId",
    "buildingId",
    "gateId",
    "shift",
    "isActive",
  ]);

  if (
    !data ||
    typeof data !== "object" ||
    Object.keys(data).some((key) => !allowedKeys.has(key))
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Unsupported security staff field."
    );
  }

  const communityId = normalizeCommunityId(data.communityId);

  if (!communityId || communityId.length > 80) {
    throw new RegistrationError(
      "invalid-argument",
      "A valid community ID is required."
    );
  }

  const phoneNumber = String(data.phoneNumber ?? "").trim();

  if (!/^\+[1-9]\d{7,14}$/.test(phoneNumber)) {
    throw new RegistrationError(
      "invalid-argument",
      "Use a valid E.164 phone number."
    );
  }

  const name = String(data.name ?? "").trim();

  if (!name || name.length > 120) {
    throw new RegistrationError(
      "invalid-argument",
      "Enter a valid security staff name."
    );
  }

  if (data.isActive != null && typeof data.isActive !== "boolean") {
    throw new RegistrationError(
      "invalid-argument",
      "isActive must be boolean."
    );
  }

  return {
    communityId,
    phoneNumber,
    name,
    securityId: optionalString(data.securityId, 80),
    buildingId: optionalString(data.buildingId, 80),
    gateId: optionalString(data.gateId, 80),
    shift: optionalString(data.shift, 80),
    isActive: data.isActive ?? true,
  };
}

async function assertNoConflictingProfile(db, uid) {
  const [
    residentSnapshot,
    adminSnapshot,
    securitySnapshot,
  ] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("admins").doc(uid).get(),
    db.collection("securityStaff").doc(uid).get(),
  ]);

  if (residentSnapshot.exists) {
    throw new RegistrationError(
      "failed-precondition",
      "This phone account already belongs to a resident."
    );
  }

  if (adminSnapshot.exists) {
    throw new RegistrationError(
      "failed-precondition",
      "This phone account already belongs to an administrator."
    );
  }

  if (securitySnapshot.exists) {
    throw new RegistrationError(
      "already-exists",
      "A security staff profile already exists for this phone number."
    );
  }
}

async function createSecurityStaffCore({
  db,
  authAdmin,
  auth,
  data,
}) {
  const input = validateCreateSecurityStaffInput(data);

  const actor = await requireActiveCommunityAdmin(
    db,
    auth,
    input.communityId
  );

  let user;
  let createdAuthUser = false;

  try {
    user = await authAdmin.getUserByPhoneNumber(input.phoneNumber);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw error;
    }

    user = await authAdmin.createUser({
      phoneNumber: input.phoneNumber,
      disabled: false,
    });

    createdAuthUser = true;
  }

  const securityRef = db.collection("securityStaff").doc(user.uid);

  try {
    await assertNoConflictingProfile(db, user.uid);

    await securityRef.create({
      uid: user.uid,

      communityId: input.communityId,

      role: "security",
      isActive: input.isActive,

      name: input.name,
      phoneNumber: input.phoneNumber,

      securityId: input.securityId,
      buildingId: input.buildingId,
      gateId: input.gateId,
      shift: input.shift,

      createdBy: actor.uid,
      createdAt: FieldValue.serverTimestamp(),

      updatedBy: actor.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });

    await auditSecurityAction({
      db,
      actorUid: actor.uid,
      communityId: input.communityId,
      action: AUDIT_ACTIONS.securityCreate,
      targetId: user.uid,
      summary: "Security staff account created.",
      metadata: {isActive: input.isActive},
    });

    return {
      uid: user.uid,
      communityId: input.communityId,
      role: "security",
    };
  } catch (error) {
    if (createdAuthUser) {
      await authAdmin.deleteUser(user.uid).catch(() => { });
    }

    throw error;
  }
}
function normalizeWorkStatus(value) {
  const raw = String(value ?? "").trim();

  const allowed = new Map([
    ["On Duty", "on-duty"],
    ["Off Duty", "off-duty"],
    ["Break", "break"],
    ["On Leave", "on-leave"],
  ]);

  const normalized = allowed.get(raw);

  if (!normalized) {
    throw new RegistrationError(
      "invalid-argument",
      "Select a valid work status."
    );
  }

  return {
    display: raw,
    status: normalized,
  };
}

async function assignSecurityWorkCore({
  db,
  auth,
  data,
}) {
  const allowedKeys = new Set([
    "communityId",
    "staffUid",
    "gateId",
    "shiftTiming",
    "workStatus",
    "specialInstructions",
  ]);

  if (
    !data ||
    typeof data !== "object" ||
    Object.keys(data).some((key) => !allowedKeys.has(key))
  ) {
    throw new RegistrationError(
      "invalid-argument",
      "Unsupported security assignment field."
    );
  }

  const communityId = normalizeCommunityId(data.communityId);
  const staffUid = String(data.staffUid ?? "").trim();
  const gateId = String(data.gateId ?? "").trim();
  const shiftTiming = String(data.shiftTiming ?? "").trim();

  const specialInstructions =
    optionalString(data.specialInstructions, 500);

  if (!communityId) {
    throw new RegistrationError(
      "invalid-argument",
      "Community ID is required."
    );
  }

  if (!staffUid || staffUid.length > 128) {
    throw new RegistrationError(
      "invalid-argument",
      "Valid security staff ID is required."
    );
  }

  if (!gateId || gateId.length > 128) {
    throw new RegistrationError(
      "invalid-argument",
      "Valid security place ID is required."
    );
  }

  if (!shiftTiming || shiftTiming.length > 120) {
    throw new RegistrationError(
      "invalid-argument",
      "Valid shift timing is required."
    );
  }

  const workStatus = normalizeWorkStatus(data.workStatus);

  const actor = await requireActiveCommunityAdmin(
    db,
    auth,
    communityId
  );

  const staffRef = db.collection("securityStaff").doc(staffUid);
  const gateRef = db.collection("gates").doc(gateId);
  let previousGateId = null;
  let previousWorkStatus = null;

  await db.runTransaction(async (transaction) => {
    const staffSnapshot = await transaction.get(staffRef);
    const gateSnapshot = await transaction.get(gateRef);

    if (!staffSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Security staff was not found."
      );
    }

    if (!gateSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Security place was not found."
      );
    }

    const staff = staffSnapshot.data() || {};
    const gate = gateSnapshot.data() || {};

    if (
      staff.uid !== staffUid ||
      staff.role !== "security" ||
      staff.isActive !== true ||
      staff.communityId !== communityId
    ) {
      throw new RegistrationError(
        "permission-denied",
        "Security staff is not active in this community."
      );
    }

    if (gate.communityId !== communityId) {
      throw new RegistrationError(
        "permission-denied",
        "Security place does not belong to this community."
      );
    }

    if (gate.workingStatus !== "Active") {
      throw new RegistrationError(
        "failed-precondition",
        "Security can only be assigned to an active place."
      );
    }

    if (
      gate.assignedSecurityId &&
      gate.assignedSecurityId !== staffUid
    ) {
      throw new RegistrationError(
        "failed-precondition",
        "This security place is already assigned to another staff member."
      );
    }

    previousGateId =
      typeof staff.gateId === "string"
        ? staff.gateId.trim()
        : "";
    previousWorkStatus = typeof staff.status === "string" ? staff.status : null;

    if (previousGateId && previousGateId !== gateId) {
      const previousGateRef =
        db.collection("gates").doc(previousGateId);

      const previousGateSnapshot =
        await transaction.get(previousGateRef);

      if (
        previousGateSnapshot.exists &&
        previousGateSnapshot.data()?.communityId === communityId &&
        previousGateSnapshot.data()?.assignedSecurityId === staffUid
      ) {
        transaction.update(previousGateRef, {
          assignedSecurityId: null,
          assignedSecurityName: null,
          assignedShiftTiming: null,
          assignedSpecialInstructions: null,
          assignedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    transaction.update(staffRef, {
      gateId,
      gateAssignment: gate.gateName ?? gateId,

      shift: shiftTiming,
      shiftTiming,

      workStatus: workStatus.display,
      status: workStatus.status,

      specialInstructions,

      lastWorkAssignment: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    });

    transaction.update(gateRef, {
      assignedSecurityId: staffUid,
      assignedSecurityName: staff.name ?? "",
      assignedShiftTiming: shiftTiming,
      assignedSpecialInstructions: specialInstructions,
      assignedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    });
  });

  await auditSecurityAction({
    db,
    actorUid: actor.uid,
    communityId,
    action: AUDIT_ACTIONS.securityAssign,
    targetId: staffUid,
    summary: "Security staff work assignment changed.",
    metadata: {
      previousGateId: previousGateId || null,
      newGateId: gateId,
      previousWorkStatus,
      newWorkStatus: workStatus.status,
    },
  });

  return {
    staffUid,
    gateId,
    communityId,
    workStatus: workStatus.status,
  };
}

async function deleteSecurityPlaceCore({
  db,
  auth,
  data,
}) {
  const communityId = normalizeCommunityId(data?.communityId);
  const gateId = String(data?.gateId ?? "").trim();

  if (!communityId) {
    throw new RegistrationError(
      "invalid-argument",
      "Community ID is required."
    );
  }

  if (!gateId || gateId.length > 128) {
    throw new RegistrationError(
      "invalid-argument",
      "Valid security place ID is required."
    );
  }

  const actor = await requireActiveCommunityAdmin(
    db,
    auth,
    communityId
  );

  const gateRef = db.collection("gates").doc(gateId);

  await db.runTransaction(async (transaction) => {
    const gateSnapshot = await transaction.get(gateRef);

    if (!gateSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Security place was not found."
      );
    }

    const gate = gateSnapshot.data() || {};

    if (gate.communityId !== communityId) {
      throw new RegistrationError(
        "permission-denied",
        "Security place does not belong to this community."
      );
    }

    if (gate.isArchived === true) {
      throw new RegistrationError(
        "failed-precondition",
        "This security place has already been removed."
      );
    }

    if (
      typeof gate.assignedSecurityId === "string" &&
      gate.assignedSecurityId.trim().length > 0
    ) {
      throw new RegistrationError(
        "failed-precondition",
        "Security staff is currently assigned to this place. Reassign or remove the assignment first."
      );
    }

    const assignedStaffQuery = db
      .collection("securityStaff")
      .where("communityId", "==", communityId)
      .where("gateId", "==", gateId)
      .limit(1);

    const assignedStaffSnapshot =
      await transaction.get(assignedStaffQuery);

    if (!assignedStaffSnapshot.empty) {
      throw new RegistrationError(
        "failed-precondition",
        "Security staff is still linked to this place. Reassign or remove the assignment first."
      );
    }

    transaction.update(gateRef, {
      isArchived: true,
      workingStatus: "Inactive",

      archivedAt: FieldValue.serverTimestamp(),
      archivedBy: actor.uid,

      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    });
  });

  return {
    gateId,
    communityId,
    archived: true,
  };
}

async function removeSecurityAssignmentCore({
  db,
  auth,
  data,
}) {
  const communityId = normalizeCommunityId(data?.communityId);
  const staffUid = String(data?.staffUid ?? "").trim();

  if (!communityId) {
    throw new RegistrationError(
      "invalid-argument",
      "Community ID is required."
    );
  }

  if (!staffUid || staffUid.length > 128) {
    throw new RegistrationError(
      "invalid-argument",
      "Valid security staff ID is required."
    );
  }

  const actor = await requireActiveCommunityAdmin(
    db,
    auth,
    communityId
  );

  const staffRef = db.collection("securityStaff").doc(staffUid);
  let removedGateId = null;

  await db.runTransaction(async (transaction) => {
    const staffSnapshot = await transaction.get(staffRef);

    if (!staffSnapshot.exists) {
      throw new RegistrationError(
        "not-found",
        "Security staff was not found."
      );
    }

    const staff = staffSnapshot.data() || {};

    if (
      staff.uid !== staffUid ||
      staff.role !== "security" ||
      staff.communityId !== communityId
    ) {
      throw new RegistrationError(
        "permission-denied",
        "Security staff does not belong to this community."
      );
    }

    const gateId =
      typeof staff.gateId === "string"
        ? staff.gateId.trim()
        : "";
    removedGateId = gateId;

    if (!gateId) {
      throw new RegistrationError(
        "failed-precondition",
        "This security staff member has no active place assignment."
      );
    }

    const gateRef = db.collection("gates").doc(gateId);
    const gateSnapshot = await transaction.get(gateRef);

    if (gateSnapshot.exists) {
      const gate = gateSnapshot.data() || {};

      if (gate.communityId !== communityId) {
        throw new RegistrationError(
          "permission-denied",
          "Assigned security place does not belong to this community."
        );
      }

      if (gate.assignedSecurityId === staffUid) {
        transaction.update(gateRef, {
          assignedSecurityId: null,
          assignedSecurityName: null,
          assignedShiftTiming: null,
          assignedSpecialInstructions: null,
          assignedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actor.uid,
        });
      }
    }

    transaction.update(staffRef, {
      gateId: null,
      gateAssignment: null,
      shift: null,
      shiftTiming: null,
      workStatus: "Off Duty",
      status: "off-duty",
      specialInstructions: null,
      lastWorkAssignment: null,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    });
  });

  await auditSecurityAction({
    db,
    actorUid: actor.uid,
    communityId,
    action: AUDIT_ACTIONS.securityAssignmentRemove,
    targetId: staffUid,
    summary: "Security staff work assignment removed.",
    metadata: {previousGateId: removedGateId, newWorkStatus: "off-duty"},
  });

  return {
    staffUid,
    communityId,
    removed: true,
  };
}
module.exports = {
  requireActiveCommunityAdmin,
  validateCreateSecurityStaffInput,
  createSecurityStaffCore,
  assignSecurityWorkCore,
  deleteSecurityPlaceCore,
  removeSecurityAssignmentCore,
};
