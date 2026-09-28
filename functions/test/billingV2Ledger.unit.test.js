const test = require('node:test');
const assert = require('node:assert/strict');
const ledger = require('../src/billing_v2_ledger');
const scope = {communityId: 'C', residentId: 'r1', currency: 'INR'};
const createdAt = Date.parse('2030-01-01T00:00:00Z');
const payment = (overrides = {}) => ledger.buildPaymentTransaction({...scope, sourceType: 'admin_cash', sourceId: 'receipt-1',
  method: 'cash', sourceState: 'received', amountMinor: 1000, receivedAt: createdAt, createdAt, ...overrides});
const allocation = (overrides = {}) => ledger.buildAllocationEvent({...scope, transactionId: payment().id,
  billId: 'jan', eventType: 'allocation', sourceType: 'payment_allocation', sourceId: 'settlement-1', amountMinor: 1000, createdAt, ...overrides});
const issued = (overrides = {}) => ledger.buildCreditEntry({...scope, eventType: 'issued', sourceType: 'payment_excess',
  sourceId: payment().id, transactionId: payment().id, amountMinor: 500, createdAt, ...overrides});
const applied = (overrides = {}) => ledger.buildCreditEntry({...scope, eventType: 'applied', sourceType: 'credit_application',
  sourceId: 'apply-1', billId: 'jan', amountMinor: 200, createdAt, ...overrides});
const liability = (billId, amount, month = '01', overrides = {}) => ({...scope, billId, schemaVersion: 2, eligible: true, issued: true,
  outstandingAmountMinor: amount, billingPeriod: `2030-${month}`, dueDateMs: Date.parse(`2030-${month}-20T00:00:00Z`), createdAtMs: createdAt, ...overrides});
const summarize = (events, transactions = [payment()]) => ledger.summarizeAllocations({...scope, transactions, events});
const credits = entries => ledger.summarizeCreditEntries({...scope, entries});
const projection = extra => ledger.calculateBillProjection({amountMinor: 1000, paidAmountMinor: 0, creditAppliedMinor: 0,
  currency: 'INR', isOverdue: false, ...extra});

test('account identity is deterministic per community/resident and excludes flat identity', () => {
  const first = ledger.residentFinancialAccountId(scope);
  assert.equal(ledger.residentFinancialAccountId({...scope, flatId: 'moved-flat'}), first);
  assert.notEqual(ledger.residentFinancialAccountId({...scope, communityId: 'OTHER'}), first);
  assert.notEqual(ledger.residentFinancialAccountId({...scope, residentId: 'r2'}), first);
  assert.match(first, /^resident_account_v2_[a-f0-9]{64}$/);
  const account = ledger.buildResidentFinancialAccount({...scope, createdAt});
  assert.deepEqual(account, {...scope, schemaVersion: 2, id: first, availableCreditMinor: 0, version: 0, createdAt, updatedAt: createdAt});
});

test('all financial identity helpers reject malformed Firestore identifiers', () => {
  for (const bad of ['', ' padded', '/', 'a/b', '.', '..', '__reserved__', 'x'.repeat(129), 'x\u0000y', '\ud800', null, 123]) {
    for (const key of ['communityId', 'residentId']) {
      assert.throws(() => ledger.residentFinancialAccountId({...scope, [key]: bad}), {code: 'invalid-argument'});
    }
    assert.throws(() => ledger.paymentTransactionId({...scope, sourceType: 'admin_cash', sourceId: bad}), {code: 'invalid-argument'});
    assert.throws(() => allocation({billId: bad}), {code: 'invalid-argument'});
    assert.throws(() => applied({sourceId: bad}), {code: 'invalid-argument'});
  }
});

for (const [name, fields, status, outstanding] of [
  ['unpaid', {}, 'pending', 1000], ['partial', {paidAmountMinor: 400}, 'partially_paid', 600],
  ['paid', {paidAmountMinor: 1000}, 'paid', 0], ['overdue', {isOverdue: true}, 'overdue', 1000],
  ['partial overdue', {paidAmountMinor: 400, isOverdue: true}, 'overdue', 600],
  ['paid past due', {paidAmountMinor: 1000, isOverdue: true}, 'paid', 0],
  ['credit partial', {creditAppliedMinor: 400}, 'partially_paid', 600],
  ['credit paid', {creditAppliedMinor: 1000}, 'paid', 0],
  ['mixed paid', {paidAmountMinor: 600, creditAppliedMinor: 400}, 'paid', 0],
  ['overallocated', {paidAmountMinor: 1000, creditAppliedMinor: 100}, 'paid', 0],
  ['zero liability', {amountMinor: 0}, 'paid', 0],
]) test(`bill projection: ${name}`, () => {
  const result = projection(fields); assert.equal(result.status, status); assert.equal(result.outstandingAmountMinor, outstanding);
  assert.equal(Object.hasOwn(result, 'paymentId'), false);
});

test('balance calculations reject unsafe, negative, fractional, nonfinite and coerced money', () => {
  for (const key of ['amountMinor', 'paidAmountMinor', 'creditAppliedMinor']) {
    for (const value of [-1, 0.1, Infinity, NaN, Number.MAX_SAFE_INTEGER + 1, '100', null, undefined]) {
      assert.throws(() => projection({[key]: value}), {code: 'invalid-argument'});
    }
  }
  assert.throws(() => projection({currency: 'USD'}), {code: 'invalid-argument'});
  assert.throws(() => projection({isOverdue: 'yes'}), {code: 'invalid-argument'});
  // BigInt intermediates avoid unsafe addition even when every field is safe.
  assert.equal(projection({amountMinor: Number.MAX_SAFE_INTEGER, paidAmountMinor: Number.MAX_SAFE_INTEGER,
    creditAppliedMinor: Number.MAX_SAFE_INTEGER}).outstandingAmountMinor, 0);
});

test('payment source identity is stable across retry timestamps, changed amount and changed payer', () => {
  const original = payment();
  const retry = payment({createdAt: createdAt + 1});
  assert.equal(retry.id, original.id); assert.equal(ledger.assertImmutableRetry(original, retry), original);
  for (const change of [{amountMinor: 900}, {residentId: 'r2'}, {receivedAt: createdAt + 1}]) {
    const proposed = payment(change); assert.equal(proposed.id, original.id);
    assert.throws(() => ledger.assertImmutableRetry(original, proposed), /different immutable terms/);
  }
  assert.notEqual(payment({sourceId: 'receipt-2'}).id, original.id);
  assert.notEqual(payment({communityId: 'OTHER'}).id, original.id);
});

test('recognized received/approved sources build transactions; pending/rejected proofs cannot', () => {
  for (const [sourceType, method] of [['admin_cash', 'cash'], ['direct_upi_proof', 'upi'], ['bank_transfer', 'bank_transfer'], ['cheque', 'cheque']]) {
    const result = payment({sourceType, method, sourceState: 'approved', reference: 'Approved source ref'});
    assert.equal(result.schemaVersion, 2); assert.equal(result.reference, 'Approved source ref'); assert(Object.isFrozen(result));
  }
  for (const sourceState of ['pending', 'rejected', 'failed', undefined, 'received']) {
    assert.throws(() => payment({sourceType: 'direct_upi_proof', method: 'upi', sourceState}), {code: 'invalid-argument'});
  }
  for (const fields of [{amountMinor: 0}, {method: 'other'}, {sourceType: 'unknown'}, {receivedAt: NaN}, {createdAt: -1}, {reference: ' '}]) {
    assert.throws(() => payment(fields), {code: 'invalid-argument'});
  }
});

test('allocation/reversal history retains originals and computes net paid without mutating input', () => {
  const original = allocation(); const snapshot = {...original};
  const reversal = allocation({eventType: 'reversal', originalAllocationId: original.id, sourceType: 'bill_revision', sourceId: 'rev2', amountMinor: 200});
  const result = summarize([reversal, original]);
  assert.equal(result.paidByBill.jan, 800); assert.equal(result.remainingAllocations[0].remainingAmountMinor, 800);
  assert.equal(reversal.originalAllocationId, original.id); assert.equal(reversal.direction, 'decrease');
  assert.deepEqual(original, snapshot); assert(Object.isFrozen(original));
});

test('same source is counted once and conflicting financial replay is rejected', () => {
  const original = allocation(); const duplicate = allocation({createdAt: createdAt + 1});
  assert.equal(original.id, duplicate.id); assert.equal(summarize([original, duplicate]).paidByBill.jan, 1000);
  assert.throws(() => summarize([original, allocation({amountMinor: 900})]), /different immutable terms/);
});

test('reversals cannot exceed original unreversed amount, target another bill or reference missing history', () => {
  const original = allocation();
  const reverse = overrides => allocation({eventType: 'reversal', originalAllocationId: original.id, sourceId: 'rev2', amountMinor: 700, ...overrides});
  assert.throws(() => summarize([original, reverse({}), reverse({sourceId: 'rev3', amountMinor: 301})]), /negative/);
  assert.throws(() => summarize([original, reverse({billId: 'feb'})]), /original allocation/);
  assert.throws(() => summarize([reverse({})]), /original allocation/);
  assert.equal(summarize([original, reverse({}), reverse({sourceId: 'rev3', amountMinor: 300})]).paidByBill.jan, 0);
  assert.throws(() => summarize([original], []), /unknown received/);
});

test('allocations support many bills/transactions while limiting each received transaction', () => {
  const p1 = payment(), p2 = payment({sourceId: 'receipt-2'});
  const events = [allocation({amountMinor: 600}), allocation({billId: 'feb', amountMinor: 400}),
    allocation({transactionId: p2.id, sourceId: 'settlement-2', amountMinor: 200})];
  assert.deepEqual(summarize(events, [p1, p2]).paidByBill, {jan: 800, feb: 400});
  assert.throws(() => summarize([allocation(), allocation({billId: 'feb', amountMinor: 1})]), /exceed/);
  assert.throws(() => summarize([allocation({residentId: 'r2'})]), /mismatch/);
});

for (const [name, amountMinor, expected, unallocated] of [
  ['exact single', 1000, [['jan', 1000]], 0], ['partial single', 400, [['jan', 400]], 0],
  ['across months midway', 2000, [['jan', 1000], ['feb', 1000]], 0],
  ['exact all', 3000, [['jan', 1000], ['feb', 1200], ['mar', 800]], 0],
  ['excess', 3500, [['jan', 1000], ['feb', 1200], ['mar', 800]], 500],
  ['zero', 0, [], 0],
]) test(`oldest-first payment planner: ${name}`, () => {
  const liabilities = Object.freeze([liability('mar', 800, '03'), liability('jan', 1000), liability('feb', 1200, '02')].map(Object.freeze));
  const result = ledger.planPaymentAllocations({...scope, amountMinor, liabilities});
  assert.deepEqual(result.allocations, expected.map(([billId, amountMinor]) => ({billId, amountMinor})));
  assert.equal(result.unallocatedAmountMinor, unallocated); assert.equal(liabilities[0].billId, 'mar');
});

test('planner ordering uses due date, billing period, creation time then codepoint bill ID', () => {
  const common = {dueDateMs: createdAt, createdAtMs: createdAt};
  const liabilities = [liability('z', 1, '02', common), liability('B', 1, '01', common),
    liability('A', 1, '01', common), liability('earlier-created', 1, '01', {...common, createdAtMs: createdAt - 1}),
    liability('earlier-due', 1, '12', {...common, dueDateMs: createdAt - 1, schemaVersion: 1})];
  const plan = order => ledger.planPaymentAllocations({...scope, amountMinor: 5, liabilities: order});
  assert.deepEqual(plan(liabilities).allocations.map(item => item.billId), ['earlier-due', 'earlier-created', 'A', 'B', 'z']);
  assert.deepEqual(plan(liabilities), plan([...liabilities].reverse()));
});

test('planner rejects duplicate/malformed/ineligible/cross-account/currency-mixed liabilities', () => {
  const run = liabilities => ledger.planPaymentAllocations({...scope, amountMinor: 1, liabilities});
  assert.throws(() => run([liability('jan', 1), liability('jan', 1)]), /Duplicate/);
  for (const patch of [{outstandingAmountMinor: -1}, {outstandingAmountMinor: Number.MAX_SAFE_INTEGER + 1},
    {outstandingAmountMinor: 1.01}, {currency: 'USD'}, {communityId: 'OTHER'}, {residentId: 'r2'}, {eligible: false},
    {issued: false}, {schemaVersion: 3}, {billingPeriod: '2030-13'}, {dueDateMs: '2030-01-20'}, {createdAtMs: Infinity}]) {
    assert.throws(() => run([liability('jan', 1, '01', patch)]), {code: 'invalid-argument'});
  }
  for (const liabilities of [null, {}, [null], [{}]]) assert.throws(() => run(liabilities), {code: 'invalid-argument'});
  for (const amountMinor of [-1, 1.2, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => ledger.planPaymentAllocations({...scope, amountMinor, liabilities: []}), {code: 'invalid-argument'});
  }
});

test('credit entries issue, apply and restore with auditable source attribution', () => {
  const issue = issued(), apply = applied();
  const restore = ledger.buildCreditEntry({...scope, eventType: 'restored', sourceType: 'bill_revision', sourceId: 'rev2', revisionId: 'rev2',
    billId: 'jan', originalCreditEntryId: apply.id, amountMinor: 100, createdAt});
  assert.equal(credits([issue]).availableCreditMinor, 500);
  assert.equal(credits([issue, apply]).availableCreditMinor, 300);
  assert.equal(credits([issue, apply, restore]).availableCreditMinor, 400);
  assert.equal(credits([issue, apply, restore]).creditAppliedByBill.jan, 100);
  assert.equal(restore.originalCreditEntryId, apply.id); assert.equal(restore.direction, 'increase');
  assert.equal(credits([issue, applied({amountMinor: 500})]).availableCreditMinor, 0);
});

test('credit planner applies oldest first, carries leftovers and can later fund a future issued bill', () => {
  const liabilities = [liability('feb', 600, '02'), liability('jan', 200)];
  const result = ledger.planCreditApplications({...scope, availableCreditMinor: 500, liabilities});
  assert.deepEqual(result, {applications: [{billId: 'jan', amountMinor: 200}, {billId: 'feb', amountMinor: 300}], remainingCreditMinor: 0});
  const carry = ledger.planCreditApplications({...scope, availableCreditMinor: 500, liabilities: [liabilities[1]]});
  assert.equal(carry.remainingCreditMinor, 300);
  assert.deepEqual(ledger.planCreditApplications({...scope, availableCreditMinor: 300, liabilities: [liabilities[0]]}),
    {applications: [{billId: 'feb', amountMinor: 300}], remainingCreditMinor: 0});
  assert.equal(ledger.planCreditApplications({...scope, availableCreditMinor: 300, liabilities: []}).remainingCreditMinor, 300);
});

test('credit entries are idempotent, reject overspend/over-restoration and have no transfer/withdrawal event', () => {
  const issue = issued(), apply = applied();
  assert.equal(issued({createdAt: createdAt + 1}).id, issue.id);
  assert.equal(credits([issue, issue, apply, apply]).availableCreditMinor, 300);
  assert.throws(() => credits([issue, issued({amountMinor: 501})]), /different immutable terms/);
  assert.throws(() => credits([issue, applied({amountMinor: 501})]), /negative/);
  for (const eventType of ['withdrawal', 'transfer', 'refund', 'unknown']) assert.throws(() => issued({eventType}), /Unsupported/);
  const restore = amountMinor => ledger.buildCreditEntry({...scope, eventType: 'restored', sourceType: 'bill_revision', sourceId: 'rev2',
    revisionId: 'rev2', originalCreditEntryId: apply.id, billId: 'jan', amountMinor, createdAt});
  assert.throws(() => credits([issue, apply, restore(201)]), /negative/);
  assert.throws(() => credits([issue, restore(100)]), /original bill application/);
  assert.throws(() => credits([issued({residentId: 'r2'})]), /mismatch/);
  assert.throws(() => credits([issued({amountMinor: Number.MAX_SAFE_INTEGER}), issued({sourceId: 'different', transactionId: 'different', amountMinor: 1})]), /safe integer/);
});

test('account scope isolates credit from flat changes and all planners are side-effect free for V1 records', () => {
  const {sosStore} = require('./helpers/sos_store');
  const db = sosStore();
  const bill = Object.freeze({amount: 100, status: 'paid', paymentId: 'legacy', residentId: 'r1'});
  const legacyPayment = Object.freeze({amount: 100, method: 'external', status: 'completed', billId: 'jan'});
  db.values.set('bills/jan', bill); db.values.set('payments/legacy', legacyPayment);
  const before = [...db.values.entries()];
  delete require.cache[require.resolve('../src/billing_v2_ledger')];
  const imported = require('../src/billing_v2_ledger');
  imported.planPaymentAllocations({...scope, amountMinor: 1, liabilities: [liability('jan', 1, '01', {schemaVersion: 1})]});
  imported.planCreditApplications({...scope, availableCreditMinor: 1, liabilities: []});
  imported.buildPaymentTransaction(payment());
  assert.deepEqual([...db.values.entries()], before);
  assert.deepEqual(credits([issued({...scope, flatId: 'new-flat'})]), credits([issued()]));
});

const revise = (extra = {}) => ledger.planDownwardRevision({...scope, billId: 'jan', revisionId: 'rev2',
  originalAmountMinor: 1000, revisedAmountMinor: 800, createdAt, isOverdue: false,
  transactions: [payment()], allocationEvents: [allocation()], creditEntries: [], ...extra});

test('downward revision 1000 paid to 800 plans an attributable 200 reversal and 200 resident credit', () => {
  const transaction = payment(), original = allocation();
  const plan = revise({transactions: Object.freeze([transaction]), allocationEvents: Object.freeze([original])});
  assert.equal(plan.projection.paidAmountMinor, 800); assert.equal(plan.projection.outstandingAmountMinor, 0);
  assert.equal(plan.allocationEvents.length, 1); assert.equal(plan.allocationEvents[0].amountMinor, 200);
  assert.equal(plan.allocationEvents[0].originalAllocationId, original.id);
  assert.equal(plan.creditEntries[0].eventType, 'issued'); assert.equal(plan.creditEntries[0].amountMinor, 200);
  assert.equal(plan.creditEntries[0].allocationReversalId, plan.allocationEvents[0].id);
  assert.equal(plan.creditEntries[0].transactionId, transaction.id); assert.equal(plan.creditEntries[0].revisionId, 'rev2');
  assert.equal(plan.availableCreditMinor, 200); assert.equal(original.amountMinor, 1000); assert.equal(transaction.amountMinor, 1000);
});

test('downward revision with only 400 paid retains payment and leaves 400 outstanding without credit', () => {
  const plan = revise({allocationEvents: [allocation({amountMinor: 400})]});
  assert.equal(plan.projection.paidAmountMinor, 400); assert.equal(plan.projection.outstandingAmountMinor, 400);
  assert.equal(plan.projection.status, 'partially_paid'); assert.deepEqual(plan.allocationEvents, []); assert.deepEqual(plan.creditEntries, []);
});

test('concurrent plans use identical source IDs and merging retries cannot double-credit', async () => {
  const [first, second] = await Promise.all([Promise.resolve(revise()), Promise.resolve(revise({createdAt: createdAt + 1}))]);
  assert.equal(first.allocationEvents[0].id, second.allocationEvents[0].id);
  assert.equal(first.creditEntries[0].id, second.creditEntries[0].id);
  assert.equal(summarize([allocation(), ...first.allocationEvents, ...second.allocationEvents]).paidByBill.jan, 800);
  assert.equal(credits([...first.creditEntries, ...second.creditEntries]).availableCreditMinor, 200);
  const rebased = revise({allocationEvents: [allocation(), ...first.allocationEvents], creditEntries: first.creditEntries});
  assert.deepEqual(rebased.allocationEvents, []); assert.deepEqual(rebased.creditEntries, []); assert.equal(rebased.availableCreditMinor, 200);
  assert.deepEqual(rebased.projection, first.projection);
});

test('downward correction follows remaining allocation attribution newest-first with deterministic ties', () => {
  const p2 = payment({sourceId: 'receipt-2', amountMinor: 600});
  const a1 = allocation({amountMinor: 400});
  const a2 = allocation({transactionId: p2.id, sourceId: 'second', amountMinor: 600, createdAt: createdAt + 1});
  const args = {transactions: [payment(), p2], allocationEvents: [a1, a2], revisedAmountMinor: 300};
  const result = revise(args);
  assert.deepEqual(result.allocationEvents.map(event => [event.originalAllocationId, event.amountMinor]), [[a2.id, 600], [a1.id, 100]]);
  assert.deepEqual(result.creditEntries.map(event => [event.transactionId, event.amountMinor]), [[p2.id, 600], [payment().id, 100]]);
  assert.deepEqual(revise({...args, allocationEvents: [a2, a1]}), result);
});

test('zero revision fully releases payments; upward/invalid revisions are rejected', () => {
  const zero = revise({revisedAmountMinor: 0}); assert.equal(zero.projection.paidAmountMinor, 0); assert.equal(zero.availableCreditMinor, 1000);
  for (const revisedAmountMinor of [-1, 1.1, Infinity, Number.MAX_SAFE_INTEGER + 1, 1001]) {
    assert.throws(() => revise({revisedAmountMinor}), {code: 'invalid-argument'});
  }
});

test('mixed downward revision restores 100 applied credit before reversing 200 paid and issuing 200 credit', () => {
  const application = applied({amountMinor: 100});
  const transaction = payment(), original = allocation();
  const history = [issued({amountMinor: 100}), application];
  const before = JSON.stringify({transaction, original, history});
  const result = revise({transactions: [transaction], allocationEvents: [original], creditEntries: history});
  assert.equal(result.projection.paidAmountMinor, 800); assert.equal(result.projection.creditAppliedMinor, 0);
  assert.equal(result.projection.outstandingAmountMinor, 0); assert.equal(result.projection.status, 'paid');
  assert.equal(result.allocationEvents.length, 1); assert.equal(result.allocationEvents[0].amountMinor, 200);
  assert.equal(result.allocationEvents[0].originalAllocationId, original.id);
  assert.deepEqual(result.creditEntries.map(event => [event.eventType, event.amountMinor]), [['restored', 100], ['issued', 200]]);
  assert.equal(result.creditEntries[0].originalCreditEntryId, application.id);
  assert.equal(result.creditEntries[1].allocationReversalId, result.allocationEvents[0].id);
  assert.equal(result.creditEntries[1].transactionId, transaction.id); assert.equal(result.availableCreditMinor, 300);
  assert.equal(JSON.stringify({transaction, original, history}), before);
});

test('mixed revision restores only excess credit when payments fit the revised liability', () => {
  const result = revise({allocationEvents: [allocation({amountMinor: 700})],
    creditEntries: [issued({amountMinor: 200}), applied({amountMinor: 200})]});
  assert.equal(result.projection.paidAmountMinor, 700); assert.equal(result.projection.creditAppliedMinor, 100);
  assert.equal(result.projection.outstandingAmountMinor, 0); assert.equal(result.availableCreditMinor, 100);
  assert.deepEqual(result.allocationEvents, []);
  assert.deepEqual(result.creditEntries.map(event => [event.eventType, event.amountMinor]), [['restored', 100]]);
});

test('mixed revision without excess preserves both payment and credit attribution', () => {
  const withoutExcess = revise({allocationEvents: [allocation({amountMinor: 400})],
    creditEntries: [issued({amountMinor: 100}), applied({amountMinor: 100})]});
  assert.equal(withoutExcess.projection.outstandingAmountMinor, 300);
  assert.equal(withoutExcess.projection.paidAmountMinor, 400); assert.equal(withoutExcess.projection.creditAppliedMinor, 100);
  assert.deepEqual(withoutExcess.allocationEvents, []); assert.deepEqual(withoutExcess.creditEntries, []);
});

test('mixed revision retries cannot double-restore or double-issue resident credit', async () => {
  const history = [issued({amountMinor: 100}), applied({amountMinor: 100})];
  const [first, second] = await Promise.all([Promise.resolve(revise({creditEntries: history})),
    Promise.resolve(revise({creditEntries: history, createdAt: createdAt + 1}))]);
  assert.deepEqual(first.creditEntries.map(event => event.id), second.creditEntries.map(event => event.id));
  assert.equal(first.allocationEvents[0].id, second.allocationEvents[0].id);
  const mergedCredit = [...history, ...first.creditEntries, ...second.creditEntries];
  const mergedPayments = [allocation(), ...first.allocationEvents, ...second.allocationEvents];
  assert.equal(credits(mergedCredit).availableCreditMinor, 300); assert.equal(credits(mergedCredit).creditAppliedByBill.jan, 0);
  assert.equal(summarize(mergedPayments).paidByBill.jan, 800);
  const retry = revise({allocationEvents: mergedPayments, creditEntries: mergedCredit});
  assert.deepEqual(retry.creditEntries, []); assert.deepEqual(retry.allocationEvents, []);
  assert.equal(retry.availableCreditMinor, 300); assert.deepEqual(retry.projection, first.projection);
});

test('mixed revision restores only remaining credit applications newest-first and preserves other bills', () => {
  const a1 = applied({sourceId: 'first-credit', amountMinor: 120});
  const a2 = applied({sourceId: 'second-credit', amountMinor: 100, createdAt: createdAt + 1});
  const previous = ledger.buildCreditEntry({...scope, eventType: 'restored', sourceType: 'bill_revision', sourceId: 'rev1',
    revisionId: 'rev1', originalCreditEntryId: a1.id, billId: 'jan', amountMinor: 20, createdAt});
  const history = [issued(), a1, a2, previous, applied({sourceId: 'other-bill', billId: 'feb', amountMinor: 50})];
  const args = {allocationEvents: [allocation({amountMinor: 750})], creditEntries: history};
  const result = revise(args);
  assert.deepEqual(result.creditEntries.map(event => [event.originalCreditEntryId, event.amountMinor]), [[a2.id, 100], [a1.id, 50]]);
  assert.deepEqual(result.allocationEvents, []); assert.equal(result.projection.creditAppliedMinor, 50);
  assert.equal(credits([...history, ...result.creditEntries]).creditAppliedByBill.feb, 50);
  assert.deepEqual(revise({...args, creditEntries: [...history].reverse()}), result);
});

test('credit-only downward revision restores original applied credit without issuing new credit', () => {
  const application = applied({amountMinor: 1000});
  const history = [issued({amountMinor: 1000}), application];
  const plan = revise({allocationEvents: [], creditEntries: history});
  assert.equal(plan.projection.creditAppliedMinor, 800); assert.equal(plan.projection.paidAmountMinor, 0);
  assert.deepEqual(plan.allocationEvents, []); assert.equal(plan.creditEntries.length, 1);
  assert.equal(plan.creditEntries[0].eventType, 'restored'); assert.equal(plan.creditEntries[0].amountMinor, 200);
  assert.equal(plan.creditEntries[0].originalCreditEntryId, application.id); assert.equal(plan.availableCreditMinor, 200);
  const retry = revise({allocationEvents: [], creditEntries: [...history, ...plan.creditEntries]});
  assert.deepEqual(retry.creditEntries, []); assert.equal(retry.availableCreditMinor, 200);
});
