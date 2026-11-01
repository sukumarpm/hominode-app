const { createHash } = require("node:crypto");

const ASSISTED_SOURCE = "admin_assisted";
const ASSISTED_METHODS = new Set([
  "in_person_with_community_records",
  "live_video_with_community_records",
  "document_and_community_records",
]);
const validId = (value) =>
  typeof value === "string" &&
  value.trim() === value &&
  value.length > 0 &&
  value.length <= 128 &&
  !/[\/\u0000-\u001f\u007f]/.test(value);
const validReference = (value) =>
  typeof value === "string" &&
  /^[A-Za-z0-9][A-Za-z0-9._:-]{2,159}$/.test(value);
const time = (value) =>
  value?.toMillis?.() ??
  (value instanceof Date
    ? value.getTime()
    : typeof value === "number"
      ? value
      : NaN);
const validTime = (value, now) =>
  Number.isFinite(time(value)) && time(value) > 0 && time(value) <= now;

function assistedIntakeDigest(requestId, uid, communityId, intake) {
  return createHash("sha256")
    .update(
      JSON.stringify([
        requestId,
        uid,
        communityId,
        intake.schemaVersion,
        intake.initiatedBy,
        intake.supportCaseReference,
        intake.verificationMethod,
        intake.verificationEvidenceReference,
        intake.verificationNotes,
        intake.consentAttested,
      ]),
    )
    .digest("hex");
}

function isAssistedIntake(
  request,
  requestId = request?.requestId,
  now = Date.now(),
) {
  const intake = request?.assistedIntake;
  return (
    request?.sourceApp === ASSISTED_SOURCE &&
    request.requestId === requestId &&
    validId(requestId) &&
    validId(request.uid) &&
    validId(request.communityId) &&
    request.communityScopeVerified === true &&
    intake?.schemaVersion === 1 &&
    validId(intake.initiatedBy) &&
    intake.initiatedBy !== request.uid &&
    validTime(intake.initiatedAt, now) &&
    validReference(intake.supportCaseReference) &&
    ASSISTED_METHODS.has(intake.verificationMethod) &&
    validReference(intake.verificationEvidenceReference) &&
    intake.verificationEvidenceReference !== intake.supportCaseReference &&
    typeof intake.verificationNotes === "string" &&
    intake.verificationNotes.trim().length >= 20 &&
    intake.verificationNotes.length <= 600 &&
    intake.consentAttested === true &&
    request.intakeDigest ===
      assistedIntakeDigest(requestId, request.uid, request.communityId, intake)
  );
}

function hasResidentDeletionVerification(
  request,
  requestId = request?.requestId,
  now = Date.now(),
) {
  if (
    !request ||
    request.requestId !== requestId ||
    !validId(requestId) ||
    !validId(request.uid) ||
    !validId(request.communityId) ||
    request.communityScopeVerified !== true ||
    !validTime(request.verificationCompletedAt, now)
  )
    return false;
  if (request.sourceApp === "resident")
    return (
      request.assistedIntake == null && request.assistedVerification == null
    );
  if (!isAssistedIntake(request, requestId, now)) return false;
  const proof = request.assistedVerification;
  return (
    proof?.schemaVersion === 1 &&
    proof.requestId === requestId &&
    proof.uid === request.uid &&
    proof.communityId === request.communityId &&
    proof.intakeDigest === request.intakeDigest &&
    validId(proof.verifiedBy) &&
    proof.verifiedBy !== request.uid &&
    validTime(proof.verifiedAt, now) &&
    time(proof.verifiedAt) >= time(request.assistedIntake.initiatedAt) &&
    proof.identityConfirmed === true &&
    proof.consentConfirmed === true &&
    proof.verificationMethod === request.assistedIntake.verificationMethod &&
    proof.verificationEvidenceReference ===
      request.assistedIntake.verificationEvidenceReference
  );
}

// Retains the previous normal-Resident helper contract while strictly gating the new origin.
function residentDeletionSourceAllowed(
  request,
  requestId = request?.requestId,
  now = Date.now(),
) {
  return (
    (request?.sourceApp === "resident" &&
      request.assistedIntake == null &&
      request.assistedVerification == null) ||
    hasResidentDeletionVerification(request, requestId, now)
  );
}

module.exports = {
  ASSISTED_SOURCE,
  ASSISTED_METHODS,
  validId,
  validReference,
  assistedIntakeDigest,
  isAssistedIntake,
  hasResidentDeletionVerification,
  residentDeletionSourceAllowed,
};
