// Resident-facing, read-only receipt projection over immutable Billing V2
// settlement and ledger records. This module never creates financial records.
const {RegistrationError, verifiedPhoneAuth} = require('./register_resident');
const ledger = require('./billing_v2_ledger');

const MAX_EVENTS = 2000;
const METHODS = new Set(['upi', 'cash', 'bank_transfer', 'cheque']);
const fail = (reason, code = 'failed-precondition') => {
  throw new RegistrationError(code, `resident_billing_v2_receipt_${reason}`);
};
const check = (condition, reason, code) => {if (!condition) fail(reason, code);};

function validId(value) {
  return typeof value === 'string' && value.length > 0 && value === value.trim() &&
    Buffer.byteLength(value, 'utf8') <= 128 && !/[\/\u0000-\u001f\u007f]/.test(value) &&
    !['.', '..'].includes(value) && !/^__.*__$/.test(value) && Buffer.from(value).toString() === value;
}

function parseRequest(auth, data) {
  const identity = verifiedPhoneAuth(auth);
  check(data && typeof data === 'object' && !Array.isArray(data) &&
    Object.keys(data).length === 1 && Object.keys(data)[0] === 'transactionId' &&
    validId(data.transactionId), 'invalid_request', 'invalid-argument');
  return {residentId: identity.uid, transactionId: data.transactionId};
}

function rootRows(snapshot, collection) {
  return snapshot.docs.filter(doc => doc.ref.path === `${collection}/${doc.id}`);
}

function assertScope(value, scope) {
  check(value?.schemaVersion === 2 && value.communityId === scope.communityId &&
    value.residentId === scope.residentId && value.currency === 'INR', 'invalid_financial_history');
}

function timestampMillis(value) {
  const millis = value && typeof value.toMillis === 'function' ? value.toMillis() : null;
  check(Number.isSafeInteger(millis) && millis >= 0 && millis <= 8640000000000000,
    'invalid_financial_history');
  return millis;
}

async function readAdjustments(db, transaction, scope, settlement) {
  const {allocationsSnapshot, creditSnapshot} = await db.runTransaction(async tx => {
    const allocationsQuery = db.collection('paymentAllocations')
      .where('transactionId', '==', transaction.id).limit(MAX_EVENTS + 1);
    const creditQuery = db.collection('residentCreditEntries')
      .where('transactionId', '==', transaction.id).limit(MAX_EVENTS + 1);
    const [allocations, credits] = await Promise.all([tx.get(allocationsQuery), tx.get(creditQuery)]);
    return {allocationsSnapshot: allocations, creditSnapshot: credits};
  });
  const allocations = rootRows(allocationsSnapshot, 'paymentAllocations');
  const credits = rootRows(creditSnapshot, 'residentCreditEntries');
  check(allocations.length <= MAX_EVENTS && credits.length <= MAX_EVENTS, 'financial_history_limit');
  const laterReversals = [];
  const laterCredits = [];
  for (const doc of allocations) {
    const event = doc.data();
    assertScope(event, scope);
    try { ledger.assertImmutableRetry(event, ledger.buildAllocationEvent(event)); }
    catch (_) { fail('invalid_financial_history'); }
    check(event.transactionId === transaction.id, 'invalid_financial_history');
    if (event.eventType === 'reversal') laterReversals.push(event);
  }
  try {
    ledger.summarizeAllocations({...scope, transactions: [transaction],
      events: [...settlement.allocationEvents, ...allocations.map(doc => doc.data())]});
  } catch (_) { fail('invalid_financial_history'); }
  for (const doc of credits) {
    const event = doc.data();
    assertScope(event, scope);
    try { ledger.assertImmutableRetry(event, ledger.buildCreditEntry(event)); }
    catch (_) { fail('invalid_financial_history'); }
    check(event.transactionId === transaction.id, 'invalid_financial_history');
    if (event.sourceType === 'bill_revision' && event.eventType === 'issued') laterCredits.push(event);
  }
  try {
    ledger.summarizeCreditEntries({...scope,
      entries: [...settlement.creditEntries, ...credits.map(doc => doc.data())]});
  } catch (_) { fail('invalid_financial_history'); }
  return {
    reversedAllocationMinor: sum(laterReversals.map(event => event.amountMinor)),
    revisionCreditIssuedMinor: sum(laterCredits.map(event => event.amountMinor)),
  };
}

function sum(values) {
  let total = 0n;
  for (const value of values) {
    check(Number.isSafeInteger(value) && value >= 0, 'invalid_financial_history');
    total += BigInt(value);
  }
  check(total <= BigInt(Number.MAX_SAFE_INTEGER), 'invalid_financial_history');
  return Number(total);
}

async function getResidentBillingV2ReceiptCore({db, auth, data}) {
  const input = parseRequest(auth, data);
  const userSnapshot = await db.collection('users').doc(input.residentId).get();
  const resident = userSnapshot.data();
  check(userSnapshot.exists && resident?.uid === input.residentId && resident.role === 'resident' &&
    resident.isActive === true && resident.approvalStatus === 'approved' && resident.status === 'active' &&
    (resident.occupancyStatus == null || resident.occupancyStatus === 'current') && validId(resident.communityId),
  'resident_unavailable', 'permission-denied');
  const scope = {communityId: resident.communityId, residentId: input.residentId, currency: 'INR'};
  const communitySnapshot = await db.collection('communities').doc(scope.communityId).get();
  const community = communitySnapshot.data();
  check(communitySnapshot.exists && community?.isActive === true, 'community_unavailable', 'permission-denied');

  const matches = await db.collection('paymentSettlementsV2').where('transaction.id', '==', input.transactionId)
    .limit(2).get();
  const settlementDocs = rootRows(matches, 'paymentSettlementsV2');
  check(settlementDocs.length === 1, 'settlement_not_found', 'not-found');
  const settlementDoc = settlementDocs[0];
  const settlement = settlementDoc.data();
  check(settlement?.schemaVersion === 2 && settlement.transaction?.id === input.transactionId,
    'invalid_settlement');
  const transaction = settlement.transaction;
  // Hide existence and tenant details from a different active resident account.
  check(transaction.communityId === scope.communityId && transaction.residentId === scope.residentId,
    'receipt_unavailable', 'permission-denied');
  assertScope(transaction, scope);
  check(METHODS.has(transaction.method) && Number.isSafeInteger(transaction.amountMinor) &&
    transaction.amountMinor > 0 && Number.isSafeInteger(transaction.receivedAt) && transaction.receivedAt >= 0,
  'invalid_settlement');

  // A V2 settlement is the only source for an official receipt. Proof-backed
  // settlements additionally require the authoritative proof to remain completed.
  if (transaction.sourceType === 'direct_upi_proof') {
    const proofSnapshot = await db.collection('paymentProofsV2').doc(transaction.sourceId).get();
    const proof = proofSnapshot.data();
    check(proofSnapshot.exists && proof.schemaVersion === 2 && proof.status === 'completed' &&
      proof.transactionId === transaction.id && proof.residentId === scope.residentId &&
      proof.communityId === scope.communityId &&
      proof.submittedAmountMinor === settlement.claimedAmountMinor &&
      proof.confirmedAmountMinor === (settlement.confirmedAmountMinor ?? transaction.amountMinor) &&
      proof.amountMismatch === settlement.amountMismatch, 'proof_not_settled', 'failed-precondition');
  } else {
    check(['admin_cash', 'bank_transfer', 'cheque'].includes(transaction.sourceType), 'invalid_settlement');
  }

  const transactionSnapshot = await db.collection('paymentTransactions').doc(transaction.id).get();
  check(transactionSnapshot.exists, 'invalid_settlement');
  try { ledger.assertImmutableRetry(transactionSnapshot.data(), transaction); }
  catch (_) { fail('invalid_settlement'); }

  check(Array.isArray(settlement.allocationEvents) && Array.isArray(settlement.creditEntries),
    'invalid_settlement');
  check(settlement.allocationEvents.every(event => event.eventType === 'allocation' &&
    event.transactionId === transaction.id), 'invalid_settlement');
  check(settlement.creditEntries.every(event => event.eventType === 'issued' &&
    event.sourceType === 'payment_excess' && event.sourceId === transaction.id &&
    event.transactionId === transaction.id && event.billId == null), 'invalid_settlement');
  const allocationSummary = ledger.summarizeAllocations({...scope, transactions: [transaction],
    events: settlement.allocationEvents});
  const allocations = settlement.allocationEvents.filter(event => event.eventType === 'allocation')
    .map(event => ({billId: event.billId, amountMinor: event.amountMinor,
      allocatedAt: event.createdAt}));
  const allocatedMinor = sum(allocations.map(item => item.amountMinor));
  const creditSummary = ledger.summarizeCreditEntries({...scope, entries: settlement.creditEntries});
  const excessCreditMinor = creditSummary.availableCreditMinor;
  const confirmedAmountMinor = settlement.confirmedAmountMinor ?? transaction.amountMinor;
  check(Number.isSafeInteger(confirmedAmountMinor) && confirmedAmountMinor > 0 &&
    confirmedAmountMinor === transaction.amountMinor &&
    BigInt(allocatedMinor) + BigInt(excessCreditMinor) === BigInt(confirmedAmountMinor),
  'settlement_reconciliation_failed');
  // Run the complete event validator even for transactions with no allocation.
  check(Object.values(allocationSummary.paidByBill).reduce((total, value) => total + value, 0) === allocatedMinor,
    'settlement_reconciliation_failed');

  const proofBacked = transaction.sourceType === 'direct_upi_proof';
  const verifiedAt = proofBacked ? timestampMillis(settlement.reviewedAt) : timestampMillis(settlement.createdAt);
  const communityNameValue = community.name ?? community.displayName ?? community.communityName;
  const communityName = typeof communityNameValue === 'string' && communityNameValue.trim()
    ? communityNameValue.trim() : null;
  const laterAdjustments = await readAdjustments(db, transaction, scope, settlement);
  return {
    success: true,
    schemaVersion: 1,
    receiptId: `HOMINODE-V2-${transaction.id}`,
    transactionId: transaction.id,
    community: {communityId: scope.communityId, name: communityName,
      address: typeof community.address === 'string' ? community.address : null},
    currency: 'INR',
    method: transaction.method,
    paymentReference: typeof transaction.reference === 'string' ? transaction.reference : null,
    receivedAt: transaction.receivedAt,
    moneyReceivedMinor: confirmedAmountMinor,
    confirmedAmountMinor,
    claimedAmountMinor: Number.isSafeInteger(settlement.claimedAmountMinor)
      ? settlement.claimedAmountMinor : null,
    amountMismatch: typeof settlement.amountMismatch === 'boolean' ? settlement.amountMismatch : null,
    confirmation: {status: 'verified', verifiedAt,
      verifiedBy: proofBacked ? 'Community Admin' : 'Recorded by Community Admin'},
    allocations,
    allocatedAmountMinor: allocatedMinor,
    excessCreditMinor,
    reconciliation: {confirmedAmountMinor, allocatedAmountMinor: allocatedMinor, excessCreditMinor},
    accountingBasis: {amountsAreMinorUnits: true, allocationsAreFromThisPayment: true,
      existingCreditApplicationsExcluded: true},
    snapshot: 'original_settlement',
    laterAdjustments,
  };
}

module.exports = {getResidentBillingV2ReceiptCore};
