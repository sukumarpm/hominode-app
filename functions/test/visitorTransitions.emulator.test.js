const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let env;
const check = (name, fn) => test(name, {skip: !enabled}, fn);
const client = uid => env.authenticatedContext(uid, {firebase: {sign_in_provider: 'phone'}}).firestore();
const ref = (uid, id = 'visit') => client(uid).doc(`visitors/${id}`);
const initial = {communityId: 'a', hostUserId: 'ra', flatId: 'fa', buildingId: 'ba', status: 'expected',
  isApproved: false, approvedBy: null, approvedAt: null, actualArrival: null, departure: null};
const approve = uid => ({status: 'approved', isApproved: true, approvedBy: uid, approvedAt: serverTimestamp(), updatedAt: serverTimestamp()});
const reject = uid => ({status: 'rejected', isApproved: false, rejectedBy: uid, rejectedAt: serverTimestamp(), updatedAt: serverTimestamp()});
const enter = (uid, pending = false) => ({...(pending ? approve(uid) : {}), status: 'inside', isApproved: true,
  actualArrival: serverTimestamp(), checkedInBy: uid, updatedAt: serverTimestamp()});
const exit = uid => ({status: 'completed', departure: serverTimestamp(), checkedOutBy: uid, updatedAt: serverTimestamp()});
async function seed(data, id = 'visit') {
  await env.withSecurityRulesDisabled(ctx => ctx.firestore().doc(`visitors/${id}`).set(data));
}
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({projectId: 'demo-hominode-visitor-transitions', firestore: {
    host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
    rules: fs.readFileSync(`${__dirname}/../../firestore.rules`, 'utf8'),
  }});
});
test.after(async () => {if (env) await env.cleanup();});
test.beforeEach(async () => {
  if (!enabled) return;
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore(); const batch = db.batch();
    for (const c of ['a', 'b']) {
      batch.set(db.doc(`communities/${c}`), {isActive: true});
      batch.set(db.doc(`buildings/b${c}`), {communityId: c});
      batch.set(db.doc(`flats/f${c}`), {communityId: c, buildingId: `b${c}`, residentUserId: `r${c}`});
      batch.set(db.doc(`users/r${c}`), {uid: `r${c}`, role: 'resident', residentType: 'owner', isActive: true,
        approvalStatus: 'approved', communityId: c, buildingId: `b${c}`, flatId: `f${c}`});
      batch.set(db.doc(`admins/a${c}`), {uid: `a${c}`, role: 'admin', isActive: true, authorizedCommunityIds: [c]});
      batch.set(db.doc(`securityStaff/s${c}`), {uid: `s${c}`, role: 'security', isActive: true, communityId: c});
    }
    batch.set(db.doc('visitors/visit'), initial);
    await batch.commit();
  });
});
for (const uid of ['aa', 'sa']) {
  check(`${uid}: pending approval, arrival and checkout are actor-attributed and use server time`, async () => {
    await assertSucceeds(ref(uid).update(approve(uid)));
    const approved = (await ref(uid).get()).data();
    assert.equal(approved.approvedBy, uid);
    assert(approved.approvedAt.isEqual(approved.updatedAt));
    await assertSucceeds(ref(uid).update(enter(uid)));
    const arrived = (await ref(uid).get()).data();
    assert.equal(arrived.checkedInBy, uid);
    assert(arrived.actualArrival.isEqual(arrived.updatedAt));
    assert(arrived.approvedAt.isEqual(approved.approvedAt));
    await assertSucceeds(ref(uid).update(exit(uid)));
    const departed = (await ref(uid).get()).data();
    assert.equal(departed.status, 'completed');
    assert.equal(departed.checkedOutBy, uid);
    assert(departed.departure.isEqual(departed.updatedAt));
  });
  check(`${uid}: pending rejection is terminal`, async () => {
    await assertSucceeds(ref(uid).update(reject(uid)));
    const rejected = (await ref(uid).get()).data();
    assert.equal(rejected.rejectedBy, uid);
    assert(rejected.rejectedAt.isEqual(rejected.updatedAt));
    await assertFails(ref(uid).update(approve(uid)));
    await assertFails(ref(uid).update(enter(uid, true)));
    await assertFails(ref(uid).update(reject(uid)));
  });
}
check('Security QR admission atomically approves pending invitations', async () => {
  await assertSucceeds(ref('sa').update(enter('sa', true)));
  const value = (await ref('sa').get()).data();
  assert.equal(value.approvedBy, 'sa'); assert.equal(value.checkedInBy, 'sa');
  assert(value.approvedAt.isEqual(value.actualArrival));
});
check('replayed check-in, check-out and terminal re-entry are denied', async () => {
  await ref('sa').update(enter('sa', true));
  await assertFails(ref('sa').update(enter('sa')));
  await ref('sa').update(exit('sa'));
  await assertFails(ref('sa').update(exit('sa')));
  await assertFails(ref('sa').update(enter('sa')));
});
check('forged or missing actor IDs and client timestamps are denied for every transition', async () => {
  for (const [state, make, actorField, timeField] of [
    [initial, approve, 'approvedBy', 'approvedAt'],
    [initial, reject, 'rejectedBy', 'rejectedAt'],
    [{...initial, status: 'approved', isApproved: true}, enter, 'checkedInBy', 'actualArrival'],
    [{...initial, status: 'inside', isApproved: true, actualArrival: new Date()}, exit, 'checkedOutBy', 'departure'],
  ]) {
    await seed(state);
    await assertFails(ref('sa').update({...make('sa'), [actorField]: 'aa'}));
    await assertFails(ref('sa').update({...make('sa'), [timeField]: new Date(0)}));
    await assertFails(ref('sa').update({...make('sa'), updatedAt: new Date(0)}));
    const missing = make('sa'); delete missing[actorField];
    await assertFails(ref('sa').update(missing));
  }
});
check('approved check-in cannot rewrite original approval attribution', async () => {
  await ref('aa').update(approve('aa'));
  await assertFails(ref('sa').update(enter('sa', true)));
  await assertSucceeds(ref('sa').update(enter('sa')));
});
check('cross-community actors, residents and unauthenticated callers cannot transition', async () => {
  for (const uid of ['ab', 'sb', 'ra', 'rb']) await assertFails(ref(uid).update(approve(uid)));
  await assertFails(env.unauthenticatedContext().firestore().doc('visitors/visit').update(approve('aa')));
  await assertFails(ref('aa').update({...approve('aa'), communityId: 'b'}));
});
check('cross-community or conflicting host and unit references fail on create and transition', async () => {
  for (const patch of [{hostUserId: 'rb'}, {residentId: 'rb'}, {hostUserId: 'missing'},
    {buildingId: 'bb'}, {flatId: 'fb'}]) {
    for (const uid of ['aa', 'sa']) await assertFails(ref(uid, 'new').set({...initial, ...patch}));
    await seed({...initial, ...patch});
    await assertFails(ref('aa').update(approve('aa')));
    await assertFails(ref('sa').update(enter('sa', true)));
  }
});
check('all creators must start unapproved, without forged approval or gate fields', async () => {
  for (const uid of ['aa', 'sa', 'ra']) {
    for (const patch of [{status: 'inside'}, {isApproved: true}, {approvedBy: 'aa'}, {rejectedAt: new Date()},
      {actualArrival: new Date()}, {checkedInBy: 'sa'}, {checkedOutBy: 'sa'}, {departure: new Date()}]) {
      await assertFails(ref(uid, 'new').set({...initial, ...patch}));
    }
    await assertSucceeds(ref(uid, `new-${uid}`).set(initial));
  }
});
check('Admin residentId-only pending creation and subsequent approval remain supported', async () => {
  const {hostUserId, ...data} = initial;
  await assertSucceeds(ref('aa', 'admin-created').set({...data, residentId: 'ra', status: 'pending'}));
  await assertSucceeds(ref('aa', 'admin-created').update(approve('aa')));
});
check('simultaneous reject and gate admission produce exactly one valid final state', async () => {
  const results = await Promise.allSettled([ref('aa').update(reject('aa')), ref('sa').update(enter('sa', true))]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'permission-denied');
  const value = (await ref('aa').get()).data();
  if (value.status === 'inside') {
    assert.equal(value.checkedInBy, 'sa'); assert.equal(value.approvedBy, 'sa'); assert.equal(value.rejectedBy, undefined);
  } else {
    assert.equal(value.status, 'rejected'); assert.equal(value.rejectedBy, 'aa'); assert.equal(value.actualArrival, null);
  }
});
check('concurrent check-in and check-out replays each have one winner', async () => {
  await ref('aa').update(approve('aa'));
  for (const action of [enter, exit]) {
    const results = await Promise.allSettled([ref('aa').update(action('aa')), ref('sa').update(action('sa'))]);
    assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
    assert.equal(results.find(r => r.status === 'rejected').reason.code, 'permission-denied');
  }
});
check('legacy approved/inside records work, terminal aliases never re-enter', async () => {
  await seed({...initial, isApproved: true});
  await assertSucceeds(ref('sa').update(enter('sa')));
  for (const status of ['arrived', 'checked_in', 'inside']) {
    await seed({...initial, status, actualArrival: new Date()});
    await assertSucceeds(ref('sa').update(exit('sa')));
  }
  for (const status of ['rejected', 'cancelled', 'canceled', 'completed', 'departed', 'checked_out', 'checked-out', 'exited']) {
    await seed({...initial, status});
    await assertFails(ref('sa').update(enter('sa', true)));
  }
});

check('resident metadata edits cannot preserve a foreign host alias', async () => {
  await assertSucceeds(ref('ra').update({visitorName: 'Updated guest'}));
  await seed({...initial, residentId: 'rb'});
  await assertFails(ref('ra').update({visitorName: 'Invalid host'}));
});
