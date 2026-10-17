const assert = require('node:assert/strict');
const {fixture, now} = require('./payment_v2_cases');
const {getResidentBillingV2ReceiptCore: getReceipt} = require('../../src/billing_v2_receipt');
const {rejectPaymentProofV2Core: reject} = require('../../src/payment_v2');
const {createMonthlyBillingBatchV2Core: issue} = require('../../src/billing_batch');

const residentAuth = {uid: 'r', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const receipt = (f, transactionId, auth = residentAuth) => getReceipt({db: f.db, auth, data: {transactionId}});

function receiptCases(test, environment) {
  test('partial verified UPI receipt reconciles Admin-confirmed amount and linked bill allocation', async () => {
    const f = await fixture(environment);
    const proof = await f.proof(400, 0, 'partial', 2, 'PARTIAL-REF');
    const result = await proof.approve({confirmedAmountMinor: 300});
    const value = await receipt(f, result.transactionId);
    assert.equal(value.confirmedAmountMinor, 300);
    assert.equal(value.claimedAmountMinor, 400);
    assert.equal(value.amountMismatch, true);
    assert.deepEqual(value.allocations.map(({billId, amountMinor}) => ({billId, amountMinor})),
      [{billId: f.bills[0], amountMinor: 300}]);
    assert.equal(value.reconciliation.allocatedAmountMinor + value.reconciliation.excessCreditMinor,
      value.reconciliation.confirmedAmountMinor);
    assert.equal(value.paymentReference, 'PARTIAL-REF');
    assert.equal(value.confirmation.verifiedBy, 'Community Admin');
    assert.equal(Object.hasOwn(value, 'receiptPath'), false);
    assert.equal(Object.hasOwn(value, 'qrToken'), false);
    assert.equal(Object.hasOwn(value, 'credentialHash'), false);
  });

  test('exact settlement receipt retains stable identity', async () => {
    const f = await fixture(environment);
    const proof = await f.proof(1000, 0, 'exact', 2, 'EXACT-REF');
    const result = await proof.approve({confirmedAmountMinor: 1000});
    const first = await receipt(f, result.transactionId), second = await receipt(f, result.transactionId);
    assert.equal(first.receiptId, `HOMINODE-V2-${result.transactionId}`);
    assert.deepEqual(second, first);
    assert.equal(first.confirmedAmountMinor, 1000);
    assert.equal(first.excessCreditMinor, 0);
    assert.equal(first.snapshot, 'original_settlement');
  });

  test('receipt keeps a later application of generated credit separate from money received', async () => {
    const f = await fixture(environment);
    const proof = await f.proof(1500, 0, 'credit-issued', 2, 'CREDIT-REF');
    const result = await proof.approve({confirmedAmountMinor: 1500});
    await issue({db: f.db, auth: {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}},
      now, data: {communityId: 'C', scope: 'community', billingPeriod: '2030-02', idempotencyKey: 'issue-2030-02',
        chargeLines: [{lineId: 'base', code: 'maintenance', amountMinor: 400}], dueDate: '2030-02-15'}});
    const credits = await f.rows('residentCreditEntries');
    assert(credits.some(([, event]) => event.eventType === 'applied' && event.amountMinor === 400));
    const value = await receipt(f, result.transactionId);
    assert.equal(value.moneyReceivedMinor, 1500);
    assert.equal(value.allocatedAmountMinor, 1000);
    assert.equal(value.excessCreditMinor, 500);
    assert.equal(value.accountingBasis.existingCreditApplicationsExcluded, true);
  });

  test('excess receipt separates allocated payment from excess credit generated', async () => {
    const f = await fixture(environment);
    const proof = await f.proof(1200, 0, 'excess', 2, 'EXCESS-REF');
    const result = await proof.approve({confirmedAmountMinor: 1300});
    const value = await receipt(f, result.transactionId);
    assert.equal(value.confirmedAmountMinor, 1300);
    assert.equal(value.claimedAmountMinor, 1200);
    assert.equal(value.allocatedAmountMinor, 1000);
    assert.equal(value.excessCreditMinor, 300);
    assert.equal(value.reconciliation.allocatedAmountMinor + value.reconciliation.excessCreditMinor, 1300);
  });

  test('receipt reports all payment allocations before credit generated beyond account liabilities', async () => {
    const f = await fixture(environment, [1000, 800]);
    const proof = await f.proof(2000, 0, 'multi-bill', 2, 'MULTI-BILL-REF');
    const result = await proof.approve({confirmedAmountMinor: 2000});
    const value = await receipt(f, result.transactionId);
    assert.deepEqual(value.allocations.map(({billId, amountMinor}) => ({billId, amountMinor})), [
      {billId: f.bills[0], amountMinor: 1000}, {billId: f.bills[1], amountMinor: 800},
    ]);
    assert.equal(value.excessCreditMinor, 200);
    assert.equal(value.moneyReceivedMinor, 2000);
  });

  test('separate partial payment transactions receive separate receipts', async () => {
    const f = await fixture(environment);
    const first = await f.proof(400, 0, 'part-one', 2, 'PART-ONE').then(p => p.approve({confirmedAmountMinor: 400}));
    const second = await f.proof(600, 0, 'part-two', 2, 'PART-TWO').then(p => p.approve({confirmedAmountMinor: 600}));
    const a = await receipt(f, first.transactionId), b = await receipt(f, second.transactionId);
    assert.notEqual(a.receiptId, b.receiptId);
    assert.equal(a.confirmedAmountMinor, 400);
    assert.equal(b.confirmedAmountMinor, 600);
  });

  test('pending, rejected and nonexistent proofs do not produce receipts', async () => {
    const f = await fixture(environment);
    const pending = await f.prepareOnly();
    await assert.rejects(receipt(f, 'missing-transaction'), {code: 'not-found'});
    await assert.rejects(receipt(f, pending.paymentId), {code: 'not-found'});
    await reject({db: f.db, auth: {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}},
      data: {paymentId: pending.paymentId, rejectionReason: 'Evidence not valid'}});
    await assert.rejects(receipt(f, pending.paymentId), {code: 'not-found'});
  });

  test('resident cannot retrieve another account receipt and phone verification is required', async () => {
    const f = await fixture(environment);
    const proof = await f.proof(1000, 0, 'private', 2, 'PRIVATE-REF');
    const result = await proof.approve({confirmedAmountMinor: 1000});
    await f.ref('users/other').set({uid: 'other', role: 'resident', isActive: true, approvalStatus: 'approved',
      status: 'active', communityId: 'C'});
    await assert.rejects(receipt(f, result.transactionId, {...residentAuth, uid: 'other'}),
      {code: 'permission-denied'});
    await assert.rejects(receipt(f, result.transactionId, {uid: 'r', token: {phone_number: '+639171234567'}}),
      {code: 'unauthenticated'});
  });

  test('post-revision receipt preserves original allocation and reports later reversal separately', async () => {
    const f = await fixture(environment);
    const proof = await f.proof(1000, 0, 'revision', 2, 'REVISION-REF');
    const result = await proof.approve({confirmedAmountMinor: 1000});
    await f.revision(800);
    const value = await receipt(f, result.transactionId);
    assert.equal(value.allocations[0].amountMinor, 1000);
    assert.equal(value.confirmedAmountMinor, 1000);
    assert.equal(value.laterAdjustments.reversedAllocationMinor, 200);
  });
}

module.exports = {receiptCases, residentAuth, now};
