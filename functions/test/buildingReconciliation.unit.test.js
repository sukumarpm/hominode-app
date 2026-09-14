const test = require('node:test');
const assert = require('node:assert/strict');
const {validateInput, planReconciliation, reconcileBuildingCore} = require('../src/building_reconciliation');

const auth = {uid: 'admin-a', token: {phone_number: '+639171100000', firebase: {sign_in_provider: 'phone'}}};
const input = (overrides = {}) => ({communityId: 'A', buildingId: 'building-a', name: 'Alpha', floors: 3, flatsPerFloor: 3, totalFlats: 9, flatBhkConfig: {}, ...overrides});
const flats = () => Array.from({length: 9}, (_, index) => ({
  id: `canonical-${index + 1}`,
  data: {id: `canonical-${index + 1}`, communityId: 'A', buildingId: 'building-a', buildingName: 'Alpha',
    floor: Math.floor(index / 3) + 1, flatNumber: index % 3 + 1,
    flatLabel: ['A-101', 'Villa-03', 'T201'][index % 3] + `-${index}`, flatId: `A00${index + 1}`,
    status: 'vacant', type: '3BHK', bhkType: '3BHK', createdAt: 'original-created', updatedAt: 'original-updated',
    customMetadata: {keep: true}, residentUserId: null, residentId: null, reservedOnboardingId: null},
}));

// An atomic store that rejects reads after writes and can discard/retry a transaction.
function fakeDb(units = flats(), options = {}) {
  const values = new Map([
    ['admins/admin-a', {uid: 'admin-a', role: 'admin', isActive: true, authorizedCommunityIds: ['A'],
      buildings: [{buildingId: 'building-a', buildingName: 'Alpha', preserve: true}, {buildingId: 'other', buildingName: 'Other'}],
      buildingIds: ['building-a', 'other'], buildingNames: ['Alpha', 'Other']}],
    ['communities/A', {isActive: true}],
    ['buildings/building-a', {...input(), buildingName: 'Alpha', adminId: 'admin-a', createdAt: 'original', occupied: 99}],
    ...units.map((flat) => [`flats/${flat.id}`, structuredClone(flat.data)]),
  ]);
  let nextId = 0;
  const ref = (path) => ({path, id: path.split('/').pop(), get: async () => snapshot(path)});
  const snapshot = (path) => ({id: path.split('/').pop(), ref: ref(path), exists: values.has(path), data: () => values.get(path)});
  const query = (name, clauses = []) => ({name, clauses,
    where: (key, op, value) => query(name, [...clauses, [key, value]]),
  });
  return {values, collection: (name) => ({...query(name), doc: (id) => ref(`${name}/${id || `new-${++nextId}`}`)}),
    async runTransaction(fn) {
      for (let attempt = 0; attempt < 2; attempt++) {
        const writes = [];
        const tx = {get: async (target) => {
          assert.equal(writes.length, 0, 'all reads must precede writes');
          if (target.path) return snapshot(target.path);
          return {docs: [...values.keys()].filter((path) => path.startsWith(`${target.name}/`) &&
            target.clauses.every(([key, value]) => values.get(path)[key] === value)).map(snapshot)};
        }};
        for (const kind of ['create', 'update', 'delete']) tx[kind] = (ref, data) => writes.push({kind, ref, data});
        const result = await fn(tx);
        if (!attempt && options.beforeRetry) { options.beforeRetry(values); continue; }
        if (options.failCommit) throw Error('simulated commit failure');
        for (const {kind, ref, data} of writes) {
          if (kind === 'delete') values.delete(ref.path);
          else if (kind === 'update') values.set(ref.path, {...values.get(ref.path), ...data});
          else { assert(!values.has(ref.path)); values.set(ref.path, data); }
        }
        return result;
      }
    },
  };
}
const edit = (db, overrides) => reconcileBuildingCore({db, auth, data: input(overrides)});
const snapshotValues = (db) => structuredClone([...db.values]);

test('3x3 -> 4x3 creates only three units and preserves every survivor document and ID', async () => {
  const db = fakeDb();
  const originals = flats();
  db.values.get('flats/canonical-1').status = 'occupied';
  db.values.get('flats/canonical-1').residentUserId = 'resident-1';
  originals[0].data = structuredClone(db.values.get('flats/canonical-1'));
  const result = await edit(db, {floors: 4, totalFlats: 12});
  for (const flat of originals) assert.deepEqual(db.values.get(`flats/${flat.id}`), flat.data);
  const added = [...db.values].filter(([path]) => path.startsWith('flats/new-')).map(([, data]) => data);
  assert.equal(added.length, 3);
  assert.deepEqual(added.map((flat) => [flat.floor, flat.flatNumber]), [[4, 1], [4, 2], [4, 3]]);
  assert.equal(result.totalFlats, 12);
  assert.equal(result.occupied, 1);
  assert.equal(result.vacant, 11);
  assert.equal(result.occupancyRate, 8);
});

test('3x3 -> 3x2 removes precisely the third position on each floor', async () => {
  const db = fakeDb();
  await edit(db, {flatsPerFloor: 2, totalFlats: 6});
  for (const flat of flats()) {
    if (flat.data.flatNumber === 3) assert.equal(db.values.has(`flats/${flat.id}`), false);
    else assert.deepEqual(db.values.get(`flats/${flat.id}`), flat.data);
  }
  const building = db.values.get('buildings/building-a');
  assert.equal(building.totalFlats, 6);
  assert.equal(building.vacant, 6);
  assert.equal(building.occupied, 0);
});

for (const changes of [{status: 'occupied'}, {status: 'reserved'}, {residentUserId: 'u'}, {residentId: 'r'},
  {reservedOnboardingId: 'pending'}, {residentUid: 'legacy'}, {residentIds: ['legacy']},
  {residentUserId: {}}, {status: 'unknown'}]) {
  test(`unsafe removal blocks the entire edit: ${JSON.stringify(changes)}`, async () => {
    const db = fakeDb();
    Object.assign(db.values.get('flats/canonical-3'), changes);
    const before = snapshotValues(db);
    await assert.rejects(edit(db, {name: 'Renamed', flatsPerFloor: 2, totalFlats: 6}),
      (error) => error.code === 'failed-precondition' && error.message.includes('T201-2'));
    assert.deepEqual(snapshotValues(db), before);
  });
}

test('empty links permit removal; maintenance counted separately and occupied alone determines rate', async () => {
  const db = fakeDb();
  Object.assign(db.values.get('flats/canonical-3'), {residentUserId: ' ', residentId: '', reservedOnboardingId: null});
  Object.assign(db.values.get('flats/canonical-1'), {status: 'occupied', residentUserId: 'u'});
  Object.assign(db.values.get('flats/canonical-2'), {status: 'reserved', reservedOnboardingId: 'r'});
  db.values.get('flats/canonical-4').status = 'maintenance';
  const result = await edit(db, {flatsPerFloor: 2, totalFlats: 6});
  assert.deepEqual([result.totalFlats, result.occupied, result.reserved, result.vacant, result.maintenance, result.occupancyRate], [6, 1, 1, 3, 1, 17]);
});

test('rename synchronizes current references and owner summary without touching unit labels/IDs/links', async () => {
  const db = fakeDb();
  db.values.set('users/u', {communityId: 'A', buildingId: 'building-a', buildingName: 'Alpha', flatId: 'canonical-1', flatLabel: 'A-101-0'});
  db.values.set('residentOnboarding/r', {communityId: 'A', buildingId: 'building-a', buildingReference: 'Alpha', unitReference: 'Villa-03-1', flatId: 'canonical-2'});
  db.values.set('users/foreign', {communityId: 'B', buildingId: 'building-a', buildingName: 'Foreign'});
  await edit(db, {name: 'Renamed'});
  for (const flat of flats()) assert.deepEqual(db.values.get(`flats/${flat.id}`), {...flat.data, buildingName: 'Renamed'});
  assert.equal(db.values.get('users/u').buildingName, 'Renamed');
  assert.equal(db.values.get('users/u').flatId, 'canonical-1');
  assert.equal(db.values.get('residentOnboarding/r').buildingReference, 'Renamed');
  assert.equal(db.values.get('residentOnboarding/r').unitReference, 'Villa-03-1');
  assert.equal(db.values.get('users/foreign').buildingName, 'Foreign');
  const admin = db.values.get('admins/admin-a');
  assert.deepEqual(admin.buildingNames, ['Other', 'Renamed']);
  assert.equal(admin.buildings[0].totalFlats, 9);
  assert.equal(admin.buildings[0].preserve, true);
  assert.deepEqual(admin.buildings[1], {buildingId: 'other', buildingName: 'Other'});
});

test('BHK is changed only for explicitly identified documents and new positions', async () => {
  const db = fakeDb();
  await edit(db, {floors: 4, totalFlats: 12, flatBhkConfig: {'doc:canonical-1': '5BHK', 'pos:4:2': '1BHK'}});
  assert.deepEqual(db.values.get('flats/canonical-1'), {...flats()[0].data, type: '5BHK', bhkType: '5BHK'});
  assert.equal(db.values.get('flats/canonical-2').type, '3BHK');
  assert.equal(db.values.get('flats/new-2').type, '1BHK');
});

test('widening does not collide with old/custom generated labels', () => {
  const original = flats();
  original[0].data.flatLabel = 'A010';
  const plan = planReconciliation(input({flatsPerFloor: 4, totalFlats: 12}), original);
  const labels = [...original.map((flat) => flat.data.flatLabel), ...plan.additions.map((flat) => flat.flatLabel)];
  assert.equal(new Set(labels).size, 12);
  assert.deepEqual(plan.additions.map((flat) => [flat.floor, flat.flatNumber]), [[1, 4], [2, 4], [3, 4]]);
});

for (const invalid of [{floor: null}, {flatNumber: 0}, {floor: 1.5}, {floor: 1, flatNumber: 1}, {communityId: 'B'}]) {
  test(`ambiguous physical positions fail closed: ${JSON.stringify(invalid)}`, async () => {
    const db = fakeDb();
    Object.assign(db.values.get('flats/canonical-3'), invalid);
    const before = snapshotValues(db);
    await assert.rejects(edit(db, {}), {code: 'failed-precondition'});
    assert.deepEqual(snapshotValues(db), before);
  });
}

test('stale document/position BHK keys and invalid dimensions are rejected', async () => {
  for (const overrides of [{floors: 0}, {floors: 1.1}, {totalFlats: 10}, {floors: 500, totalFlats: 1500}, {flatBhkConfig: {'doc:canonical-1': 'invalid'}}]) {
    assert.throws(() => validateInput(input(overrides)), {code: 'invalid-argument'});
  }
  for (const key of ['A-101', 'doc:deleted', 'pos:1:1']) {
    const db = fakeDb();
    const before = snapshotValues(db);
    await assert.rejects(edit(db, {flatBhkConfig: {[key]: '1BHK'}}), {code: 'failed-precondition'});
    assert.deepEqual(snapshotValues(db), before);
  }
});

test('authorization and community mismatch fail before mutations', async () => {
  for (const path of ['admins/admin-a', 'communities/A', 'buildings/building-a']) {
    const db = fakeDb();
    const current = db.values.get(path);
    db.values.set(path, {...current, isActive: false, communityId: 'B'});
    const before = snapshotValues(db);
    await assert.rejects(edit(db, {}));
    assert.deepEqual(snapshotValues(db), before);
  }
  await assert.rejects(reconcileBuildingCore({db: fakeDb(), auth: null, data: input()}), {code: 'unauthenticated'});
});

test('write budget includes synchronized references and aborts all changes', async () => {
  const db = fakeDb();
  for (let i = 0; i < 490; i++) db.values.set(`users/${i}`, {communityId: 'A', buildingId: 'building-a'});
  const before = snapshotValues(db);
  await assert.rejects(edit(db, {name: 'Renamed'}), {code: 'resource-exhausted'});
  assert.deepEqual(snapshotValues(db), before);
});

test('failed commit leaves every document intact', async () => {
  const db = fakeDb(flats(), {failCommit: true});
  const before = snapshotValues(db);
  await assert.rejects(edit(db, {floors: 4, totalFlats: 12}), /simulated commit failure/);
  assert.deepEqual(snapshotValues(db), before);
});

test('a retried transaction rechecks a concurrently reserved unit and never deletes it', async () => {
  const db = fakeDb(flats(), {beforeRetry: (values) => {
    values.set('flats/canonical-3', {...values.get('flats/canonical-3'), status: 'reserved', reservedOnboardingId: 'r'});
  }});
  await assert.rejects(edit(db, {flatsPerFloor: 2, totalFlats: 6}), {code: 'failed-precondition'});
  assert.equal(db.values.get('buildings/building-a').flatsPerFloor, 3);
  assert.equal(db.values.get('flats/canonical-3').status, 'reserved');
  assert.equal([...db.values.keys()].filter((path) => path.startsWith('flats/')).length, 9);
});

const {createBuildingCore} = require('../src/building_reconciliation');
const {structureType, unitType} = require('../src/unit_schema');
test('missing housing types default to legacy apartments without mutating data', () => {
  const legacy = {};
  assert.equal(structureType(legacy), 'apartment_building');
  assert.equal(unitType(legacy), 'apartment');
  assert.deepEqual(legacy, {});
});
for (const [housing, type] of [['apartment_building', 'apartment'], ['villa_cluster', 'villa'], ['row_house_cluster', 'row_house'], ['townhouse_cluster', 'townhouse'], ['mixed', 'duplex'], ['other', 'other']]) {
  test(`trusted creation supports ${housing}/${type}`, async () => {
    const db = fakeDb();
    const created = await createBuildingCore({db, auth, data: input({structureType: housing, unitType: type})});
    const building = db.values.get(`buildings/${created.buildingId}`);
    assert.equal(building.structureType, housing);
    const createdUnits = [...db.values.entries()].filter(([path, data]) => path.startsWith('flats/') && data.buildingId === created.buildingId);
    assert.equal(createdUnits.length, 9);
    for (const [path, unit] of createdUnits) {
      assert.equal(unit.id, path.split('/')[1]);
      assert.equal(unit.unitType, type);
      assert.equal(unit.unitLabelNormalized, unit.flatLabel.toLowerCase());
      if (housing !== 'apartment_building') {
        assert.equal(unit.floor, 0);
        assert.equal(unit.unitIndex, unit.flatNumber);
      }
    }
  });
}
for (const housing of ['villa_cluster', 'row_house_cluster', 'townhouse_cluster']) {
  test(`${housing} expansion/reduction preserves stable index, ID and custom label`, async () => {
    const db = fakeDb();
    const result = await createBuildingCore({db, auth, data: input({structureType: housing, totalFlats: 3})});
    const units = [...db.values.entries()].filter(([path, data]) => path.startsWith('flats/') && data.buildingId === result.buildingId);
    units[0][1].flatLabel = 'Custom Home';
    const originals = units.map(([path, data]) => [path, {...data}]);
    const change = {db, auth, data: input({buildingId: result.buildingId, structureType: housing, totalFlats: 5})};
    await reconcileBuildingCore(change);
    for (const [path, unit] of originals) assert.deepEqual(db.values.get(path), unit);
    await reconcileBuildingCore({...change, data: {...change.data, totalFlats: 2}});
    assert.equal(db.values.has(units[2][0]), false);
    assert.equal(db.values.get(units[0][0]).flatLabel, 'Custom Home');
  });
}

test('apartment-to-cluster conversion preserves IDs, labels, links and count', async () => {
  const db = fakeDb();
  db.values.get('flats/canonical-1').residentUserId = 'resident';
  db.values.get('flats/canonical-1').status = 'occupied';
  await edit(db, {structureType: 'villa_cluster'});
  for (let i = 1; i <= 9; i++) {
    const unit = db.values.get(`flats/canonical-${i}`);
    assert.equal(unit.unitIndex, i);
    assert.equal(unit.floor, 0);
    assert.equal(unit.flatLabel, flats()[i - 1].data.flatLabel);
    assert.equal(unit.unitType, 'villa');
  }
  assert.equal(db.values.get('flats/canonical-1').residentUserId, 'resident');
  assert.equal(db.values.get('buildings/building-a').floors, 0);
});

test('type conversion cannot hide a simultaneous unit reduction', async () => {
  const db = fakeDb();
  const before = snapshotValues(db);
  await assert.rejects(edit(db, {structureType: 'villa_cluster', totalFlats: 3}), {code: 'failed-precondition'});
  assert.deepEqual(snapshotValues(db), before);
});
