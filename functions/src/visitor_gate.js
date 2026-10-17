const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { RegistrationError } = require("./register_resident");
const {credentialHash} = require("./visitor_credentials");

const QR_VALIDITY_MS = 24 * 60 * 60 * 1000;

function invalid(message = "This visitor pass is invalid or expired.") {
  throw new RegistrationError("failed-precondition", message);
}

function legacyCredentialEligible(visitor) {
  return visitor?.credentialVersion == null && visitor?.legacyCredentialSunsetAt == null;
}

function assertLegacyCredentialWindow(cutoffUtc, nowMs) {
  if (cutoffUtc == null) return;
  if (typeof cutoffUtc !== "string" ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(cutoffUtc)) {
    throw new RegistrationError("failed-precondition", "Legacy visitor verification is unavailable.");
  }
  const cutoffMs = Date.parse(cutoffUtc);
  if (!Number.isFinite(cutoffMs) || new Date(cutoffMs).toISOString() !== cutoffUtc || nowMs >= cutoffMs) {
    throw new RegistrationError("failed-precondition", "Legacy visitor verification is unavailable.");
  }
}

function requireString(value, label, maxLength = 200) {
  if (typeof value !== "string" || !value.trim() || value.length > maxLength) {
    throw new RegistrationError("invalid-argument", `A valid ${label} is required.`);
  }
  return value.trim();
}

async function requireSecurity(db, auth) {
  if (!auth?.uid || !auth.token?.phone_number || auth.token.firebase?.sign_in_provider !== "phone") {
    throw new RegistrationError("unauthenticated", "Verified phone authentication is required.");
  }
  const profileRef = db.collection("securityStaff").doc(auth.uid);
  const profileSnapshot = await profileRef.get();
  const profile = profileSnapshot.data();
  if (!profileSnapshot.exists || profile?.uid !== auth.uid || profile?.role !== "security" ||
      profile?.isActive !== true || typeof profile?.communityId !== "string" || !profile.communityId.trim()) {
    throw new RegistrationError("permission-denied", "An active Security account is required.");
  }
  if (profile.phoneNumber !== auth.token.phone_number) {
    throw new RegistrationError("permission-denied", "The verified phone does not match the Security account.");
  }
  const communityRef = db.collection("communities").doc(profile.communityId.trim());
  const communitySnapshot = await communityRef.get();
  if (!communitySnapshot.exists || communitySnapshot.data()?.isActive !== true) {
    throw new RegistrationError("permission-denied", "The assigned community is unavailable.");
  }
  return {uid: auth.uid, communityId: profile.communityId.trim()};
}

function isVisitValid(visitor, nowMs) {
  const expected = visitor.expectedArrival ?? visitor.expectedTime;
  const expectedMs = expected instanceof Timestamp ? expected.toMillis() :
    expected instanceof Date ? expected.getTime() : NaN;
  return Number.isFinite(expectedMs) && Math.abs(nowMs - expectedMs) <= QR_VALIDITY_MS;
}

function pendingVisitor(visitor) {
  return ["expected", "pending"].includes(visitor.status) &&
    visitor.isApproved === false && visitor.actualArrival == null && visitor.departure == null;
}

function previouslyApprovedVisitor(visitor) {
  return visitor.status === "approved" && visitor.isApproved === true &&
    visitor.actualArrival == null && visitor.departure == null;
}

async function privateCredentialFor({db, token, hmacKey}) {
  const indexId = credentialHash(hmacKey, "qr", token);
  const index = await db.collection("visitorGateCredentialIndex").doc(indexId).get();
  if (!index.exists) return null;
  const value = index.data();
  if (value?.credentialType !== "qr" || !value.visitorId || !value.communityId) return null;
  const [visitor, credential] = await Promise.all([
    db.collection("visitors").doc(value.visitorId).get(),
    db.collection("visitorHostCredentials").doc(value.visitorId).get(),
  ]);
  if (!visitor.exists || !credential.exists || credential.data()?.qrToken !== token ||
      visitor.data()?.communityId !== value.communityId) return null;
  return {id: value.visitorId, data: () => visitor.data()};
}

async function resolveVisitorQrCore({db, auth, data, hmacKey, legacyCredentialCutoffUtc, now = Date.now}) {
  const security = await requireSecurity(db, auth);
  const token = typeof data?.qrToken === "string" ? data.qrToken.trim() : "";
  const legacyVisitorId = typeof data?.legacyVisitorId === "string" ? data.legacyVisitorId.trim() : "";
  if (Boolean(token) === Boolean(legacyVisitorId)) {
    throw new RegistrationError("invalid-argument", "A visitor QR credential is required.");
  }
  if (token && (token.length > 512 || /\s/.test(token))) {
    throw new RegistrationError("invalid-argument", "The visitor QR credential is invalid.");
  }
  let doc;
  if (token) {
    const snapshot = await db.collection("visitors").where("qrToken", "==", token).limit(2).get();
    const legacyMatches = snapshot.docs.filter((item) => legacyCredentialEligible(item.data()));
    if (legacyMatches.length === 1) {
      assertLegacyCredentialWindow(legacyCredentialCutoffUtc, now());
      doc = legacyMatches[0];
    }
    else if (legacyMatches.length === 0 && hmacKey) doc = await privateCredentialFor({db, token, hmacKey});
    if (!doc) invalid();
  } else {
    const snapshot = await db.collection("visitors").doc(requireString(legacyVisitorId, "visitor QR credential", 160)).get();
    if (!snapshot.exists || snapshot.data()?.qrToken != null || !legacyCredentialEligible(snapshot.data())) invalid();
    assertLegacyCredentialWindow(legacyCredentialCutoffUtc, now());
    doc = {id: legacyVisitorId, data: () => snapshot.data()};
  }
  const visitor = doc.data();
  if (visitor.communityId !== security.communityId || visitor.gateAccessStatus === "denied" ||
      visitor.gateEntryDeniedAt != null ||
      (!pendingVisitor(visitor) && !previouslyApprovedVisitor(visitor)) ||
      !isVisitValid(visitor, now())) invalid();
  return {
    visitorId: doc.id,
    visitorName: String(visitor.visitorName || "").slice(0, 160),
    hostName: String(visitor.hostName || visitor.residentName || "").slice(0, 160),
    flatId: String(visitor.flatId || "").slice(0, 80),
    flatLabel: String(visitor.flatLabel || visitor.flatId || "").slice(0, 80),
    phoneNumber: String(visitor.phoneNumber || visitor.phone || "").slice(0, 40),
    purpose: String(visitor.purpose || "").slice(0, 300),
    expectedArrival: visitor.expectedArrival?.toMillis?.() ?? null,
    canReject: pendingVisitor(visitor),
  };
}

async function transitionVisitorFromQrCore({db, auth, data, hmacKey, legacyCredentialCutoffUtc, now = Date.now}) {
  const security = await requireSecurity(db, auth);
  const visitorId = requireString(data?.visitorId, "visitor ID", 160);
  const token = typeof data?.qrToken === "string" ? data.qrToken.trim() : "";
  const legacyVisitorId = typeof data?.legacyVisitorId === "string" ? data.legacyVisitorId.trim() : "";
  if (Boolean(token) === Boolean(legacyVisitorId) ||
      (legacyVisitorId && legacyVisitorId !== visitorId)) {
    throw new RegistrationError("invalid-argument", "The visitor QR credential is invalid.");
  }
  if (token.length > 512 || /\s/.test(token)) {
    throw new RegistrationError("invalid-argument", "The visitor QR credential is invalid.");
  }
  const action = requireString(data?.action, "visitor action", 16);
  if (!['approve', 'reject'].includes(action)) {
    throw new RegistrationError("invalid-argument", "The visitor action is invalid.");
  }
  const ref = db.collection("visitors").doc(visitorId);
  const securityRef = db.collection("securityStaff").doc(security.uid);
  const communityRef = db.collection("communities").doc(security.communityId);
  const indexRef = token && hmacKey
    ? db.collection("visitorGateCredentialIndex").doc(credentialHash(hmacKey, "qr", token))
    : null;
  const credentialRef = token ? db.collection("visitorHostCredentials").doc(visitorId) : null;
  return db.runTransaction(async (transaction) => {
    const securitySnapshot = await transaction.get(securityRef);
    const communitySnapshot = await transaction.get(communityRef);
    const snapshot = await transaction.get(ref);
    const indexSnapshot = indexRef ? await transaction.get(indexRef) : null;
    const credentialSnapshot = credentialRef ? await transaction.get(credentialRef) : null;
    const currentSecurity = securitySnapshot.data();
    if (!securitySnapshot.exists || currentSecurity?.uid !== security.uid ||
        currentSecurity?.phoneNumber !== auth.token.phone_number ||
        currentSecurity?.role !== "security" || currentSecurity?.isActive !== true ||
        currentSecurity?.communityId !== security.communityId || !communitySnapshot.exists ||
        communitySnapshot.data()?.isActive !== true) {
      throw new RegistrationError("permission-denied", "Security authorization is no longer valid.");
    }
    if (!snapshot.exists) invalid();
    const visitor = snapshot.data();
    const privateIndex = indexSnapshot?.data();
    const privateCredential = credentialSnapshot?.data();
    const legacyTokenMatch = Boolean(token) && legacyCredentialEligible(visitor) && visitor.qrToken === token;
    const legacyIdMatch = Boolean(legacyVisitorId) && legacyCredentialEligible(visitor) &&
      visitor.qrToken == null && legacyVisitorId === visitorId;
    if (legacyTokenMatch || legacyIdMatch) {
      assertLegacyCredentialWindow(legacyCredentialCutoffUtc, now());
    }
    const credentialMatches = token
      ? legacyTokenMatch || (privateIndex?.credentialType === "qr" &&
        privateIndex?.visitorId === visitorId && privateIndex?.communityId === security.communityId &&
        privateCredential?.qrToken === token && privateCredential?.communityId === security.communityId)
      : legacyIdMatch;
    if (visitor.communityId !== security.communityId || visitor.gateAccessStatus === "denied" ||
        visitor.gateEntryDeniedAt != null || !credentialMatches ||
        !isVisitValid(visitor, now())) invalid();
    const allowedPending = pendingVisitor(visitor);
    const allowedPreviouslyApproved = action === 'approve' && previouslyApprovedVisitor(visitor);
    if (!allowedPending && !allowedPreviouslyApproved) {
      throw new RegistrationError("failed-precondition", "This visitor request has already been processed.");
    }
    if (action === 'reject' && !allowedPending) invalid();
    if (action === 'reject') {
      transaction.update(ref, {
        status: 'rejected', isApproved: false, rejectedBy: security.uid,
        rejectedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      return {visitorId, status: 'rejected', visitorName: visitor.visitorName || 'Visitor'};
    }
    transaction.update(ref, {
      status: 'inside', isApproved: true, actualArrival: FieldValue.serverTimestamp(),
      checkedInBy: security.uid,
      ...(allowedPending ? {approvedBy: security.uid, approvedAt: FieldValue.serverTimestamp()} : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {visitorId, status: 'inside', visitorName: visitor.visitorName || 'Visitor'};
  });
}

module.exports = {
  QR_VALIDITY_MS, isVisitValid, pendingVisitor, previouslyApprovedVisitor,
  requireSecurity, legacyCredentialEligible, assertLegacyCredentialWindow,
  resolveVisitorQrCore, transitionVisitorFromQrCore,
};
