const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {sosStore} = require('./helpers/sos_store');
const {
  billingScheduleId,
  billingScheduleRevisionId,
  billingScheduleDateKeys,
  isBillingPeriodInSchedule,
  nextBillingPeriod,
  createBillingScheduleV2Core: create,
  reviseBillingScheduleV2Core: revise,
  pauseBillingScheduleV2Core: pause,
  resumeBillingScheduleV2Core: resume,
  stopBillingScheduleV2Core: stop,
} = require('../src/billing_schedule');
const {localBillingPeriodFromMillis} = require('../src/billing_batch');

const auth = {uid: 'admin-1', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const now = () => Date.parse('2030-01-02T03:04:05Z');
const lines = amountMinor => [{lineId: 'base', code: 'maintenance', amountMinor}];
const baseInput = {
  schemaVersion: 2,
  communityId: 'C',
  currency: 'INR',
  frequency: 'monthly',
  idempotencyKey: 'schedule-key-1',
  scope: 'community',
  generationDay: 5,
  dueDay: 20,
  startBillingPeriod: '2030-02',
  endBillingPeriod: null,
  chargeLines: lines(120001),
};

function fixture() {
  const db = sosStore();
  const set = (key, value) => db.values.set(key, value);
  set('admins/admin-1', {uid: 'admin-1', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  set('communities/C', {isActive: true, timeZone: 'Pacific/Honolulu'});
  set('communities/OTHER', {isActive: true, timeZone: 'UTC'});
  set('buildings/b1', {communityId: 'C'});
  set('buildings/b2', {communityId: 'OTHER'});
  set('flats/f1', {communityId: 'C', buildingId: 'b1'});
  set('flats/f2', {communityId: 'C', buildingId: 'b1'});
  set('flats/other-flat', {communityId: 'OTHER', buildingId: 'b2'});
  const runCreate = (extra = {}, options = {}) => create({
    db, auth, now, data: {...baseInput, ...extra}, ...options,
  });
  const createBase = async (extra = {}, options = {}) => runCreate(extra, options);
  const schedulePath = scheduleId => `billingSchedules/${scheduleId}`;
  const revisionPath = (scheduleId, revisionId) => `${schedulePath(scheduleId)}/revisions/${revisionId}`;
  const docs = collection => [...db.values.entries()].filter(([key]) =>
    key.startsWith(`${collection}/`) && key.split('/').length === 2);
  return {db, set, runCreate, createBase, schedulePath, revisionPath, docs};
}

async function createThenBuildRevision(extra = {}) {
  const f = fixture();
  const created = await f.createBase();
  const schedule = f.db.values.get(f.schedulePath(created.scheduleId));
  const data = {
    communityId: 'C',
    scheduleId: created.scheduleId,
    expectedRevisionId: 'revision_1',
    idempotencyKey: 'revision-key-1',
    scope: 'building',
    buildingId: 'b1',
    generationDay: 6,
    dueDay: 22,
    startBillingPeriod: '2030-03',
    endBillingPeriod: null,
    chargeLines: lines(150000),
    reason: '  New future schedule terms  ',
    ...extra,
  };
  return {f, created, schedule, data, run: (changes = {}, options = {}) =>
    revise({db: f.db, auth, now, data: {...data, ...changes}, ...options})};
}

test('creates an active monthly schedule and revision 1 atomically with complete terms', async () => {
  const f = fixture();
  const result = await f.runCreate();
  assert.deepEqual(result, {
    success: true,
    scheduleId: billingScheduleId('C', 'schedule-key-1'),
    revisionId: 'revision_1',
    revisionNo: 1,
    alreadyCompleted: false,
  });
  const schedule = f.db.values.get(f.schedulePath(result.scheduleId));
  const revision = f.db.values.get(f.revisionPath(result.scheduleId, 'revision_1'));
  assert.equal(schedule.status, 'active');
  assert.equal(schedule.id, result.scheduleId);
  assert.equal(schedule.schemaVersion, 2);
  assert.equal(schedule.currency, 'INR');
  assert.equal(schedule.frequency, 'monthly');
  assert.equal(schedule.currentRevisionId, 'revision_1');
  assert.equal(schedule.currentRevisionEffectiveFromBillingPeriod, '2030-02');
  assert.equal(schedule.revisionNo, 1);
  assert.equal(schedule.createdBy, 'admin-1');
  assert.equal(schedule.updatedBy, 'admin-1');
  assert.equal(schedule.generatedThroughBillingPeriod, null);
  assert.deepEqual(revision.chargeLines, [{...baseInput.chargeLines[0], label: 'Maintenance'}]);
  assert.equal(revision.scheduleId, result.scheduleId);
  assert.equal(revision.revisionId, 'revision_1');
  assert.equal(revision.effectiveFromBillingPeriod, '2030-02');
  assert.equal(revision.revisionNo, 1);
  assert.equal(revision.createdBy, 'admin-1');
  assert.equal(revision.createdAt.toMillis(), now());
  assert.equal(schedule.createdAt.toMillis(), now());
  assert.equal(f.docs('billingSchedules').length, 1);
  assert.equal(f.db.values.has('billingSchedules'), false);
});

test('same create key and exact terms retry safely; changed terms conflict', async () => {
  const f = fixture();
  const first = await f.runCreate();
  const retry = await f.runCreate();
  assert.equal(retry.scheduleId, first.scheduleId);
  assert.equal(retry.alreadyCompleted, true);
  assert.equal(f.docs('billingSchedules').length, 1);
  assert.equal(f.db.values.has(f.revisionPath(first.scheduleId, 'revision_1')), true);
  await assert.rejects(f.runCreate({dueDay: 21}), {code: 'already-exists'});
  assert.equal(f.docs('billingSchedules').length, 1);
});

test('cross-community Admin creation is denied', async () => {
  const f = fixture();
  await assert.rejects(f.runCreate({communityId: 'OTHER'}), {code: 'permission-denied'});
  assert.equal(f.docs('billingSchedules').length, 0);
});

test('schema, currency, frequency, and unexpected fields fail closed', async () => {
  const f = fixture();
  for (const changes of [
    {schemaVersion: 1},
    {schemaVersion: '2'},
    {currency: 'USD'},
    {frequency: 'yearly'},
    {status: 'active'},
    {amount: 100},
    {endBillingPeriod: undefined},
  ]) {
    await assert.rejects(f.runCreate(changes), {code: 'invalid-argument'});
  }
  assert.equal(f.docs('billingSchedules').length, 0);
});

test('generationDay and dueDay accept only integers from 1 through 28', async () => {
  const f = fixture();
  for (const generationDay of [0, 29, 1.5, '1']) {
    await assert.rejects(f.runCreate({generationDay}), {code: 'invalid-argument'});
  }
  for (const dueDay of [0, 29, 2.5, '28']) {
    await assert.rejects(f.runCreate({dueDay}), {code: 'invalid-argument'});
  }
  for (const [generationDay, dueDay] of [[20, 19], [28, 1]]) {
    await assert.rejects(f.runCreate({generationDay, dueDay}), {code: 'invalid-argument'});
  }
  for (const [generationDay, dueDay] of [[5, 5], [1, 28]]) {
    const result = await f.runCreate({generationDay, dueDay, idempotencyKey: `valid-days-${generationDay}-${dueDay}`});
    assert(result.scheduleId);
  }
});

test('period bounds reject malformed periods and end before start, while open-ended schedule is accepted', async () => {
  const f = fixture();
  for (const startBillingPeriod of ['2030-00', '2030-13', '2030-2', '2030/02', 203002]) {
    await assert.rejects(f.runCreate({startBillingPeriod}), {code: 'invalid-argument'});
  }
  await assert.rejects(f.runCreate({startBillingPeriod: '2030-06', endBillingPeriod: '2030-05'}), {
    code: 'invalid-argument',
  });
  const result = await f.runCreate({endBillingPeriod: null});
  assert.equal(f.db.values.get(f.schedulePath(result.scheduleId)).endBillingPeriod, null);
});

test('all V2 scope forms follow existing identifier rules and selected units are community-scoped', async () => {
  const f = fixture();
  const cases = [
    [{scope: 'community'}, {scope: 'community', buildingId: null, flatId: null, flatIds: []}],
    [{scope: 'building', buildingId: 'b1'}, {scope: 'building', buildingId: 'b1', flatId: null, flatIds: []}],
    [{scope: 'unit', buildingId: 'b1', flatId: 'f1'}, {scope: 'unit', buildingId: 'b1', flatId: 'f1', flatIds: []}],
    [{scope: 'units', flatIds: ['f2', 'f1', 'f2']}, {scope: 'units', buildingId: null, flatId: null, flatIds: ['f1', 'f2']}],
  ];
  for (const [input, expected] of cases) {
    const result = await f.runCreate({...input, idempotencyKey: `scope-${expected.scope}-${expected.flatId || expected.buildingId || 'all'}`});
    const schedule = f.db.values.get(f.schedulePath(result.scheduleId));
    for (const [key, value] of Object.entries(expected)) assert.deepEqual(schedule[key], value);
  }
  for (const input of [
    {scope: 'building'},
    {scope: 'building', buildingId: 'b2'},
    {scope: 'unit', buildingId: 'b1', flatId: 'other-flat'},
    {scope: 'unit', buildingId: 'b1'},
    {scope: 'units', flatIds: []},
    {scope: 'units', flatIds: ['other-flat']},
    {scope: 'community', buildingId: 'b1'},
    {scope: 'building', buildingId: 'b1', flatId: 'f1'},
  ]) {
    await assert.rejects(f.runCreate({...input, idempotencyKey: `invalid-${Math.random()}`}), {code: /invalid-argument|permission-denied/});
  }
});

test('reuses the V2 billing batch charge-line validator', async () => {
  const f = fixture();
  await assert.rejects(f.runCreate({chargeLines: []}), {code: 'invalid-argument'});
  await assert.rejects(f.runCreate({chargeLines: [{lineId: 'x', code: 'custom', amountMinor: 100}]}), {code: 'invalid-argument'});
  assert.equal(f.docs('billingSchedules').length, 0);
});

test('period applicability and generated date keys are canonical and host-timezone independent', () => {
  const schedule = {startBillingPeriod: '2030-02', endBillingPeriod: '2030-04', generationDay: 5, dueDay: 20};
  const original = process.env.TZ;
  try {
    for (const zone of ['UTC', 'Pacific/Honolulu', 'Asia/Tokyo']) {
      process.env.TZ = zone;
      assert.equal(isBillingPeriodInSchedule(schedule, '2030-01'), false);
      assert.equal(isBillingPeriodInSchedule(schedule, '2030-02'), true);
      assert.equal(isBillingPeriodInSchedule(schedule, '2030-04'), true);
      assert.equal(isBillingPeriodInSchedule(schedule, '2030-05'), false);
      assert.deepEqual(billingScheduleDateKeys(schedule, '2030-03'), {
        generationDateKey: '2030-03-05', dueDateKey: '2030-03-20',
      });
    }
  } finally {
    if (original === undefined) delete process.env.TZ;
    else process.env.TZ = original;
  }
  assert.equal(isBillingPeriodInSchedule({...schedule, endBillingPeriod: null}, '2030-12'), true);
  assert.equal(billingScheduleDateKeys(schedule, '2030-05'), null);
});

test('revision updates future terms once and preserves immutable revision 1', async () => {
  const f = await createThenBuildRevision();
  const originalRevision = f.f.db.values.get(f.f.revisionPath(f.created.scheduleId, 'revision_1'));
  const result = await f.run();
  const schedule = f.f.db.values.get(f.f.schedulePath(f.created.scheduleId));
  const revision = f.f.db.values.get(f.f.revisionPath(f.created.scheduleId, result.revisionId));
  assert.equal(result.revisionNo, 2);
  assert.equal(result.alreadyCompleted, false);
  assert.equal(schedule.currentRevisionId, result.revisionId);
  assert.equal(schedule.revisionNo, 2);
  assert.equal(schedule.generationDay, 6);
  assert.equal(schedule.currency, 'INR');
  assert.equal(schedule.frequency, 'monthly');
  assert.equal(revision.scheduleId, f.created.scheduleId);
  assert.equal(revision.previousRevisionId, 'revision_1');
  assert.equal(revision.reason, 'New future schedule terms');
  assert.equal(revision.effectiveFromBillingPeriod, '2030-03');
  assert.equal(schedule.currentRevisionEffectiveFromBillingPeriod, '2030-03');
  assert.equal(revision.createdBy, 'admin-1');
  assert.equal(revision.createdAt.toMillis(), now());
  assert.deepEqual(f.f.db.values.get(f.f.revisionPath(f.created.scheduleId, 'revision_1')), originalRevision);
  assert.equal(f.f.docs('bills').length, 0);
});

test('revision effective period is max(start, community-local current month, next after generated-through)', async () => {
  const currentNow = () => Date.parse('2030-04-15T12:00:00Z'); // Apr 15 in Honolulu.
  for (const [generatedThroughBillingPeriod, expected] of [
    [null, '2030-04'], ['2030-02', '2030-04'], ['2030-04', '2030-05'],
    ['2030-06', '2030-07'], ['2030-12', '2031-01'],
  ]) {
    const f = await createThenBuildRevision();
    if (generatedThroughBillingPeriod) {
      f.f.set(f.f.schedulePath(f.created.scheduleId), {
        ...f.schedule, generatedThroughBillingPeriod,
      });
    }
    const first = await f.run({startBillingPeriod: '2030-01'}, {now: currentNow});
    const revisionPath = f.f.revisionPath(f.created.scheduleId, first.revisionId);
    assert.equal(f.f.db.values.get(revisionPath).effectiveFromBillingPeriod, expected);
    assert.equal(f.f.db.values.get(f.f.schedulePath(f.created.scheduleId)).currentRevisionEffectiveFromBillingPeriod, expected);
  }
});

test('effective period uses community timezone, stays stable on retries, and rejects an earlier end period', async () => {
  const millis = Date.parse('2030-04-01T05:00:00Z');
  const original = process.env.TZ;
  try {
    for (const hostZone of ['UTC', 'Pacific/Honolulu', 'Asia/Tokyo']) {
      process.env.TZ = hostZone;
      assert.equal(localBillingPeriodFromMillis(millis, {timeZone: 'Pacific/Honolulu'}), '2030-03');
    }
  } finally { if (original === undefined) delete process.env.TZ; else process.env.TZ = original; }
  assert.equal(nextBillingPeriod('2032-02'), '2032-03');
  assert.equal(nextBillingPeriod('2032-12'), '2033-01');

  const f = await createThenBuildRevision();
  const laterNow = () => Date.parse('2030-04-15T12:00:00Z');
  const first = await f.run({startBillingPeriod: '2030-01'}, {now: laterNow});
  const storedEffective = f.f.db.values.get(f.f.revisionPath(f.created.scheduleId, first.revisionId)).effectiveFromBillingPeriod;
  const retry = await f.run({startBillingPeriod: '2030-01'}, {now: () => Date.parse('2030-10-15T12:00:00Z')});
  assert.equal(retry.alreadyCompleted, true);
  assert.equal(f.f.db.values.get(f.f.revisionPath(f.created.scheduleId, first.revisionId)).effectiveFromBillingPeriod, storedEffective);

  const invalid = await createThenBuildRevision();
  await assert.rejects(invalid.run({startBillingPeriod: '2030-01', endBillingPeriod: '2030-03'}, {now: laterNow}), {
    code: 'invalid-argument',
  });
});

test('current root effective-period pointer must match its immutable revision', async () => {
  const createdFixture = fixture();
  const created = await createdFixture.createBase();
  const rootPath = createdFixture.schedulePath(created.scheduleId);
  const root = createdFixture.db.values.get(rootPath);
  createdFixture.set(rootPath, {...root, currentRevisionEffectiveFromBillingPeriod: '2030-03'});
  await assert.rejects(createdFixture.runCreate(), {code: 'failed-precondition'});

  const f = await createThenBuildRevision();
  const stored = f.f.db.values.get(f.f.schedulePath(f.created.scheduleId));
  f.f.set(f.f.schedulePath(f.created.scheduleId), {...stored, currentRevisionEffectiveFromBillingPeriod: '2030-04'});
  await assert.rejects(f.run(), {code: 'failed-precondition'});
});

test('stale expected revision fails and exact retry is safe', async () => {
  const f = await createThenBuildRevision();
  const result = await f.run();
  const retry = await f.run();
  assert.equal(retry.revisionId, result.revisionId);
  assert.equal(retry.revisionNo, 2);
  assert.equal(retry.alreadyCompleted, true);
  await assert.rejects(f.run({expectedRevisionId: 'revision_1', idempotencyKey: 'new-revision'}), {code: 'failed-precondition'});
});

test('changed revision request with the same key conflicts', async () => {
  const f = await createThenBuildRevision();
  await f.run();
  await assert.rejects(f.run({generationDay: 7}), {code: 'already-exists'});
});

test('revision rejects immutable community, currency, and frequency changes', async () => {
  const f = await createThenBuildRevision();
  await assert.rejects(f.run({communityId: 'OTHER'}), {code: 'permission-denied'});
  await assert.rejects(f.run({currency: 'USD'}), {code: 'invalid-argument'});
  await assert.rejects(f.run({frequency: 'yearly'}), {code: 'invalid-argument'});
  assert.equal(f.f.db.values.get(f.f.schedulePath(f.created.scheduleId)).currency, 'INR');
  assert.equal(f.f.db.values.get(f.f.schedulePath(f.created.scheduleId)).frequency, 'monthly');
});

test('revision reason is trimmed and bounded', async () => {
  const f = await createThenBuildRevision();
  await f.run({reason: '   revised amount   '});
  const revision = f.f.db.values.get(f.f.revisionPath(f.created.scheduleId, billingScheduleRevisionId(f.created.scheduleId, 'revision-key-1')));
  assert.equal(revision.reason, 'revised amount');
  const next = await createThenBuildRevision();
  await assert.rejects(next.run({reason: 'x'.repeat(301)}), {code: 'invalid-argument'});
});

test('lifecycle transitions active to paused and paused to active with immutable audit events', async () => {
  const f = fixture();
  const created = await f.createBase();
  const path = f.schedulePath(created.scheduleId);
  const revisionBefore = f.db.values.get(f.revisionPath(created.scheduleId, 'revision_1'));
  const paused = await pause({db: f.db, auth, now, data: {communityId: 'C', scheduleId: created.scheduleId, reason: '  maintenance  '}});
  assert.equal(paused.status, 'paused');
  let schedule = f.db.values.get(path);
  assert.equal(schedule.statusChangedBy, 'admin-1');
  assert.equal(schedule.statusChangedAt.toMillis(), now());
  assert.equal(f.db.values.get(`${path}/lifecycleEvents/transition_1`).reason, 'maintenance');
  const resumed = await resume({db: f.db, auth, now, data: {communityId: 'C', scheduleId: created.scheduleId}});
  assert.equal(resumed.status, 'active');
  schedule = f.db.values.get(path);
  assert.equal(schedule.lifecycleRevision, 2);
  assert.equal(f.db.values.has(`${path}/lifecycleEvents/transition_2`), true);
  assert.deepEqual(f.db.values.get(f.revisionPath(created.scheduleId, 'revision_1')), revisionBefore);
  assert.deepEqual(f.docs('bills'), []);
});

test('active and paused schedules can be stopped; stopped is terminal', async () => {
  for (const startPaused of [false, true]) {
    const f = fixture();
    const created = await f.createBase();
    if (startPaused) await pause({db: f.db, auth, now, data: {communityId: 'C', scheduleId: created.scheduleId}});
    const result = await stop({db: f.db, auth, now, data: {communityId: 'C', scheduleId: created.scheduleId}});
    assert.equal(result.status, 'stopped');
    const schedule = f.db.values.get(f.schedulePath(created.scheduleId));
    assert.equal(schedule.status, 'stopped');
    assert.deepEqual(schedule.chargeLines, [{...baseInput.chargeLines[0], label: 'Maintenance'}]);
    assert.equal(schedule.scope, 'community');
    assert.equal(f.docs('bills').length, 0);
    for (const action of [pause, resume, stop]) {
      await assert.rejects(action({db: f.db, auth, now, data: {communityId: 'C', scheduleId: created.scheduleId}}), {
        code: 'failed-precondition',
      });
    }
  }
});

test('lifecycle cross-community access and unexpected fields are rejected without writes', async () => {
  const f = fixture();
  const created = await f.createBase();
  await assert.rejects(pause({db: f.db, auth, now, data: {communityId: 'OTHER', scheduleId: created.scheduleId}}), {code: 'permission-denied'});
  await assert.rejects(pause({db: f.db, auth, now, data: {communityId: 'C', scheduleId: created.scheduleId, extra: true}}), {code: 'invalid-argument'});
  assert.equal(f.db.values.get(f.schedulePath(created.scheduleId)).status, 'active');
});

test('no schedule operation writes bills or financial ledger documents', async () => {
  const f = await createThenBuildRevision();
  await f.run();
  await pause({db: f.f.db, auth, now, data: {communityId: 'C', scheduleId: f.created.scheduleId}});
  await resume({db: f.f.db, auth, now, data: {communityId: 'C', scheduleId: f.created.scheduleId}});
  await stop({db: f.f.db, auth, now, data: {communityId: 'C', scheduleId: f.created.scheduleId}});
  for (const collection of [
    'bills', 'paymentTransactions', 'paymentAllocations', 'residentCreditEntries',
    'residentFinancialAccounts', 'paymentSettlementsV2',
  ]) assert.equal(f.f.docs(collection).length, 0, collection);
});

test('callable exports use the existing trusted App Check wrapper and V1 batch source stays untouched', () => {
  const indexSource = fs.readFileSync(path.join(__dirname, '../src/index.js'), 'utf8');
  for (const name of ['create', 'revise', 'pause', 'resume', 'stop']) {
    const callable = `${name}BillingScheduleV2`;
    assert.match(indexSource, new RegExp(`exports\\.${callable} = appCheckedCallable\\(`));
  }
  assert.match(indexSource, /exports\.createMonthlyBillingBatchV2 = appCheckedCallable\(\s*createMonthlyBillingBatchV2Core,/);
  const batchSource = fs.readFileSync(path.join(__dirname, '../src/billing_batch.js'), 'utf8');
  assert.match(batchSource, /async function createMonthlyBillingBatchV2Core/);
  assert.match(batchSource, /module\.exports = \{createMonthlyBillingBatchV2Core, monthlyBillIdV2, validateChargeLines,\s*validateDueDateV2, localBillingPeriodFromMillis\}/);
});

test('schedule module has no direct billing or financial writes, deletion, or generated-bill logic', () => {
  const source = fs.readFileSync(path.join(__dirname, '../src/billing_schedule.js'), 'utf8');
  assert.doesNotMatch(source, /paymentTransactions|paymentAllocations|residentCreditEntries|residentFinancialAccounts|paymentSettlementsV2/);
  assert.doesNotMatch(source, /\.delete\s*\(/);
  assert.doesNotMatch(source, /collection\(['"]bills['"]\)/);
});
