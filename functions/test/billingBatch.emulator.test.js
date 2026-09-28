const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createMonthlyBillingBatchV2Core: generate, monthlyBillIdV2} = require('../src/billing_batch');
const {createMaintenanceBillsCore, recurringBillId} = require('../src/billing_management');

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = 'demo-hominode-billing-v2';
const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const data = {communityId: 'C', scope: 'community', billingPeriod: '2030-01', idempotencyKey: 'january',
  dueDate: '2030-02-28', chargeLines: [{lineId: 'base', code: 'maintenance', amountMinor: 100001},
    {lineId: 'water', code: 'water', amountMinor: 299}]};
const now = () => Date.parse('2030-01-31T12:00:00Z');
let app, db;
const run = (name, fn) => test(name, {skip: !enabled}, fn);
const issue = (extra = {}, options = {}) => generate({db, auth, data: {...data, ...extra}, now, ...options});
const billRef = n => db.collection('bills').doc(monthlyBillIdV2('C', `f${n}`, '2030-01'));

async function seedUnits(start, end) {
  const batch = db.batch();
  for (let n = start; n <= end; n++) {
    batch.set(db.doc(`flats/f${n}`), {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: `r${n}`, flatLabel: `Unit ${n}`});
    batch.set(db.doc(`users/r${n}`), {uid: `r${n}`, role: 'resident', isActive: true, approvalStatus: 'approved',
      status: 'active', communityId: 'C', buildingId: 'b', flatId: `f${n}`, name: `Resident ${n}`});
  }
  await batch.commit();
}

test.before(async () => {
  if (!enabled) return;
  app = initializeApp({projectId}, 'billing-v2-integration');
  db = getFirestore(app);
});
test.after(async () => {if (app) await deleteApp(app);});
test.beforeEach(async () => {
  if (!enabled) return;
  // Only this dedicated demo database is cleared; never a configured live project.
  const response = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
  assert.equal(response.ok, true);
  await Promise.all([
    db.doc('admins/a').set({uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']}),
    db.doc('communities/C').set({isActive: true, timeZone: 'Asia/Manila'}),
    db.doc('buildings/b').set({communityId: 'C'}),
  ]);
  await seedUnits(1, 2);
});

run('V2 transaction persists coherent bills, assignments and immutable revisions across retries', async () => {
  const first = await issue(); assert.equal(first.created, 2);
  const batchRef = db.doc(`billingBatches/${first.batchId}`);
  const batchRevisionRef = batchRef.collection('revisions').doc('revision_1');
  const revisionRef = billRef(1).collection('revisions').doc('revision_1');
  const initial = (await billRef(1).get()).data();
  const batchRevision = (await batchRevisionRef.get()).data();
  const billRevision = (await revisionRef.get()).data();
  assert.equal(initial.amountMinor, 100300); assert.equal(initial.amount, 1003);
  assert.equal(initial.outstandingAmountMinor, 100300); assert.equal(initial.paidAmountMinor, 0); assert.equal(initial.creditAppliedMinor, 0);
  assert.equal(initial.billingBatchId, first.batchId); assert.equal(initial.appliedBatchRevisionId, 'revision_1');
  assert.equal(initial.dueDate.toDate().toISOString(), '2030-02-27T16:00:00.000Z');
  assert.equal(initial.chargeLines.length, 2); assert.equal(initial.currency, 'INR');
  for (const key of ['paymentId', 'paymentMethod', 'paymentReference', 'paidAt']) assert.equal(Object.hasOwn(initial, key), false);
  const retry = await issue({}, {now: () => Date.parse('2030-07-01T00:00:00Z')});
  assert.equal(retry.batchId, first.batchId); assert.equal(retry.created, 0); assert.equal(retry.alreadyCompleted, 2);
  assert.deepEqual((await billRef(1).get()).data(), initial);
  assert.deepEqual((await batchRevisionRef.get()).data(), batchRevision); assert.deepEqual((await revisionRef.get()).data(), billRevision);
  assert.equal((await db.collection('billingBatches').get()).size, 1);
  assert.equal((await db.collection('billingAssignments').get()).size, 2);
  assert.equal((await db.collection('bills').get()).size, 2);
});

run('concurrent same-key requests create exactly one batch and one liability per unit', async () => {
  const results = await Promise.all([issue(), issue()]);
  assert.equal(results[0].batchId, results[1].batchId);
  assert.equal(results.reduce((sum, item) => sum + item.created, 0), 2);
  assert.equal((await db.collection('billingBatches').get()).size, 1);
  assert.equal((await db.collection('bills').get()).size, 2);
  assert.equal((await db.collection('billingAssignments').get()).size, 2);
  assert.equal((await billRef(1).collection('revisions').get()).size, 1);
});

run('concurrent overlapping batches with different lines cannot create duplicate unit/month liability', async () => {
  const requests = [
    {scope: 'units', flatIds: ['f1']},
    {scope: 'unit', buildingId: 'b', flatId: 'f1', idempotencyKey: 'parking',
      chargeLines: [{lineId: 'parking', code: 'parking', amountMinor: 30000}]},
  ];
  const results = await Promise.all(requests.map(request => issue(request)));
  let created = results.reduce((sum, item) => sum + item.created, 0);
  assert(created <= 1);
  assert((await db.collection('bills').get()).size <= 1);
  for (let i = 0; i < results.length; i++) {
    // Contention can exhaust SDK retries, particularly on the emulator. Such
    // a target must be explicitly reported and remain safely resumable.
    if (results[i].resumeRequired) {
      assert.equal(results[i].failed, 1); assert.equal(results[i].unresolved[0].flatId, 'f1');
      results[i] = await issue(requests[i]);
      created += results[i].created;
    }
    assert.equal(results[i].resumeRequired, false);
    assert.equal(results[i].failed, 0);
  }
  assert.equal(created, 1);
  assert.equal(results.reduce((sum, item) => sum + item.reconciliationRequired, 0), 1);
  assert.equal((await db.collection('bills').get()).size, 1); assert.equal((await db.collection('billingAssignments').get()).size, 1);
  const conflict = results.find(item => item.reconciliationRequired).conflicts[0];
  assert.equal(conflict.flatId, 'f1'); assert.equal(conflict.reason, 'unit_period_already_assigned');
});

run('existing V1 water liability is preserved and explicitly blocks V2 while ad-hoc remains separate', async () => {
  await createMaintenanceBillsCore({db, auth, data: {communityId: 'C', scope: 'unit', buildingId: 'b', flatId: 'f1',
    month: 'Jan', year: '2030', chargeType: 'water', amount: 10, dueDate: '2030-02-01'}});
  const legacyRef = db.doc(`bills/${recurringBillId('C', 'f1', 'water', '2030-01')}`);
  const original = (await legacyRef.get()).data();
  await db.doc('bills/ad-hoc').set({billingKind: 'ad_hoc', communityId: 'C', flatId: 'f2', billingPeriod: '2030-01'});
  const result = await issue(); assert.equal(result.created, 1); assert.equal(result.reconciliationRequired, 1);
  assert.deepEqual(result.conflicts[0].billIds, [legacyRef.id]); assert.deepEqual((await legacyRef.get()).data(), original);
  assert.equal((await billRef(1).get()).exists, false); assert.equal((await billRef(2).get()).exists, true);
});

run('failed target transaction rolls back financial records and resumes on retry', async () => {
  const original = db.runTransaction.bind(db); let fired = false;
  db.runTransaction = fn => original(async transaction => {
    const create = transaction.create.bind(transaction);
    transaction.create = (ref, value) => {
      const result = create(ref, value);
      if (!fired && ref.path === billRef(2).path) {fired = true; throw Error('injected failure after staging bill');}
      return result;
    };
    return fn(transaction);
  });
  let partial;
  try {partial = await issue();} finally {db.runTransaction = original;}
  assert.equal(partial.created, 1); assert.equal(partial.failed, 1); assert.equal(partial.remaining, 1);
  assert.equal((await billRef(2).get()).exists, false);
  assert.equal((await db.doc(`billingAssignments/${billRef(2).id}`).get()).exists, false);
  assert.equal((await billRef(2).collection('revisions').get()).size, 0);
  const originalBill = (await billRef(1).get()).data();
  const retry = await issue(); assert.equal(retry.created, 1); assert.equal(retry.failed, 0); assert.equal(retry.status, 'completed');
  assert.deepEqual((await billRef(1).get()).data(), originalBill);
});

run('generation over 100 units resumes a frozen manifest without expanding scope', async () => {
  await seedUnits(3, 102);
  const first = await issue(); assert.equal(first.created, 100); assert.equal(first.remaining, 2);
  await seedUnits(103, 103);
  const retry = await issue(); assert.equal(retry.created, 2); assert.equal(retry.alreadyCompleted, 100);
  assert.equal(retry.generation.targetCount, 102); assert.equal(retry.generation.materializedCount, 102); assert.equal(retry.resumeRequired, false);
  assert.equal((await billRef(103).get()).exists, false);
  assert.equal((await db.collection(`billingBatches/${first.batchId}/targets`).get()).size, 102);
});

run('unauthorized Admin, foreign targets, invalid timezone and changed idempotency terms fail closed', async () => {
  await assert.rejects(issue({}, {auth: {...auth, uid: 'intruder'}}), {code: 'permission-denied'});
  await db.doc('flats/f2').update({communityId: 'OTHER'});
  await assert.rejects(issue({scope: 'units', flatIds: ['f1', 'f2']}), {code: 'permission-denied'});
  await db.doc('communities/C').update({timeZone: 'Invalid/Zone'});
  await assert.rejects(issue(), {code: 'failed-precondition'});
  assert.equal((await db.collection('billingBatches').get()).size, 0);
  await db.doc('communities/C').update({timeZone: 'Asia/Manila'});
  await issue(); await assert.rejects(issue({dueDate: '2030-02-01'}), {code: 'already-exists'});
});

async function seedPagination(last = 101) {
  await seedUnits(3, last);
  const batch = db.batch();
  for (let n = 1; n <= 100; n++) {
    const flatId = `a${String(n).padStart(3, '0')}`;
    batch.set(db.doc(`flats/${flatId}`), {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: `r${n}`});
    batch.delete(db.doc(`flats/f${n}`)); batch.update(db.doc(`users/r${n}`), {flatId});
  }
  await batch.commit();
}

async function replaceOccupant(n) {
  const resident = (await db.doc(`users/r${n}`).get()).data();
  const batch = db.batch();
  batch.set(db.doc(`users/replacement${n}`), {...resident, uid: `replacement${n}`});
  batch.update(db.doc(`users/r${n}`), {isActive: false, status: 'moved_out'});
  batch.update(db.doc(`flats/f${n}`), {residentUserId: `replacement${n}`});
  await batch.commit();
}

run('pagination freezes r101 and retries reconcile replacement without bill, reservation or revision', async () => {
  await seedPagination();
  const first = await issue(); assert.equal(first.created, 100); assert.equal(first.remaining, 1);
  const batchRef = db.doc(`billingBatches/${first.batchId}`);
  const targetRef = batchRef.collection('targets').doc('f101');
  const scope = (await batchRef.get()).data().initialScope;
  const frozen = scope.targets.find(item => item.flatId === 'f101');
  assert.equal(frozen.residentId, 'r101'); assert.equal(frozen.buildingId, 'b');
  assert.equal((await targetRef.get()).exists, false);
  await replaceOccupant(101);
  const resumed = await issue(); assert.equal(resumed.created, 0); assert.equal(resumed.reconciliationRequired, 1);
  const target = (await targetRef.get()).data();
  assert.equal(target.status, 'reconciliation_required'); assert.equal(target.reason, 'occupancy_changed_since_batch_creation');
  assert.deepEqual(target.frozenAssignment, frozen);
  assert.equal((await billRef(101).get()).exists, false);
  assert.equal((await db.doc(`billingAssignments/${billRef(101).id}`).get()).exists, false);
  assert.equal((await billRef(101).collection('revisions').get()).size, 0);
  assert.equal((await issue()).created, 0);
  assert.deepEqual((await batchRef.get()).data().initialScope, scope);
  assert.deepEqual((await batchRef.collection('revisions').doc('revision_1').get()).data().initialScope, scope);
  assert.deepEqual((await targetRef.get()).data().frozenAssignment, frozen);
});

run('occupant replacement after materialization is reconciled before financial writes', async () => {
  const original = db.runTransaction.bind(db); let calls = 0;
  db.runTransaction = async fn => {
    if (++calls === 3) {
      const batches = await db.collection('billingBatches').get();
      const target = (await batches.docs[0].ref.collection('targets').doc('f1').get()).data();
      assert.equal(target.frozenAssignment.residentId, 'r1');
      await replaceOccupant(1);
    }
    return original(fn);
  };
  let result;
  try {result = await issue();} finally {db.runTransaction = original;}
  assert.equal(result.created, 1); assert.equal(result.reconciliationRequired, 1);
  assert.equal(result.conflicts[0].reason, 'occupancy_changed_since_batch_creation');
  assert.equal((await billRef(1).get()).exists, false);
  assert.equal((await db.doc(`billingAssignments/${billRef(1).id}`).get()).exists, false);
  assert.equal((await billRef(1).collection('revisions').get()).size, 0);
});

run('initially vacant, missing, ambiguous and inactive assignments remain excluded after pagination', async () => {
  await seedPagination(104);
  await Promise.all([
    db.doc('flats/f101').update({status: 'vacant', residentUserId: null}),
    db.doc('flats/f102').update({residentUserId: null}),
    db.doc('flats/f103').update({residentUid: 'other'}),
    db.doc('users/r104').update({isActive: false}),
  ]);
  const first = await issue(); assert.equal(first.created, 100);
  const batchRef = db.doc(`billingBatches/${first.batchId}`);
  const scope = (await batchRef.get()).data().initialScope;
  await seedUnits(101, 104);
  const resumed = await issue(); assert.equal(resumed.created, 0); assert.equal(resumed.skipped, 4);
  const reasons = ['unit_not_eligible', 'missing_occupant', 'ambiguous_occupant', 'resident_not_eligible'];
  for (let n = 101; n <= 104; n++) {
    const target = (await batchRef.collection('targets').doc(`f${n}`).get()).data();
    assert.equal(target.status, 'skipped'); assert.equal(target.reason, reasons[n - 101]);
    assert.deepEqual(target.frozenAssignment, scope.targets.find(item => item.flatId === `f${n}`));
    assert.equal((await billRef(n).get()).exists, false);
  }
  assert.equal((await issue()).created, 0);
  assert.deepEqual((await batchRef.get()).data().initialScope, scope);
});

run('cosmetic name and unit-label changes do not conflict with the frozen assignment', async () => {
  const original = db.runTransaction.bind(db); let calls = 0;
  db.runTransaction = async fn => {
    if (++calls === 3) await Promise.all([
      db.doc('users/r1').update({name: 'Updated Resident'}), db.doc('flats/f1').update({flatLabel: 'Updated Label'}),
    ]);
    return original(fn);
  };
  let result;
  try {result = await issue();} finally {db.runTransaction = original;}
  assert.equal(result.created, 2); assert.equal(result.reconciliationRequired, 0);
  const bill = (await billRef(1).get()).data();
  assert.equal(bill.residentId, 'r1'); assert.equal(bill.residentName, 'Updated Resident'); assert.equal(bill.flatLabel, 'Updated Label');
});
