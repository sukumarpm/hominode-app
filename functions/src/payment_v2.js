const {createHash} = require('node:crypto');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin} = require('./resident_identity');
const {buildAuditLog} = require('./audit_log');
const {validateChargeLines, monthlyBillIdV2} = require('./billing_batch');
const {assertV2SettlementReady} = require('./billing_revision');
const ledger = require('./billing_v2_ledger');

const MAX_ALLOCATIONS = 20;
const MAX_ACCOUNT_BILLS = 200;
const MAX_HISTORY_DOCUMENTS = 2000;
const METHODS = {cash: 'admin_cash', bank_transfer: 'bank_transfer', cheque: 'cheque'};
const EXTENSIONS = ['jpg', 'jpeg', 'png', 'heic', 'heif'];
const stamp = () => FieldValue.serverTimestamp();
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const fail = (message, code = 'failed-precondition') => {throw new RegistrationError(code, message);};
const check = (condition, message) => {if (!condition) fail(message);};
const validId = value => typeof value === 'string' && value.length > 0 && value === value.trim() &&
  Buffer.byteLength(value, 'utf8') <= 128 && !/[\/\u0000-\u001f\u007f]/.test(value) &&
  !['.', '..'].includes(value) && !/^__.*__$/.test(value) && Buffer.from(value).toString() === value;
function id(value) {if (!validId(value)) fail('Invalid identifier.', 'invalid-argument'); return value;}
function input(data, allowed) {
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !allowed.includes(key))) {
    fail('Unexpected V2 payment fields.', 'invalid-argument');
  }
}
function amount(value) {
  if (!Number.isSafeInteger(value) || value <= 0) fail('A positive safe integer amountMinor is required.', 'invalid-argument');
  return value;
}
function reference(value) {
  if (value == null) return null;
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 200) fail('Invalid payment reference.', 'invalid-argument');
  return value.trim();
}
function authUid(auth) {if (!validId(auth?.uid)) fail('Authentication is required.', 'unauthenticated'); return auth.uid;}
const rootDocs = (snapshot, name) => snapshot.docs.filter(doc => doc.ref.path === `${name}/${doc.id}`);
function overdue(bill, nowMs) {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {timeZone: bill.timeZone, calendar: 'gregory', numberingSystem: 'latn',
      year: 'numeric', month: '2-digit', day: '2-digit'}).formatToParts(new Date(nowMs));
    const date = Object.fromEntries(parts.map(part => [part.type, part.value]));
    return `${date.year.padStart(4, '0')}-${date.month}-${date.day}` > bill.dueDateKey;
  } catch (_) {fail('Invalid bill due-date context.');}
}
function projection(bill, billId, history, nowMs) {
  return ledger.calculateBillProjection({amountMinor: bill.amountMinor, currency: 'INR',
    paidAmountMinor: history.payments.paidByBill[billId] || 0,
    creditAppliedMinor: history.credits.creditAppliedByBill[billId] || 0, isOverdue: overdue(bill, nowMs)});
}
async function liability(db, tx, doc, scope) {
  const bill = doc.data(), billId = doc.id;
  check(bill?.schemaVersion === 2 && bill.currency === 'INR' && bill.billingKind === 'recurring' &&
    bill.communityId === scope.communityId && bill.residentId === scope.residentId &&
    ['billingBatchId', 'currentRevisionId', 'flatId', 'buildingId'].every(key => validId(bill[key])) &&
    typeof bill.billingPeriod === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(bill.billingPeriod) &&
    billId === monthlyBillIdV2(scope.communityId, bill.flatId, bill.billingPeriod) &&
    (bill.userId == null || bill.userId === scope.residentId), 'bill_identity_mismatch');
  const batch = (await tx.get(db.collection('billingBatches').doc(bill.billingBatchId))).data();
  assertV2SettlementReady({bill, batch, billingBatchId: bill.billingBatchId});
  check(batch.currency === 'INR' && batch.billingPeriod === bill.billingPeriod && batch.revisionNo === bill.revisionNo,
    'bill_batch_mismatch');
  const previous = (await tx.get(db.collection(`bills/${billId}/revisions`).doc(bill.currentRevisionId))).data();
  check(previous?.schemaVersion === 2 && previous.billId === billId && previous.revisionId === bill.currentRevisionId &&
    ['billingBatchId', 'communityId', 'residentId', 'flatId', 'buildingId', 'currency', 'billingKind', 'billingPeriod',
      'revisionNo', 'amountMinor', 'appliedBatchRevisionId', 'dueDateKey', 'timeZone'].every(key => previous[key] != null && previous[key] === bill[key]) &&
    Number.isSafeInteger(bill.revisionNo) && bill.revisionNo > 0 &&
    bill.dueDate instanceof Timestamp && previous.dueDate instanceof Timestamp && bill.dueDate.isEqual(previous.dueDate) &&
    typeof bill.dueDateKey === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(bill.dueDateKey) &&
    typeof bill.timeZone === 'string' && !!bill.timeZone && bill.createdAt instanceof Timestamp,
  'previous_bill_revision_mismatch');
  try {
    const a = validateChargeLines(bill.chargeLines), b = validateChargeLines(previous.chargeLines);
    check(a.amountMinor === bill.amountMinor && b.amountMinor === previous.amountMinor &&
      JSON.stringify(a.chargeLines) === JSON.stringify(b.chargeLines), 'previous_bill_revision_mismatch');
  } catch (_) {fail('previous_bill_revision_mismatch');}
  return {bill, billId, ref: doc.ref};
}
function financialDocs(snapshot, name, scope) {
  return rootDocs(snapshot, name).map(doc => {
    const value = doc.data();
    check(value.id === doc.id && value.schemaVersion === 2 && value.communityId === scope.communityId &&
      value.residentId === scope.residentId && value.currency === scope.currency, 'invalid_financial_history');
    return value;
  });
}
function summarize(scope, transactions, allocations, credits) {
  try {
    return {payments: ledger.summarizeAllocations({...scope, transactions, events: allocations}),
      credits: ledger.summarizeCreditEntries({...scope, entries: credits})};
  } catch (_) {fail('invalid_financial_history');}
}
async function historyFor(db, tx, scope) {
  const events = {};
  for (const name of ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries']) {
    events[name] = financialDocs(await tx.get(db.collection(name).where('communityId', '==', scope.communityId)
      .where('residentId', '==', scope.residentId).limit(MAX_HISTORY_DOCUMENTS + 1)), name, scope);
    check(events[name].length <= MAX_HISTORY_DOCUMENTS, 'financial_history_limit: account reconciliation is required');
  }
  const history = summarize(scope, events.paymentTransactions, events.paymentAllocations, events.residentCreditEntries);
  const accountRef = db.collection('residentFinancialAccounts').doc(ledger.residentFinancialAccountId(scope));
  const account = (await tx.get(accountRef)).data();
  if (account) {
    check(account.schemaVersion === 2 && account.id === accountRef.id && account.communityId === scope.communityId &&
      account.residentId === scope.residentId && account.currency === scope.currency &&
      Number.isSafeInteger(account.version) && account.version >= 0 && Number.isSafeInteger(account.version + 1), 'invalid_financial_account');
    check(account.availableCreditMinor === history.credits.availableCreditMinor, 'account_projection_mismatch');
  } else check(history.credits.availableCreditMinor === 0, 'account_projection_mismatch');
  return {...history, ...events, accountRef, account};
}
async function verifyProjection(db, tx, entry, scope, history, nowMs) {
  for (const name of ['paymentAllocations', 'residentCreditEntries']) {
    const events = financialDocs(await tx.get(db.collection(name).where('billId', '==', entry.billId)
      .limit(MAX_HISTORY_DOCUMENTS + 1)), name, scope);
    check(events.length <= MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  }
  const expected = projection(entry.bill, entry.billId, history, nowMs);
  check(['paidAmountMinor', 'creditAppliedMinor', 'outstandingAmountMinor'].every(key => expected[key] === entry.bill[key]),
    'ledger_projection_mismatch');
  return {...entry, outstandingAmountMinor: expected.outstandingAmountMinor};
}
function proofContext(proof, paymentId) {
  check(proof?.schemaVersion === 2 && proof.id === paymentId && proof.provider === 'direct_upi' && proof.method === 'upi' &&
    proof.verificationMode === 'manual' && proof.evidenceType === 'receipt' && proof.currency === 'INR' &&
    ['billId', 'communityId', 'residentId', 'submittedBillRevisionId'].every(key => validId(proof[key])) &&
    proof.userId === proof.residentId && Number.isSafeInteger(proof.submittedAmountMinor) && proof.submittedAmountMinor > 0 &&
    proof.submittedAt instanceof Timestamp, 'invalid_v2_proof');
  const prefix = `payment_receipts/${proof.communityId}/${proof.billId}/${proof.residentId}/${paymentId}`;
  check(EXTENSIONS.some(extension => proof.receiptPath === `${prefix}.${extension}`), 'Receipt path does not match this proof.');
  return {paymentId, billId: proof.billId, communityId: proof.communityId, residentId: proof.residentId,
    amountMinor: proof.submittedAmountMinor, submittedBillRevisionId: proof.submittedBillRevisionId,
    submittedAt: proof.submittedAt.toMillis(), receiptPath: proof.receiptPath, paymentReference: reference(proof.paymentReference)};
}
async function receiptEvidence(bucket, proof) {
  let metadata;
  try {[metadata] = await bucket.file(proof.receiptPath).getMetadata();} catch (error) {
    if (Number(error.code) === 404) fail('The submitted receipt object does not exist.');
    throw error;
  }
  const context = metadata.metadata || {};
  check(metadata.name === proof.receiptPath && metadata.generation && Number.isFinite(Number(metadata.size)) &&
    Number(metadata.size) > 0 && Number(metadata.size) < 10 * 1024 * 1024 &&
    /^image\/(jpeg|jpg|png|heic|heif)$/.test(metadata.contentType || '') && context.paymentId === proof.id &&
    context.billId === proof.billId && context.communityId === proof.communityId && context.residentUid === proof.residentId,
  'Receipt object does not match the submitted payment evidence.');
  // Storage receipt paths are create-only. Pin the exact evidence generation.
  return {receiptGeneration: String(metadata.generation), receiptBucket: bucket.name};
}

// Preparation captures the payment intent before the resident uploads evidence.
// V2 proofs are deliberately outside payments, so V1 review cannot process them.
async function preparePaymentProofV2Core({db, auth, data, now = Date.now}) {
  const uid = authUid(auth);
  input(data, ['billId', 'submittedAmountMinor', 'submittedBillRevisionId', 'idempotencyKey', 'receiptExtension', 'paymentReference']);
  const request = {billId: id(data.billId), submittedAmountMinor: amount(data.submittedAmountMinor),
    submittedBillRevisionId: id(data.submittedBillRevisionId), idempotencyKey: id(data.idempotencyKey),
    receiptExtension: data.receiptExtension, paymentReference: reference(data.paymentReference)};
  if (!EXTENSIONS.includes(request.receiptExtension)) fail('Invalid receipt extension.', 'invalid-argument');
  const paymentId = `proof_v2_${hash([uid, request.idempotencyKey])}`;
  const ref = db.collection('paymentProofsV2').doc(paymentId);
  return db.runTransaction(async tx => {
    const existing = (await tx.get(ref)).data();
    if (existing) {
      check(existing.residentId === uid && existing.requestHash === hash(request), 'idempotency_conflict');
      return {paymentId, receiptPath: existing.receiptPath, status: existing.status};
    }
    const doc = await tx.get(db.collection('bills').doc(request.billId)), bill = doc.data();
    check(bill?.residentId === uid, 'Bill does not belong to this resident.');
    const resident = (await tx.get(db.collection('users').doc(uid))).data();
    const community = (await tx.get(db.collection('communities').doc(id(bill.communityId)))).data();
    check(resident?.uid === uid && resident.role === 'resident' && community?.isActive === true, 'Resident/community is unavailable.');
    const scope = {communityId: bill.communityId, residentId: uid, currency: 'INR'};
    const entry = await liability(db, tx, doc, scope), history = await historyFor(db, tx, scope);
    const nowMs = now();
    const checked = await verifyProjection(db, tx, entry, scope, history, nowMs);
    check(bill.currentRevisionId === request.submittedBillRevisionId, 'Bill revision changed; refresh before preparing payment.');
    check(checked.outstandingAmountMinor > 0, 'This bill has no outstanding liability.');
    const receiptPath = `payment_receipts/${scope.communityId}/${request.billId}/${uid}/${paymentId}.${request.receiptExtension}`;
    tx.create(ref, {schemaVersion: 2, id: paymentId, ...scope, userId: uid, billId: request.billId,
      submittedAmountMinor: request.submittedAmountMinor, submittedBillRevisionId: request.submittedBillRevisionId,
      submittedAt: Timestamp.fromMillis(nowMs), provider: 'direct_upi', method: 'upi', verificationMode: 'manual',
      evidenceType: 'receipt', status: 'pending', receiptPath, paymentReference: request.paymentReference, requestHash: hash(request)});
    return {paymentId, receiptPath, status: 'pending'};
  });
}
function eventWrites(record) {
  return [{collection: 'paymentTransactions', event: record.transaction},
    ...record.allocationEvents.map(event => ({collection: 'paymentAllocations', event})),
    ...record.creditEntries.map(event => ({collection: 'residentCreditEntries', event}))];
}
async function retrySettlement(db, tx, existing, request) {
  check(existing.requestHash === hash(request), 'idempotency_conflict');
  for (const {collection, event} of eventWrites(existing)) {
    const saved = (await tx.get(db.collection(collection).doc(event.id))).data();
    check(!!saved, 'incomplete_settlement_history');
    try {ledger.assertImmutableRetry(saved, event);} catch (_) {fail('immutable_financial_conflict');}
  }
  return {...existing.result, alreadyCompleted: true};
}
function audit(uid, scope, transaction, plan) {
  return buildAuditLog({actorUid: uid, actorRole: 'admin', communityId: scope.communityId,
    action: transaction.method === 'upi' ? 'payment_v2.verify' : 'payment_v2.offline', targetType: 'paymentTransaction',
    targetId: transaction.id, summary: 'V2 payment settled', metadata: {transactionId: transaction.id, residentId: scope.residentId,
      amountMinor: transaction.amountMinor, allocatedBillIds: plan.allocations.map(a => a.billId),
      allocatedAmountsMinor: plan.allocations.map(a => String(a.amountMinor)), excessCreditMinor: plan.unallocatedAmountMinor,
      paymentMethod: transaction.method, paymentReference: transaction.reference}});
}
async function settle(db, tx, {scope, request, source, entries, history, recordRef, uid, nowMs, proofRef, evidence}) {
  const plan = ledger.planPaymentAllocations({...scope, amountMinor: request.amountMinor, liabilities: entries.map(entry => ({
    ...scope, billId: entry.billId, schemaVersion: 2, eligible: true, issued: true, outstandingAmountMinor: entry.outstandingAmountMinor,
    billingPeriod: entry.bill.billingPeriod, dueDateMs: entry.bill.dueDate.toMillis(), createdAtMs: entry.bill.createdAt.toMillis(),
  }))});
  check(plan.allocations.length <= MAX_ALLOCATIONS, `split_payment_required: at most ${MAX_ALLOCATIONS} bill allocations per payment`);
  const transaction = ledger.buildPaymentTransaction({...scope, ...source, amountMinor: request.amountMinor,
    reference: request.paymentReference, receivedAt: nowMs, createdAt: nowMs});
  const allocationEvents = plan.allocations.map(a => ledger.buildAllocationEvent({...scope, ...a, transactionId: transaction.id,
    eventType: 'allocation', sourceType: 'payment_allocation', sourceId: transaction.id, createdAt: nowMs}));
  const creditEntries = plan.unallocatedAmountMinor ? [ledger.buildCreditEntry({...scope, eventType: 'issued', sourceType: 'payment_excess',
    sourceId: transaction.id, transactionId: transaction.id, amountMinor: plan.unallocatedAmountMinor, createdAt: nowMs})] : [];
  const next = summarize(scope, [...history.paymentTransactions, transaction], [...history.paymentAllocations, ...allocationEvents],
    [...history.residentCreditEntries, ...creditEntries]);
  const result = {success: true, transactionId: transaction.id, allocations: plan.allocations,
    excessCreditMinor: plan.unallocatedAmountMinor, alreadyCompleted: false};
  const record = {schemaVersion: 2, requestHash: hash(request), transaction, allocationEvents, creditEntries, result,
    createdBy: uid, createdAt: Timestamp.fromMillis(nowMs)};
  // Every deterministic document is checked before any write. An orphan record
  // cannot be imported as a fresh receipt of money or applied a second time.
  for (const {collection, event} of eventWrites(record)) {
    const existing = (await tx.get(db.collection(collection).doc(event.id))).data();
    if (existing) {
      try {ledger.assertImmutableRetry(existing, event);} catch (_) {fail('immutable_financial_conflict');}
      fail('orphan_financial_source');
    }
  }
  const auditRef = db.collection('auditLogs').doc(recordRef.id);
  check(!(await tx.get(auditRef)).exists, 'immutable_audit_conflict');
  const auditEntry = audit(uid, scope, transaction, plan);
  const updates = plan.allocations.map(a => {
    const entry = entries.find(e => e.billId === a.billId);
    return {ref: entry.ref, value: projection(entry.bill, entry.billId, next, nowMs)};
  });
  for (const {collection, event} of eventWrites(record)) tx.create(db.collection(collection).doc(event.id), event);
  // Always serialize settlements on the account, even when no excess is issued.
  const account = {...(history.account || ledger.buildResidentFinancialAccount({...scope, createdAt: nowMs})),
    availableCreditMinor: next.credits.availableCreditMinor, version: (history.account?.version || 0) + 1, updatedAt: nowMs};
  if (history.account) tx.update(history.accountRef, account); else tx.create(history.accountRef, account);
  for (const update of updates) tx.update(update.ref, {...update.value, updatedAt: stamp()});
  if (proofRef) tx.update(proofRef, {status: 'completed', transactionId: transaction.id, ...evidence,
    reviewedBy: uid, reviewedAt: stamp(), updatedAt: stamp()});
  tx.create(recordRef, record);
  tx.create(auditRef, auditEntry);
  return result;
}
async function verifyPaymentProofV2Core({db, bucket, auth, data, now = Date.now}) {
  input(data, ['paymentId']); const paymentId = id(data.paymentId);
  const proofRef = db.collection('paymentProofsV2').doc(paymentId);
  return db.runTransaction(async tx => {
    const proof = (await tx.get(proofRef)).data();
    if (!proof) fail('V2 proof was not found.', 'not-found');
    const request = proofContext(proof, paymentId);
    const {uid} = await requireOperationalAdmin(db, auth, proof.communityId, tx);
    const recordRef = db.collection('paymentSettlementsV2').doc(`settlement_v2_${hash(['proof', paymentId])}`);
    const existing = (await tx.get(recordRef)).data();
    if (existing) {
      check(proof.status === 'completed' && proof.transactionId === existing.transaction.id, 'proof_settlement_mismatch');
      return retrySettlement(db, tx, existing, request);
    }
    check(proof.status === 'pending', 'Only pending V2 proofs can be approved.');
    const scope = {communityId: proof.communityId, residentId: proof.residentId, currency: 'INR'};
    const entry = await liability(db, tx, await tx.get(db.collection('bills').doc(proof.billId)), scope);
    const history = await historyFor(db, tx, scope), nowMs = now();
    const checked = await verifyProjection(db, tx, entry, scope, history, nowMs);
    const evidence = await receiptEvidence(bucket, proof);
    return settle(db, tx, {scope, request, source: {sourceType: 'direct_upi_proof', sourceId: paymentId, sourceState: 'approved', method: 'upi'},
      entries: [checked], history, recordRef, uid, nowMs, proofRef, evidence});
  });
}
async function rejectPaymentProofV2Core({db, auth, data}) {
  input(data, ['paymentId', 'rejectionReason']); const paymentId = id(data.paymentId);
  if (typeof data.rejectionReason !== 'string' || !data.rejectionReason.trim() || data.rejectionReason.trim().length > 1000) {
    fail('A rejection reason is required.', 'invalid-argument');
  }
  return db.runTransaction(async tx => {
    const ref = db.collection('paymentProofsV2').doc(paymentId), proof = (await tx.get(ref)).data();
    check(proof?.schemaVersion === 2 && validId(proof.communityId), 'V2 proof was not found.');
    const {uid} = await requireOperationalAdmin(db, auth, proof.communityId, tx);
    check(proof.status === 'pending', 'Only pending V2 proofs can be rejected.');
    tx.update(ref, {status: 'failed', rejectionReason: data.rejectionReason.trim(), reviewedBy: uid, reviewedAt: stamp(), updatedAt: stamp()});
    return {success: true, paymentId};
  });
}
async function recordOfflinePaymentV2Core({db, auth, data, now = Date.now}) {
  input(data, ['communityId', 'residentId', 'amountMinor', 'paymentMethod', 'paymentReference', 'idempotencyKey']);
  const request = {communityId: id(data.communityId), residentId: id(data.residentId), amountMinor: amount(data.amountMinor),
    paymentMethod: data.paymentMethod, paymentReference: reference(data.paymentReference), idempotencyKey: id(data.idempotencyKey)};
  if (!Object.hasOwn(METHODS, request.paymentMethod)) fail('Choose cash, bank_transfer or cheque.', 'invalid-argument');
  const scope = {communityId: request.communityId, residentId: request.residentId, currency: 'INR'};
  // Key scope deliberately excludes method/resident/amount so changed terms
  // cannot accidentally turn a retry into another payment.
  const recordRef = db.collection('paymentSettlementsV2').doc(`settlement_v2_${hash(['offline', scope.communityId, request.idempotencyKey])}`);
  return db.runTransaction(async tx => {
    const {uid} = await requireOperationalAdmin(db, auth, scope.communityId, tx);
    const existing = (await tx.get(recordRef)).data();
    if (existing) return retrySettlement(db, tx, existing, request);
    const resident = (await tx.get(db.collection('users').doc(scope.residentId))).data();
    check(resident?.uid === scope.residentId && resident.role === 'resident', 'Invalid resident financial account.');
    const docs = rootDocs(await tx.get(db.collection('bills').where('schemaVersion', '==', 2)
      .where('communityId', '==', scope.communityId).where('residentId', '==', scope.residentId).limit(MAX_ACCOUNT_BILLS + 1)), 'bills');
    check(docs.length <= MAX_ACCOUNT_BILLS, 'account_liability_limit: too many bills for an atomic settlement');
    const history = await historyFor(db, tx, scope), nowMs = now(), entries = [];
    check(docs.length > 0 || history.account || resident.communityId === scope.communityId, 'Resident does not belong to this financial account.');
    for (const doc of docs) entries.push(await verifyProjection(db, tx, await liability(db, tx, doc, scope), scope, history, nowMs));
    return settle(db, tx, {scope, request, source: {sourceType: METHODS[request.paymentMethod], sourceId: recordRef.id,
      sourceState: 'received', method: request.paymentMethod}, entries, history, recordRef, uid, nowMs});
  });
}
module.exports = {preparePaymentProofV2Core, verifyPaymentProofV2Core, rejectPaymentProofV2Core, recordOfflinePaymentV2Core, MAX_ALLOCATIONS};
