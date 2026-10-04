const assert = require('node:assert/strict');
const {Timestamp} = require('firebase-admin/firestore');
const {createMonthlyBillingBatchV2Core: issue} = require('../../src/billing_batch');
const {fixture, auth, now} = require('./payment_v2_cases');

const lines = amountMinor => [{lineId: 'base', code: 'maintenance', amountMinor}];

function assertMinorUnits(report) {
  const values = [
    report.generatedAtMs,
    report.liabilitySummary.billsCount,
    report.liabilitySummary.billedMinor,
    report.liabilitySummary.paidAllocationMinor,
    report.liabilitySummary.creditAppliedMinor,
    report.liabilitySummary.outstandingMinor,
    report.liabilitySummary.overdueOutstandingMinor,
    report.liabilitySummary.statusCounts.pending,
    report.liabilitySummary.statusCounts.partially_paid,
    report.liabilitySummary.statusCounts.paid,
    report.liabilitySummary.statusCounts.overdue,
    report.collectionActivity.transactionCount,
    report.collectionActivity.totalReceivedMinor,
    report.collectionActivity.methods.upi.count,
    report.collectionActivity.methods.upi.totalMinor,
    report.collectionActivity.methods.cash.count,
    report.collectionActivity.methods.cash.totalMinor,
    report.collectionActivity.methods.bank_transfer.count,
    report.collectionActivity.methods.bank_transfer.totalMinor,
    report.collectionActivity.methods.cheque.count,
    report.collectionActivity.methods.cheque.totalMinor,
    report.creditPosition.accountsCount,
    report.creditPosition.residentsWithCreditCount,
    report.creditPosition.totalAvailableCreditMinor,
  ];
  for (const value of values) {
    assert.equal(Number.isSafeInteger(value), true);
    assert.equal(value >= 0, true);
  }
}

async function createSecondResidentMarchBills(f) {
  await f.ref('flats/f2').set({communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: 'r2'});
  await f.ref('users/r2').set({
    uid: 'r2',
    role: 'resident',
    isActive: true,
    approvalStatus: 'approved',
    status: 'active',
    communityId: 'C',
    buildingId: 'b',
    flatId: 'f2',
  });
  await issue({
    db: f.db,
    auth,
    now: () => Date.parse('2030-03-15T00:00:00Z'),
    data: {
      communityId: 'C',
      scope: 'units',
      flatIds: ['f', 'f2'],
      billingPeriod: '2030-03',
      idempotencyKey: 'issue-2030-03-units',
      chargeLines: lines(500),
      dueDate: '2030-04-15',
    },
  });
}

function billingV2ReportCases(test, environment, reportCore) {
  const report = (db, billingPeriod, options = {}) => reportCore({
    db,
    auth,
    data: {communityId: 'C', billingPeriod},
    now: options.now || now,
  });

  test('financial report returns zero totals when no V2 billing activity exists', async () => {
    const f = await fixture(environment, []);
    const result = await report(f.db, '2030-01');
    assert.equal(result.success, true);
    assert.equal(result.communityId, 'C');
    assert.equal(result.billingPeriod, '2030-01');
    assert.deepEqual(result.liabilitySummary, {
      billsCount: 0,
      billedMinor: 0,
      paidAllocationMinor: 0,
      creditAppliedMinor: 0,
      outstandingMinor: 0,
      overdueOutstandingMinor: 0,
      statusCounts: {pending: 0, partially_paid: 0, paid: 0, overdue: 0},
    });
    assert.deepEqual(result.collectionActivity, {
      transactionCount: 0,
      totalReceivedMinor: 0,
      methods: {
        upi: {count: 0, totalMinor: 0},
        cash: {count: 0, totalMinor: 0},
        bank_transfer: {count: 0, totalMinor: 0},
        cheque: {count: 0, totalMinor: 0},
      },
    });
    assert.deepEqual(result.creditPosition, {
      accountsCount: 0,
      residentsWithCreditCount: 0,
      totalAvailableCreditMinor: 0,
    });
    assertMinorUnits(result);
  });

  test('liability summary tracks unpaid, partial and paid progression for the same period', async () => {
    const f = await fixture(environment, [1000]);

    const unpaid = await report(f.db, '2030-01');
    assert.equal(unpaid.liabilitySummary.billedMinor, 1000);
    assert.equal(unpaid.liabilitySummary.paidAllocationMinor, 0);
    assert.equal(unpaid.liabilitySummary.outstandingMinor, 1000);
    assert.equal(unpaid.liabilitySummary.statusCounts.pending, 1);

    await f.pay({amountMinor: 400, idempotencyKey: 'partial-cash'});
    const partial = await report(f.db, '2030-01');
    assert.equal(partial.liabilitySummary.paidAllocationMinor, 400);
    assert.equal(partial.liabilitySummary.outstandingMinor, 600);
    assert.equal(partial.liabilitySummary.statusCounts.partially_paid, 1);
    assert.equal(partial.collectionActivity.totalReceivedMinor, 400);
    assert.equal(partial.collectionActivity.methods.cash.totalMinor, 400);

    await f.pay({amountMinor: 600, idempotencyKey: 'remaining-cash'});
    const paid = await report(f.db, '2030-01');
    assert.equal(paid.liabilitySummary.paidAllocationMinor, 1000);
    assert.equal(paid.liabilitySummary.outstandingMinor, 0);
    assert.equal(paid.liabilitySummary.statusCounts.paid, 1);
    assert.equal(paid.collectionActivity.totalReceivedMinor, 1000);
    assert.equal(paid.collectionActivity.transactionCount, 2);
    assertMinorUnits(paid);
  });

  test('overdue outstanding is computed from local due-date context', async () => {
    const f = await fixture(environment, [1000]);
    const overdue = await report(f.db, '2030-01', {now: () => Date.parse('2030-02-15T16:00:00Z')});
    assert.equal(overdue.liabilitySummary.statusCounts.overdue, 1);
    assert.equal(overdue.liabilitySummary.overdueOutstandingMinor, 1000);
    assert.equal(overdue.liabilitySummary.outstandingMinor, 1000);
    assertMinorUnits(overdue);
  });

  test('collection activity uses local month and provides exact method breakdown including direct UPI', async () => {
    const f = await fixture(environment, [100, 100, 100, 100]);
    const proof = await f.proof(100, 0, 'upi-proof-jan');
    await proof.approve();
    await f.pay({amountMinor: 100, paymentMethod: 'cash', idempotencyKey: 'cash-jan'});
    await f.pay({amountMinor: 100, paymentMethod: 'bank_transfer', idempotencyKey: 'bank-jan'});
    await f.pay({amountMinor: 100, paymentMethod: 'cheque', idempotencyKey: 'cheque-jan'});

    const result = await report(f.db, '2030-01');
    assert.equal(result.collectionActivity.transactionCount, 4);
    assert.equal(result.collectionActivity.totalReceivedMinor, 400);
    assert.deepEqual(result.collectionActivity.methods, {
      upi: {count: 1, totalMinor: 100},
      cash: {count: 1, totalMinor: 100},
      bank_transfer: {count: 1, totalMinor: 100},
      cheque: {count: 1, totalMinor: 100},
    });
    assertMinorUnits(result);
  });

  test('single transaction spanning multiple bills is reflected per-period in liability totals', async () => {
    const f = await fixture(environment, [1000, 1200]);
    await f.pay({amountMinor: 1500, idempotencyKey: 'span-two-bills'});

    const jan = await report(f.db, '2030-01');
    assert.equal(jan.liabilitySummary.paidAllocationMinor, 1000);
    assert.equal(jan.liabilitySummary.outstandingMinor, 0);
    assert.equal(jan.liabilitySummary.statusCounts.paid, 1);
    assert.equal(jan.collectionActivity.totalReceivedMinor, 1500);

    const feb = await report(f.db, '2030-02');
    assert.equal(feb.liabilitySummary.billedMinor, 1200);
    assert.equal(feb.liabilitySummary.paidAllocationMinor, 500);
    assert.equal(feb.liabilitySummary.outstandingMinor, 700);
    assert.equal(feb.liabilitySummary.statusCounts.partially_paid, 1);
    assertMinorUnits(feb);
  });

  test('excess received amount appears as resident credit and downward revision preserves attribution via credit issuance', async () => {
    const f = await fixture(environment, [1000]);
    await f.pay({amountMinor: 1300, idempotencyKey: 'excess-credit'});

    const withExcess = await report(f.db, '2030-01');
    assert.equal(withExcess.liabilitySummary.paidAllocationMinor, 1000);
    assert.equal(withExcess.liabilitySummary.outstandingMinor, 0);
    assert.equal(withExcess.creditPosition.totalAvailableCreditMinor, 300);
    assert.equal(withExcess.creditPosition.residentsWithCreditCount, 1);

    await f.revision(800);
    const revised = await report(f.db, '2030-01');
    assert.equal(revised.liabilitySummary.billedMinor, 800);
    assert.equal(revised.liabilitySummary.paidAllocationMinor, 800);
    assert.equal(revised.liabilitySummary.outstandingMinor, 0);
    assert.equal(revised.creditPosition.totalAvailableCreditMinor, 500);
    assert.equal(revised.collectionActivity.totalReceivedMinor, 1300);
    assertMinorUnits(revised);
  });

  test('multiple residents in one community aggregate correctly', async () => {
    const f = await fixture(environment, []);
    await createSecondResidentMarchBills(f);
    await f.pay({amountMinor: 500, idempotencyKey: 'march-resident-r'});

    const result = await report(f.db, '2030-03');
    assert.equal(result.liabilitySummary.billsCount, 2);
    assert.equal(result.liabilitySummary.billedMinor, 1000);
    assert.equal(result.liabilitySummary.paidAllocationMinor, 500);
    assert.equal(result.liabilitySummary.outstandingMinor, 500);
    assert.equal(result.liabilitySummary.statusCounts.paid, 1);
    assert.equal(result.liabilitySummary.statusCounts.pending, 1);
    assert.equal(result.creditPosition.accountsCount, 1);
    assertMinorUnits(result);
  });

  test('cross-community data is ignored by community-scoped report queries', async () => {
    const f = await fixture(environment, [1000]);
    await f.ref('bills/foreign-bill').set({
      schemaVersion: 2,
      communityId: 'D',
      residentId: 'foreign',
      flatId: 'f2',
      buildingId: 'b2',
      currency: 'INR',
      billingKind: 'recurring',
      billingPeriod: '2030-01',
      amountMinor: 9999,
      paidAmountMinor: 0,
      creditAppliedMinor: 0,
      outstandingAmountMinor: 9999,
      status: 'pending',
      dueDateKey: '2030-02-15',
      timeZone: 'Asia/Manila',
      dueDate: Timestamp.fromMillis(Date.parse('2030-02-14T16:00:00Z')),
    });
    await f.ref('paymentTransactions/foreign-tx').set({
      schemaVersion: 2,
      id: 'foreign-tx',
      communityId: 'D',
      residentId: 'foreign',
      currency: 'INR',
      amountMinor: 9999,
      method: 'cash',
      sourceType: 'admin_cash',
      sourceId: 'foreign',
      sourceState: 'received',
      reference: null,
      receivedAt: now(),
      createdAt: now(),
    });

    const result = await report(f.db, '2030-01');
    assert.equal(result.liabilitySummary.billsCount, 1);
    assert.equal(result.liabilitySummary.billedMinor, 1000);
    assert.equal(result.collectionActivity.totalReceivedMinor, 0);
    assert.equal(result.collectionActivity.transactionCount, 0);
    assertMinorUnits(result);
  });

  test('forged bill projections fail closed with failed-precondition', async () => {
    const f = await fixture(environment, [1000]);
    await f.patch(`bills/${f.bills[0]}`, {paidAmountMinor: 1});
    await assert.rejects(report(f.db, '2030-01'), {
      code: 'failed-precondition',
      message: /billing_v2_financial_report_ledger_projection_mismatch/,
    });
  });
}

module.exports = {billingV2ReportCases};
