const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

let env;

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
    db.collection('payments').doc(paymentId).set({
      id: paymentId,
      communityId: 'BLUE-VALLEY',
      billId: 'bill-test',
      flatId: 'flat-test',
      userId: 'resident-test',
      amount: 1.0,
      provider: 'direct_upi',
      method: 'upi',
      verificationMode: 'manual',
      evidenceType: 'receipt',
      status: 'pending',
      transactionId: null,
      receiptPath:
          'payment_receipts/BLUE-VALLEY/bill-test/resident-test/payment-test.jpg',
      paymentDate: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});
