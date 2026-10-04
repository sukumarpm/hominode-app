const {Timestamp} = require('firebase-admin/firestore');
const {RegistrationError, verifiedPhoneAuth} = require('./register_resident');
const {validateChargeLines, monthlyBillIdV2} = require('./billing_batch');
const {assertV2SettlementReady} = require('./billing_revision');
const ledger = require('./billing_v2_ledger');

const PERIOD_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const MAX_ACCOUNT_BILLS = 200;
const MAX_HISTORY_DOCUMENTS = 2000;
const METHODS = new Set(['upi', 'cash', 'bank_transfer', 'cheque']);
const fail = (reason, code = 'failed-precondition') => {
  throw new RegistrationError(code, `resident_billing_v2_statement_${reason}`);
};
const check = (condition, reason, code) => {if (!condition) fail(reason, code);};

function validId(value) {
  return typeof value === 'string' && value.length > 0 && value === value.trim() &&
    Buffer.byteLength(value, 'utf8') <= 128 && !/[\/\u0000-\u001f\u007f]/.test(value) &&
    !['.', '..'].includes(value) && !/^__.*__$/.test(value) && Buffer.from(value).toString() === value;
}

function parseInput(auth, data) {
  const identity = verifiedPhoneAuth(auth);
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => key !== 'billingPeriod') ||
      typeof data.billingPeriod !== 'string' || !PERIOD_PATTERN.test(data.billingPeriod)) {
    fail('invalid_request', 'invalid-argument');
  }
  return {residentId: identity.uid, billingPeriod: data.billingPeriod};
}

function rootDocs(snapshot, name) {
  return snapshot.docs.filter(doc => doc.ref.path === `${name}/${doc.id}`);
}

function cappedRootRows(snapshot, collection, max, reason) {
  const docs = rootDocs(snapshot, collection);
  check(docs.length <= max, reason);
  return docs.map(doc => {
    const value = doc.data();
    check(value?.id === doc.id && value.schemaVersion === 2, 'invalid_financial_history');
    return value;
  });
}

function uniqueHistory(primary, linked, collection) {
  const byId = new Map();
  for (const value of [...primary, ...linked]) {
    const existing = byId.get(value.id);
    if (existing) {
      try {ledger.assertImmutableRetry(existing, value);} catch (_) {fail(`invalid_${collection}`);}
    } else byId.set(value.id, value);
  }
  return [...byId.values()];
}

function validateResident(resident, communityId, residentId) {
  check(resident?.uid === residentId && resident.role === 'resident' &&
    resident.communityId === communityId && resident.isActive === true &&
    resident.approvalStatus === 'approved' && resident.status === 'active' &&
    (resident.occupancyStatus == null || resident.occupancyStatus === 'current'), 'resident_unavailable', 'permission-denied');
  check(validId(resident.communityId), 'invalid_resident_identity');
}

function localDateKey(nowMs, timeZone) {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {timeZone, calendar: 'gregory', numberingSystem: 'latn',
      year: 'numeric', month: '2-digit', day: '2-digit'}).formatToParts(new Date(nowMs));
    const date = Object.fromEntries(parts.map(part => [part.type, part.value]));
    return `${date.year.padStart(4, '0')}-${date.month}-${date.day}`;
  } catch (_) {fail('invalid_bill_due_context');}
}

function validateContext(value, scope, reason = 'invalid_financial_history') {
  check(value?.communityId === scope.communityId && value.residentId === scope.residentId &&
    value.currency === 'INR', reason);
}

async function readHistoryCollection(db, name, scope) {
  const snapshot = await db.collection(name).where('residentId', '==', scope.residentId)
    .limit(MAX_HISTORY_DOCUMENTS + 1).get();
  const rows = cappedRootRows(snapshot, name, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  for (const row of rows) validateContext(row, scope);
  return rows;
}

async function readLinkedEvents(db, collection, billIds, scope) {
  const rows = [];
  for (let offset = 0; offset < billIds.length; offset += 30) {
    const chunk = billIds.slice(offset, offset + 30);
    const billIdSet = new Set(chunk);
    const snapshot = await db.collection(collection).where('billId', 'in', chunk)
      .limit(MAX_HISTORY_DOCUMENTS + 1).get();
    const linked = cappedRootRows(snapshot, collection, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
    for (const event of linked) {
      validateContext(event, scope);
      check(billIdSet.has(event.billId), 'invalid_financial_history');
    }
    rows.push(...linked);
    check(rows.length <= MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  }
  return rows;
}

async function validateBill(db, doc, scope, nowMs, history) {
  const bill = doc.data();
  check(bill?.schemaVersion === 2 && bill.currency === 'INR' && bill.billingKind === 'recurring' &&
    bill.communityId === scope.communityId && bill.residentId === scope.residentId &&
    (bill.userId == null || bill.userId === scope.residentId) &&
    validId(doc.id) && validId(bill.flatId) && validId(bill.buildingId) &&
    validId(bill.billingBatchId) && validId(bill.currentRevisionId) &&
    typeof bill.billingPeriod === 'string' && PERIOD_PATTERN.test(bill.billingPeriod) &&
    bill.dueDate instanceof Timestamp && bill.createdAt instanceof Timestamp &&
    typeof bill.dueDateKey === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(bill.dueDateKey) &&
    typeof bill.timeZone === 'string' && !!bill.timeZone &&
    Number.isSafeInteger(bill.revisionNo) && bill.revisionNo > 0 &&
    doc.id === monthlyBillIdV2(scope.communityId, bill.flatId, bill.billingPeriod), 'invalid_bill_document');
  for (const field of ['amountMinor', 'paidAmountMinor', 'creditAppliedMinor', 'outstandingAmountMinor']) {
    check(Number.isSafeInteger(bill[field]) && bill[field] >= 0, 'invalid_bill_amounts');
  }

  const batchSnapshot = await db.collection('billingBatches').doc(bill.billingBatchId).get();
  const batch = batchSnapshot.data();
  check(batchSnapshot.exists && batch?.schemaVersion === 2 && batch.communityId === scope.communityId &&
    batch.currency === 'INR' && batch.billingPeriod === bill.billingPeriod &&
    batch.revisionNo === bill.revisionNo && batch.currentRevisionId === bill.appliedBatchRevisionId,
  'bill_batch_mismatch');
  try {assertV2SettlementReady({bill, batch, billingBatchId: bill.billingBatchId});}
  catch (_) {fail('bill_batch_mismatch');}

  const revisionSnapshot = await db.collection(`bills/${doc.id}/revisions`).doc(bill.currentRevisionId).get();
  const revision = revisionSnapshot.data();
  check(revisionSnapshot.exists && revision?.schemaVersion === 2 && revision.billId === doc.id &&
    revision.revisionId === bill.currentRevisionId && revision.billingBatchId === bill.billingBatchId &&
    revision.communityId === scope.communityId && revision.residentId === scope.residentId &&
    revision.flatId === bill.flatId && revision.buildingId === bill.buildingId &&
    revision.billingKind === 'recurring' && revision.billingPeriod === bill.billingPeriod &&
    revision.revisionNo === bill.revisionNo && revision.appliedBatchRevisionId === bill.appliedBatchRevisionId &&
    revision.currency === 'INR' && revision.amountMinor === bill.amountMinor &&
    revision.dueDateKey === bill.dueDateKey && revision.timeZone === bill.timeZone &&
    revision.dueDate instanceof Timestamp && revision.dueDate.isEqual(bill.dueDate), 'bill_revision_mismatch');
  let billLines, revisionLines;
  try {
    billLines = validateChargeLines(bill.chargeLines);
    revisionLines = validateChargeLines(revision.chargeLines);
  } catch (_) {fail('invalid_bill_charge_lines');}
  check(billLines.amountMinor === bill.amountMinor && revisionLines.amountMinor === bill.amountMinor &&
    JSON.stringify(billLines.chargeLines) === JSON.stringify(revisionLines.chargeLines), 'bill_revision_mismatch');

  const expected = ledger.calculateBillProjection({amountMinor: bill.amountMinor,
    paidAmountMinor: history.payments.paidByBill[doc.id] || 0,
    creditAppliedMinor: history.credits.creditAppliedByBill[doc.id] || 0,
    currency: 'INR', isOverdue: localDateKey(nowMs, bill.timeZone) > bill.dueDateKey});
  const nonOverdueStatus = ledger.calculateBillProjection({amountMinor: bill.amountMinor,
    paidAmountMinor: history.payments.paidByBill[doc.id] || 0,
    creditAppliedMinor: history.credits.creditAppliedByBill[doc.id] || 0,
    currency: 'INR', isOverdue: false}).status;
  const storedStatusMayBeBeforeDueDateTransition = expected.status === 'overdue' &&
    bill.status === nonOverdueStatus;
  check(bill.paidAmountMinor === expected.paidAmountMinor &&
    bill.creditAppliedMinor === expected.creditAppliedMinor &&
    bill.outstandingAmountMinor === expected.outstandingAmountMinor &&
    ['pending', 'partially_paid', 'paid', 'overdue'].includes(bill.status) &&
    (bill.status === expected.status || storedStatusMayBeBeforeDueDateTransition),
  'ledger_projection_mismatch');
  return {bill, billId: doc.id, projection: expected, chargeLines: billLines.chargeLines};
}

function settlementRows(billId, allocations, transactions) {
  const byTransaction = new Map();
  const transactionMap = new Map(transactions.map(transaction => [transaction.id, transaction]));
  for (const allocation of allocations) {
    if (allocation.billId !== billId || allocation.remainingAmountMinor === 0) continue;
    const transaction = transactionMap.get(allocation.transactionId);
    check(!!transaction, 'invalid_financial_history');
    byTransaction.set(transaction.id, (byTransaction.get(transaction.id) || 0n) + BigInt(allocation.remainingAmountMinor));
  }
  return [...byTransaction].map(([transactionId, amount]) => {
    const transaction = transactionMap.get(transactionId);
    check(METHODS.has(transaction.method) && Number.isSafeInteger(transaction.receivedAt) &&
      transaction.receivedAt >= 0 && (transaction.reference == null || typeof transaction.reference === 'string'),
    'invalid_financial_history');
    check(amount > 0n && amount <= BigInt(Number.MAX_SAFE_INTEGER), 'invalid_financial_history');
    return {transactionId, method: transaction.method, reference: transaction.reference ?? null,
      receivedAt: transaction.receivedAt, netAppliedMinor: Number(amount)};
  }).sort((a, b) => a.receivedAt - b.receivedAt || a.transactionId.localeCompare(b.transactionId));
}

async function getResidentBillingV2StatementCore({db, auth, data, now = Date.now}) {
  const input = parseInput(auth, data);
  const userSnapshot = await db.collection('users').doc(input.residentId).get();
  const resident = userSnapshot.data();
  check(userSnapshot.exists, 'resident_unavailable', 'permission-denied');
  const communityId = resident?.communityId;
  check(validId(communityId), 'invalid_resident_identity', 'permission-denied');
  validateResident(resident, communityId, input.residentId);
  const communitySnapshot = await db.collection('communities').doc(communityId).get();
  const community = communitySnapshot.data();
  check(communitySnapshot.exists && community?.isActive === true, 'community_unavailable', 'permission-denied');

  const nowMs = now();
  check(Number.isSafeInteger(nowMs) && nowMs >= 0 && nowMs <= 8640000000000000, 'invalid_now');
  const scope = {communityId, residentId: input.residentId, currency: 'INR'};
  const billSnapshot = await db.collection('bills').where('schemaVersion', '==', 2)
    .where('communityId', '==', communityId).where('residentId', '==', input.residentId)
    .limit(MAX_ACCOUNT_BILLS + 1).get();
  const billDocs = rootDocs(billSnapshot, 'bills');
  check(billDocs.length <= MAX_ACCOUNT_BILLS, 'account_bill_limit');

  const [transactions, accountAllocations, accountCredits] = await Promise.all([
    readHistoryCollection(db, 'paymentTransactions', scope),
    readHistoryCollection(db, 'paymentAllocations', scope),
    readHistoryCollection(db, 'residentCreditEntries', scope),
  ]);
  const billIds = billDocs.map(doc => doc.id);
  const [linkedAllocations, linkedCredits] = await Promise.all([
    readLinkedEvents(db, 'paymentAllocations', billIds, scope),
    readLinkedEvents(db, 'residentCreditEntries', billIds, scope),
  ]);
  const allocationEvents = uniqueHistory(accountAllocations, linkedAllocations, 'paymentAllocations');
  const creditEntries = uniqueHistory(accountCredits, linkedCredits, 'residentCreditEntries');

  let payments, credits;
  try {
    payments = ledger.summarizeAllocations({...scope, transactions, events: allocationEvents});
    credits = ledger.summarizeCreditEntries({...scope, entries: creditEntries});
  } catch (_) {fail('invalid_financial_history');}

  const accountId = ledger.residentFinancialAccountId(scope);
  const accountSnapshot = await db.collection('residentFinancialAccounts').doc(accountId).get();
  const account = accountSnapshot.data();
  let availableCreditMinor = 0;
  if (accountSnapshot.exists) {
    check(account?.id === accountId && account.schemaVersion === 2 && account.communityId === communityId &&
      account.residentId === input.residentId && account.currency === 'INR' &&
      Number.isSafeInteger(account.version) && account.version >= 0 &&
      Number.isSafeInteger(account.availableCreditMinor) && account.availableCreditMinor >= 0 &&
      Number.isSafeInteger(account.createdAt) && account.createdAt >= 0 &&
      Number.isSafeInteger(account.updatedAt) && account.updatedAt >= account.createdAt,
    'invalid_financial_account');
    check(account.availableCreditMinor === credits.availableCreditMinor, 'account_projection_mismatch');
    availableCreditMinor = account.availableCreditMinor;
  } else check(credits.availableCreditMinor === 0, 'account_projection_mismatch');

  const history = {payments, credits};
  const validatedBills = [];
  for (const doc of billDocs) validatedBills.push(await validateBill(db, doc, scope, nowMs, history));
  const statementBills = validatedBills.filter(item => item.bill.billingPeriod === input.billingPeriod)
    .sort((a, b) => a.bill.dueDateKey.localeCompare(b.bill.dueDateKey) ||
      a.bill.createdAt.toMillis() - b.bill.createdAt.toMillis() || a.billId.localeCompare(b.billId));

  const summary = {billsCount: 0, billedMinor: 0n, paidAllocationMinor: 0n, creditAppliedMinor: 0n,
    outstandingMinor: 0n, availableCreditMinor,
    statusCounts: {pending: 0, partially_paid: 0, paid: 0, overdue: 0}};
  const bills = statementBills.map(({bill, billId, projection, chargeLines}) => {
    summary.billsCount++;
    summary.billedMinor += BigInt(projection.amountMinor);
    summary.paidAllocationMinor += BigInt(projection.paidAmountMinor);
    summary.creditAppliedMinor += BigInt(projection.creditAppliedMinor);
    summary.outstandingMinor += BigInt(projection.outstandingAmountMinor);
    summary.statusCounts[projection.status]++;
    return {billId, billingPeriod: bill.billingPeriod, amountMinor: projection.amountMinor,
      paidAllocationMinor: projection.paidAmountMinor, creditAppliedMinor: projection.creditAppliedMinor,
      outstandingMinor: projection.outstandingAmountMinor, status: projection.status,
      dueDateKey: bill.dueDateKey, chargeLines,
      settlements: settlementRows(billId, payments.remainingAllocations, transactions)};
  });
  for (const key of ['billedMinor', 'paidAllocationMinor', 'creditAppliedMinor', 'outstandingMinor']) {
    check(summary[key] <= BigInt(Number.MAX_SAFE_INTEGER), 'financial_total_overflow');
    summary[key] = Number(summary[key]);
  }

  return {success: true, schemaVersion: 1, communityId, residentId: input.residentId,
    billingPeriod: input.billingPeriod, generatedAtMs: nowMs, summary, bills};
}

module.exports = {getResidentBillingV2StatementCore, MAX_ACCOUNT_BILLS, MAX_HISTORY_DOCUMENTS};
