const crypto = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { sendCanonicalNotification } = require("./notifications");
const { operationalAccessFailure } = require("./resident_identity");
const {
  resolveCommunitySubscriptionCore,
  subscriptionCanUseFeature,
} = require("./subscription_management");
const { eventPushAllowed } = require("./event_notification_preferences");
const eventNotificationId = (communityId, eventId, uid) =>
  crypto
    .createHash("sha256")
    .update(`community_event_created|${communityId}|${eventId}|${uid}`)
    .digest("hex");
function eligible(profile, uid, communityId, community) {
  return (
    profile?.uid === uid &&
    profile.role === "resident" &&
    profile.communityId === communityId &&
    profile.isActive === true &&
    profile.approvalStatus === "approved" &&
    (!profile.status || profile.status === "active") &&
    !operationalAccessFailure(profile, { ...community, id: communityId })
  );
}
async function notifyCreatedEventCore({
  db,
  messaging,
  eventId,
  now = Date.now,
}) {
  if (typeof eventId !== "string" || !eventId || eventId.includes("/"))
    return { skipped: true };
  const source = await db.collection("events_announcements").doc(eventId).get();
  const event = source.data();
  if (
    !source.exists ||
    event.type !== "event" ||
    !event.communityId ||
    typeof event.title !== "string" ||
    !event.title.trim() ||
    ["cancelled", "deleted", "completed"].includes(event.status)
  )
    return { skipped: true };
  const communityId = event.communityId;
  const community = (
    await db.collection("communities").doc(communityId).get()
  ).data();
  const adminId = event.adminId || event.authorId;
  if (typeof adminId !== "string" || !adminId || adminId.includes("/"))
    return { skipped: true };
  const admin = (await db.collection("admins").doc(adminId).get()).data();
  if (
    community?.isActive !== true ||
    admin?.isActive !== true ||
    admin.uid !== adminId ||
    admin.role !== "admin" ||
    !admin.authorizedCommunityIds?.includes(communityId)
  )
    return { skipped: true };
  const subscription = await resolveCommunitySubscriptionCore({
    db,
    communityId,
  });
  if (!subscriptionCanUseFeature(subscription, "events", now()))
    return { skipped: true };
  let cursor,
    created = 0,
    attempted = 0;
  while (true) {
    let query = db
      .collection("users")
      .where("communityId", "==", communityId)
      .orderBy("__name__")
      .limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const user of page.docs) {
      if (!eligible(user.data(), user.id, communityId, community)) continue;
      const id = eventNotificationId(communityId, eventId, user.id);
      const ref = db.collection("notifications").doc(id);
      const claimed = await db.runTransaction(async (tx) => {
        const [existing, current] = await Promise.all([
          tx.get(ref),
          tx.get(user.ref),
        ]);
        if (!eligible(current.data(), user.id, communityId, community))
          return false;
        if (existing.exists) return false;
        tx.create(ref, {
          communityId,
          recipientId: user.id,
          audience: "resident",
          role: "resident",
          appId: "resident",
          type: "event",
          eventType: "community_event_created",
          title: event.title.trim().slice(0, 160),
          message:
            "A new community event is available. Open the event for details.",
          data: {
            route: "events",
            eventId,
            eventType: "community_event_created",
          },
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
          deliveryStatus: "sending",
        });
        return true;
      });
      if (!claimed) continue;
      created++;
      // At most one FCM attempt per resident/event: a crashed/ambiguous send is
      // not replayed, avoiding duplicate pushes. The durable inbox remains.
      try {
        attempted++;
        const result = await sendCanonicalNotification({
          db,
          messaging,
          recipientUid: user.id,
          communityId,
          role: "resident",
          appId: "resident",
          notificationId: id,
          title: event.title.trim().slice(0, 160),
          message: "A new community event is available.",
          notificationData: {
            route: "events",
            eventType: "community_event_created",
          },
          deviceFilter: (device) => eventPushAllowed(device, now()),
        });
        await ref.update({
          deliveryStatus: result.noDevices
            ? "no_devices"
            : result.failureCount
              ? "partial_failure"
              : "sent",
        });
      } catch (_) {
        await ref.update({ deliveryStatus: "failed" });
      }
    }
    if (page.size < 200) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return { created, attempted };
}
module.exports = { notifyCreatedEventCore, eventNotificationId, eligible };
