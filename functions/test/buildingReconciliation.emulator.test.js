const test = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {initializeApp, getApps} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {reconcileBuildingCore} = require('../src/building_reconciliation');
const {assignResidentOnboardingToFlatCore, cancelResidentOnboardingReservationCore,
  approveResidentRegistrationCore, renameUnitCore} = require('../src/resident_identity');
const {residentOnboardingId} = require('../src/resident_import_ids');
const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

async function fixture() {
  if (!getApps().length) initializeApp({projectId: 'demo-hominode'});
  const db = getFirestore();
  const suffix = randomUUID();
  const communityId = `community-${suffix}`;
  const buildingId = `building-${suffix}`;
  const uid = `admin-${suffix}`;
  const auth = {uid, token: {phone_number: '+639171100000', firebase: {sign_in_provider: 'phone'}}};
  const data = {communityId, buildingId, name: 'Alpha', floors: 3, flatsPerFloor: 3, totalFlats: 9, flatBhkConfig: {}};
  const batch = db.batch();
  batch.set(db.collection('admins').doc(uid), {uid, role: 'admin', isActive: true, authorizedCommunityIds: [communityId]});
  batch.set(db.collection('communities').doc(communityId), {isActive: true});
  const buildingRef = db.collection('buildings').doc(buildingId);
  batch.set(buildingRef, {...data, buildingName: 'Alpha', adminId: uid});
  const units = [];
  for (let i = 0; i < 9; i++) {
    const ref = db.collection('flats').doc(`canonical-${suffix}-${i}`);
    const flat = {id: ref.id, buildingId, communityId, buildingName: 'Alpha',
      floor: Math.floor(i / 3) + 1, flatNumber: i % 3 + 1, flatId: `A00${i + 1}`,
      flatLabel: ['A-101', 'Villa-03', 'T201'][i % 3] + `-${i}`, status: 'vacant',
      type: '3BHK', bhkType: '3BHK', createdAt: Timestamp.fromMillis(12345),
      residentUserId: null, residentId: null, reservedOnboardingId: null};
    batch.set(ref, flat);
    units.push({ref, data: flat});
  }
  await batch.commit();
  const query = db.collection('flats').where('buildingId', '==', buildingId);
  return {db, auth, data, units, buildingRef, query, edit: (changes = {}) => reconcileBuildingCore({db, auth, data: {...data, ...changes}})};
}

test('real transaction expansion/reduction preserves IDs and complete survivor documents; stream sees final units', {skip: !enabled}, async () => {
  const f = await fixture();
  const streamResult = new Promise((resolve, reject) => {
    const timer = setTimeout(() => {unsubscribe(); reject(Error('stream did not see 12 units'));}, 30000);
    const unsubscribe = f.query.onSnapshot((snapshot) => {
      if (snapshot.size === 12) {clearTimeout(timer); unsubscribe(); resolve(snapshot);}
    }, reject);
  });
  await f.edit({floors: 4, totalFlats: 12});
  assert.equal((await streamResult).size, 12);
  for (const unit of f.units) assert.deepEqual((await unit.ref.get()).data(), unit.data);
  const result = await f.edit({flatsPerFloor: 2, totalFlats: 6});
  assert.equal(result.totalFlats, 6);
  assert.equal(result.vacant, 6);
  for (const unit of f.units) {
    const snapshot = await unit.ref.get();
    if (unit.data.flatNumber === 3) assert.equal(snapshot.exists, false);
    else assert.deepEqual(snapshot.data(), unit.data);
  }
});

test('reservation, cancel, custom rename, and approval remain compatible across building edits', {skip: !enabled}, async () => {
  const f = await fixture();
  const unit = f.units[2]; // The position a width reduction would remove.
  const phone = '+639171100001';
  const onboardingId = residentOnboardingId(f.data.communityId, phone);
  const onboardingRef = f.db.collection('residentOnboarding').doc(onboardingId);
  await onboardingRef.set({communityId: f.data.communityId, approvalStatus: 'pending', status: 'pending_registration', residentName: 'Test', residentType: 'owner', phoneNumber: phone});
  const assignment = {communityId: f.data.communityId, buildingId: f.data.buildingId, flatId: unit.ref.id, onboardingId};
  const call = (core, data) => core({db: f.db, auth: f.auth, data});
  await call(assignResidentOnboardingToFlatCore, assignment);
  assert.equal((await unit.ref.get()).data().status, 'reserved');
  const before = (await f.buildingRef.get()).data();
  await assert.rejects(f.edit({name: 'Blocked rename', flatsPerFloor: 2, totalFlats: 6}), {code: 'failed-precondition'});
  assert.deepEqual((await f.buildingRef.get()).data(), before);
  await f.edit({name: 'Renamed', floors: 4, totalFlats: 12});
  assert.equal((await onboardingRef.get()).data().buildingReference, 'Renamed');
  await call(renameUnitCore, {...assignment, newLabel: 'Villa-Custom'});
  assert.equal((await unit.ref.get()).data().flatLabel, 'Villa-Custom');
  await call(cancelResidentOnboardingReservationCore, assignment);
  assert.equal((await unit.ref.get()).data().status, 'vacant');
  await call(assignResidentOnboardingToFlatCore, assignment);
  const residentRef = f.db.collection('users').doc(`resident-${randomUUID()}`);
  await residentRef.set({role: 'resident', communityId: f.data.communityId, approvalStatus: 'pending', isActive: false,
    declaredResidentType: 'owner', phoneNumber: phone, buildingId: f.data.buildingId, flatId: unit.ref.id});
  await call(approveResidentRegistrationCore, {
    communityId: f.data.communityId, userId: residentRef.id,
    buildingId: f.data.buildingId, flatId: unit.ref.id, residentType: 'owner',
  });
  assert.equal((await unit.ref.get()).data().status, 'occupied');
  assert.equal((await unit.ref.get()).data().residentUserId, residentRef.id);
  assert.equal((await unit.ref.get()).data().flatLabel, 'Villa-Custom');
  await assert.rejects(f.edit({name: 'Renamed', flatsPerFloor: 2, totalFlats: 6}), {code: 'failed-precondition'});
  const stats = await f.edit({name: 'Renamed', floors: 4, totalFlats: 12});
  assert.equal(stats.occupied, 1);
  assert.equal(stats.reserved, 0);
  assert.equal(stats.occupancyRate, 8);
});

test('concurrent reservation and reduction cannot both succeed for a removed unit', {skip: !enabled}, async () => {
  const f = await fixture();
  const flatId = f.units[2].ref.id;
  const onboardingId = `pending-${randomUUID()}`;
  await f.db.collection('residentOnboarding').doc(onboardingId).set({communityId: f.data.communityId,
    approvalStatus: 'pending', status: 'pending_registration', residentType: 'owner'});
  const results = await Promise.allSettled([
    f.edit({flatsPerFloor: 2, totalFlats: 6}),
    assignResidentOnboardingToFlatCore({db: f.db, auth: f.auth,
      data: {communityId: f.data.communityId, buildingId: f.data.buildingId, flatId, onboardingId}}),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  const unit = await f.units[2].ref.get();
  const building = (await f.buildingRef.get()).data();
  if (unit.exists) {
    assert.equal(unit.data().status, 'reserved');
    assert.equal(building.flatsPerFloor, 3);
  } else {
    assert.equal(building.flatsPerFloor, 2);
    const onboarding = (await f.db.collection('residentOnboarding').doc(onboardingId).get()).data();
    assert.equal(onboarding.flatId, undefined);
  }
});
