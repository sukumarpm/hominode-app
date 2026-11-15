"use strict";

const { createHash, randomBytes, randomUUID } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");
const { hasVerifiedPhoneAuth } = require("./phone_auth");

// Manual intake only. These records never enter Resident deletion/cleanup jobs.
const COLLECTION = "securityAccountDeletionRequests";
const LEASE_MS = 120000;
const SUPPORT_ADDRESS = "hominodecare@gmail.com";
const documentId = (value) => typeof value === "string" && value.length > 0 &&
  value.length <= 128 && !/[\/\x00-\x1f]/.test(value) && ![".", ".."].includes(value);

function receipt(record) {
  return record ? {
    reference: record.reference,
    status: record.status,
    submitted: record.emailDelivery?.state === "sent",
  } : null;
}

async function securityAccountDeletionRequestCore({ db, auth, data, sendMail, now = Date.now }) {
  if (!hasVerifiedPhoneAuth(auth) || !documentId(auth.uid)) {
    throw new HttpsError("unauthenticated", "Sign in with your Security account to continue.");
  }
  const submitting = data?.action === "submit";
  const allowed = submitting ? ["action", "confirmed"] : ["action"];
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      !["status", "submit"].includes(data.action) || Object.keys(data).some(key => !allowed.includes(key)) ||
      (submitting && data.confirmed !== true)) {
    throw new HttpsError("invalid-argument", "Confirm a request for your own Security account.");
  }
  const ref = db.collection(COLLECTION).doc(createHash("sha256").update(auth.uid).digest("hex"));
  const leaseId = randomUUID();
  const claim = await db.runTransaction(async tx => {
    const staff = (await tx.get(db.collection("securityStaff").doc(auth.uid))).data();
    if (!staff || staff.uid !== auth.uid || staff.role !== "security" || staff.isActive !== true ||
        staff.phoneNumber !== auth.token.phone_number || !documentId(staff.communityId)) {
      throw new HttpsError("permission-denied", "An active matching Security account is required.");
    }
    const community = (await tx.get(db.collection("communities").doc(staff.communityId))).data();
    if (!community || community.isActive !== true) {
      throw new HttpsError("permission-denied", "Your community could not be verified. Contact your Community Admin.");
    }
    const communityName = String(community.name || community.communityName || staff.communityId).trim().slice(0, 120);
    const existing = (await tx.get(ref)).data();
    if (existing && (existing.uid !== auth.uid || existing.sourceApp !== "security" || existing.communityId !== staff.communityId)) {
      throw new HttpsError("failed-precondition", "Your account assignment changed. Contact Hominode Support about your existing request.");
    }
    if (!submitting || existing?.emailDelivery?.state === "sent") {
      return { response: { communityName, request: receipt(existing), idempotent: !!existing } };
    }
    if (existing?.emailDelivery?.state === "sending" && existing.emailDelivery.leaseExpiresAt > now()) {
      throw new HttpsError("aborted", "Your request is being submitted. Wait a moment, then check again.");
    }
    // Same private routing schema as the public community-dropdown form.
    // No client-supplied recipient, UID or community can reach this lookup.
    const contact = (await tx.get(db.collection("communityDeletionContacts").doc(staff.communityId))).data();
    const recipient = typeof contact?.email === "string" ? contact.email.trim().toLowerCase() : "";
    if (!recipient || recipient.length > 254 || /[\r\n]/.test(contact.email) || !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(recipient)) {
      throw new HttpsError("failed-precondition", "Your community's deletion-request contact is not configured. Contact your Community Admin or Hominode Support.");
    }
    const record = existing ?? {
      uid: auth.uid, sourceApp: "security", communityId: staff.communityId,
      communityName, reference: `SDR-${randomBytes(12).toString("hex").toUpperCase()}`,
      status: "pending_review", manualReviewOnly: true,
      identity: { name: String(staff.name || "Security officer").trim().slice(0, 120), phoneNumber: staff.phoneNumber },
      requestedAt: FieldValue.serverTimestamp(),
    };
    const emailDelivery = { state: "sending", leaseId, leaseExpiresAt: now() + LEASE_MS,
      attempts: (existing?.emailDelivery?.attempts ?? 0) + 1 };
    tx.set(ref, { ...record, emailDelivery, updatedAt: FieldValue.serverTimestamp() });
    return { record, recipient, communityName, idempotent: !!existing };
  });
  if (claim.response) return claim.response;

  async function finish(state) {
    await db.runTransaction(async tx => {
      const fresh = (await tx.get(ref)).data();
      if (fresh?.emailDelivery?.leaseId !== leaseId) {
        throw new HttpsError("aborted", "Your submission could not be confirmed. Please check again.");
      }
      tx.update(ref, { emailDelivery: { ...fresh.emailDelivery, state, leaseExpiresAt: null },
        updatedAt: FieldValue.serverTimestamp() });
    });
  }
  try {
    await sendMail({
      from: `Hominode Account Deletion <${SUPPORT_ADDRESS}>`,
      to: claim.recipient,
      subject: `[Hominode Security] Account deletion request ${claim.record.reference}`,
      text: [
        "A Security officer requested account deletion review.",
        `Reference: ${claim.record.reference}`,
        `Community: ${claim.communityName} (${claim.record.communityId})`,
        `Account UID: ${claim.record.uid}`,
        `Name: ${claim.record.identity.name}`,
        `Registered verified phone: ${claim.record.identity.phoneNumber}`,
        "",
        "MANUAL REVIEW ONLY — the account has not been deleted or disabled.",
        "Verify identity and consent, review and reassign duties, and assess retention before taking any action.",
        "Preserve security/audit history, gate logs and incident records. This request does not authorize automated cleanup.",
      ].join("\n"),
    });
  } catch (_) {
    try { await finish("failed"); } catch (_) { /* The same request remains retryable after its lease. */ }
    throw new HttpsError("unavailable", "Submission could not be confirmed. Please retry; your existing reference will be reused.");
  }
  await finish("sent");
  return { communityName: claim.communityName, request: receipt({ ...claim.record, emailDelivery: { state: "sent" } }), idempotent: claim.idempotent };
}

module.exports = { COLLECTION, securityAccountDeletionRequestCore };
