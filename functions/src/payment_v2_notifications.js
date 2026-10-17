const crypto = require('node:crypto');
const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const {sendCanonicalNotification} = require('./notifications');

const EVENT_COLLECTION = 'billingV2PaymentNotificationEvents';
const NOTIFICATION_COLLECTION = 'notifications';
const OFFLINE_METHOD_LABELS = Object.freeze({
  cash: 'Cash',
  bank_transfer: 'Bank transfer',
  cheque: 'Cheque',
  upi: 'Direct UPI',
});

function eventIdFor(eventType, sourceId) {
  return crypto.createHash('sha256').update(`billing_v2|${eventType}|${sourceId}`).digest('hex').slice(0, 48);
}

function formatInrMinorUnits(value) {
  if (!Number.isSafeInteger(value) || value <= 0) throw new TypeError('Invalid payment amount.');
  const whole = Math.floor(value / 100).toLocaleString('en-IN');
  return `₹${whole}.${String(value % 100).padStart(2, '0')}`;
}

function presentation(eventType, event) {
  switch (eventType) {
    case 'payment_proof_submitted':
      return {
        title: 'Payment proof submitted',
        message: `Your claimed payment amount of ${formatInrMinorUnits(event.claimedAmountMinor)} is awaiting Admin verification. This is not confirmation that funds were received.`,
      };
    case 'payment_proof_verified':
      return {
        title: 'Payment verified',
        message: `Your Admin confirmed receipt of ${formatInrMinorUnits(event.confirmedAmountMinor)}. View Billing for the settlement details.`,
      };
    case 'payment_proof_rejected':
      return {
        title: 'Payment proof needs attention',
        message: 'Your payment proof was not approved. Open Billing for details or contact your community Admin.',
      };
    case 'offline_payment_settled': {
      const method = OFFLINE_METHOD_LABELS[event.method];
      if (!method || method === 'Direct UPI') throw new TypeError('Invalid offline payment method.');
      return {
        title: 'Payment recorded by Admin',
        message: `Your Admin recorded a ${method} payment of ${formatInrMinorUnits(event.confirmedAmountMinor)}. View Billing for the settlement details.`,
      };
    }
    default:
      throw new TypeError('Unsupported Billing V2 payment event.');
  }
}

function buildPaymentNotification(eventType, sourceId, event, nowMs) {
  if (!['payment_proof_submitted', 'payment_proof_verified', 'payment_proof_rejected', 'offline_payment_settled'].includes(eventType) ||
      typeof sourceId !== 'string' || !sourceId || typeof event.communityId !== 'string' || !event.communityId ||
      typeof event.recipientUid !== 'string' || !event.recipientUid) {
    throw new TypeError('Invalid Billing V2 notification event.');
  }
  const {title, message} = presentation(eventType, event);
  const id = eventIdFor(eventType, sourceId);
  const timestamp = Timestamp.fromMillis(nowMs);
  const notification = {
    communityId: event.communityId,
    recipientId: event.recipientUid,
    audience: 'resident',
    role: 'resident',
    appId: 'resident',
    title,
    message,
    type: 'payment',
    eventType,
    data: {route: 'billing', eventType},
    isRead: false,
    deliveryStatus: 'pending',
    createdBy: 'system:billing-v2',
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  const outbox = {
    schemaVersion: 1,
    id,
    eventType,
    sourceId,
    communityId: event.communityId,
    recipientUid: event.recipientUid,
    title,
    message,
    route: 'billing',
    status: 'pending',
    createdAt: timestamp,
  };
  return {id, notification, outbox};
}

function createPaymentNotificationWrites(tx, db, eventType, sourceId, event, nowMs) {
  const built = buildPaymentNotification(eventType, sourceId, event, nowMs);
  tx.create(db.collection(NOTIFICATION_COLLECTION).doc(built.id), built.notification);
  tx.create(db.collection(EVENT_COLLECTION).doc(built.id), built.outbox);
  return built.id;
}

function parseFinalizedProofObject(object) {
  const name = object?.name;
  const match = typeof name === 'string' && /^payment_receipts\/([^/]+)\/([^/]+)\/([^/]+)\/([^/.]+)\.(jpg|jpeg|png|heic|heif)$/i.exec(name);
  const metadata = object?.metadata;
  if (!match || !metadata || typeof metadata !== 'object' ||
      metadata.communityId !== match[1] || metadata.billId !== match[2] ||
      metadata.residentUid !== match[3] || metadata.paymentId !== match[4] ||
      !/^image\/(jpeg|jpg|png|heic|heif)$/i.test(object.contentType || '') ||
      !object.generation || !Number.isSafeInteger(Number(object.size)) || Number(object.size) <= 0 || Number(object.size) >= 10 * 1024 * 1024) {
    return null;
  }
  return {name, communityId: match[1], billId: match[2], residentUid: match[3], paymentId: match[4]};
}

async function createProofSubmittedNotification({db, object, now = Date.now}) {
  const upload = parseFinalizedProofObject(object);
  if (!upload) return {created: false, reason: 'invalid_upload'};
  const proofRef = db.collection('paymentProofsV2').doc(upload.paymentId);
  const eventId = eventIdFor('payment_proof_submitted', upload.paymentId);
  return db.runTransaction(async tx => {
    const proofSnapshot = await tx.get(proofRef);
    const userSnapshot = await tx.get(db.collection('users').doc(upload.residentUid));
    const communitySnapshot = await tx.get(db.collection('communities').doc(upload.communityId));
    const eventSnapshot = await tx.get(db.collection(EVENT_COLLECTION).doc(eventId));
    const proof = proofSnapshot.data();
    if (!proofSnapshot.exists || proof?.schemaVersion !== 2 || proof.status !== 'pending' ||
        proof.id !== upload.paymentId || proof.residentId !== upload.residentUid ||
        proof.communityId !== upload.communityId || proof.billId !== upload.billId ||
        proof.receiptPath !== upload.name || proof.evidenceType !== 'receipt' ||
        !Number.isSafeInteger(proof.submittedAmountMinor) || proof.submittedAmountMinor <= 0 ||
        userSnapshot.data()?.uid !== upload.residentUid || userSnapshot.data()?.role !== 'resident' ||
        userSnapshot.data()?.communityId !== upload.communityId || userSnapshot.data()?.approvalStatus !== 'approved' ||
        userSnapshot.data()?.isActive !== true ||
        (userSnapshot.data()?.status != null && userSnapshot.data().status !== 'active') ||
        communitySnapshot.data()?.isActive !== true) {
      return {created: false, reason: 'proof_not_eligible'};
    }
    if (eventSnapshot.exists) return {created: false, duplicate: true, notificationId: eventId};
    const notification = buildPaymentNotification('payment_proof_submitted', upload.paymentId, {
      communityId: upload.communityId,
      recipientUid: upload.residentUid,
      claimedAmountMinor: proof.submittedAmountMinor,
    }, now());
    tx.create(db.collection(NOTIFICATION_COLLECTION).doc(notification.id), notification.notification);
    tx.create(db.collection(EVENT_COLLECTION).doc(notification.id), notification.outbox);
    return {created: true, notificationId: notification.id};
  });
}

async function dispatchPaymentV2NotificationCore({db, messaging, event, logger = console}) {
  const eventId = event?.params?.eventId;
  if (typeof eventId !== 'string' || !eventId) return {sent: false, reason: 'invalid_event'};
  const eventRef = db.collection(EVENT_COLLECTION).doc(eventId);
  let claimed;
  try {
    claimed = await db.runTransaction(async tx => {
      const snapshot = await tx.get(eventRef);
      const value = snapshot.data();
      if (!snapshot.exists || value?.schemaVersion !== 1 || value.id !== eventId || value.status !== 'pending') return null;
      tx.update(eventRef, {status: 'sending', attemptCount: 1, lastAttemptAt: FieldValue.serverTimestamp()});
      return value;
    });
  } catch (error) {
    logger.warn?.('Billing V2 notification claim failed.', {code: error?.code || 'unknown'});
    return {sent: false, reason: 'claim_failed'};
  }
  if (!claimed) return {sent: false, duplicate: true};

  try {
    const result = await sendCanonicalNotification({
      db,
      messaging,
      recipientUid: claimed.recipientUid,
      communityId: claimed.communityId,
      role: 'resident',
      appId: 'resident',
      notificationId: eventId,
      title: claimed.title,
      message: claimed.message,
      notificationData: {eventType: claimed.eventType, route: claimed.route},
    });
    await eventRef.update({status: result.noDevices ? 'no_devices' : result.failureCount === 0 ? 'sent' : 'partial',
      successCount: result.successCount, failureCount: result.failureCount, updatedAt: FieldValue.serverTimestamp()});
    await db.collection(NOTIFICATION_COLLECTION).doc(eventId).update({
      deliveryStatus: result.noDevices ? 'no_devices' : result.failureCount === 0 ? 'sent' : 'partial',
      successCount: result.successCount, failureCount: result.failureCount, updatedAt: FieldValue.serverTimestamp(),
    });
    return {sent: true, ...result};
  } catch (error) {
    // The in-app notification was committed with the financial event. Push is best effort;
    // do not throw and cause delivery retries that could repeat an accepted FCM send.
    try {
      await eventRef.update({status: 'failed', failureCode: error?.code || 'delivery_failed', updatedAt: FieldValue.serverTimestamp()});
      await db.collection(NOTIFICATION_COLLECTION).doc(eventId).update({deliveryStatus: 'failed', updatedAt: FieldValue.serverTimestamp()});
    } catch (markerError) {
      logger.warn?.('Billing V2 notification delivery marker failed.', {code: markerError?.code || 'unknown'});
    }
    logger.warn?.('Billing V2 notification push failed.', {code: error?.code || 'unknown'});
    return {sent: false, reason: 'push_failed'};
  }
}

module.exports = {
  EVENT_COLLECTION,
  eventIdFor,
  buildPaymentNotification,
  createPaymentNotificationWrites,
  createProofSubmittedNotification,
  dispatchPaymentV2NotificationCore,
  parseFinalizedProofObject,
};
