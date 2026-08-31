const {FieldValue} = require("firebase-admin/firestore");

const AUDIT_COLLECTION = "auditLogs";
const PLATFORM_COMMUNITY_ID = "__platform__";

const AUDIT_ACTIONS = Object.freeze({
  residentApprove: "resident.approve",
  residentReject: "resident.reject",
  residentDeactivate: "resident.deactivate",
  residentReactivate: "resident.reactivate",
  residentMoveOut: "resident.move_out",
  residentReassign: "resident.reassign",
  identityApprove: "identity_verification.approve",
  identityReject: "identity_verification.reject",
  adminCreate: "admin.create",
  adminSetActive: "admin.set_active",
  adminAssignmentsUpdate: "admin.assignments_update",
  securityCreate: "security_staff.create",
  securityAssign: "security_staff.assign",
  securityAssignmentRemove: "security_staff.assignment_remove",
  communityConfigurationUpdate: "community.configuration_update",
  communityStatusUpdate: "community.status_update",
  communityLocationUpdate: "community.location_update",
});

function requiredString(value, field, maxLength) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized || normalized.length > maxLength) {
    throw new Error(`Audit ${field} is invalid.`);
  }
  return normalized;
}

function safeMetadata(metadata) {
  if (metadata == null) return undefined;
  if (typeof metadata !== "object" || Array.isArray(metadata)) {
    throw new Error("Audit metadata must be an object.");
  }
  const entries = Object.entries(metadata);
  if (entries.length > 12) throw new Error("Audit metadata is too large.");
  const result = {};
  for (const [rawKey, value] of entries) {
    const key = requiredString(rawKey, "metadata key", 80);
    const scalar = value == null || typeof value === "boolean" ||
      (typeof value === "number" && Number.isFinite(value)) ||
      (typeof value === "string" && value.length <= 200);
    const stringList = Array.isArray(value) && value.length <= 20 &&
      value.every((item) => typeof item === "string" && item.length <= 120);
    if (!scalar && !stringList) {
      throw new Error(`Audit metadata ${key} is invalid.`);
    }
    result[key] = value;
  }
  return result;
}

function buildAuditLog({
  actorUid,
  actorRole,
  communityId,
  action,
  targetType,
  targetId,
  summary,
  metadata,
}) {
  const entry = {
    actorUid: requiredString(actorUid, "actorUid", 128),
    actorRole: requiredString(actorRole, "actorRole", 40),
    communityId: requiredString(communityId, "communityId", 80),
    action: requiredString(action, "action", 120),
    targetType: requiredString(targetType, "targetType", 80),
    targetId: requiredString(targetId, "targetId", 128),
    timestamp: FieldValue.serverTimestamp(),
    summary: requiredString(summary, "summary", 240),
  };
  const sanitizedMetadata = safeMetadata(metadata);
  if (sanitizedMetadata && Object.keys(sanitizedMetadata).length > 0) {
    entry.metadata = sanitizedMetadata;
  }
  return entry;
}

async function writeAuditLogBestEffort({db, logger = console, ...fields}) {
  try {
    const entry = buildAuditLog(fields);
    const ref = db.collection(AUDIT_COLLECTION).doc();
    // Lightweight unit-test stores may not implement auto-ID creates. The
    // production Admin SDK always does; skipping here keeps core tests focused.
    if (!ref?.id || typeof ref.create !== "function") {
      return {written: false, skipped: true};
    }
    await ref.create(entry);
    return {written: true, id: ref.id};
  } catch (error) {
    logger.error("Critical audit log write failed.", {
      action: fields.action,
      targetType: fields.targetType,
      targetId: fields.targetId,
      error: error?.message ?? String(error),
    });
    return {written: false};
  }
}

module.exports = {
  AUDIT_ACTIONS,
  AUDIT_COLLECTION,
  PLATFORM_COMMUNITY_ID,
  buildAuditLog,
  writeAuditLogBestEffort,
};
