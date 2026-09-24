const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');
const {ref: storageRef, uploadBytes, deleteObject, getMetadata} = require('firebase/storage');
const {verifyPaymentProofCore: verify, rejectPaymentProofCore: reject, recordManualPaymentCore: manual} = require('../src/payment_verification');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST && !!process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const projectId = 'demo-hominode-finance';
const bucketName = `${projectId}.appspot.com`;
let env, app, db, bucket;
const run = (name, fn) => test(name, {skip: !enabled}, fn);
const client = uid => env.authenticatedContext(uid, {firebase: {sign_in_provider: 'phone'}}).firestore();
const storage = uid => env.authenticatedContext(uid, {firebase: {sign_in_provider: 'phone'}}).storage(`gs://${bucketName}`);
const receiptPath = id => `payment_receipts/C/b/r/${id}.png`;
const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6V8AAAAASUVORK5CYII=', 'base64');
const metadata = id => ({contentType: 'image/png', customMetadata: {paymentId: id, billId: 'b', communityId: 'C', residentUid: 'r'}});
const payment = id => ({id, communityId: 'C', flatId: 'f', userId: 'r', billId: 'b', amount: 100, status: 'pending', method: 'external', receiptPath: receiptPath(id), createdAt: new Date(), updatedAt: new Date(), paymentDate: new Date()});
const args = id => ({db, bucket, auth: {uid: 'a'}, data: {paymentId: id}});
const bill = {communityId: 'C', adminId: 'a', residentId: 'r', flatId: 'f', amount: 100, status: 'pending', paidAt: null};
async function submit(id = 'p', upload = true) {
  if (upload) await assertSucceeds(uploadBytes(storageRef(storage('r'), receiptPath(id)), bytes, metadata(id)));
  await assertSucceeds(client('r').doc(`payments/${id}`).set(payment(id)));
}
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({projectId, firestore: {
    host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()), rules: fs.readFileSync(`${__dirname}/../../firestore.rules`, 'utf8'),
  }, storage: {host: '127.0.0.1', port: Number(process.env.FIREBASE_STORAGE_EMULATOR_HOST.split(':').pop()), rules: fs.readFileSync(`${__dirname}/../../storage.rules`, 'utf8')}});
  app = initializeApp({projectId, storageBucket: bucketName}, 'payment-integration'); db = getFirestore(app); bucket = getStorage(app).bucket();
});
test.after(async () => {if (env) await env.cleanup(); if (app) await deleteApp(app);});
test.beforeEach(async () => {
  if (!enabled) return;
  await env.clearFirestore();
  // clearStorage only lists root objects; our receipts live in nested paths.
  await bucket.deleteFiles({prefix: 'payment_receipts/'});
  const batch = db.batch();
  for (const [path, data] of Object.entries({
    'communities/C': {isActive: true}, 'communities/OTHER': {isActive: true},
    'admins/a': {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']},
    'admins/other': {uid: 'other', role: 'admin', isActive: true, authorizedCommunityIds: ['OTHER']},
    'admins/super': {uid: 'super', role: 'superAdmin', isActive: true, authorizedCommunityIds: ['C']},
    'users/r': {uid: 'r', role: 'resident', residentType: 'owner', isActive: true, approvalStatus: 'approved', communityId: 'C', flatId: 'f'},
    'users/r2': {uid: 'r2', role: 'resident', residentType: 'owner', isActive: true, approvalStatus: 'approved', communityId: 'C', flatId: 'f'},
    'users/foreign': {uid: 'foreign', role: 'resident', residentType: 'owner', isActive: true, approvalStatus: 'approved', communityId: 'OTHER', flatId: 'foreign'},
    'flats/f': {communityId: 'C', residentUserId: 'r'}, 'bills/b': bill,
  })) batch.set(db.doc(path), data);
  await batch.commit();
});
run('resident upload/submission -> Admin verification -> immutable linked financial history', async () => {
  await submit(); await verify(args('p'));
  const p = (await db.doc('payments/p').get()).data(); const b = (await db.doc('bills/b').get()).data();
  assert.equal(p.status, 'completed'); assert.equal(p.reviewedBy, 'a'); assert(p.receiptGeneration);
  assert.equal(b.status, 'paid'); assert.equal(b.paidAmount, 100); assert.equal(b.paymentId, 'p'); assert.equal(b.settledBy, 'a');
  assert(p.reviewedAt.isEqual(b.paidAt)); assert(p.reviewedAt.isEqual(p.updatedAt));
  const audits = await db.collection('auditLogs').get(); assert.equal(audits.size, 1); assert.equal(audits.docs[0].data().actorUid, 'a');
  for (const uid of ['r', 'a']) {
    await assertSucceeds(client(uid).doc('bills/b').get()); await assertSucceeds(client(uid).doc('payments/p').get());
    await assertSucceeds(getMetadata(storageRef(storage(uid), receiptPath('p'))));
    for (const path of ['bills/b', 'payments/p']) {
      await assertFails(client(uid).doc(path).delete()); await assertFails(client(uid).doc(path).update({amount: 1}));
    }
    await assertFails(deleteObject(storageRef(storage(uid), receiptPath('p'))));
  }
});
run('nonexistent receipt cannot settle', async () => {
  await submit('p', false); await assert.rejects(verify(args('p')), {code: 'failed-precondition'});
  assert.equal((await db.doc('bills/b').get()).data().status, 'pending');
});
run('arbitrary and cross-context paths fail at submission and backend verification', async () => {
  for (const receiptPath of ['https://example.com/receipt', 'payment_receipts/OTHER/b/r/p.png', 'payment_receipts/C/other/r/p.png',
    'payment_receipts/C/b/r2/p.png', 'payment_receipts/C/b/r/reused.png']) {
    await assertFails(client('r').doc('payments/p').set({...payment('p'), receiptPath}));
    await db.doc('payments/p').set({...payment('p'), receiptPath});
    await assert.rejects(verify(args('p')), {code: 'failed-precondition'});
  }
});
run('existing receipt with forged metadata cannot settle', async () => {
  await bucket.file(receiptPath('p')).save(bytes, {metadata: {contentType: 'image/png', metadata: {...metadata('p').customMetadata, residentUid: 'foreign'}}});
  await submit('p', false); await assert.rejects(verify(args('p')), {code: 'failed-precondition'});
});
run('Storage rejects foreign resident writes, overwrites and deletion of submitted evidence', async () => {
  await submit();
  await assertFails(uploadBytes(storageRef(storage('foreign'), receiptPath('other')), bytes, metadata('other')));
  await assertFails(uploadBytes(storageRef(storage('r'), receiptPath('p')), bytes, metadata('p')));
  await assertFails(deleteObject(storageRef(storage('r'), receiptPath('p'))));
  await assertSucceeds(getMetadata(storageRef(storage('r'), receiptPath('p'))));
});
run('cross-community bill/payment and unrelated bill owner cannot settle', async () => {
  await submit();
  for (const patch of [{communityId: 'OTHER'}, {residentId: 'r2'}, {flatId: 'other'}]) {
    await db.doc('bills/b').set({...bill, ...patch});
    await assert.rejects(verify(args('p')), {code: 'failed-precondition'});
  }
});
run('unauthorized Admin and Super Admin cannot verify, reject or manually settle', async () => {
  await submit();
  for (const uid of ['other', 'super', 'r']) {
    for (const [core, data] of [[verify, {paymentId: 'p'}], [reject, {paymentId: 'p', rejectionReason: 'No'}], [manual, {billId: 'b', paymentMethod: 'cash'}]]) {
      await assert.rejects(core({...args('p'), auth: {uid}, data}), {code: 'permission-denied'});
    }
  }
});
run('inactive community blocks financial review and manual settlement', async () => {
  await submit(); await db.doc('communities/C').update({isActive: false});
  for (const [core, data] of [[verify, {paymentId: 'p'}], [reject, {paymentId: 'p', rejectionReason: 'No'}], [manual, {billId: 'b', paymentMethod: 'manual'}]]) {
    await assert.rejects(core({...args('p'), data}), {code: 'failed-precondition'});
  }
});
run('client settlement, amounts, audit attribution and paid creation are denied', async () => {
  for (const uid of ['a', 'r', 'super']) {
    for (const patch of [{status: 'paid'}, {paidAmount: 100}, {amount: 1}, {chargeBreakdown: {discount: -99}},
      {paidAt: serverTimestamp()}, {settledBy: 'a'}, {paymentId: 'forged'}, {residentId: 'r2'}]) {
      await assertFails(client(uid).doc('bills/b').update(patch));
    }
    await assertFails(client(uid).doc('bills/new').set({...bill, status: 'paid'}));
    await assertFails(client(uid).doc('bills/new').set({...bill, paidAmount: 100}));
  }
  await assertSucceeds(client('a').doc('bills/new').set({...bill, billingKind: 'ad_hoc'}));
  await assertSucceeds(client('a').doc('bills/new').update({status: 'overdue', updatedAt: serverTimestamp()}));
});
run('duplicate/concurrent proofs cannot settle one bill twice', async () => {
  await submit('p'); await submit('p2');
  const results = await Promise.allSettled([verify(args('p')), verify(args('p')), verify(args('p2'))]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  for (const r of results.filter(r => r.status === 'rejected')) assert.equal(r.reason.code, 'failed-precondition');
  assert.equal((await db.collection('auditLogs').get()).size, 1);
  assert.equal((await db.collection('payments').where('status', '==', 'completed').get()).size, 1);
});
run('rejection is terminal and retains receipt; concurrent verify/reject has one winner', async () => {
  await submit(); await reject({...args('p'), data: {paymentId: 'p', rejectionReason: 'Wrong receipt'}});
  await assert.rejects(verify(args('p')), {code: 'failed-precondition'});
  await assertSucceeds(getMetadata(storageRef(storage('r'), receiptPath('p'))));
  await submit('p2');
  const results = await Promise.allSettled([verify(args('p2')), reject({...args('p2'), data: {paymentId: 'p2', rejectionReason: 'Wrong receipt'}})]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const p = (await db.doc('payments/p2').get()).data(); const b = (await db.doc('bills/b').get()).data();
  assert.equal(b.status, p.status === 'completed' ? 'paid' : 'pending');
});
run('manual payment creates an auditable record and races proof settlement safely', async () => {
  const result = await manual({...args('p'), data: {billId: 'b', paymentMethod: 'manual'}});
  const record = (await db.doc(`payments/${result.paymentId}`).get()).data();
  assert.equal(record.evidenceType, 'admin_attestation'); assert.equal(record.recordedBy, 'a'); assert.equal(record.receiptPath, undefined);
  assert.equal((await db.doc('bills/b').get()).data().paymentId, result.paymentId);
  await assertSucceeds(client('r').doc(`payments/${result.paymentId}`).get());
  await db.doc('bills/b').set(bill); // A fresh fixture state solely for the race.
  await submit('p');
  const results = await Promise.allSettled([verify(args('p')), manual({...args('p'), data: {billId: 'b', paymentMethod: 'cash'}})]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'failed-precondition');
});
run('Resident cannot alter verification or settlement fields; linked unpaid history also cannot be deleted', async () => {
  await submit();
  for (const uid of ['r', 'a']) {
    for (const patch of [{status: 'completed'}, {reviewedBy: 'a'}, {reviewedAt: serverTimestamp()}, {receiptPath: 'forged'}, {amount: 1}]) {
      await assertFails(client(uid).doc('payments/p').update(patch));
    }
    await assertFails(client(uid).doc('payments/p').delete()); await assertFails(client(uid).doc('bills/b').delete());
  }
  await assertFails(client('r2').doc('payments/other-owner').set({...payment('other-owner'), userId: 'r2', receiptPath: 'payment_receipts/C/b/r2/other-owner.png'}));
});
