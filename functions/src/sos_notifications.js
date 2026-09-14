const crypto = require('node:crypto');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { notificationAudienceKey, requireCanonicalRecipient, NOTIFICATION_CHANNEL_ID } = require('./notifications');

const digest = (v) => crypto.createHash('sha256').update(v).digest('hex');
const staleCodes = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);
async function recipientsForSos(db, event) {
  if (event.status !== 'triggered' && event.status !== 'cancelled') return [{ uid: event.residentUid, role: 'resident' }];
  const [security, admins] = await Promise.all([
    db.collection('securityStaff').where('communityId', '==', event.communityId).get(),
    db.collection('admins').where('authorizedCommunityIds', 'array-contains', event.communityId).get(),
  ]);
  return [...security.docs.filter((d) => d.data().uid === d.id && d.data().role === 'security' && d.data().isActive === true).map((d) => ({ uid: d.id, role: 'security' })),
  ...admins.docs.filter((d) => d.data().uid === d.id && d.data().role === 'admin' && d.data().isActive === true).map((d) => ({ uid: d.id, role: 'admin' }))];
}
async function deliverSosRecipient({ db, messaging, eventId, event, alert, recipient, now = Date.now() }) {
  const notificationId = digest(`${eventId}|${recipient.role}|${recipient.uid}`);
  const ref = db.collection('notifications').doc(notificationId);
  const deliveryRef = db.collection('sosDeliveries').doc(notificationId);
  const leaseId = crypto.randomUUID();
  const title = event.status === 'triggered' ? `SOS Alert — ${alert.buildingName || 'Community'}${alert.unitLabel ? `, ${alert.unitLabel}` : ''}` : `Emergency ${event.status}`;
  const message = event.status === 'triggered' ? 'Emergency assistance requested by a resident.' :
    event.status === 'cancelled' ? 'The resident cancelled this emergency before acknowledgement.' : `Your emergency assistance status is ${event.status}.`;
  const lease = await db.runTransaction(async (tx) => {
    const previous = (await tx.get(deliveryRef)).data();
    if (previous?.complete === true) return null;
    if (previous?.leaseUntil?.toMillis() > now) throw new Error('Emergency delivery already in progress; retry later.');
    const notification = await tx.get(ref);
    if (!notification.exists) tx.create(ref, {
      communityId: event.communityId, recipientId: recipient.uid,
      audience: recipient.role, role: recipient.role, appId: recipient.role, type: 'sos', priority: 'urgent',
      title, message, sourceEntityId: event.alertId, isRead: false, createdAt: FieldValue.serverTimestamp(), deliveryStatus: 'pending'
    });
    tx.set(deliveryRef, {
      leaseId, leaseUntil: Timestamp.fromMillis(now + 120000), complete: false,
      attempts: (previous?.attempts || 0) + 1
    }, { merge: true });
    return new Set(previous?.sentTokenHashes || []);
  });
  if (!lease) return;
  const finish = async (patch) => db.runTransaction(async (tx) => {
    const current = (await tx.get(deliveryRef)).data();
    if (current?.leaseId !== leaseId) throw new Error('Emergency delivery lease changed.');
    tx.update(deliveryRef, { ...patch, leaseUntil: Timestamp.fromMillis(0), updatedAt: FieldValue.serverTimestamp() });
    tx.update(ref, { deliveryStatus: patch.complete ? 'processed' : 'retry_pending' });
  });
  try {
    try {
      await requireCanonicalRecipient(db, { recipientUid: recipient.uid, communityId: event.communityId, role: recipient.role, appId: recipient.role });
    } catch (error) {
      if (['failed-precondition', 'permission-denied'].includes(error.code)) { await finish({ complete: true, skipped: 'recipient_unavailable' }); return; }
      throw error;
    }
    const devices = await db.collection('notificationDevices').where('audienceKey', '==', notificationAudienceKey({
      appId: recipient.role, role: recipient.role, communityId: event.communityId, uid: recipient.uid
    })).get();
    const byToken = new Map();
    for (const doc of devices.docs) {
      const value = doc.data();
      if (value.active !== true || value.uid !== recipient.uid || value.communityId !== event.communityId ||
        value.role !== recipient.role || value.appId !== recipient.role || typeof value.token !== 'string' || !value.token) continue;
      if (lease.has(digest(value.token))) continue;
      const refs = byToken.get(value.token) || []; refs.push(doc.ref); byToken.set(value.token, refs);
    }
    let retry = false;
    const tokens = [...byToken.keys()];
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const result = await messaging.sendEachForMulticast({
        tokens: chunk, notification: { title, body: message },
        data: { type: 'notification', entityId: notificationId, communityId: event.communityId },
        android: { priority: 'high', ttl: 300000, notification: { channelId: NOTIFICATION_CHANNEL_ID, tag: notificationId } },
        apns: { headers: { 'apns-priority': '10', 'apns-collapse-id': notificationId }, payload: { aps: { sound: 'default' } } }
      });
      const completed = [];
      for (let j = 0; j < result.responses.length; j++) {
        const response = result.responses[j];
        if (response.success || staleCodes.has(response.error?.code)) completed.push(digest(chunk[j]));
        else retry = true;
        if (staleCodes.has(response.error?.code)) {
          // Recheck the token before removal: registration may have rotated it.
          for (const deviceRef of byToken.get(chunk[j])) await db.runTransaction(async (tx) => {
            if ((await tx.get(deviceRef)).data()?.token === chunk[j]) tx.delete(deviceRef);
          });
        }
      }
      if (completed.length) await deliveryRef.update({ sentTokenHashes: FieldValue.arrayUnion(...completed) });
    }
    await finish({ complete: !retry, noDevices: tokens.length === 0 });
    if (retry) throw new Error('Emergency notification delivery requires retry.');
  } catch (error) {
    await finish({ complete: false });
    throw error;
  }
}
async function dispatchSosEventCore({ db, messaging, eventId }) {
  const eventRef = db.collection('sosNotificationEvents').doc(eventId);
  const event = (await eventRef.get()).data();
  if (!event || event.deliveryStatus === 'processed') return;
  const alert = (await db.collection('sosAlerts').doc(event.alertId).get()).data();
  if (!alert || alert.communityId !== event.communityId || alert.residentUid !== event.residentUid) throw new Error('Invalid emergency event context.');
  if (
    !Number.isInteger(event.version) ||
    !Number.isInteger(alert.version)
  ) {
    throw new Error('Invalid emergency notification version.');
  }

  if (event.version < alert.version) {
    await eventRef.update({
      deliveryStatus: 'processed',
      superseded: true,
      processedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  if (event.version > alert.version) {
    throw new Error('Emergency notification version is ahead of alert state.');
  }

  const recipients = await recipientsForSos(db, event);
  let next = 0;
  let failed = false;
  await Promise.all(Array.from({ length: Math.min(8, recipients.length) }, async () => {
    while (next < recipients.length) {
      const recipient = recipients[next++];
      try { await deliverSosRecipient({ db, messaging, eventId, event, alert, recipient }); }
      catch (_) { failed = true; }
    }
  }));
  if (failed) {
    console.error('SOS notification delivery will retry.', { eventId });
    throw new Error('SOS notification delivery incomplete.');
  }
  await eventRef.update({ deliveryStatus: 'processed', processedAt: FieldValue.serverTimestamp(), recipientCount: recipients.length });
}
module.exports = { recipientsForSos, deliverSosRecipient, dispatchSosEventCore };
