const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {createMonthlyBillingBatchV2Core: issue, monthlyBillIdV2} = require('../../src/billing_batch');
const {reviseMonthlyBillingBatchV2Core: revise} = require('../../src/billing_revision');
const {preparePaymentProofV2Core: prepare, verifyPaymentProofV2Core: verify,
  rejectPaymentProofV2Core: reject, recordOfflinePaymentV2Core: offline, MAX_ALLOCATIONS} = require('../../src/payment_v2');
const ledger = require('../../src/billing_v2_ledger');
const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const now = () => Date.parse('2030-01-15T00:00:00Z');
const lines = amountMinor => [{lineId: 'base', code: 'maintenance', amountMinor}];
const collections = ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries', 'residentFinancialAccounts', 'paymentSettlementsV2', 'auditLogs'];
async function fixture(environment, amounts = [1000], timeZone = 'Asia/Manila') {
  const {db, bucket, upload} = await environment();
  const ref = path => {const parts = path.split('/'); return db.collection(parts.slice(0, -1).join('/')).doc(parts.at(-1));};
  const get = async path => (await ref(path).get()).data();
  const patch = (path, data) => ref(path).update(data);
  await ref('admins/a').set({uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  await ref('communities/C').set({isActive: true, timeZone});
  await ref('buildings/b').set({communityId: 'C'});
  await ref('flats/f').set({communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: 'r'});
  await ref('users/r').set({uid: 'r', role: 'resident', isActive: true, approvalStatus: 'approved', status: 'active', communityId: 'C', buildingId: 'b', flatId: 'f'});
  const bills = [], batches = [];
  for (let i = 0; i < amounts.length; i++) {
    const period = `${2030 + Math.floor(i / 12)}-${String(i % 12 + 1).padStart(2, '0')}`;
    const issued = await issue({db, auth, now, data: {communityId: 'C', scope: 'community', billingPeriod: period,
      idempotencyKey: `issue-${period}`, chargeLines: lines(amounts[i]), dueDate: '2030-02-15'}});
    bills.push(monthlyBillIdV2('C', 'f', period)); batches.push(issued.batchId);
  }
  const rows = async name => (await db.collection(name).get()).docs.filter(doc => doc.ref.path === `${name}/${doc.id}`)
    .map(doc => [doc.id, doc.data()]).sort(([a], [b]) => a.localeCompare(b));
  const financialState = () => Promise.all(collections.map(rows));
  const pay = (extra = {}, options = {}) => offline({db, auth, now, data: {communityId: 'C', residentId: 'r', amountMinor: 1000,
    paymentMethod: 'cash', idempotencyKey: 'offline', ...extra}, ...options});
  const proof = async (amountMinor = 1000, n = 0, key = 'proof') => {
    const bill = await get(`bills/${bills[n]}`);
    const data = {billId: bills[n], submittedAmountMinor: amountMinor, submittedBillRevisionId: bill.currentRevisionId,
      idempotencyKey: key, receiptExtension: 'jpg', paymentReference: 'UPI-REF'};
    const result = await prepare({db, auth: {uid: 'r'}, now, data});
    await upload(result.receiptPath, {paymentId: result.paymentId, billId: bills[n], communityId: 'C', residentUid: 'r'});
    return {...result, data, approve: (options = {}) => verify({db, bucket, auth, now, data: {paymentId: result.paymentId}, ...options})};
  };
  const revision = (amountMinor, n = 0) => revise({db, auth, now, data: {communityId: 'C', billingBatchId: batches[n],
    expectedRevisionId: 'revision_1', idempotencyKey: 'edit', chargeLines: lines(amountMinor)}});
  return {db, bucket, upload, ref, get, patch, bills, batches, rows, financialState, pay, proof, revision};
}
function paymentCases(test, environment) {
  test('Direct UPI exact payment captures submitted context and atomically settles with private receipt evidence', async () => {
    const f = await fixture(environment), p = await f.proof();
    const submitted = await f.get(`paymentProofsV2/${p.paymentId}`), previous = await f.get(`bills/${f.bills[0]}/revisions/revision_1`);
    for (const [key, value] of Object.entries({billId: f.bills[0], communityId: 'C', residentId: 'r', userId: 'r',
      submittedAmountMinor: 1000, submittedBillRevisionId: 'revision_1', provider: 'direct_upi', method: 'upi',
      verificationMode: 'manual', evidenceType: 'receipt', status: 'pending'})) assert.equal(submitted[key], value);
    assert(submitted.submittedAt instanceof Timestamp); assert((await f.financialState()).every(rows => rows.length === 0));
    const result = await p.approve(); assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: 1000}]);
    const bill = await f.get(`bills/${f.bills[0]}`), proof = await f.get(`paymentProofsV2/${p.paymentId}`);
    assert.equal(bill.status, 'paid'); assert.equal(bill.paidAmountMinor, 1000); assert.equal(bill.outstandingAmountMinor, 0);
    assert.equal(proof.status, 'completed'); assert.equal(proof.transactionId, result.transactionId); assert(proof.receiptGeneration);
    for (const key of Object.keys(submitted)) if (key !== 'status') assert.deepEqual(proof[key], submitted[key]);
    for (const key of ['paymentId', 'paidAt', 'paymentMethod']) assert.equal(Object.hasOwn(bill, key), false);
    assert.deepEqual(await f.get(`bills/${f.bills[0]}/revisions/revision_1`), previous);
    const audit = (await f.rows('auditLogs'))[0][1]; assert.equal(audit.metadata.transactionId, result.transactionId);
    assert.deepEqual(audit.metadata.allocatedAmountsMinor, ['1000']); assert(!JSON.stringify(audit).includes('payment_receipts'));
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].version, 1);
  });
  for (const [revised, outstanding, excess] of [[1200, 200, 0], [800, 0, 200]]) {
    test(`Direct UPI submitted for 1000 before revision to ${revised} settles current liability`, async () => {
      const f = await fixture(environment, [1000, 500]), p = await f.proof();
      const other = await f.get(`bills/${f.bills[1]}`);
      assert.equal((await f.revision(revised)).applied, 1);
      const result = await p.approve(); assert.equal(result.excessCreditMinor, excess);
      assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: Math.min(1000, revised)}]);
      assert.equal((await f.get(`bills/${f.bills[0]}`)).outstandingAmountMinor, outstanding);
      assert.deepEqual(await f.get(`bills/${f.bills[1]}`), other);
      const credits = await f.rows('residentCreditEntries');
      assert.equal(credits.length, excess ? 1 : 0);
      if (excess) {assert.equal(credits[0][1].transactionId, result.transactionId); assert.equal(credits[0][1].amountMinor, excess);}
    });
  }
  test('pending and rejected proofs remain non-financial', async () => {
    const f = await fixture(environment), p = await f.proof();
    await reject({db: f.db, auth, data: {paymentId: p.paymentId, rejectionReason: 'Wrong receipt'}});
    await assert.rejects(p.approve(), /Only pending/);
    assert((await f.financialState()).every(rows => rows.length === 0));
    assert.equal((await f.get(`bills/${f.bills[0]}`)).paidAmountMinor, 0);
  });
  for (const [name, edit] of [['active revision', (f) => f.patch(`billingBatches/${f.batches[0]}`, {activeRevisionId: 'revision-active'})],
    ['stale batch pointer', (f) => f.patch(`bills/${f.bills[0]}`, {appliedBatchRevisionId: 'old'})]]) {
    test(`${name} blocks both settlement paths without any writes`, async () => {
      const f = await fixture(environment), p = await f.proof(); await edit(f);
      const before = await f.financialState();
      await assert.rejects(p.approve(), /blocked/); await assert.rejects(f.pay(), /blocked/);
      assert.deepEqual(await f.financialState(), before); assert.equal((await f.get(`paymentProofsV2/${p.paymentId}`)).status, 'pending');
    });
  }
  for (const paymentMethod of ['cash', 'bank_transfer', 'cheque']) test(`Admin ${paymentMethod} settles one bill with an audit record`, async () => {
    const f = await fixture(environment); const result = await f.pay({paymentMethod, paymentReference: 'REF-1'});
    assert.equal(result.allocations.length, 1); assert.equal((await f.get(`bills/${f.bills[0]}`)).status, 'paid');
    const transaction = (await f.rows('paymentTransactions'))[0][1];
    assert.equal(transaction.method, paymentMethod); assert.equal(transaction.reference, 'REF-1');
    assert.equal((await f.rows('auditLogs'))[0][1].action, 'payment_v2.offline');
  });
  test('Admin payment spans Jan/Feb/Mar oldest-first with a partial final bill', async () => {
    const f = await fixture(environment, [1000, 1200, 800]);
    const result = await f.pay({amountMinor: 2000});
    assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: 1000}, {billId: f.bills[1], amountMinor: 1000}]);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).status, 'paid');
    const partial = await f.get(`bills/${f.bills[1]}`); assert.equal(partial.status, 'partially_paid'); assert.equal(partial.outstandingAmountMinor, 200);
    assert.equal((await f.get(`bills/${f.bills[2]}`)).paidAmountMinor, 0);
  });
  test('Admin excess becomes attributable credit without consuming existing resident credit', async () => {
    const f = await fixture(environment);
    const first = await f.pay({amountMinor: 1300}); assert.equal(first.excessCreditMinor, 300);
    await f.revision(1200);
    const second = await f.pay({idempotencyKey: 'second', amountMinor: 300});
    assert.deepEqual(second.allocations, [{billId: f.bills[0], amountMinor: 200}]); assert.equal(second.excessCreditMinor, 100);
    const account = (await f.rows('residentFinancialAccounts'))[0][1]; assert.equal(account.availableCreditMinor, 400); assert.equal(account.version, 2);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).creditAppliedMinor, 0);
    assert((await f.rows('residentCreditEntries')).every(([, entry]) => entry.eventType === 'issued'));
  });
  for (const kind of ['proof', 'offline']) test(`${kind} retries preserve every financial effect, including after later revision`, async () => {
    const f = await fixture(environment), p = kind === 'proof' ? await f.proof(1300) : null;
    const execute = options => p ? p.approve(options) : f.pay({amountMinor: 1300}, options);
    const first = await execute(); const before = await f.financialState();
    const retry = await execute({now: () => now() + 5000});
    assert.equal(retry.alreadyCompleted, true); assert.equal(retry.transactionId, first.transactionId);
    assert.deepEqual(await f.financialState(), before);
    await f.revision(1200);
    assert.equal((await execute()).transactionId, first.transactionId);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).outstandingAmountMinor, 200);
  });
  test('changed idempotency amount, method, payer or reference fails closed', async () => {
    const f = await fixture(environment); await f.pay(); const before = await f.financialState();
    for (const changed of [{amountMinor: 999}, {paymentMethod: 'cheque'}, {residentId: 'other'}, {paymentReference: 'changed'}]) {
      await assert.rejects(f.pay(changed), /idempotency_conflict/);
    }
    assert.deepEqual(await f.financialState(), before);
  });
  test('move-out and replacement never change historical payment ownership', async () => {
    const f = await fixture(environment), p = await f.proof(400);
    await f.patch('users/r', {isActive: false, status: 'moved_out', communityId: 'OTHER', flatId: null});
    await f.patch('flats/f', {residentUserId: 'replacement'});
    await p.approve(); await f.pay({amountMinor: 700});
    assert((await f.rows('paymentTransactions')).every(([, tx]) => tx.residentId === 'r'));
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].availableCreditMinor, 100);
  });
  for (const [name, changes] of [['paid', {paidAmountMinor: 1}], ['credit', {creditAppliedMinor: 1}],
    ['outstanding', {outstandingAmountMinor: 1}], ['liability', {amountMinor: 1100, chargeLines: lines(1100), outstandingAmountMinor: 1100}]]) {
    test(`${name} drift fails both paths without writes`, async () => {
      const f = await fixture(environment), p = await f.proof(); await f.patch(`bills/${f.bills[0]}`, changes);
      const before = await f.financialState(), bill = await f.get(`bills/${f.bills[0]}`);
      const reason = name === 'liability' ? /previous_bill_revision_mismatch/ : /ledger_projection_mismatch/;
      await assert.rejects(p.approve(), reason); await assert.rejects(f.pay(), reason);
      assert.deepEqual(await f.financialState(), before); assert.deepEqual(await f.get(`bills/${f.bills[0]}`), bill);
    });
  }
  for (const kind of ['proof', 'offline']) test(`${kind} injected failure rolls back proof, allocations, credit, account, bill and audit`, async () => {
    const f = await fixture(environment), p = kind === 'proof' ? await f.proof(1300) : null;
    const original = f.db.runTransaction.bind(f.db), before = await f.financialState(), bill = await f.get(`bills/${f.bills[0]}`);
    f.db.runTransaction = fn => original(async tx => {
      const create = tx.create.bind(tx);
      tx.create = (ref, value) => {const result = create(ref, value); if (ref.path.startsWith('residentCreditEntries/')) throw Error('injected failure'); return result;};
      return fn(tx);
    });
    try {await assert.rejects(p ? p.approve() : f.pay({amountMinor: 1300}), /injected failure/);} finally {f.db.runTransaction = original;}
    assert.deepEqual(await f.financialState(), before); assert.deepEqual(await f.get(`bills/${f.bills[0]}`), bill);
    if (p) assert.equal((await f.get(`paymentProofsV2/${p.paymentId}`)).status, 'pending');
    assert.equal((await (p ? p.approve() : f.pay({amountMinor: 1300}))).excessCreditMinor, 300);
  });
  test('allocation bound fails atomically and exactly the bound succeeds', async () => {
    const f = await fixture(environment, Array(MAX_ALLOCATIONS + 1).fill(1));
    await assert.rejects(f.pay({amountMinor: MAX_ALLOCATIONS + 1}), /split_payment_required/);
    assert((await f.financialState()).every(rows => rows.length === 0));
    assert.equal((await f.pay({amountMinor: MAX_ALLOCATIONS})).allocations.length, MAX_ALLOCATIONS);
  });
  for (const [label, instant, status] of [['due day', '2030-02-15T15:59:59.999Z', 'partially_paid'],
    ['next local midnight', '2030-02-15T16:00:00Z', 'overdue']]) test(`settlement ${label} uses local date and fully paid stays paid`, async () => {
    const f = await fixture(environment); const before = await f.get(`bills/${f.bills[0]}`);
    await f.pay({amountMinor: 400}, {now: () => Date.parse(instant)});
    assert.equal((await f.get(`bills/${f.bills[0]}`)).status, status);
    const p = await f.proof(600); await p.approve({now: () => Date.parse(instant)});
    const bill = await f.get(`bills/${f.bills[0]}`); assert.equal(bill.status, 'paid'); assert.deepEqual(bill.dueDate, before.dueDate);
  });
  test('Admin settlement excludes V1 and foreign bills and does not write V1 payments', async () => {
    const f = await fixture(environment);
    const legacy = {communityId: 'C', residentId: 'r', amount: 100, status: 'pending'};
    const foreign = {...await f.get(`bills/${f.bills[0]}`), residentId: 'other'};
    await f.ref('bills/legacy').set(legacy); await f.ref('bills/foreign').set(foreign);
    await f.pay({amountMinor: 1300});
    assert.deepEqual(await f.get('bills/legacy'), legacy); assert.deepEqual(await f.get('bills/foreign'), foreign);
    assert.equal((await f.rows('payments')).length, 0);
  });
  test('unauthorized, inactive and Super Admin cannot approve or record V2 money', async () => {
    const f = await fixture(environment), p = await f.proof(); const original = await f.get('admins/a');
    for (const change of [{isActive: false}, {role: 'superAdmin'}, {authorizedCommunityIds: ['OTHER']}]) {
      await f.ref('admins/a').set({...original, ...change});
      await assert.rejects(f.pay(), {code: 'permission-denied'}); await assert.rejects(p.approve(), {code: 'permission-denied'});
    }
    await f.ref('admins/a').set(original); await f.patch('communities/C', {isActive: false});
    await assert.rejects(f.pay(), {code: 'failed-precondition'}); await assert.rejects(p.approve(), {code: 'failed-precondition'});
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('preparation and offline requests reject forged balances, overdue and unsupported methods', async () => {
    const f = await fixture(environment), p = await f.proof(400);
    for (const extra of [{outstandingAmountMinor: 2}, {isOverdue: false}, {amountMinor: 0}, {amountMinor: 0.1},
      {amountMinor: Number.MAX_SAFE_INTEGER + 1}, {paymentMethod: 'manual'}, {paymentMethod: 'upi'}]) await assert.rejects(f.pay(extra), {code: 'invalid-argument'});
    await assert.rejects(prepare({db: f.db, auth: {uid: 'other'}, now, data: p.data}));
    await assert.rejects(prepare({db: f.db, auth: {uid: 'r'}, now, data: {...p.data, submittedAt: now()}}), {code: 'invalid-argument'});
    await assert.rejects(prepare({db: f.db, auth: {uid: 'r'}, now, data: {...p.data, submittedAmountMinor: 500}}), /idempotency_conflict/);
    const retry = await prepare({db: f.db, auth: {uid: 'r'}, now, data: p.data}); assert.equal(retry.paymentId, p.paymentId);
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
  });
  test('missing and cross-context receipts never settle', async () => {
    const f = await fixture(environment), p = await f.proof();
    await assert.rejects(p.approve({bucket: {file: () => ({getMetadata: async () => {throw Object.assign(Error('missing'), {code: 404});}})}}), /does not exist/);
    await f.patch(`paymentProofsV2/${p.paymentId}`, {receiptPath: 'https://invalid/private-receipt'});
    await assert.rejects(p.approve(), /Receipt path/);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('receipt metadata must match proof identity, size, generation and MIME type', async () => {
    const f = await fixture(environment), p = await f.proof();
    const metadata = {name: p.receiptPath, generation: '123', size: '10', contentType: 'image/jpeg',
      metadata: {paymentId: p.paymentId, billId: f.bills[0], communityId: 'C', residentUid: 'r'}};
    for (const changes of [{size: '0'}, {size: '10485760'}, {size: 'NaN'}, {generation: null}, {contentType: 'text/plain'},
      {name: 'other'}, {metadata: {...metadata.metadata, residentUid: 'other'}}, {metadata: {...metadata.metadata, paymentId: 'other'}}]) {
      await assert.rejects(p.approve({bucket: {name: 'test', file: () => ({getMetadata: async () => [{...metadata, ...changes}]})}}), /Receipt object/);
    }
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('proof intent drift after approval and immutable event drift both reject retry', async () => {
    const f = await fixture(environment), p = await f.proof(); const result = await p.approve();
    await f.patch(`paymentProofsV2/${p.paymentId}`, {submittedAmountMinor: 900});
    await assert.rejects(p.approve(), /idempotency_conflict/);
    await f.patch(`paymentProofsV2/${p.paymentId}`, {submittedAmountMinor: 1000});
    await f.patch(`paymentTransactions/${result.transactionId}`, {amountMinor: 900});
    await assert.rejects(p.approve(), /immutable_financial_conflict/);
    assert.equal((await f.rows('paymentAllocations')).length, 1);
  });
  test('foreign financial events pointing at a bill and account drift fail closed', async () => {
    const f = await fixture(environment); await f.pay({amountMinor: 400});
    const [allocationId, allocation] = (await f.rows('paymentAllocations'))[0];
    await f.patch(`paymentAllocations/${allocationId}`, {residentId: 'other'});
    await assert.rejects(f.pay({idempotencyKey: 'next'}), /invalid_financial_history/);
    await f.ref(`paymentAllocations/${allocationId}`).set(allocation);
    const accountId = (await f.rows('residentFinancialAccounts'))[0][0];
    await f.patch(`residentFinancialAccounts/${accountId}`, {availableCreditMinor: 100});
    await assert.rejects(f.pay({idempotencyKey: 'next'}), /account_projection_mismatch/);
    assert.equal((await f.rows('paymentTransactions')).length, 1);
  });
  test('missing current immutable bill revision blocks settlement', async () => {
    const f = await fixture(environment), p = await f.proof();
    await f.ref(`bills/${f.bills[0]}/revisions/revision_1`).delete();
    await assert.rejects(f.pay(), /previous_bill_revision_mismatch/); await assert.rejects(p.approve(), /previous_bill_revision_mismatch/);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('simultaneous same-key offline retries commit exactly once', async () => {
    const f = await fixture(environment);
    const results = await Promise.all([f.pay({amountMinor: 1300}), f.pay({amountMinor: 1300})]);
    assert.equal(results[0].transactionId, results[1].transactionId); assert.equal((await f.rows('paymentTransactions')).length, 1);
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].version, 1); assert.equal((await f.rows('residentCreditEntries')).length, 1);
  });
  test('simultaneous proof and offline payments serialize account and cannot overallocate a bill', async () => {
    const f = await fixture(environment), p = await f.proof(600);
    await Promise.all([p.approve(), f.pay({amountMinor: 600})]);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).paidAmountMinor, 1000);
    const account = (await f.rows('residentFinancialAccounts'))[0][1]; assert.equal(account.availableCreditMinor, 200); assert.equal(account.version, 2);
    assert.equal((await f.rows('paymentTransactions')).length, 2);
  });
  test('simultaneous approval of the same proof creates exactly one payment and audit', async () => {
    const f = await fixture(environment), p = await f.proof(1300);
    const results = await Promise.all([p.approve(), p.approve()]);
    assert.equal(results[0].transactionId, results[1].transactionId);
    assert.equal(results.filter(r => r.alreadyCompleted).length, 1);
    for (const name of ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries', 'auditLogs']) {
      assert.equal((await f.rows(name)).length, 1);
    }
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].version, 1);
  });
  test('deterministic transaction collision outside the account query fails without overwriting history', async () => {
    const f = await fixture(environment);
    const sourceId = `settlement_v2_${createHash('sha256').update(JSON.stringify(['offline', 'C', 'offline'])).digest('hex')}`;
    const conflicting = ledger.buildPaymentTransaction({communityId: 'C', residentId: 'other', currency: 'INR',
      sourceType: 'admin_cash', sourceId, sourceState: 'received', method: 'cash', amountMinor: 1000, receivedAt: now(), createdAt: now()});
    await f.ref(`paymentTransactions/${conflicting.id}`).set(conflicting);
    const before = await f.financialState();
    await assert.rejects(f.pay(), /immutable_financial_conflict/);
    assert.deepEqual(await f.financialState(), before);
  });
  test('downward revision of a V2 payment preserves attribution and later payments retain the issued credit', async () => {
    const f = await fixture(environment); const first = await f.pay();
    assert.equal((await f.revision(800)).applied, 1);
    const bill = await f.get(`bills/${f.bills[0]}`); assert.equal(bill.paidAmountMinor, 800);
    const credits = await f.rows('residentCreditEntries');
    assert.equal(credits[0][1].transactionId, first.transactionId); assert.equal(credits[0][1].amountMinor, 200);
    const second = await f.pay({idempotencyKey: 'second', amountMinor: 100});
    assert.deepEqual(second.allocations, []); assert.equal(second.excessCreditMinor, 100);
    const account = (await f.rows('residentFinancialAccounts'))[0][1];
    assert.equal(account.availableCreditMinor, 300); assert.equal(account.version, 3);
  });
  test('credit-only payment for a resident without V2 liabilities retains every received minor unit', async () => {
    const f = await fixture(environment, []); const result = await f.pay({amountMinor: 500});
    assert.deepEqual(result.allocations, []); assert.equal(result.excessCreditMinor, 500);
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].availableCreditMinor, 500);
  });
}
module.exports = {paymentCases, fixture, auth, now};
