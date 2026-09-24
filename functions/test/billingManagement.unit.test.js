const test = require('node:test');
const assert = require('node:assert/strict');
const {sosStore} = require('./helpers/sos_store');
const {createMaintenanceBillsCore: generate, recurringBillId} = require('../src/billing_management');
const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const data = {communityId: 'C', scope: 'community', amount: 100, month: 'January', year: '2030', dueDate: '2030-01-20'};
function fixture() {
  const db = sosStore();
  const set = (path, value) => db.values.set(path, value);
  set('admins/a', {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  set('communities/C', {isActive: true, name: 'Community'});
  set('buildings/b', {communityId: 'C'});
  for (const n of [1, 2]) {
    set(`flats/f${n}`, {communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: `r${n}`});
    set(`users/r${n}`, {uid: `r${n}`, role: 'resident', communityId: 'C', buildingId: 'b', flatId: `f${n}`,
      isActive: true, approvalStatus: 'approved', status: 'active', name: `Resident ${n}`});
  }
  const patch = (path, value) => set(path, {...db.values.get(path), ...value});
  return {db, set, patch, run: extra => generate({db, auth, data: {...data, ...extra}})};
}
test('monthly generation creates one current-occupant bill per unit and retry creates none', async () => {
  const f = fixture(); assert.equal((await f.run()).created, 2);
  const bills = [...f.db.values.entries()].filter(([path]) => path.startsWith('bills/'));
  assert.equal(bills.length, 2); assert.equal(bills[0][1].billingPeriod, '2030-01');
  assert.equal(bills[0][1].residentId, 'r1'); assert.equal(bills[0][1].billingKind, 'recurring');
  const again = await f.run(); assert.equal(again.created, 0); assert.equal(again.existing, 2);
});
test('month aliases, overlapping scopes and selected units share the same identity', async () => {
  const f = fixture(); assert.equal((await f.run({scope: 'units', flatIds: ['f1', 'f1']})).created, 1);
  assert.equal((await f.run({scope: 'unit', buildingId: 'b', flatId: 'f1', month: '01'})).created, 0);
  assert.equal((await f.run({scope: 'building', buildingId: 'b', month: 'jan'})).created, 1);
  assert.equal((await f.run({month: 'JANUARY'})).created, 0);
});
test('partial failure retry resumes without rewriting completed targets', async () => {
  const f = fixture(); const original = f.db.runTransaction.bind(f.db); let calls = 0;
  f.db.runTransaction = fn => {if (++calls === 2) throw Error('simulated interruption'); return original(fn);};
  await assert.rejects(f.run(), /simulated interruption/);
  const first = f.db.values.get(`bills/${recurringBillId('C', 'f1', 'maintenance', '2030-01')}`);
  f.db.runTransaction = original;
  const resumed = await f.run(); assert.equal(resumed.created, 1); assert.equal(resumed.existing, 1);
  assert.deepEqual(f.db.values.get(`bills/${recurringBillId('C', 'f1', 'maintenance', '2030-01')}`), first);
});
for (const [label, path, patch] of [
  ['inactive', 'users/r1', {isActive: false}], ['rejected', 'users/r1', {approvalStatus: 'rejected'}],
  ['unapproved', 'users/r1', {approvalStatus: 'pending'}], ['moved-out', 'users/r1', {status: 'moved_out'}],
  ['foreign resident', 'users/r1', {communityId: 'OTHER'}], ['wrong assignment', 'users/r1', {flatId: 'f2'}],
  ['foreign unit', 'flats/f1', {communityId: 'OTHER'}], ['ambiguous occupant', 'flats/f1', {residentUid: 'r2'}],
  ['vacant unit', 'flats/f1', {status: 'vacant'}], ['missing occupant', 'flats/f1', {residentUserId: null}],
]) test(`${label} excluded`, async () => {
  const f = fixture(); f.patch(path, patch); const result = await f.run(); assert.equal(result.created, 1);
  assert.equal(f.db.values.has(`bills/${recurringBillId('C', 'f1', 'maintenance', '2030-01')}`), false);
});
test('multiple resident records for a unit bill only the canonical current occupant', async () => {
  const f = fixture(); f.set('users/duplicate', {...f.db.values.get('users/r1'), uid: 'duplicate'});
  assert.equal((await f.run()).created, 2);
  assert.equal(f.db.values.get(`bills/${recurringBillId('C', 'f1', 'maintenance', '2030-01')}`).residentId, 'r1');
});
test('new period or charge type creates legitimate separate bills', async () => {
  const f = fixture(); assert.equal((await f.run()).created, 2);
  assert.equal((await f.run({month: 'February'})).created, 2);
  assert.equal((await f.run({chargeType: 'water'})).created, 2);
});
test('changed terms report conflicts and preserve existing paid history', async () => {
  const f = fixture(); await f.run();
  const key = `bills/${recurringBillId('C', 'f1', 'maintenance', '2030-01')}`;
  f.patch(key, {status: 'paid', paymentId: 'original', paidAmount: 100}); const original = f.db.values.get(key);
  const result = await f.run({amount: 200}); assert.equal(result.created, 0); assert.deepEqual(result.conflicts, ['f1', 'f2']);
  assert.deepEqual(f.db.values.get(key), original);
});
test('legacy duplicates are reported unchanged; explicit ad-hoc bills do not consume recurring identity', async () => {
  const f = fixture();
  for (const id of ['old1', 'old2']) f.set(`bills/${id}`, {communityId: 'C', flatId: 'f1', type: 'combined', month: 'Jan', year: '2030', status: 'paid'});
  f.set('bills/manual', {communityId: 'C', flatId: 'f2', type: 'combined', month: 'January', year: '2030', billingKind: 'ad_hoc'});
  const result = await f.run(); assert.equal(result.created, 1); assert.deepEqual(result.legacyMatches, [{flatId: 'f1', billIds: ['old1', 'old2']}]);
  assert.equal(f.db.values.get('bills/old1').status, 'paid'); assert(f.db.values.has('bills/manual'));
});
test('unauthorized Admin and inactive community are denied', async () => {
  for (const [path, patch] of [['admins/a', {authorizedCommunityIds: ['OTHER']}], ['admins/a', {role: 'superAdmin'}], ['communities/C', {isActive: false}]]) {
    const f = fixture(); f.patch(path, patch); await assert.rejects(f.run(), error => ['permission-denied', 'failed-precondition'].includes(error.code));
    assert.equal([...f.db.values.keys()].some(key => key.startsWith('bills/')), false);
  }
});
test('selected cross-community units and invalid periods cannot generate', async () => {
  const f = fixture(); f.patch('flats/f2', {communityId: 'OTHER'});
  await assert.rejects(f.run({scope: 'units', flatIds: ['f1', 'f2']}), {code: 'permission-denied'});
  await assert.rejects(f.run({month: 'made-up'}), {code: 'invalid-argument'});
});
