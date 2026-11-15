const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let env;
const phone = '+14155558888';
const actor = (uid) => env.authenticatedContext(uid, {
  phone_number: phone, firebase: {sign_in_provider: 'phone'},
}).firestore();
const recipient = (role, extra = {}) => ({
  communityId: 'C1', recipientId: `${role}-a`, audience: role, role, appId: role,
  type: 'sos', title: 'SOS Alert — Nova, N014', message: 'Emergency assistance requested by a resident.',
  sourceEntityId: 'SOS-1', isRead: false, createdAt: new Date(), deliveryStatus: 'sent', ...extra,
});

test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({projectId: 'demo-hominode-notification-read', firestore: {
    host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
    rules: fs.readFileSync(process.env.NOTIFICATION_RULES_FILE || path.join(__dirname, '../../firestore.rules'), 'utf8'),
  }});
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = db.batch();
    for (const id of ['C1', 'C2']) batch.set(db.collection('communities').doc(id), {isActive: true});
    for (const [id, communityId] of [['security-a', 'C1'], ['security-b', 'C1'], ['security-c', 'C2']]) {
      batch.set(db.collection('securityStaff').doc(id), {uid: id, communityId, phoneNumber: phone, role: 'security', isActive: true});
    }
    batch.set(db.collection('admins').doc('admin-a'), {uid: 'admin-a', phoneNumber: phone, role: 'admin', isActive: true, authorizedCommunityIds: ['C1']});
    batch.set(db.collection('users').doc('resident-a'), {uid: 'resident-a', phoneNumber: phone, role: 'resident', isActive: true, approvalStatus: 'approved', communityId: 'C1', residentType: 'owner', ownershipType: 'owner'});
    for (const role of ['security', 'admin', 'resident']) {
      batch.set(db.collection('notifications').doc(role), recipient(role));
    }
    batch.set(db.collection('notifications').doc('security-general'), recipient('security', {type: 'general'}));
    const legacy = [
      {...recipient('security'), recipientId: phone},
      {...recipient('security'), audience: 'all_security'},
      {...recipient('security'), role: null},
      {...recipient('security'), appId: null},
    ];
    legacy.forEach((data, i) => batch.set(db.collection('notifications').doc(`legacy-${i}`), data));
    await batch.commit();
  });
});
test.after(async () => { if (env) await env.cleanup(); });

test('Security can read and persist its own SOS read state', {skip: !enabled}, async () => {
  const ref = actor('security-a').collection('notifications').doc('security');
  await assertSucceeds(ref.get());
  await assertSucceeds(ref.update({isRead: true, readAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  const data = (await assertSucceeds(ref.get())).data();
  assert.equal(data.isRead, true);
  assert.ok(data.readAt);
  assert.equal(data.sourceEntityId, 'SOS-1');
  assert.equal(data.title, 'SOS Alert — Nova, N014');
  assert.equal(data.message, 'Emergency assistance requested by a resident.');
  // Reopening the inbox reads the same persisted state and canonical SOS target.
  const reopened = await assertSucceeds(actor('security-a').collection('notifications')
      .where('communityId', '==', 'C1').where('recipientId', '==', 'security-a')
      .where('audience', '==', 'security').where('role', '==', 'security').where('appId', '==', 'security').get());
  assert.equal(reopened.docs.find((doc) => doc.id === 'security').data().isRead, true);
});

test('Security read updates work for existing general notifications and isRead-only clients', {skip: !enabled}, async () => {
  const ref = actor('security-a').collection('notifications').doc('security-general');
  await assertSucceeds(ref.update({isRead: true}));
  assert.equal((await ref.get()).data().isRead, true);
});

test('noncanonical legacy recipient and audience fields never broaden access', {skip: !enabled}, async () => {
  for (let i = 0; i < 4; i++) {
    const ref = actor('security-a').collection('notifications').doc(`legacy-${i}`);
    await assertFails(ref.get());
    await assertFails(ref.update({isRead: true}));
  }
});

test('signed-out and non-phone sessions cannot mark Security notifications', {skip: !enabled}, async () => {
  for (const context of [env.unauthenticatedContext(), env.authenticatedContext('security-a', {
    phone_number: phone, firebase: {sign_in_provider: 'password'},
  })]) {
    const ref = context.firestore().collection('notifications').doc('security');
    await assertFails(ref.get());
    await assertFails(ref.update({isRead: true}));
  }
});

test('a different recipient or community cannot read or mark the SOS notification', {skip: !enabled}, async () => {
  for (const uid of ['security-b', 'security-c', 'admin-a', 'resident-a']) {
    const ref = actor(uid).collection('notifications').doc('security');
    await assertFails(ref.get());
    await assertFails(ref.update({isRead: true}));
  }
});

test('read permission never permits content, routing or delivery modifications', {skip: !enabled}, async () => {
  const ref = actor('security-a').collection('notifications').doc('security');
  for (const patch of [{message: 'forged'}, {title: 'forged'}, {recipientId: 'security-b'}, {communityId: 'C2'}, {audience: 'admin'}, {role: 'admin'}, {appId: 'admin'}, {sourceEntityId: 'SOS-2'}, {deliveryStatus: 'failed'}, {isRead: 'true'}]) {
    await assertFails(ref.update({isRead: true, ...patch}));
  }
});

test('Admin and Resident notification read conventions remain compatible', {skip: !enabled}, async () => {
  for (const role of ['admin', 'resident']) {
    const ref = actor(`${role}-a`).collection('notifications').doc(role);
    await assertSucceeds(ref.update({isRead: true}));
    await assertSucceeds(ref.update({isRead: true, readAt: serverTimestamp(), updatedAt: serverTimestamp()}));
    assert.equal((await ref.get()).data().isRead, true);
  }
});
