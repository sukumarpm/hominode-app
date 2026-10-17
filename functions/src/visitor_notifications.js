const crypto = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {
  notificationAudienceKey,
  requireActiveCommunity,
  requireCanonicalRecipient,
  visitorNotificationId,
} = require("./notifications");

const DELIVERY_COLLECTION = "visitorNotificationDeliveries";
const NOTIFICATION_COLLECTION = "notifications";
const MAX_SEND_ATTEMPTS = 3;
const TRANSIENT_MESSAGING_CODES = new Set([
  "messaging/server-unavailable",
  "messaging/internal-error",
  "messaging/unavailable",
  "messaging/unknown-error",
  "messaging/quota-exceeded",
  "messaging/device-message-rate-exceeded",
  "messaging/topics-message-rate-exceeded",
]);
const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function eventForTransition(before = {}, after = {}) {
  if (after.status === "approved" && before.status !== "approved" &&
      after.isApproved === true && after.approvedBy && after.approvedAt != null) {
    return {eventType: "visitor_approved", actorUid: after.approvedBy, eventAt: after.approvedAt};
  }
  if (after.status === "rejected" && before.status !== "rejected" &&
      after.rejectedBy && after.rejectedAt != null) {
    return {eventType: "visitor_rejected", actorUid: after.rejectedBy, eventAt: after.rejectedAt};
  }
  if (after.status === "inside" && before.actualArrival == null &&
      after.actualArrival != null && after.checkedInBy) {
    return {
      eventType: "visitor_checked_in",
      actorUid: after.checkedInBy,
      eventAt: after.actualArrival,
      verificationMethod: after.verificationMethod || "legacy_qr",
    };
  }
  if ((after.gateAccessStatus === "denied" || after.gateEntryDeniedAt != null) &&
      before.gateAccessStatus !== "denied" && before.gateEntryDeniedAt == null &&
      after.gateEntryDeniedBy && after.gateEntryDeniedAt != null) {
    return {
      eventType: "visitor_entry_denied",
      actorUid: after.gateEntryDeniedBy,
      eventAt: after.gateEntryDeniedAt,
      reason: safeReason(after.gateEntryDenialReason),
    };
  }
  if (after.status === "completed" && before.status !== "completed" &&
      before.departure == null && after.departure != null && after.checkedOutBy) {
    return {eventType: "visitor_checked_out", actorUid: after.checkedOutBy, eventAt: after.departure};
  }
  return null;
}

function safeReason(value) {
  if (typeof value !== "string") return "";
  return value.replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{43}(?![A-Za-z0-9_-])/g, "[redacted]")
    .replace(/(?<![A-Za-z0-9])[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}(?![A-Za-z0-9])/gi, "[redacted]")
    .replace(/\s+/g, " ").trim().slice(0, 300);
}

function eventCopy(eventType, visitorName, reason) {
  const name = String(visitorName || "Your visitor").replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, 120) || "Your visitor";
  switch (eventType) {
    case "visitor_approved": return {title: "Visitor approved", message: `${name} was approved to visit.`};
    case "visitor_rejected": return {title: "Visitor rejected", message: `${name}'s visit request was rejected.`};
    case "visitor_checked_in": return {title: "Visitor checked in", message: `${name} checked in.`};
    case "visitor_entry_denied": return {
      title: "Visitor entry denied",
      message: reason ? `${name} was denied entry. Reason: ${reason}` : `${name} was denied entry.`,
    };
    case "visitor_checked_out": return {title: "Visitor checked out", message: `${name} checked out.`};
    default: return null;
  }
}

function timestampString(value) {
  if (value && typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return "";
}

async function sendTokenBatch({messaging, tokens, message, waitForRetry}) {
  let pending = [...tokens];
  let successCount = 0;
  let failureCount = 0;
  let attempts = 0;
  const invalidTokens = new Set();

  for (let attempt = 1; pending.length && attempt <= MAX_SEND_ATTEMPTS; attempt++) {
    attempts++;
    const response = await messaging.sendEachForMulticast({...message, tokens: pending});
    const retry = [];
    for (let index = 0; index < response.responses.length; index++) {
      const result = response.responses[index];
      const token = pending[index];
      if (result.success) {
        successCount++;
      } else if (INVALID_TOKEN_CODES.has(result.error?.code)) {
        invalidTokens.add(token);
        failureCount++;
      } else if (TRANSIENT_MESSAGING_CODES.has(result.error?.code) && attempt < MAX_SEND_ATTEMPTS) {
        retry.push(token);
      } else {
        failureCount++;
      }
    }
    pending = retry;
    if (pending.length) await waitForRetry(1000 * (2 ** (attempt - 1)));
  }

  failureCount += pending.length;
  return {successCount, failureCount, invalidTokens, attempts};
}

async function dispatchVisitorDecisionCore({db, messaging, event, waitForRetry = wait}) {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const transition = eventForTransition(before, after);
  const hostUserId = after.hostUserId || after.residentId;
  if (!transition || !after.communityId || !hostUserId ||
      (after.hostUserId && after.residentId && after.hostUserId !== after.residentId) ||
      (before.communityId && before.communityId !== after.communityId) ||
      (before.hostUserId && before.hostUserId !== hostUserId)) {
    return {ignored: true};
  }

  const visitorId = event.params.visitorId;
  const eventId = visitorNotificationId(visitorId, transition.eventType, hostUserId);
  const deliveryRef = db.collection(DELIVERY_COLLECTION).doc(eventId);
  const notificationRef = db.collection(NOTIFICATION_COLLECTION).doc(eventId);
  const copy = eventCopy(transition.eventType, after.visitorName, transition.reason);
  let eligible = false;
  try {
    await requireCanonicalRecipient(db, {
      recipientUid: hostUserId, communityId: after.communityId,
      role: "resident", appId: "resident",
    });
    await requireActiveCommunity(db, after.communityId);
    eligible = true;
  } catch (_) {
    // Do not persist or send a visitor notification to an inactive or mismatched host.
  }
  if (!eligible) return {ignored: true, recipientUnavailable: true};

  const data = {
    visitorId,
    visitorName: String(after.visitorName || "Your visitor").slice(0, 120),
    status: after.status || "",
    actorUid: transition.actorUid,
    eventAt: transition.eventAt || null,
    ...(transition.verificationMethod ? {verificationMethod: transition.verificationMethod} : {}),
    ...(transition.reason ? {reason: transition.reason} : {}),
  };
  let claimed = false;
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(deliveryRef);
    if (existing.exists) return;
    transaction.create(deliveryRef, {
      visitorId, recipientUid: hostUserId, communityId: after.communityId,
      eventType: transition.eventType, actorUid: transition.actorUid,
      eventAt: transition.eventAt || null, deliveryStatus: "sending",
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(notificationRef, {
      communityId: after.communityId, recipientId: hostUserId,
      audience: "resident", role: "resident", appId: "resident",
      title: copy.title, message: copy.message,
      type: "visitor", eventType: transition.eventType, data,
      priority: "normal", sourceEntityId: visitorId,
      createdBy: transition.actorUid, actorUid: transition.actorUid,
      eventAt: transition.eventAt || null,
      isRead: false, deliveryStatus: "pending",
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    claimed = true;
  });
  if (!claimed) return {duplicate: true};

  try {
    const devices = await db.collection("notificationDevices")
      .where("audienceKey", "==", notificationAudienceKey({
        appId: "resident", role: "resident", communityId: after.communityId, uid: hostUserId,
      })).get();
    const tokenDevices = new Map();
    for (const doc of devices.docs) {
      const device = doc.data();
      if (device.active === true && device.uid === hostUserId &&
          device.communityId === after.communityId && device.appId === "resident" &&
          device.role === "resident" && typeof device.token === "string") {
        if (!tokenDevices.has(device.token)) tokenDevices.set(device.token, []);
        tokenDevices.get(device.token).push(doc);
      }
    }
    const tokens = [...tokenDevices.keys()];
    let successCount = 0;
    let failureCount = 0;
    let attempts = 0;
    const invalidTokens = new Set();
    if (tokens.length && messaging) {
      for (let index = 0; index < tokens.length; index += 500) {
        const batchTokens = tokens.slice(index, index + 500);
        const pushData = {
          type: "notification", entityId: eventId, communityId: after.communityId,
          eventType: transition.eventType, visitorId,
          visitorName: data.visitorName, status: data.status,
          actorUid: transition.actorUid, eventAt: timestampString(transition.eventAt),
        };
        const result = await sendTokenBatch({
          messaging, tokens: batchTokens, waitForRetry,
          message: {
            notification: {title: copy.title, body: copy.message},
            data: pushData,
            android: {priority: "high", notification: {channelId: "hominode_high_importance"}},
            apns: {headers: {"apns-priority": "10"}, payload: {aps: {sound: "default"}}},
          },
        });
        successCount += result.successCount;
        failureCount += result.failureCount;
        attempts += result.attempts;
        for (const token of result.invalidTokens) invalidTokens.add(token);
      }
    }
    for (const token of invalidTokens) {
      for (const device of tokenDevices.get(token) || []) {
        await db.runTransaction(async (transaction) => {
          const current = await transaction.get(device.ref);
          if (current.exists && current.data()?.token === token) transaction.delete(device.ref);
        });
      }
    }
    const deliveryStatus = !tokens.length ? "no_devices" : !messaging ? "failed" :
      failureCount === 0 ? "sent" : successCount > 0 ? "partial" : "failed";
    await Promise.all([
      deliveryRef.update({deliveryStatus, successCount, failureCount, attempts, updatedAt: FieldValue.serverTimestamp()}),
      notificationRef.update({deliveryStatus, successCount, failureCount, attempts, sentAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()}),
    ]);
    return {deliveryStatus, successCount, failureCount};
  } catch (_) {
    // Notification delivery is best effort and never changes the visitor transition.
    await Promise.all([
      deliveryRef.update({deliveryStatus: "failed", updatedAt: FieldValue.serverTimestamp()}),
      notificationRef.update({deliveryStatus: "failed", updatedAt: FieldValue.serverTimestamp()}),
    ]);
    return {deliveryStatus: "failed"};
  }
}

module.exports = {dispatchVisitorDecisionCore, eventForTransition, sendTokenBatch};
