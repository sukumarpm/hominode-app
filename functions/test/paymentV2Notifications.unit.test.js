const test = require('node:test');
const assert = require('node:assert/strict');
const {sosStore} = require('./helpers/sos_store');
const {
  EVENT_COLLECTION,
  buildPaymentNotification,
  createProofSubmittedNotification,
  dispatchPaymentV2NotificationCore,
  eventIdFor,
} = require('../src/payment_v2_notifications');
const {notificationAudienceKey} = require('../src/notifications');

const now = Date.parse('2030-01-15T00:00:00Z');
const notificationEvents = db => [...db.values.entries()]
  .filter(([path]) => path.startsWith(`${EVENT_COLLECTION}/`)).map(([, value]) => value);

test('payment event content distinguishes submitted claims, confirmed settlement, rejection and offline recording', () => {
  const submitted = buildPaymentNotification('payment_proof_submitted', 'proof-1', {
    communityId: 'C', recipientUid: 'r', claimedAmountMinor: 1250,
  }, now);
  assert.match(submitted.notification.message, /claimed payment amount of ₹12\.50/);
  assert.match(submitted.notification.message, /not confirmation that funds were received/);
  assert.equal(submitted.notification.eventType, 'payment_proof_submitted');
  assert.deepEqual(submitted.notification.data, {route: 'billing', eventType: 'payment_proof_submitted'});

  const verified = buildPaymentNotification('payment_proof_verified', 'txn-1', {
    communityId: 'C', recipientUid: 'r', confirmedAmountMinor: 875, claimedAmountMinor: 1250,
  }, now);
  assert.match(verified.notification.message, /Admin confirmed receipt of ₹8\.75/);
  assert.doesNotMatch(verified.notification.message, /12\.50/);

  const rejected = buildPaymentNotification('payment_proof_rejected', 'proof-2', {
    communityId: 'C', recipientUid: 'r', rejectionReason: 'private internal note',
  }, now);
  assert.match(rejected.notification.message, /Open Billing/);
  assert.doesNotMatch(JSON.stringify(rejected), /private internal note/);

  const offline = buildPaymentNotification('offline_payment_settled', 'txn-2', {
    communityId: 'C', recipientUid: 'r', confirmedAmountMinor: 2500, method: 'bank_transfer',
  }, now);
  assert.match(offline.notification.message, /Admin recorded a Bank transfer payment of ₹25\.00/);
  assert.equal(offline.id, eventIdFor('offline_payment_settled', 'txn-2'));
});

test('uploaded pending proof creates one deterministic host-only in-app event after receipt finalization', async () => {
  const db = sosStore();
  await db.collection('users').doc('r').set({uid: 'r', role: 'resident', communityId: 'C', approvalStatus: 'approved', isActive: true});
  await db.collection('communities').doc('C').set({isActive: true});
  const paymentId = 'proof_v2_abc123';
  const receiptPath = `payment_receipts/C/bill-1/r/${paymentId}.jpg`;
  await db.collection('paymentProofsV2').doc(paymentId).set({
    schemaVersion: 2, id: paymentId, status: 'pending', residentId: 'r', communityId: 'C',
    billId: 'bill-1', submittedAmountMinor: 1250, evidenceType: 'receipt', receiptPath,
  });
  const object = {
    name: receiptPath, contentType: 'image/jpeg', generation: '123', size: '100',
    metadata: {paymentId, billId: 'bill-1', communityId: 'C', residentUid: 'r'},
  };
  const first = await createProofSubmittedNotification({db, object, now: () => now});
  const second = await createProofSubmittedNotification({db, object, now: () => now + 1});
  assert.equal(first.created, true);
  assert.deepEqual(second, {created: false, duplicate: true, notificationId: first.notificationId});
  assert.equal(notificationEvents(db).length, 1);
  assert.equal([...db.values.keys()].filter(path => path.startsWith('notifications/')).length, 1);
  const notification = db.values.get(`notifications/${first.notificationId}`);
  assert.equal(notification.recipientId, 'r');
  assert.equal(notification.communityId, 'C');
  assert.equal(notification.type, 'payment');
  assert.equal(notification.deliveryStatus, 'pending');
});

test('proof upload with mismatched host/community or non-pending proof creates no notification', async () => {
  const db = sosStore();
  await db.collection('users').doc('r').set({uid: 'r', role: 'resident', communityId: 'C', approvalStatus: 'approved', isActive: true});
  await db.collection('communities').doc('C').set({isActive: true});
  const paymentId = 'proof_v2_bad';
  const receiptPath = `payment_receipts/C/bill-1/r/${paymentId}.jpg`;
  await db.collection('paymentProofsV2').doc(paymentId).set({
    schemaVersion: 2, id: paymentId, status: 'failed', residentId: 'r', communityId: 'C',
    billId: 'bill-1', submittedAmountMinor: 1250, evidenceType: 'receipt', receiptPath,
  });
  const result = await createProofSubmittedNotification({db, object: {
    name: receiptPath, contentType: 'image/jpeg', generation: '123', size: '100',
    metadata: {paymentId, billId: 'bill-1', communityId: 'C', residentUid: 'r'},
  }, now: () => now});
  assert.deepEqual(result, {created: false, reason: 'proof_not_eligible'});
  assert.equal(notificationEvents(db).length, 0);
});

test('proof notification is suppressed when resident profile community or upload identity disagrees', async () => {
  const db = sosStore();
  await db.collection('users').doc('r').set({uid: 'r', role: 'resident', communityId: 'OTHER', approvalStatus: 'approved', isActive: true});
  await db.collection('communities').doc('C').set({isActive: true});
  const paymentId = 'proof_v2_scope';
  const receiptPath = `payment_receipts/C/bill-1/r/${paymentId}.jpg`;
  await db.collection('paymentProofsV2').doc(paymentId).set({
    schemaVersion: 2, id: paymentId, status: 'pending', residentId: 'r', communityId: 'C',
    billId: 'bill-1', submittedAmountMinor: 1250, evidenceType: 'receipt', receiptPath,
  });
  const baseObject = {name: receiptPath, contentType: 'image/jpeg', generation: '123', size: '100',
    metadata: {paymentId, billId: 'bill-1', communityId: 'C', residentUid: 'r'}};
  const wrongProfile = await createProofSubmittedNotification({db, object: baseObject, now: () => now});
  assert.deepEqual(wrongProfile, {created: false, reason: 'proof_not_eligible'});
  const wrongUploadIdentity = await createProofSubmittedNotification({db, object: {
    ...baseObject, metadata: {...baseObject.metadata, residentUid: 'other'},
  }, now: () => now});
  assert.deepEqual(wrongUploadIdentity, {created: false, reason: 'invalid_upload'});
  assert.equal(notificationEvents(db).length, 0);
  assert.equal([...db.values.keys()].filter(path => path.startsWith('notifications/')).length, 0);
});

async function seedPendingEvent(db, eventId, overrides = {}) {
  const built = buildPaymentNotification('payment_proof_verified', 'txn-1', {
    communityId: 'C', recipientUid: 'r', confirmedAmountMinor: 875,
  }, now);
  await db.collection('billingV2PaymentNotificationEvents').doc(eventId).set({
    ...built.outbox, id: eventId, status: 'pending', ...overrides,
  });
  await db.collection('notifications').doc(eventId).set(built.notification);
}

function seedRecipientAndDevice(db) {
  const audienceKey = notificationAudienceKey({appId: 'resident', role: 'resident', communityId: 'C', uid: 'r'});
  db.values.set('users/r', {uid: 'r', role: 'resident', communityId: 'C', approvalStatus: 'approved', isActive: true});
  db.values.set('notificationDevices/device-1', {
    uid: 'r', communityId: 'C', role: 'resident', appId: 'resident', audienceKey,
    active: true, token: 'synthetic-test-token',
  });
}

test('concurrent dispatch attempts send at most one FCM push for a deterministic event', async () => {
  const db = sosStore();
  seedRecipientAndDevice(db);
  const eventId = eventIdFor('payment_proof_verified', 'txn-1');
  await seedPendingEvent(db, eventId);
  let sends = 0;
  const messaging = {sendEachForMulticast: async request => {
    sends++;
    await new Promise(resolve => setTimeout(resolve, 5));
    assert.deepEqual(request.data, {
      type: 'notification', entityId: eventId, communityId: 'C',
      eventType: 'payment_proof_verified', route: 'billing',
    });
    return {successCount: 1, failureCount: 0, responses: [{success: true}]};
  }};
  const event = {params: {eventId}};
  const results = await Promise.all([
    dispatchPaymentV2NotificationCore({db, messaging, event}),
    dispatchPaymentV2NotificationCore({db, messaging, event}),
  ]);
  assert.equal(sends, 1);
  assert.equal(results.filter(result => result.sent).length, 1);
  assert.equal(db.values.get(`${EVENT_COLLECTION}/${eventId}`).status, 'sent');
  assert.equal(db.values.get(`notifications/${eventId}`).deliveryStatus, 'sent');
});

test('FCM failure is best-effort, keeps the in-app notification and does not retry push on duplicate event', async () => {
  const db = sosStore();
  seedRecipientAndDevice(db);
  const eventId = eventIdFor('payment_proof_verified', 'txn-fail');
  await seedPendingEvent(db, eventId);
  let sends = 0;
  const messaging = {sendEachForMulticast: async () => {sends++; throw Object.assign(new Error('synthetic'), {code: 'unavailable'});}};
  const event = {params: {eventId}};
  const first = await dispatchPaymentV2NotificationCore({db, messaging, event, logger: {warn() {}}});
  const retry = await dispatchPaymentV2NotificationCore({db, messaging, event, logger: {warn() {}}});
  assert.deepEqual(first, {sent: false, reason: 'push_failed'});
  assert.equal(retry.duplicate, true);
  assert.equal(sends, 1);
  assert.equal(db.values.get(`${EVENT_COLLECTION}/${eventId}`).status, 'failed');
  assert.equal(db.values.get(`notifications/${eventId}`).deliveryStatus, 'failed');
  assert.equal(db.values.has(`notifications/${eventId}`), true);
});

test('event identifiers are based on lifecycle type and source transition, not message wording', () => {
  assert.equal(eventIdFor('payment_proof_verified', 'txn-1'), eventIdFor('payment_proof_verified', 'txn-1'));
  assert.notEqual(eventIdFor('payment_proof_verified', 'txn-1'), eventIdFor('offline_payment_settled', 'txn-1'));
  assert.notEqual(eventIdFor('payment_proof_verified', 'txn-1'), eventIdFor('payment_proof_verified', 'txn-2'));
});
