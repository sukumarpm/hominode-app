const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {randomUUID} = require('node:crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');
const {createVisitorInvitationCore, getVisitorCredentialsCore} = require('../src/visitor_credentials');
const {verifyVisitorCredentialCore} = require('../src/visitor_verification');
const {resolveVisitorQrCore} = require('../src/visitor_gate');
const {checkoutVisitorsCore, listSecurityVisitorsCore} = require('../src/security_visitor_workflow');
const {dispatchVisitorDecisionCore} = require('../src/visitor_notifications');
const {notificationAudienceKey, visitorNotificationId} = require('../src/notifications');

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = 'demo-hominode-visitor-phase1';
const hmacKey = 'synthetic-phase1-credential-key-at-least-32-bytes';
const phone = '+639170000000';
const auth = (uid) => ({uid, token: {phone_number: phone, firebase: {sign_in_provider: 'phone'}}});
let env, app, db;
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({projectId, firestore: {
    host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
    rules: fs.readFileSync(`${__dirname}/../../firestore.rules`, 'utf8'),
  }});
  app = initializeApp({projectId}, `visitor-phase1-${randomUUID()}`);
  db = getFirestore(app);
});
test.after(async () => { if (app) await deleteApp(app); if (env) await env.cleanup(); });

async function fixture() {
  const suffix = randomUUID();
  const communityId = `C-${suffix}`, host = `host-${suffix}`, other = `other-${suffix}`;
  const security = `security-${suffix}`, admin = `admin-${suffix}`, flat = `flat-${suffix}`;
  const batch = db.batch();
  batch.set(db.collection('communities').doc(communityId), {isActive: true, timeZone: 'Asia/Manila'});
  batch.set(db.collection('users').doc(host), {uid: host, role: 'resident', phoneNumber: phone, communityId,
    approvalStatus: 'approved', isActive: true, status: 'active', residentType: 'owner', ownershipType: 'owner',
    identityVerified: true, identityVerificationStatus: 'verified', flatId: flat, name: 'Phase One Host'});
  batch.set(db.collection('users').doc(other), {uid: other, role: 'resident', phoneNumber: phone, communityId,
    approvalStatus: 'approved', isActive: true, residentType: 'owner', flatId: `${flat}-other`});
  batch.set(db.collection('flats').doc(flat), {communityId, status: 'occupied', residentUserId: host, flatLabel: 'N014'});
  batch.set(db.collection('flats').doc(`${flat}-other`), {communityId, status: 'occupied', residentUserId: other});
  batch.set(db.collection('securityStaff').doc(security), {uid: security, role: 'security', phoneNumber: phone, communityId, isActive: true});
  batch.set(db.collection('admins').doc(admin), {uid: admin, role: 'admin', phoneNumber: phone, authorizedCommunityIds: [communityId], isActive: true});
  await batch.commit();
  const client = (uid) => env.authenticatedContext(uid, auth(uid).token).firestore();
  const create = () => createVisitorInvitationCore({db, auth: auth(host), hmacKey,
    data: {visitorName: 'Phase One Guest', purpose: 'Visit', expectedArrival: Date.now()}});
  const retrieve = (visitorId, uid = host) => getVisitorCredentialsCore({db, auth: auth(uid), hmacKey, data: {visitorId}});
  return {communityId, host, other, security, admin, client, create, retrieve};
}

test('Resident create → private retrieval → existing Security QR entry → checkout', {skip: !enabled}, async () => {
  const f = await fixture();
  const issued = await f.create();
  const visitor = (await db.collection('visitors').doc(issued.visitorId).get()).data();
  assert.equal(visitor.status, 'expected'); assert.equal(visitor.isApproved, false);
  assert.equal(visitor.communityId, f.communityId); assert.equal(visitor.hostUserId, f.host);
  assert.equal('qrToken' in visitor, false); assert.equal('visitorPassCode' in visitor, false);
  const credentials = await f.retrieve(issued.visitorId);
  assert.equal(credentials.qrToken, issued.qrToken);
  assert.equal(credentials.visitorPassCode.replace(/[^A-Z0-9]/g, ''), issued.visitorPassCode.replace(/[^A-Z0-9]/g, ''));
  assert.equal(credentials.legacy, undefined);
  await assertFails(f.client(f.host).collection('visitorHostCredentials').doc(issued.visitorId).get());
  const operationId = randomUUID();
  const entered = await verifyVisitorCredentialCore({db, auth: auth(f.security), hmacKey,
    data: {qrToken: credentials.qrToken, operationId}});
  assert.equal(entered.status, 'inside');
  const checkedIn = (await db.collection('visitors').doc(issued.visitorId).get()).data();
  assert.equal(checkedIn.isApproved, false); assert.ok(checkedIn.actualArrival);
  const replay = await verifyVisitorCredentialCore({db, auth: auth(f.security), hmacKey,
    data: {qrToken: credentials.qrToken, operationId}});
  assert.equal(replay.idempotent, true);
  await checkoutVisitorsCore({db, auth: auth(f.security), data: {visitorIds: [issued.visitorId], operationId: randomUUID()}});
  const finished = (await db.collection('visitors').doc(issued.visitorId).get()).data();
  assert.equal(finished.status, 'completed'); assert.ok(finished.departure);
});

test('retrieved manual code enters through the unchanged Security verification contract', {skip: !enabled}, async () => {
  const f = await fixture(); const issued = await f.create(); const credentials = await f.retrieve(issued.visitorId);
  const result = await verifyVisitorCredentialCore({db, auth: auth(f.security), hmacKey,
    data: {manualCode: credentials.visitorPassCode.toLowerCase(), operationId: randomUUID()}});
  assert.equal(result.visitorId, issued.visitorId); assert.equal(result.verificationMethod, 'manual');
});

for (const method of ['qr', 'manual']) {
  test(`${method} entry preserves upcoming-list confidentiality, automatic check-in details and Resident arrival notification`, {skip: !enabled}, async () => {
    const f = await fixture(); const issued = await f.create(); const credentials = await f.retrieve(issued.visitorId);
    const upcoming = await listSecurityVisitorsCore({db, auth: auth(f.security), data: {category: 'expected'}});
    assert.equal(upcoming.visitors[0].visitorId, issued.visitorId);
    assert.equal(upcoming.visitors[0].adminApproved, false);
    for (const field of ['qrToken', 'manualCode', 'visitorPassCode', 'credentialHash']) {
      assert.equal(field in upcoming.visitors[0], false);
    }
    assert.equal(JSON.stringify(upcoming).includes(credentials.qrToken), false);
    assert.equal(JSON.stringify(upcoming).includes(credentials.visitorPassCode), false);
    await assertFails(f.client(f.security).collection('visitorHostCredentials').doc(issued.visitorId).get());
    await assertFails(f.client(f.security).collection('visitorGateCredentialIndex').get());

    const deviceToken = `synthetic-resident-device-${randomUUID()}`;
    await db.collection('notificationDevices').doc(randomUUID()).set({
      audienceKey: notificationAudienceKey({appId: 'resident', role: 'resident', communityId: f.communityId, uid: f.host}),
      uid: f.host, communityId: f.communityId, appId: 'resident', role: 'resident', active: true, token: deviceToken,
    });
    const ref = db.collection('visitors').doc(issued.visitorId);
    const before = await ref.get();
    const verified = await verifyVisitorCredentialCore({db, auth: auth(f.security), hmacKey,
      data: {...(method === 'qr' ? {qrToken: credentials.qrToken} : {manualCode: credentials.visitorPassCode}), operationId: randomUUID()}});
    const after = await ref.get();
    assert.equal(verified.status, 'inside');
    assert.equal(verified.visitorName, 'Phase One Guest');
    assert.equal(verified.flatLabel, 'N014');
    assert.equal(after.data().isApproved, false);
    assert.ok(after.data().actualArrival);
    const pushes = [];
    const messaging = {sendEachForMulticast: async (message) => {
      pushes.push(message);
      return {responses: message.tokens.map(() => ({success: true}))};
    }};
    const event = {id: randomUUID(), params: {visitorId: issued.visitorId}, data: {before, after}};
    assert.equal((await dispatchVisitorDecisionCore({db, messaging, event})).deliveryStatus, 'sent');
    assert.equal((await dispatchVisitorDecisionCore({db, messaging, event})).duplicate, true);
    assert.equal(pushes.length, 1);
    assert.deepEqual(pushes[0].tokens, [deviceToken]);
    assert.equal(pushes[0].notification.title, 'Visitor checked in');
    assert.equal(JSON.stringify(pushes[0]).includes(credentials.qrToken), false);
    assert.equal(JSON.stringify(pushes[0]).includes(credentials.visitorPassCode), false);
    const notificationId = visitorNotificationId(issued.visitorId, 'visitor_checked_in', f.host);
    const notification = await assertSucceeds(f.client(f.host).collection('notifications').doc(notificationId).get());
    assert.equal(notification.data().recipientId, f.host);
    assert.equal(notification.data().communityId, f.communityId);
    assert.equal(notification.data().eventType, 'visitor_checked_in');
    assert.equal(notification.data().data.verificationMethod, method);
    assert.equal(notification.data().isRead, false);
  });
}

test('Admin decisions remain optional and Admin can check out either kind of Security check-in', {skip: !enabled}, async () => {
  for (const approved of [false, true]) {
    const f = await fixture(); const issued = await f.create();
    const adminRef = f.client(f.admin).collection('visitors').doc(issued.visitorId);
    if (approved) await assertSucceeds(adminRef.update({
      status: 'approved', isApproved: true, approvedBy: f.admin,
      approvedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    const credentials = await f.retrieve(issued.visitorId);
    await verifyVisitorCredentialCore({db, auth: auth(f.security), hmacKey,
      data: {qrToken: credentials.qrToken, operationId: randomUUID()}});
    assert.equal((await db.collection('visitors').doc(issued.visitorId).get()).data().isApproved, approved);
    await assertSucceeds(adminRef.update({status: 'completed', departure: serverTimestamp(), checkedOutBy: f.admin, updatedAt: serverTimestamp()}));
    assert.equal((await adminRef.get()).data().status, 'completed');
  }
});

test('invalid credentials and document-ID downgrade attempts never grant entry', {skip: !enabled}, async () => {
  const f = await fixture(); const issued = await f.create();
  for (const input of [{qrToken: 'not-a-private-token'}, {manualCode: 'INVALIDCODE123'}, {legacyVisitorId: issued.visitorId}]) {
    await assert.rejects(verifyVisitorCredentialCore({db, auth: auth(f.security), hmacKey,
      data: {...input, operationId: randomUUID()}}));
  }
  await assert.rejects(resolveVisitorQrCore({db, auth: auth(f.security), hmacKey, data: {legacyVisitorId: issued.visitorId}}));
  assert.equal((await db.collection('visitors').doc(issued.visitorId).get()).data().status, 'expected');
});

test('credential retrieval rejects another Resident, Admin and cross-community Security', {skip: !enabled}, async () => {
  const f = await fixture(), foreign = await fixture(); const issued = await f.create();
  await assert.rejects(f.retrieve(issued.visitorId, f.other));
  await assert.rejects(f.retrieve(issued.visitorId, f.admin));
  await assert.rejects(foreign.retrieve(issued.visitorId));
  const credentials = await f.retrieve(issued.visitorId);
  await assert.rejects(verifyVisitorCredentialCore({db, auth: auth(foreign.security), hmacKey,
    data: {qrToken: credentials.qrToken, operationId: randomUUID()}}));
});

test('Admin can read all community lifecycle states while foreign and unscoped reads fail', {skip: !enabled}, async () => {
  const f = await fixture(), foreign = await fixture();
  const invited = await f.create(), other = await foreign.create();
  const cases = [
    {status: 'expected', isApproved: false}, {status: 'approved', isApproved: true},
    {status: 'inside', isApproved: false, actualArrival: Timestamp.now()},
    {status: 'rejected', isApproved: false}, {status: 'expected', gateAccessStatus: 'denied'},
    {status: 'completed', departure: Timestamp.now()},
  ];
  for (let i = 0; i < cases.length; i++) await db.collection('visitors').doc(`${invited.visitorId}-${i}`).set({communityId: f.communityId, hostUserId: f.host, ...cases[i]});
  const collection = f.client(f.admin).collection('visitors');
  const rows = await assertSucceeds(collection.where('communityId', '==', f.communityId).get());
  assert.equal(rows.size, cases.length + 1);
  await assertFails(collection.doc(other.visitorId).get());
  await assertFails(collection.get());
});
