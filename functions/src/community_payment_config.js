const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {requireAuthorizedCommunityAdmin} = require("./community_location_management");
const {buildAuditLog} = require("./audit_log");

function invalid(message) {
  throw new RegistrationError("invalid-argument", message);
}

function validateInput(data) {
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !["communityId", "directUpi"].includes(key))) {
    invalid("Only communityId and directUpi may be supplied.");
  }
  if (typeof data.communityId !== "string") invalid("A valid community ID is required.");
  const communityId = data.communityId.trim();
  if (!communityId || communityId !== data.communityId || communityId.includes("/") || communityId.length > 128) {
    invalid("A valid community ID is required.");
  }

  const directUpi = data.directUpi;
  if (!directUpi || typeof directUpi !== "object" || Array.isArray(directUpi) ||
      Object.keys(directUpi).some((key) => !["enabled", "vpa", "payeeName"].includes(key)) ||
      typeof directUpi.enabled !== "boolean") {
    invalid("A valid Direct UPI configuration is required.");
  }

  if (!directUpi.enabled) {
    if (Object.keys(directUpi).some((key) => key !== "enabled")) {
      invalid("VPA and payeeName must be omitted when Direct UPI is disabled.");
    }
    return {communityId, directUpi: {enabled: false}};
  }

  if (typeof directUpi.vpa !== "string" || typeof directUpi.payeeName !== "string") {
    invalid("A VPA and payee name are required when Direct UPI is enabled.");
  }
  const vpa = directUpi.vpa.trim();
  const payeeName = directUpi.payeeName.trim();
  const parts = vpa.split("@");
  const vpaPartPattern = /^[A-Za-z0-9._+-]+$/;
  const handlePattern = /^[A-Za-z0-9._-]+$/;
  if (vpa.length > 255 || /\s/.test(vpa) || parts.length !== 2 ||
      !vpaPartPattern.test(parts[0]) || !handlePattern.test(parts[1])) {
    invalid("Enter a valid UPI VPA.");
  }
  if (!payeeName || payeeName.length > 120) invalid("Enter a valid payee name.");

  return {communityId, directUpi: {enabled: true, vpa, payeeName}};
}

async function updateCommunityPaymentConfigCore({db, auth, data}) {
  const input = validateInput(data);
  const {uid} = await requireAuthorizedCommunityAdmin(db, auth, input.communityId);
  const communityRef = db.collection("communities").doc(input.communityId);
  const configRef = db.collection("communityPaymentConfigs").doc(input.communityId);
  const auditRef = db.collection("auditLogs").doc();

  await db.runTransaction(async (transaction) => {
    const communitySnapshot = await transaction.get(communityRef);
    if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
      throw new RegistrationError("failed-precondition", "The target community is inactive or unavailable.");
    }

    transaction.set(configRef, {
      communityId: input.communityId,
      version: 1,
      directUpi: input.directUpi,
      updatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(auditRef, buildAuditLog({
      actorUid: uid,
      actorRole: "admin",
      communityId: input.communityId,
      action: "community.payment_config_update",
      targetType: "community_payment_config",
      targetId: input.communityId,
      summary: "Community payment configuration updated.",
      metadata: {directUpiEnabled: input.directUpi.enabled},
    }));
  });

  return {communityId: input.communityId, directUpi: input.directUpi, updatedBy: uid};
}

module.exports = {updateCommunityPaymentConfigCore, validateInput};
