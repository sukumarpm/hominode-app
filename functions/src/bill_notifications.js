// Read-only bill projection into the existing recipient notification collection.
// No bill, payment, settlement or audit document is changed here.
const { createHash } = require("node:crypto");
const { FieldValue } = require("firebase-admin/firestore");
const validId = (v) =>
  typeof v === "string" && !!v && v === v.trim() && !v.includes("/");
const billNotificationId = (communityId, uid, billId) =>
  createHash("sha256")
    .update(`bill_created|${communityId}|${uid}|${billId}`)
    .digest("hex")
    .slice(0, 48);
async function billContext(db, billId, communityId, uid) {
  if (!validId(billId)) return null;
  const snapshot = await db.collection("bills").doc(billId).get();
  const bill = snapshot.data();
  if (
    !snapshot.exists ||
    bill.communityId !== communityId ||
    (bill.residentId || bill.userId) !== uid ||
    (bill.residentId && bill.userId && bill.residentId !== bill.userId)
  )
    return null;
  return bill;
}
async function existingBillNotification(db, communityId, uid, billId, tx) {
  const query = db
    .collection("notifications")
    .where("communityId", "==", communityId)
    .where("recipientId", "==", uid)
    .where("audience", "==", "resident")
    .where("role", "==", "resident")
    .where("appId", "==", "resident")
    .where("sourceEntityId", "==", billId)
    .where("type", "==", "payment")
    .where("title", "==", "New Bill Created")
    .limit(1);
  const prior = tx ? await tx.get(query) : await query.get();
  return prior.docs[0]?.id || null;
}
async function recordCreatedBillNotificationCore({ db, billId }) {
  if (!validId(billId)) return { created: false };
  const source = await db.collection("bills").doc(billId).get();
  const bill = source.data();
  if (
    !source.exists ||
    bill.schemaVersion !== 2 ||
    bill.currency !== "INR" ||
    !validId(bill.communityId) ||
    !validId(bill.residentId) ||
    !Number.isSafeInteger(bill.amountMinor) ||
    bill.amountMinor < 0 ||
    (bill.userId && bill.userId !== bill.residentId)
  )
    return { created: false };
  const id = billNotificationId(bill.communityId, bill.residentId, billId);
  return db.runTransaction(async (tx) => {
    const ref = db.collection("notifications").doc(id);
    const [old, user, community, current] = await Promise.all([
      tx.get(ref),
      tx.get(db.collection("users").doc(bill.residentId)),
      tx.get(db.collection("communities").doc(bill.communityId)),
      tx.get(source.ref),
    ]);
    if (
      old.exists ||
      (await existingBillNotification(
        db,
        bill.communityId,
        bill.residentId,
        billId,
        tx,
      ))
    )
      return { created: false, duplicate: true };
    const resident = user.data();
    if (
      !community.data()?.isActive ||
      resident?.uid !== bill.residentId ||
      resident.role !== "resident" ||
      resident.isActive !== true ||
      resident.approvalStatus !== "approved" ||
      (resident.status && resident.status !== "active") ||
      resident.communityId !== bill.communityId ||
      current.data()?.residentId !== bill.residentId ||
      current.data()?.communityId !== bill.communityId
    )
      return { created: false };
    tx.create(ref, {
      communityId: bill.communityId,
      recipientId: bill.residentId,
      audience: "resident",
      role: "resident",
      appId: "resident",
      type: "payment",
      eventType: "bill_created",
      title: "New Bill Created",
      message: "A new bill is available. Open Billing to view the details.",
      sourceEntityId: billId,
      data: { route: "billing", billId, eventType: "bill_created" },
      isRead: false,
      deliveryStatus: "inbox_only",
      createdBy: "system:billing-v2",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { created: true, notificationId: id };
  });
}
module.exports = {
  billContext,
  existingBillNotification,
  billNotificationId,
  recordCreatedBillNotificationCore,
};
