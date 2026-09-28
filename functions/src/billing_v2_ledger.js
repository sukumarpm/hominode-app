// Internal, pure accounting primitives. No database handles, clocks, callable
// registration, or V1 imports. Times in these internal records are explicit UTC
// epoch milliseconds. A future writer must atomically create immutable events
// and update the resident account/version and bill projections in a transaction.
const {createHash} = require('node:crypto');

function fail(message) {
  const error = new Error(message);
  error.code = 'invalid-argument';
  throw error;
}
function documentId(value) {
  if (typeof value !== 'string' || !value || value !== value.trim() ||
      Buffer.byteLength(value, 'utf8') > 128 || /[\/\u0000-\u001f\u007f]/.test(value) ||
      ['.', '..'].includes(value) || /^__.*__$/.test(value) || Buffer.from(value).toString() !== value) {
    fail('Invalid financial document/source identifier.');
  }
  return value;
}
function money(value, positive = false) {
  if (!Number.isSafeInteger(value) || value < (positive ? 1 : 0)) fail('Money must be a safe nonnegative integer in minor units.');
  return value;
}
function safeMoney(value) {
  if (value < 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) fail('Financial total is negative or exceeds the safe integer range.');
  return Number(value);
}
function time(value) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 8640000000000000) fail('An explicit valid UTC epoch millisecond timestamp is required.');
  return value;
}
function context(value) {
  if (!value || value.currency !== 'INR') fail('The ledger requires INR currency.');
  return {communityId: documentId(value.communityId), residentId: documentId(value.residentId), currency: 'INR'};
}
function sameContext(a, b) {
  const left = context(a), right = context(b);
  if (Object.keys(left).some(key => left[key] !== right[key])) fail('Financial account/currency mismatch.');
}
function source(value) {
  const sourceType = value.sourceType;
  if (typeof sourceType !== 'string' || !/^[a-z][a-z0-9_]{0,63}$/.test(sourceType)) fail('Invalid financial source type.');
  return [sourceType, documentId(value.sourceId)];
}
function id(prefix, parts) {
  return `${prefix}_${createHash('sha256').update(JSON.stringify(parts)).digest('hex')}`;
}
function residentFinancialAccountId({communityId, residentId}) {
  return id('resident_account_v2', [documentId(communityId), documentId(residentId)]);
}
// The payer and amount deliberately do not affect the transaction ID. A retry
// with a changed payer/amount must conflict with the existing approved source.
function paymentTransactionId(value) {
  return id('payment_v2', [documentId(value.communityId), ...source(value)]);
}
function allocationEventId(value) {
  if (!['allocation', 'reversal'].includes(value.eventType)) fail('Invalid allocation event type.');
  const original = value.eventType === 'reversal' ? documentId(value.originalAllocationId) : null;
  return id('allocation_v2', [documentId(value.communityId), ...source(value), value.eventType,
    documentId(value.transactionId), documentId(value.billId), original]);
}
function creditEntryId(value) {
  if (!['issued', 'applied', 'restored'].includes(value.eventType)) fail('Invalid credit event type.');
  return id('credit_v2', [documentId(value.communityId), ...source(value), value.eventType,
    value.billId == null ? null : documentId(value.billId),
    value.allocationReversalId == null ? null : documentId(value.allocationReversalId),
    value.originalCreditEntryId == null ? null : documentId(value.originalCreditEntryId)]);
}

// Immutable source comparison ignores append time, which may differ on retry.
// receivedAt and every financial field remain part of the immutable contract.
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort()
    .filter(key => key !== 'createdAt').map(key => [key, canonical(value[key])]));
  return value;
}
function assertImmutableRetry(existing, proposed) {
  if (JSON.stringify(canonical(existing)) !== JSON.stringify(canonical(proposed))) {
    fail('The financial source already exists with different immutable terms.');
  }
  return existing;
}
function uniqueEvents(events, validate) {
  if (!Array.isArray(events)) fail('An explicit complete event history is required.');
  const result = new Map();
  for (const event of events) {
    validate(event);
    if (result.has(event.id)) assertImmutableRetry(result.get(event.id), event);
    else result.set(event.id, event);
  }
  return [...result.values()];
}

function calculateBillProjection({amountMinor, paidAmountMinor, creditAppliedMinor, currency, isOverdue}) {
  if (currency !== 'INR' || typeof isOverdue !== 'boolean') fail('INR and an explicit trusted overdue flag are required.');
  money(amountMinor); money(paidAmountMinor); money(creditAppliedMinor);
  const difference = BigInt(amountMinor) - BigInt(paidAmountMinor) - BigInt(creditAppliedMinor);
  const outstandingAmountMinor = safeMoney(difference > 0n ? difference : 0n);
  const status = outstandingAmountMinor === 0 ? 'paid' : isOverdue ? 'overdue' :
    paidAmountMinor > 0 || creditAppliedMinor > 0 ? 'partially_paid' : 'pending';
  return Object.freeze({schemaVersion: 2, currency, amountMinor, paidAmountMinor, creditAppliedMinor, outstandingAmountMinor, status});
}

function buildResidentFinancialAccount(value) {
  const scope = context(value);
  const createdAt = time(value.createdAt);
  return Object.freeze({schemaVersion: 2, id: residentFinancialAccountId(scope), ...scope,
    availableCreditMinor: 0, version: 0, createdAt, updatedAt: createdAt});
}

const PAYMENT_METHODS = Object.freeze({direct_upi_proof: 'upi', admin_cash: 'cash', bank_transfer: 'bank_transfer', cheque: 'cheque'});
function buildPaymentTransaction(value) {
  const scope = context(value);
  const [sourceType, sourceId] = source(value);
  if (!Object.hasOwn(PAYMENT_METHODS, sourceType) || PAYMENT_METHODS[sourceType] !== value.method ||
      !['approved', 'received'].includes(value.sourceState) ||
      (sourceType === 'direct_upi_proof' && value.sourceState !== 'approved')) {
    fail('Only recognized approved/received sources can represent a payment transaction.');
  }
  const reference = value.reference == null ? null : value.reference;
  if (reference !== null && (typeof reference !== 'string' || reference.length > 200 || !reference.trim())) fail('Invalid payment reference.');
  return Object.freeze({schemaVersion: 2, id: paymentTransactionId(value), ...scope,
    amountMinor: money(value.amountMinor, true), method: value.method, sourceType, sourceId,
    sourceState: value.sourceState, reference, receivedAt: time(value.receivedAt), createdAt: time(value.createdAt)});
}
function validatePayment(event, scope) {
  sameContext(event, scope);
  if (event.schemaVersion !== 2) fail('Expected a V2 payment transaction.');
  assertImmutableRetry(event, buildPaymentTransaction(event));
}

function buildAllocationEvent(value) {
  const scope = context(value);
  const [sourceType, sourceId] = source(value);
  const originalAllocationId = value.eventType === 'reversal' ? documentId(value.originalAllocationId) : null;
  if (value.eventType === 'allocation' && value.originalAllocationId != null) fail('An allocation cannot reverse another event.');
  return Object.freeze({schemaVersion: 2, id: allocationEventId(value), ...scope,
    transactionId: documentId(value.transactionId), billId: documentId(value.billId),
    eventType: value.eventType, direction: value.eventType === 'allocation' ? 'increase' : 'decrease',
    amountMinor: money(value.amountMinor, true), sourceType, sourceId, originalAllocationId,
    createdAt: time(value.createdAt)});
}

// The full account history and received transactions are required. Reversals
// are checked per original allocation, not merely against the bill's net total.
function summarizeAllocations({communityId, residentId, currency, transactions, events}) {
  const scope = context({communityId, residentId, currency});
  const payments = new Map(uniqueEvents(transactions, event => validatePayment(event, scope)).map(event => [event.id, event]));
  const entries = uniqueEvents(events, event => {
    sameContext(event, scope);
    assertImmutableRetry(event, buildAllocationEvent(event));
    if (!payments.has(event.transactionId)) fail('Allocation references an unknown received payment transaction.');
  });
  const originals = new Map(entries.filter(event => event.eventType === 'allocation').map(event => [event.id, event]));
  const reversed = new Map();
  for (const event of entries.filter(item => item.eventType === 'reversal')) {
    const original = originals.get(event.originalAllocationId);
    if (!original || original.transactionId !== event.transactionId || original.billId !== event.billId) fail('Reversal must reference its original allocation in this account/bill.');
    reversed.set(original.id, (reversed.get(original.id) || 0n) + BigInt(event.amountMinor));
  }
  const byBill = new Map(), byTransaction = new Map();
  const remainingAllocations = [...originals.values()].map(event => {
    const remaining = BigInt(event.amountMinor) - (reversed.get(event.id) || 0n);
    const remainingAmountMinor = safeMoney(remaining);
    byBill.set(event.billId, (byBill.get(event.billId) || 0n) + remaining);
    byTransaction.set(event.transactionId, (byTransaction.get(event.transactionId) || 0n) + remaining);
    return {...event, remainingAmountMinor};
  });
  for (const [transactionId, amount] of byTransaction) {
    if (amount > BigInt(payments.get(transactionId).amountMinor)) fail('Net allocations exceed the received transaction amount.');
  }
  return {paidByBill: Object.fromEntries([...byBill].map(([key, value]) => [key, safeMoney(value)])), remainingAllocations};
}

function orderedLiabilities(scope, liabilities) {
  if (!Array.isArray(liabilities)) fail('Liabilities must be an array of trusted issued descriptors.');
  const ids = new Set();
  const result = liabilities.map(bill => {
    sameContext(bill, scope);
    documentId(bill.billId);
    if (ids.has(bill.billId)) fail('Duplicate bill ID.');
    ids.add(bill.billId);
    if (![1, 2].includes(bill.schemaVersion) || bill.eligible !== true || bill.issued !== true ||
        typeof bill.billingPeriod !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(bill.billingPeriod)) fail('Malformed or ineligible liability.');
    return {billId: bill.billId, outstandingAmountMinor: money(bill.outstandingAmountMinor),
      dueDateMs: time(bill.dueDateMs), billingPeriod: bill.billingPeriod, createdAtMs: time(bill.createdAtMs)};
  });
  const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
  return result.sort((a, b) => compare(a.dueDateMs, b.dueDateMs) || compare(a.billingPeriod, b.billingPeriod) ||
    compare(a.createdAtMs, b.createdAtMs) || compare(a.billId, b.billId));
}
function distribute(value, availableMinor) {
  const scope = context(value);
  let remainingMinor = money(availableMinor);
  const allocations = [];
  for (const bill of orderedLiabilities(scope, value.liabilities)) {
    const amountMinor = Math.min(remainingMinor, bill.outstandingAmountMinor);
    if (amountMinor > 0) allocations.push(Object.freeze({billId: bill.billId, amountMinor}));
    remainingMinor -= amountMinor;
  }
  return {allocations: Object.freeze(allocations), remainingMinor};
}
function planPaymentAllocations(value) {
  const {allocations, remainingMinor} = distribute(value, value.amountMinor);
  return Object.freeze({allocations, unallocatedAmountMinor: remainingMinor});
}
function planCreditApplications(value) {
  const {allocations, remainingMinor} = distribute(value, value.availableCreditMinor);
  return Object.freeze({applications: allocations, remainingCreditMinor: remainingMinor});
}

function buildCreditEntry(value) {
  const scope = context(value);
  const [sourceType, sourceId] = source(value);
  const eventType = value.eventType;
  const billId = value.billId == null ? null : documentId(value.billId);
  const transactionId = value.transactionId == null ? null : documentId(value.transactionId);
  const revisionId = value.revisionId == null ? null : documentId(value.revisionId);
  const allocationReversalId = value.allocationReversalId == null ? null : documentId(value.allocationReversalId);
  const originalCreditEntryId = value.originalCreditEntryId == null ? null : documentId(value.originalCreditEntryId);
  if (eventType === 'issued') {
    if (!transactionId || originalCreditEntryId ||
        !((sourceType === 'payment_excess' && sourceId === transactionId && !billId && !revisionId && !allocationReversalId) ||
          (sourceType === 'bill_revision' && sourceId === revisionId && billId && allocationReversalId))) fail('Issued credit needs a received-payment or allocation-reversal source.');
  } else if (eventType === 'applied') {
    if (sourceType !== 'credit_application' || !billId || transactionId || revisionId || allocationReversalId || originalCreditEntryId) fail('Applied credit needs a bill and application source.');
  } else if (eventType === 'restored') {
    if (sourceType !== 'bill_revision' || sourceId !== revisionId || !billId || !originalCreditEntryId || transactionId || allocationReversalId) fail('Restored credit must reference the original application and bill revision.');
  } else fail('Unsupported credit event.');
  return Object.freeze({schemaVersion: 2, id: creditEntryId(value), ...scope, eventType,
    direction: eventType === 'applied' ? 'decrease' : 'increase', amountMinor: money(value.amountMinor, true),
    sourceType, sourceId, billId, transactionId, revisionId, allocationReversalId, originalCreditEntryId,
    createdAt: time(value.createdAt)});
}

function summarizeCreditEntries({communityId, residentId, currency, entries}) {
  const scope = context({communityId, residentId, currency});
  const events = uniqueEvents(entries, event => {
    sameContext(event, scope); assertImmutableRetry(event, buildCreditEntry(event));
  });
  const applications = new Map(events.filter(event => event.eventType === 'applied').map(event => [event.id, event]));
  const restored = new Map();
  let available = 0n;
  for (const event of events) {
    available += BigInt(event.amountMinor) * (event.eventType === 'applied' ? -1n : 1n);
    if (event.eventType === 'restored') {
      const original = applications.get(event.originalCreditEntryId);
      if (!original || original.billId !== event.billId) fail('Restored credit must reference its original bill application.');
      restored.set(original.id, (restored.get(original.id) || 0n) + BigInt(event.amountMinor));
    }
  }
  const byBill = new Map();
  const remainingApplications = [...applications.values()].map(event => {
    const remaining = BigInt(event.amountMinor) - (restored.get(event.id) || 0n);
    const remainingAmountMinor = safeMoney(remaining);
    byBill.set(event.billId, (byBill.get(event.billId) || 0n) + remaining);
    return {...event, remainingAmountMinor};
  });
  return {availableCreditMinor: safeMoney(available),
    creditAppliedByBill: Object.fromEntries([...byBill].map(([key, amount]) => [key, safeMoney(amount)])), remainingApplications};
}

// Plans an immutable correction against complete, consistent account histories.
// Later writers must serialize on the account version and use create-only event
// writes. Deterministic IDs/deduplication alone are NOT a concurrency lock.
function planDownwardRevision(value) {
  const scope = context(value);
  const billId = documentId(value.billId), revisionId = documentId(value.revisionId);
  const originalAmountMinor = money(value.originalAmountMinor), revisedAmountMinor = money(value.revisedAmountMinor);
  if (revisedAmountMinor > originalAmountMinor) fail('Expected a downward or unchanged liability revision.');
  const createdAt = time(value.createdAt);
  const payments = summarizeAllocations({...scope, transactions: value.transactions, events: value.allocationEvents});
  const credits = summarizeCreditEntries({...scope, entries: value.creditEntries});
  const paidAmountMinor = payments.paidByBill[billId] || 0;
  const creditAppliedMinor = credits.creditAppliedByBill[billId] || 0;
  const excess = BigInt(paidAmountMinor) + BigInt(creditAppliedMinor) - BigInt(revisedAmountMinor);
  let remaining = excess > 0n ? safeMoney(excess) : 0;
  const allocationEvents = [], creditEntries = [];
  // Approved policy: restore excess applied credit first, retaining attribution
  // to its original application. Reverse payments only for the excess left over.
  const applications = credits.remainingApplications.filter(event => event.billId === billId)
    .sort((a, b) => b.createdAt - a.createdAt || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  for (const original of applications) {
    const amountMinor = Math.min(remaining, original.remainingAmountMinor);
    if (amountMinor === 0) continue;
    creditEntries.push(buildCreditEntry({...scope, eventType: 'restored', sourceType: 'bill_revision', sourceId: revisionId,
      billId, revisionId, originalCreditEntryId: original.id, amountMinor, createdAt}));
    remaining -= amountMinor;
  }
  // Preserve attribution by reversing the newest remaining allocation first;
  // stable ID breaks timestamp ties independently of caller array ordering.
  const originals = payments.remainingAllocations.filter(event => event.billId === billId)
    .sort((a, b) => b.createdAt - a.createdAt || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  for (const original of originals) {
    const amountMinor = Math.min(remaining, original.remainingAmountMinor);
    if (amountMinor === 0) continue;
    const reversal = buildAllocationEvent({...scope, eventType: 'reversal', sourceType: 'bill_revision', sourceId: revisionId,
      originalAllocationId: original.id, transactionId: original.transactionId, billId, amountMinor, createdAt});
    allocationEvents.push(reversal);
    creditEntries.push(buildCreditEntry({...scope, eventType: 'issued', sourceType: 'bill_revision', sourceId: revisionId,
      transactionId: original.transactionId, billId, revisionId, allocationReversalId: reversal.id, amountMinor, createdAt}));
    remaining -= amountMinor;
  }
  if (remaining !== 0) fail('Reconciliation exceeds remaining attributable payment allocations.');
  // Re-validate the combined history to catch source collisions/over-reversal.
  const nextPayments = summarizeAllocations({...scope, transactions: value.transactions, events: [...value.allocationEvents, ...allocationEvents]});
  const nextCredits = summarizeCreditEntries({...scope, entries: [...value.creditEntries, ...creditEntries]});
  return Object.freeze({billId, revisionId, allocationEvents: Object.freeze(allocationEvents), creditEntries: Object.freeze(creditEntries),
    projection: calculateBillProjection({amountMinor: revisedAmountMinor, paidAmountMinor: nextPayments.paidByBill[billId] || 0,
      creditAppliedMinor: nextCredits.creditAppliedByBill[billId] || 0, currency: scope.currency, isOverdue: value.isOverdue}),
    availableCreditMinor: nextCredits.availableCreditMinor});
}

module.exports = {residentFinancialAccountId, paymentTransactionId, allocationEventId, creditEntryId,
  assertImmutableRetry, calculateBillProjection, buildResidentFinancialAccount, buildPaymentTransaction,
  buildAllocationEvent, summarizeAllocations, planPaymentAllocations, buildCreditEntry,
  summarizeCreditEntries, planCreditApplications, planDownwardRevision};
