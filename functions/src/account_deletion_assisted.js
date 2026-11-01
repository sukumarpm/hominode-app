const { FieldValue } = require("firebase-admin/firestore");
const { createHash } = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");
const { requireOperationalAdmin } = require("./resident_identity");
const { APP_CONTEXTS } = require("./notifications");
const { hasVerifiedPhoneAuth } = require("./phone_auth");
const { validateRecentAuth } = require("./account_deletion_requests");
const { initialRetry } = require("./account_deletion_retry");
const { buildAuditLog } = require("./audit_log");
const {
  ASSISTED_SOURCE,
  ASSISTED_METHODS,
  validId,
  validReference,
  assistedIntakeDigest,
  isAssistedIntake,
  hasResidentDeletionVerification,
} = require("./account_deletion_verification");

function exact(data, fields) {
  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    Object.keys(data).some((field) => !fields.includes(field))
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Only the documented assisted-deletion fields are accepted.",
    );
  }
}
function intakeInput(data) {
  exact(data, [
    "residentUid",
    "communityId",
    "supportCaseReference",
    "verificationMethod",
    "verificationEvidenceReference",
    "verificationNotes",
    "consentAttested",
  ]);
  if (
    !validId(data.residentUid) ||
    !validId(data.communityId) ||
    data.communityId.length > 80 ||
    !validReference(data.supportCaseReference) ||
    data.supportCaseReference.length > 80 ||
    !ASSISTED_METHODS.has(data.verificationMethod) ||
    !validReference(data.verificationEvidenceReference) ||
    data.verificationEvidenceReference === data.supportCaseReference ||
    data.consentAttested !== true
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Resident, community, independent verification evidence and explicit deletion consent are required. Email or a support-case reference alone is insufficient.",
    );
  }
  const notes = data.verificationNotes;
  if (
    typeof notes !== "string" ||
    notes.trim().length < 20 ||
    notes.length > 600 ||
    /[\u0000-\u0008\u000b\u000c\u000e-\u001f]|data:|base64|<img|https?:\/\/|gs:\/\/|[A-Za-z0-9+/]{160,}={0,2}/i.test(
      notes,
    )
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Provide a brief text verification summary (20–600 characters), not identity-document images, image data or document links. Use a protected evidence reference.",
    );
  }
  return { ...data, verificationNotes: notes.trim() };
}
async function requireAssistedSession(db, auth, app, tx, now) {
  validateRecentAuth(auth, Math.floor(now / 1000));
  const context = APP_CONTEXTS[app?.appId];
  if (
    context?.role !== "admin" ||
    context.appId !== "admin" ||
    !hasVerifiedPhoneAuth(auth)
  )
    throw new HttpsError(
      "permission-denied",
      "Use a verified phone session in the authorized Admin application.",
    );
  const ref = db.collection("admins").doc(auth.uid),
    snapshot = await (tx ? tx.get(ref) : ref.get());
  const profile = snapshot.data();
  if (
    !snapshot.exists ||
    profile?.uid !== auth.uid ||
    profile.role !== "admin" ||
    profile.isActive !== true ||
    profile.phoneNumber !== auth.token.phone_number ||
    !Array.isArray(profile.authorizedCommunityIds) ||
    !profile.authorizedCommunityIds.length
  ) {
    throw new HttpsError(
      "permission-denied",
      "An active canonical Community Admin is required.",
    );
  }
}
async function authorizedAdmin(db, auth, app, communityId, tx, now) {
  await requireAssistedSession(db, auth, app, tx, now);
  return requireOperationalAdmin(db, auth, communityId, tx);
}
async function canonicalResident(db, tx, uid, communityId) {
  const [resident, admin, security] = await Promise.all(
    ["users", "admins", "securityStaff"].map((collection) =>
      tx.get(db.collection(collection).doc(uid)),
    ),
  );
  const profile = resident.data();
  if (
    !resident.exists ||
    profile?.uid !== uid ||
    profile.role !== "resident" ||
    profile.communityId !== communityId ||
    admin.exists ||
    security.exists ||
    (profile.communityIds != null &&
      (!Array.isArray(profile.communityIds) ||
        profile.communityIds.some((id) => id !== communityId))) ||
    ["deleted", "completed"].includes(profile.status)
  )
    throw new HttpsError(
      "failed-precondition",
      "An existing canonical single-community Resident without another account role is required.",
    );
  return profile;
}
function audit(
  tx,
  db,
  requestId,
  phase,
  actorUid,
  uid,
  communityId,
  intake,
  intakeDigest,
) {
  tx.create(
    db.collection("auditLogs").doc(`${requestId}_${phase}`),
    buildAuditLog({
      actorUid,
      actorRole: "admin",
      communityId,
      action: `account_deletion.assisted_${phase}`,
      targetType: "resident",
      targetId: uid,
      summary:
        phase === "intake"
          ? "Admin-assisted deletion intake recorded; verification pending."
          : "Resident identity and explicit deletion consent independently verified.",
      metadata: {
        requestId,
        supportCaseReference: intake.supportCaseReference,
        verificationMethod: intake.verificationMethod,
        verificationEvidenceReference: intake.verificationEvidenceReference,
        consentAttested: true,
        intakeDigest,
        ...(phase === "verified"
          ? { identityConfirmed: true, consentConfirmed: true }
          : {}),
      },
    }),
  );
}

async function createAdminAssistedDeletionRequestCore({
  db,
  auth,
  app,
  data,
  now = Date.now(),
}) {
  const input = intakeInput(data);
  await authorizedAdmin(db, auth, app, input.communityId, null, now);
  const requestId = `assisted_${createHash("sha256").update(input.residentUid).digest("hex")}`;
  const collection = db.collection("accountDeletionRequests"),
    ref = collection.doc(requestId);
  return db.runTransaction(async (tx) => {
    const actor = await authorizedAdmin(
      db,
      auth,
      app,
      input.communityId,
      tx,
      now,
    );
    const [existing, related] = await Promise.all([
      tx.get(ref),
      tx.get(collection.where("uid", "==", input.residentUid)),
    ]);
    const prior = existing.data();
    if (
      existing.exists &&
      prior.status === "completed" &&
      prior.uid === input.residentUid &&
      prior.communityId === input.communityId &&
      hasResidentDeletionVerification(
        prior,
        requestId,
        Math.max(now, Date.now()),
      ) &&
      [
        "supportCaseReference",
        "verificationMethod",
        "verificationEvidenceReference",
        "verificationNotes",
        "consentAttested",
      ].every((field) => prior.assistedIntake[field] === input[field])
    ) {
      return {
        requestId,
        status: "completed",
        sourceApp: ASSISTED_SOURCE,
        intakeDigest: prior.intakeDigest,
        idempotent: true,
      };
    }
    const profile = await canonicalResident(
      db,
      tx,
      input.residentUid,
      input.communityId,
    );
    const records = related.docs.filter((doc) => doc.id !== requestId);
    if (
      records.some(
        (doc) =>
          doc.data().communityId !== input.communityId ||
          doc.data().status === "completed",
      )
    ) {
      throw new HttpsError(
        "failed-precondition",
        "An existing deletion lifecycle requires reconciliation; no new assisted intake was created.",
      );
    }
    const active = records.filter(
      (doc) =>
        !["completed", "cancelled", "rejected"].includes(doc.data().status),
    );
    if (active.length) {
      if (
        active.length === 1 &&
        hasResidentDeletionVerification(
          active[0].data(),
          active[0].id,
          Math.max(now, Date.now()),
        )
      )
        return {
          requestId: active[0].id,
          status: active[0].data().status,
          sourceApp: active[0].data().sourceApp,
          idempotent: true,
          existingVerifiedRequest: true,
        };
      throw new HttpsError(
        "failed-precondition",
        "An existing incomplete, unverified or ambiguous deletion request must be reconciled before assisted intake.",
      );
    }
    if (existing.exists) {
      const request = existing.data(),
        intake = request.assistedIntake;
      if (
        !isAssistedIntake(request, requestId, Math.max(now, Date.now())) ||
        request.uid !== input.residentUid ||
        request.communityId !== input.communityId ||
        [
          "supportCaseReference",
          "verificationMethod",
          "verificationEvidenceReference",
          "verificationNotes",
          "consentAttested",
        ].some((field) => intake[field] !== input[field])
      ) {
        throw new HttpsError(
          "already-exists",
          "An assisted request already exists with different evidence or scope. Its identity and consent evidence cannot be overwritten.",
        );
      }
      return {
        requestId,
        status: request.status,
        sourceApp: ASSISTED_SOURCE,
        intakeDigest: request.intakeDigest,
        idempotent: true,
      };
    }
    const timestamp = FieldValue.serverTimestamp();
    const intake = {
      schemaVersion: 1,
      initiatedBy: actor.uid,
      initiatedAt: timestamp,
      supportCaseReference: input.supportCaseReference,
      verificationMethod: input.verificationMethod,
      verificationEvidenceReference: input.verificationEvidenceReference,
      verificationNotes: input.verificationNotes,
      consentAttested: true,
    };
    const intakeDigest = assistedIntakeDigest(
      requestId,
      input.residentUid,
      input.communityId,
      intake,
    );
    tx.create(ref, {
      requestId,
      uid: input.residentUid,
      sourceApp: ASSISTED_SOURCE,
      communityId: input.communityId,
      communityScopeVerified: true,
      status: "pending_assisted_verification",
      reviewStatus: "pending_identity_verification",
      routingStatus: "pending_identity_verification",
      financialReviewStatus: "UNKNOWN_REQUIRES_REVIEW",
      deletionPolicyVersion: 2,
      assistedIntake: intake,
      intakeDigest,
      retainedResidentIdentity: {
        name:
          String(profile.fullName || profile.name || "")
            .trim()
            .slice(0, 120) || null,
        phoneNumber:
          String(profile.phoneNumber || profile.phone || "")
            .trim()
            .slice(0, 40) || null,
        unit:
          String(profile.flatLabel || profile.unitId || profile.flatId || "")
            .trim()
            .slice(0, 120) || null,
        communityId: input.communityId,
        communityName:
          String(actor.community.name || actor.community.communityName || "")
            .trim()
            .slice(0, 120) || null,
        residentType: ["owner", "tenant"].includes(
          profile.residentType || profile.ownershipType,
        )
          ? profile.residentType || profile.ownershipType
          : null,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
      processing: null,
    });
    audit(
      tx,
      db,
      requestId,
      "intake",
      actor.uid,
      input.residentUid,
      input.communityId,
      intake,
      intakeDigest,
    );
    return {
      requestId,
      status: "pending_assisted_verification",
      sourceApp: ASSISTED_SOURCE,
      intakeDigest,
      idempotent: false,
    };
  });
}

async function verifyAdminAssistedDeletionRequestCore({
  db,
  auth,
  app,
  data,
  now = Date.now(),
}) {
  exact(data, [
    "requestId",
    "intakeDigest",
    "identityConfirmed",
    "consentConfirmed",
  ]);
  if (
    !validId(data.requestId) ||
    !/^[a-f0-9]{64}$/.test(data.intakeDigest || "") ||
    data.identityConfirmed !== true ||
    data.consentConfirmed !== true
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Confirm independent identity verification and explicit Resident deletion consent against the saved intake digest.",
    );
  }
  await requireAssistedSession(db, auth, app, null, now);
  const ref = db.collection("accountDeletionRequests").doc(data.requestId);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref),
      request = snapshot.data();
    if (
      !snapshot.exists ||
      !isAssistedIntake(request, data.requestId, Math.max(now, Date.now()))
    )
      throw new HttpsError(
        "failed-precondition",
        "A valid pending Admin-assisted intake is required.",
      );
    const actor = await authorizedAdmin(
      db,
      auth,
      app,
      request.communityId,
      tx,
      now,
    );
    if (data.intakeDigest !== request.intakeDigest)
      throw new HttpsError(
        "failed-precondition",
        "Intake evidence changed. Review the saved intake again.",
      );
    if (
      hasResidentDeletionVerification(
        request,
        data.requestId,
        Math.max(now, Date.now()),
      )
    )
      return {
        requestId: data.requestId,
        status: request.status,
        verificationStatus: "verified",
        idempotent: true,
      };
    if (
      request.status !== "pending_assisted_verification" ||
      request.verificationCompletedAt ||
      request.assistedVerification ||
      request.retry
    )
      throw new HttpsError(
        "failed-precondition",
        "The intake is no longer awaiting assisted verification.",
      );
    await canonicalResident(db, tx, request.uid, request.communityId);
    const timestamp = FieldValue.serverTimestamp();
    tx.update(ref, {
      assistedVerification: {
        schemaVersion: 1,
        requestId: data.requestId,
        uid: request.uid,
        communityId: request.communityId,
        intakeDigest: request.intakeDigest,
        verifiedBy: actor.uid,
        verifiedAt: timestamp,
        identityConfirmed: true,
        consentConfirmed: true,
        verificationMethod: request.assistedIntake.verificationMethod,
        verificationEvidenceReference:
          request.assistedIntake.verificationEvidenceReference,
      },
      verificationCompletedAt: timestamp,
      status: "pending_review",
      reviewStatus: "processing",
      routingStatus: "processing",
      financialReviewStatus: "NOT_REQUIRED",
      retry: initialRetry(now),
      updatedAt: timestamp,
    });
    audit(
      tx,
      db,
      data.requestId,
      "verified",
      actor.uid,
      request.uid,
      request.communityId,
      request.assistedIntake,
      request.intakeDigest,
    );
    return {
      requestId: data.requestId,
      status: "pending_review",
      verificationStatus: "verified",
      processingStatus: "queued",
      idempotent: false,
    };
  });
}
module.exports = {
  createAdminAssistedDeletionRequestCore,
  verifyAdminAssistedDeletionRequestCore,
};
