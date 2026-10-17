const crypto = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {RegistrationError} = require("./register_resident");
const {credentialHash, normalizeManualCode} = require("./visitor_credentials");
const {requireSecurity, pendingVisitor, previouslyApprovedVisitor, isVisitValid} = require("./visitor_gate");

const MANUAL_ATTEMPT_WINDOW_MS = 5 * 60 * 1000;
const MAX_MANUAL_ATTEMPTS_PER_WINDOW = 10;

function denied() {
  throw new RegistrationError("permission-denied", "Visitor credential could not be verified.");
}

function operationId(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{16,100}$/.test(value)) {
    throw new RegistrationError("invalid-argument", "A valid verification operation ID is required.");
  }
  return value;
}

function digest(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (Number.isFinite(value)) return value;
  return null;
}

function verifySecuritySnapshot(snapshot, communitySnapshot, security, auth) {
  const profile = snapshot.data();
  return snapshot.exists && profile?.uid === security.uid && profile.role === "security" &&
    profile.isActive === true && profile.communityId === security.communityId &&
    profile.phoneNumber === auth.token.phone_number && communitySnapshot.exists &&
    communitySnapshot.data()?.isActive === true;
}

async function recordManualAttempt({db, security, auth, now, operationRef, candidateVisitorId}) {
  const rateLimitId = digest(`${security.uid}|${security.communityId}`);
  const rateRef = db.collection("visitorGateRateLimits").doc(rateLimitId);
  const securityRef = db.collection("securityStaff").doc(security.uid);
  const communityRef = db.collection("communities").doc(security.communityId);

  await db.runTransaction(async (transaction) => {
    const [securitySnapshot, communitySnapshot, rateSnapshot, operationSnapshot] = await Promise.all([
      transaction.get(securityRef), transaction.get(communityRef), transaction.get(rateRef),
      transaction.get(operationRef),
    ]);
    if (!verifySecuritySnapshot(securitySnapshot, communitySnapshot, security, auth)) {
      throw new RegistrationError("permission-denied", "Security authorization is no longer valid.");
    }
    const priorOperation = operationSnapshot.data();
    if (operationSnapshot.exists && candidateVisitorId &&
        priorOperation?.securityUid === security.uid &&
        priorOperation?.communityId === security.communityId &&
        priorOperation?.visitorId === candidateVisitorId &&
        priorOperation?.verificationMethod === "manual" && priorOperation?.status === "inside") {
      return;
    }
    const current = rateSnapshot.data();
    const nowMs = now();
    const windowStartedAt = timestampMillis(current?.windowStartedAt);
    const inWindow = windowStartedAt != null && nowMs - windowStartedAt < MANUAL_ATTEMPT_WINDOW_MS;
    const attempts = inWindow ? Number(current?.attempts || 0) : 0;
    if (attempts >= MAX_MANUAL_ATTEMPTS_PER_WINDOW) {
      throw new RegistrationError("resource-exhausted", "Too many manual visitor-code attempts. Try again later.");
    }
    transaction.set(rateRef, {
      securityUid: security.uid,
      communityId: security.communityId,
      windowStartedAt: inWindow ? current.windowStartedAt : new Date(nowMs),
      attempts: attempts + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function parseCredential(data) {
  const qrToken = typeof data?.qrToken === "string" ? data.qrToken.trim() : "";
  const manualInput = typeof data?.manualCode === "string" ? data.manualCode : "";
  const manualCode = normalizeManualCode(manualInput);
  if (Boolean(qrToken) === Boolean(manualInput)) {
    throw new RegistrationError("invalid-argument", "Provide exactly one visitor credential.");
  }
  if (qrToken) {
    if (qrToken.length > 512 || /\s/.test(qrToken)) denied();
    return {type: "qr", value: qrToken};
  }
  // Eight characters is the minimum supported for migrated legacy codes; new
  // invitations use twelve. The rate limit applies before format/lookup checks.
  return {type: "manual", value: manualCode};
}

async function verifyVisitorCredentialCore({db, auth, data, hmacKey, now = Date.now}) {
  const security = await requireSecurity(db, auth);
  const credential = parseCredential(data);
  const opId = operationId(data?.operationId);
  if (!credential.value || (credential.type === "manual" &&
      (credential.value.length < 8 || credential.value.length > 32))) {
    const operationKey = digest(`${security.uid}|${security.communityId}|${opId}`);
    if (credential.type === "manual") await recordManualAttempt({db, security, auth, now,
      operationRef: db.collection("visitorGateOperations").doc(operationKey), candidateVisitorId: null});
    denied();
  }

  const indexId = credentialHash(hmacKey, credential.type, credential.value);
  const indexRef = db.collection("visitorGateCredentialIndex").doc(indexId);
  const securityRef = db.collection("securityStaff").doc(security.uid);
  const communityRef = db.collection("communities").doc(security.communityId);
  const operationKey = digest(`${security.uid}|${security.communityId}|${opId}`);
  const operationRef = db.collection("visitorGateOperations").doc(operationKey);
  const eventRef = db.collection("visitorGateEvents").doc(operationKey);
  if (credential.type === "manual") {
    const candidateIndex = await indexRef.get();
    await recordManualAttempt({db, security, auth, now, operationRef,
      candidateVisitorId: candidateIndex.exists ? candidateIndex.data()?.visitorId : null});
  }

  return db.runTransaction(async (transaction) => {
    const [securitySnapshot, communitySnapshot, indexSnapshot, priorOperation] = await Promise.all([
      transaction.get(securityRef), transaction.get(communityRef),
      transaction.get(indexRef), transaction.get(operationRef),
    ]);
    if (!verifySecuritySnapshot(securitySnapshot, communitySnapshot, security, auth)) {
      throw new RegistrationError("permission-denied", "Security authorization is no longer valid.");
    }
    if (!indexSnapshot.exists) denied();
    const index = indexSnapshot.data();
    if (index?.credentialType !== credential.type || index?.credentialVersion !== 1 ||
        index?.communityId !== security.communityId || typeof index?.visitorId !== "string" ||
        !index.visitorId) denied();

    const visitorRef = db.collection("visitors").doc(index.visitorId);
    const privateCredentialRef = db.collection("visitorHostCredentials").doc(index.visitorId);
    const [visitorSnapshot, privateCredentialSnapshot] = await Promise.all([
      transaction.get(visitorRef), transaction.get(privateCredentialRef),
    ]);
    if (!visitorSnapshot.exists || !privateCredentialSnapshot.exists) denied();
    const visitor = visitorSnapshot.data();
    const privateCredential = privateCredentialSnapshot.data();
    const submittedValue = credential.type === "qr" ? privateCredential?.qrToken :
      normalizeManualCode(privateCredential?.manualCode);
    if (visitor.communityId !== security.communityId ||
        privateCredential.communityId !== security.communityId ||
        privateCredential.credentialVersion !== 1 || submittedValue !== credential.value ||
        privateCredential.hostUserId !== visitor.hostUserId ||
        timestampMillis(index.validFrom) == null || timestampMillis(index.expiresAt) == null) denied();

    const nowMs = now();
    const validFrom = timestampMillis(index.validFrom);
    const expiresAt = timestampMillis(index.expiresAt);
    const privateValidFrom = timestampMillis(privateCredential.validFrom);
    const privateExpiresAt = timestampMillis(privateCredential.expiresAt);
    if (privateValidFrom !== validFrom || privateExpiresAt !== expiresAt) denied();
    const operation = priorOperation.data();
    if (priorOperation.exists) {
      if (operation.securityUid !== security.uid || operation.communityId !== security.communityId ||
          operation.visitorId !== index.visitorId || operation.verificationMethod !== credential.type ||
          operation.status !== "inside") denied();
      return {...operation.response, idempotent: true};
    }
    if (visitor.gateAccessStatus === "denied" || visitor.gateEntryDeniedAt != null ||
        nowMs < validFrom || nowMs > expiresAt || !isVisitValid(visitor, nowMs) ||
        (!pendingVisitor(visitor) && !previouslyApprovedVisitor(visitor))) denied();

    const flatLabel = String(visitor.flatLabel || visitor.flatId || "").slice(0, 80);
    const response = {
      visitorId: index.visitorId,
      visitorName: String(visitor.visitorName || "Visitor").slice(0, 120),
      phoneNumber: String(visitor.phoneNumber || visitor.phone || "").slice(0, 40),
      hostName: String(visitor.hostName || visitor.residentName || "Resident").slice(0, 120),
      flatId: String(visitor.flatId || "").slice(0, 120),
      flatLabel,
      purpose: String(visitor.purpose || "").slice(0, 300),
      status: "inside",
      verificationMethod: credential.type,
    };
    transaction.update(visitorRef, {
      status: "inside",
      actualArrival: FieldValue.serverTimestamp(),
      checkedInBy: security.uid,
      verificationMethod: credential.type,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationRef, {
      securityUid: security.uid,
      communityId: security.communityId,
      visitorId: index.visitorId,
      verificationMethod: credential.type,
      status: "inside",
      response,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(eventRef, {
      securityUid: security.uid,
      communityId: security.communityId,
      visitorId: index.visitorId,
      verificationMethod: credential.type,
      eventType: "visitor_checked_in",
      outcome: "inside",
      createdAt: FieldValue.serverTimestamp(),
    });
    return {...response, idempotent: false};
  });
}

module.exports = {
  MANUAL_ATTEMPT_WINDOW_MS,
  MAX_MANUAL_ATTEMPTS_PER_WINDOW,
  verifyVisitorCredentialCore,
};
