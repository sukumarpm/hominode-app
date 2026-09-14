const test = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {initializeApp, getApps} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createBuildingCore, reconcileBuildingCore} = require('../src/building_reconciliation');
const {assignResidentOnboardingToFlatCore, cancelResidentOnboardingReservationCore, renameUnitCore, approveResidentRegistrationCore} = require('../src/resident_identity');
const {validateResidentBulkImportCore, importResidentsBulkCore, commitRow, normalizeRow} = require('../src/resident_bulk_import');
const {registerResidentCore} = require('../src/register_resident');
const {residentOnboardingId, importRowId} = require('../src/resident_import_ids');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
let phoneSequence = 8100;
const phoneAuth = (uid, phone) => ({uid, token: {phone_number: phone, firebase: {sign_in_provider: 'phone'}}});
async function fixture(type = 'villa_cluster') {
  if (!getApps().length) initializeApp({projectId: 'demo-hominode'});
  const db = getFirestore();
  const communityId = `units-${randomUUID()}`;
  const uid = `admin-${randomUUID()}`;
  const phone = `+1415555${phoneSequence++}`;
  const auth = phoneAuth(uid, phone);
  await db.collection('admins').doc(uid).set({uid, role: 'admin', isActive: true, authorizedCommunityIds: [communityId]});
  await db.collection('communities').doc(communityId).set({isActive: true, countryCode: 'US'});
  const layout = {communityId, name: 'Homes', floors: 1, flatsPerFloor: 3, totalFlats: 3, flatBhkConfig: {}, structureType: type};
  const call = (core, data) => core({db, auth, data});
  const created = await call(createBuildingCore, layout);
  const buildingId = created.buildingId;
  const query = db.collection('flats').where('buildingId', '==', buildingId);
  const units = (await query.get()).docs.sort((a, b) => a.data().flatNumber - b.data().flatNumber);
  const unit = units[2];
  const label = type === 'apartment_building' ? 'A-101' : 'Villa-Custom';
  await call(renameUnitCore, {communityId, buildingId, flatId: unit.id, newLabel: label});
  const row = {rowNumber: 2, building: 'Homes', unit: label, residentName: 'Test Resident', phoneNumber: phone, residentType: 'owner'};
  const bulkData = (overrides = {}) => ({communityId, importJobId: `job_${randomUUID()}`, rows: [row], ...overrides});
  return {db, auth, communityId, buildingId, query, units, unit, label, layout, row, phone, call, bulkData};
}
async function expectStream(ref, predicate, action) {
  let stop;
  let timer;
  const changed = new Promise((resolve, reject) => {
    timer = setTimeout(() => reject(Error('Expected live stream update')), 15000);
    stop = ref.onSnapshot((snapshot) => {if (predicate(snapshot)) resolve(snapshot);}, reject);
  });
  try {await action(); return await changed;} finally {clearTimeout(timer); stop();}
}
for (const type of ['apartment_building', 'villa_cluster', 'row_house_cluster', 'townhouse_cluster']) {
  test(`${type}: canonical create, reserve, cancel, bulk import, OTP claim and approval`, {skip: !enabled}, async () => {
    const f = await fixture(type);
    const onboardingId = residentOnboardingId(f.communityId, f.phone);
    const onboardingRef = f.db.collection('residentOnboarding').doc(onboardingId);
    await onboardingRef.set({communityId: f.communityId, phoneNumber: f.phone, residentName: 'Pending', residentType: 'owner',
      approvalStatus: 'pending', status: 'pending_registration', claimedByUid: null});
    const assignment = {communityId: f.communityId, buildingId: f.buildingId, flatId: f.unit.id, onboardingId};
    await expectStream(f.unit.ref, (doc) => doc.data().status === 'reserved', () => f.call(assignResidentOnboardingToFlatCore, assignment));
    await expectStream(f.unit.ref, (doc) => doc.data().status === 'vacant', () => f.call(cancelResidentOnboardingReservationCore, assignment));
    const imported = await f.call(importResidentsBulkCore, f.bulkData());
    assert.equal(imported.rows[0].status, 'imported');
    assert.equal((await f.unit.ref.get()).data().reservedOnboardingId, onboardingId);
    const residentUid = `resident-${randomUUID()}`;
    // The imported existing pending onboarding remains eligible for the original claim path.
    await registerResidentCore({db: f.db, auth: phoneAuth(residentUid, f.phone), data: {claimImportedOnboarding: true}});
    const residentRef = f.db.collection('users').doc(residentUid);
    const pending = (await residentRef.get()).data();
    assert.equal(pending.flatId, f.unit.id);
    assert.equal(pending.identityVerified, false);
    assert.equal(pending.approvalStatus, 'pending');
    await expectStream(f.unit.ref, (doc) => doc.data().status === 'occupied', () => f.call(approveResidentRegistrationCore,
      {communityId: f.communityId, buildingId: f.buildingId, flatId: f.unit.id, userId: residentUid, residentType: 'owner'}));
    assert.equal((await residentRef.get()).data().flatId, f.unit.id);
    assert.equal((await f.unit.ref.get()).data().flatLabel, f.label);
    await assert.rejects(f.call(reconcileBuildingCore, {...f.layout, buildingId: f.buildingId,
      totalFlats: 1, floors: 1, flatsPerFloor: 1}), {code: 'failed-precondition'});
    assert.equal((await f.unit.ref.get()).data().residentUserId, residentUid);
    assert.equal((await f.query.get()).size, 3);
  });
}

test('rename uniqueness is case-insensitive within a structure; same label allowed elsewhere', {skip: !enabled}, async () => {
  const f = await fixture();
  await assert.rejects(f.call(renameUnitCore, {communityId: f.communityId, buildingId: f.buildingId, flatId: f.units[1].id, newLabel: 'vIlLa-CuStOm'}), {code: 'already-exists'});
  const second = await f.call(createBuildingCore, {...f.layout, name: 'Other Homes'});
  const secondUnit = (await f.db.collection('flats').where('buildingId', '==', second.buildingId).get()).docs[0];
  await expectStream(secondUnit.ref, (doc) => doc.data().flatLabel === 'Villa-Custom', () => f.call(renameUnitCore,
    {communityId: f.communityId, buildingId: second.buildingId, flatId: secondUnit.id, newLabel: 'Villa-Custom'}));
  assert.equal((await secondUnit.ref.get()).data().unitLabelNormalized, 'villa-custom');
});

test('two simultaneous assignments cannot reserve one canonical unit', {skip: !enabled}, async () => {
  const f = await fixture();
  const ids = [`pending-${randomUUID()}`, `pending-${randomUUID()}`];
  for (const id of ids) await f.db.collection('residentOnboarding').doc(id).set({communityId: f.communityId, residentType: 'owner', approvalStatus: 'pending', status: 'pending_registration'});
  const results = await Promise.allSettled(ids.map((onboardingId) => f.call(assignResidentOnboardingToFlatCore,
    {communityId: f.communityId, buildingId: f.buildingId, flatId: f.unit.id, onboardingId})));
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal((await f.unit.ref.get()).data().status, 'reserved');
});

test('bulk import races manual reservation safely; exactly one allocation wins', {skip: !enabled}, async () => {
  const f = await fixture();
  const onboardingId = `manual-${randomUUID()}`;
  await f.db.collection('residentOnboarding').doc(onboardingId).set({communityId: f.communityId, residentType: 'owner', approvalStatus: 'pending', status: 'pending_registration'});
  const [bulk, manual] = await Promise.allSettled([
    f.call(importResidentsBulkCore, f.bulkData()),
    f.call(assignResidentOnboardingToFlatCore, {communityId: f.communityId, buildingId: f.buildingId, flatId: f.unit.id, onboardingId}),
  ]);
  const imported = bulk.status === 'fulfilled' && bulk.value.rows[0].status === 'imported';
  assert.equal(Number(imported) + Number(manual.status === 'fulfilled'), 1);
  const unit = (await f.unit.ref.get()).data();
  assert.equal(unit.status, 'reserved');
  assert.equal(unit.reservedOnboardingId, imported ? residentOnboardingId(f.communityId, f.phone) : onboardingId);
});

test('stale validated bulk row is rechecked after reservation and after building rename', {skip: !enabled}, async () => {
  const f = await fixture();
  const data = f.bulkData();
  const validation = await f.call(validateResidentBulkImportCore, data);
  const row = {...normalizeRow(f.row, 0, 'US'), ...validation.rows[0], importRowId: importRowId(data.importJobId, 2)};
  await f.call(importResidentsBulkCore, f.bulkData({rows: [{...f.row, phoneNumber: '+14155559990'}]}));
  const result = await commitRow({db: f.db, auth: f.auth, input: data, row});
  assert.equal(result.code, 'unit_reserved');
  assert.equal((await f.db.collection('residentImportRows').doc(row.importRowId).get()).exists, false);
  await f.call(reconcileBuildingCore, {...f.layout, buildingId: f.buildingId, name: 'Current Homes'});
  const renamed = await f.call(validateResidentBulkImportCore, f.bulkData({rows: [{...f.row, building: 'Current Homes', phoneNumber: '+14155559990'}]}));
  assert.equal(renamed.rows[0].flatId, f.unit.id);
  assert.equal(renamed.rows[0].status, 'ready');
});

test('eligible moved-out resident bulk update uses trusted reassignment, with atomic row marker', {skip: !enabled}, async () => {
  const f = await fixture();
  const uid = `moved-${randomUUID()}`;
  const userRef = f.db.collection('users').doc(uid);
  await userRef.set({uid, role: 'resident', communityId: f.communityId, phoneNumber: f.phone, residentType: 'owner', ownershipType: 'owner',
    approvalStatus: 'approved', status: 'inactive', isActive: false, occupancyStatus: 'moved_out', flatId: null, buildingId: null});
  const data = f.bulkData();
  const validation = await f.call(validateResidentBulkImportCore, data);
  assert.equal(validation.rows[0].action, 'reassign');
  const result = await f.call(importResidentsBulkCore, data);
  assert.equal(result.rows[0].status, 'imported');
  const resident = (await userRef.get()).data();
  assert.equal(resident.reassignmentCount, 1);
  assert.equal(resident.flatId, f.unit.id);
  assert.equal(resident.isActive, true);
  assert.equal((await f.unit.ref.get()).data().status, 'occupied');
  const retry = await f.call(importResidentsBulkCore, data);
  assert.equal(retry.rows[0].status, 'already_imported');
  assert.equal((await userRef.get()).data().reassignmentCount, 1);
});

test('bulk cannot bypass tenant verification for moved-out reassignment', {skip: !enabled}, async () => {
  const f = await fixture();
  const uid = `tenant-${randomUUID()}`;
  await f.db.collection('users').doc(uid).set({uid, role: 'resident', communityId: f.communityId, phoneNumber: f.phone,
    residentType: 'tenant', ownershipType: 'tenant', approvalStatus: 'approved', status: 'inactive', isActive: false,
    occupancyStatus: 'moved_out', identityVerified: false, flatId: null, buildingId: null});
  const result = await f.call(importResidentsBulkCore, f.bulkData({rows: [{...f.row, residentType: 'tenant'}]}));
  assert.equal(result.rows[0].code, 'identity_required');
  assert.equal((await f.unit.ref.get()).data().status, 'vacant');
});

test('apartment/cluster conversion round trip preserves document IDs, custom names and resident pointers', {skip: !enabled}, async () => {
  const f = await fixture('apartment_building');
  await f.unit.ref.update({status: 'occupied', residentUserId: 'canonical-resident'});
  const originalIds = f.units.map((doc) => doc.id).sort();
  await f.call(reconcileBuildingCore, {...f.layout, buildingId: f.buildingId, structureType: 'villa_cluster'});
  let unit = (await f.unit.ref.get()).data();
  assert.equal(unit.floor, 0);
  assert.equal(unit.unitIndex, 3);
  assert.equal(unit.flatLabel, f.label);
  await f.call(reconcileBuildingCore, {...f.layout, buildingId: f.buildingId, structureType: 'apartment_building'});
  unit = (await f.unit.ref.get()).data();
  assert.equal(unit.floor, 1);
  assert.equal(unit.flatNumber, 3);
  assert.equal(unit.unitIndex, undefined);
  assert.equal(unit.residentUserId, 'canonical-resident');
  assert.equal(unit.flatLabel, f.label);
  assert.deepEqual((await f.query.get()).docs.map((doc) => doc.id).sort(), originalIds);
});
