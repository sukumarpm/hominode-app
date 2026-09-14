const test = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {initializeApp, getApps} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {deleteBuildingCore, validateBuildingDeletionCore} = require('../src/building_deletion');
const {reconcileBuildingCore, createBuildingCore} = require('../src/building_reconciliation');
const {assignResidentOnboardingToFlatCore, reassignResidentCore} = require('../src/resident_identity');
const {importResidentsBulkCore} = require('../src/resident_bulk_import');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;

async function fixture(count = 3) {
  if (!getApps().length) initializeApp({projectId: 'demo-hominode'});
  const db = getFirestore();
  const communityId = `deletion-${randomUUID()}`;
  const uid = `admin-${randomUUID()}`;
  const auth = {uid, token: {phone_number: '+14155558881', firebase: {sign_in_provider: 'phone'}}};
  await db.collection('communities').doc(communityId).set({isActive: true, countryCode: 'US'});
  await db.collection('admins').doc(uid).set({uid, role: 'admin', isActive: true, authorizedCommunityIds: [communityId]});
  const layout = {communityId, name: 'Tower A', floors: 1, flatsPerFloor: count, totalFlats: count,
    structureType: 'villa_cluster', flatBhkConfig: {}};
  const created = await createBuildingCore({db, auth, data: layout});
  const buildingId = created.buildingId;
  const data = {communityId, buildingId};
  const query = db.collection('flats').where('buildingId', '==', buildingId);
  const units = (await query.get()).docs;
  const buildingRef = db.collection('buildings').doc(buildingId);
  const call = (core, input = data) => core({db, auth, data: input});
  return {db, auth, data, units, query, buildingRef, layout, call,
    check: () => call(validateBuildingDeletionCore), remove: () => call(deleteBuildingCore)};
}

test('real deletion preserves readable history, removes all units, and live stream removes building', {skip: !enabled}, async () => {
  const f = await fixture();
  const ref = f.db.collection('visitors').doc();
  await ref.set({communityId: f.data.communityId, flatId: f.units[0].id, status: 'departed'});
  let stop;
  let timer;
  const gone = new Promise((resolve, reject) => {
    timer = setTimeout(() => reject(Error('No building removal stream event')), 60000);
    stop = f.buildingRef.onSnapshot((doc) => {if (!doc.exists) resolve();}, reject);
  });
  try {await f.remove(); await gone;} finally {clearTimeout(timer); stop();}
  assert.equal((await f.query.get()).size, 0);
  assert.equal((await ref.get()).data().flatLabel, f.units[0].data().flatLabel);
  assert.equal((await ref.get()).data().buildingName, 'Tower A');
  const audit = await f.db.collection('auditLogs').where('targetId', '==', f.data.buildingId).get();
  assert.equal(audit.size, 1);
  assert.equal(audit.docs[0].data().metadata.result, 'deleted');
  // Reusing the visible name creates entirely different canonical IDs.
  const replacement = await f.call(createBuildingCore, f.layout);
  assert.notEqual(replacement.buildingId, f.data.buildingId);
  const replacementUnits = await f.db.collection('flats').where('buildingId', '==', replacement.buildingId).get();
  assert(replacementUnits.docs.every((doc) => !f.units.some((old) => old.id === doc.id)));
});

test('preflight is advisory: reservation created before final delete blocks all deletes', {skip: !enabled}, async () => {
  const f = await fixture(); assert.equal((await f.check()).canDelete, true);
  const ref = f.db.collection('residentOnboarding').doc();
  await ref.set({communityId: f.data.communityId, approvalStatus: 'pending', status: 'pending_registration', residentType: 'owner'});
  await f.call(assignResidentOnboardingToFlatCore, {...f.data, flatId: f.units[0].id, onboardingId: ref.id});
  await assert.rejects(f.remove(), {code: 'failed-precondition'});
  assert.equal((await f.query.get()).size, 3); assert((await f.buildingRef.get()).exists);
});

test('concurrent reservation and deletion cannot both succeed', {skip: !enabled}, async () => {
  const f = await fixture();
  const ref = f.db.collection('residentOnboarding').doc();
  await ref.set({communityId: f.data.communityId, approvalStatus: 'pending', status: 'pending_registration', residentType: 'owner'});
  const results = await Promise.allSettled([f.remove(), f.call(assignResidentOnboardingToFlatCore,
    {...f.data, flatId: f.units[0].id, onboardingId: ref.id})]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  if ((await f.buildingRef.get()).exists) {
    assert.equal((await f.query.get()).size, 3);
    assert.equal((await f.units[0].ref.get()).data().status, 'reserved');
  } else {
    assert.equal((await f.query.get()).size, 0);
    assert.equal((await ref.get()).data().flatId, undefined);
  }
});

test('concurrent expansion and deletion cannot leave orphan units', {skip: !enabled}, async () => {
  const f = await fixture();
  const result = await Promise.allSettled([f.remove(), f.call(reconcileBuildingCore,
    {...f.layout, ...f.data, totalFlats: 4, flatsPerFloor: 4})]);
  if (result[0].status === 'fulfilled') {
    assert.equal((await f.buildingRef.get()).exists, false);
    assert.equal((await f.query.get()).size, 0);
  } else {
    assert((await f.buildingRef.get()).exists);
    assert.equal((await f.query.get()).size, 4);
  }
});

test('concurrent bulk allocation and deletion leaves no active orphan', {skip: !enabled}, async () => {
  const f = await fixture();
  const row = {rowNumber: 2, building: 'Tower A', unit: f.units[0].data().flatLabel,
    residentName: 'Test', phoneNumber: '+14155558889', residentType: 'owner'};
  await Promise.allSettled([f.remove(), f.call(importResidentsBulkCore,
    {communityId: f.data.communityId, importJobId: `job_${randomUUID()}`, rows: [row]})]);
  const references = await f.db.collection('residentOnboarding').where('buildingId', '==', f.data.buildingId).get();
  if (!(await f.buildingRef.get()).exists) {
    assert.equal((await f.query.get()).size, 0); assert.equal(references.size, 0);
  } else {
    assert.equal((await f.query.get()).size, 3); assert.equal(references.size, 1);
  }
});

test('concurrent eligible resident reassignment and deletion cannot both succeed', {skip: !enabled}, async () => {
  const f = await fixture(); const userRef = f.db.collection('users').doc();
  await userRef.set({communityId: f.data.communityId, role: 'resident', residentType: 'owner', ownershipType: 'owner',
    status: 'inactive', occupancyStatus: 'moved_out', isActive: false, approvalStatus: 'approved'});
  const results = await Promise.allSettled([f.remove(), f.call(reassignResidentCore,
    {...f.data, flatId: f.units[0].id, userId: userRef.id})]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const resident = (await userRef.get()).data();
  if (!(await f.buildingRef.get()).exists) {
    assert.equal(resident.flatId, undefined); assert.equal((await f.query.get()).size, 0);
  } else {
    assert.equal(resident.flatId, f.units[0].id); assert.equal((await f.query.get()).size, 3);
  }
});

test('real 499-unit transaction succeeds; one extra child blocks atomically', {skip: !enabled, timeout: 240000}, async () => {
  const f = await fixture(499);
  const child = f.db.collection('parkingSlots').doc();
  await child.set({...f.data, status: 'vacant'});
  await assert.rejects(f.remove(), {code: 'failed-precondition'});
  assert.equal((await f.query.get()).size, 499); assert((await child.get()).exists);
  await child.delete(); // Test fixture only: clear the unused slot through Admin SDK.
  await f.remove();
  assert.equal((await f.query.get()).size, 0); assert.equal((await f.buildingRef.get()).exists, false);
});
