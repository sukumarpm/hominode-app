const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {paymentCases} = require('./helpers/payment_v2_cases');
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST && !!process.env.STORAGE_EMULATOR_HOST;
const projectId = 'demo-hominode-payment-v2';
let app, db, bucket;
test.before(() => {
  if (!enabled) return;
  app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'payment-v2-tests');
  db = getFirestore(app); bucket = getStorage(app).bucket();
});
test.after(async () => {if (app) await deleteApp(app);});
test.beforeEach(async () => {
  if (!enabled) return;
  const result = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
  assert.equal(result.ok, true);
});
paymentCases((name, fn) => test(name, {skip: !enabled}, fn), async () => ({db, bucket,
  upload: (path, metadata) => bucket.file(path).save(Buffer.from('test image evidence'), {resumable: false,
    metadata: {contentType: 'image/jpeg', metadata}}),
}));

// Client rules are exercised separately from the Admin SDK settlement cases.
// These tests need only the Firestore emulator.
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, collection, getDoc, getDocs, query, where, setDoc, updateDoc, deleteDoc, Timestamp} = require('firebase/firestore');
const readOnlyCollections = ['paymentProofsV2', 'paymentTransactions', 'paymentAllocations',
  'residentCreditEntries', 'residentFinancialAccounts'];

test.describe('Billing V2 read-only rules', {skip: !process.env.FIRESTORE_EMULATOR_HOST}, () => {
  let rules;
  const client = uid => uid ? rules.authenticatedContext(uid, {firebase: {sign_in_provider: 'phone'}}).firestore()
    : rules.unauthenticatedContext().firestore();
  const seed = async entries => rules.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [path, data] of Object.entries(entries)) await setDoc(doc(db, path), data);
  });
  test.before(async () => {
    const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
    rules = await initializeTestEnvironment({projectId: 'demo-hominode-payment-v2-rules', firestore: {
      host, port: Number(port), rules: readFileSync(require.resolve('../../firestore.rules'), 'utf8'),
    }});
  });
  test.after(async () => {if (rules) await rules.cleanup();});
  test.beforeEach(async () => {
    await rules.clearFirestore();
    const resident = {uid: 'r', role: 'resident', residentType: 'owner', communityId: 'C', flatId: 'f',
      approvalStatus: 'approved', isActive: true, status: 'active'};
    const admin = {uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']};
    const entries = {
      'communities/C': {isActive: true}, 'communities/D': {isActive: true},
      'users/r': resident, 'users/other': {...resident, uid: 'other'},
      'users/foreign': {...resident, uid: 'foreign', communityId: 'D'},
      'users/inactive': {...resident, uid: 'inactive', isActive: false},
      'users/moved': {...resident, uid: 'moved', status: 'moved_out'},
      'users/pending': {...resident, uid: 'pending', approvalStatus: 'pending'},
      'admins/a': admin, 'admins/foreignAdmin': {...admin, uid: 'foreignAdmin', authorizedCommunityIds: ['D']},
      'admins/inactiveAdmin': {...admin, uid: 'inactiveAdmin', isActive: false},
      'admins/super': {...admin, uid: 'super', role: 'superAdmin'},
      'admins/multi': {...admin, uid: 'multi', authorizedCommunityIds: ['C', 'D']},
      'securityStaff/security': {uid: 'security', role: 'security', isActive: true, communityId: 'C'},
      'paymentSettlementsV2/private': {schemaVersion: 2, communityId: 'C', residentId: 'r'},
      'bills/v1': {communityId: 'C', flatId: 'f', residentId: 'r', amount: 100, status: 'pending'},
    };
    for (const name of readOnlyCollections) {
      entries[`${name}/own`] = {schemaVersion: 2, communityId: 'C', residentId: 'r'};
      // Neither same-flat access nor legacy owner aliases authorize V2 reads.
      entries[`${name}/other`] = {schemaVersion: 2, communityId: 'C', residentId: 'other', flatId: 'f', userId: 'r', createdBy: 'r'};
      entries[`${name}/foreign`] = {schemaVersion: 2, communityId: 'D', residentId: 'r'};
    }
    await seed(entries);
  });

  for (const name of readOnlyCollections) {
    test(`${name}: own get and correctly scoped list succeed; broad lists fail`, async () => {
      const db = client('r');
      await assertSucceeds(getDoc(doc(db, name, 'own')));
      const own = await assertSucceeds(getDocs(query(collection(db, name), where('communityId', '==', 'C'), where('residentId', '==', 'r'))));
      assert.deepEqual(own.docs.map(doc => doc.id), ['own']);
      await assertFails(getDocs(collection(db, name)));
      await assertFails(getDocs(query(collection(db, name), where('communityId', '==', 'C'))));
      await assertFails(getDocs(query(collection(db, name), where('residentId', '==', 'r'))));
    });
    test(`${name}: cross-resident, cross-community and legacy owner aliases grant no access`, async () => {
      const db = client('r');
      await assertFails(getDoc(doc(db, name, 'other')));
      await assertFails(getDoc(doc(db, name, 'foreign')));
      await assertFails(getDoc(doc(client('foreign'), name, 'own')));
      for (const [communityId, residentId] of [['C', 'other'], ['D', 'r']]) {
        await assertFails(getDocs(query(collection(db, name), where('communityId', '==', communityId), where('residentId', '==', residentId))));
      }
    });
    test(`${name}: active Admin reads only assigned active communities`, async () => {
      const db = client('a');
      await assertSucceeds(getDoc(doc(db, name, 'own')));
      await assertSucceeds(getDoc(doc(db, name, 'other')));
      const rows = await assertSucceeds(getDocs(query(collection(db, name), where('communityId', '==', 'C'))));
      assert.equal(rows.size, 2);
      await assertFails(getDoc(doc(db, name, 'foreign')));
      await assertFails(getDoc(doc(client('foreignAdmin'), name, 'own')));
      await assertFails(getDocs(query(collection(db, name), where('communityId', '==', 'D'))));
      await assertFails(getDocs(collection(db, name)));
      await assertSucceeds(getDoc(doc(client('multi'), name, 'own')));
      await assertSucceeds(getDoc(doc(client('multi'), name, 'foreign')));
    });
    test(`${name}: inactive residents/Admins, Super Admin, Security and anonymous callers cannot read`, async () => {
      for (const uid of ['inactive', 'moved', 'pending', 'inactiveAdmin', 'super', 'security', null]) {
        // A matching residentId must not bypass profile or role restrictions.
        await seed({[`${name}/restricted`]: {schemaVersion: 2, communityId: 'C', residentId: uid || 'r'}});
        const db = client(uid);
        await assertFails(getDoc(doc(db, name, 'restricted')));
        await assertFails(getDocs(query(collection(db, name), where('communityId', '==', 'C'), where('residentId', '==', uid || 'r'))));
      }
    });
    test(`${name}: inactive community blocks resident and assigned Admin reads`, async () => {
      await seed({'communities/C': {isActive: false}});
      for (const uid of ['r', 'a', 'multi']) {
        const db = client(uid);
        await assertFails(getDoc(doc(db, name, 'own')));
        await assertFails(getDocs(query(collection(db, name), where('communityId', '==', 'C'), where('residentId', '==', 'r'))));
      }
    });
    test(`${name}: all client creates, updates and deletes are denied`, async () => {
      for (const uid of ['r', 'other', 'foreign', 'a', 'multi', 'super', null]) {
        const db = client(uid);
        await assertFails(setDoc(doc(db, name, 'new'), {schemaVersion: 2, communityId: 'C', residentId: uid || 'r'}));
        await assertFails(updateDoc(doc(db, name, 'own'), {residentId: uid || 'r', amountMinor: 1}));
        await assertFails(deleteDoc(doc(db, name, 'own')));
      }
    });
  }
  test('paymentSettlementsV2 remains inaccessible to every client role', async () => {
    for (const uid of ['r', 'a', 'multi', 'super', null]) {
      const db = client(uid);
      await assertFails(getDoc(doc(db, 'paymentSettlementsV2/private')));
      await assertFails(getDocs(query(collection(db, 'paymentSettlementsV2'), where('communityId', '==', 'C'), where('residentId', '==', 'r'))));
      await assertFails(setDoc(doc(db, 'paymentSettlementsV2/new'), {communityId: 'C', residentId: 'r'}));
      await assertFails(updateDoc(doc(db, 'paymentSettlementsV2/private'), {amountMinor: 1}));
      await assertFails(deleteDoc(doc(db, 'paymentSettlementsV2/private')));
    }
  });
  test('V2 read grants do not expose nested backend documents', async () => {
    for (const name of readOnlyCollections) {
      await seed({[`${name}/own/internal/private`]: {communityId: 'C', residentId: 'r'}});
      for (const uid of ['r', 'a']) await assertFails(getDoc(doc(client(uid), `${name}/own/internal/private`)));
    }
  });
  test('V1 bill reads and pending proof submission retain their existing permissions', async () => {
    const resident = client('r'), admin = client('a');
    await assertSucceeds(getDoc(doc(resident, 'bills/v1')));
    await assertSucceeds(getDoc(doc(admin, 'bills/v1')));
    const payment = {id: 'v1-proof', communityId: 'C', billId: 'v1', flatId: 'f', userId: 'r', amount: 100,
      method: 'external', status: 'pending', receiptPath: 'payment_receipts/C/v1/r/v1-proof.jpg',
      paymentDate: Timestamp.now(), createdAt: Timestamp.now(), updatedAt: Timestamp.now()};
    await assertSucceeds(setDoc(doc(resident, 'payments/v1-proof'), payment));
    await assertSucceeds(getDoc(doc(resident, 'payments/v1-proof')));
    await assertSucceeds(getDoc(doc(admin, 'payments/v1-proof')));
    for (const db of [resident, admin]) {
      await assertFails(updateDoc(doc(db, 'payments/v1-proof'), {status: 'completed'}));
      await assertFails(deleteDoc(doc(db, 'payments/v1-proof')));
    }
  });
});
