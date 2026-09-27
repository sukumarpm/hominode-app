const {FieldValue} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {buildAuditLog} = require('./audit_log');

const clean = value => typeof value === 'string' ? value.trim() : '';
const fail = (message, code = 'failed-precondition') => {throw new RegistrationError(code, message);};
function documentId(value) {
  if (typeof value !== 'string' || !value || value !== value.trim() || value.includes('/') || value.length > 128) {
    fail('A valid document ID is required.', 'invalid-argument');
  }
  return value;
}
function input(data, allowed) {
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !allowed.includes(key))) {
    fail('Unexpected payment request fields.', 'invalid-argument');
  }
}
function requireAuth(auth) {
  if (!clean(auth?.uid)) fail('Authentication is required.', 'unauthenticated');
  return auth.uid;
}
async function requireAuthorizedAdmin(db, transaction, uid, communityId) {
  documentId(communityId);
  const admin = (await transaction.get(db.collection('admins').doc(uid))).data();
  // Super Admin manages the platform; routine financial operations require a
  // community Admin profile and an explicit assignment, just like the rules.
  if (admin?.uid !== uid || admin.role !== 'admin' || admin.isActive !== true ||
      !Array.isArray(admin.authorizedCommunityIds) || !admin.authorizedCommunityIds.includes(communityId)) {
    fail('An authorized active community Admin is required.', 'permission-denied');
  }
  const community = await transaction.get(db.collection('communities').doc(communityId));
  if (!community.exists || community.data().isActive !== true) fail('The community is inactive or unavailable.');
}
function requireUnpaidBill(bill) {
  if (!bill || !['pending', 'overdue'].includes(bill.status) || bill.paymentId != null || bill.paidAt != null ||
      (bill.paidAmount != null && bill.paidAmount !== 0)) fail('This bill is not unsettled.');
  if (typeof bill.amount !== 'number' || !Number.isFinite(bill.amount) || bill.amount <= 0) fail('The bill amount is invalid.');
}
async function requirePayer(db, transaction, bill, uid) {
  documentId(uid); documentId(bill.flatId);
  const resident = (await transaction.get(db.collection('users').doc(uid))).data();
  const flat = (await transaction.get(db.collection('flats').doc(bill.flatId))).data();
  if (resident?.uid !== uid || resident.role !== 'resident' || resident.communityId !== bill.communityId ||
      resident.flatId !== bill.flatId || flat?.communityId !== bill.communityId ||
      (bill.buildingId != null && flat.buildingId !== bill.buildingId) ||
      ['residentId', 'userId'].some(key => bill[key] != null && bill[key] !== uid)) {
    fail('Payment payer and bill ownership do not match.');
  }
}
async function requireReceipt(bucket, paymentId, payment) {
  const path = payment.receiptPath;
  const prefix = `payment_receipts/${payment.communityId}/${payment.billId}/${payment.userId}/`;
  const extensions = ['jpg', 'jpeg', 'png', 'heic', 'heif'];
  if (!extensions.some(extension => path === `${prefix}${paymentId}.${extension}`)) {
    fail('The receipt path does not match this payment.');
  }
  let metadata;
  try {
    [metadata] = await bucket.file(path).getMetadata();
  } catch (error) {
    if (Number(error.code) === 404) fail('The submitted receipt object does not exist.');
    throw error;
  }
  const context = metadata.metadata || {};
  if (metadata.name !== path || !metadata.generation || Number(metadata.size) <= 0 ||
      !Number.isFinite(Number(metadata.size)) || Number(metadata.size) >= 10 * 1024 * 1024 ||
      !/^image\/(jpeg|jpg|png|heic|heif)$/.test(metadata.contentType || '') ||
      context.paymentId !== paymentId || context.billId !== payment.billId ||
      context.communityId !== payment.communityId || context.residentUid !== payment.userId) {
    fail('The receipt object does not match the submitted payment evidence.');
  }
  // Receipt paths are create-only in Storage rules: residents cannot replace or
  // delete evidence between this check and commit. Record the exact generation.
  return {receiptGeneration: String(metadata.generation), receiptBucket: bucket.name};
}
function appendAudit(db, transaction, {uid, communityId, paymentId, billId, action, amount}) {
  transaction.create(db.collection('auditLogs').doc(), buildAuditLog({
    actorUid: uid, actorRole: 'admin', communityId, action, targetType: 'payment', targetId: paymentId,
    summary: `Payment ${action.split('.').pop()}`, metadata: {billId, amount},
  }));
}
function settleBill(transaction, ref, payment, paymentId, uid) {
  transaction.update(ref, {
    status: 'paid', paidAmount: payment.amount, paymentMethod: payment.method,
    paymentReference: clean(payment.transactionId) || null, paymentId,
    settledBy: uid, paidAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
}
async function reviewPayment({db, bucket, auth, data}, rejecting) {
  const uid = requireAuth(auth);
  input(data, rejecting ? ['paymentId', 'rejectionReason'] : ['paymentId']);
  const paymentId = documentId(data.paymentId);
  const rejectionReason = clean(data.rejectionReason);
  if (rejecting && (!rejectionReason || rejectionReason.length > 1000)) fail('A valid rejection reason is required.', 'invalid-argument');
  const paymentRef = db.collection('payments').doc(paymentId);
  return db.runTransaction(async transaction => {
    const paymentSnapshot = await transaction.get(paymentRef);
    if (!paymentSnapshot.exists) fail('Payment submission was not found.', 'not-found');
    const payment = paymentSnapshot.data();
    await requireAuthorizedAdmin(db, transaction, uid, payment.communityId);
    const legacyProof = payment.method === 'external' &&
      !('provider' in payment) && !('verificationMode' in payment) && !('evidenceType' in payment);
    const directUpiProof = payment.provider === 'direct_upi' && payment.method === 'upi' &&
      payment.verificationMode === 'manual' && payment.evidenceType === 'receipt';
    if (payment.status !== 'pending' || (!legacyProof && !directUpiProof) || payment.id !== paymentId) {
      fail('Only pending payment-proof submissions can be reviewed.');
    }
    const billId = documentId(payment.billId);
    const billRef = db.collection('bills').doc(billId);
    const bill = (await transaction.get(billRef)).data();
    if (!bill || bill.communityId !== payment.communityId || bill.flatId !== payment.flatId) fail('Payment and bill scope do not match.');
    // A bad or missing receipt can be rejected; it can never settle a bill.
    // Rejection also remains possible for a duplicate proof after settlement.
    let evidence = {};
    if (!rejecting) {
      requireUnpaidBill(bill);
      if (typeof payment.amount !== 'number' || payment.amount !== bill.amount) fail('Payment amount does not match the bill amount.');
      await requirePayer(db, transaction, bill, payment.userId);
      evidence = await requireReceipt(bucket, paymentId, payment);
    }
    transaction.update(paymentRef, {
      status: rejecting ? 'failed' : 'completed',
      ...(rejecting ? {rejectionReason} : evidence),
      reviewedAt: FieldValue.serverTimestamp(), reviewedBy: uid, updatedAt: FieldValue.serverTimestamp(),
    });
    if (!rejecting) settleBill(transaction, billRef, payment, paymentId, uid);
    appendAudit(db, transaction, {uid, communityId: payment.communityId, paymentId, billId,
      action: rejecting ? 'payment.reject' : 'payment.verify', amount: payment.amount});
    return {success: true, paymentId, billId};
  });
}
const verifyPaymentProofCore = args => reviewPayment(args, false);
const rejectPaymentProofCore = args => reviewPayment(args, true);

async function recordManualPaymentCore({db, auth, data}) {
  const uid = requireAuth(auth);
  input(data, ['billId', 'paymentMethod', 'paymentReference']);
  const billId = documentId(data.billId);
  const method = clean(data.paymentMethod).toLowerCase();
  if (!['manual', 'cash', 'cheque', 'bank_transfer'].includes(method)) fail('An explicit offline payment method is required.', 'invalid-argument');
  if (data.paymentReference != null && (typeof data.paymentReference !== 'string' || data.paymentReference.length > 200)) {
    fail('Invalid payment reference.', 'invalid-argument');
  }
  const billRef = db.collection('bills').doc(billId);
  const paymentRef = db.collection('payments').doc();
  return db.runTransaction(async transaction => {
    const bill = (await transaction.get(billRef)).data();
    if (!bill) fail('Bill was not found.', 'not-found');
    await requireAuthorizedAdmin(db, transaction, uid, bill.communityId);
    requireUnpaidBill(bill);
    documentId(bill.flatId);
    const flat = (await transaction.get(db.collection('flats').doc(bill.flatId))).data();
    const payerUid = bill.residentId || bill.userId || flat?.residentUserId || flat?.residentUid;
    await requirePayer(db, transaction, bill, payerUid);
    const payment = {
      id: paymentRef.id, billId, communityId: bill.communityId, flatId: bill.flatId, userId: payerUid,
      amount: bill.amount, method, status: 'completed', evidenceType: 'admin_attestation',
      transactionId: clean(data.paymentReference) || null,
      recordedBy: uid, reviewedBy: uid, reviewedAt: FieldValue.serverTimestamp(),
      paymentDate: FieldValue.serverTimestamp(), createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.create(paymentRef, payment);
    settleBill(transaction, billRef, payment, paymentRef.id, uid);
    appendAudit(db, transaction, {uid, communityId: bill.communityId, paymentId: paymentRef.id, billId,
      action: 'payment.manual', amount: bill.amount});
    return {success: true, paymentId: paymentRef.id, billId};
  });
}
module.exports = {verifyPaymentProofCore, rejectPaymentProofCore, recordManualPaymentCore};
