const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {Timestamp} = require('firebase-admin/firestore');
const {sosStore} = require('./helpers/sos_store');
const {triggerSosCore, transitionSosCore, getSosContextCore, locationSnapshot} = require('../src/sos');
const {dispatchSosEventCore, recipientsForSos} = require('../src/sos_notifications');
const {notificationAudienceKey} = require('../src/notifications');
const auth = (uid) => ({uid, token: {phone_number: '+14155558888', firebase: {sign_in_provider: 'phone'}}});
function fixture(type = 'apartment_building') {
  const db = sosStore();
  db.values.set('communities/c', {isActive: true, name: 'Community'});
  db.values.set('users/resident', {uid: 'resident', role: 'resident', communityId: 'c', name: 'Resident Test', status: 'active',
    approvalStatus: 'approved', isActive: true, residentType: 'owner', ownershipType: 'owner', buildingId: 'building', flatId: 'canonical', occupancyStatus: 'current'});
  db.values.set('buildings/building', {communityId: 'c', name: 'Homes', structureType: type});
  db.values.set('flats/canonical', {communityId: 'c', buildingId: 'building', flatLabel: 'Villa-Custom', status: 'occupied', residentUserId: 'resident', unitType: type === 'apartment_building' ? 'apartment' : 'villa'});
  for (const uid of ['security', 'security2']) db.values.set(`securityStaff/${uid}`, {uid, role: 'security', communityId: 'c', isActive: true, name: uid});
  db.values.set('admins/admin', {uid: 'admin', role: 'admin', authorizedCommunityIds: ['c'], isActive: true});
  let seq = 0;
  const call = (core, uid, data) => core({db, auth: auth(uid), data});
  return {db, call, trigger: (data = {}) => call(triggerSosCore, 'resident', {requestId: `request_identifier_${++seq}`, ...data}),
    transition: (alertId, action, uid = 'security', extra = {}) => call(transitionSosCore, uid, {communityId: 'c', alertId, action, ...extra})};
}
for (const type of ['apartment_building', 'villa_cluster', 'row_house_cluster', 'townhouse_cluster', 'mixed', 'other']) {
  test(`${type}: trusted context, no GPS, durable event and atomic audit`, async () => {
    const f = fixture(type); const result = await f.trigger(); const alert = f.db.values.get(`sosAlerts/${result.alertId}`);
    assert.equal(alert.unitId, 'canonical'); assert.equal(alert.unitLabel, 'Villa-Custom'); assert.equal(alert.buildingName, 'Homes');
    assert.equal(alert.structureType, type); assert.equal(alert.residentUid, 'resident'); assert.equal(alert.locationAvailable, false);
    assert(alert.triggeredAt instanceof Timestamp); assert(f.db.values.has(`sosNotificationEvents/${result.alertId}_1`));
    assert([...f.db.values.keys()].some((k) => k.startsWith('auditLogs/')));
  });
}
test('unauthenticated, impersonated and cross-community requests rejected', async () => {
  const f = fixture(); await assert.rejects(triggerSosCore({db: f.db, auth: null, data: {requestId: 'request_identifier'}}), {code: 'unauthenticated'});
  for (const spoof of [{residentUid: 'other'}, {communityId: 'other'}, {unitId: 'other'}, {role: 'admin'}]) await assert.rejects(f.trigger(spoof), {code: 'invalid-argument'});
});
for (const patch of [{approvalStatus: 'pending'}, {isActive: false}, {residentType: 'tenant', ownershipType: 'tenant', identityVerified: false}, {role: 'security'}]) {
  test(`existing resident safeguards remain enforced: ${JSON.stringify(patch)}`, async () => {
    const f = fixture(); Object.assign(f.db.values.get('users/resident'), patch); await assert.rejects(f.trigger(), {code: 'permission-denied'});
  });
}
test('approved resident with no allocation has explicit fallback; conflicting allocation is rejected', async () => {
  const f = fixture(); Object.assign(f.db.values.get('users/resident'), {flatId: null, buildingId: null});
  const r = await f.trigger(); assert.equal(f.db.values.get(`sosAlerts/${r.alertId}`).unitContextAvailable, false);
  const g = fixture(); g.db.values.get('flats/canonical').residentUserId = 'other'; await assert.rejects(g.trigger(), {code: 'failed-precondition'});
});
test('valid one-time GPS is recorded; malformed, stale and future locations rejected', async () => {
  const f = fixture(); const r = await f.trigger({location: {latitude: 14, longitude: 121, accuracy: 10, capturedAt: Date.now()}});
  assert.equal(f.db.values.get(`sosAlerts/${r.alertId}`).locationAvailable, true);
  for (const patch of [{latitude: 100}, {longitude: -190}, {accuracy: -1}, {capturedAt: 0}, {capturedAt: Date.now() + 120000}]) {
    assert.throws(() => locationSnapshot({latitude: 14, longitude: 121, accuracy: 5, capturedAt: Date.now(), ...patch}), {code: 'invalid-argument'});
  }
});
test('rapid requests create one active SOS, one event, and one trigger audit', async () => {
  const f = fixture(); const results = await Promise.all(Array.from({length: 12}, () => f.trigger()));
  assert.equal(new Set(results.map((r) => r.alertId)).size, 1);
  assert.equal([...f.db.values.keys()].filter((k) => k.startsWith('sosAlerts/')).length, 1);
  assert.equal([...f.db.values.keys()].filter((k) => k.startsWith('sosNotificationEvents/')).length, 1);
});
test('legal lifecycle keeps timestamps/actors/history; request retry after terminal does not create new alert', async () => {
  const f = fixture(); const requestId = 'stable_request_identifier'; const {alertId} = await f.trigger({requestId});
  await f.transition(alertId, 'acknowledge'); await f.transition(alertId, 'respond', 'admin'); await f.transition(alertId, 'resolve', 'security2', {resolutionNote: 'Assistance provided'});
  const alert = f.db.values.get(`sosAlerts/${alertId}`);
  assert.equal(alert.status, 'resolved'); assert.equal(alert.acknowledgedByUid, 'security'); assert.equal(alert.respondingByUid, 'admin');
  assert.equal(alert.resolvedByUid, 'security2'); assert.equal(alert.resolutionNote, 'Assistance provided'); assert(!f.db.values.has('sosActive/resident'));
  assert.equal((await f.trigger({requestId})).alertId, alertId);
  assert.notEqual((await f.trigger()).alertId, alertId);
});
test('illegal transitions and unauthorized actors rejected', async () => {
  const f = fixture(); const {alertId} = await f.trigger();
  await assert.rejects(f.transition(alertId, 'respond'), {code: 'failed-precondition'});
  await assert.rejects(f.transition(alertId, 'acknowledge', 'resident'), {code: 'permission-denied'});
  f.db.values.get('securityStaff/security2').communityId = 'other';
  await assert.rejects(f.transition(alertId, 'acknowledge', 'security2'), {code: 'permission-denied'});
  await f.transition(alertId, 'cancel', 'resident');
  await assert.rejects(f.transition(alertId, 'acknowledge'), {code: 'failed-precondition'});
});
test('acknowledgement versus cancellation race commits one legal path', async () => {
  const f = fixture(); const {alertId} = await f.trigger();
  const results = await Promise.allSettled([f.transition(alertId, 'acknowledge'), f.transition(alertId, 'cancel', 'resident')]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert(['acknowledged', 'cancelled'].includes(f.db.values.get(`sosAlerts/${alertId}`).status));
});
test('simultaneous acknowledgements preserve original actor and emit one event', async () => {
  const f = fixture(); const {alertId} = await f.trigger();
  await Promise.all([f.transition(alertId, 'acknowledge'), f.transition(alertId, 'acknowledge', 'security2')]);
  const alert = f.db.values.get(`sosAlerts/${alertId}`); assert.equal(alert.version, 2); assert.equal(alert.acknowledgedByUid, 'security');
  assert.equal([...f.db.values.keys()].filter((k) => k.startsWith('sosNotificationEvents/')).length, 2);
});
test('respond and resolve race cannot resurrect a resolved emergency', async () => {
  const f = fixture(); const {alertId} = await f.trigger(); await f.transition(alertId, 'acknowledge');
  await Promise.allSettled([f.transition(alertId, 'respond'), f.transition(alertId, 'resolve', 'admin')]);
  assert.equal(f.db.values.get(`sosAlerts/${alertId}`).status, 'resolved');
  await assert.rejects(f.transition(alertId, 'respond'), {code: 'failed-precondition'});
  await assert.rejects(f.transition(alertId, 'cancel', 'resident'), {code: 'failed-precondition'});
});
test('contacts are absent unless trusted profile/community fields exist; client cannot override', async () => {
  const f = fixture(); const context = () => f.call(getSosContextCore, 'resident', {});
  assert.equal((await context()).securityPhone, null);
  f.db.values.get('communities/c').securityPhone = '+14155558888';
  f.db.values.get('users/resident').emergencyContactNumber = '+14155559999';
  assert.equal((await context()).emergencyPhone, '+14155559999'); assert.equal((await context()).securityPhone, '+14155558888');
});
function device(f, uid, role, token, suffix = '') {
  f.db.values.set(`notificationDevices/${uid}${suffix}`, {uid, communityId: 'c', role, appId: role, token, active: true,
    audienceKey: notificationAudienceKey({uid, communityId: 'c', role, appId: role})});
}
test('notifications target only active community staff/admins and deduplicate multiple devices/tokens', async () => {
  const f = fixture(); const {alertId} = await f.trigger(); const eventId = `${alertId}_1`;
  f.db.values.set('securityStaff/foreign', {uid: 'foreign', role: 'security', communityId: 'other', isActive: true});
  f.db.values.get('securityStaff/security2').isActive = false;
  device(f, 'security', 'security', 'one'); device(f, 'security', 'security', 'one', '-duplicate'); device(f, 'security', 'security', 'two', '-second');
  device(f, 'admin', 'admin', 'admin-token'); device(f, 'security2', 'security', 'disabled'); device(f, 'foreign', 'security', 'foreign');
  const sent = [];
  const messaging = {sendEachForMulticast: async (message) => {sent.push(message); return {responses: message.tokens.map(() => ({success: true}))};}};
  await dispatchSosEventCore({db: f.db, messaging, eventId}); await dispatchSosEventCore({db: f.db, messaging, eventId});
  assert.deepEqual(sent.flatMap((m) => m.tokens).sort(), ['admin-token', 'one', 'two']);
  assert(sent.every((m) => m.android.priority === 'high' && m.data.communityId === 'c'));
  assert(!JSON.stringify(sent).includes('Resident Test'));
});
test('transient notification failure does not lose SOS; retry skips successful tokens and clears stale tokens', async () => {
  const f = fixture(); const {alertId} = await f.trigger(); const eventId = `${alertId}_1`;
  device(f, 'security', 'security', 'good'); device(f, 'security', 'security', 'stale', '-stale'); device(f, 'security', 'security', 'retry', '-retry');
  const sent = []; let fail = true;
  const messaging = {sendEachForMulticast: async (message) => {sent.push(...message.tokens); return {responses: message.tokens.map((token) =>
    token === 'stale' ? {success: false, error: {code: 'messaging/registration-token-not-registered'}} : token === 'retry' && fail ? {success: false, error: {code: 'messaging/unavailable'}} : {success: true})};}};
  await assert.rejects(dispatchSosEventCore({db: f.db, messaging, eventId}));
  assert(f.db.values.has(`sosAlerts/${alertId}`)); assert(!f.db.values.has('notificationDevices/security-stale'));
  fail = false; await dispatchSosEventCore({db: f.db, messaging, eventId});
  assert.equal(sent.filter((t) => t === 'good').length, 1); assert.equal(sent.filter((t) => t === 'retry').length, 2);
});
test('status notifications target only the owning resident', async () => {
  const f = fixture(); const {alertId} = await f.trigger(); await f.transition(alertId, 'acknowledge');
  assert.deepEqual(await recipientsForSos(f.db, f.db.values.get(`sosNotificationEvents/${alertId}_2`)), [{uid: 'resident', role: 'resident'}]);
});
test('callable registration retains App Check and event retries', () => {
  const source = fs.readFileSync(require.resolve('../src/index'), 'utf8');
  for (const name of ['triggerSos', 'transitionSos', 'getSosContext']) assert.match(source, new RegExp(`exports.${name} = appCheckedCallable`));
  assert.match(source, /retry: true/);
});
