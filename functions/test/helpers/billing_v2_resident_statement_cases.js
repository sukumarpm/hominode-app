const assert = require('node:assert/strict');
const {Timestamp} = require('firebase-admin/firestore');
const {readFileSync} = require('node:fs');
const {fixture, auth: adminAuth, now} = require('./payment_v2_cases');
const ledger = require('../../src/billing_v2_ledger');
const {createMonthlyBillingBatchV2Core: issue, monthlyBillIdV2} = require('../../src/billing_batch');
const {getResidentBillingV2StatementCore: statementCore,
  MAX_HISTORY_DOCUMENTS} = require('../../src/billing_v2_resident_statement');

const residentAuth = {uid: 'r', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const period = '2030-01';

function statement(db, billingPeriod = period, auth = residentAuth, data = {billingPeriod}, overrides = {}) {
  return statementCore({db, auth, data, now, ...overrides});
}

function assertMinorUnits(value) {
  for (const [key, item] of Object.entries(value)) {
    if (key.endsWith('Minor')) {
      assert.equal(Number.isSafeInteger(item), true, `${key} should be a safe integer`);
      assert.equal(item >= 0, true, `${key} should be nonnegative`);
    } else if (item && typeof item === 'object') assertMinorUnits(item);
  }
}

async function setAccount(f, creditMinor, version = 1) {
  const ref = f.ref(`residentFinancialAccounts/${ledger.residentFinancialAccountId({communityId: 'C', residentId: 'r'})}`);
  const account = (await ref.get()).data() || ledger.buildResidentFinancialAccount({
    communityId: 'C', residentId: 'r', currency: 'INR', createdAt: now(),
  });
  await ref.set({...account, availableCreditMinor: creditMinor, version, updatedAt: now() + version});
}

async function createCreditAppliedToFebruary(f, appliedMinor = 100) {
  await f.pay({amountMinor: 1200, idempotencyKey: 'issue-excess-credit'});
  const february = await issue({db: f.db, auth: adminAuth, now, data: {communityId: 'C', scope: 'community',
    billingPeriod: '2030-02', idempotencyKey: 'statement-credit-february',
    chargeLines: [{lineId: 'base', code: 'maintenance', amountMinor: 1000}], dueDate: '2030-02-15'}});
  f.bills.push(monthlyBillIdV2('C', 'f', '2030-02'));
  f.batches.push(february.batchId);
  const existing = (await f.get(`residentFinancialAccounts/${ledger.residentFinancialAccountId({communityId: 'C', residentId: 'r'})}`));
  assert.equal(existing.availableCreditMinor, 200);
  const entry = ledger.buildCreditEntry({communityId: 'C', residentId: 'r', currency: 'INR',
    eventType: 'applied', sourceType: 'credit_application', sourceId: 'apply-february-credit',
    billId: f.bills[1], amountMinor: appliedMinor, createdAt: now()});
  await f.ref(`residentCreditEntries/${entry.id}`).set(entry);
  const bill = await f.get(`bills/${f.bills[1]}`);
  await f.patch(`bills/${f.bills[1]}`, {creditAppliedMinor: appliedMinor,
    outstandingAmountMinor: bill.amountMinor - appliedMinor,
    status: appliedMinor === bill.amountMinor ? 'paid' : 'partially_paid'});
  await setAccount(f, 200 - appliedMinor, 2);
}

async function seedPaymentHistory(f, {amountMinor, allocationMinor, reversalMinor = 0}) {
  const billId = f.bills[0];
  const tx = ledger.buildPaymentTransaction({communityId: 'C', residentId: 'r', currency: 'INR',
    sourceType: 'admin_cash', sourceId: 'statement-seeded-payment', sourceState: 'received', method: 'cash',
    amountMinor, reference: null, receivedAt: now(), createdAt: now()});
  const allocation = ledger.buildAllocationEvent({communityId: 'C', residentId: 'r', currency: 'INR',
    transactionId: tx.id, billId, eventType: 'allocation', sourceType: 'payment_allocation',
    sourceId: tx.id, amountMinor: allocationMinor, createdAt: now()});
  const transactions = [tx], allocationEvents = [allocation], creditEntries = [];
  if (reversalMinor > 0) {
    const reversal = ledger.buildAllocationEvent({communityId: 'C', residentId: 'r', currency: 'INR',
      transactionId: tx.id, billId, eventType: 'reversal', sourceType: 'bill_revision', sourceId: 'statement-revision',
      originalAllocationId: allocation.id, amountMinor: reversalMinor, createdAt: now() + 1});
    allocationEvents.push(reversal);
    creditEntries.push(ledger.buildCreditEntry({communityId: 'C', residentId: 'r', currency: 'INR',
      eventType: 'issued', sourceType: 'bill_revision', sourceId: 'statement-revision', transactionId: tx.id,
      billId, revisionId: 'statement-revision', allocationReversalId: reversal.id,
      amountMinor: reversalMinor, createdAt: now() + 1}));
  }
  for (const transaction of transactions) await f.ref(`paymentTransactions/${transaction.id}`).set(transaction);
  for (const event of allocationEvents) await f.ref(`paymentAllocations/${event.id}`).set(event);
  for (const entry of creditEntries) await f.ref(`residentCreditEntries/${entry.id}`).set(entry);
  const payments = ledger.summarizeAllocations({communityId: 'C', residentId: 'r', currency: 'INR', transactions, events: allocationEvents});
  const credits = ledger.summarizeCreditEntries({communityId: 'C', residentId: 'r', currency: 'INR', entries: creditEntries});
  const bill = await f.get(`bills/${billId}`);
  const projection = ledger.calculateBillProjection({amountMinor: bill.amountMinor,
    paidAmountMinor: payments.paidByBill[billId] || 0,
    creditAppliedMinor: credits.creditAppliedByBill[billId] || 0,
    currency: 'INR', isOverdue: false});
  await f.patch(`bills/${billId}`, {...projection});
  await setAccount(f, credits.availableCreditMinor, 1);
  return {tx, allocation};
}

function billingV2ResidentStatementCases(test, environment) {
  test('requires verified phone auth and rejects non-resident/admin identities', async () => {
    const f = await fixture(environment, [1000]);
    await assert.rejects(statement(f.db, period, null), {code: 'unauthenticated'});
    await assert.rejects(statement(f.db, period, {uid: 'r'}), {code: 'unauthenticated'});
    await assert.rejects(statement(f.db, period, {uid: 'r', token: {phone_number: '+639171234567',
      firebase: {sign_in_provider: 'password'}}}), {code: 'unauthenticated'});
    const residentResult = await statement(f.db, period, residentAuth);
    assert.equal(residentResult.residentId, 'r');
    await f.ref('users/a').set({uid: 'a', role: 'admin', communityId: 'C', isActive: true,
      approvalStatus: 'approved', status: 'active'});
    const adminPhoneAuth = {uid: 'a', token: residentAuth.token};
    await assert.rejects(statement(f.db, period, adminPhoneAuth), {code: 'permission-denied'});
    await f.patch('users/r', {role: 'superAdmin'});
    await assert.rejects(statement(f.db), {code: 'permission-denied'});
  });

  test('derives resident and community from the trusted active user record', async () => {
    const f = await fixture(environment, []);
    await f.ref('communities/D').set({isActive: true, timeZone: 'Asia/Manila'});
    await f.patch('users/r', {communityId: 'D'});
    const result = await statement(f.db);
    assert.equal(result.residentId, 'r');
    assert.equal(result.communityId, 'D');
    assert.equal(result.billingPeriod, period);
    assert.equal(result.bills.length, 0);
    await assert.rejects(statement(f.db, period, residentAuth, {billingPeriod: period, residentId: 'other'}), {code: 'invalid-argument'});
    await assert.rejects(statement(f.db, period, residentAuth, {billingPeriod: period, communityId: 'C'}), {code: 'invalid-argument'});
  });

  test('rejects inactive, inconsistent and unavailable resident/community identity', async () => {
    const f = await fixture(environment, []);
    await f.patch('users/r', {isActive: false});
    await assert.rejects(statement(f.db), /resident_unavailable/);
    await f.patch('users/r', {isActive: true, status: 'moved_out'});
    await assert.rejects(statement(f.db), /resident_unavailable/);
    await f.patch('users/r', {status: 'active', communityId: 'missing'});
    await assert.rejects(statement(f.db), /community_unavailable/);
    await f.patch('users/r', {communityId: 'C'});
    await f.patch('communities/C', {isActive: false});
    await assert.rejects(statement(f.db), /community_unavailable/);
  });

  test('rejects malformed, empty and extra-field billing periods', async () => {
    const f = await fixture(environment, []);
    for (const billingPeriod of ['', '2030-00', '2030-13', '2030-1', '2030-01-01']) {
      await assert.rejects(statement(f.db, billingPeriod), {code: 'invalid-argument'});
    }
    await assert.rejects(statementCore({db: f.db, auth: residentAuth, data: {}, now}), {code: 'invalid-argument'});
  });

  test('returns an unpaid bill with canonical charge lines and integer minor units', async () => {
    const f = await fixture(environment, [12345]);
    const result = await statement(f.db);
    assert.equal(result.summary.billsCount, 1);
    assert.equal(result.summary.billedMinor, 12345);
    assert.equal(result.summary.paidAllocationMinor, 0);
    assert.equal(result.summary.outstandingMinor, 12345);
    assert.deepEqual(result.summary.statusCounts, {pending: 1, partially_paid: 0, paid: 0, overdue: 0});
    assert.deepEqual(result.bills[0].chargeLines, [{lineId: 'base', code: 'maintenance', label: 'Maintenance', amountMinor: 12345}]);
    assertMinorUnits(result);
  });

  test('computes overdue status from the trusted local due date even if the stored convenience status is stale', async () => {
    const f = await fixture(environment, [1000]);
    const result = await statementCore({db: f.db, auth: residentAuth, data: {billingPeriod: period},
      now: () => Date.parse('2030-03-01T00:00:00Z')});
    assert.equal(result.bills[0].status, 'overdue');
    assert.equal(result.summary.statusCounts.overdue, 1);
  });

  test('returns a fully paid bill and its allocation settlement', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 1000});
    const result = await statement(f.db);
    assert.equal(result.bills[0].status, 'paid');
    assert.equal(result.bills[0].outstandingMinor, 0);
    assert.equal(result.bills[0].settlements[0].netAppliedMinor, 1000);
    assert.equal(result.bills[0].settlements[0].method, 'cash');
  });

  test('projects partial payment from allocation history', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 300});
    const result = await statement(f.db);
    assert.equal(result.bills[0].status, 'partially_paid');
    assert.equal(result.bills[0].paidAllocationMinor, 300);
    assert.equal(result.bills[0].outstandingMinor, 700);
  });

  test('attributes one split payment to each bill in separate periods', async () => {
    const f = await fixture(environment, [500, 500]);
    const payment = await f.pay({amountMinor: 700});
    const jan = await statement(f.db, '2030-01');
    const feb = await statement(f.db, '2030-02');
    assert.equal(jan.bills[0].settlements[0].transactionId, payment.transactionId);
    assert.equal(jan.bills[0].settlements[0].netAppliedMinor, 500);
    assert.equal(feb.bills[0].settlements[0].transactionId, payment.transactionId);
    assert.equal(feb.bills[0].settlements[0].netAppliedMinor, 200);
  });

  test('reports UPI, cash, bank transfer and cheque with a missing reference left null', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 100, idempotencyKey: 'cash-statement'});
    await f.pay({amountMinor: 100, paymentMethod: 'bank_transfer', idempotencyKey: 'bank-statement'});
    await f.pay({amountMinor: 100, paymentMethod: 'cheque', idempotencyKey: 'cheque-statement'});
    await (await f.proof(700, 0, 'upi-statement')).approve();
    const result = await statement(f.db);
    assert.deepEqual(new Set(result.bills[0].settlements.map(row => row.method)),
      new Set(['upi', 'cash', 'bank_transfer', 'cheque']));
    assert.equal(result.bills[0].settlements.find(row => row.method === 'upi').netAppliedMinor, 700);
    assert(result.bills[0].settlements.filter(row => row.method !== 'upi').every(row => row.netAppliedMinor === 100));
    assert(result.bills[0].settlements.some(row => row.method === 'cash' && row.reference === null));
    assertMinorUnits(result);
  });

  test('keeps excess resident credit separate from the selected period liability', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 1200, idempotencyKey: 'excess-credit'});
    const result = await statement(f.db);
    assert.equal(result.summary.outstandingMinor, 0);
    assert.equal(result.summary.availableCreditMinor, 200);
    assert.equal(result.bills[0].settlements[0].netAppliedMinor, 1000);
  });

  test('recomputes a credit application and validates current available account credit', async () => {
    const f = await fixture(environment, [1000]);
    await createCreditAppliedToFebruary(f, 100);
    const result = await statement(f.db, '2030-02');
    assert.equal(result.summary.creditAppliedMinor, 100);
    assert.equal(result.summary.availableCreditMinor, 100);
    assert.equal(result.bills[0].outstandingMinor, 900);
    const accountId = ledger.residentFinancialAccountId({communityId: 'C', residentId: 'r'});
    await f.patch(`residentFinancialAccounts/${accountId}`, {availableCreditMinor: 99});
    await assert.rejects(statement(f.db, '2030-02'), /account_projection_mismatch/);
  });

  test('restores credit from a downward bill revision', async () => {
    const f = await fixture(environment, [1000]);
    await createCreditAppliedToFebruary(f, 100);
    await f.revision(50, 1);
    const result = await statement(f.db, '2030-02');
    assert.equal(result.bills[0].amountMinor, 50);
    assert.equal(result.bills[0].creditAppliedMinor, 50);
    assert.equal(result.summary.availableCreditMinor, 150);
  });

  test('handles a downward revision by reducing net settlement attribution', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 1000});
    await f.revision(600);
    const result = await statement(f.db);
    assert.equal(result.bills[0].amountMinor, 600);
    assert.equal(result.bills[0].paidAllocationMinor, 600);
    assert.equal(result.bills[0].settlements[0].netAppliedMinor, 600);
    assert.equal(result.summary.availableCreditMinor, 400);
  });

  test('allocation reversal reduces net settlement and fully reversed allocations are omitted', async () => {
    const f = await fixture(environment, [1000]);
    await seedPaymentHistory(f, {amountMinor: 1000, allocationMinor: 1000, reversalMinor: 300});
    const partial = await statement(f.db);
    assert.equal(partial.bills[0].settlements[0].netAppliedMinor, 700);
    const g = await fixture(environment, [1000]);
    await seedPaymentHistory(g, {amountMinor: 1000, allocationMinor: 1000, reversalMinor: 1000});
    const full = await statement(g.db);
    assert.deepEqual(full.bills[0].settlements, []);
    assert.equal(full.bills[0].paidAllocationMinor, 0);
  });

  test('fails closed on bill and account projection mismatches', async () => {
    const f = await fixture(environment, [1000]);
    await f.patch(`bills/${f.bills[0]}`, {paidAmountMinor: 1});
    await assert.rejects(statement(f.db), /ledger_projection_mismatch/);
    const g = await fixture(environment, [1000]);
    const accountId = ledger.residentFinancialAccountId({communityId: 'C', residentId: 'r'});
    await g.ref(`residentFinancialAccounts/${accountId}`).set({schemaVersion: 2, id: accountId,
      communityId: 'C', residentId: 'r', currency: 'INR', version: 0,
      availableCreditMinor: 1, createdAt: now(), updatedAt: now()});
    await assert.rejects(statement(g.db), /account_projection_mismatch/);
  });

  test('rejects malformed, cross-community and cross-resident financial history', async () => {
    const malformed = await fixture(environment, [1000]);
    await malformed.ref('paymentTransactions/bad').set({id: 'bad', schemaVersion: 2, communityId: 'C',
      residentId: 'r', currency: 'INR', amountMinor: 0, method: 'cash', sourceType: 'admin_cash',
      sourceId: 'bad', sourceState: 'received', reference: null, receivedAt: now(), createdAt: now()});
    await assert.rejects(statement(malformed.db), /invalid_financial_history/);
    const foreignCommunity = await fixture(environment, [1000]);
    await foreignCommunity.ref('paymentTransactions/foreign').set({id: 'foreign', schemaVersion: 2,
      communityId: 'D', residentId: 'r', currency: 'INR', amountMinor: 1, method: 'cash',
      sourceType: 'admin_cash', sourceId: 'foreign', sourceState: 'received', reference: null,
      receivedAt: now(), createdAt: now()});
    await assert.rejects(statement(foreignCommunity.db), /invalid_financial_history/);
    const foreignResident = await fixture(environment, [1000]);
    const billId = foreignResident.bills[0];
    await foreignResident.ref('paymentAllocations/cross-resident').set({id: 'cross-resident', schemaVersion: 2,
      communityId: 'C', residentId: 'other', currency: 'INR', billId, transactionId: 'elsewhere',
      eventType: 'allocation', direction: 'increase', amountMinor: 1, sourceType: 'payment_allocation',
      sourceId: 'elsewhere', originalAllocationId: null, createdAt: now()});
    await assert.rejects(statement(foreignResident.db), /invalid_financial_history/);
  });

  test('uses integer minor units and deterministic settlement ordering', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 100, idempotencyKey: 'order-a'});
    await f.pay({amountMinor: 100, idempotencyKey: 'order-b'});
    const first = await statement(f.db), second = await statement(f.db);
    assert.deepEqual(first, second);
    const rows = first.bills[0].settlements;
    assert.deepEqual(rows.map(row => row.transactionId), [...rows.map(row => row.transactionId)].sort());
    assertMinorUnits(first);
  });

  test('server-side query limits bound reads before oversized history is processed', async () => {
    const f = await fixture(environment, []);
    for (let index = 0; index < MAX_HISTORY_DOCUMENTS + 2; index++) {
      const id = `tx-${String(index).padStart(5, '0')}`;
      await f.ref(`paymentTransactions/${id}`).set({id, schemaVersion: 2, communityId: 'C',
        residentId: 'r', currency: 'INR', amountMinor: 1, method: 'cash', sourceType: 'admin_cash',
        sourceId: id, sourceState: 'received', reference: null, receivedAt: now(), createdAt: now()});
    }
    let transactionReads = 0, maximumReturned = 0;
    const boundedDb = {collection(name) {
      const collection = f.db.collection(name);
      return new Proxy(collection, {get(target, key) {
        if (key !== 'where') return target[key];
        return (...args) => {
          let cap = null;
          let query = target.where(...args);
          const wrap = current => new Proxy(current, {get(queryTarget, queryKey) {
            if (queryKey === 'where') return (...clause) => wrap(queryTarget.where(...clause));
            if (queryKey === 'limit') return value => {cap = value; return wrap(queryTarget.limit(value));};
            if (queryKey === 'get') return async () => {
              assert([201, MAX_HISTORY_DOCUMENTS + 1].includes(cap));
              const result = await queryTarget.get();
              if (name === 'paymentTransactions') {transactionReads++; maximumReturned = Math.max(maximumReturned, result.size);}
              return result;
            };
            return queryTarget[queryKey];
          }});
          return wrap(query);
        };
      }});
    }};
    await assert.rejects(statement(boundedDb), /financial_history_limit/);
    assert.equal(transactionReads, 1);
    assert.equal(maximumReturned, MAX_HISTORY_DOCUMENTS + 1);
  });

  test('callable registration uses the existing App Check convention', () => {
    const source = readFileSync(require.resolve('../../src/index'), 'utf8');
    assert.match(source, /exports\.getResidentBillingV2Statement = appCheckedCallable\(\s*getResidentBillingV2StatementCore,/);
    assert.match(source, /enforceAppCheck: true/);
  });
}

module.exports = {billingV2ResidentStatementCases};
