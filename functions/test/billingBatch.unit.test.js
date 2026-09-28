const test = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {sosStore} = require('./helpers/sos_store');
const {createMonthlyBillingBatchV2Core: generate, monthlyBillIdV2,
  validateChargeLines, validateDueDateV2} = require('../src/billing_batch');
const {recurringBillId, createMaintenanceBillsCore} = require('../src/billing_management');

const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const now = () => Date.parse('2030-01-15T20:00:00Z'); // Jan 16 in Manila.
const line = (lineId = 'maintenance-base', code = 'maintenance', amountMinor = 100001, label) =>
  ({lineId, code, amountMinor, ...(label == null ? {} : {label})});
const data = {communityId: 'C', scope: 'community', billingPeriod: '2030-01',
  idempotencyKey: 'issue-january', dueDate: '2030-02-16', chargeLines: [line()]};

function fixture(count = 2) {
  const db = sosStore();
  const set = (path, value) => db.values.set(path, value);
  const patch = (path, value) => set(path, {...db.values.get(path), ...value});
  set('admins/a', {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  set('communities/C', {isActive: true, timeZone: 'Asia/Manila'});
  set('buildings/b', {communityId: 'C'});
  function addUnit(n) {
    set(`flats/f${n}`, {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: `r${n}`, flatLabel: `Unit ${n}`});
    set(`users/r${n}`, {uid: `r${n}`, role: 'resident', isActive: true, approvalStatus: 'approved', status: 'active',
      communityId: 'C', flatId: `f${n}`, buildingId: 'b', name: `Resident ${n}`});
  }
  for (let n = 1; n <= count; n++) addUnit(n);
  const run = (extra = {}, options = {}) => generate({db, auth, data: {...data, ...extra}, now, ...options});
  const docs = collection => [...db.values.entries()].filter(([path]) => path.split('/').length === 2 && path.startsWith(`${collection}/`));
  const bill = n => db.values.get(`bills/${monthlyBillIdV2('C', `f${n}`, data.billingPeriod)}`);
  return {db, set, patch, addUnit, run, docs, bill};
}

test('all standard codes and multiple lines have stable identities and an integer calculated total', () => {
  const codes = ['maintenance', 'water', 'parking', 'service', 'electricity', 'security', 'other'];
  const lines = codes.map((code, i) => line(`line-${i}`, code, i + 1));
  const result = validateChargeLines(lines);
  assert.equal(result.amountMinor, 28);
  assert.deepEqual(result.chargeLines.map(item => item.code), codes);
  assert.deepEqual(result.chargeLines.map(item => item.lineId), lines.map(item => item.lineId));
  assert.deepEqual(validateChargeLines([...lines].reverse()), result);
});

test('custom labels trim/normalize whitespace while line IDs survive future label changes', () => {
  const result = validateChargeLines([line('lift-fund', 'custom', 123, '  Lift   Repair\tFund  ')]);
  assert.deepEqual(result.chargeLines, [{lineId: 'lift-fund', code: 'custom', label: 'Lift Repair Fund', amountMinor: 123}]);
  assert.equal(validateChargeLines([line('lift-fund', 'custom', 200, 'Elevator Fund')]).chargeLines[0].lineId, 'lift-fund');
});

test('custom labels reject case-insensitive and whitespace-normalized duplicates', () => {
  for (const label of ['lift repair fund', ' lift   repair fund ', 'LIFT REPAIR FUND']) {
    assert.throws(() => validateChargeLines([line('a', 'custom', 1, 'Lift Repair Fund'), line('b', 'custom', 1, label)]), {code: 'invalid-argument'});
  }
});

test('custom labels reject every reserved name with case/whitespace variations', () => {
  for (const label of ['Maintenance', ' maintenance ', 'MAINTENANCE', 'Water', 'Parking', 'Service', 'Electricity', 'Security', 'Other']) {
    assert.throws(() => validateChargeLines([line('a', 'custom', 1, label)]), {code: 'invalid-argument'});
  }
});

test('invalid lines, labels, duplicate codes and duplicate/missing line IDs are rejected', () => {
  for (const lines of [[], [null], [line('a', 'unknown')], [line('a', 'custom', 1)],
    [line('a', 'custom', 1, ' ')], [line('a', 'custom', 1, 'x'.repeat(81))],
    [line('a'), line('a', 'water')], [line('a'), line('b')], [{code: 'water', amountMinor: 1}],
    [line('a', 'water', 1, 'Maintenance')], [{...line(), amount: 1}]]) {
    assert.throws(() => validateChargeLines(lines), {code: 'invalid-argument'});
  }
});

test('money accepts exact paise and zero lines; rejects invalid precision, coercion and unsafe totals', () => {
  assert.equal(validateChargeLines([line('a', 'water', 101), line('b', 'parking', 0)]).amountMinor, 101);
  assert.equal(validateChargeLines([line('a', 'water', Number.MAX_SAFE_INTEGER)]).amountMinor, Number.MAX_SAFE_INTEGER);
  for (const value of [-1, 0.1, NaN, Infinity, -Infinity, '100', null, undefined, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => validateChargeLines([line('a', 'water', value === undefined ? 1 : value)].map(item => ({...item, amountMinor: value}))), {code: 'invalid-argument'});
  }
  assert.throws(() => validateChargeLines([line('a', 'water', Number.MAX_SAFE_INTEGER), line('b', 'parking', 1)]), {code: 'invalid-argument'});
  assert.throws(() => validateChargeLines([line('a', 'water', 0)]), {code: 'invalid-argument'});
});

test('monthly identity depends only on community/unit/month and leaves V1 charge-type identity unchanged', () => {
  const id = monthlyBillIdV2('C', 'f1', '2030-01');
  assert.equal(monthlyBillIdV2('C', 'f1', '2030-01', [line('water', 'water')]), id);
  for (const args of [['OTHER', 'f1', '2030-01'], ['C', 'f2', '2030-01'], ['C', 'f1', '2030-02']]) {
    assert.notEqual(monthlyBillIdV2(...args), id);
  }
  const expectedV1 = 'recurring_' + createHash('sha256').update(JSON.stringify(['C', 'f1', 'maintenance', '2030-01'])).digest('hex');
  assert.equal(recurringBillId('C', 'f1', 'maintenance', '2030-01'), expectedV1);
  assert.notEqual(recurringBillId('C', 'f1', 'maintenance', '2030-01'), recurringBillId('C', 'f1', 'water', '2030-01'));
});

test('due date accepts local today and exactly one month, rejects earlier/later dates', () => {
  for (const due of ['2030-01-16', '2030-02-16']) {
    const dates = validateDueDateV2(due, {timeZone: 'Asia/Manila'}, now());
    assert.equal(dates.creationLocalDate, '2030-01-16');
    assert.equal(dates.maxDueDateKey, '2030-02-16');
    assert.equal(dates.dueDate.toDate().toISOString(), `${due === '2030-01-16' ? '2030-01-15' : '2030-02-15'}T16:00:00.000Z`);
  }
  for (const due of ['2030-01-15', '2030-02-17', '2030-02-30', '2030-1-16', 'not-a-date']) {
    assert.throws(() => validateDueDateV2(due, {timeZone: 'Asia/Manila'}, now()), {code: 'invalid-argument'});
  }
});

for (const [start, end] of [['2030-01-31', '2030-02-28'], ['2032-01-31', '2032-02-29'],
  ['2030-09-28', '2030-10-28'], ['2030-12-31', '2031-01-31']]) {
  test(`calendar month clamp ${start} -> ${end}`, () => {
    const millis = Date.parse(`${start}T12:00:00Z`);
    assert.equal(validateDueDateV2(end, {timeZone: 'UTC'}, millis).maxDueDateKey, end);
    const later = new Date(Date.parse(`${end}T00:00:00Z`) + 86400000).toISOString().slice(0, 10);
    assert.throws(() => validateDueDateV2(later, {timeZone: 'UTC'}, millis), {code: 'invalid-argument'});
  });
}

test('missing and invalid trusted community time zones fail closed', () => {
  for (const timeZone of [undefined, '', 'Not/AZone', 42]) {
    assert.throws(() => validateDueDateV2('2030-01-16', {timeZone}, now()), {code: 'failed-precondition'});
  }
});

test('DST and UTC-boundary due dates are independent of the host time zone', () => {
  const prior = process.env.TZ;
  try {
    for (const host of ['UTC', 'Pacific/Honolulu', 'Asia/Tokyo']) {
      process.env.TZ = host;
      const dates = validateDueDateV2('2030-03-11', {timeZone: 'America/New_York'}, Date.parse('2030-03-10T04:30:00Z'));
      assert.equal(dates.creationLocalDate, '2030-03-09');
      assert.equal(dates.dueDate.toDate().toISOString(), '2030-03-11T04:00:00.000Z');
    }
  } finally { if (prior === undefined) delete process.env.TZ; else process.env.TZ = prior; }
});

for (const [scope, extra, count] of [
  ['community', {}, 2], ['building', {buildingId: 'b'}, 2],
  ['unit', {buildingId: 'b', flatId: 'f1'}, 1], ['units', {flatIds: ['f1', 'f1']}, 1],
]) test(`${scope} scope resolves frozen authorized targets`, async () => {
  const f = fixture(); const result = await f.run({scope, ...extra});
  assert.equal(result.created, count); assert.equal(result.generation.targetCount, count);
  assert.equal(result.status, 'completed'); assert.equal(result.resumeRequired, false);
  assert.equal(f.docs('billingAssignments').length, count);
});

test('cross-community, missing and wrong-building selected targets reject without creating a batch', async () => {
  for (const extra of [{scope: 'units', flatIds: ['f1', 'f2']}, {scope: 'unit', buildingId: 'b', flatId: 'f2'},
    {scope: 'units', flatIds: ['missing']}, {scope: 'building', buildingId: 'foreign'}]) {
    const f = fixture(); f.patch('flats/f2', {communityId: 'OTHER'}); f.set('buildings/foreign', {communityId: 'OTHER'});
    await assert.rejects(f.run(extra), {code: 'permission-denied'}); assert.equal(f.docs('billingBatches').length, 0);
  }
});

test('community and building scopes filter foreign units and other buildings', async () => {
  const f = fixture(); f.patch('flats/f2', {communityId: 'OTHER'});
  f.addUnit(3); f.set('buildings/b2', {communityId: 'C'}); f.patch('flats/f3', {buildingId: 'b2'});
  f.patch('users/r3', {buildingId: 'b2'});
  assert.equal((await f.run({scope: 'building', buildingId: 'b'})).created, 1);
  const next = await f.run({idempotencyKey: 'community'});
  assert.equal(next.created, 1); assert.equal(next.reconciliationRequired, 1); assert.equal(next.generation.targetCount, 2);
});

test('generated bill and immutable revisions contain coherent independent terms with no settlement fields', async () => {
  const f = fixture(); const lines = [line(), line('parking', 'parking', 30000), line('lift', 'custom', 125, 'Lift Fund')];
  const first = await f.run({chargeLines: lines});
  const bill = f.bill(1); const batch = f.db.values.get(`billingBatches/${first.batchId}`);
  const batchRevision = f.db.values.get(`billingBatches/${first.batchId}/revisions/revision_1`);
  const billRevision = f.db.values.get(`bills/${monthlyBillIdV2('C', 'f1', data.billingPeriod)}/revisions/revision_1`);
  for (const doc of [bill, batchRevision, billRevision]) {
    assert.equal(doc.schemaVersion, 2); assert.equal(doc.amountMinor, 130126); assert.equal(doc.currency, 'INR');
    assert.deepEqual(doc.chargeLines, validateChargeLines(lines).chargeLines);
  }
  assert.equal(bill.billingBatchId, first.batchId); assert.equal(bill.appliedBatchRevisionId, 'revision_1');
  assert.equal(billRevision.billingBatchId, first.batchId); assert.equal(billRevision.appliedBatchRevisionId, 'revision_1');
  assert.equal(bill.amount, 1301.26); assert.deepEqual(bill.chargeBreakdown, {Maintenance: 1000.01, Parking: 300, 'Lift Fund': 1.25});
  assert.equal(bill.paidAmountMinor, 0); assert.equal(bill.creditAppliedMinor, 0); assert.equal(bill.outstandingAmountMinor, 130126);
  assert.equal(bill.status, 'pending'); assert.equal(bill.billingKind, 'recurring'); assert.equal(bill.buildingId, 'b');
  assert.equal(bill.residentId, 'r1'); assert.equal(bill.residentName, 'Resident 1'); assert.equal(bill.flatLabel, 'Unit 1');
  assert.equal(batch.createdBy, 'a'); assert.equal(batch.creationLocalDate, '2030-01-16'); assert.equal(batch.currentRevisionId, 'revision_1');
  assert(batch.createdAt); assert(batch.updatedAt); assert(bill.createdAt); assert(bill.updatedAt);
  for (const field of ['paymentId', 'paymentMethod', 'paymentReference', 'paidAt']) assert.equal(Object.hasOwn(bill, field), false);
  const second = await f.run({chargeLines: lines}, {now: () => Date.parse('2030-06-01T00:00:00Z')});
  assert.equal(second.created, 0); assert.equal(second.alreadyCompleted, 2); assert.equal(second.batchId, first.batchId);
  assert.deepEqual(f.bill(1), bill); assert.deepEqual(f.db.values.get(`billingBatches/${first.batchId}/revisions/revision_1`), batchRevision);
  assert.deepEqual(f.db.values.get(`bills/${monthlyBillIdV2('C', 'f1', data.billingPeriod)}/revisions/revision_1`), billRevision);
  assert.equal(f.docs('billingBatches').length, 1); assert.equal(f.docs('bills').length, 2);
  assert.notEqual(f.bill(1).chargeLines, f.bill(2).chargeLines); assert.notEqual(f.bill(1).chargeLines, batch.chargeLines);
  assert.deepEqual(batchRevision.lineApplicability.map(item => item.lineId).sort(), ['lift', 'maintenance-base', 'parking']);
});

test('idempotencyKey rejects changed terms and client totals; scope cannot expand on retry', async () => {
  const f = fixture(); const first = await f.run(); f.addUnit(3);
  for (const change of [{chargeLines: [line('different')]}, {dueDate: '2030-01-20'}, {billingPeriod: '2030-02'}]) {
    await assert.rejects(f.run(change), {code: 'already-exists'});
  }
  await assert.rejects(f.run({amountMinor: 1}), {code: 'invalid-argument'});
  assert.equal((await f.run()).generation.targetCount, 2); assert.equal(f.bill(3), undefined);
  assert.equal(f.db.values.get(`billingBatches/${first.batchId}`).generation.completed, 2);
});

test('overlapping V2 scopes/charge lines reserve only one monthly liability', async () => {
  const f = fixture(); await f.run({scope: 'unit', buildingId: 'b', flatId: 'f1'});
  const first = f.bill(1);
  const second = await f.run({idempotencyKey: 'parking-selected', scope: 'units', flatIds: ['f1'], chargeLines: [line('parking', 'parking', 30000)]});
  assert.equal(second.created, 0); assert.equal(second.reconciliationRequired, 1);
  assert.equal(second.conflicts[0].reason, 'unit_period_already_assigned'); assert.equal(second.status, 'reconciliation_required');
  assert.deepEqual(f.bill(1), first); assert.equal(f.docs('bills').length, 1); assert.equal(f.docs('billingAssignments').length, 1);
});

test('concurrent same-key and overlapping batch calls cannot duplicate bills/revisions/assignments', async () => {
  const f = fixture(); const results = await Promise.all([f.run(), f.run(), f.run({idempotencyKey: 'overlap'})]);
  assert.equal(results.reduce((sum, result) => sum + result.created, 0), 2);
  assert.equal(f.docs('bills').length, 2); assert.equal(f.docs('billingAssignments').length, 2); assert.equal(f.docs('billingBatches').length, 2);
  assert.equal([...f.db.values.keys()].filter(path => /^bills\/[^/]+\/revisions\//.test(path)).length, 2);
});

test('generation failure is durable/reported and retry resumes without touching a completed bill', async () => {
  const f = fixture(); const original = f.db.runTransaction.bind(f.db); let fired = false;
  f.db.runTransaction = fn => original(async transaction => {
    const get = transaction.get;
    transaction.get = async ref => {
      if (!fired && ref.path === 'flats/f2' && f.bill(1)) {fired = true; throw Error('simulated outage');}
      return get(ref);
    };
    return fn(transaction);
  });
  const partial = await f.run(); assert.equal(partial.created, 1); assert.equal(partial.failed, 1);
  assert.equal(partial.resumeRequired, true); assert.equal(partial.generation.failed, 1); assert.equal(partial.unresolved[0].flatId, 'f2');
  const first = f.bill(1); f.db.runTransaction = original;
  const resumed = await f.run(); assert.equal(resumed.created, 1); assert.equal(resumed.alreadyCompleted, 1);
  assert.equal(resumed.failed, 0); assert.equal(resumed.generation.failed, 0); assert.equal(resumed.status, 'completed');
  assert.deepEqual(f.bill(1), first);
});

test('interruption after durable batch creation resumes target materialization and revision 1', async () => {
  const f = fixture(); const original = f.db.runTransaction.bind(f.db); let calls = 0;
  f.db.runTransaction = fn => {if (++calls === 2) throw Error('interrupted'); return original(fn);};
  await assert.rejects(f.run(), /interrupted/); assert.equal(f.docs('billingBatches').length, 1);
  const revision = [...f.db.values.entries()].find(([path]) => path.includes('/revisions/'));
  f.db.runTransaction = original;
  const result = await f.run(); assert.equal(result.created, 2); assert.deepEqual(f.db.values.get(revision[0]), revision[1]);
});

test('more than 100 targets uses bounded resumable materialization and a frozen scope', async () => {
  const f = fixture(103); const first = await f.run();
  assert.equal(first.created, 100); assert.equal(first.generation.materializedCount, 100); assert.equal(first.remaining, 3);
  f.addUnit(104);
  const next = await f.run(); assert.equal(next.created, 3); assert.equal(next.alreadyCompleted, 100);
  assert.equal(next.generation.targetCount, 103); assert.equal(next.generation.materializedCount, 103); assert.equal(next.resumeRequired, false);
  assert.equal(f.bill(104), undefined);
});

test('V1 liability of any charge type/status is reported without modification; ad-hoc remains separate', async () => {
  const f = fixture();
  await createMaintenanceBillsCore({db: f.db, auth, data: {communityId: 'C', scope: 'unit', buildingId: 'b', flatId: 'f1',
    amount: 100, month: 'Jan', year: '2030', dueDate: '2030-01-20', chargeType: 'water'}});
  const v1Id = recurringBillId('C', 'f1', 'water', '2030-01'); f.patch(`bills/${v1Id}`, {status: 'paid', paymentId: 'old'});
  const old = f.db.values.get(`bills/${v1Id}`);
  f.set('bills/ad-hoc', {communityId: 'C', flatId: 'f2', billingPeriod: '2030-01', billingKind: 'ad_hoc'});
  const result = await f.run(); assert.equal(result.created, 1); assert.equal(result.reconciliationRequired, 1);
  assert.deepEqual(result.conflicts[0].billIds, [v1Id]); assert.deepEqual(f.db.values.get(`bills/${v1Id}`), old);
});

test('random-ID legacy period aliases/unknown dates block, different known periods do not', async () => {
  for (const legacy of [{month: 'JANUARY', year: '2030'}, {month: '01', year: 2030}, {month: 'Jan', year: '2030'}, {}]) {
    const f = fixture(1); const old = {communityId: 'C', flatId: 'f1', ...legacy}; f.set('bills/old', old);
    const result = await f.run(); assert.equal(result.reconciliationRequired, 1); assert.deepEqual(f.db.values.get('bills/old'), old);
  }
  const f = fixture(1); f.set('bills/old', {communityId: 'C', flatId: 'f1', billingPeriod: '2029-12'});
  assert.equal((await f.run()).created, 1);
});

test('legacy liability still requires reconciliation after the unit becomes vacant', async () => {
  const f = fixture(1); f.patch('flats/f1', {status: 'vacant', residentUserId: null});
  f.set('bills/old', {communityId: 'C', flatId: 'f1', billingPeriod: '2030-01', status: 'paid'});
  const result = await f.run(); assert.equal(result.reconciliationRequired, 1); assert.equal(result.skipped, 0);
  assert.deepEqual(result.conflicts[0].billIds, ['old']);
});

for (const [label, path, change] of [
  ['inactive resident', 'users/r1', {isActive: false}], ['unapproved resident', 'users/r1', {approvalStatus: 'pending'}],
  ['moved out', 'users/r1', {status: 'moved_out'}], ['foreign resident', 'users/r1', {communityId: 'OTHER'}],
  ['wrong flat', 'users/r1', {flatId: 'f2'}], ['wrong building', 'users/r1', {buildingId: 'other'}],
  ['ambiguous occupant', 'flats/f1', {residentUid: 'r2'}], ['vacant', 'flats/f1', {status: 'vacant'}],
  ['missing occupant', 'flats/f1', {residentUserId: null}], ['foreign building', 'buildings/b', {communityId: 'OTHER'}],
]) test(`${label} yields a durable skipped target`, async () => {
  const f = fixture(1); f.patch(path, change); const result = await f.run();
  assert.equal(result.created, 0); assert.equal(result.skipped, 1); assert.equal(result.resumeRequired, false);
  assert(f.db.values.get(`billingBatches/${result.batchId}/targets/f1`).reason);
});

test('only a verified-phone active operational community Admin can create or resume', async () => {
  for (const [path, change] of [['admins/a', {isActive: false}], ['admins/a', {role: 'superAdmin'}],
    ['admins/a', {authorizedCommunityIds: ['OTHER']}], ['communities/C', {isActive: false}]]) {
    const f = fixture(); await f.run(); f.patch(path, change);
    await assert.rejects(f.run(), error => ['permission-denied', 'failed-precondition'].includes(error.code));
    assert.equal(f.docs('billingBatches').length, 1);
  }
  const f = fixture(); await assert.rejects(f.run({}, {auth: null})); assert.equal(f.docs('billingBatches').length, 0);
});

test('authority and target eligibility are rechecked after initial materialization', async () => {
  const f = fixture(); const original = f.db.runTransaction.bind(f.db); let calls = 0;
  f.db.runTransaction = fn => {
    if (++calls === 3) f.patch('flats/f1', {communityId: 'OTHER'});
    return original(fn);
  };
  const changed = await f.run();
  assert.equal(changed.reconciliationRequired, 1);
  assert.equal(changed.conflicts[0].reason, 'occupancy_changed_since_batch_creation');
  const g = fixture(); const tx = g.db.runTransaction.bind(g.db); calls = 0;
  g.db.runTransaction = fn => {if (++calls === 3) g.patch('admins/a', {isActive: false}); return tx(fn);};
  await assert.rejects(g.run(), {code: 'permission-denied'}); assert.equal(g.docs('bills').length, 0);
});

test('empty community completes without fabricated financial records', async () => {
  const f = fixture(0); const result = await f.run(); assert.equal(result.status, 'completed'); assert.equal(result.created, 0);
  assert.equal(f.docs('billingAssignments').length, 0); assert.equal(f.docs('bills').length, 0);
});

test('new callable uses the existing App Check wrapper', () => {
  const source = require('node:fs').readFileSync(`${__dirname}/../src/index.js`, 'utf8');
  assert.match(source, /exports\.createMonthlyBillingBatchV2 = appCheckedCallable\(\s*createMonthlyBillingBatchV2Core,/);
  assert.match(source, /enforceAppCheck: true/);
});

function paginatedFixture(extra = 1) {
  const f = fixture(100 + extra);
  // Keep f101 beyond the first page even with lexicographic document ordering.
  for (let n = 1; n <= 100; n++) {
    const id = `a${String(n).padStart(3, '0')}`;
    f.set(`flats/${id}`, f.db.values.get(`flats/f${n}`));
    f.db.values.delete(`flats/f${n}`); f.patch(`users/r${n}`, {flatId: id});
  }
  return f;
}

function replaceOccupant(f, n) {
  f.set(`users/replacement${n}`, {...f.db.values.get(`users/r${n}`), uid: `replacement${n}`});
  f.patch(`users/r${n}`, {status: 'moved_out', isActive: false});
  f.patch(`flats/f${n}`, {residentUserId: `replacement${n}`});
}

test('pagination and retries retain r101 assignment and reconcile a replacement without financial writes', async () => {
  const f = paginatedFixture(); const first = await f.run(); assert.equal(first.created, 100);
  const batchPath = `billingBatches/${first.batchId}`;
  const original = f.db.values.get(batchPath).initialScope;
  const frozen = original.targets.find(item => item.flatId === 'f101');
  assert.equal(frozen.residentId, 'r101'); assert.equal(frozen.buildingId, 'b'); assert.equal(frozen.ineligibleReason, null);
  assert.equal(f.db.values.has(`${batchPath}/targets/f101`), false);
  replaceOccupant(f, 101);
  const result = await f.run(); assert.equal(result.created, 0); assert.equal(result.reconciliationRequired, 1);
  const target = f.db.values.get(`${batchPath}/targets/f101`);
  assert.equal(target.status, 'reconciliation_required'); assert.equal(target.reason, 'occupancy_changed_since_batch_creation');
  assert.deepEqual(target.frozenAssignment, frozen); assert.equal(f.bill(101), undefined);
  const billId = monthlyBillIdV2('C', 'f101', data.billingPeriod);
  assert.equal(f.db.values.has(`billingAssignments/${billId}`), false);
  assert.equal(f.db.values.has(`bills/${billId}/revisions/revision_1`), false);
  await f.run(); assert.deepEqual(f.db.values.get(batchPath).initialScope, original);
  assert.deepEqual(f.db.values.get(`${batchPath}/revisions/revision_1`).initialScope, original);
  assert.deepEqual(f.db.values.get(`${batchPath}/targets/f101`).frozenAssignment, frozen);
});

test('replacement after durable materialization cannot inherit the original target liability', async () => {
  const f = fixture(1); const original = f.db.runTransaction.bind(f.db); let calls = 0;
  f.db.runTransaction = fn => {
    if (++calls === 3) {
      const target = [...f.db.values.entries()].find(([path]) => path.endsWith('/targets/f1'))[1];
      assert.equal(target.frozenAssignment.residentId, 'r1'); replaceOccupant(f, 1);
    }
    return original(fn);
  };
  const result = await f.run(); assert.equal(result.reconciliationRequired, 1); assert.equal(result.created, 0);
  assert.equal(result.conflicts[0].reason, 'occupancy_changed_since_batch_creation');
  assert.equal(f.docs('bills').length, 0); assert.equal(f.docs('billingAssignments').length, 0);
});

test('initially vacant, missing, ambiguous, inactive and invalid-building targets stay excluded after repair', async () => {
  const f = paginatedFixture(5);
  f.patch('flats/f101', {status: 'vacant', residentUserId: null});
  f.patch('flats/f102', {residentUserId: null});
  f.patch('flats/f103', {residentUid: 'other'});
  f.patch('users/r104', {isActive: false});
  f.patch('flats/f105', {buildingId: 'missing'});
  const first = await f.run(); assert.equal(first.created, 100);
  const scope = f.db.values.get(`billingBatches/${first.batchId}`).initialScope;
  for (let n = 101; n <= 105; n++) f.addUnit(n);
  const resumed = await f.run(); assert.equal(resumed.created, 0); assert.equal(resumed.skipped, 5);
  const reasons = ['unit_not_eligible', 'missing_occupant', 'ambiguous_occupant', 'resident_not_eligible', 'building_not_eligible'];
  for (let n = 101; n <= 105; n++) {
    const target = f.db.values.get(`billingBatches/${first.batchId}/targets/f${n}`);
    assert.equal(target.reason, reasons[n - 101]); assert.equal(f.bill(n), undefined);
    assert.deepEqual(target.frozenAssignment, scope.targets.find(item => item.flatId === `f${n}`));
  }
  assert.equal((await f.run()).created, 0);
});

test('cosmetic changes and equivalent occupant aliases preserve financial assignment', async () => {
  const f = fixture(1); const original = f.db.runTransaction.bind(f.db); let calls = 0;
  f.db.runTransaction = fn => {
    if (++calls === 3) {
      f.patch('users/r1', {name: 'Updated Name'});
      f.patch('flats/f1', {flatLabel: 'Renamed Unit', residentUserId: null, residentUid: 'r1'});
    }
    return original(fn);
  };
  const result = await f.run(); assert.equal(result.created, 1); assert.equal(result.reconciliationRequired, 0);
  assert.equal(f.bill(1).residentId, 'r1'); assert.equal(f.bill(1).residentName, 'Updated Name');
  assert.equal(f.bill(1).flatLabel, 'Renamed Unit');
});

test('building, vacancy, ambiguous occupant and resident-side reassignment changes reconcile', async () => {
  for (const [path, patch] of [['flats/f1', {buildingId: 'different'}], ['flats/f1', {status: 'vacant'}],
    ['flats/f1', {residentUid: 'conflicting'}], ['users/r1', {flatId: 'other'}]]) {
    const f = fixture(1); const original = f.db.runTransaction.bind(f.db); let calls = 0;
    f.db.runTransaction = fn => {if (++calls === 3) f.patch(path, patch); return original(fn);};
    const result = await f.run(); assert.equal(result.reconciliationRequired, 1);
    assert.equal(result.conflicts[0].reason, 'occupancy_changed_since_batch_creation'); assert.equal(f.bill(1), undefined);
  }
});

test('richer assignment manifest rejects oversized scopes before creating a batch or revision', async () => {
  const f = fixture(200);
  for (let n = 1; n <= 200; n++) f.patch(`flats/f${n}`, {status: 'x'.repeat(4000)});
  await assert.rejects(f.run(), error => error.code === 'invalid-argument' && /Select fewer units/.test(error.message));
  assert.equal(f.docs('billingBatches').length, 0); assert.equal(f.docs('bills').length, 0);
});
