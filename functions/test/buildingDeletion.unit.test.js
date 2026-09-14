const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {deleteBuildingCore, validateBuildingDeletionCore, classifyDependency} = require('../src/building_deletion');

const auth = {uid: 'admin', token: {phone_number: '+639171100000', firebase: {sign_in_provider: 'phone'}}};
const data = {communityId: 'community', buildingId: 'tower'};
function fixture(count = 3, options = {}) {
  const values = new Map([
    ['admins/admin', {uid: 'admin', role: 'admin', isActive: true, authorizedCommunityIds: ['community']}],
    ['communities/community', {isActive: true}],
    ['buildings/tower', {communityId: 'community', name: 'Tower A', adminId: 'admin'}],
    ...Array.from({length: count}, (_, i) => [`flats/unit-${i}`, {communityId: 'community', buildingId: 'tower',
      flatLabel: ['A-101', 'Villa-03', 'T201'][i % 3], status: 'vacant', floor: 1, flatNumber: i + 1}]),
  ]);
  let seq = 0;
  const snapshot = (path) => ({id: path.split('/').pop(), ref: ref(path), exists: values.has(path), data: () => values.get(path)});
  const ref = (path) => ({path, id: path.split('/').pop(), get: async () => snapshot(path),
    create: async (value) => {assert(!values.has(path)); values.set(path, value);}});
  const query = (name, clauses = [], limit = Infinity) => ({name, clauses, cap: limit,
    where: (k, op, v) => query(name, [...clauses, [k, op, v]], limit), limit: (n) => query(name, clauses, n)});
  const matches = (doc, [key, op, value]) => op === '==' ? doc[key] === value : op === 'in' ? value.includes(doc[key]) :
    op === 'array-contains' ? Array.isArray(doc[key]) && doc[key].includes(value) : Array.isArray(doc[key]) && doc[key].some((v) => value.includes(v));
  const db = {values, writes: [], collection: (name) => ({...query(name), doc: (id) => ref(`${name}/${id || `generated-${++seq}`}`)}),
    async runTransaction(fn) {
      for (let attempt = 0; attempt < 2; attempt++) {
        const writes = [];
        const tx = {get: async (target) => {
          assert.equal(writes.length, 0, 'reads must precede all writes');
          if (target.path) return snapshot(target.path);
          return {docs: [...values.keys()].filter((path) => path.startsWith(`${target.name}/`) &&
            target.clauses.every((clause) => matches(values.get(path), clause))).slice(0, target.cap).map(snapshot)};
        }};
        for (const kind of ['delete', 'update']) tx[kind] = (ref, data) => writes.push({kind, ref, data});
        const result = await fn(tx);
        if (!attempt && options.beforeRetry) {options.beforeRetry(values); continue;}
        if (options.failCommit) throw Error('commit failed');
        assert(writes.length <= 500);
        for (const w of writes) {
          if (w.kind === 'delete') values.delete(w.ref.path);
          else values.set(w.ref.path, {...values.get(w.ref.path), ...w.data});
        }
        db.writes = writes;
        return result;
      }
    }};
  return {db, values, check: () => validateBuildingDeletionCore({db, auth, data}),
    remove: () => deleteBuildingCore({db, auth, data}),
    add: (collection, value, id = 'ref') => values.set(`${collection}/${id}`, {communityId: 'community', ...value})};
}
async function blocked(f, text) {
  const before = structuredClone([...f.values]);
  const preflight = await f.check();
  assert.equal(preflight.canDelete, false);
  if (text) assert.match(preflight.reasons.join(';'), text);
  await assert.rejects(f.remove(), {code: 'failed-precondition'});
  assert.deepEqual([...f.values], before, 'blocked operations make no writes');
}

for (const count of [0, 3, 499]) test(`${count} vacant units delete atomically within 500 writes`, async () => {
  const f = fixture(count);
  assert.equal((await f.check()).canDelete, true);
  assert.equal((await f.remove()).unitCount, count);
  assert.equal(f.values.has('buildings/tower'), false);
  assert.equal([...f.values.keys()].some((k) => k.startsWith('flats/')), false);
  assert.equal(f.db.writes.length, count + 1);
  const audit = [...f.values].find(([k]) => k.startsWith('auditLogs/'))[1];
  assert.equal(audit.actorUid, 'admin');
  assert.equal(audit.metadata.unitCount, count);
  assert.equal(audit.metadata.result, 'deleted');
  assert.equal(audit.buildingSnapshot.units.length, count);
  if (count) assert.deepEqual(audit.buildingSnapshot.units[0], {unitId: 'unit-0', unitLabel: 'A-101'});
});
for (const patch of [{status: 'reserved'}, {status: 'occupied'}, {residentUserId: 'u'}, {residentId: 'r'},
  {residentUid: 'legacy'}, {residentIds: ['u']}, {residentIds: {}}, {residentUserId: {}},
  {reservedOnboardingId: 'onboarding'}, {status: 'unknown'}, {status: null}]) {
  test(`unit cannot be deleted: ${JSON.stringify(patch)}`, async () => {
    const f = fixture(); Object.assign(f.values.get('flats/unit-1'), patch); await blocked(f, /Villa-03/);
  });
}
test('multiple custom labels and total conflicts are returned without resident PII', async () => {
  const f = fixture(20);
  for (let i = 0; i < 20; i++) Object.assign(f.values.get(`flats/unit-${i}`), {status: 'reserved', reservedForName: 'Private Name'});
  const check = await f.check(); assert.equal(check.conflictCount, 20); assert.equal(check.reasons.length, 12);
  assert.match(check.reasons.join(), /A-101/); assert(!JSON.stringify(check).includes('Private Name'));
});
for (const [collection, value] of [
  ['users', {flatId: 'unit-0', status: 'active'}], ['residents', {buildingId: 'tower', status: 'inactive'}],
  ['residentOnboarding', {flatId: 'unit-1', status: 'pending_registration'}],
  ['residentOnboarding', {buildingReference: 'Tower A', status: 'pending_registration'}],
  ['residentAllocations', {unitId: 'unit-1', status: 'active'}],
  ['complaints', {flatId: 'unit-1', status: 'in-progress'}], ['maintenanceRequests', {unitId: 'unit-1', status: 'pending'}],
  ['bills', {flatId: 'unit-1', status: 'overdue'}], ['payments', {flatId: 'unit-1', status: 'pending'}],
  ['parkingSlots', {buildingId: 'tower', status: 'vacant', userId: 'u'}], ['vehicles', {buildingId: 'tower'}],
  ['amenities', {buildingId: 'tower', isActive: true}], ['gates', {buildingId: 'tower', assignedSecurityId: 'u'}],
  ['staff', {buildingId: 'tower'}], ['visitors', {flatId: 'unit-1', status: 'inside'}],
  ['notices', {targetFlats: ['unit-1'], status: 'published'}], ['events', {targetBuildingIds: ['tower']}],
  ['amenityBookings', {unitId: 'unit-1', status: 'confirmed'}], ['parcels', {flatId: 'unit-1', status: 'received'}],
]) test(`${collection} active dependency blocks even vacant units`, async () => {
  const f = fixture(); f.add(collection, value); await blocked(f, new RegExp(collection));
});
test('unused maintenance allowed, active service dependency blocked', async () => {
  const f = fixture(); f.values.get('flats/unit-0').status = 'maintenance';
  assert.equal((await f.check()).canDelete, true);
  f.add('serviceRequests', {flatId: 'unit-0', status: 'open'}); await blocked(f, /serviceRequests/);
});
test('indirect active booking referencing an inactive amenity blocks', async () => {
  const f = fixture(); f.add('amenities', {buildingId: 'tower', isActive: false}, 'pool');
  f.add('bookings', {amenityId: 'pool', status: 'confirmed'}); await blocked(f, /bookings/);
});
test('legacy indirect allocations without community scope still block', async () => {
  const f = fixture(); f.add('parkingSlots', {buildingId: 'tower', status: 'vacant'}, 'slot');
  f.add('vehicles', {slotId: 'slot', communityId: undefined}); await blocked(f, /vehicles/);
});
test('ambiguous departure values and contradictory inactive staff remain unsafe', async () => {
  const f = fixture(); f.add('visitors', {flatId: 'unit-1', status: 'inside', departure: ''});
  f.add('securityStaff', {buildingId: 'tower', isActive: false, status: 'on-duty'});
  await blocked(f, /visitors/);
  assert.match((await f.check()).reasons.join(), /securityStaff/);
});
test('missing community and foreign-community canonical references are not ignored', async () => {
  const f = fixture(); f.add('users', {flatId: 'unit-0', communityId: undefined}); await blocked(f, /users/);
  f.add('users', {flatId: 'unit-0', communityId: 'foreign'}); await blocked(f, /inconsistent community/);
});
test('renamed legacy label-only pending allocation is ambiguous and blocks; unrelated terminal history is not relabelled', async () => {
  const f = fixture(); f.add('residentOnboarding', {buildingReference: 'Old building name', unitReference: 'Old unit name', status: 'pending_registration'});
  await blocked(f, /residentOnboarding/);
  f.values.get('residentOnboarding/ref').status = 'cancelled';
  const history = structuredClone(f.values.get('residentOnboarding/ref'));
  await f.remove(); assert.deepEqual(f.values.get('residentOnboarding/ref'), history);
});
test('history remains readable and existing labels/IDs/timestamps remain intact', async () => {
  const f = fixture();
  f.add('visitors', {flatId: 'unit-0', status: 'departed', createdAt: 'original'});
  f.add('complaints', {unitId: 'unit-1', status: 'resolved', flatLabel: 'Original Name'});
  f.add('users', {previousBuildingId: 'tower', previousFlatId: 'unit-2', occupancyStatus: 'moved_out', isActive: false});
  f.add('bills', {flatId: 'unit-0', status: 'paid'});
  f.add('payments', {flatId: 'unit-0', status: 'completed'});
  f.add('auditLogs', {buildingId: 'tower', summary: 'Original audit'});
  await f.remove();
  assert.equal(f.values.get('visitors/ref').flatId, 'unit-0');
  assert.equal(f.values.get('visitors/ref').flatLabel, 'A-101');
  assert.equal(f.values.get('visitors/ref').createdAt, 'original');
  assert.equal(f.values.get('complaints/ref').flatLabel, 'Original Name');
  assert.equal(f.values.get('users/ref').previousFlatLabel, 'T201');
  assert.equal(f.values.get('users/ref').previousBuildingName, 'Tower A');
  assert.equal(f.values.get('auditLogs/ref').summary, 'Original audit');
});
test('safe parking configuration and admin summaries removed; unrelated entries retained', async () => {
  const f = fixture(); f.add('parkingSlots', {buildingId: 'tower', status: 'vacant', userId: null, vehicleId: ''});
  Object.assign(f.values.get('admins/admin'), {buildingIds: ['tower', 'other'], buildings: [{buildingId: 'tower', buildingName: 'Tower A'}, {buildingId: 'other', buildingName: 'Other'}], buildingNames: ['Tower A', 'Other']});
  await f.remove(); assert(!f.values.has('parkingSlots/ref'));
  assert.deepEqual(f.values.get('admins/admin').buildingIds, ['other']);
  assert.deepEqual(f.values.get('admins/admin').buildingNames, ['Other']);
});
test('499 units plus child cleanup is rejected with no partial changes', async () => {
  const f = fixture(499); f.add('parkingSlots', {buildingId: 'tower', status: 'vacant'}); await blocked(f, /501 writes/);
});
test('more than 499 units rejected with no partial changes', async () => {await blocked(fixture(500), /499 units/);});
test('authorization and selected community fail closed', async () => {
  const f = fixture();
  await assert.rejects(deleteBuildingCore({db: f.db, auth: null, data}), {code: 'unauthenticated'});
  await assert.rejects(deleteBuildingCore({db: f.db, auth, data: {buildingId: 'tower'}}), {code: 'invalid-argument'});
  f.values.get('buildings/tower').communityId = 'other';
  await assert.rejects(f.remove(), {code: 'permission-denied'});
  f.values.get('admins/admin').authorizedCommunityIds = ['other'];
  await assert.rejects(f.remove(), {code: 'permission-denied'});
});
for (const structureType of [undefined, 'villa_cluster', 'row_house_cluster', 'townhouse_cluster', 'mixed', 'other']) {
  test(`${structureType || 'legacy apartment'} uses canonical references after names change`, async () => {
    const f = fixture(); Object.assign(f.values.get('buildings/tower'), {structureType, name: 'Renamed'});
    f.values.get('flats/unit-0').flatLabel = 'Custom Renamed'; f.add('residentOnboarding', {flatId: 'unit-0'});
    await blocked(f, /residentOnboarding/);
  });
}
test('safe preflight cannot authorize stale reserved state', async () => {
  const f = fixture(); assert.equal((await f.check()).canDelete, true);
  f.values.get('flats/unit-0').status = 'reserved'; await blocked(f, /Reserved/);
});
test('transaction retry rechecks an assignment and discards all pending deletes', async () => {
  const f = fixture(3, {beforeRetry: (values) => values.set('users/racer', {communityId: 'community', flatId: 'unit-0', status: 'active'})});
  await assert.rejects(f.remove(), {code: 'failed-precondition'});
  assert(f.values.has('buildings/tower')); assert(f.values.has('flats/unit-2'));
});
test('failed commit leaves every building/unit/history document untouched', async () => {
  const f = fixture(3, {failCommit: true}); const before = [...f.values];
  await assert.rejects(f.remove(), /commit failed/); assert.deepEqual([...f.values], before);
});
test('callables enforce App Check and old client deletion is denied', () => {
  const index = fs.readFileSync(require.resolve('../src/index'), 'utf8');
  for (const callable of ['deleteBuilding', 'validateBuildingDeletion']) assert.match(index, new RegExp(`exports.${callable} = appCheckedCallable`));
  assert.match(index, /enforceAppCheck: true/);
  const rules = fs.readFileSync(`${__dirname}/../../firestore.rules`, 'utf8');
  for (const name of ['buildings', 'flats']) assert.match(rules.slice(rules.indexOf(`match /${name}/`) + 6).split('match /')[0], /allow delete: if false/);
});
test('unknown dependency states and suspended residents fail closed', () => {
  assert.equal(classifyDependency('resident', {status: 'inactive', isActive: false}), 'block');
  assert.equal(classifyDependency('booking', {status: 'mystery'}), 'block');
});
