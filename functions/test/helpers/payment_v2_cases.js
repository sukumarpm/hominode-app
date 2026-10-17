const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {createMonthlyBillingBatchV2Core: issue, monthlyBillIdV2} = require('../../src/billing_batch');
const {reviseMonthlyBillingBatchV2Core: revise} = require('../../src/billing_revision');
const {preparePaymentProofV2Core: prepare, verifyPaymentProofV2Core: verify,
  rejectPaymentProofV2Core: reject, recordOfflinePaymentV2Core: offline, MAX_ALLOCATIONS} = require('../../src/payment_v2');
const {createProofSubmittedNotification, dispatchPaymentV2NotificationCore, EVENT_COLLECTION} = require('../../src/payment_v2_notifications');
const {notificationAudienceKey} = require('../../src/notifications');
const ledger = require('../../src/billing_v2_ledger');
const auth = {uid: 'a', token: {phone_number: '+639171234567', firebase: {sign_in_provider: 'phone'}}};
const now = () => Date.parse('2030-01-15T00:00:00Z');
const lines = amountMinor => [{lineId: 'base', code: 'maintenance', amountMinor}];
const collections = ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries', 'residentFinancialAccounts', 'paymentSettlementsV2', 'auditLogs'];
async function fixture(environment, amounts = [1000], timeZone = 'Asia/Manila') {
  const {db, bucket, upload} = await environment();
  const ref = path => {const parts = path.split('/'); return db.collection(parts.slice(0, -1).join('/')).doc(parts.at(-1));};
  const get = async path => (await ref(path).get()).data();
  const patch = (path, data) => ref(path).update(data);
  await ref('admins/a').set({uid: 'a', role: 'admin', isActive: true, authorizedCommunityIds: ['C']});
  await ref('communities/C').set({isActive: true, timeZone});
  await ref('buildings/b').set({communityId: 'C'});
  await ref('flats/f').set({communityId: 'C', buildingId: 'b', status: 'occupied', residentUserId: 'r'});
  await ref('users/r').set({uid: 'r', role: 'resident', isActive: true, approvalStatus: 'approved', status: 'active', communityId: 'C', buildingId: 'b', flatId: 'f'});
  const bills = [], batches = [];
  for (let i = 0; i < amounts.length; i++) {
    const period = `${2030 + Math.floor(i / 12)}-${String(i % 12 + 1).padStart(2, '0')}`;
    const issued = await issue({db, auth, now, data: {communityId: 'C', scope: 'community', billingPeriod: period,
      idempotencyKey: `issue-${period}`, chargeLines: lines(amounts[i]), dueDate: '2030-02-15'}});
    bills.push(monthlyBillIdV2('C', 'f', period)); batches.push(issued.batchId);
  }
  const rows = async name => (await db.collection(name).get()).docs.filter(doc => doc.ref.path === `${name}/${doc.id}`)
    .map(doc => [doc.id, doc.data()]).sort(([a], [b]) => a.localeCompare(b));
  const financialState = () => Promise.all(collections.map(rows));
  const pay = (extra = {}, options = {}) => offline({db, auth, now, data: {communityId: 'C', residentId: 'r', amountMinor: 1000,
    paymentMethod: 'cash', idempotencyKey: 'offline', ...extra}, ...options});
  const proof = async (amountMinor = 1000, n = 0, key = 'proof', amountContractVersion = null, paymentReference = 'UPI-REF') => {
    const bill = await get(`bills/${bills[n]}`);
    const data = {billId: bills[n], submittedAmountMinor: amountMinor, submittedBillRevisionId: bill.currentRevisionId,
      idempotencyKey: key, receiptExtension: 'jpg', paymentReference,
      ...(amountContractVersion == null ? {} : {amountContractVersion})};
    const result = await prepare({db, auth: {uid: 'r'}, now, data});
    await upload(result.receiptPath, {paymentId: result.paymentId, billId: bills[n], communityId: 'C', residentUid: 'r'});
    return {...result, data, approve: ({confirmedAmountMinor, ...options} = {}) => verify({db, bucket, auth, now,
      data: {paymentId: result.paymentId, ...(confirmedAmountMinor === undefined ? {} : {confirmedAmountMinor})}, ...options})};
  };
  const revision = async (amountMinor, n = 0) => {
    const batch = await get(`billingBatches/${batches[n]}`);
    return revise({db, auth, now, data: {communityId: 'C', billingBatchId: batches[n],
      expectedRevisionId: batch.currentRevisionId, idempotencyKey: `edit-${batch.revisionNo + 1}`, chargeLines: lines(amountMinor)}});
  };
  const prepareOnly = async (extra = {}, n = 0) => {
    const bill = await get(`bills/${bills[n]}`);
    const data = {billId: bills[n], submittedAmountMinor: bill.outstandingAmountMinor,
      submittedBillRevisionId: bill.currentRevisionId, idempotencyKey: 'prepare-only', receiptExtension: 'png', ...extra};
    return {...await prepare({db, auth: {uid: 'r'}, now, data}), data};
  };
  return {db, bucket, upload, ref, get, patch, bills, batches, rows, financialState, pay, proof, revision, prepareOnly};
}
function paymentCases(test, environment) {
  test('same-key preparation retry preserves the original proof after outstanding and revision change', async () => {
    const f = await fixture(environment), first = await f.prepareOnly();
    const before = await f.get(`paymentProofsV2/${first.paymentId}`);
    await f.revision(1200);
    const retry = await prepare({db: f.db, auth: {uid: 'r'}, data: first.data, now: () => now() + 5000});
    assert.equal(retry.paymentId, first.paymentId); assert.equal(retry.receiptPath, first.receiptPath);
    assert.deepEqual(await f.get(`paymentProofsV2/${first.paymentId}`), before);
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('different preparation key is rejected while a proof is pending, and rejection permits a new proof', async () => {
    const f = await fixture(environment), first = await f.prepareOnly();
    await assert.rejects(f.prepareOnly({idempotencyKey: 'second'}), {code: 'failed-precondition', message: /payment_proof_already_pending/});
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
    await reject({db: f.db, auth, data: {paymentId: first.paymentId, rejectionReason: 'Receipt missing'}});
    const rejected = await f.get(`paymentProofsV2/${first.paymentId}`);
    const rejectionNotifications = await f.rows('notifications');
    assert.equal(rejectionNotifications.length, 1);
    assert.equal(rejectionNotifications[0][1].eventType, 'payment_proof_rejected');
    assert.match(rejectionNotifications[0][1].message, /Open Billing/);
    const second = await f.prepareOnly({idempotencyKey: 'second'});
    assert.notEqual(second.paymentId, first.paymentId);
    const oldRetry = await prepare({db: f.db, auth: {uid: 'r'}, now, data: first.data});
    assert.equal(oldRetry.paymentId, first.paymentId); assert.equal(oldRetry.status, 'failed');
    await assert.rejects(f.prepareOnly({idempotencyKey: 'third'}), /payment_proof_already_pending/);
    assert.deepEqual(await f.get(`paymentProofsV2/${first.paymentId}`), rejected);
    assert.equal((await f.rows('paymentProofsV2')).filter(([, p]) => p.status === 'pending').length, 1);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('simultaneous different-key preparations create only one pending proof', async () => {
    const f = await fixture(environment);
    const results = await Promise.allSettled([f.prepareOnly({idempotencyKey: 'one'}), f.prepareOnly({idempotencyKey: 'two'})]);
    assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
    const rejected = results.find(result => result.status === 'rejected');
    assert.equal(rejected.reason.code, 'failed-precondition'); assert.match(rejected.reason.message, /payment_proof_already_pending/);
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
    assert.equal((await f.rows('paymentProofGuardsV2')).length, 1);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('simultaneous same-key preparations return the same proof', async () => {
    const f = await fixture(environment);
    const results = await Promise.all([f.prepareOnly(), f.prepareOnly()]);
    assert.equal(results[0].paymentId, results[1].paymentId);
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
  });
  test('pending proof predating the guard still blocks a new key', async () => {
    const f = await fixture(environment), first = await f.prepareOnly();
    for (const [guardId] of await f.rows('paymentProofGuardsV2')) await f.ref(`paymentProofGuardsV2/${guardId}`).delete();
    await assert.rejects(f.prepareOnly({idempotencyKey: 'other'}), /payment_proof_already_pending/);
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
    assert.equal((await prepare({db: f.db, auth: {uid: 'r'}, now, data: first.data})).paymentId, first.paymentId);
  });
  test('pending proof for another bill does not block preparation', async () => {
    const f = await fixture(environment, [1000, 1000]);
    const first = await f.prepareOnly(), second = await f.prepareOnly({idempotencyKey: 'other-bill'}, 1);
    assert.notEqual(first.paymentId, second.paymentId); assert.equal((await f.rows('paymentProofsV2')).length, 2);
  });
  test('completed proof permits a new exact-outstanding proof after upward revision', async () => {
    const f = await fixture(environment), first = await f.proof(); await first.approve(); await f.revision(1200);
    const before = await f.financialState();
    const second = await f.prepareOnly({submittedAmountMinor: 200});
    assert.notEqual(second.paymentId, first.paymentId);
    assert.equal((await f.get(`paymentProofsV2/${second.paymentId}`)).submittedAmountMinor, 200);
    assert.deepEqual(await f.financialState(), before);
  });
  test('preparation accepts exact partial outstanding derived from immutable ledger', async () => {
    const f = await fixture(environment); await f.pay({amountMinor: 400}); const before = await f.financialState();
    const p = await f.prepareOnly({submittedAmountMinor: 600});
    assert.equal((await f.get(`paymentProofsV2/${p.paymentId}`)).submittedAmountMinor, 600);
    assert.deepEqual(await f.financialState(), before);
  });
  for (const submittedAmountMinor of [599, 601, 1000]) {
    test(`preparation rejects ${submittedAmountMinor} against current outstanding 600 without any proof or money writes`, async () => {
      const f = await fixture(environment); await f.pay({amountMinor: 400}); const before = await f.financialState();
      await assert.rejects(f.prepareOnly({submittedAmountMinor}), {code: 'failed-precondition', message: /submitted_amount_mismatch/});
      assert.equal((await f.rows('paymentProofsV2')).length, 0); assert.equal((await f.rows('paymentProofGuardsV2')).length, 0);
      assert.deepEqual(await f.financialState(), before);
    });
  }
  test('zero submitted amount and zero outstanding cannot prepare a new proof', async () => {
    const f = await fixture(environment);
    await assert.rejects(f.prepareOnly({submittedAmountMinor: 0}), {code: 'invalid-argument'});
    await f.pay(); const before = await f.financialState();
    await assert.rejects(f.prepareOnly({submittedAmountMinor: 1}), {code: 'failed-precondition', message: /no outstanding/});
    assert.equal((await f.rows('paymentProofsV2')).length, 0); assert.deepEqual(await f.financialState(), before);
  });
  test('stale submitted revision is rejected even when the submitted amount equals current outstanding', async () => {
    const f = await fixture(environment); await f.revision(1200);
    await assert.rejects(f.prepareOnly({submittedAmountMinor: 1200, submittedBillRevisionId: 'revision_1'}),
      {code: 'failed-precondition', message: /Bill revision changed/});
    assert.equal((await f.rows('paymentProofsV2')).length, 0); assert.equal((await f.rows('paymentProofGuardsV2')).length, 0);
  });
  test('prepared proof without uploaded receipt cannot create any financial effects', async () => {
    const f = await fixture(environment), p = await f.prepareOnly({idempotencyKey: 'missing-evidence'});
    assert.equal((await f.rows('notifications')).length, 0);
    assert.equal((await f.rows(EVENT_COLLECTION)).length, 0);
    const bill = await f.get(`bills/${f.bills[0]}`), proof = await f.get(`paymentProofsV2/${p.paymentId}`);
    await assert.rejects(verify({db: f.db, bucket: f.bucket, auth, now, data: {paymentId: p.paymentId}}),
      {code: 'failed-precondition', message: /receipt object does not exist/});
    assert((await f.financialState()).every(rows => rows.length === 0));
    assert.deepEqual(await f.get(`bills/${f.bills[0]}`), bill);
    assert.deepEqual(await f.get(`paymentProofsV2/${p.paymentId}`), proof);
  });
  test('finalized receipt event creates one sanitized host notification and duplicate delivery is idempotent', async () => {
    const f = await fixture(environment), p = await f.proof(1000, 0, 'upload-notification', null, 'PRIVATE-REFERENCE');
    const [firstFinalizedObject] = await f.bucket.file(p.receiptPath).getMetadata();
    // A repeated upload may produce another finalize event (and Storage generation).
    await f.upload(p.receiptPath, {
      paymentId: p.paymentId, billId: f.bills[0], communityId: 'C', residentUid: 'r',
    });
    const [finalizedObject] = await f.bucket.file(p.receiptPath).getMetadata();
    const deliveries = await Promise.all([
      createProofSubmittedNotification({db: f.db, object: firstFinalizedObject, now}),
      createProofSubmittedNotification({db: f.db, object: finalizedObject, now}),
      createProofSubmittedNotification({db: f.db, object: finalizedObject, now}),
    ]);
    assert.equal(deliveries.filter(result => result.created).length, 1);
    assert.equal(deliveries.filter(result => result.duplicate).length, 2);
    const [notificationId, notification] = (await f.rows('notifications'))[0];
    assert.equal(notification.recipientId, 'r'); assert.equal(notification.communityId, 'C');
    assert.equal(notification.eventType, 'payment_proof_submitted');
    assert.deepEqual(notification.data, {route: 'billing', eventType: 'payment_proof_submitted'});
    assert.match(notification.message, /awaiting Admin verification/);
    assert.match(notification.message, /not confirmation that funds were received/);
    assert(!JSON.stringify(notification).includes(p.receiptPath));
    assert(!JSON.stringify(notification).includes('PRIVATE-REFERENCE'));
    assert.equal((await f.rows(EVENT_COLLECTION)).length, 1);
    assert.equal((await f.get(`${EVENT_COLLECTION}/${notificationId}`)).route, 'billing');
  });
  test('finalized upload cannot notify for wrong metadata, host or community', async () => {
    const f = await fixture(environment), p = await f.proof(1000, 0, 'invalid-upload-notification');
    const [finalizedObject] = await f.bucket.file(p.receiptPath).getMetadata();
    const wrongCommunity = await createProofSubmittedNotification({db: f.db,
      object: {...finalizedObject, metadata: {...finalizedObject.metadata, communityId: 'D'}}, now});
    assert.deepEqual(wrongCommunity, {created: false, reason: 'invalid_upload'});
    await f.patch('users/r', {communityId: 'D'});
    const wrongHostScope = await createProofSubmittedNotification({db: f.db, object: finalizedObject, now});
    assert.deepEqual(wrongHostScope, {created: false, reason: 'proof_not_eligible'});
    const missingObject = await createProofSubmittedNotification({db: f.db,
      object: {...finalizedObject, name: `${p.receiptPath}.unrelated`}, now});
    assert.deepEqual(missingObject, {created: false, reason: 'invalid_upload'});
    assert.equal((await f.rows('notifications')).length, 0);
    assert.equal((await f.rows(EVENT_COLLECTION)).length, 0);
  });
  test('Direct UPI exact payment captures submitted context and atomically settles with private receipt evidence', async () => {
    const f = await fixture(environment), p = await f.proof();
    const submitted = await f.get(`paymentProofsV2/${p.paymentId}`), previous = await f.get(`bills/${f.bills[0]}/revisions/revision_1`);
    for (const [key, value] of Object.entries({billId: f.bills[0], communityId: 'C', residentId: 'r', userId: 'r',
      submittedAmountMinor: 1000, submittedBillRevisionId: 'revision_1', provider: 'direct_upi', method: 'upi',
      verificationMode: 'manual', evidenceType: 'receipt', status: 'pending'})) assert.equal(submitted[key], value);
    assert(submitted.submittedAt instanceof Timestamp); assert((await f.financialState()).every(rows => rows.length === 0));
    const result = await p.approve(); assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: 1000}]);
    const bill = await f.get(`bills/${f.bills[0]}`), proof = await f.get(`paymentProofsV2/${p.paymentId}`);
    assert.equal(bill.status, 'paid'); assert.equal(bill.paidAmountMinor, 1000); assert.equal(bill.outstandingAmountMinor, 0);
    assert.equal(proof.status, 'completed'); assert.equal(proof.transactionId, result.transactionId); assert(proof.receiptGeneration);
    for (const key of Object.keys(submitted)) if (key !== 'status') assert.deepEqual(proof[key], submitted[key]);
    for (const key of ['paymentId', 'paidAt', 'paymentMethod']) assert.equal(Object.hasOwn(bill, key), false);
    assert.deepEqual(await f.get(`bills/${f.bills[0]}/revisions/revision_1`), previous);
    const paymentNotifications = await f.rows('notifications');
    assert.equal(paymentNotifications.length, 1);
    assert.equal(paymentNotifications[0][1].recipientId, 'r');
    assert.equal(paymentNotifications[0][1].communityId, 'C');
    assert.equal(paymentNotifications[0][1].eventType, 'payment_proof_verified');
    assert.match(paymentNotifications[0][1].message, /Admin confirmed receipt of ₹10\.00/);
    assert(!JSON.stringify(paymentNotifications[0][1]).includes('UPI-REF'));
    assert(!JSON.stringify(paymentNotifications[0][1]).includes('payment_receipts/'));
    assert.deepEqual(paymentNotifications[0][1].data, {route: 'billing', eventType: 'payment_proof_verified'});
    assert.equal((await f.rows('billingV2PaymentNotificationEvents')).length, 1);
    const audit = (await f.rows('auditLogs'))[0][1]; assert.equal(audit.metadata.transactionId, result.transactionId);
    assert.deepEqual(audit.metadata.allocatedAmountsMinor, ['1000']); assert(!JSON.stringify(audit).includes('payment_receipts'));
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].version, 1);
  });
  test('flexible proof requires Admin confirmation and a partial confirmation settles only the received amount', async () => {
    const f = await fixture(environment), p = await f.proof(700, 0, 'partial-flex', 2);
    await assert.rejects(p.approve(), /Admin-confirmed received amount is required/);
    assert((await f.financialState()).every(rows => rows.length === 0));
    const result = await p.approve({confirmedAmountMinor: 400});
    assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: 400}]);
    assert.equal(result.excessCreditMinor, 0);
    const bill = await f.get(`bills/${f.bills[0]}`), proof = await f.get(`paymentProofsV2/${p.paymentId}`);
    assert.equal(bill.paidAmountMinor, 400); assert.equal(bill.outstandingAmountMinor, 600);
    assert.equal(proof.submittedAmountMinor, 700); assert.equal(proof.confirmedAmountMinor, 400);
    assert.equal(proof.amountMismatch, true); assert.equal(proof.reviewedBy, 'a');
    const settlement = (await f.rows('paymentSettlementsV2'))[0][1];
    assert.equal(settlement.claimedAmountMinor, 700); assert.equal(settlement.confirmedAmountMinor, 400);
    assert.equal(settlement.amountMismatch, true); assert.equal(settlement.reviewedBy, 'a');
    const audit = (await f.rows('auditLogs'))[0][1];
    assert.equal(audit.metadata.claimedAmountMinor, 700); assert.equal(audit.metadata.confirmedAmountMinor, 400);
    assert.equal(audit.metadata.amountMismatch, true);
  });
  test('flexible exact payment settles the target bill without credit', async () => {
    const f = await fixture(environment), p = await f.proof(1000, 0, 'exact-flex', 2);
    const result = await p.approve({confirmedAmountMinor: 1000});
    assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: 1000}]);
    assert.equal(result.excessCreditMinor, 0);
  });
  test('confirmed excess allocates target bill first, then other liabilities FIFO, then credit', async () => {
    const f = await fixture(environment, [500, 600, 300]);
    const p = await f.proof(1700, 1, 'excess-flex', 2);
    const result = await p.approve({confirmedAmountMinor: 1700});
    assert.deepEqual(result.allocations, [
      {billId: f.bills[1], amountMinor: 600},
      {billId: f.bills[0], amountMinor: 500},
      {billId: f.bills[2], amountMinor: 300},
    ]);
    assert.equal(result.excessCreditMinor, 300);
    assert.equal((await f.get(`residentFinancialAccounts/${ledger.residentFinancialAccountId({communityId: 'C', residentId: 'r', currency: 'INR'})}`)).availableCreditMinor, 300);
  });
  test('same flexible proof retry is idempotent and a different confirmed amount cannot mutate settlement', async () => {
    const f = await fixture(environment), p = await f.proof(500, 0, 'confirmed-retry', 2);
    const first = await p.approve({confirmedAmountMinor: 300});
    const before = await f.financialState();
    const retry = await p.approve({confirmedAmountMinor: 300});
    assert.equal(retry.alreadyCompleted, true); assert.equal(retry.transactionId, first.transactionId);
    assert.equal((await f.rows('notifications')).length, 1);
    assert.equal((await f.rows('billingV2PaymentNotificationEvents')).length, 1);
    await assert.rejects(p.approve({confirmedAmountMinor: 301}), /idempotency_conflict/);
    assert.deepEqual(await f.financialState(), before);
  });
  test('concurrent reviews with conflicting confirmed amounts settle only the first amount', async () => {
    const f = await fixture(environment), p = await f.proof(500, 0, 'conflicting-review', 2);
    const results = await Promise.allSettled([
      p.approve({confirmedAmountMinor: 250}), p.approve({confirmedAmountMinor: 350}),
    ]);
    assert.equal(results.filter(item => item.status === 'fulfilled').length, 1);
    assert.equal(results.filter(item => item.status === 'rejected').length, 1);
    assert.equal((await f.rows('paymentTransactions')).length, 1);
    assert.equal((await f.rows('notifications')).length, 1);
    assert.equal((await f.rows(EVENT_COLLECTION)).length, 1);
    assert.equal((await f.rows('paymentAllocations'))[0][1].amountMinor,
      (await f.rows('paymentTransactions'))[0][1].amountMinor);
  });
  test('concurrent same-amount reviews return one immutable settlement', async () => {
    const f = await fixture(environment), p = await f.proof(500, 0, 'same-review', 2);
    const results = await Promise.all([
      p.approve({confirmedAmountMinor: 300}), p.approve({confirmedAmountMinor: 300}),
    ]);
    assert.equal(results[0].transactionId, results[1].transactionId);
    assert.equal(results.filter(item => item.alreadyCompleted).length, 1);
    assert.equal((await f.rows('paymentTransactions')).length, 1);
    assert.equal((await f.rows('notifications')).length, 1);
    assert.equal((await f.rows(EVENT_COLLECTION)).length, 1);
  });
  test('duplicate normalized UPI references within an account cannot settle twice', async () => {
    const f = await fixture(environment, [1000, 500]);
    const first = await f.proof(1000, 0, 'reference-first', 2, 'upi-ref-1');
    const second = await f.proof(500, 1, 'reference-second', 2, ' UPI-REF-1 ');
    await first.approve({confirmedAmountMinor: 1000});
    const before = await f.financialState();
    await assert.rejects(second.approve({confirmedAmountMinor: 500}), /duplicate_payment_reference/);
    assert.deepEqual(await f.financialState(), before);
    assert.equal((await f.get(`paymentProofsV2/${second.paymentId}`)).status, 'pending');
  });
  test('concurrent proofs with one normalized reference cannot both settle', async () => {
    const f = await fixture(environment, [1000, 500]);
    const first = await f.proof(1000, 0, 'concurrent-reference-first', 2, 'UPI-REF-CONCURRENT');
    const second = await f.proof(500, 1, 'concurrent-reference-second', 2, ' upi-ref-concurrent ');
    const results = await Promise.allSettled([
      first.approve({confirmedAmountMinor: 1000}), second.approve({confirmedAmountMinor: 500}),
    ]);
    assert.equal(results.filter(item => item.status === 'fulfilled').length, 1);
    const rejection = results.find(item => item.status === 'rejected');
    assert.match(rejection.reason.message, /duplicate_payment_reference/);
    assert.equal((await f.rows('paymentTransactions')).length, 1);
    assert.equal((await f.rows('paymentReferenceGuardsV2')).length, 1);
  });
  test('missing payment reference remains reviewable and is explicitly recorded for manual scrutiny', async () => {
    const f = await fixture(environment), p = await f.proof(1000, 0, 'no-reference', 2, null);
    await p.approve({confirmedAmountMinor: 1000});
    const settlement = (await f.rows('paymentSettlementsV2'))[0][1];
    const audit = (await f.rows('auditLogs'))[0][1];
    assert.equal(settlement.referenceReviewRequired, true);
    assert.equal(audit.metadata.referenceReviewRequired, true);
    assert.equal((await f.rows('paymentReferenceGuardsV2')).length, 0);
  });
  test('flexible proof settles a revised target first and then the resident FIFO liabilities', async () => {
    const f = await fixture(environment, [1000, 500]), p = await f.proof(1000, 0, 'revision-flex', 2);
    await f.revision(800);
    const result = await p.approve({confirmedAmountMinor: 1000});
    assert.deepEqual(result.allocations, [
      {billId: f.bills[0], amountMinor: 800}, {billId: f.bills[1], amountMinor: 200},
    ]);
    assert.equal(result.excessCreditMinor, 0);
  });
  for (const [revised, outstanding, excess] of [[1200, 200, 0], [800, 0, 0]]) {
    test(`legacy Direct UPI submitted for 1000 before revision to ${revised} settles current liabilities`, async () => {
      const f = await fixture(environment, [1000, 500]), p = await f.proof();
      const other = await f.get(`bills/${f.bills[1]}`);
      assert.equal((await f.revision(revised)).applied, 1);
      const result = await p.approve(); assert.equal(result.excessCreditMinor, excess);
      assert.deepEqual(result.allocations, revised === 800
        ? [{billId: f.bills[0], amountMinor: 800}, {billId: f.bills[1], amountMinor: 200}]
        : [{billId: f.bills[0], amountMinor: 1000}]);
      assert.equal((await f.get(`bills/${f.bills[0]}`)).outstandingAmountMinor, outstanding);
      if (revised === 1200) assert.deepEqual(await f.get(`bills/${f.bills[1]}`), other);
      const credits = await f.rows('residentCreditEntries');
      assert.equal(credits.length, excess ? 1 : 0);
      if (excess) {assert.equal(credits[0][1].transactionId, result.transactionId); assert.equal(credits[0][1].amountMinor, excess);}
    });
  }
  test('pending and rejected proofs remain non-financial', async () => {
    const f = await fixture(environment), p = await f.proof();
    await reject({db: f.db, auth, data: {paymentId: p.paymentId, rejectionReason: 'Wrong receipt'}});
    await assert.rejects(p.approve(), /Only pending/);
    assert((await f.financialState()).every(rows => rows.length === 0));
    assert.equal((await f.get(`bills/${f.bills[0]}`)).paidAmountMinor, 0);
  });
  for (const [name, edit] of [['active revision', (f) => f.patch(`billingBatches/${f.batches[0]}`, {activeRevisionId: 'revision-active'})],
    ['stale batch pointer', (f) => f.patch(`bills/${f.bills[0]}`, {appliedBatchRevisionId: 'old'})]]) {
    test(`${name} blocks both settlement paths without any writes`, async () => {
      const f = await fixture(environment), p = await f.proof(); await edit(f);
      const before = await f.financialState();
      await assert.rejects(p.approve(), /blocked/); await assert.rejects(f.pay(), /blocked/);
      assert.deepEqual(await f.financialState(), before); assert.equal((await f.get(`paymentProofsV2/${p.paymentId}`)).status, 'pending');
    });
  }
  for (const paymentMethod of ['cash', 'bank_transfer', 'cheque']) test(`Admin ${paymentMethod} settles one bill with an audit record`, async () => {
    const f = await fixture(environment); const result = await f.pay({paymentMethod, paymentReference: 'REF-1'});
    assert.equal(result.allocations.length, 1); assert.equal((await f.get(`bills/${f.bills[0]}`)).status, 'paid');
    const transaction = (await f.rows('paymentTransactions'))[0][1];
    assert.equal(transaction.method, paymentMethod); assert.equal(transaction.reference, 'REF-1');
    assert.equal((await f.rows('auditLogs'))[0][1].action, 'payment_v2.offline');
    const paymentNotification = (await f.rows('notifications'))[0][1];
    assert.equal(paymentNotification.eventType, 'offline_payment_settled');
    assert.equal(paymentNotification.recipientId, 'r');
    assert.match(paymentNotification.message, /Admin recorded a/);
    assert.deepEqual(paymentNotification.data, {route: 'billing', eventType: 'offline_payment_settled'});
    assert(!JSON.stringify(paymentNotification).includes('REF-1'));
  });
  test('FCM failure after Admin settlement leaves committed financial state and in-app notification intact', async () => {
    const f = await fixture(environment);
    const result = await f.pay({paymentMethod: 'cash', idempotencyKey: 'push-failure-settlement'});
    const financialBeforePush = await f.financialState();
    const [eventId, eventData] = (await f.rows(EVENT_COLLECTION))[0];
    assert.equal(eventData.eventType, 'offline_payment_settled');
    const audienceKey = notificationAudienceKey({appId: 'resident', role: 'resident', communityId: 'C', uid: 'r'});
    await f.ref('notificationDevices/device-1').set({uid: 'r', communityId: 'C', role: 'resident',
      appId: 'resident', audienceKey, active: true, token: 'synthetic-test-token'});
    const delivery = await dispatchPaymentV2NotificationCore({db: f.db,
      messaging: {sendEachForMulticast: async () => {throw Object.assign(Error('unavailable'), {code: 'unavailable'});}},
      event: {params: {eventId}}, logger: {warn() {}}});
    assert.deepEqual(delivery, {sent: false, reason: 'push_failed'});
    assert.deepEqual(await f.financialState(), financialBeforePush);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).status, 'paid');
    assert.equal((await f.get(`paymentTransactions/${result.transactionId}`)).amountMinor, 1000);
    assert.equal((await f.rows('notifications')).length, 1);
  });
  test('Admin payment spans Jan/Feb/Mar oldest-first with a partial final bill', async () => {
    const f = await fixture(environment, [1000, 1200, 800]);
    const result = await f.pay({amountMinor: 2000});
    assert.deepEqual(result.allocations, [{billId: f.bills[0], amountMinor: 1000}, {billId: f.bills[1], amountMinor: 1000}]);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).status, 'paid');
    const partial = await f.get(`bills/${f.bills[1]}`); assert.equal(partial.status, 'partially_paid'); assert.equal(partial.outstandingAmountMinor, 200);
    assert.equal((await f.get(`bills/${f.bills[2]}`)).paidAmountMinor, 0);
  });
  test('Admin excess becomes attributable credit without consuming existing resident credit', async () => {
    const f = await fixture(environment);
    const first = await f.pay({amountMinor: 1300}); assert.equal(first.excessCreditMinor, 300);
    await f.revision(1200);
    const second = await f.pay({idempotencyKey: 'second', amountMinor: 300});
    assert.deepEqual(second.allocations, [{billId: f.bills[0], amountMinor: 200}]); assert.equal(second.excessCreditMinor, 100);
    const account = (await f.rows('residentFinancialAccounts'))[0][1]; assert.equal(account.availableCreditMinor, 400); assert.equal(account.version, 2);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).creditAppliedMinor, 0);
    assert((await f.rows('residentCreditEntries')).every(([, entry]) => entry.eventType === 'issued'));
  });
  for (const kind of ['proof', 'offline']) test(`${kind} retries preserve every financial effect, including after later revision`, async () => {
    const f = await fixture(environment, [kind === 'proof' ? 1300 : 1000]), p = kind === 'proof' ? await f.proof(1300) : null;
    if (p) await f.revision(1000); // Exact at preparation; later revision creates excess at approval.
    const execute = options => p ? p.approve(options) : f.pay({amountMinor: 1300}, options);
    const first = await execute(); const before = await f.financialState();
    const retry = await execute({now: () => now() + 5000});
    assert.equal(retry.alreadyCompleted, true); assert.equal(retry.transactionId, first.transactionId);
    assert.deepEqual(await f.financialState(), before);
    await f.revision(1200);
    assert.equal((await execute()).transactionId, first.transactionId);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).outstandingAmountMinor, 200);
  });
  test('changed idempotency amount, method, payer or reference fails closed', async () => {
    const f = await fixture(environment); await f.pay(); const before = await f.financialState();
    for (const changed of [{amountMinor: 999}, {paymentMethod: 'cheque'}, {residentId: 'other'}, {paymentReference: 'changed'}]) {
      await assert.rejects(f.pay(changed), /idempotency_conflict/);
    }
    assert.deepEqual(await f.financialState(), before);
  });
  test('move-out and replacement never change historical payment ownership', async () => {
    const f = await fixture(environment, [400]), p = await f.proof(400);
    await f.revision(1000);
    await f.patch('users/r', {isActive: false, status: 'moved_out', communityId: 'OTHER', flatId: null});
    await f.patch('flats/f', {residentUserId: 'replacement'});
    await p.approve(); await f.pay({amountMinor: 700});
    assert((await f.rows('paymentTransactions')).every(([, tx]) => tx.residentId === 'r'));
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].availableCreditMinor, 100);
  });
  for (const [name, changes] of [['paid', {paidAmountMinor: 1}], ['credit', {creditAppliedMinor: 1}],
    ['outstanding', {outstandingAmountMinor: 1}], ['liability', {amountMinor: 1100, chargeLines: lines(1100), outstandingAmountMinor: 1100}]]) {
    test(`${name} drift fails both paths without writes`, async () => {
      const f = await fixture(environment), p = await f.proof(); await f.patch(`bills/${f.bills[0]}`, changes);
      const before = await f.financialState(), bill = await f.get(`bills/${f.bills[0]}`);
      const reason = name === 'liability' ? /previous_bill_revision_mismatch/ : /ledger_projection_mismatch/;
      await assert.rejects(p.approve(), reason); await assert.rejects(f.pay(), reason);
      assert.deepEqual(await f.financialState(), before); assert.deepEqual(await f.get(`bills/${f.bills[0]}`), bill);
    });
  }
  for (const kind of ['proof', 'offline']) test(`${kind} injected failure rolls back proof, allocations, credit, account, bill and audit`, async () => {
    const f = await fixture(environment, [kind === 'proof' ? 1300 : 1000]), p = kind === 'proof' ? await f.proof(1300) : null;
    if (p) await f.revision(1000); // Exact at preparation; later revision creates excess at approval.
    const original = f.db.runTransaction.bind(f.db), before = await f.financialState(), bill = await f.get(`bills/${f.bills[0]}`);
    f.db.runTransaction = fn => original(async tx => {
      const create = tx.create.bind(tx);
      tx.create = (ref, value) => {const result = create(ref, value); if (ref.path.startsWith('residentCreditEntries/')) throw Error('injected failure'); return result;};
      return fn(tx);
    });
    try {await assert.rejects(p ? p.approve() : f.pay({amountMinor: 1300}), /injected failure/);} finally {f.db.runTransaction = original;}
    assert.deepEqual(await f.financialState(), before); assert.deepEqual(await f.get(`bills/${f.bills[0]}`), bill);
    if (p) assert.equal((await f.get(`paymentProofsV2/${p.paymentId}`)).status, 'pending');
    assert.equal((await (p ? p.approve() : f.pay({amountMinor: 1300}))).excessCreditMinor, 300);
  });
  test('allocation bound fails atomically and exactly the bound succeeds', async () => {
    const f = await fixture(environment, Array(MAX_ALLOCATIONS + 1).fill(1));
    await assert.rejects(f.pay({amountMinor: MAX_ALLOCATIONS + 1}), /split_payment_required/);
    assert((await f.financialState()).every(rows => rows.length === 0));
    assert.equal((await f.pay({amountMinor: MAX_ALLOCATIONS})).allocations.length, MAX_ALLOCATIONS);
  });
  for (const [label, instant, status] of [['due day', '2030-02-15T15:59:59.999Z', 'partially_paid'],
    ['next local midnight', '2030-02-15T16:00:00Z', 'overdue']]) test(`settlement ${label} uses local date and fully paid stays paid`, async () => {
    const f = await fixture(environment); const before = await f.get(`bills/${f.bills[0]}`);
    await f.pay({amountMinor: 400}, {now: () => Date.parse(instant)});
    assert.equal((await f.get(`bills/${f.bills[0]}`)).status, status);
    const p = await f.proof(600); await p.approve({now: () => Date.parse(instant)});
    const bill = await f.get(`bills/${f.bills[0]}`); assert.equal(bill.status, 'paid'); assert.deepEqual(bill.dueDate, before.dueDate);
  });
  test('Admin settlement excludes V1 and foreign bills and does not write V1 payments', async () => {
    const f = await fixture(environment);
    const legacy = {communityId: 'C', residentId: 'r', amount: 100, status: 'pending'};
    const foreign = {...await f.get(`bills/${f.bills[0]}`), residentId: 'other'};
    await f.ref('bills/legacy').set(legacy); await f.ref('bills/foreign').set(foreign);
    await f.pay({amountMinor: 1300});
    assert.deepEqual(await f.get('bills/legacy'), legacy); assert.deepEqual(await f.get('bills/foreign'), foreign);
    assert.equal((await f.rows('payments')).length, 0);
  });
  test('unauthorized, inactive and Super Admin cannot approve or record V2 money', async () => {
    const f = await fixture(environment), p = await f.proof(); const original = await f.get('admins/a');
    for (const change of [{isActive: false}, {role: 'superAdmin'}, {authorizedCommunityIds: ['OTHER']}]) {
      await f.ref('admins/a').set({...original, ...change});
      await assert.rejects(f.pay(), {code: 'permission-denied'}); await assert.rejects(p.approve(), {code: 'permission-denied'});
    }
    await f.ref('admins/a').set(original); await f.patch('communities/C', {isActive: false});
    await assert.rejects(f.pay(), {code: 'failed-precondition'}); await assert.rejects(p.approve(), {code: 'failed-precondition'});
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('preparation and offline requests reject forged balances, overdue and unsupported methods', async () => {
    const f = await fixture(environment, [400]), p = await f.proof(400);
    await f.revision(1000);
    for (const extra of [{outstandingAmountMinor: 2}, {isOverdue: false}, {amountMinor: 0}, {amountMinor: 0.1},
      {amountMinor: Number.MAX_SAFE_INTEGER + 1}, {paymentMethod: 'manual'}, {paymentMethod: 'upi'}]) await assert.rejects(f.pay(extra), {code: 'invalid-argument'});
    await assert.rejects(prepare({db: f.db, auth: {uid: 'other'}, now, data: p.data}));
    await assert.rejects(prepare({db: f.db, auth: {uid: 'r'}, now, data: {...p.data, submittedAt: now()}}), {code: 'invalid-argument'});
    await assert.rejects(prepare({db: f.db, auth: {uid: 'r'}, now, data: {...p.data, submittedAmountMinor: 500}}), /idempotency_conflict/);
    const retry = await prepare({db: f.db, auth: {uid: 'r'}, now, data: p.data}); assert.equal(retry.paymentId, p.paymentId);
    assert.equal((await f.rows('paymentProofsV2')).length, 1);
  });
  test('missing and cross-context receipts never settle', async () => {
    const f = await fixture(environment), p = await f.proof();
    await assert.rejects(p.approve({bucket: {file: () => ({getMetadata: async () => {throw Object.assign(Error('missing'), {code: 404});}})}}), /does not exist/);
    await f.patch(`paymentProofsV2/${p.paymentId}`, {receiptPath: 'https://invalid/private-receipt'});
    await assert.rejects(p.approve(), /Receipt path/);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('receipt metadata must match proof identity, size, generation and MIME type', async () => {
    const f = await fixture(environment), p = await f.proof();
    const metadata = {name: p.receiptPath, generation: '123', size: '10', contentType: 'image/jpeg',
      metadata: {paymentId: p.paymentId, billId: f.bills[0], communityId: 'C', residentUid: 'r'}};
    for (const changes of [{size: '0'}, {size: '10485760'}, {size: 'NaN'}, {generation: null}, {contentType: 'text/plain'},
      {name: 'other'}, {metadata: {...metadata.metadata, residentUid: 'other'}}, {metadata: {...metadata.metadata, paymentId: 'other'}}]) {
      await assert.rejects(p.approve({bucket: {name: 'test', file: () => ({getMetadata: async () => [{...metadata, ...changes}]})}}), /Receipt object/);
    }
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('proof intent drift after approval and immutable event drift both reject retry', async () => {
    const f = await fixture(environment), p = await f.proof(); const result = await p.approve();
    await f.patch(`paymentProofsV2/${p.paymentId}`, {submittedAmountMinor: 900});
    await assert.rejects(p.approve(), /idempotency_conflict/);
    await f.patch(`paymentProofsV2/${p.paymentId}`, {submittedAmountMinor: 1000});
    await f.patch(`paymentTransactions/${result.transactionId}`, {amountMinor: 900});
    await assert.rejects(p.approve(), /immutable_financial_conflict/);
    assert.equal((await f.rows('paymentAllocations')).length, 1);
  });
  test('foreign financial events pointing at a bill and account drift fail closed', async () => {
    const f = await fixture(environment); await f.pay({amountMinor: 400});
    const [allocationId, allocation] = (await f.rows('paymentAllocations'))[0];
    await f.patch(`paymentAllocations/${allocationId}`, {residentId: 'other'});
    await assert.rejects(f.pay({idempotencyKey: 'next'}), /invalid_financial_history/);
    await f.ref(`paymentAllocations/${allocationId}`).set(allocation);
    const accountId = (await f.rows('residentFinancialAccounts'))[0][0];
    await f.patch(`residentFinancialAccounts/${accountId}`, {availableCreditMinor: 100});
    await assert.rejects(f.pay({idempotencyKey: 'next'}), /account_projection_mismatch/);
    assert.equal((await f.rows('paymentTransactions')).length, 1);
  });
  test('missing current immutable bill revision blocks settlement', async () => {
    const f = await fixture(environment), p = await f.proof();
    await f.ref(`bills/${f.bills[0]}/revisions/revision_1`).delete();
    await assert.rejects(f.pay(), /previous_bill_revision_mismatch/); await assert.rejects(p.approve(), /previous_bill_revision_mismatch/);
    assert((await f.financialState()).every(rows => rows.length === 0));
  });
  test('simultaneous same-key offline retries commit exactly once', async () => {
    const f = await fixture(environment);
    const results = await Promise.all([f.pay({amountMinor: 1300}), f.pay({amountMinor: 1300})]);
    assert.equal(results[0].transactionId, results[1].transactionId); assert.equal((await f.rows('paymentTransactions')).length, 1);
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].version, 1); assert.equal((await f.rows('residentCreditEntries')).length, 1);
  });
  test('simultaneous proof and offline payments serialize account and cannot overallocate a bill', async () => {
    const f = await fixture(environment, [600]), p = await f.proof(600);
    await f.revision(1000);
    await Promise.all([p.approve(), f.pay({amountMinor: 600})]);
    assert.equal((await f.get(`bills/${f.bills[0]}`)).paidAmountMinor, 1000);
    const account = (await f.rows('residentFinancialAccounts'))[0][1]; assert.equal(account.availableCreditMinor, 200); assert.equal(account.version, 2);
    assert.equal((await f.rows('paymentTransactions')).length, 2);
  });
  test('concurrent settlement and recurring bill issuance serialize credit and liabilities on the resident account', async () => {
    const f = await fixture(environment, [500]);
    const secondBillId = monthlyBillIdV2('C', 'f', '2030-02');
    const results = await Promise.all([
      f.pay({amountMinor: 1000, idempotencyKey: 'issue-race-payment'}),
      issue({db: f.db, auth, now: () => Date.parse('2030-02-15T00:00:00Z'),
        data: {communityId: 'C', scope: 'community', billingPeriod: '2030-02',
          idempotencyKey: 'issue-race-february', chargeLines: lines(700), dueDate: '2030-03-15'}}),
    ]);
    assert.equal(results[0].transactionId != null, true);
    const january = await f.get(`bills/${f.bills[0]}`), february = await f.get(`bills/${secondBillId}`);
    assert.equal(february.amountMinor, 700);
    for (const bill of [january, february]) {
      assert(bill.paidAmountMinor + bill.creditAppliedMinor <= bill.amountMinor);
      assert(bill.outstandingAmountMinor >= 0);
    }
    assert.equal(january.paidAmountMinor + february.paidAmountMinor +
      january.creditAppliedMinor + february.creditAppliedMinor, 1000);
    const account = await f.get(`residentFinancialAccounts/${ledger.residentFinancialAccountId({communityId: 'C', residentId: 'r'})}`);
    assert.equal(account.availableCreditMinor, 0);
    assert.equal((await f.rows('paymentTransactions')).length, 1);
  });
  test('simultaneous approval of the same proof creates exactly one payment and audit', async () => {
    const f = await fixture(environment, [1300]), p = await f.proof(1300);
    await f.revision(1000);
    const results = await Promise.all([p.approve(), p.approve()]);
    assert.equal(results[0].transactionId, results[1].transactionId);
    assert.equal(results.filter(r => r.alreadyCompleted).length, 1);
    for (const name of ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries', 'auditLogs']) {
      assert.equal((await f.rows(name)).length, 1);
    }
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].version, 1);
  });
  test('deterministic transaction collision outside the account query fails without overwriting history', async () => {
    const f = await fixture(environment);
    const sourceId = `settlement_v2_${createHash('sha256').update(JSON.stringify(['offline', 'C', 'offline'])).digest('hex')}`;
    const conflicting = ledger.buildPaymentTransaction({communityId: 'C', residentId: 'other', currency: 'INR',
      sourceType: 'admin_cash', sourceId, sourceState: 'received', method: 'cash', amountMinor: 1000, receivedAt: now(), createdAt: now()});
    await f.ref(`paymentTransactions/${conflicting.id}`).set(conflicting);
    const before = await f.financialState();
    await assert.rejects(f.pay(), /immutable_financial_conflict/);
    assert.deepEqual(await f.financialState(), before);
  });
  test('downward revision of a V2 payment preserves attribution and later payments retain the issued credit', async () => {
    const f = await fixture(environment); const first = await f.pay();
    assert.equal((await f.revision(800)).applied, 1);
    const bill = await f.get(`bills/${f.bills[0]}`); assert.equal(bill.paidAmountMinor, 800);
    const credits = await f.rows('residentCreditEntries');
    assert.equal(credits[0][1].transactionId, first.transactionId); assert.equal(credits[0][1].amountMinor, 200);
    const second = await f.pay({idempotencyKey: 'second', amountMinor: 100});
    assert.deepEqual(second.allocations, []); assert.equal(second.excessCreditMinor, 100);
    const account = (await f.rows('residentFinancialAccounts'))[0][1];
    assert.equal(account.availableCreditMinor, 300); assert.equal(account.version, 3);
  });
  test('credit-only payment for a resident without V2 liabilities retains every received minor unit', async () => {
    const f = await fixture(environment, []); const result = await f.pay({amountMinor: 500});
    assert.deepEqual(result.allocations, []); assert.equal(result.excessCreditMinor, 500);
    assert.equal((await f.rows('residentFinancialAccounts'))[0][1].availableCreditMinor, 500);
  });
}
module.exports = {paymentCases, fixture, auth, now};
