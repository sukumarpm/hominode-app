"use strict";
const { createHash, randomBytes, randomUUID } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");
const { hasVerifiedPhoneAuth } = require("./phone_auth");

const COLLECTION = "securitySupportRequests";
const TOPICS = Object.freeze({
  technical_issue: "App or technical issue", other: "Other support",
  phone_number: "Registered phone number", gate_shift: "Gate or shift assignment",
  account_access: "Account provisioning or access",
});
const ADMIN_TOPICS = new Set(["phone_number", "gate_shift", "account_access"]);
const id = value => typeof value === "string" && value.length > 0 && value.length <= 128 && !/[\/\x00-\x1f]/.test(value) && ![".", ".."].includes(value);
const hash = value => createHash("sha256").update(value).digest("hex");
const receipt = record => ({ reference: record.reference, status: "received", destination: record.destination, communityName: record.communityName });

async function securitySupportRequestCore({ db, auth, data, sendMail, now = Date.now }) {
  if (!hasVerifiedPhoneAuth(auth) || !id(auth.uid)) throw new HttpsError("unauthenticated", "Sign in with your Security account.");
  const submit = data?.action === "submit";
  const allowed = submit ? ["action", "topic", "message", "requestKey"] : ["action"];
  if (!data || typeof data !== "object" || Array.isArray(data) || !["context", "submit"].includes(data.action) || Object.keys(data).some(key => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "A valid support request is required.");
  }
  let message, fingerprint;
  if (submit) {
    if (!Object.hasOwn(TOPICS, data.topic) || typeof data.message !== "string" || data.message.length > 2000 ||
        typeof data.requestKey !== "string" || !/^[a-f0-9]{32}$/.test(data.requestKey)) {
      throw new HttpsError("invalid-argument", "Choose a topic and describe the issue in 10–2000 characters.");
    }
    message = data.message.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, " ").trim();
    if (message.length < 10) throw new HttpsError("invalid-argument", "Describe the issue in at least 10 characters.");
    fingerprint = hash(`${data.topic}\n${message}`);
  }
  const leaseId = randomUUID();
  const ref = submit ? db.collection(COLLECTION).doc(hash(`${auth.uid}/${data.requestKey}`)) : null;
  const claim = await db.runTransaction(async tx => {
    const staff = (await tx.get(db.collection("securityStaff").doc(auth.uid))).data();
    if (!staff || staff.uid !== auth.uid || staff.role !== "security" || staff.isActive !== true ||
        staff.phoneNumber !== auth.token.phone_number || !id(staff.communityId)) {
      throw new HttpsError("permission-denied", "An active matching Security account is required.");
    }
    const community = (await tx.get(db.collection("communities").doc(staff.communityId))).data();
    if (community?.isActive !== true) throw new HttpsError("permission-denied", "Your community could not be verified.");
    const communityName = String(community.name || community.communityName || staff.communityId).trim().slice(0, 120);
    if (!submit) return { response: { communityName } };
    const existing = (await tx.get(ref)).data();
    if (existing && (existing.uid !== auth.uid || existing.communityId !== staff.communityId || existing.fingerprint !== fingerprint)) {
      throw new HttpsError("failed-precondition", "The request or account assignment changed. Start a new request.");
    }
    if (existing?.status === "received") return { response: receipt(existing) };
    if (existing?.delivery?.state === "sending" && existing.delivery.leaseExpiresAt > now()) {
      throw new HttpsError("aborted", "Your request is still being submitted. Please wait and retry.");
    }
    const limitRef = db.collection("securitySupportRequestLimits").doc(hash(auth.uid));
    const limit = (await tx.get(limitRef)).data();
    const day = new Date(now()).toISOString().slice(0, 10);
    if (!existing && limit && (now() - limit.lastSubmittedAt < 60000 || (limit.day === day && limit.count >= 10))) {
      throw new HttpsError("resource-exhausted", "Please wait before sending another request, or try again tomorrow if you reached the daily limit.");
    }
    const destination = ADMIN_TOPICS.has(data.topic) ? "community_admin" : "hominode_support";
    const admins = destination === "community_admin"
      ? (await tx.get(db.collection("admins").where("authorizedCommunityIds", "array-contains", staff.communityId).limit(100))).docs
        .filter(doc => { const profile = doc.data(); return profile.uid === doc.id && profile.role === "admin" && profile.isActive === true &&
          Array.isArray(profile.authorizedCommunityIds) && profile.authorizedCommunityIds.includes(staff.communityId); })
      : [];
    if (destination === "community_admin" && !admins.length) {
      throw new HttpsError("failed-precondition", "No active Community Admin could be reached. Choose Other support to contact Hominode Support.");
    }
    const record = existing ?? { uid: auth.uid, communityId: staff.communityId, communityName,
      reference: `HSP-${randomBytes(12).toString("hex").toUpperCase()}`, fingerprint,
      topic: data.topic, message, destination, sourceApp: "security",
      identity: { name: String(staff.name || "Security officer").trim().slice(0, 120), phoneNumber: staff.phoneNumber },
      createdAt: FieldValue.serverTimestamp() };
    if (!existing) tx.set(limitRef, { lastSubmittedAt: now(), day, count: limit?.day === day ? limit.count + 1 : 1 });
    if (destination === "community_admin") {
      for (const admin of admins) {
        tx.set(db.collection("notifications").doc(`security-support-${hash(`${ref.id}/${admin.id}`).slice(0, 40)}`), {
          communityId: staff.communityId, recipientId: admin.id, audience: "admin", role: "admin", appId: "admin",
          title: `Security request: ${TOPICS[data.topic]}`,
          message: `${record.identity.name} (${record.identity.phoneNumber})\n\n${message}\n\nReference: ${record.reference}`,
          type: "general", priority: "medium", sourceEntityId: ref.id,
          metadata: { eventType: "security_support_request", reference: record.reference, topic: data.topic },
          isRead: false, deliveryStatus: "sent", deliveryChannel: "in_app",
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
      }
      tx.set(ref, { ...record, status: "received", delivery: { state: "sent", channel: "admin_notifications" }, updatedAt: FieldValue.serverTimestamp() });
      return { response: receipt(record) };
    }
    tx.set(ref, { ...record, status: "pending_delivery", delivery: { state: "sending", leaseId, leaseExpiresAt: now() + 120000 }, updatedAt: FieldValue.serverTimestamp() });
    return { record };
  });
  if (claim.response) return claim.response;
  async function finish(state) {
    await db.runTransaction(async tx => {
      const fresh = (await tx.get(ref)).data();
      if (fresh?.delivery?.leaseId !== leaseId) throw new HttpsError("aborted", "Please retry to confirm your request.");
      tx.update(ref, { status: state === "sent" ? "received" : "pending_delivery", delivery: { state, leaseExpiresAt: null }, updatedAt: FieldValue.serverTimestamp() });
    });
  }
  const record = claim.record;
  try {
    await sendMail({ from: "Hominode Support <hominodecare@gmail.com>", to: "hominodecare@gmail.com",
      subject: `[Hominode Security Support] ${record.reference}`,
      text: ["Authenticated Security support request", `Reference: ${record.reference}`, `Topic: ${TOPICS[record.topic]}`,
        `Community: ${record.communityName} (${record.communityId})`, `Officer: ${record.identity.name}`,
        `Verified registered phone: ${record.identity.phoneNumber}`, "", record.message,
        "", "This is a support request, not an account-deletion request or authorization to change any account or audit record."].join("\n"),
    });
  } catch (_) {
    try { await finish("failed"); } catch (_) { /* Retry retains the request and reference. */ }
    throw new HttpsError("unavailable", "Your request could not be confirmed. Retry with the same message.");
  }
  await finish("sent");
  return receipt(record);
}

module.exports = { securitySupportRequestCore, COLLECTION };
