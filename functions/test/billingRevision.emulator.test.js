const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createMonthlyBillingBatchV2Core: issue, monthlyBillIdV2} = require('../src/billing_batch');
const {reviseMonthlyBillingBatchV2Core: revise, billingRevisionId, assertV2SettlementReady} = require('../src/billing_revision');
const ledger = require('../src/billing_v2_ledger');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = 'demo-hominode-billing-revision';
const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const now = () => Date.parse('2030-01-15T00:00:00Z');
const lines = amountMinor => [{lineId: 'base', code: 'maintenance', amountMinor}];
const run = (name, fn) => test(name, {skip: !enabled}, fn);
let app, db;
test.before(async () => {if (enabled) {app = initializeApp({projectId}, 'billing-revision-tests'); db = getFirestore(app);}});
test.after(async () => {if (app) await deleteApp(app);});
test.beforeEach(async () => {
  if (!enabled) return;
  const response = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
  assert.equal(response.ok, true);
});

async function fixture(count = 1, timeZone = 'Asia/Manila') {
  const seed = db.batch();
  seed.set(db.doc('admins/a'), {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  seed.set(db.doc('communities/C'), {isActive: true, timeZone});
  seed.set(db.doc('buildings/b'), {communityId: 'C'});
  for (let n = 1; n <= count; n++) {
    seed.set(db.doc(`flats/f${n}`), {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: `r${n}`});
    seed.set(db.doc(`users/r${n}`), {uid: `r${n}`, role: 'resident', isActive: true, approvalStatus: 'approved', status: 'active',
      communityId: 'C', buildingId: 'b', flatId: `f${n}`});
  }
  await seed.commit();
  const creation = {communityId: 'C', scope: 'community', billingPeriod: '2030-01', idempotencyKey: 'issue', chargeLines: lines(1000), dueDate: '2030-02-15'};
  let generated;
  do {generated = await issue({db, auth, now, data: creation});} while (generated.resumeRequired);
  const batchId = generated.batchId, batchRef = db.doc(`billingBatches/${batchId}`);
  const billRef = n => db.doc(`bills/${monthlyBillIdV2('C', `f${n}`, '2030-01')}`);
  const request = {communityId: 'C', billingBatchId: batchId, expectedRevisionId: 'revision_1', idempotencyKey: 'edit', chargeLines: lines(1200)};
  const run = (extra = {}, options = {}) => revise({db, auth, now, data: {...request, ...extra}, ...options});
  async function seedMoney(paid = 1000, credit = 0, n = 1) {
    const scope = {communityId: 'C', residentId: `r${n}`, currency: 'INR'};
    const transaction = ledger.buildPaymentTransaction({...scope, sourceType: 'admin_cash', sourceId: `cash${n}`, sourceState: 'received',
      method: 'cash', amountMinor: paid, receivedAt: now(), createdAt: now()});
    const allocation = ledger.buildAllocationEvent({...scope, transactionId: transaction.id, billId: billRef(n).id, eventType: 'allocation',
      sourceType: 'payment_allocation', sourceId: `settle${n}`, amountMinor: paid, createdAt: now()});
    const writes = db.batch();
    writes.create(db.doc(`paymentTransactions/${transaction.id}`), transaction);
    writes.create(db.doc(`paymentAllocations/${allocation.id}`), allocation);
    if (credit) {
      for (const entry of [ledger.buildCreditEntry({...scope, eventType: 'issued', sourceType: 'payment_excess', sourceId: transaction.id,
        transactionId: transaction.id, amountMinor: credit, createdAt: now()}), ledger.buildCreditEntry({...scope, eventType: 'applied',
        sourceType: 'credit_application', sourceId: 'apply', billId: billRef(n).id, amountMinor: credit, createdAt: now()})]) {
        writes.create(db.doc(`residentCreditEntries/${entry.id}`), entry);
      }
      writes.create(db.doc(`residentFinancialAccounts/${ledger.residentFinancialAccountId(scope)}`), ledger.buildResidentFinancialAccount({...scope, createdAt: now()}));
    }
    writes.update(billRef(n), ledger.calculateBillProjection({amountMinor: 1000, paidAmountMinor: paid, creditAppliedMinor: credit, currency: 'INR', isOverdue: false}));
    await writes.commit();
    return {transaction, allocation, scope};
  }
  return {batchId, batchRef, billRef, run, seedMoney};
}

run('basic upward revision atomically advances current pointers with immutable old snapshots and unchanged due date', async () => {
  const f = await fixture(); const oldBatch = (await f.batchRef.get()).data(), oldBill = (await f.billRef(1).get()).data();
  const oldRevision = (await f.billRef(1).collection('revisions').doc('revision_1').get()).data();
  const result = await f.run(); assert.equal(result.applied, 1); assert.equal(result.status, 'completed');
  const bill = (await f.billRef(1).get()).data(), batch = (await f.batchRef.get()).data();
  assert.equal(bill.outstandingAmountMinor, 1200); assert.equal(bill.amount, 12); assert.equal(batch.currentRevisionId, result.revisionId);
  assert.equal(bill.currentRevisionId, result.revisionId); assert.equal(batch.activeRevisionId, null);
  assert.deepEqual(batch.generation, oldBatch.generation); assert.deepEqual(bill.dueDate, oldBill.dueDate);
  assert.deepEqual((await f.billRef(1).collection('revisions').doc('revision_1').get()).data(), oldRevision);
  assert.equal((await f.billRef(1).collection('revisions').doc(result.revisionId).get()).data().previousRevisionId, 'revision_1');
  for (const key of ['paidAt', 'paymentId', 'paymentMethod']) assert.equal(Object.hasOwn(bill, key), false);
});

for (const [name, paid, credit, revised, netPaid, outstanding, available] of [
  ['paid upward', 1000, 0, 1200, 1000, 200, 0], ['paid downward', 1000, 0, 800, 800, 0, 200],
  ['mixed downward', 1000, 100, 800, 800, 0, 300], ['partial payment', 400, 0, 800, 400, 400, 0],
]) run(name, async () => {
  const f = await fixture(); const {transaction, allocation, scope} = await f.seedMoney(paid, credit);
  const originalCredit = await db.collection('residentCreditEntries').get();
  const result = await f.run({chargeLines: lines(revised)}); assert.equal(result.applied, 1);
  const bill = (await f.billRef(1).get()).data();
  assert.equal(bill.paidAmountMinor, netPaid); assert.equal(bill.outstandingAmountMinor, outstanding);
  assert.deepEqual((await db.doc(`paymentTransactions/${transaction.id}`).get()).data(), transaction);
  assert.deepEqual((await db.doc(`paymentAllocations/${allocation.id}`).get()).data(), allocation);
  for (const doc of originalCredit.docs) assert.deepEqual((await doc.ref.get()).data(), doc.data());
  const account = await db.doc(`residentFinancialAccounts/${ledger.residentFinancialAccountId(scope)}`).get();
  if (available) {assert.equal(account.data().availableCreditMinor, available); assert.equal(account.data().version, 1);}
  else {assert.equal(account.exists, false); assert.equal((await db.collection('paymentAllocations').get()).size, 1);}
  if (credit) {
    const entries = (await db.collection('residentCreditEntries').where('sourceType', '==', 'bill_revision').get()).docs.map(doc => doc.data());
    assert.equal(entries.find(entry => entry.eventType === 'restored').amountMinor, 100);
    assert.equal(entries.find(entry => entry.eventType === 'issued').amountMinor, 200);
  }
});

run('equal-total edit and exact retries preserve every prior immutable document; changed key terms conflict', async () => {
  const f = await fixture(); await f.seedMoney(400);
  const extra = {chargeLines: [{lineId: 'custom', code: 'custom', label: 'Repair Fund', amountMinor: 600}, ...lines(400)]};
  const first = await f.run(extra);
  const bill = (await f.billRef(1).get()).data(); const revision = (await f.batchRef.collection('revisions').doc(first.revisionId).get()).data();
  const retry = await f.run(extra); assert.equal(retry.applied, 0); assert.equal(retry.alreadyCompleted, 1); assert.equal(retry.revisionId, first.revisionId);
  assert.deepEqual((await f.billRef(1).get()).data(), bill);
  assert.deepEqual((await f.batchRef.collection('revisions').doc(first.revisionId).get()).data(), revision);
  assert.equal((await db.collection('residentCreditEntries').get()).size, 0);
  await assert.rejects(f.run({chargeLines: lines(900)}), {code: 'already-exists'});
});

run('103 bills resume in pages and settlement remains blocked until the final target commits', async () => {
  const f = await fixture(103); const first = await f.run(); assert.equal(first.applied, 100); assert.equal(first.remaining, 3);
  const batch = (await f.batchRef.get()).data(); assert.equal(batch.currentRevisionId, 'revision_1'); assert.equal(batch.activeRevisionId, first.revisionId);
  assert.throws(() => assertV2SettlementReady({batch, bill: ({}), billingBatchId: f.batchId}), /blocked/);
  await assert.rejects(f.run({idempotencyKey: 'another'}), /Another batch revision/);
  const done = await f.run(); assert.equal(done.applied, 3); assert.equal(done.alreadyCompleted, 100); assert.equal(done.remaining, 0);
  const current = (await f.batchRef.get()).data(); assert.equal(current.currentRevisionId, first.revisionId);
  assertV2SettlementReady({batch: current, bill: (await f.billRef(1).get()).data(), billingBatchId: f.batchId});
});

run('concurrent revision reservations accept one key and never produce duplicate financial effects', async () => {
  const f = await fixture(); await f.seedMoney();
  const attempts = await Promise.allSettled([f.run({chargeLines: lines(800)}), f.run({idempotencyKey: 'competing', chargeLines: lines(700)})]);
  const successes = attempts.filter(item => item.status === 'fulfilled'); assert.equal(successes.length, 1);
  const first = successes[0].value;
  if (first.resumeRequired) {
    const winningKey = (await f.batchRef.collection('revisions').doc(first.revisionId).get()).data().idempotencyKey;
    const retry = await f.run({idempotencyKey: winningKey, chargeLines: lines(winningKey === 'edit' ? 800 : 700)});
    assert.equal(retry.remaining, 0);
  }
  assert.equal((await db.collection('residentCreditEntries').get()).size, 1);
  assert.equal((await f.billRef(1).collection('revisions').get()).size, 2);
});

run('resident move-out retains original ownership and newly issued credit stays on that resident', async () => {
  const f = await fixture(); await f.seedMoney();
  await db.doc('users/r1').update({isActive: false, status: 'moved_out', flatId: null});
  await db.doc('flats/f1').update({residentUserId: 'replacement'});
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  assert.equal((await f.billRef(1).get()).data().residentId, 'r1');
  assert.equal((await db.collection('residentFinancialAccounts').get()).docs[0].data().residentId, 'r1');
});

run('ledger mismatch remains active and reconciliation-required without partial financial writes', async () => {
  const f = await fixture(); await f.seedMoney(); await f.billRef(1).update({paidAmountMinor: 999});
  const result = await f.run({chargeLines: lines(800)});
  assert.equal(result.reconciliationRequired, 1); assert.equal(result.unresolved[0].reason, 'ledger_projection_mismatch');
  assert.equal((await db.collection('residentCreditEntries').get()).size, 0);
  assert.equal((await f.billRef(1).collection('revisions').doc(result.revisionId).get()).exists, false);
  const batch = (await f.batchRef.get()).data(); assert.equal(batch.currentRevisionId, 'revision_1'); assert.equal(batch.activeRevisionId, result.revisionId);
  await f.billRef(1).update({paidAmountMinor: 1000}); assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
});

run('exception after staging credit rolls back allocations/account/bill/snapshot/checkpoint and retry commits once', async () => {
  const f = await fixture(); await f.seedMoney(); const billBefore = (await f.billRef(1).get()).data();
  const original = db.runTransaction.bind(db); let fired = false;
  db.runTransaction = fn => original(async tx => {
    const create = tx.create.bind(tx);
    tx.create = (ref, value) => {const result = create(ref, value); if (!fired && ref.path.startsWith('residentCreditEntries/')) {fired = true; throw Error('injected financial failure');} return result;};
    return fn(tx);
  });
  let partial;
  try {partial = await f.run({chargeLines: lines(800)});} finally {db.runTransaction = original;}
  assert.equal(partial.failed, 1); assert.equal(partial.applied, 0);
  assert.equal((await db.collection('residentCreditEntries').get()).size, 0); assert.equal((await db.collection('residentFinancialAccounts').get()).size, 0);
  assert.equal((await db.collection('paymentAllocations').get()).size, 1);
  assert.deepEqual((await f.billRef(1).get()).data(), billBefore);
  assert.equal((await f.billRef(1).collection('revisions').doc(partial.revisionId).get()).exists, false);
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 0);
  assert.equal((await db.collection('residentCreditEntries').get()).size, 1);
});

run('server time drives overdue and pending/rejected V1 proofs never contribute to V2 paid balances', async () => {
  const f = await fixture();
  await db.doc('payments/pending').set({billId: f.billRef(1).id, status: 'pending', amount: 1000});
  await db.doc('payments/rejected').set({billId: f.billRef(1).id, status: 'failed', amount: 1000});
  assert.equal((await f.run({}, {now: () => Date.parse('2030-03-01T00:00:00Z')})).applied, 1);
  const bill = (await f.billRef(1).get()).data(); assert.equal(bill.status, 'overdue'); assert.equal(bill.paidAmountMinor, 0);
  assert.equal(bill.outstandingAmountMinor, 1200); assert.equal((await db.doc('payments/pending').get()).data().status, 'pending');
});

run('foreign/inactive/Super Admin and unexpected due-date editing are rejected', async () => {
  const f = await fixture();
  await assert.rejects(f.run({dueDate: '2030-02-01'}), {code: 'invalid-argument'});
  await db.doc('admins/a').update({role: 'superAdmin'});
  await assert.rejects(f.run(), {code: 'permission-denied'});
  await db.doc('admins/a').update({role: 'admin', isActive: false});
  await assert.rejects(f.run(), {code: 'permission-denied'});
  await db.doc('admins/a').update({isActive: true, authorizedCommunityIds: ['OTHER']});
  await assert.rejects(f.run(), {code: 'permission-denied'});
});

run('concurrent revisions of two monthly bills serialize the same resident account without losing credit', async () => {
  const f = await fixture(); await f.seedMoney();
  const second = await issue({db, auth, now, data: {communityId: 'C', scope: 'community', billingPeriod: '2030-02',
    idempotencyKey: 'issue-february', chargeLines: lines(1000), dueDate: '2030-02-15'}});
  const scope = {communityId: 'C', residentId: 'r1', currency: 'INR'};
  const billId = monthlyBillIdV2('C', 'f1', '2030-02');
  const transaction = ledger.buildPaymentTransaction({...scope, sourceType: 'admin_cash', sourceId: 'feb-cash',
    sourceState: 'received', method: 'cash', amountMinor: 1000, receivedAt: now(), createdAt: now()});
  const allocation = ledger.buildAllocationEvent({...scope, transactionId: transaction.id, billId, eventType: 'allocation',
    sourceType: 'payment_allocation', sourceId: 'feb-settlement', amountMinor: 1000, createdAt: now()});
  const seed = db.batch(); seed.create(db.doc(`paymentTransactions/${transaction.id}`), transaction);
  seed.create(db.doc(`paymentAllocations/${allocation.id}`), allocation);
  seed.update(db.doc(`bills/${billId}`), {paidAmountMinor: 1000, outstandingAmountMinor: 0, status: 'paid'});
  await seed.commit();
  const requests = [{chargeLines: lines(800)}, {billingBatchId: second.batchId, chargeLines: lines(800)}];
  const results = await Promise.all(requests.map(request => f.run(request)));
  for (let i = 0; i < results.length; i++) {
    if (results[i].resumeRequired) results[i] = await f.run(requests[i]);
    assert.equal(results[i].remaining, 0);
  }
  const account = (await db.doc(`residentFinancialAccounts/${ledger.residentFinancialAccountId(scope)}`).get()).data();
  assert.equal(account.availableCreditMinor, 400); assert.equal(account.version, 2);
  assert.equal((await db.collection('residentCreditEntries').get()).size, 2);
  assert.equal((await db.collection('paymentAllocations').get()).size, 4);
  assert.equal((await f.billRef(1).get()).data().paidAmountMinor, 800);
  assert.equal((await db.doc(`bills/${billId}`).get()).data().paidAmountMinor, 800);
});

run('equal-total mixed edit leaves every allocation/credit balance unchanged', async () => {
  const f = await fixture(); await f.seedMoney(1000, 100);
  const result = await f.run({chargeLines: [{lineId: 'repair', code: 'custom', label: 'Repair Fund', amountMinor: 1000}]});
  assert.equal(result.applied, 1);
  const bill = (await f.billRef(1).get()).data();
  assert.equal(bill.paidAmountMinor, 1000); assert.equal(bill.creditAppliedMinor, 100);
  assert.equal((await db.collection('paymentAllocations').get()).size, 1);
  assert.equal((await db.collection('residentCreditEntries').get()).size, 2);
  assert.equal((await db.collection('residentFinancialAccounts').get()).docs[0].data().version, 0);
});

for (const kind of ['amount and lines', 'due date', 'missing predecessor']) run(`batch predecessor rejects ${kind} tampering without reserving a revision`, async () => {
  const f = await fixture(), previousRef = f.batchRef.collection('revisions').doc('revision_1');
  const previous = (await previousRef.get()).data();
  if (kind === 'missing predecessor') await previousRef.delete();
  else await f.batchRef.update(kind === 'amount and lines' ? {amountMinor: 1100, chargeLines: lines(1100)}
    : {dueDate: previous.dueDate.constructor.fromMillis(previous.dueDate.toMillis() + 86400000), dueDateKey: '2030-02-16'});
  const before = (await f.batchRef.get()).data();
  await assert.rejects(f.run(), {code: 'failed-precondition', message: 'batch_projection_mismatch'});
  assert.deepEqual((await f.batchRef.get()).data(), before); assert.equal(before.activeRevisionId == null, true);
  const next = f.batchRef.collection('revisions').doc(billingRevisionId(f.batchId, 'edit'));
  assert.equal((await next.get()).exists, false);
  assert.equal((await next.collection('state').get()).size, 0); assert.equal((await next.collection('targets').get()).size, 0);
  if (kind !== 'missing predecessor') assert.deepEqual((await previousRef.get()).data(), previous);
});

run('coherent bill liability tampering after freeze requires reconciliation without financial effects', async () => {
  const f = await fixture(); await f.seedMoney();
  const previousRef = f.billRef(1).collection('revisions').doc('revision_1'), previous = (await previousRef.get()).data();
  const financialState = () => Promise.all(['paymentTransactions', 'paymentAllocations', 'residentCreditEntries', 'residentFinancialAccounts']
    .map(async name => (await db.collection(name).get()).docs.map(doc => [doc.id, doc.data()])));
  const moneyBefore = await financialState();
  const original = db.runTransaction.bind(db); let calls = 0, tampered, result;
  db.runTransaction = async fn => {
    if (++calls === 3) {
      assert.equal((await f.batchRef.get()).data().activeRevisionId, billingRevisionId(f.batchId, 'edit'));
      await f.billRef(1).update({amountMinor: 1100, chargeLines: lines(1100), outstandingAmountMinor: 100});
      tampered = (await f.billRef(1).get()).data();
    }
    return original(fn);
  };
  try {result = await f.run({chargeLines: lines(800)});} finally {db.runTransaction = original;}
  assert.equal(result.reconciliationRequired, 1); assert.equal(result.applied, 0);
  assert.equal(result.unresolved[0].reason, 'previous_bill_revision_mismatch');
  assert.deepEqual((await f.billRef(1).get()).data(), tampered);
  assert.equal((await f.billRef(1).collection('revisions').doc(result.revisionId).get()).exists, false);
  assert.deepEqual((await previousRef.get()).data(), previous);
  assert.deepEqual(await financialState(), moneyBefore);
});

run('missing immutable bill predecessor requires reconciliation without changing the bill', async () => {
  const f = await fixture(), before = (await f.billRef(1).get()).data();
  await f.billRef(1).collection('revisions').doc('revision_1').delete();
  const result = await f.run();
  assert.equal(result.reconciliationRequired, 1); assert.equal(result.unresolved[0].reason, 'previous_bill_revision_mismatch');
  assert.deepEqual((await f.billRef(1).get()).data(), before);
  assert.equal((await f.billRef(1).collection('revisions').get()).size, 0);
  assert.equal((await db.collection('paymentAllocations').get()).size, 0);
  assert.equal((await db.collection('residentCreditEntries').get()).size, 0);
});

run('payment after the predecessor snapshot proceeds using immutable ledger balances', async () => {
  const f = await fixture(), previousRef = f.billRef(1).collection('revisions').doc('revision_1');
  const previous = (await previousRef.get()).data(); assert.equal(previous.paidAmountMinor, 0);
  await f.seedMoney(400);
  assert.equal((await f.run({chargeLines: lines(800)})).applied, 1);
  const bill = (await f.billRef(1).get()).data();
  assert.equal(bill.paidAmountMinor, 400); assert.equal(bill.outstandingAmountMinor, 400); assert.equal(bill.status, 'partially_paid');
  assert.deepEqual((await previousRef.get()).data(), previous);
});

run('revision 3 validates self-contained revision 2 using canonical lines and preserves both predecessors', async () => {
  const f = await fixture();
  const refs = [f.batchRef.collection('revisions').doc('revision_1'), f.billRef(1).collection('revisions').doc('revision_1')];
  const old = await Promise.all(refs.map(async ref => (await ref.get()).data()));
  const second = await f.run({chargeLines: [...lines(600), {lineId: 'repair', code: 'custom', label: 'Repairs', amountMinor: 600}]});
  assert.equal(second.applied, 1);
  refs.push(f.batchRef.collection('revisions').doc(second.revisionId), f.billRef(1).collection('revisions').doc(second.revisionId));
  old.push(...await Promise.all(refs.slice(2).map(async ref => (await ref.get()).data())));
  assert.equal(old[2].billingPeriod, '2030-01'); assert.equal(old[3].billingPeriod, '2030-01'); assert.equal(old[3].billingKind, 'recurring');
  for (const ref of [f.batchRef, f.billRef(1)]) await ref.update({chargeLines: [...(await ref.get()).data().chargeLines].reverse()});
  const third = await f.run({idempotencyKey: 'third', expectedRevisionId: second.revisionId, chargeLines: lines(900)});
  assert.equal(third.applied, 1); assert.equal(third.revisionNo, 3);
  assert.equal((await f.billRef(1).collection('revisions').doc(third.revisionId).get()).data().previousRevisionId, second.revisionId);
  for (let i = 0; i < refs.length; i++) assert.deepEqual((await refs[i].get()).data(), old[i]);
});

for (const [timeZone, label, instant, overdue] of [
  ['Asia/Manila', 'due-day daytime', '2030-02-15T04:00:00Z', false],
  ['Asia/Manila', 'last millisecond of due day', '2030-02-15T15:59:59.999Z', false],
  ['Asia/Manila', 'next local midnight', '2030-02-15T16:00:00Z', true],
  ['UTC', 'due-day daytime', '2030-02-15T04:00:00Z', false],
  ['UTC', 'last millisecond of due day', '2030-02-15T23:59:59.999Z', false],
  ['UTC', 'next local midnight', '2030-02-16T00:00:00Z', true],
]) run(`${timeZone} ${label}: unpaid/partial respect the calendar boundary and paid stays paid`, async () => {
  const f = await fixture(3, timeZone);
  await f.seedMoney(400, 0, 2); await f.seedMoney(1000, 0, 3);
  const dueDates = await Promise.all([1, 2, 3].map(async n => (await f.billRef(n).get()).data().dueDate));
  const result = await f.run({chargeLines: lines(800)}, {now: () => Date.parse(instant)});
  assert.equal(result.applied, 3);
  for (const n of [1, 2, 3]) {
    const bill = (await f.billRef(n).get()).data();
    assert.equal(bill.status, n === 3 ? 'paid' : overdue ? 'overdue' : n === 2 ? 'partially_paid' : 'pending');
    assert.equal(bill.dueDateKey, '2030-02-15'); assert.equal(bill.timeZone, timeZone);
    assert.deepEqual(bill.dueDate, dueDates[n - 1]);
  }
});
