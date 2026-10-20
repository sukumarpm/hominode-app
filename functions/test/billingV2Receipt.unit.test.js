const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {sosStore} = require('./helpers/sos_store');
const {receiptCases} = require('./helpers/billing_v2_receipt_cases');

async function environment() {
  const objects = new Map();
  const bucket = {name: 'test-bucket', file: path => ({getMetadata: async () => {
    if (!objects.has(path)) throw Object.assign(Error('Object not found'), {code: 404});
    return [objects.get(path)];
  }})};
  return {db: sosStore(), bucket, upload: async (path, metadata) => objects.set(path, {
    name: path, generation: '123', size: '10', contentType: 'image/jpeg', metadata,
  })};
}

receiptCases(test, environment);

test('resident Billing V2 receipt callable uses the App Check wrapper', () => {
  const source = readFileSync(require.resolve('../src/index'), 'utf8');
  assert.match(source, /exports\.getResidentBillingV2Receipt = appCheckedCallable\(\s*getResidentBillingV2ReceiptCore,/);
  assert.match(source, /getResidentBillingV2ReceiptCore,\s*\}\s*=\s*require\(["']\.\/billing_v2_receipt["']\)/);
});

// Exact historical writer shape captured in the previous deployment audit:
// settlement: createdBy/createdAt, transaction, allocations/credits, result;
// proof: completed + transactionId + reviewedBy/reviewedAt, without the later
// flexible amount-confirmation fields. No production records/files are used.
const {fixture} = require('./helpers/payment_v2_cases');
const {residentAuth} = require('./helpers/billing_v2_receipt_cases');
const {getResidentBillingV2ReceiptCore: getReceipt} = require('../src/billing_v2_receipt');
async function historicalFixture(reference = 'UPI-REF') {
  const f = await fixture(environment);
  const proof = await f.proof(1000, 0, 'proof', null, reference);
  const result = await proof.approve();
  const [settlementId, settlement] = (await f.rows('paymentSettlementsV2'))[0];
  for (const key of ['claimedAmountMinor', 'confirmedAmountMinor', 'amountMismatch',
    'amountConfirmationMode', 'reviewedBy', 'reviewedAt', 'referenceReviewRequired']) delete settlement[key];
  await f.ref(`paymentSettlementsV2/${settlementId}`).set(settlement);
  const completed = await f.get(`paymentProofsV2/${proof.paymentId}`);
  for (const key of ['confirmedAmountMinor', 'amountMismatch', 'amountConfirmationMode']) delete completed[key];
  await f.ref(`paymentProofsV2/${proof.paymentId}`).set(completed);
  return {...f, proof, result, settlementId};
}
const receipt = (f, auth = residentAuth, data = {transactionId:f.result.transactionId}) =>
  getReceipt({db:f.db, auth, data});

test('historical Admin-verified settlement returns a read-only compatible receipt', async () => {
  const f = await historicalFixture();
  const before = new Map(f.db.values);
  const value = await receipt(f);
  assert.equal(value.moneyReceivedMinor, 1000);
  assert.equal(value.allocatedAmountMinor, 1000);
  assert.equal(value.excessCreditMinor, 0);
  assert.equal(value.claimedAmountMinor, null);
  assert.equal(value.amountMismatch, null);
  assert.equal(value.paymentReference, 'UPI-REF');
  assert.equal(value.confirmation.status, 'verified');
  assert.equal(value.confirmation.verifiedAt, (await f.get(`paymentProofsV2/${f.proof.paymentId}`)).reviewedAt.toMillis());
  assert.deepEqual(f.db.values, before);
});

test('historical receipt preserves a missing reference without inventing one', async () => {
  const f = await historicalFixture(null);
  assert.equal((await receipt(f)).paymentReference, null);
});

test('historical Admin authorization is recorded evidence, not dependent on the Admin still being active', async () => {
  const f = await historicalFixture();
  await f.patch('admins/a', {isActive: false});
  assert.equal((await receipt(f)).confirmation.verifiedBy, 'Community Admin');
});

for (const [name, edit] of [
  ['pending proof', f => f.patch(`paymentProofsV2/${f.proof.paymentId}`, {status: 'pending'})],
  ['missing proof', f => f.ref(`paymentProofsV2/${f.proof.paymentId}`).delete()],
  ['unmatched Admin review', f => f.patch(`paymentProofsV2/${f.proof.paymentId}`, {reviewedBy: 'other-admin'})],
  ['missing review time', async f => {
    const proof = await f.get(`paymentProofsV2/${f.proof.paymentId}`);
    delete proof.reviewedAt;
    await f.ref(`paymentProofsV2/${f.proof.paymentId}`).set(proof);
  }],
  ['claim differing from settled money', f => f.patch(`paymentProofsV2/${f.proof.paymentId}`, {submittedAmountMinor: 999})],
  ['flexible proof without confirmation', f => f.patch(`paymentProofsV2/${f.proof.paymentId}`, {amountContractVersion: 2})],
  ['partial newer settlement metadata', f => f.patch(`paymentSettlementsV2/${f.settlementId}`, {confirmedAmountMinor: 1000})],
  ['null newer settlement metadata', f => f.patch(`paymentSettlementsV2/${f.settlementId}`, {confirmedAmountMinor: null})],
  ['partial newer proof metadata', f => f.patch(`paymentProofsV2/${f.proof.paymentId}`, {amountMismatch: false})],
  ['missing canonical transaction', f => f.ref(`paymentTransactions/${f.result.transactionId}`).delete()],
  ['missing original ledger allocation', async f => {
    for (const [id] of await f.rows('paymentAllocations')) await f.ref(`paymentAllocations/${id}`).delete();
  }],
  ['incomplete allocation snapshot', f => f.patch(`paymentSettlementsV2/${f.settlementId}`, {allocationEvents: []})],
]) {
  test(`receipt rejects ${name} rather than treating it as historical success`, async () => {
    const f = await historicalFixture();
    await edit(f);
    const before = new Map(f.db.values);
    await assert.rejects(receipt(f), {code: 'failed-precondition'});
    assert.deepEqual(f.db.values, before);
  });
}

for (const amountMinor of [0, -1, 1.5, '1000', Number.MAX_SAFE_INTEGER + 1, NaN]) {
  test(`receipt rejects malformed transaction amount ${String(amountMinor)}`, async () => {
    const f = await historicalFixture();
    const record = await f.get(`paymentSettlementsV2/${f.settlementId}`);
    record.transaction.amountMinor = amountMinor;
    await f.ref(`paymentSettlementsV2/${f.settlementId}`).set(record);
    await assert.rejects(receipt(f), {code: 'failed-precondition'});
  });
}

test('a mutable paid flag or submitted screenshot cannot replace an authoritative settlement', async () => {
  const f = await fixture(environment);
  const p = await f.proof();
  await f.patch(`bills/${f.bills[0]}`, {status:'paid', paidAmountMinor:1000, outstandingAmountMinor:0});
  await assert.rejects(getReceipt({db:f.db, auth:residentAuth, data:{transactionId:p.paymentId}}), {code:'not-found'});
  assert.equal((await f.rows('paymentSettlementsV2')).length,0);
});

test('cross-community, foreign resident, unauthenticated and forged request access is denied', async () => {
  const f = await historicalFixture();
  await f.ref('communities/D').set({isActive:true});
  await f.ref('users/foreign').set({uid:'foreign',role:'resident',isActive:true,
    approvalStatus:'approved',status:'active',communityId:'D'});
  await assert.rejects(receipt(f,{...residentAuth,uid:'foreign'}),{code:'permission-denied'});
  await f.patch('users/foreign',{communityId:'C'});
  await assert.rejects(receipt(f,{...residentAuth,uid:'foreign'}),{code:'permission-denied'});
  await assert.rejects(receipt(f,null),{code:'unauthenticated'});
  await assert.rejects(receipt(f,residentAuth,{transactionId:f.result.transactionId, confirmedAmountMinor:1000}),{code:'invalid-argument'});
  await assert.rejects(receipt(f,residentAuth,{transactionId:'../foreign'}),{code:'invalid-argument'});
});

test('current confirmation metadata must be complete, numeric and internally consistent', async () => {
  for (const patch of [{claimedAmountMinor:'1000'}, {confirmedAmountMinor:0}, {amountMismatch:true}]) {
    const f = await fixture(environment);
    const proof = await f.proof(1000,0,'current',2);
    const result = await proof.approve({confirmedAmountMinor:1000});
    const [id] = (await f.rows('paymentSettlementsV2'))[0];
    await f.patch(`paymentSettlementsV2/${id}`,patch);
    await assert.rejects(getReceipt({db:f.db,auth:residentAuth,data:{transactionId:result.transactionId}}),{code:'failed-precondition'});
  }
});

for (const paymentMethod of ['cash', 'bank_transfer', 'cheque']) {
  test(`existing ${paymentMethod} settlement receipt remains compatible without proof-only metadata`, async () => {
    const f = await fixture(environment);
    const result = await f.pay({paymentMethod});
    const value = await getReceipt({db:f.db,auth:residentAuth,data:{transactionId:result.transactionId}});
    assert.equal(value.method,paymentMethod);
    assert.equal(value.confirmedAmountMinor,1000);
    assert.equal(value.claimedAmountMinor,null);
    assert.equal(value.amountMismatch,null);
    assert.equal(value.confirmation.verifiedBy,'Recorded by Community Admin');
    assert.equal(value.paymentReference,null);
  });
}
