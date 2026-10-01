const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {Timestamp} = require('firebase-admin/firestore');
const {sosStore} = require('./helpers/sos_store');
const {
  createBillingScheduleV2Core: createSchedule,
  reviseBillingScheduleV2Core: reviseSchedule,
  reserveBillingSchedulePeriodV2Core: reservePeriod,
  executeBillingSchedulePeriodV2Core: executePeriod,
  pauseBillingScheduleV2Core: pauseSchedule,
  stopBillingScheduleV2Core: stopSchedule,
  scheduleBatchIdempotencyKey,
} = require('../src/billing_schedule');
const {resolveBillingReconciliationV2Core: resolveReconciliation} = require('../src/billing_reconciliation');
const {createMonthlyBillingBatchV2Core: createBatch, monthlyBillingBatchId} = require('../src/billing_batch');
const {operationalBillingSystemAuthority, SYSTEM_BILLING_ACTOR_ID} = require('../src/resident_identity');

const auth = {uid: 'admin-1', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const onHonolulu = value => Date.parse(`${value}-10:00`);
const reserveNow = () => onHonolulu('2030-02-05T12:00:00');
const executeAfterDue = () => onHonolulu('2030-03-01T12:00:00');
const oldLines = [{lineId: 'maintenance', code: 'maintenance', amountMinor: 12345}];
const newLines = [{lineId: 'water', code: 'water', amountMinor: 67890}];

function fixture({count = 1, scheduleTerms = {}} = {}) {
  const db = sosStore();
  const set = (key, value) => db.values.set(key, value);
  set('admins/admin-1', {uid: 'admin-1', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  set('communities/C', {isActive: true, timeZone: 'Pacific/Honolulu'});
  set('communities/OTHER', {isActive: true, timeZone: 'UTC'});
  set('buildings/b1', {communityId: 'C'});
  for (let n = 1; n <= count; n++) {
    const flatId = `f${n}`;
    const residentId = `r${n}`;
    set(`flats/${flatId}`, {communityId: 'C', buildingId: 'b1', status: 'occupied', residentUserId: residentId,
      flatLabel: `Unit ${n}`});
    set(`users/${residentId}`, {uid: residentId, role: 'resident', isActive: true,
      approvalStatus: 'approved', status: 'active', communityId: 'C', flatId, buildingId: 'b1', name: `Resident ${n}`});
  }
  const data = {
    schemaVersion: 2, communityId: 'C', currency: 'INR', frequency: 'monthly', idempotencyKey: 'schedule-key',
    scope: 'community', generationDay: 5, dueDay: 20, startBillingPeriod: '2030-02',
    endBillingPeriod: null, chargeLines: oldLines, ...scheduleTerms,
  };
  const create = (changes = {}) => createSchedule({db, auth, now: reserveNow, data: {...data, ...changes}});
  const schedulePath = scheduleId => `billingSchedules/${scheduleId}`;
  const generationPath = (scheduleId, period) => `${schedulePath(scheduleId)}/generations/${period}`;
  const revisionPath = (scheduleId, revisionId) => `${schedulePath(scheduleId)}/revisions/${revisionId}`;
  const docs = collection => [...db.values.entries()].filter(([key]) =>
    key.startsWith(`${collection}/`) && key.split('/').length === 2);
  const reserve = (scheduleId, billingPeriod, now = reserveNow, options = {}) => reservePeriod({db, auth, now,
    data: {communityId: 'C', scheduleId, billingPeriod}, ...options});
  const execute = (scheduleId, billingPeriod, now = executeAfterDue, options = {}) => executePeriod({
    db, auth, now, data: {communityId: 'C', scheduleId, billingPeriod}, ...options,
  });
  return {db, set, data, create, reserve, execute, schedulePath, generationPath, revisionPath, docs};
}

async function reserveFebruary(f, changes = {}) {
  const created = await f.create(changes);
  await f.reserve(created.scheduleId, '2030-02');
  return created.scheduleId;
}

async function reviseTerms(f, scheduleId, {now = reserveNow, changes = {}} = {}) {
  return reviseSchedule({db: f.db, auth, now, data: {
    communityId: 'C', scheduleId, expectedRevisionId: 'revision_1', idempotencyKey: 'revision-2',
    scope: 'community', generationDay: 5, dueDay: 20, startBillingPeriod: '2030-02',
    endBillingPeriod: null, chargeLines: newLines, ...changes,
  }});
}

test('executes reserved period from pinned scope, charge lines, due date and deterministic source identity', async () => {
  const f = fixture({scheduleTerms: {scope: 'unit', buildingId: 'b1', flatId: 'f1'}});
  const scheduleId = await reserveFebruary(f);
  const reservationPath = f.generationPath(scheduleId, '2030-02');
  const reservation = f.db.values.get(reservationPath);
  await reviseTerms(f, scheduleId, {now: reserveNow, changes: {
    scope: 'community', generationDay: 7, dueDay: 18, chargeLines: newLines,
  }});

  let invocation;
  const result = await f.execute(scheduleId, '2030-02', executeAfterDue, {
    createBatch: args => {invocation = args; return createBatch(args);},
  });
  const key = scheduleBatchIdempotencyKey(scheduleId, '2030-02');
  const batchId = monthlyBillingBatchId('C', key);
  assert.match(key, /^schedule_v2_[a-f0-9]{64}$/);
  assert.equal(invocation.data.idempotencyKey, key);
  assert.equal(invocation.data.scope, 'unit');
  assert.equal(invocation.data.buildingId, 'b1');
  assert.equal(invocation.data.flatId, 'f1');
  assert.deepEqual(invocation.data.chargeLines, oldLines.map(line => ({...line, label: 'Maintenance'})));
  assert.equal(invocation.data.dueDate, reservation.dueDateKey);
  assert.deepEqual(invocation.source, {scheduleId, scheduleRevisionId: 'revision_1'});
  assert.equal(invocation.dueDateValidationNowMs, reservation.createdAt.toMillis());
  assert.equal(result.status, 'completed');
  assert.equal(result.alreadyCompleted, false);
  assert.equal(result.batchId, batchId);
  const batch = f.db.values.get(`billingBatches/${batchId}`);
  assert.equal(batch.scheduleId, scheduleId);
  assert.equal(batch.scheduleRevisionId, 'revision_1');
  assert.equal(batch.createdAt.toMillis(), executeAfterDue());
  assert.equal(f.docs('bills').length, 1);
  const root = f.db.values.get(f.schedulePath(scheduleId));
  assert.equal(root.generatedThroughBillingPeriod, '2030-02');
  assert.equal(root.generationInProgressBillingPeriod, null);
  assert.equal(root.generationInProgressScheduleRevisionId, null);
});

test('execution is allowed after pause or stop for an already reserved period', async () => {
  for (const transition of [pauseSchedule, stopSchedule]) {
    const f = fixture();
    const scheduleId = await reserveFebruary(f);
    await transition({db: f.db, auth, now: reserveNow,
      data: {communityId: 'C', scheduleId}});
    const result = await f.execute(scheduleId, '2030-02');
    assert.equal(result.status, 'completed');
    assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generatedThroughBillingPeriod, '2030-02');
  }
});

test('trusted system authority reserves and resumes execution through every batch transaction without user auth', async () => {
  const f = fixture({count: 101});
  const {scheduleId} = await f.create(); // Human setup remains the existing Admin flow.
  let authorityCalls = 0;
  const requireSystem = (db, _auth, communityId, transaction) => {
    authorityCalls++;
    return operationalBillingSystemAuthority(db, _auth, communityId, transaction);
  };

  await assert.rejects(reservePeriod({db: f.db, auth: undefined, now: reserveNow, requireAuthority: requireSystem,
    data: {communityId: 'OTHER', scheduleId, billingPeriod: '2030-02'}}), {code: 'permission-denied'});
  assert.equal(f.db.values.has(f.generationPath(scheduleId, '2030-02')), false);

  await f.reserve(scheduleId, '2030-02', reserveNow, {auth: undefined, requireAuthority: requireSystem});
  const generationPath = f.generationPath(scheduleId, '2030-02');
  assert.equal(f.db.values.get(generationPath).createdBy, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(f.db.values.get(generationPath).updatedBy, SYSTEM_BILLING_ACTOR_ID);

  const first = await f.execute(scheduleId, '2030-02', executeAfterDue,
    {auth: undefined, requireAuthority: requireSystem});
  assert.equal(first.resumeRequired, true);
  assert.equal(first.status, 'executing');
  assert.equal(f.db.values.get(generationPath).updatedBy, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generatedThroughBillingPeriod, null);

  const second = await f.execute(scheduleId, '2030-02', executeAfterDue,
    {auth: undefined, requireAuthority: requireSystem});
  assert.equal(second.status, 'completed');
  assert.equal(f.db.values.get(generationPath).createdBy, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(f.db.values.get(generationPath).updatedBy, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).updatedBy, SYSTEM_BILLING_ACTOR_ID);

  const batchId = second.batchId;
  const batch = f.db.values.get(`billingBatches/${batchId}`);
  const batchRevision = f.db.values.get(`billingBatches/${batchId}/revisions/revision_1`);
  assert.equal(batch.createdBy, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(batch.updatedBy, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(batchRevision.createdBy, SYSTEM_BILLING_ACTOR_ID);
  for (const flatId of ['f1', 'f101']) {
    const target = f.db.values.get(`billingBatches/${batchId}/targets/${flatId}`);
    const billId = target.billId;
    const bill = f.db.values.get(`bills/${billId}`);
    const assignment = f.db.values.get(`billingAssignments/${billId}`);
    const billRevision = f.db.values.get(`bills/${billId}/revisions/revision_1`);
    for (const row of [target, bill, assignment, billRevision]) {
      assert.equal(row.createdBy, SYSTEM_BILLING_ACTOR_ID);
      assert.equal(row.updatedBy, SYSTEM_BILLING_ACTOR_ID);
    }
  }
  assert(authorityCalls >= 15, `expected authority rechecks through nested transactions, saw ${authorityCalls}`);
  assert.equal(f.db.values.has(`admins/${SYSTEM_BILLING_ACTOR_ID}`), false);
  assert.equal(f.db.values.has(`users/${SYSTEM_BILLING_ACTOR_ID}`), false);
});

test('client cannot inject batch terms or execute an unreserved period', async () => {
  const f = fixture();
  const created = await f.create();
  for (const extra of [
    {idempotencyKey: 'client'}, {chargeLines: newLines}, {scope: 'unit'}, {amountMinor: 1},
    {dueDate: '2030-02-01'}, {scheduleRevisionId: 'revision_1'}, {systemMode: true},
    {systemActor: 'system:billing-scheduler'}, {bypassAuth: true},
  ]) {
    await assert.rejects(executePeriod({db: f.db, auth, now: executeAfterDue,
      data: {communityId: 'C', scheduleId: created.scheduleId, billingPeriod: '2030-02', ...extra}}), {
      code: 'invalid-argument',
    });
  }
  await assert.rejects(f.execute(created.scheduleId, '2030-02'), {code: 'failed-precondition'});
  assert.deepEqual(f.docs('billingBatches'), []);
  assert.deepEqual(f.docs('bills'), []);
});

test('batch invocation error preserves executing reservation and retry uses the same batch identity', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  let initialId;
  await assert.rejects(f.execute(scheduleId, '2030-02', executeAfterDue, {
    createBatch: async args => {
      const result = await createBatch(args);
      initialId = result.batchId;
      throw new Error('simulated ambiguous callable timeout');
    },
  }), /simulated ambiguous callable timeout/);
  const generation = f.db.values.get(f.generationPath(scheduleId, '2030-02'));
  const root = f.db.values.get(f.schedulePath(scheduleId));
  assert.equal(generation.status, 'executing');
  assert.equal(generation.batchId, initialId);
  assert.equal(root.generationInProgressBillingPeriod, '2030-02');
  assert.equal(root.generatedThroughBillingPeriod, null);
  const retry = await f.execute(scheduleId, '2030-02');
  assert.equal(retry.batchId, initialId);
  assert.equal(retry.status, 'completed');
  assert.equal(f.docs('billingBatches').length, 1);
  assert.equal(f.docs('bills').length, 1);
});

test('resumeRequired persists executing progress and retains the fence until the same batch completes', async () => {
  const f = fixture({count: 101});
  const scheduleId = await reserveFebruary(f);
  const first = await f.execute(scheduleId, '2030-02');
  const generation = f.db.values.get(f.generationPath(scheduleId, '2030-02'));
  const root = f.db.values.get(f.schedulePath(scheduleId));
  assert.equal(first.resumeRequired, true);
  assert.equal(generation.status, 'executing');
  assert.equal(generation.batchId, first.batchId);
  assert.equal(generation.latestBatchProgress.generation.completed, 100);
  assert.equal(root.generationInProgressBillingPeriod, '2030-02');
  assert.equal(root.generatedThroughBillingPeriod, null);
  assert.equal(f.docs('bills').length, 100);

  const retry = await f.execute(scheduleId, '2030-02');
  assert.equal(retry.status, 'completed');
  assert.equal(retry.batchId, first.batchId);
  assert.equal(f.docs('billingBatches').length, 1);
  assert.equal(f.docs('bills').length, 101);
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generatedThroughBillingPeriod, '2030-02');
});

test('unresolved batch failures cannot finalize or advance the schedule', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  const batchId = monthlyBillingBatchId('C', scheduleBatchIdempotencyKey(scheduleId, '2030-02'));
  await assert.rejects(f.execute(scheduleId, '2030-02', executeAfterDue, {
    createBatch: async () => ({batchId, status: 'unresolved', resumeRequired: false, failed: 1}),
  }), {code: 'failed-precondition'});
  const generation = f.db.values.get(f.generationPath(scheduleId, '2030-02'));
  assert.equal(generation.status, 'executing');
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generatedThroughBillingPeriod, null);
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generationInProgressBillingPeriod, '2030-02');
});

test('reconciliation_required is terminal, advances sequencing, and remains stable on retry', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  f.set('bills/legacy-feb', {communityId: 'C', flatId: 'f1', billingPeriod: '2030-02',
    billingKind: 'recurring', status: 'pending'});
  const result = await f.execute(scheduleId, '2030-02');
  const generation = f.db.values.get(f.generationPath(scheduleId, '2030-02'));
  assert.equal(result.status, 'reconciliation_required');
  assert.equal(generation.status, 'reconciliation_required');
  assert.equal(generation.reconciliationRequiredCount, 1);
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generatedThroughBillingPeriod, '2030-02');
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generationInProgressBillingPeriod, null);
  const retry = await f.execute(scheduleId, '2030-02');
  assert.equal(retry.alreadyCompleted, true);
  assert.equal(retry.status, 'reconciliation_required');
  assert.equal(f.docs('billingBatches').length, 1);
  assert.equal(f.docs('bills').length, 1); // The existing liability remains; no duplicate was generated.
});

test('terminal retry survives a later revision and later period reservation without another batch', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  const first = await f.execute(scheduleId, '2030-02');
  await reviseTerms(f, scheduleId, {now: () => onHonolulu('2030-03-05T12:00:00')});
  await f.reserve(scheduleId, '2030-03', () => onHonolulu('2030-03-05T12:00:00'));
  const retry = await f.execute(scheduleId, '2030-02', () => onHonolulu('2030-03-06T12:00:00'));
  assert.equal(retry.alreadyCompleted, true);
  assert.equal(retry.batchId, first.batchId);
  assert.equal(retry.scheduleRevisionId, 'revision_1');
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generationInProgressBillingPeriod, '2030-03');
  assert.equal(f.docs('billingBatches').length, 1);
  assert.equal(f.docs('bills').length, 1);
});

test('schedule-linked reconciliation resolution remains read-before-write safe and finalizes generation counters', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  f.set('bills/legacy-feb', {
    communityId: 'C',
    flatId: 'f1',
    billingPeriod: '2030-02',
    billingKind: 'recurring',
    status: 'pending',
  });

  const executed = await f.execute(scheduleId, '2030-02');
  assert.equal(executed.status, 'reconciliation_required');
  const generationPath = f.generationPath(scheduleId, '2030-02');
  const generationBefore = f.db.values.get(generationPath);
  const scheduleBefore = f.db.values.get(f.schedulePath(scheduleId));
  assert.equal(generationBefore.reconciliationRequiredCount, 1);
  assert.equal(scheduleBefore.generatedThroughBillingPeriod, '2030-02');

  const resolved = await resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f1',
      expectedConflictingBillIds: ['legacy-feb'],
      resolutionType: 'existing_liability_confirmed',
      note: 'Confirmed in schedule execution review.',
    },
  });
  assert.equal(resolved.success, true);
  assert.equal(resolved.status, 'completed');

  const batch = f.db.values.get(`billingBatches/${executed.batchId}`);
  const generationAfter = f.db.values.get(generationPath);
  const scheduleAfter = f.db.values.get(f.schedulePath(scheduleId));
  const resolutionRecords = [...f.db.values.entries()].filter(([key]) =>
    key.startsWith(`billingBatches/${executed.batchId}/reconciliations/`));
  assert.equal(resolutionRecords.length, 1);
  const deterministicResolutionId = resolutionRecords[0][0].split('/').pop();
  const audit = f.db.values.get(`auditLogs/billing_reconciliation_resolve_v2_${deterministicResolutionId}`);

  assert.equal(batch.status, 'completed');
  assert.equal(batch.generation.reconciliationRequired, 0);
  assert.equal(generationAfter.status, 'completed');
  assert.equal(generationAfter.reconciliationRequiredCount, 0);
  assert.equal(generationAfter.latestBatchProgress.status, 'completed');
  assert.equal(generationAfter.latestBatchProgress.generation.reconciliationRequired, 0);
  assert.deepEqual(generationAfter.terminalCounters, batch.generation);
  assert(generationAfter.reconciliationResolvedAt);
  assert.equal(generationAfter.reconciliationResolutionId, deterministicResolutionId);
  assert.equal(scheduleAfter.generatedThroughBillingPeriod, '2030-02');
  assert.equal(scheduleAfter.generationInProgressBillingPeriod, null);
  assert.equal(scheduleAfter.status, 'active');
  assert(audit);
  assert.equal(audit.action, 'billing.reconciliation_resolve');
  assert.equal(audit.targetId, `${executed.batchId}:f1`);
  assert.equal(audit.metadata.resolutionId, deterministicResolutionId);
});

test('reconciliation resolution does not reactivate a stopped schedule', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  await stopSchedule({db: f.db, auth, now: reserveNow,
    data: {communityId: 'C', scheduleId}});
  f.set('bills/legacy-feb', {
    communityId: 'C',
    flatId: 'f1',
    billingPeriod: '2030-02',
    billingKind: 'recurring',
    status: 'pending',
  });
  const executed = await f.execute(scheduleId, '2030-02');
  assert.equal(executed.status, 'reconciliation_required');
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).status, 'stopped');

  await resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f1',
      expectedConflictingBillIds: ['legacy-feb'],
      resolutionType: 'existing_liability_confirmed',
    },
  });
  assert.equal(f.db.values.get(f.schedulePath(scheduleId)).status, 'stopped');
});

test('schedule-linked reconciliation rejects generation scheduleRevisionId mismatch', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  f.set('bills/legacy-feb', {
    communityId: 'C',
    flatId: 'f1',
    billingPeriod: '2030-02',
    billingKind: 'recurring',
    status: 'pending',
  });
  const executed = await f.execute(scheduleId, '2030-02');
  const generationPath = f.generationPath(scheduleId, '2030-02');
  f.set(generationPath, {
    ...f.db.values.get(generationPath),
    scheduleRevisionId: 'tampered-revision',
  });

  await assert.rejects(resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f1',
      expectedConflictingBillIds: ['legacy-feb'],
      resolutionType: 'existing_liability_confirmed',
    },
  }), {code: 'failed-precondition'});
  assert.equal(f.db.values.get(`billingBatches/${executed.batchId}/targets/f1`).status, 'reconciliation_required');
  assert.equal(f.docs('auditLogs').length, 0);
});

test('two-target schedule-linked reconciliation stays partial then becomes fully completed', async () => {
  const f = fixture({count: 2});
  const scheduleId = await reserveFebruary(f);
  f.set('bills/legacy-feb-f1', {
    communityId: 'C',
    flatId: 'f1',
    billingPeriod: '2030-02',
    billingKind: 'recurring',
    status: 'pending',
  });
  f.set('bills/legacy-feb-f2', {
    communityId: 'C',
    flatId: 'f2',
    billingPeriod: '2030-02',
    billingKind: 'recurring',
    status: 'pending',
  });

  const executed = await f.execute(scheduleId, '2030-02');
  assert.equal(executed.status, 'reconciliation_required');
  const generationPath = f.generationPath(scheduleId, '2030-02');

  const first = await resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f1',
      expectedConflictingBillIds: ['legacy-feb-f1'],
      resolutionType: 'existing_liability_confirmed',
    },
  });
  assert.equal(first.status, 'reconciliation_required');

  const batchAfterFirst = f.db.values.get(`billingBatches/${executed.batchId}`);
  const generationAfterFirst = f.db.values.get(generationPath);
  assert.equal(batchAfterFirst.status, 'reconciliation_required');
  assert.equal(batchAfterFirst.generation.reconciliationRequired, 1);
  assert.equal(generationAfterFirst.status, 'reconciliation_required');
  assert.equal(generationAfterFirst.reconciliationRequiredCount, 1);
  assert.deepEqual(generationAfterFirst.terminalCounters, batchAfterFirst.generation);
  assert.equal(generationAfterFirst.latestBatchProgress.status, 'reconciliation_required');

  const second = await resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f2',
      expectedConflictingBillIds: ['legacy-feb-f2'],
      resolutionType: 'existing_liability_confirmed',
    },
  });
  assert.equal(second.status, 'completed');

  const batchAfterSecond = f.db.values.get(`billingBatches/${executed.batchId}`);
  const generationAfterSecond = f.db.values.get(generationPath);
  assert.equal(batchAfterSecond.status, 'completed');
  assert.equal(batchAfterSecond.generation.reconciliationRequired, 0);
  assert.equal(generationAfterSecond.status, 'completed');
  assert.equal(generationAfterSecond.reconciliationRequiredCount, 0);
  assert.deepEqual(generationAfterSecond.terminalCounters, batchAfterSecond.generation);
  assert.equal(generationAfterSecond.latestBatchProgress.status, 'completed');
});

test('schedule-linked idempotent retry leaves batch, generation, and target state unchanged', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  f.set('bills/legacy-feb', {
    communityId: 'C',
    flatId: 'f1',
    billingPeriod: '2030-02',
    billingKind: 'recurring',
    status: 'pending',
  });
  const executed = await f.execute(scheduleId, '2030-02');
  await resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f1',
      expectedConflictingBillIds: ['legacy-feb'],
      resolutionType: 'existing_liability_confirmed',
    },
  });

  const batchPath = `billingBatches/${executed.batchId}`;
  const targetPath = `billingBatches/${executed.batchId}/targets/f1`;
  const generationPath = f.generationPath(scheduleId, '2030-02');
  const batchBeforeRetry = f.db.values.get(batchPath);
  const targetBeforeRetry = f.db.values.get(targetPath);
  const generationBeforeRetry = f.db.values.get(generationPath);

  const retry = await resolveReconciliation({
    db: f.db,
    auth,
    data: {
      communityId: 'C',
      batchId: executed.batchId,
      flatId: 'f1',
      expectedConflictingBillIds: ['legacy-feb'],
      resolutionType: 'existing_liability_confirmed',
    },
  });
  assert.equal(retry.alreadyCompleted, true);
  assert.deepEqual(f.db.values.get(batchPath), batchBeforeRetry);
  assert.deepEqual(f.db.values.get(targetPath), targetBeforeRetry);
  assert.deepEqual(f.db.values.get(generationPath), generationBeforeRetry);
  assert.equal(f.docs('auditLogs').length, 1);
});

test('finalization re-reads persisted batch linkage and refuses altered community, period, or revision', async () => {
  for (const [field, value] of [['communityId', 'OTHER'], ['billingPeriod', '2030-03'],
    ['scheduleRevisionId', 'different-revision']]) {
    const f = fixture();
    const scheduleId = await reserveFebruary(f);
    const batchId = monthlyBillingBatchId('C', scheduleBatchIdempotencyKey(scheduleId, '2030-02'));
    await assert.rejects(f.execute(scheduleId, '2030-02', executeAfterDue, {
      createBatch: async args => {
        const result = await createBatch(args);
        const batchPath = `billingBatches/${result.batchId}`;
        f.set(batchPath, {...f.db.values.get(batchPath), [field]: value});
        return result;
      },
    }), {code: 'failed-precondition'});
    assert.equal(f.db.values.get(f.generationPath(scheduleId, '2030-02')).status, 'executing');
    assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generatedThroughBillingPeriod, null);
    assert.equal(f.db.values.get(f.schedulePath(scheduleId)).generationInProgressBillingPeriod, '2030-02');
    assert.equal(f.db.values.has(`billingBatches/${batchId}`), true);
  }
});

test('generation sequence mismatch fails before invoking the batch engine', async () => {
  const f = fixture();
  const scheduleId = await reserveFebruary(f);
  const rootPath = f.schedulePath(scheduleId);
  f.set(rootPath, {...f.db.values.get(rootPath), generatedThroughBillingPeriod: '2030-02'});
  let invoked = false;
  await assert.rejects(f.execute(scheduleId, '2030-02', executeAfterDue, {
    createBatch: async () => {invoked = true; return {};},
  }), {code: 'failed-precondition'});
  assert.equal(invoked, false);
  assert.equal(f.docs('billingBatches').length, 0);
});

test('executor contains no direct bill, assignment, or financial ledger writes', () => {
  const source = fs.readFileSync(path.join(__dirname, '../src/billing_schedule.js'), 'utf8');
  assert.doesNotMatch(source, /collection\(['"]bills['"]\)/);
  assert.doesNotMatch(source, /collection\(['"]billingAssignments['"]\)/);
  assert.doesNotMatch(source, /paymentTransactions|paymentAllocations|residentCreditEntries|residentFinancialAccounts|paymentSettlementsV2/);
  assert.match(source, /createMonthlyBillingBatchV2Core/);
});

test('execute callable is App Check wrapped and wired to the schedule execution core', () => {
  const source = fs.readFileSync(path.join(__dirname, '../src/index.js'), 'utf8');
  assert.match(source, /exports\.executeBillingSchedulePeriodV2 = appCheckedCallable\(\s*executeBillingSchedulePeriodV2Core,/);
  assert.match(source, /exports\.resolveBillingReconciliationV2 = appCheckedCallable\(\s*resolveBillingReconciliationV2Core,/);
});
