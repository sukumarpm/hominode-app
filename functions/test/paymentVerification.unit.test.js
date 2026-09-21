const test = require('node:test');
const assert = require('node:assert/strict');
const {sosStore} = require('./helpers/sos_store');
const {verifyPaymentProofCore: verify, rejectPaymentProofCore: reject, recordManualPaymentCore: manual} = require('../src/payment_verification');
function fixture() {
  const db = sosStore();
  for (const [path, data] of Object.entries({
    'admins/a': {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']},
    'communities/C': {isActive: true}, 'users/r': {uid: 'r', role: 'resident', communityId: 'C', flatId: 'f'},
    'flats/f': {communityId: 'C', residentUserId: 'r'},
    'bills/b': {communityId: 'C', flatId: 'f', residentId: 'r', amount: 100, status: 'pending'},
    'payments/p': {id: 'p', communityId: 'C', flatId: 'f', userId: 'r', billId: 'b', amount: 100,
      status: 'pending', method: 'external', receiptPath: 'payment_receipts/C/b/r/p.jpg'},
  })) db.values.set(path, data);
  const metadata = {name: 'payment_receipts/C/b/r/p.jpg', size: '10', generation: '123', contentType: 'image/jpeg',
    metadata: {paymentId: 'p', billId: 'b', communityId: 'C', residentUid: 'r'}};
  const bucket = {name: 'test-bucket', file: path => {assert.equal(path, metadata.name); return {getMetadata: async () => [metadata]};}};
  const args = {db, bucket, auth: {uid: 'a'}, data: {paymentId: 'p'}};
  const patch = (path, data) => db.values.set(path, {...db.values.get(path), ...data});
  return {db, args, metadata, patch};
}
test('valid proof settles atomically with server-authored attribution and immutable evidence identity', async () => {
  const {db, args} = fixture(); await verify(args);
  const payment = db.values.get('payments/p'); const bill = db.values.get('bills/b');
  assert.equal(payment.status, 'completed'); assert.equal(payment.reviewedBy, 'a'); assert.equal(payment.receiptGeneration, '123');
  assert(payment.reviewedAt.toMillis()); assert.equal(bill.paidAmount, 100); assert.equal(bill.settledBy, 'a');
  assert.equal(bill.paymentId, 'p'); assert(bill.paidAt.toMillis());
  assert.equal([...db.values.values()].filter(v => v.action === 'payment.verify').length, 1);
});
for (const [name, path, patch, code] of [
  ['unauthorized Admin', 'admins/a', {authorizedCommunityIds: ['OTHER']}, 'permission-denied'],
  ['inactive Admin', 'admins/a', {isActive: false}, 'permission-denied'],
  ['Super Admin', 'admins/a', {role: 'superAdmin'}, 'permission-denied'],
  ['inactive community', 'communities/C', {isActive: false}, 'failed-precondition'],
  ['foreign bill', 'bills/b', {communityId: 'OTHER'}, 'failed-precondition'],
  ['foreign payer', 'users/r', {communityId: 'OTHER'}, 'failed-precondition'],
  ['unrelated bill owner', 'bills/b', {residentId: 'other'}, 'failed-precondition'],
  ['conflicting owner aliases', 'bills/b', {userId: 'other'}, 'failed-precondition'],
  ['wrong amount', 'payments/p', {amount: 99}, 'failed-precondition'],
  ['rejected payment', 'payments/p', {status: 'failed'}, 'failed-precondition'],
  ['completed payment', 'payments/p', {status: 'completed'}, 'failed-precondition'],
  ['already paid bill', 'bills/b', {status: 'paid'}, 'failed-precondition'],
]) test(`${name} cannot settle`, async () => {
  const f = fixture(); f.patch(path, patch); await assert.rejects(verify(f.args), {code});
  assert.equal([...f.db.values.values()].filter(v => v.action).length, 0);
});
test('missing object never settles, but can be rejected without removing evidence', async () => {
  const f = fixture(); f.args.bucket = {file: () => ({getMetadata: async () => {throw Object.assign(Error('missing'), {code: 404});}})};
  await assert.rejects(verify(f.args), {code: 'failed-precondition'});
  await reject({...f.args, data: {paymentId: 'p', rejectionReason: 'Receipt missing'}});
  assert.equal(f.db.values.get('payments/p').status, 'failed');
  assert.equal(f.db.values.get('bills/b').status, 'pending');
  await assert.rejects(verify(f.args), {code: 'failed-precondition'});
});
test('arbitrary, cross-community and reused receipt paths are rejected before Storage access', async () => {
  for (const receiptPath of ['gs://evil/receipt', 'https://evil/receipt', 'payment_receipts/OTHER/b/r/p.jpg',
    'payment_receipts/C/other/r/p.jpg', 'payment_receipts/C/b/other/p.jpg', 'payment_receipts/C/b/r/other.jpg']) {
    const f = fixture(); f.patch('payments/p', {receiptPath});
    f.args.bucket = {file: () => assert.fail('invalid path must not be accessed')};
    await assert.rejects(verify(f.args), {code: 'failed-precondition'});
  }
});
test('object metadata, size and content type must match financial evidence', async () => {
  for (const patch of [{size: '0'}, {size: 'NaN'}, {size: '10485760'}, {contentType: 'text/plain'}, {generation: null},
    {metadata: {}}, {metadata: {paymentId: 'p', billId: 'other', communityId: 'C', residentUid: 'r'}}]) {
    const f = fixture(); Object.assign(f.metadata, patch);
    await assert.rejects(verify(f.args), {code: 'failed-precondition'});
  }
});
test('forged identity, amount and timestamp inputs are rejected', async () => {
  for (const patch of [{reviewedBy: 'other'}, {reviewedAt: 1}, {amount: 1}, {communityId: 'OTHER'}]) {
    const f = fixture(); await assert.rejects(verify({...f.args, data: {paymentId: 'p', ...patch}}), {code: 'invalid-argument'});
  }
});
test('manual payment is explicit Admin attestation, not fabricated receipt verification', async () => {
  const f = fixture(); const result = await manual({...f.args, data: {billId: 'b', paymentMethod: 'manual'}});
  const payment = f.db.values.get(`payments/${result.paymentId}`);
  assert.equal(payment.evidenceType, 'admin_attestation'); assert.equal(payment.recordedBy, 'a');
  assert.equal(payment.amount, 100); assert.equal(payment.receiptPath, undefined);
  assert.equal(f.db.values.get('bills/b').paymentId, result.paymentId);
  await assert.rejects(manual({...f.args, data: {billId: 'b', paymentMethod: 'manual'}}), {code: 'failed-precondition'});
  await assert.rejects(verify(f.args), {code: 'failed-precondition'});
});
test('manual and reject enforce active-community and Super Admin restrictions', async () => {
  for (const change of [['admins/a', {role: 'superAdmin'}, 'permission-denied'], ['communities/C', {isActive: false}, 'failed-precondition']]) {
    for (const [core, data] of [[manual, {billId: 'b', paymentMethod: 'cash'}], [reject, {paymentId: 'p', rejectionReason: 'Wrong receipt'}]]) {
      const f = fixture(); f.patch(change[0], change[1]); await assert.rejects(core({...f.args, data}), {code: change[2]});
    }
  }
});
test('online or forged manual payment payloads are not accepted', async () => {
  const f = fixture();
  for (const data of [{billId: 'b', paymentMethod: 'online'}, {billId: 'b', paymentMethod: 'manual', amount: 1}]) {
    await assert.rejects(manual({...f.args, data}), {code: 'invalid-argument'});
  }
});
test('overdue proof settlement remains supported', async () => {
  const f = fixture(); f.patch('bills/b', {status: 'overdue'}); assert.equal((await verify(f.args)).success, true);
});
