const test = require('node:test');
const assert = require('node:assert/strict');
const {sosStore} = require('./helpers/sos_store');
const {createMonthlyBillingBatchV2Core: issue, monthlyBillIdV2} = require('../src/billing_batch');
const {reviseMonthlyBillingBatchV2Core: revise, billingRevisionId, assertV2SettlementReady} = require('../src/billing_revision');
const ledger = require('../src/billing_v2_ledger');
const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const now = () => Date.parse('2030-01-15T00:00:00Z');
const lines = amountMinor => [{lineId: 'base', code: 'maintenance', amountMinor}];
async function fixture(count = 1, beforeIssue) {
  const db = sosStore();
  const set = (path, data) => db.values.set(path, data);
  const patch = (path, data) => set(path, {...db.values.get(path), ...data});
  set('admins/a', {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  set('communities/C', {isActive: true, timeZone: 'Asia/Manila'});
  set('buildings/b', {communityId: 'C'});
  for (let n = 1; n <= count; n++) {
    set(`flats/f${n}`, {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: `r${n}`});
    set(`users/r${n}`, {uid: `r${n}`, role: 'resident', isActive: true, approvalStatus: 'approved', status: 'active',
      communityId: 'C', buildingId: 'b', flatId: `f${n}`});
  }
  if (beforeIssue) beforeIssue({set, patch});
  const creation = {communityId: 'C', scope: 'community', billingPeriod: '2030-01', idempotencyKey: 'issue',
    chargeLines: lines(1000), dueDate: '2030-02-15'};
  let generated;
  do {generated = await issue({db, auth, now, data: creation});} while (generated.resumeRequired);
  const batchId = generated.batchId;
  const batchPath = `billingBatches/${batchId}`;
  const billId = n => monthlyBillIdV2('C', `f${n}`, '2030-01');
  const billPath = n => `bills/${billId(n)}`;
  const data = {communityId: 'C', billingBatchId: batchId, expectedRevisionId: 'revision_1', idempotencyKey: 'edit', chargeLines: lines(1200)};
  const run = (extra = {}, options = {}) => revise({db, auth, now, data: {...data, ...extra}, ...options});
  const docs = name => [...db.values.entries()].filter(([path]) => path.startsWith(`${name}/`) && path.split('/').length === 2);
  function seedMoney(paid = 1000, credit = 0, n = 1) {
    const scope = {communityId: 'C', residentId: `r${n}`, currency: 'INR'};
    const transaction = ledger.buildPaymentTransaction({...scope, sourceType: 'admin_cash', sourceId: `cash${n}`, sourceState: 'received',
      method: 'cash', amountMinor: paid || 1, receivedAt: now(), createdAt: now()});
    const allocation = paid ? ledger.buildAllocationEvent({...scope, transactionId: transaction.id, billId: billId(n),
      eventType: 'allocation', sourceType: 'payment_allocation', sourceId: `settle${n}`, amountMinor: paid, createdAt: now()}) : null;
    if (paid) {set(`paymentTransactions/${transaction.id}`, transaction); set(`paymentAllocations/${allocation.id}`, allocation);}
    if (credit) {
      const entry = ledger.buildCreditEntry({...scope, eventType: 'issued', sourceType: 'payment_excess', sourceId: transaction.id,
        transactionId: transaction.id, amountMinor: credit, createdAt: now()});
      const application = ledger.buildCreditEntry({...scope, eventType: 'applied', sourceType: 'credit_application', sourceId: `apply${n}`,
        billId: billId(n), amountMinor: credit, createdAt: now()});
      set(`residentCreditEntries/${entry.id}`, entry); set(`residentCreditEntries/${application.id}`, application);
      set(`residentFinancialAccounts/${ledger.residentFinancialAccountId(scope)}`, ledger.buildResidentFinancialAccount({...scope, createdAt: now()}));
    }
    patch(billPath(n), ledger.calculateBillProjection({amountMinor: 1000, paidAmountMinor: paid, creditAppliedMinor: credit, currency: 'INR', isOverdue: false}));
    return {transaction, allocation, scope};
  }
  return {db, set, patch, batchId, batchPath, billId, billPath, run, docs, seedMoney, data};
}

test('basic upward revision preserves revision 1 and dates, snapshots revision 2 and updates current pointers', async () => {
  const f = await fixture();
  const batch = f.db.values.get(f.batchPath), bill = f.db.values.get(f.billPath(1));
  const oldBatchRevision = f.db.values.get(`${f.batchPath}/revisions/revision_1`);
  const oldBillRevision = f.db.values.get(`${f.billPath(1)}/revisions/revision_1`);
  const result = await f.run({reason: 'Annual charge update'});
  assert.equal(result.applied, 1); assert.equal(result.revisionNo, 2); assert.equal(result.status, 'completed');
  const updated = f.db.values.get(f.billPath(1)), current = f.db.values.get(f.batchPath);
  assert.equal(updated.amountMinor, 1200); assert.equal(updated.outstandingAmountMinor, 1200); assert.equal(updated.status, 'pending');
  assert.equal(updated.amount, 12); assert.deepEqual(updated.chargeBreakdown, {Maintenance: 12});
  assert.equal(current.currentRevisionId, result.revisionId); assert.equal(current.activeRevisionId, null);
  assert.equal(updated.currentRevisionId, result.revisionId); assert.equal(updated.appliedBatchRevisionId, result.revisionId);
  assert.deepEqual(current.generation, batch.generation); assert.deepEqual(updated.dueDate, bill.dueDate);
  assert.equal(updated.dueDateKey, bill.dueDateKey); assert.equal(updated.timeZone, bill.timeZone);
  assert.deepEqual(f.db.values.get(`${f.batchPath}/revisions/revision_1`), oldBatchRevision);
  assert.deepEqual(f.db.values.get(`${f.billPath(1)}/revisions/revision_1`), oldBillRevision);
  const rev = f.db.values.get(`${f.billPath(1)}/revisions/${result.revisionId}`);
  assert.equal(rev.previousRevisionId, 'revision_1'); assert.equal(rev.amountMinor, 1200); assert.equal(rev.residentId, 'r1');
  for (const key of ['paymentId', 'paidAt', 'paymentMethod']) assert.equal(Object.hasOwn(updated, key), false);
});

for (const [name, paid, credit, revised, expectedPaid, outstanding, available, reversalCount] of [
  ['paid upward', 1000, 0, 1200, 1000, 200, 0, 0],
  ['paid downward', 1000, 0, 800, 800, 0, 200, 1],
  ['mixed downward', 1000, 100, 800, 800, 0, 300, 1],
  ['partial payment', 400, 0, 800, 400, 400, 0, 0],
  ['credit-only downward', 0, 1000, 800, 0, 0, 200, 0],
]) test(name, async () => {
  const f = await fixture(); const {transaction, allocation, scope} = f.seedMoney(paid, credit);
  const originalEvents = [...f.docs('residentCreditEntries'), ...f.docs('paymentAllocations'), ...f.docs('paymentTransactions')];
  const result = await f.run({chargeLines: lines(revised)}); assert.equal(result.applied, 1); assert.equal(result.remaining, 0);
  const bill = f.db.values.get(f.billPath(1)); assert.equal(bill.paidAmountMinor, expectedPaid); assert.equal(bill.outstandingAmountMinor, outstanding);
  const reversals = f.docs('paymentAllocations').filter(([, value]) => value.eventType === 'reversal');
  assert.equal(reversals.length, reversalCount);
  if (reversalCount) {assert.equal(reversals[0][1].amountMinor, 200); assert.equal(reversals[0][1].originalAllocationId, allocation.id);}
  for (const [path, original] of originalEvents) assert.deepEqual(f.db.values.get(path), original);
  if (paid) assert.deepEqual(f.db.values.get(`paymentTransactions/${transaction.id}`), transaction);
  if (available) {
    const account = f.db.values.get(`residentFinancialAccounts/${ledger.residentFinancialAccountId(scope)}`);
    assert.equal(account.availableCreditMinor, available); assert.equal(account.version, 1);
  } else assert.equal(f.docs('residentFinancialAccounts').length, 0);
  if (paid && credit) {
    assert.equal(bill.creditAppliedMinor, 0);
    assert.deepEqual(f.docs('residentCreditEntries').filter(([, e]) => e.sourceType === 'bill_revision')
      .map(([, e]) => [e.eventType, e.amountMinor]), [['restored', 100], ['issued', 200]]);
  }
});

test('equal-total line edit creates a revision without financial events', async () => {
  const f = await fixture(); f.seedMoney(400);
  const result = await f.run({chargeLines: [{lineId: 'custom', code: 'custom', label: 'Repairs', amountMinor: 600}, {lineId: 'base', code: 'maintenance', amountMinor: 400}]});
  assert.equal(result.applied, 1); assert.equal(f.db.values.get(f.billPath(1)).paidAmountMinor, 400);
  assert.equal(f.db.values.get(f.billPath(1)).outstandingAmountMinor, 600);
  assert.equal(f.docs('paymentAllocations').length, 1); assert.equal(f.docs('residentCreditEntries').length, 0);
});

test('same-key retries preserve immutable snapshots/events and changed terms conflict', async () => {
  const f = await fixture(); f.seedMoney();
  const request = {chargeLines: lines(800)}; const first = await f.run(request);
  const snapshot = [...f.db.values.entries()]; const retry = await f.run(request);
  assert.equal(retry.revisionId, first.revisionId); assert.equal(retry.applied, 0); assert.equal(retry.alreadyCompleted, 1);
  assert.deepEqual([...f.db.values.entries()], snapshot);
  await assert.rejects(f.run({chargeLines: lines(700)}), {code: 'already-exists'});
  await assert.rejects(f.run({...request, reason: 'changed'}), {code: 'already-exists'});
  const next = await f.run({idempotencyKey: 'next', expectedRevisionId: first.revisionId, chargeLines: lines(600)});
  assert.equal(next.revisionNo, 3); assert.equal(f.docs('residentFinancialAccounts')[0][1].availableCreditMinor, 400);
  assert.equal((await f.run(request)).revisionId, first.revisionId);
  assert.equal(f.db.values.get(f.batchPath).currentRevisionId, next.revisionId);
});

test('bounded pagination keeps the old current revision and blocks settlement until all bills complete', async () => {
  const f = await fixture(103); const oldGeneration = f.db.values.get(f.batchPath).generation;
  const first = await f.run(); assert.equal(first.applied, 100); assert.equal(first.remaining, 3);
  const batch = f.db.values.get(f.batchPath); assert.equal(batch.currentRevisionId, 'revision_1'); assert.equal(batch.revisionNo, 1);
  assert.equal(batch.activeRevisionId, first.revisionId); assert.equal(batch.activeRevisionNo, 2);
  const bill = f.docs('bills').find(([, b]) => b.appliedBatchRevisionId === first.revisionId)[1];
  assert.throws(() => assertV2SettlementReady({bill, batch, billingBatchId: f.batchId}), {code: 'failed-precondition'});
  await assert.rejects(f.run({idempotencyKey: 'other'}), /Another batch revision/);
  const done = await f.run(); assert.equal(done.applied, 3); assert.equal(done.alreadyCompleted, 100); assert.equal(done.status, 'completed');
  const current = f.db.values.get(f.batchPath);
  assert.deepEqual(current.generation, oldGeneration);
  assertV2SettlementReady({bill: f.db.values.get(f.billPath(1)), batch: current, billingBatchId: f.batchId});
  assert.throws(() => assertV2SettlementReady({bill: {...bill, appliedBatchRevisionId: 'revision_1'}, batch: current, billingBatchId: f.batchId}), /blocked/);
});

test('concurrent distinct revision requests reserve only one active revision', async () => {
  const f = await fixture(101);
  const results = await Promise.allSettled([f.run(), f.run({idempotencyKey: 'competing'})]);
  assert.equal(results.filter(item => item.status === 'fulfilled').length, 1);
  assert.equal(results.filter(item => item.status === 'rejected').length, 1);
  const success = results.find(item => item.status === 'fulfilled').value;
  assert.equal(f.db.values.get(f.batchPath).activeRevisionId, success.revisionId);
});

test('concurrent same-key downward retries cannot duplicate credit or a bill revision', async () => {
  const f = await fixture(); f.seedMoney();
  const results = await Promise.all([f.run({chargeLines: lines(800)}), f.run({chargeLines: lines(800)})]);
  assert.equal(results.reduce((sum, result) => sum + result.applied, 0), 1);
  assert.equal(results[0].revisionId, results[1].revisionId); assert.equal(f.docs('residentCreditEntries').length, 1);
  assert.equal(f.docs('residentFinancialAccounts')[0][1].availableCreditMinor, 200);
});

test('move-out and replacement do not transfer historical bill ownership or resulting credit', async () => {
  const f = await fixture(); f.seedMoney();
  f.patch('users/r1', {status: 'moved_out', flatId: null, isActive: false});
  f.patch('flats/f1', {residentUserId: 'replacement'});
  f.set('users/replacement', {uid: 'replacement', communityId: 'C', flatId: 'f1'});
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  assert.equal(f.db.values.get(f.billPath(1)).residentId, 'r1');
  assert.equal(f.docs('residentFinancialAccounts')[0][1].residentId, 'r1');
});

test('only generated V2 bills are frozen; skipped, conflicted, V1 and unrelated bills are excluded', async () => {
  const f = await fixture(3, ({patch, set}) => {
    patch('flats/f2', {status: 'vacant'});
    set('bills/legacy', {communityId: 'C', flatId: 'f3', billingPeriod: '2030-01'});
  });
  f.set('bills/unrelated', {schemaVersion: 2, billingBatchId: 'other', communityId: 'C'});
  const result = await f.run(); assert.equal(result.targetCount, 1); assert.equal(result.applied, 1);
  assert.equal(f.db.values.get('bills/legacy').amountMinor, undefined);
});

for (const [name, change] of [['paid', {paidAmountMinor: 5}], ['credit', {creditAppliedMinor: 5}], ['outstanding', {outstandingAmountMinor: 5}]]) {
  test(`${name} projection mismatch reconciles without partial financial writes; repair resumes`, async () => {
    const f = await fixture(); f.seedMoney(); f.patch(f.billPath(1), change);
    const result = await f.run({chargeLines: lines(800)});
    assert.equal(result.reconciliationRequired, 1); assert.equal(result.applied, 0); assert.equal(result.remaining, 1);
    assert.equal(result.unresolved[0].reason, 'ledger_projection_mismatch'); assert.equal(f.docs('residentCreditEntries').length, 0);
    assert.equal(f.db.values.get(f.batchPath).currentRevisionId, 'revision_1');
    f.patch(f.billPath(1), {paidAmountMinor: 1000, creditAppliedMinor: 0, outstandingAmountMinor: 0});
    assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  });
}

test('bill ownership mutation after freezing is explicitly reconciled', async () => {
  const f = await fixture(); const original = f.db.runTransaction.bind(f.db); let calls = 0;
  f.db.runTransaction = fn => {if (++calls === 3) f.patch(f.billPath(1), {residentId: 'replacement'}); return original(fn);};
  const result = await f.run(); assert.equal(result.reconciliationRequired, 1);
  assert.equal(result.unresolved[0].reason, 'previous_bill_revision_mismatch');
});

test('failure after staging credit rolls back every effect and safely resumes', async () => {
  const f = await fixture(); f.seedMoney(); const originalBill = f.db.values.get(f.billPath(1));
  const original = f.db.runTransaction.bind(f.db); let fired = false;
  f.db.runTransaction = fn => original(async tx => {
    const create = tx.create;
    tx.create = (ref, value) => {create(ref, value); if (!fired && ref.path.startsWith('residentCreditEntries/')) {fired = true; throw Error('injected write failure');}};
    return fn(tx);
  });
  const partial = await f.run({chargeLines: lines(800)}); assert.equal(partial.failed, 1); assert.equal(partial.applied, 0);
  assert.equal(f.docs('residentCreditEntries').length, 0); assert.equal(f.docs('residentFinancialAccounts').length, 0);
  assert.equal(f.docs('paymentAllocations').length, 1); assert.deepEqual(f.db.values.get(f.billPath(1)), originalBill);
  assert.equal(f.db.values.has(`${f.billPath(1)}/revisions/${partial.revisionId}`), false);
  f.db.runTransaction = original;
  const result = await f.run({chargeLines: lines(800)}); assert.equal(result.applied, 1); assert.equal(result.failed, 0);
});

test('trusted dueDate/server time determine overdue, while paid bills remain paid', async () => {
  for (const paid of [0, 400, 1000]) {
    const f = await fixture(); if (paid) f.seedMoney(paid);
    const result = await f.run({chargeLines: lines(800)}, {now: () => Date.parse('2030-03-01T00:00:00Z')});
    assert.equal(result.applied, 1); assert.equal(f.db.values.get(f.billPath(1)).status, paid === 1000 ? 'paid' : 'overdue');
  }
});

test('V1 settlement fields and pending/rejected proofs supply no V2 paid authority', async () => {
  const f = await fixture(); f.patch(f.billPath(1), {paymentId: 'v1', paymentMethod: 'cash', paidAmount: 1000});
  for (const status of ['pending', 'failed']) f.set(`payments/${status}`, {billId: f.billId(1), amount: 1000, status});
  const before = f.docs('payments');
  assert.equal((await f.run()).applied, 1);
  assert.equal(f.db.values.get(f.billPath(1)).paidAmountMinor, 0); assert.equal(f.db.values.get(f.billPath(1)).outstandingAmountMinor, 1200);
  assert.deepEqual(f.docs('payments'), before);
});

test('invalid financial account identity, balance and event paths fail closed', async () => {
  for (const kind of ['account_identity', 'account_balance', 'event_path', 'foreign_bill_event']) {
    const f = await fixture(); const {scope, allocation} = f.seedMoney(1000, 100);
    const accountPath = `residentFinancialAccounts/${ledger.residentFinancialAccountId(scope)}`;
    if (kind === 'account_identity') f.patch(accountPath, {residentId: 'other'});
    if (kind === 'account_balance') f.patch(accountPath, {availableCreditMinor: 999});
    if (kind === 'event_path') {f.db.values.delete(`paymentAllocations/${allocation.id}`); f.set('paymentAllocations/wrong-id', allocation);}
    if (kind === 'foreign_bill_event') f.set('paymentAllocations/foreign', {...allocation, id: 'foreign', residentId: 'other'});
    const before = f.docs('residentCreditEntries');
    const result = await f.run({chargeLines: lines(800)}); assert.equal(result.reconciliationRequired, 1); assert.equal(result.applied, 0);
    assert.deepEqual(f.docs('residentCreditEntries'), before);
  }
});

test('deterministic financial event collision with changed terms cannot overwrite history', async () => {
  const f = await fixture(); const {transaction, allocation, scope} = f.seedMoney();
  const revisionId = billingRevisionId(f.batchId, 'edit');
  const plan = ledger.planDownwardRevision({...scope, billId: f.billId(1), revisionId, originalAmountMinor: 1000,
    revisedAmountMinor: 800, transactions: [transaction], allocationEvents: [allocation], creditEntries: [], createdAt: now(), isOverdue: false});
  const conflicting = {...plan.creditEntries[0], residentId: 'foreign'};
  f.set(`residentCreditEntries/${conflicting.id}`, {...conflicting, billId: 'another-bill'});
  const result = await f.run({chargeLines: lines(800)});
  assert.equal(result.unresolved[0].reason, 'immutable_event_conflict'); assert.equal(f.docs('paymentAllocations').length, 1);
});

test('authority, strict payload, stale expected revision and unfinished generation checks', async () => {
  const f = await fixture();
  for (const extra of [{isOverdue: false}, {dueDate: '2030-02-01'}, {amountMinor: 1}, {reason: 'x'.repeat(301)}]) {
    await assert.rejects(f.run(extra), {code: 'invalid-argument'});
  }
  await assert.rejects(f.run({expectedRevisionId: 'stale'}), {code: 'failed-precondition'});
  for (const change of [{role: 'superAdmin'}, {isActive: false}, {authorizedCommunityIds: ['OTHER']}]) {
    const original = f.db.values.get('admins/a'); f.patch('admins/a', change);
    await assert.rejects(f.run(), {code: 'permission-denied'}); f.set('admins/a', original);
  }
  f.patch(f.batchPath, {generation: {...f.db.values.get(f.batchPath).generation, failed: 1}});
  await assert.rejects(f.run(), /Finish initial batch generation/);
});

test('new callable uses existing App Check wrapper', () => {
  const source = require('node:fs').readFileSync(`${__dirname}/../src/index.js`, 'utf8');
  assert.match(source, /exports\.reviseMonthlyBillingBatchV2 = appCheckedCallable\(\s*reviseMonthlyBillingBatchV2Core,/);
  assert.match(source, /enforceAppCheck: true/);
});

test('new credit carries forward with existing credit and never automatically pays another bill', async () => {
  const f = await fixture(); const {scope} = f.seedMoney();
  const credit = ledger.buildCreditEntry({...scope, eventType: 'issued', sourceType: 'payment_excess',
    sourceId: 'earlier-receipt', transactionId: 'earlier-receipt', amountMinor: 100, createdAt: now()});
  f.set(`residentCreditEntries/${credit.id}`, credit);
  const accountId = ledger.residentFinancialAccountId(scope);
  f.set(`residentFinancialAccounts/${accountId}`, {...ledger.buildResidentFinancialAccount({...scope, createdAt: now()}),
    availableCreditMinor: 100, version: 5});
  const otherBill = {...f.db.values.get(f.billPath(1)), billingBatchId: 'other-batch', billingPeriod: '2029-12',
    paidAmountMinor: 0, outstandingAmountMinor: 1000, status: 'pending'};
  f.set('bills/older-unpaid', otherBill);
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  const account = f.db.values.get(`residentFinancialAccounts/${accountId}`);
  assert.equal(account.availableCreditMinor, 300); assert.equal(account.version, 6);
  assert.deepEqual(f.db.values.get('bills/older-unpaid'), otherBill);
  assert.equal(f.docs('residentCreditEntries').filter(([, event]) => event.eventType === 'applied').length, 0);
});

test('empty generated population can complete a revision without fabricated financial records', async () => {
  const f = await fixture(1, ({patch}) => patch('flats/f1', {status: 'vacant'}));
  const result = await f.run(); assert.equal(result.targetCount, 0); assert.equal(result.status, 'completed');
  assert.equal(f.db.values.get(f.batchPath).currentRevisionId, result.revisionId);
  assert.equal(f.docs('bills').length, 0); assert.equal(f.docs('residentFinancialAccounts').length, 0);
});

test('equal-total edit preserves mixed historical overallocation without financial corrections', async () => {
  const f = await fixture(); f.seedMoney(1000, 100);
  const before = [...f.docs('paymentAllocations'), ...f.docs('residentCreditEntries'), ...f.docs('residentFinancialAccounts')];
  const result = await f.run({chargeLines: [{lineId: 'repair', code: 'custom', label: 'Repair Fund', amountMinor: 1000}]});
  assert.equal(result.applied, 1);
  const bill = f.db.values.get(f.billPath(1));
  assert.equal(bill.paidAmountMinor, 1000); assert.equal(bill.creditAppliedMinor, 100); assert.equal(bill.outstandingAmountMinor, 0);
  assert.deepEqual([...f.docs('paymentAllocations'), ...f.docs('residentCreditEntries'), ...f.docs('residentFinancialAccounts')], before);
});

for (const kind of ['amount and lines', 'due date']) test(`batch predecessor rejects coherent ${kind} tampering before reservation`, async () => {
  const f = await fixture();
  const previousPath = `${f.batchPath}/revisions/revision_1`, previous = f.db.values.get(previousPath);
  const change = kind === 'amount and lines' ? {amountMinor: 1100, chargeLines: lines(1100)}
    : {dueDate: previous.dueDate.constructor.fromMillis(previous.dueDate.toMillis() + 86400000), dueDateKey: '2030-02-16'};
  f.patch(f.batchPath, change);
  const before = [...f.db.values.entries()];
  await assert.rejects(f.run(), {code: 'failed-precondition', message: 'batch_projection_mismatch'});
  assert.deepEqual([...f.db.values.entries()], before);
  assert.equal(f.db.values.get(f.batchPath).activeRevisionId == null, true);
  const nextPath = `${f.batchPath}/revisions/${billingRevisionId(f.batchId, 'edit')}`;
  assert.equal([...f.db.values.keys()].some(path => path.startsWith(nextPath)), false);
  assert.deepEqual(f.db.values.get(previousPath), previous);
});

test('missing or inconsistent immutable batch predecessors fail closed without reserving anything', async () => {
  for (const change of [null, {schemaVersion: 1}, {billingBatchId: 'other'}, {communityId: 'OTHER'},
    {revisionId: 'other'}, {revisionNo: 2}, {currency: 'USD'}, {billingPeriod: '2030-02'},
    {amountMinor: 999}, {chargeLines: []}, {dueDateKey: '2030-02-16'}, {timeZone: 'UTC'}]) {
    const f = await fixture(), path = `${f.batchPath}/revisions/revision_1`;
    if (change) f.patch(path, change); else f.db.values.delete(path);
    const before = [...f.db.values.entries()];
    await assert.rejects(f.run(), {message: 'batch_projection_mismatch'});
    assert.deepEqual([...f.db.values.entries()], before);
  }
});

test('coherent bill liability tampering after freeze cannot produce financial events or a revision', async () => {
  const f = await fixture(); f.seedMoney();
  const previousPath = `${f.billPath(1)}/revisions/revision_1`, previous = f.db.values.get(previousPath);
  const moneyBefore = [...f.docs('paymentTransactions'), ...f.docs('paymentAllocations'),
    ...f.docs('residentCreditEntries'), ...f.docs('residentFinancialAccounts')];
  const original = f.db.runTransaction.bind(f.db); let calls = 0, tampered;
  f.db.runTransaction = fn => {
    if (++calls === 3) {
      assert.equal(f.db.values.get(f.batchPath).activeRevisionId, billingRevisionId(f.batchId, 'edit'));
      f.patch(f.billPath(1), {amountMinor: 1100, chargeLines: lines(1100), outstandingAmountMinor: 100});
      tampered = f.db.values.get(f.billPath(1));
    }
    return original(fn);
  };
  const result = await f.run({chargeLines: lines(800)});
  assert.equal(result.reconciliationRequired, 1); assert.equal(result.applied, 0);
  assert.equal(result.unresolved[0].reason, 'previous_bill_revision_mismatch');
  assert.deepEqual(f.db.values.get(f.billPath(1)), tampered);
  assert.equal(f.db.values.has(`${f.billPath(1)}/revisions/${result.revisionId}`), false);
  assert.deepEqual(f.db.values.get(previousPath), previous);
  assert.deepEqual([...f.docs('paymentTransactions'), ...f.docs('paymentAllocations'),
    ...f.docs('residentCreditEntries'), ...f.docs('residentFinancialAccounts')], moneyBefore);
});

test('missing or inconsistent immutable bill predecessors require reconciliation', async () => {
  for (const change of [null, {schemaVersion: 1}, {billId: 'other'}, {billingBatchId: 'other'},
    {revisionId: 'other'}, {revisionNo: 2}, {communityId: 'OTHER'}, {residentId: 'other'}, {flatId: 'other'},
    {buildingId: 'other'}, {currency: 'USD'}, {billingKind: 'one_off'}, {billingPeriod: '2030-02'},
    {amountMinor: 999}, {chargeLines: []}, {dueDateKey: '2030-02-16'}, {timeZone: 'UTC'}, {appliedBatchRevisionId: 'other'}]) {
    const f = await fixture(), path = `${f.billPath(1)}/revisions/revision_1`;
    if (change) f.patch(path, change); else f.db.values.delete(path);
    const bill = f.db.values.get(f.billPath(1));
    const result = await f.run();
    assert.equal(result.reconciliationRequired, 1); assert.equal(result.unresolved[0].reason, 'previous_bill_revision_mismatch');
    assert.deepEqual(f.db.values.get(f.billPath(1)), bill);
    assert.equal(f.db.values.has(`${f.billPath(1)}/revisions/${result.revisionId}`), false);
    assert.equal(f.docs('paymentAllocations').length + f.docs('residentCreditEntries').length, 0);
  }
});

test('payment after the predecessor snapshot is validated from ledger history, not snapshot balances', async () => {
  const f = await fixture(), path = `${f.billPath(1)}/revisions/revision_1`;
  const previous = f.db.values.get(path); assert.equal(previous.paidAmountMinor, 0);
  f.seedMoney(400);
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  const bill = f.db.values.get(f.billPath(1));
  assert.equal(bill.paidAmountMinor, 400); assert.equal(bill.outstandingAmountMinor, 400); assert.equal(bill.status, 'partially_paid');
  assert.deepEqual(f.db.values.get(path), previous);
});

test('revision 3 validates self-contained revision 2 with canonical line ordering and preserves all predecessors', async () => {
  const f = await fixture();
  const paths = [`${f.batchPath}/revisions/revision_1`, `${f.billPath(1)}/revisions/revision_1`];
  const old = paths.map(path => f.db.values.get(path));
  const second = await f.run({chargeLines: [...lines(600), {lineId: 'repair', code: 'custom', label: 'Repairs', amountMinor: 600}]});
  assert.equal(second.applied, 1);
  paths.push(`${f.batchPath}/revisions/${second.revisionId}`, `${f.billPath(1)}/revisions/${second.revisionId}`);
  old.push(...paths.slice(2).map(path => f.db.values.get(path)));
  assert.equal(old[2].billingPeriod, '2030-01'); assert.equal(old[3].billingPeriod, '2030-01'); assert.equal(old[3].billingKind, 'recurring');
  for (const path of [f.batchPath, f.billPath(1)]) f.patch(path, {chargeLines: [...f.db.values.get(path).chargeLines].reverse()});
  const third = await f.run({idempotencyKey: 'third', expectedRevisionId: second.revisionId, chargeLines: lines(900)});
  assert.equal(third.applied, 1); assert.equal(third.revisionNo, 3);
  assert.equal(f.db.values.get(`${f.billPath(1)}/revisions/${third.revisionId}`).previousRevisionId, second.revisionId);
  paths.forEach((path, i) => assert.deepEqual(f.db.values.get(path), old[i]));
});

for (const [timeZone, label, instant, overdue] of [
  ['Asia/Manila', 'due-day daytime', '2030-02-15T04:00:00Z', false],
  ['Asia/Manila', 'last millisecond of due day', '2030-02-15T15:59:59.999Z', false],
  ['Asia/Manila', 'next local midnight', '2030-02-15T16:00:00Z', true],
  ['UTC', 'due-day daytime', '2030-02-15T04:00:00Z', false],
  ['UTC', 'last millisecond of due day', '2030-02-15T23:59:59.999Z', false],
  ['UTC', 'next local midnight', '2030-02-16T00:00:00Z', true],
]) test(`${timeZone} ${label}: unpaid/partial respect the calendar boundary and paid stays paid`, async () => {
  const f = await fixture(3, ({patch}) => patch('communities/C', {timeZone}));
  f.seedMoney(400, 0, 2); f.seedMoney(1000, 0, 3);
  const dueDates = [1, 2, 3].map(n => f.db.values.get(f.billPath(n)).dueDate);
  const result = await f.run({chargeLines: lines(800)}, {now: () => Date.parse(instant)});
  assert.equal(result.applied, 3);
  for (const n of [1, 2, 3]) {
    const bill = f.db.values.get(f.billPath(n));
    assert.equal(bill.status, n === 3 ? 'paid' : overdue ? 'overdue' : n === 2 ? 'partially_paid' : 'pending');
    assert.equal(bill.dueDateKey, '2030-02-15'); assert.equal(bill.timeZone, timeZone);
    assert.deepEqual(bill.dueDate, dueDates[n - 1]);
  }
});
