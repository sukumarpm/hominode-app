const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {sosStore} = require('./helpers/sos_store');
const {RegistrationError} = require('../src/register_resident');
const {
  runRecurringBillingV2SchedulerCore,
  firestoreSchedulePage,
  JOB_PATH,
} = require('../src/billing_recurring_scheduler');
const {
  operationalBillingSystemAuthority,
  SYSTEM_BILLING_ACTOR_ID,
} = require('../src/resident_identity');
const {
  createBillingScheduleV2Core,
  reserveBillingSchedulePeriodV2Core,
  executeBillingSchedulePeriodV2Core,
} = require('../src/billing_schedule');

const nowUtc = value => Date.parse(`${value}Z`);
const FEB5 = nowUtc('2030-02-05T12:00:00');
const lines = [{lineId: 'maintenance', code: 'maintenance', amountMinor: 10000}];

function schedule(id, overrides = {}) {
  return {
    id,
    schemaVersion: 2,
    status: 'active',
    communityId: 'C',
    startBillingPeriod: '2030-02',
    endBillingPeriod: null,
    generatedThroughBillingPeriod: null,
    generationInProgressBillingPeriod: null,
    generationDay: 5,
    dueDay: 20,
    ...overrides,
  };
}

function fixture({now = FEB5, rows = [], maxActiveSchedules, maxInProgressSchedules, pageSize} = {}) {
  const db = sosStore();
  db.values.set('communities/C', {isActive: true, timeZone: 'UTC'});
  db.values.set('communities/OTHER', {isActive: true, timeZone: 'Asia/Manila'});
  db.values.set('communities/inactive', {isActive: false, timeZone: 'UTC'});
  for (const row of rows) db.values.set(`billingSchedules/${row.id}`, row.data);
  const events = [];
  const reserveCalls = [];
  const executeCalls = [];
  const listPage = async ({phase, cursor, limit}) => {
    let entries = [...db.values.entries()]
      .filter(([key]) => key.startsWith('billingSchedules/') && key.split('/').length === 2)
      .map(([key, data]) => ({id: key.split('/').pop(), data}))
      .filter(row => phase === 'inProgress' ? row.data.generationInProgressBillingPeriod != null :
        row.data.status === 'active' && row.data.generationInProgressBillingPeriod == null)
      .sort((a, b) => phase === 'inProgress' ?
        String(a.data.generationInProgressBillingPeriod).localeCompare(String(b.data.generationInProgressBillingPeriod)) || a.id.localeCompare(b.id) :
        a.id.localeCompare(b.id));
    if (phase === 'inProgress' && cursor && typeof cursor.scheduleId === 'string') {
      entries = entries.filter(row => String(row.data.generationInProgressBillingPeriod) > String(cursor.billingPeriod) ||
        (String(row.data.generationInProgressBillingPeriod) === String(cursor.billingPeriod) && row.id > cursor.scheduleId));
    } else if (phase === 'active' && typeof cursor === 'string') {
      entries = entries.filter(row => row.id > cursor);
    }
    const docs = entries.slice(0, limit);
    const last = docs.at(-1);
    return {
      rows: docs,
      hasMore: entries.length > limit,
      cursor: phase === 'inProgress' && last ? {
        billingPeriod: last.data.generationInProgressBillingPeriod,
        scheduleId: last.id,
      } : last?.id ?? null,
    };
  };
  const requireAuthority = async (store, auth, communityId, tx) => {
    assert.equal(auth, null);
    events.push(`authority:${communityId}`);
    return operationalBillingSystemAuthority(store, auth, communityId, tx);
  };
  const reserveCore = async input => {
    events.push(`reserve:${input.data.scheduleId}:${input.data.billingPeriod}`);
    reserveCalls.push(input);
    await input.requireAuthority(input.db, input.auth, input.data.communityId);
    return {success: true};
  };
  const executeCore = async input => {
    events.push(`execute:${input.data.scheduleId}:${input.data.billingPeriod}`);
    executeCalls.push(input);
    await input.requireAuthority(input.db, input.auth, input.data.communityId);
    return {status: 'completed', resumeRequired: false};
  };
  const run = options => runRecurringBillingV2SchedulerCore({
    db, now: () => now, requireAuthority, reserveCore, executeCore, listPage,
    logger: {error: (...args) => events.push(`log:${args[0]}`)},
    ...(maxActiveSchedules == null ? {} : {maxActiveSchedules}),
    ...(maxInProgressSchedules == null ? {} : {maxInProgressSchedules}),
    ...(pageSize == null ? {} : {pageSize}),
    ...options,
  });
  return {db, run, events, reserveCalls, executeCalls, listPage, requireAuthority};
}

test('reserved work is executed first, including executing, paused, and stopped schedules', async () => {
  const rows = [
    {id: 'active', data: schedule('active')},
    {id: 'paused', data: schedule('paused', {status: 'paused', generationInProgressBillingPeriod: '2030-01'})},
    {id: 'stopped', data: schedule('stopped', {status: 'stopped', generationInProgressBillingPeriod: '2030-02'})},
    {id: 'executing', data: schedule('executing', {status: 'active', generationInProgressBillingPeriod: '2030-03'})},
  ];
  const f = fixture({rows});
  const summary = await f.run();
  assert.deepEqual(f.executeCalls.slice(0, 3).map(call => call.data.scheduleId), ['paused', 'stopped', 'executing']);
  assert.equal(f.events.some(item => item.startsWith('reserve:')), true);
  assert.equal(f.events.findIndex(item => item.startsWith('execute:')) < f.events.findIndex(item => item.startsWith('reserve:')), true);
  assert.equal(summary.resumed, 3);
  assert.equal(summary.completed, 4);
});

test('resumeRequired is left for a later pass and terminal schedule state is owned by the execution core', async () => {
  const row = {id: 'resume', data: schedule('resume', {
    status: 'stopped', generationInProgressBillingPeriod: '2030-01',
    generatedThroughBillingPeriod: null,
  })};
  const f = fixture({rows: [row]});
  let executions = 0;
  const summary = await f.run({executeCore: async input => {
    executions++;
    assert.equal(input.auth, null);
    await input.requireAuthority(input.db, input.auth, input.data.communityId);
    return {status: 'executing', resumeRequired: true};
  }});
  assert.equal(executions, 1);
  assert.equal(summary.executing, 1);
  assert.equal(f.db.values.get('billingSchedules/resume').generationInProgressBillingPeriod, '2030-01');
  assert.equal(f.db.values.get('billingSchedules/resume').generatedThroughBillingPeriod, null);
});

test('eligible active schedules reserve then execute start period or exactly the next period', async () => {
  for (const row of [
    {id: 'from-start', data: schedule('from-start')},
    {id: 'from-through', data: schedule('from-through', {
      startBillingPeriod: '2030-01', generatedThroughBillingPeriod: '2030-01',
    })},
  ]) {
    const f = fixture({rows: [row]});
    const summary = await f.run();
    assert.equal(f.reserveCalls.length, 1);
    assert.equal(f.reserveCalls[0].data.billingPeriod, '2030-02');
    assert.equal(f.executeCalls[0].data.billingPeriod, '2030-02');
    assert.equal(summary.reserved, 1);
    assert.equal(f.events.indexOf('reserve:' + row.id + ':2030-02') < f.events.indexOf('execute:' + row.id + ':2030-02'), true);
  }
});

test('never skips an old expected period; it reports missed_period and leaves schedule unchanged', async () => {
  const row = {id: 'old', data: schedule('old', {
    startBillingPeriod: '2029-11', generatedThroughBillingPeriod: '2029-11',
  })};
  const f = fixture({rows: [row]});
  const before = {...row.data};
  const summary = await f.run();
  assert.equal(summary.missedPeriod, 1);
  assert.equal(f.reserveCalls.length, 0);
  assert.deepEqual(f.db.values.get('billingSchedules/old'), before);
});

test('generation window boundaries and future periods are classified without financial mutation', async () => {
  const cases = [
    ['before', '2030-02-04T12:00:00', schedule('before'), 'beforeWindow'],
    ['generation', '2030-02-05T12:00:00', schedule('generation'), 'reserved'],
    ['due', '2030-02-20T12:00:00', schedule('due'), 'reserved'],
    ['missed-window', '2030-02-21T12:00:00', schedule('missed-window'), 'missedWindow'],
    ['future', '2030-02-05T12:00:00', schedule('future', {startBillingPeriod: '2030-03'}), 'notDue'],
  ];
  for (const [id, time, data, expected] of cases) {
    const f = fixture({now: nowUtc(time), rows: [{id, data}]});
    const before = {...data};
    const result = await f.run();
    if (expected === 'reserved') {
      assert.equal(result.reserved, 1, id);
      assert.equal(f.reserveCalls[0].data.billingPeriod, '2030-02');
    } else {
      assert.equal(result[expected], 1, id);
      assert.equal(f.reserveCalls.length, 0, id);
      assert.deepEqual(f.db.values.get(`billingSchedules/${id}`), before, id);
    }
  }
});

test('community timezone, not host timezone, controls period and date eligibility', async () => {
  const f = fixture({now: Date.parse('2030-02-04T16:30:00Z'), rows: [
    {id: 'utc', data: schedule('utc', {communityId: 'C'})},
    {id: 'manila', data: schedule('manila', {communityId: 'OTHER'})},
  ]});
  const prior = process.env.TZ;
  try {
    process.env.TZ = 'Pacific/Honolulu';
    const result = await f.run();
    assert.equal(result.reserved, 1);
    assert.equal(result.beforeWindow, 1);
    assert.equal(f.reserveCalls[0].data.scheduleId, 'manila');
  } finally {
    if (prior === undefined) delete process.env.TZ;
    else process.env.TZ = prior;
  }
});

test('inactive or missing community errors are isolated while another community proceeds', async () => {
  const f = fixture({rows: [
    {id: 'inactive', data: schedule('inactive', {communityId: 'inactive'})},
    {id: 'missing', data: schedule('missing', {communityId: 'missing'})},
    {id: 'valid', data: schedule('valid')},
  ]});
  const result = await f.run();
  assert.equal(result.errors.length, 2);
  assert.deepEqual(result.errors.map(error => error.scheduleId).sort(), ['inactive', 'missing']);
  assert.equal(result.reserved, 1);
  assert.equal(f.reserveCalls[0].data.scheduleId, 'valid');
});

test('malformed stored schedule fields are reported instead of silently skipped', async () => {
  const f = fixture({rows: [
    {id: 'bad-day', data: schedule('bad-day', {generationDay: '5'})},
    {id: 'bad-identity', data: schedule('bad-identity', {id: 'different'})},
  ]});
  const result = await f.run();
  assert.equal(result.errors.length, 2);
  assert.equal(f.reserveCalls.length, 0);
});

test('in-progress pagination advances and active cursor wraps after reaching the end', async () => {
  const rows = Array.from({length: 125}, (_, index) => {
    const id = `s${String(index + 1).padStart(3, '0')}`;
    return {id, data: schedule(id, {startBillingPeriod: '2030-03'})};
  });
  const f = fixture({rows, maxActiveSchedules: 50, pageSize: 20});
  const summaries = [await f.run(), await f.run(), await f.run()];
  assert.deepEqual(summaries.map(item => item.scanned), [50, 50, 25]);
  assert.equal(f.db.values.get(JOB_PATH).activeCursorScheduleId, null);
  const fourth = await f.run();
  assert.equal(fourth.scanned, 50);
  assert.equal(f.db.values.get(JOB_PATH).activeCursorScheduleId, 's050');
});

test('in-progress cursor is paged before active work and malformed or deleted cursor state recovers', async () => {
  const rows = [
    ...Array.from({length: 3}, (_, index) => {
      const id = `ip${index + 1}`;
      return {id, data: schedule(id, {generationInProgressBillingPeriod: `2030-0${index + 1}`})};
    }),
    {id: 'a1', data: schedule('a1', {startBillingPeriod: '2030-03'})},
    {id: 'a2', data: schedule('a2', {startBillingPeriod: '2030-03'})},
  ];
  const f = fixture({rows, maxInProgressSchedules: 2, maxActiveSchedules: 1, pageSize: 1});
  const first = await f.run();
  assert.equal(first.resumed, 2);
  assert.equal(f.executeCalls[0].data.scheduleId, 'ip1');
  assert.equal(f.executeCalls[1].data.scheduleId, 'ip2');
  assert.equal(f.db.values.get(JOB_PATH).inProgressCursorScheduleId, 'ip2');
  await f.run();
  assert.equal(f.executeCalls[2].data.scheduleId, 'ip3');

  f.db.values.set(JOB_PATH, {activeCursorScheduleId: 42, inProgressCursorBillingPeriod: {},
    inProgressCursorScheduleId: 'deleted'});
  const recovered = await f.run();
  assert(recovered.scanned > 0);
  assert.equal(f.db.values.get(JOB_PATH).activeCursorScheduleId, 'a1');
});

test('execution receives system authority and no user auth; reservation and execution retry are logically idempotent', async () => {
  const db = sosStore();
  db.values.set('admins/admin', {uid: 'admin', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  db.values.set('communities/C', {isActive: true, timeZone: 'UTC'});
  db.values.set('buildings/b', {communityId: 'C'});
  db.values.set('flats/f', {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: 'r', flatLabel: '1'});
  db.values.set('users/r', {uid: 'r', role: 'resident', isActive: true, approvalStatus: 'approved',
    status: 'active', communityId: 'C', buildingId: 'b', flatId: 'f', name: 'Resident'});
  const auth = {uid: 'admin', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
  const data = {schemaVersion: 2, communityId: 'C', currency: 'INR', frequency: 'monthly',
    idempotencyKey: 'scheduler-integration', scope: 'community', generationDay: 5, dueDay: 20,
    startBillingPeriod: '2030-02', endBillingPeriod: null, chargeLines: lines};
  const created = await createBillingScheduleV2Core({db, auth, now: () => FEB5, data});
  const listPage = async ({phase}) => {
    const rows = [...db.values.entries()].filter(([key]) => key.startsWith('billingSchedules/') && key.split('/').length === 2)
      .map(([key, row]) => ({id: key.split('/').pop(), data: row}));
    const result = rows.filter(row => phase === 'inProgress' ? row.data.generationInProgressBillingPeriod != null :
      row.data.status === 'active' && row.data.generationInProgressBillingPeriod == null);
    return {rows: result, hasMore: false, cursor: result.at(-1)?.id ?? null};
  };
  const run = () => runRecurringBillingV2SchedulerCore({db, now: () => FEB5,
    listPage, logger: {error() {}}});
  await Promise.all([run(), run()]);
  const scheduleRoot = db.values.get(`billingSchedules/${created.scheduleId}`);
  assert.equal(scheduleRoot.generatedThroughBillingPeriod, '2030-02');
  assert.equal(db.values.get(`billingSchedules/${created.scheduleId}/generations/2030-02`).createdBy,
    SYSTEM_BILLING_ACTOR_ID);
  const bills = [...db.values.keys()].filter(key => key.startsWith('bills/') && key.split('/').length === 2);
  const batches = [...db.values.keys()].filter(key => key.startsWith('billingBatches/') && key.split('/').length === 2);
  assert.equal(bills.length, 1);
  assert.equal(batches.length, 1);
  for (const collection of ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries',
    'residentFinancialAccounts', 'paymentSettlementsV2']) {
    assert.equal([...db.values.keys()].filter(key => key.startsWith(`${collection}/`)).length, 0, collection);
  }
  assert.equal(db.values.has(`admins/${SYSTEM_BILLING_ACTOR_ID}`), false);
  assert.equal(db.values.has(`users/${SYSTEM_BILLING_ACTOR_ID}`), false);
});

test('scheduler source uses bounded reads, onSchedule, and never directly writes financial collections', () => {
  const scheduler = fs.readFileSync(path.join(__dirname, '../src/billing_recurring_scheduler.js'), 'utf8');
  const index = fs.readFileSync(path.join(__dirname, '../src/index.js'), 'utf8');
  assert.match(scheduler, /query\.limit\(limit \+ 1\)/);
  assert.match(scheduler, /MAX_ACTIVE_PER_RUN = 100/);
  assert.doesNotMatch(scheduler, /collection\(['"](?:bills|billingAssignments|billingBatches|paymentTransactions|paymentAllocations|residentCreditEntries|residentFinancialAccounts|paymentSettlementsV2)['"]\)\s*\.doc\([^)]*\)\s*\.set/);
  assert.doesNotMatch(scheduler, /collection\(['"](?:bills|billingAssignments|billingBatches|paymentTransactions|paymentAllocations|residentCreditEntries|residentFinancialAccounts|paymentSettlementsV2)['"]\)/);
  assert.match(index, /require\("firebase-functions\/v2\/scheduler"\)/);
  assert.match(index, /exports\.runRecurringBillingV2Scheduler = onSchedule\(/);
  assert.match(index, /schedule: "every 60 minutes"/);
  assert.match(index, /timeZone: "Etc\/UTC"/);
  assert.match(index, /maxInstances: 1/);
  assert.match(index, /concurrency: 1/);
  assert.match(index, /exports\.reserveBillingSchedulePeriodV2 = appCheckedCallable\(\s*reserveBillingSchedulePeriodV2Core,/);
  assert.match(index, /exports\.executeBillingSchedulePeriodV2 = appCheckedCallable\(\s*executeBillingSchedulePeriodV2Core,/);
  assert.doesNotMatch(index, /exports\.(?:systemBilling|bypassBilling|schedulerAuthority)\s*=/);
});
