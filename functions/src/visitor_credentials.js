const {dayBounds} = require("./amenity_booking");
const {normalizeIanaTimeZone} = require("./tenant_management");
const crypto = require("node:crypto");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {resolveFlatOccupant} = require("./resident_identity");
const {residentIdentity, bringingPet, invitationDecision, assertVisitorAuthorized} = require("./visitor_policy");
const {buildAuditLog} = require("./audit_log");
const {visitorPolicyRevalidationAt} = require("./visitor_policy_resolver");

const WINDOW_MS = 24 * 60 * 60 * 1000;
const QR_BYTES = 32;
const CODE_LENGTH = 12;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_COLLISION_ATTEMPTS = 5;

function fail(code, message) { throw new RegistrationError(code, message); }
function text(value, max = 200) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    fail("invalid-argument", "Visitor details are incomplete or invalid.");
  }
  return value.trim();
}
function validKey(key) {
  if (typeof key !== "string" || Buffer.byteLength(key) < 32) {
    fail("failed-precondition", "Visitor credential service is not configured.");
  }
  return key;
}
function normalizeManualCode(value) {
  return typeof value === "string" ? value.toUpperCase().replace(/[^A-Z0-9]/g, "") : "";
}
function credentialHash(key, type, value) {
  const normalized = type === "manual" ? normalizeManualCode(value) : String(value || "").trim();
  if (!normalized) fail("invalid-argument", "A valid visitor credential is required.");
  return crypto.createHmac("sha256", validKey(key)).update(`${type}:v1:${normalized}`).digest("hex");
}
function generateQrToken() { return crypto.randomBytes(QR_BYTES).toString("base64url"); }
function validQrToken(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{43}$/.test(value);
}
function validManualCode(value) {
  const normalized = normalizeManualCode(value);
  return normalized.length >= 8 && normalized.length <= 32;
}
function generateManualCode() {
  const bytes = crypto.randomBytes(CODE_LENGTH);
  return Array.from(bytes, (byte) => CODE_ALPHABET[byte & 31]).join("");
}
function millis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (Number.isFinite(value)) return value;
  return null;
}
function visitorEligible(visitor, nowMs = Date.now()) {
  if (visitor?.gateAccessStatus === "denied" || visitor?.gateEntryDeniedAt != null) return false;
  const status = visitor?.status;
  const pending = ["expected", "pending"].includes(status) && visitor?.isApproved === false;
  const approved = ["expected", "approved"].includes(status) && visitor?.isApproved === true;
  const arrival = millis(visitor?.expectedArrival ?? visitor?.expectedTime);
  return (pending || approved) && visitor?.actualArrival == null && visitor?.departure == null &&
    arrival != null && nowMs <= arrival + WINDOW_MS;
}
function residentProfileValid(profile, uid, auth) {
  return profile?.uid === uid && profile?.role === "resident" &&
    profile?.approvalStatus === "approved" && profile?.isActive === true &&
    (profile?.status == null || profile.status === "active") &&
    typeof profile?.communityId === "string" && !!profile.communityId.trim() &&
    typeof profile?.flatId === "string" && !!profile.flatId.trim() &&
    profile?.phoneNumber === auth?.token?.phone_number;
}
async function authorizedResident(db, auth, read = (ref) => ref.get()) {
  const uid = auth?.uid;
  if (!uid || !auth?.token?.phone_number || auth?.token?.firebase?.sign_in_provider !== "phone") {
    fail("unauthenticated", "Verified phone authentication is required.");
  }
  const userSnapshot = await read(db.collection("users").doc(uid));
  const profile = userSnapshot.data();
  if (!userSnapshot.exists || !residentProfileValid(profile, uid, auth)) {
    fail("permission-denied", "An active, approved Resident account is required.");
  }
  const communitySnapshot = await read(db.collection("communities").doc(profile.communityId));
  const community = communitySnapshot.data();
  residentIdentity(profile, community);
  if (!communitySnapshot.exists || community?.isActive !== true) {
    fail("permission-denied", "Resident community or identity authorization is unavailable.");
  }
  const flatSnapshot = await read(db.collection("flats").doc(profile.flatId));
  const flat = flatSnapshot.data();
  let occupant;
  try { occupant = resolveFlatOccupant(flat); } catch (_) {
    fail("permission-denied", "The Resident's unit assignment is inconsistent.");
  }
  if (!flatSnapshot.exists || flat?.communityId !== profile.communityId ||
      flat?.status !== "occupied" || occupant?.uid !== uid) {
    fail("permission-denied", "The Resident's assigned unit is not available in this community.");
  }
  return {uid, profile, community, communityId: profile.communityId, flatId: profile.flatId, flat};
}
function visitorFields(input, host, nowMs) {
  const arrivalMs = Number(input?.expectedArrival);
  let zone;
  try {
    if (typeof host.community.timeZone === "string" && /^[+-]/.test(host.community.timeZone.trim())) {
      throw Error("IANA zone required");
    }
    zone = normalizeIanaTimeZone(host.community.timeZone);
  } catch (_) {
    fail("failed-precondition", "Configure a valid community timeZone before inviting visitors.");
  }
  const startOfToday = dayBounds(nowMs, zone).startMs;
  if (!Number.isFinite(arrivalMs) || arrivalMs < startOfToday) {
    fail("invalid-argument", "Choose a valid expected arrival time.");
  }
  const visitorName = text(input?.visitorName, 120);
  const purpose = text(input?.purpose, 300);
  const expectedArrival = Timestamp.fromMillis(arrivalMs);
  return {
    hostUserId: host.uid,
    residentId: host.uid,
    hostName: String(host.profile.name || host.profile.fullName || "Resident").slice(0, 120),
    flatId: host.flatId,
    flatLabel: String(host.profile.flatLabel || host.flat.flatLabel || host.flat.flatId || host.flatId).slice(0, 80),
    buildingId: host.profile.buildingId || host.flat.buildingId || null,
    communityId: host.communityId,
    adminId: host.profile.adminId || null,
    visitorName,
    purpose,
    bringingPet: bringingPet(input.bringingPet),
    expectedArrival,
    phoneNumber: input.phoneNumber == null || input.phoneNumber === "" ? null : text(input.phoneNumber, 40),
    vehicleNumber: input.vehicleNumber == null || input.vehicleNumber === "" ? null : text(input.vehicleNumber, 40),
    status: "expected",
    isApproved: false,
    approvedBy: null,
    approvedAt: null,
    actualArrival: null,
    departure: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    credentialVersion: 1,
    credentialValidFrom: Timestamp.fromMillis(arrivalMs - WINDOW_MS),
    credentialExpiresAt: Timestamp.fromMillis(arrivalMs + WINDOW_MS),
  };
}
function makeCredentialIndex({hash, visitorId, communityId, type, validFrom, expiresAt}) {
  return {
    visitorId, communityId, credentialType: type, credentialVersion: 1,
    validFrom, expiresAt, createdAt: FieldValue.serverTimestamp(),
  };
}

async function createVisitorInvitationCore({db, auth, data, hmacKey, now = Date.now,
  makeQrToken = generateQrToken, makeManualCode = generateManualCode}) {
  const serverOwnedFields = [
    "status", "isApproved", "approvedBy", "approvedAt", "rejectedBy", "rejectedAt",
    "rejectionReason", "actualArrival", "departure", "checkedInBy", "checkedOutBy",
    "checkedInAt", "checkedOutAt", "gateAccessStatus", "gateEntryDeniedAt",
    "gateEntryDeniedBy", "gateEntryDenialReason", "verificationMethod", "qrToken",
    "visitorPassCode", "authorizationState", "authorizationManaged", "authorizationRevision", "authorizationPolicyRevision",
    "visitorPolicySnapshot", "credentialValidFrom", "credentialExpiresAt", "credentialVersion",
  ];
  if (serverOwnedFields.some((field) => Object.prototype.hasOwnProperty.call(data || {}, field))) {
    fail("invalid-argument", "Visitor status and credentials are assigned by the server.");
  }
  const visitorId = db.collection("visitors").doc().id;
  const visitorRef = db.collection("visitors").doc(visitorId);
  const credentialRef = db.collection("visitorHostCredentials").doc(visitorId);
  let visitor;
  let decision;
  const auditRef = db.collection("auditLogs").doc();
  for (let attempt = 0; attempt < MAX_COLLISION_ATTEMPTS; attempt++) {
    const qrToken = makeQrToken();
    const manualCode = makeManualCode();
    const qrHash = credentialHash(hmacKey, "qr", qrToken);
    const manualHash = credentialHash(hmacKey, "manual", manualCode);
    const qrIndexRef = db.collection("visitorGateCredentialIndex").doc(qrHash);
    const manualIndexRef = db.collection("visitorGateCredentialIndex").doc(manualHash);
    try {
      await db.runTransaction(async (transaction) => {
        const host = await authorizedResident(db, auth, (ref) => transaction.get(ref));
        const trustedScope = {hostUserId: host.uid, residentId: host.uid,
          communityId: host.communityId, flatId: host.flatId};
        for (const [field, trustedValue] of Object.entries(trustedScope)) {
          if (data?.[field] != null && data[field] !== trustedValue) {
            fail("permission-denied", "Visitor invitation scope does not match the authenticated Resident.");
          }
        }
        const nowMs = now();
        visitor = visitorFields(data, host, nowMs);
        decision = invitationDecision({community: host.community, profile: host.profile,
          arrival: Number(data.expectedArrival), pet: visitor.bringingPet, now: nowMs});
        visitor.visitorPolicySnapshot = decision.snapshot;
        // Preserve direct-write contracts until client migration. Strict records
        // are always backend-owned, even after a community disables enforcement.
        if (decision.snapshot.enforced) Object.assign(visitor, {
          authorizationManaged: true, authorizationState: decision.authorizationState, authorizationRevision: 1,
        });
        const [qrIndex, manualIndex] = await Promise.all([
          transaction.get(qrIndexRef), transaction.get(manualIndexRef),
        ]);
        if (qrIndex.exists || manualIndex.exists) throw Object.assign(new Error("credential_collision"), {collision: true});
        transaction.create(visitorRef, visitor);
        transaction.create(credentialRef, {
          hostUserId: host.uid, communityId: host.communityId,
          qrToken, manualCode, credentialVersion: 1,
          validFrom: visitor.credentialValidFrom, expiresAt: visitor.credentialExpiresAt,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.create(qrIndexRef, {...makeCredentialIndex({hash: qrHash, visitorId, communityId: host.communityId, type: "qr", validFrom: visitor.credentialValidFrom, expiresAt: visitor.credentialExpiresAt}), hostUserId: host.uid});
        transaction.create(manualIndexRef, {...makeCredentialIndex({hash: manualHash, visitorId, communityId: host.communityId, type: "manual", validFrom: visitor.credentialValidFrom, expiresAt: visitor.credentialExpiresAt}), hostUserId: host.uid});
        transaction.create(auditRef, buildAuditLog({actorUid: host.uid, actorRole: "resident",
          communityId: host.communityId, action: "visitor.invite", targetType: "visitor", targetId: visitorId,
          summary: "Visitor invitation created.", metadata: {newState: decision.authorizationState,
            revision: decision.snapshot.revision, enforced: decision.snapshot.enforced,
            effectivePolicy: decision.snapshot.approvalMode, emergency: decision.snapshot.emergency,
            identityBasis: decision.snapshot.identityBasis, bringingPet: visitor.bringingPet}}));
      });
      if (decision.authorizationState === "pending_admin") return {visitorId,
        authorizationState: "pending_admin", authorizationRevision: 1, credentialsAvailable: false};
      return {visitorId, qrToken, visitorPassCode: `${manualCode.slice(0, 4)}-${manualCode.slice(4)}`};
    } catch (error) {
      if (!error?.collision) throw error;
    }
  }
  fail("resource-exhausted", "Could not issue unique visitor credentials. Retry shortly.");
}

async function getVisitorCredentialsCore({ db, auth, data, hmacKey, now = Date.now }) {
  const visitorId = text(data?.visitorId, 160);
  const visitorRef = db.collection("visitors").doc(visitorId);
  return db.runTransaction(async (transaction) => {
    const host = await authorizedResident(db, auth, (ref) =>
      transaction.get(ref),
    );
    const [visitorSnapshot, credentialSnapshot] = await Promise.all([
      transaction.get(visitorRef),
      transaction.get(db.collection("visitorHostCredentials").doc(visitorId)),
    ]);
    if (!visitorSnapshot.exists)
      fail("not-found", "Visitor pass is unavailable.");
    const visitor = visitorSnapshot.data();
    if (
      visitor.hostUserId !== host.uid ||
      visitor.communityId !== host.communityId
    ) {
      fail(
        "permission-denied",
        "This visitor pass is not available to this Resident.",
      );
    }
    function currentAuthorization() {
      const nowMs = now();
      const arrival = millis(visitor.expectedArrival ?? visitor.expectedTime);
      const deadlines = [visitorPolicyRevalidationAt(host.community, nowMs),
        arrival == null ? null : arrival - WINDOW_MS,
        arrival == null ? null : arrival + WINDOW_MS + 1]
        .filter((value) => value != null && value > nowMs);
      const timing = {serverTime: nowMs,
        revalidateAt: deadlines.length ? Math.min(...deadlines) : null};
      try {
        if (!visitorEligible(visitor, nowMs)) {
          fail("permission-denied", "This visitor pass is not available to this Resident.");
        }
        assertVisitorAuthorized(visitor, host.community, { now: nowMs, profile: host.profile });
      } catch (error) {
        // Only after host/community ownership has been checked. These details
        // contain no credential or authorization grant, including on denial.
        if (error instanceof RegistrationError) error.details = timing;
        throw error;
      }
      return timing;
    }
    currentAuthorization();
    if (credentialSnapshot.exists) {
      const credentials = credentialSnapshot.data();
      if (
        credentials.hostUserId !== host.uid ||
        credentials.communityId !== host.communityId
      ) {
        fail("permission-denied", "Visitor credential access is denied.");
      }
      const qrHash = credentialHash(hmacKey, "qr", credentials.qrToken);
      const manualHash = credentialHash(
        hmacKey,
        "manual",
        credentials.manualCode,
      );
      const [qrIndex, manualIndex] = await Promise.all([
        transaction.get(
          db.collection("visitorGateCredentialIndex").doc(qrHash),
        ),
        transaction.get(
          db.collection("visitorGateCredentialIndex").doc(manualHash),
        ),
      ]);
      if (
        !qrIndex.exists ||
        !manualIndex.exists ||
        qrIndex.data()?.credentialType !== "qr" ||
        manualIndex.data()?.credentialType !== "manual" ||
        qrIndex.data()?.credentialVersion !== 1 ||
        manualIndex.data()?.credentialVersion !== 1 ||
        qrIndex.data()?.visitorId !== visitorId ||
        manualIndex.data()?.visitorId !== visitorId ||
        qrIndex.data()?.communityId !== host.communityId ||
        manualIndex.data()?.communityId !== host.communityId
      ) {
        fail(
          "failed-precondition",
          "Visitor credentials are unavailable. Contact support.",
        );
      }
      return {
        ...currentAuthorization(),
        qrToken: credentials.qrToken,
        visitorPassCode: credentials.manualCode,
      };
    }
    if (
      visitor.credentialVersion === 1 ||
      visitor.legacyCredentialSunsetAt != null
    ) {
      fail(
        "failed-precondition",
        "Migrated visitor credentials are unavailable. Contact support.",
      );
    }
    // Transitional retrieval is host-authenticated; legacy data is not copied or changed here.
    const qrToken =
      typeof visitor.qrToken === "string" ? visitor.qrToken : null;
    const visitorPassCode =
      typeof visitor.visitorPassCode === "string"
        ? visitor.visitorPassCode
        : null;
    if (!qrToken && !visitorPassCode)
      fail("not-found", "Visitor credentials are unavailable.");
    currentAuthorization();
    return { qrToken, visitorPassCode, legacy: true };
  });
}

function planLegacyCredentialMigration({visitorId, visitor, hmacKey, now = Date.now(), forceNewManualCode = false}) {
  if (!visitor || typeof visitor !== "object") return {action: "skip", reason: "invalid_document"};
  const hostUserId = visitor.hostUserId || visitor.residentId;
  if (!hostUserId || !visitor.communityId ||
      (visitor.hostUserId && visitor.residentId && visitor.hostUserId !== visitor.residentId)) {
    return {action: "skip", reason: "missing_host_or_community"};
  }
  if (["completed", "departed", "checked_out", "rejected", "cancelled", "canceled"].includes(visitor.status) ||
      visitor.actualArrival != null || visitor.departure != null) return {action: "skip", reason: "terminal_visit"};
  if (!visitorEligible(visitor, now)) return {action: "skip", reason: "expired_or_ineligible"};
  const sourceQrToken = typeof visitor.qrToken === "string" ? visitor.qrToken : null;
  const sourceManualCode = typeof visitor.visitorPassCode === "string" ? visitor.visitorPassCode : null;
  const qrTokenValid = validQrToken(sourceQrToken);
  const manualCodeValid = validManualCode(sourceManualCode);
  const qrToken = qrTokenValid ? sourceQrToken : generateQrToken();
  const manualCode = manualCodeValid && !forceNewManualCode
    ? normalizeManualCode(sourceManualCode) : generateManualCode();
  return {
    action: "migrate", visitorId, hostUserId,
    communityId: visitor.communityId, qrToken, manualCode,
    sourceHostUserId: visitor.hostUserId || null,
    sourceResidentId: visitor.residentId || null,
    sourceQrValue: visitor.qrToken ?? null,
    sourceManualValue: visitor.visitorPassCode ?? null,
    missingQrToken: visitor.qrToken == null,
    missingManualCode: visitor.visitorPassCode == null,
    invalidQrToken: visitor.qrToken != null && !qrTokenValid,
    invalidManualCode: visitor.visitorPassCode != null && !manualCodeValid,
    duplicateManualCode: forceNewManualCode,
    sunsetsLegacyCredentials: true,
    qrHash: credentialHash(hmacKey, "qr", qrToken),
    manualHash: credentialHash(hmacKey, "manual", manualCode),
    validFrom: visitor.credentialValidFrom ||
      Timestamp.fromMillis(millis(visitor.expectedArrival ?? visitor.expectedTime) - WINDOW_MS),
    expiresAt: visitor.credentialExpiresAt ||
      Timestamp.fromMillis(millis(visitor.expectedArrival ?? visitor.expectedTime) + WINDOW_MS),
  };
}

module.exports = {
  MAX_COLLISION_ATTEMPTS, authorizedResident, createVisitorInvitationCore,
  credentialHash, generateManualCode, generateQrToken, getVisitorCredentialsCore,
  normalizeManualCode, planLegacyCredentialMigration, validManualCode, validQrToken, visitorEligible,
};
