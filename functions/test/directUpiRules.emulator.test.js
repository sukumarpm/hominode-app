const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

let env;

function directUpiProof(paymentId, fields = {}) {
  return {
    id: paymentId,
    communityId: 'BLUE-VALLEY',
    billId: 'bill-test',
    flatId: 'flat-test',
    userId: 'resident-test',
    amount: 1,
    provider: 'direct_upi',
    method: 'upi',
    verificationMode: 'manual',
    evidenceType: 'receipt',
    status: 'pending',
    transactionId: null,
    receiptPath:
      `payment_receipts/BLUE-VALLEY/bill-test/resident-test/${paymentId}.jpg`,
    paymentDate: new Date(),
    createdAt: new Date(),
    updatedAt: new Date(),
    ...fields,
  };
}

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hominode-upi',
    firestore: {
      host: '127.0.0.1',
      port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(':').pop()),
      rules: fs.readFileSync(
        path.join(__dirname, '../../firestore.rules'),
        'utf8',
      ),
    },
  });

  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await db.collection('communities').doc('BLUE-VALLEY').set({
      name: 'Blue Valley',
      isActive: true,
    });

    await db.collection('users').doc('resident-test').set({
      uid: 'resident-test',
      role: 'resident',
      approvalStatus: 'approved',
      isActive: true,
      status: 'active',
      communityId: 'BLUE-VALLEY',
      buildingId: 'building-test',
      flatId: 'flat-test',
      residentType: 'owner',
      ownershipType: 'owner',
      identityVerified: false,
      identityVerificationStatus: 'not_required',
    });

    await db.collection('flats').doc('flat-test').set({
      communityId: 'BLUE-VALLEY',
      buildingId: 'building-test',
      status: 'occupied',
      residentUserId: 'resident-test',
    });

    await db.collection('bills').doc('bill-test').set({
      communityId: 'BLUE-VALLEY',
      buildingId: 'building-test',
      flatId: 'flat-test',
      residentId: 'resident-test',
      amount: 1,
      status: 'pending',
      paidAt: null,
    });
  });
});

test.after(async () => {
  await env.cleanup();
});

test('resident can create Direct UPI payment proof', async () => {
  const db = env.authenticatedContext('resident-test').firestore();

  const paymentId = 'payment-test';

  await assertSucceeds(
    db.collection('payments').doc(paymentId).set(directUpiProof(paymentId)),
  );
});

test('required payment timestamps must exist and be Firestore timestamps', async () => {
  const db = env.authenticatedContext('resident-test').firestore();

  for (const field of ['paymentDate', 'createdAt', 'updatedAt']) {
    const missingId = `missing-${field}`;
    const missingTimestamp = directUpiProof(missingId);
    delete missingTimestamp[field];
    await assertFails(
      db.collection('payments').doc(missingId).set(missingTimestamp),
    );

    const invalidId = `invalid-${field}`;
    await assertFails(
      db
        .collection('payments')
        .doc(invalidId)
        .set(directUpiProof(invalidId, {[field]: 'not-a-timestamp'})),
    );
  }
});

test('transactionId remains optional, nullable, and capped at 200 characters', async () => {
  const db = env.authenticatedContext('resident-test').firestore();

  const omittedId = 'transaction-omitted';
  const withoutTransactionId = directUpiProof(omittedId);
  delete withoutTransactionId.transactionId;
  await assertSucceeds(
    db.collection('payments').doc(omittedId).set(withoutTransactionId),
  );

  const nullId = 'transaction-null';
  await assertSucceeds(
    db.collection('payments').doc(nullId).set(directUpiProof(nullId)),
  );

  const reasonableId = 'transaction-reference';
  await assertSucceeds(
    db
      .collection('payments')
      .doc(reasonableId)
      .set(directUpiProof(reasonableId, {transactionId: 'UPI-REF-2026-123456'})),
  );

  const oversizedId = 'transaction-too-long';
  await assertFails(
    db
      .collection('payments')
      .doc(oversizedId)
      .set(directUpiProof(oversizedId, {transactionId: 'x'.repeat(201)})),
  );
});
