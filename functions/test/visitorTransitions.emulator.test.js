const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const testPhoneNumber = '+639170000000';
let env;
const check = (name, fn) => test(name, {skip: !enabled}, fn);
const client = uid => env.authenticatedContext(uid, {phone_number: testPhoneNumber, firebase: {sign_in_provider: 'phone'}}).firestore();
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
      batch.set(db.doc(`users/r${c}`), {uid: `r${c}`, phoneNumber: testPhoneNumber, role: 'resident', residentType: 'owner', isActive: true,
        approvalStatus: 'approved', communityId: c, buildingId: `b${c}`, flatId: `f${c}`});
      batch.set(db.doc(`admins/a${c}`), {uid: `a${c}`, phoneNumber: testPhoneNumber, role: 'admin', isActive: true, authorizedCommunityIds: [c]});
      batch.set(db.doc(`securityStaff/s${c}`), {uid: `s${c}`, phoneNumber: testPhoneNumber, role: 'security', isActive: true, communityId: c});
    }
    batch.set(db.doc('visitors/visit'), initial);
    await batch.commit();
  });
});
check('Admin can approve a pending request without checking the visitor in', async () => {
    const uid = 'aa';
    await assertSucceeds(ref(uid).update(approve(uid)));
    const approved = (await ref(uid).get()).data();
    assert.equal(approved.status, 'approved');
    assert.equal(approved.isApproved, true);
    assert.equal(approved.approvedBy, uid);
    assert(approved.approvedAt.isEqual(approved.updatedAt));
    assert.equal(approved.actualArrival, null);
    assert.equal(approved.checkedInBy, undefined);
  });
check('Admin cannot check in directly or forge arrival fields', async () => {
  const uid = 'aa';
  await assertFails(ref(uid).update(enter(uid, true)));
  await ref(uid).update(approve(uid));
  await assertFails(ref(uid).update(enter(uid)));
  await assertFails(ref(uid).update({actualArrival: serverTimestamp(), updatedAt: serverTimestamp()}));
  await assertFails(ref(uid).update({checkedInBy: uid, updatedAt: serverTimestamp()}));
  const approved = (await ref(uid).get()).data();
  assert.equal(approved.status, 'approved');
  assert.equal(approved.actualArrival, null);
  assert.equal(approved.checkedInBy, undefined);
});
check('Admin checkout remains available for active visitors', async () => {
  const uid = 'aa';
  await seed({...initial, status: 'inside', isApproved: true, actualArrival: new Date()});
  await assertSucceeds(ref(uid).update(exit(uid)));
  const departed = (await ref(uid).get()).data();
  assert.equal(departed.status, 'completed');
  assert.equal(departed.checkedOutBy, uid);
  assert(departed.departure.isEqual(departed.updatedAt));
  });
check('Security cannot approve, reject or check in through direct Firestore writes', async () => {
    const uid = 'sa';
    await assertFails(ref(uid).update(approve(uid)));
    await assertFails(ref(uid).update(reject(uid)));
    await assertFails(ref(uid).update(enter(uid, true)));
  });
check('Security cannot read or directly check out visitors; use the secure callables', async () => {
    const uid = 'sa';
    await seed({...initial, status: 'inside', isApproved: true, actualArrival: new Date()});
    await assertFails(ref(uid).get());
    await assertFails(client(uid).collection('visitors')
      .where('communityId', '==', 'a').where('status', '==', 'inside').get());
    await assertFails(ref(uid).update(exit(uid)));
  });
check('Admin pending rejection remains terminal', async () => {
    const uid = 'aa';
    await assertSucceeds(ref(uid).update(reject(uid)));
    const rejected = (await ref(uid).get()).data();
    assert.equal(rejected.rejectedBy, uid);
    assert(rejected.rejectedAt.isEqual(rejected.updatedAt));
    await assertFails(ref(uid).update(approve(uid)));
    await assertFails(ref(uid).update(enter(uid, true)));
    await assertFails(ref(uid).update(reject(uid)));
  });
check('Security cannot check in without QR verified backend transition', async () => {
  await assertFails(ref('sa').update(enter('sa', true)));
  await assertFails(ref('sa').update(enter('sa')));
  await assertFails(ref('sa').get());
});
check('Security cannot directly check out or re-enter terminal visitors', async () => {
  await assertFails(ref('sa').update(enter('sa', true)));
  await seed({...initial, status: 'inside', isApproved: true, actualArrival: new Date()});
  await assertFails(ref('sa').update(enter('sa')));
  await assertFails(ref('sa').update(exit('sa')));
  await assertFails(ref('sa').update(exit('sa')));
  await assertFails(ref('sa').update(enter('sa')));
});
check('clients cannot forge gate-denial state on create or update', async () => {
  const forged = {...initial, gateAccessStatus: 'denied', gateEntryDeniedAt: serverTimestamp(),
    gateEntryDeniedBy: 'sa', gateEntryDenialReason: 'Forged'};
  await assertFails(ref('ra', 'forged-denial').set(forged));
  await seed(initial);
  await assertFails(ref('sa').update({gateAccessStatus: 'denied', gateEntryDeniedAt: serverTimestamp(),
    gateEntryDeniedBy: 'sa', gateEntryDenialReason: 'Forged', updatedAt: serverTimestamp()}));
  await assertFails(ref('aa').update({gateAccessStatus: 'denied', gateEntryDeniedAt: serverTimestamp(),
    gateEntryDeniedBy: 'aa', gateEntryDenialReason: 'Forged', updatedAt: serverTimestamp()}));
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
  await assertFails(ref('sa').update(enter('sa')));
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
check('all clients must use the protected invitation callable; direct and forged creates are denied', async () => {
  for (const uid of ['aa', 'sa', 'ra']) {
    for (const patch of [{status: 'inside'}, {isApproved: true}, {approvedBy: 'aa'}, {rejectedAt: new Date()},
      {actualArrival: new Date()}, {checkedInBy: 'sa'}, {checkedOutBy: 'sa'}, {departure: new Date()},
      {gateAccessStatus: 'denied'}, {gateEntryDeniedBy: 'sa'}, {verificationMethod: 'qr'}]) {
      await assertFails(ref(uid, 'new').set({...initial, ...patch}));
    }
    await assertFails(ref(uid, `new-${uid}`).set(initial));
  }
});
check('Admin cannot create a residentId-only invitation but can approve an existing Resident invitation', async () => {
  const {hostUserId, ...data} = initial;
  await assertFails(ref('aa', 'admin-created').set({...data, residentId: 'ra', status: 'pending'}));
  await assertSucceeds(ref('aa').update(approve('aa')));
  const approved = (await ref('aa').get()).data();
  assert.equal(approved.hostUserId, hostUserId);
  assert.equal(approved.status, 'approved');
  assert.equal(approved.approvedBy, 'aa');
  assert.equal(approved.actualArrival, null);
});
check('direct Security admission remains denied when Admin rejects', async () => {
  const results = await Promise.allSettled([ref('aa').update(reject('aa')), ref('sa').update(enter('sa', true))]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'permission-denied');
  const value = (await ref('aa').get()).data();
  assert.equal(value.status, 'rejected'); assert.equal(value.rejectedBy, 'aa'); assert.equal(value.actualArrival, null);
});
check('direct check-in is denied and concurrent checkout replays have one winner', async () => {
  await ref('aa').update(approve('aa'));
  await assertFails(ref('aa').update(enter('aa')));
  await assertFails(ref('sa').update(enter('sa')));
  await seed({...initial, status: 'inside', isApproved: true, actualArrival: new Date()});
  const results = await Promise.allSettled([
    ref('aa').update(exit('aa')),
    ref('sa').update(exit('sa')),
  ]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'permission-denied');
});
check('legacy approved/inside records work, terminal aliases never re-enter', async () => {
  await seed({...initial, isApproved: true});
  await assertFails(ref('sa').update(enter('sa')));
  for (const status of ['arrived', 'checked_in', 'inside']) {
    await seed({...initial, status, actualArrival: new Date()});
    // Legacy inside aliases remain manageable by Admin, but Security checkout
    // is callable-only under SEC-006 and must not use a direct Firestore write.
    await assertFails(ref('sa').update(exit('sa')));
    await assertSucceeds(ref('aa').update(exit('aa')));
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

check('visitor credential documents and indexes are server-only', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await db.doc('visitorHostCredentials/visit').set({hostUserId: 'ra', communityId: 'a', qrToken: 'secret'});
    await db.doc('visitorGateCredentialIndex/hash').set({visitorId: 'visit', communityId: 'a'});
  });
  for (const uid of ['ra', 'aa', 'sa']) {
    await assertFails(client(uid).doc('visitorHostCredentials/visit').get());
    await assertFails(client(uid).doc('visitorGateCredentialIndex/hash').get());
    await assertFails(client(uid).doc('visitorHostCredentials/visit').set({qrToken: 'forged'}));
    await assertFails(client(uid).doc('visitorGateCredentialIndex/hash').set({visitorId: 'forged'}));
  }
});
