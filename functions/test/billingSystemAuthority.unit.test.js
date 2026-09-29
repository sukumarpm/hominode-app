const test = require('node:test');
const assert = require('node:assert/strict');
const {sosStore} = require('./helpers/sos_store');
const {
  requireOperationalBillingSystem,
  SYSTEM_BILLING_ACTOR_ID,
} = require('../src/resident_identity');

test('trusted system authority returns a deterministic non-human actor and scoped active community', async () => {
  const db = sosStore();
  db.values.set('communities/C', {isActive: true, timeZone: 'Asia/Manila', id: 'untrusted-document-id'});
  const first = await requireOperationalBillingSystem(db, 'C');
  const second = await requireOperationalBillingSystem(db, 'C');
  assert.equal(SYSTEM_BILLING_ACTOR_ID, 'system:billing-scheduler');
  assert.equal(first.uid, SYSTEM_BILLING_ACTOR_ID);
  assert.equal(second.uid, first.uid);
  assert.deepEqual(first.community, {isActive: true, timeZone: 'Asia/Manila', id: 'C'});
  assert.equal(db.values.has(`admins/${SYSTEM_BILLING_ACTOR_ID}`), false);
  assert.equal(db.values.has(`users/${SYSTEM_BILLING_ACTOR_ID}`), false);
});

test('trusted system authority reads through the supplied transaction', async () => {
  const db = sosStore();
  db.values.set('communities/C', {isActive: true, timeZone: 'UTC'});
  const actor = await db.runTransaction(tx => requireOperationalBillingSystem(db, 'C', tx));
  assert.equal(actor.uid, SYSTEM_BILLING_ACTOR_ID);
});

test('trusted system authority rejects inactive, missing, and invalid community scopes', async () => {
  const db = sosStore();
  db.values.set('communities/inactive', {isActive: false});
  for (const communityId of ['inactive', 'missing']) {
    await assert.rejects(requireOperationalBillingSystem(db, communityId), {code: 'failed-precondition'});
  }
  for (const communityId of ['', ' C', 'C/other']) {
    await assert.rejects(requireOperationalBillingSystem(db, communityId), {code: 'invalid-argument'});
  }
});
