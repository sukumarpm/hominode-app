const { createHash } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const {
  sendCanonicalNotification,
  requireCanonicalRecipient,
  requireActiveCommunity,
} = require("./notifications");

// Hide IDs must not depend on report/audit IDs, which encode reporter identity.
const notificationIdForDecision = (auditId, decision) =>
  createHash("sha256")
    .update(
      JSON.stringify(
        decision.action === "hide"
          ? [
              "moderation_hide",
              decision.communityId,
              decision.postId,
              decision.commentId || "",
              decision.notificationRecipientId,
            ]
          : ["moderation_dismiss", auditId, decision.notificationRecipientId],
      ),
    )
    .digest("hex");

// Existing audit creates are the delivery event. Old decisions have no version marker.
async function dispatchModerationDecisionCore({ db, messaging, auditId }) {
  const auditRef = db.collection("moderationAudit").doc(auditId);
  const source = await auditRef.get(),
    decision = source.data();
  if (
    !source.exists ||
    decision.decisionVersion !== 1 ||
    !["hide", "dismiss"].includes(decision.action) ||
    !["post", "comment"].includes(decision.targetType) ||
    !decision.notificationRecipientId ||
    typeof decision.publicReason !== "string" ||
    !decision.publicReason.trim()
  )
    return { ignored: true };
  const recipientUid = decision.notificationRecipientId,
    communityId = decision.communityId;
  try {
    await requireCanonicalRecipient(db, {
      recipientUid,
      communityId,
      role: "resident",
      appId: "resident",
    });
    await requireActiveCommunity(db, communityId);
  } catch (error) {
    if (
      ["failed-precondition", "permission-denied", "not-found"].includes(
        error.code,
      )
    )
      return { ignored: true, recipientUnavailable: true };
    throw error; // Transient reads can retry without touching the moderation decision.
  }
  const notificationId = notificationIdForDecision(auditId, decision);
  const ref = db.collection("notifications").doc(notificationId);
  const dismissed = decision.action === "dismiss";
  const title = dismissed
    ? "Report reviewed and dismissed"
    : `${decision.targetType === "comment" ? "Comment" : "Post"} hidden by Community Admin`;
  const message = `${dismissed ? "Your report was reviewed and dismissed." : `Your ${decision.targetType} was hidden by Community Admin.`} Reason: ${decision.publicReason}`;
  const eventType = dismissed
    ? "moderation_report_dismissed"
    : `moderation_${decision.targetType}_hidden`;
  const claimed = await db.runTransaction(async (tx) => {
    const [old, current, user, community] = await Promise.all([
      tx.get(ref),
      tx.get(auditRef),
      tx.get(db.collection("users").doc(recipientUid)),
      tx.get(db.collection("communities").doc(communityId)),
    ]);
    if (old.exists) return false;
    const latest = current.data(),
      profile = user.data();
    if (
      latest?.notificationRecipientId !== recipientUid ||
      latest.communityId !== communityId ||
      latest.decisionVersion !== 1 ||
      profile?.uid !== recipientUid ||
      profile.role !== "resident" ||
      profile.communityId !== communityId ||
      profile.approvalStatus !== "approved" ||
      profile.isActive !== true ||
      (profile.status != null && profile.status !== "active") ||
      community.data()?.isActive !== true
    )
      return false;
    tx.create(ref, {
      communityId,
      recipientId: recipientUid,
      audience: "resident",
      role: "resident",
      appId: "resident",
      type: "general",
      eventType,
      title,
      message,
      isRead: false,
      priority: "normal",
      sourceEntityId: decision.postId,
      createdBy: decision.actorId,
      // Deliberately excludes report ID, reporter identity, report text and internal notes.
      data: {
        route: "notifications",
        eventType,
        targetType: decision.targetType,
        publicReason: decision.publicReason,
      },
      deliveryStatus: "sending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!claimed) return { duplicate: true };
  // Claim before FCM: event retries never resend a push accepted before a crash.
  try {
    const result = await sendCanonicalNotification({
      db,
      messaging,
      recipientUid,
      communityId,
      role: "resident",
      appId: "resident",
      notificationId,
      title,
      message,
      notificationData: { eventType, route: "notifications" },
    });
    const deliveryStatus = result.noDevices
      ? "no_devices"
      : result.failureCount
        ? "failed"
        : "sent";
    await ref.update({
      deliveryStatus,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { notificationId, deliveryStatus };
  } catch (_) {
    // A delivery/bookkeeping failure never alters the committed moderation audit/content.
    await ref
      .update({
        deliveryStatus: "failed",
        updatedAt: FieldValue.serverTimestamp(),
      })
      .catch(() => {});
    return { notificationId, deliveryStatus: "failed" };
  }
}
module.exports = { dispatchModerationDecisionCore, notificationIdForDecision };
