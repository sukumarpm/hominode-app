const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {randomUUID} = require('node:crypto');
const {initializeApp, getApps} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {triggerSosCore, transitionSosCore} = require('../src/sos');
const {dispatchSosEventCore} = require('../src/sos_notifications');
const {deleteBuildingCore} = require('../src/building_deletion');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let env;
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({projectId: 'demo-hominode-sos', firestore: {
    host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
    rules: fs.readFileSync(`${__dirname}/../../firestore.rules`, 'utf8'),
  }});
});
test.after(async () => {if (env) await env.cleanup();});
const auth = (uid) => ({uid, token: {phone_number: '+14155558888', firebase: {sign_in_provider: 'phone'}}});
async function fixture() {
  const app = getApps().find((a) => a.name === 'sos') || initializeApp({projectId: 'demo-hominode-sos'}, 'sos');
  const db = getFirestore(app); const suffix = randomUUID(); const communityId = `c-${suffix}`;
  const residentUid = `r-${suffix}`; const staffUid = `s-${suffix}`; const adminUid = `a-${suffix}`;
  const buildingId = `b-${suffix}`; const unitId = `u-${suffix}`;
  const batch = db.batch();
  batch.set(db.collection('communities').doc(communityId), {isActive: true, name: 'Community'});
  batch.set(db.collection('users').doc(residentUid), {uid: residentUid, role: 'resident', communityId, isActive: true, approvalStatus: 'approved',
    status: 'active', residentType: 'owner', ownershipType: 'owner', buildingId, flatId: unitId, name: 'Test Resident'});
  batch.set(db.collection('securityStaff').doc(staffUid), {uid: staffUid, role: 'security', communityId, isActive: true, name: 'Security'});
  batch.set(db.collection('admins').doc(adminUid), {uid: adminUid, role: 'admin', isActive: true, authorizedCommunityIds: [communityId]});
  batch.set(db.collection('buildings').doc(buildingId), {communityId, name: 'Villa Cluster', structureType: 'villa_cluster', adminId: adminUid});
  batch.set(db.collection('flats').doc(unitId), {communityId, buildingId, status: 'occupied', residentUserId: residentUid, flatLabel: 'Villa-03', unitType: 'villa'});
  await batch.commit();
  const trigger = (requestId = randomUUID()) => triggerSosCore({db, auth: auth(residentUid), data: {requestId}});
  const transition = (alertId, action, uid = staffUid) => transitionSosCore({db, auth: auth(uid), data: {communityId, alertId, action}});
  const client = (uid) => env.authenticatedContext(uid, {phone_number: '+14155558888', firebase: {sign_in_provider: 'phone'}}).firestore();
  return {db, communityId, residentUid, staffUid, adminUid, buildingId, unitId, trigger, transition, client};
}
test('concurrent triggers create one real canonical alert, outbox, and audit', {skip: !enabled}, async () => {
  const f = await fixture(); const results = await Promise.all([f.trigger(), f.trigger(), f.trigger()]);
  assert.equal(new Set(results.map((r) => r.alertId)).size, 1);
  const alerts = await f.db.collection('sosAlerts').where('communityId', '==', f.communityId).get(); assert.equal(alerts.size, 1);
  assert.equal(alerts.docs[0].data().unitId, f.unitId); assert.equal(alerts.docs[0].data().unitLabel, 'Villa-03');
  assert.equal((await f.db.collection('sosNotificationEvents').where('communityId', '==', f.communityId).get()).size, 1);
  assert.equal((await f.db.collection('auditLogs').where('communityId', '==', f.communityId).get()).size, 1);
});
test('SOS live reads are owner/community scoped and all direct state writes denied', {skip: !enabled}, async () => {
  const f = await fixture(); const g = await fixture(); const {alertId} = await f.trigger();
  for (const uid of [f.residentUid, f.staffUid, f.adminUid]) await assertSucceeds(f.client(uid).collection('sosAlerts').doc(alertId).get());
  for (const uid of [g.residentUid, g.staffUid, g.adminUid, 'unknown']) await assertFails(f.client(uid).collection('sosAlerts').doc(alertId).get());
  await assertFails(env.unauthenticatedContext().firestore().collection('sosAlerts').doc(alertId).get());
  for (const uid of [f.residentUid, f.staffUid, f.adminUid]) {
    await assertFails(f.client(uid).collection('sosAlerts').doc(alertId).update({status: 'resolved'}));
    await assertFails(f.client(uid).collection('sosAlerts').doc('forged').set({residentUid: uid, communityId: f.communityId, status: 'triggered'}));
    await assertFails(f.client(uid).collection('sosActive').doc(f.residentUid).get());
  }
  await assertSucceeds(f.client(f.staffUid).collection('sosAlerts').where('communityId', '==', f.communityId)
    .where('status', 'in', ['triggered', 'acknowledged', 'responding']).orderBy('triggeredAt').get());
  await assertSucceeds(f.client(f.residentUid).collection('sosAlerts').where('communityId', '==', f.communityId)
    .where('residentUid', '==', f.residentUid).where('status', 'in', ['triggered', 'acknowledged', 'responding']).orderBy('triggeredAt').get());
  await assertFails(f.client(f.residentUid).collection('sosAlerts').where('communityId', '==', f.communityId).get());
});
test('real cancellation and acknowledgement race; terminal history stays', {skip: !enabled}, async () => {
  const f = await fixture(); const {alertId} = await f.trigger();
  const results = await Promise.allSettled([f.transition(alertId, 'acknowledge'), f.transition(alertId, 'cancel', f.residentUid)]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const ref = f.db.collection('sosAlerts').doc(alertId); const status = (await ref.get()).data().status;
  assert(['acknowledged', 'cancelled'].includes(status));
  if (status === 'acknowledged') {await f.transition(alertId, 'respond'); await f.transition(alertId, 'resolve', f.adminUid);}
  assert((await ref.get()).exists); assert.equal((await f.db.collection('sosActive').doc(f.residentUid).get()).exists, false);
  await assert.rejects(f.transition(alertId, 'respond'), {code: 'failed-precondition'});
});
test('two responders acknowledge atomically, then live stream observes responding and resolution', {skip: !enabled}, async () => {
  const f = await fixture(); const {alertId} = await f.trigger();
  await Promise.all([f.transition(alertId, 'acknowledge'), f.transition(alertId, 'acknowledge', f.adminUid)]);
  const ref = f.db.collection('sosAlerts').doc(alertId); assert.equal((await ref.get()).data().version, 2);
  async function seeStatus(status, action) {
    let stop; let timer;
    const event = new Promise((resolve, reject) => {timer = setTimeout(() => reject(Error('Live state timeout')), 15000);
      stop = ref.onSnapshot((s) => {if (s.data().status === status) resolve();}, reject);});
    try {await action(); await event;} finally {clearTimeout(timer); stop();}
  }
  await seeStatus('responding', () => f.transition(alertId, 'respond'));
  await seeStatus('resolved', () => f.transition(alertId, 'resolve', f.adminUid));
  assert.equal((await f.db.collection('sosAlerts').where('communityId', '==', f.communityId)
    .where('status', 'in', ['triggered', 'acknowledged', 'responding']).get()).size, 0);
});
test('active query orders oldest first and terminal alerts are excluded', {skip: !enabled}, async () => {
  const f = await fixture(); const batch = f.db.batch();
  for (const [id, time, status] of [['new', 200, 'triggered'], ['old', 100, 'responding'], ['done', 50, 'resolved']]) batch.set(f.db.collection('sosAlerts').doc(`${f.communityId}-${id}`),
    {communityId: f.communityId, residentUid: f.residentUid, status, triggeredAt: Timestamp.fromMillis(time)});
  await batch.commit();
  const snapshot = await f.client(f.staffUid).collection('sosAlerts').where('communityId', '==', f.communityId)
    .where('status', 'in', ['triggered', 'acknowledged', 'responding']).orderBy('triggeredAt').get();
  assert.deepEqual(snapshot.docs.map((d) => d.data().status), ['responding', 'triggered']);
});
test('notification transport failure leaves authoritative SOS; real delivery state retries safely', {skip: !enabled}, async () => {
  const f = await fixture(); const {alertId} = await f.trigger(); const eventId = `${alertId}_1`;
  await f.db.collection('notificationDevices').doc(`device-${f.staffUid}`).set({uid: f.staffUid, role: 'security', appId: 'security', communityId: f.communityId,
    audienceKey: `security|security|${f.communityId}|${f.staffUid}`, active: true, token: 'test-token'});
  await assert.rejects(dispatchSosEventCore({db: f.db, eventId, messaging: {sendEachForMulticast: async () => {throw Error('Offline');}}}));
  assert((await f.db.collection('sosAlerts').doc(alertId).get()).exists);
  let sent = 0;
  const messaging = {sendEachForMulticast: async (m) => {sent++; return {responses: m.tokens.map(() => ({success: true}))};}};
  await dispatchSosEventCore({db: f.db, eventId, messaging}); await dispatchSosEventCore({db: f.db, eventId, messaging});
  assert.equal(sent, 1);
});
test('active SOS blocks building deletion even after its resident moves out; resolved snapshot survives', {skip: !enabled}, async () => {
  const f = await fixture(); const {alertId} = await f.trigger();
  await f.db.collection('flats').doc(f.unitId).update({status: 'vacant', residentUserId: null});
  await f.db.collection('users').doc(f.residentUid).update({buildingId: null, flatId: null, occupancyStatus: 'moved_out', isActive: false});
  const remove = () => deleteBuildingCore({db: f.db, auth: auth(f.adminUid), data: {communityId: f.communityId, buildingId: f.buildingId}});
  await assert.rejects(remove(), {code: 'failed-precondition'});
  await f.transition(alertId, 'acknowledge'); await f.transition(alertId, 'resolve'); await remove();
  assert.equal((await f.db.collection('sosAlerts').doc(alertId).get()).data().unitLabel, 'Villa-03');
});
