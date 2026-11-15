const {Timestamp} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin} = require('./resident_identity');
const {localBillingPeriodFromMillis} = require('./billing_batch');
const ledger = require('./billing_v2_ledger');

const PERIOD_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const MAX_BILLS = 10000;
const MAX_HISTORY_DOCUMENTS = 20000;
const MAX_ACCOUNTS = 10000;
const METHODS = Object.freeze(['upi', 'cash', 'bank_transfer', 'cheque']);

const fail = (reason, code = 'failed-precondition') => {
  throw new RegistrationError(code, `billing_v2_financial_report_${reason}`);
};

function rootDocs(snapshot, collection) {
  return snapshot.docs.filter(doc => doc.ref.path === `${collection}/${doc.id}`);
}

function validId(value) {
  return typeof value === 'string' && value.length > 0 && value === value.trim() &&
    Buffer.byteLength(value, 'utf8') <= 128 && !/[\/\u0000-\u001f\u007f]/.test(value) &&
    !['.', '..'].includes(value) && !/^__.*__$/.test(value) && Buffer.from(value).toString() === value;
}

function parseInput(data) {
  const allowed = ['communityId', 'billingPeriod'];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !allowed.includes(key))) {
    fail('invalid_request', 'invalid-argument');
  }
  if (!validId(data.communityId) || typeof data.billingPeriod !== 'string' || !PERIOD_PATTERN.test(data.billingPeriod)) {
    fail('invalid_request', 'invalid-argument');
  }
  return {communityId: data.communityId, billingPeriod: data.billingPeriod};
}

function money(value, reason) {
  if (!Number.isSafeInteger(value) || value < 0) fail(reason);
  return value;
}

function safeMoney(value, reason) {
  if (value < 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) fail(reason);
  return Number(value);
}

function checkCount(rows, max, reason) {
  if (rows.length > max) fail(reason);
}

function isPastLocalDueDate(nowMs, bill) {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: bill.timeZone,
      calendar: 'gregory',
      numberingSystem: 'latn',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date(nowMs));
    const date = Object.fromEntries(parts.map(part => [part.type, part.value]));
    return `${date.year.padStart(4, '0')}-${date.month}-${date.day}` > bill.dueDateKey;
  } catch (_) {
    fail('invalid_bill_due_context');
  }
}

function validateBillDocument(doc, communityId, billingPeriod) {
  const bill = doc.data();
  if (bill?.schemaVersion !== 2 || bill.billingPeriod !== billingPeriod) return null;
  if (bill.communityId !== communityId || bill.currency !== 'INR' || bill.billingKind !== 'recurring' ||
      !validId(doc.id) || !validId(bill.residentId) || !validId(bill.flatId) || !validId(bill.buildingId) ||
      typeof bill.timeZone !== 'string' || !bill.timeZone || typeof bill.dueDateKey !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}$/.test(bill.dueDateKey) || !(bill.dueDate instanceof Timestamp) ||
      !['pending', 'partially_paid', 'paid', 'overdue'].includes(bill.status)) {
    fail('invalid_bill_document');
  }
  for (const field of ['amountMinor', 'paidAmountMinor', 'creditAppliedMinor', 'outstandingAmountMinor']) {
    money(bill[field], 'invalid_bill_amounts');
  }
  return {id: doc.id, bill};
}

function validateV2EventRoot(doc, communityId, reason) {
  const event = doc.data();
  if (!event || event.id !== doc.id || event.schemaVersion !== 2 || event.communityId !== communityId ||
      event.currency !== 'INR' || !validId(event.residentId)) {
    fail(reason);
  }
  return event;
}

function validateAccountRoot(doc, communityId) {
  const account = doc.data();
  if (!account || account.id !== doc.id || account.schemaVersion !== 2 || account.communityId !== communityId ||
      account.currency !== 'INR' || !validId(account.residentId) || !Number.isSafeInteger(account.version) ||
      account.version < 0) {
    fail('invalid_financial_account');
  }
  money(account.availableCreditMinor, 'invalid_financial_account');
  const expectedId = ledger.residentFinancialAccountId({communityId, residentId: account.residentId});
  if (expectedId !== account.id) fail('invalid_financial_account');
  return account;
}

function groupByResident(rows, communityId, reason) {
  const grouped = new Map();
  for (const doc of rows) {
    const event = validateV2EventRoot(doc, communityId, reason);
    const residentId = event.residentId;
    if (!grouped.has(residentId)) grouped.set(residentId, []);
    grouped.get(residentId).push(event);
  }
  return grouped;
}

async function getBillingV2FinancialReportCore({db, auth, data, now = Date.now, requireAuthority = requireOperationalAdmin}) {
  const input = parseInput(data);
  const {community} = await requireAuthority(db, auth, input.communityId);
  const nowMs = now();
  if (!Number.isFinite(nowMs)) fail('invalid_now');

  const [billsSnapshot, transactionSnapshot, allocationSnapshot, creditSnapshot, accountSnapshot] = await Promise.all([
    db.collection('bills').where('communityId', '==', input.communityId).limit(MAX_BILLS + 1).get(),
    db.collection('paymentTransactions').where('communityId', '==', input.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
    db.collection('paymentAllocations').where('communityId', '==', input.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
    db.collection('residentCreditEntries').where('communityId', '==', input.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
    db.collection('residentFinancialAccounts').where('communityId', '==', input.communityId).limit(MAX_ACCOUNTS + 1).get(),
  ]);

  const billRows = rootDocs(billsSnapshot, 'bills');
  const transactionRows = rootDocs(transactionSnapshot, 'paymentTransactions');
  const allocationRows = rootDocs(allocationSnapshot, 'paymentAllocations');
  const creditRows = rootDocs(creditSnapshot, 'residentCreditEntries');
  const accountRows = rootDocs(accountSnapshot, 'residentFinancialAccounts');

  checkCount(billRows, MAX_BILLS, 'bill_limit');
  checkCount(transactionRows, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  checkCount(allocationRows, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  checkCount(creditRows, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  checkCount(accountRows, MAX_ACCOUNTS, 'financial_account_limit');

  const bills = [];
  for (const doc of billRows) {
    const parsed = validateBillDocument(doc, input.communityId, input.billingPeriod);
    if (parsed) bills.push(parsed);
  }

  const transactionsByResident = groupByResident(transactionRows, input.communityId, 'invalid_financial_history');
  const allocationsByResident = groupByResident(allocationRows, input.communityId, 'invalid_financial_history');
  const creditsByResident = groupByResident(creditRows, input.communityId, 'invalid_financial_history');

  const accountsByResident = new Map();
  for (const row of accountRows) {
    const account = validateAccountRoot(row, input.communityId);
    if (accountsByResident.has(account.residentId)) fail('invalid_financial_account');
    accountsByResident.set(account.residentId, account);
  }

  const residentIds = new Set([
    ...bills.map(item => item.bill.residentId),
    ...transactionsByResident.keys(),
    ...allocationsByResident.keys(),
    ...creditsByResident.keys(),
    ...accountsByResident.keys(),
  ]);

  const summariesByResident = new Map();
  for (const residentId of residentIds) {
    const scope = {communityId: input.communityId, residentId, currency: 'INR'};
    const transactions = transactionsByResident.get(residentId) || [];
    const allocations = allocationsByResident.get(residentId) || [];
    const credits = creditsByResident.get(residentId) || [];

    let payments;
    let creditSummary;
    try {
      payments = ledger.summarizeAllocations({...scope, transactions, events: allocations});
      creditSummary = ledger.summarizeCreditEntries({...scope, entries: credits});
    } catch (_) {
      fail('invalid_financial_history');
    }

    const account = accountsByResident.get(residentId);
    if (account) {
      if (account.availableCreditMinor !== creditSummary.availableCreditMinor) {
        fail('account_projection_mismatch');
      }
    } else if (creditSummary.availableCreditMinor !== 0) {
      fail('account_projection_mismatch');
    }

    summariesByResident.set(residentId, {payments, creditSummary});
  }

  let billedMinor = 0n;
  let paidAllocationMinor = 0n;
  let creditAppliedMinor = 0n;
  let outstandingMinor = 0n;
  let overdueOutstandingMinor = 0n;
  const statusCounts = {pending: 0, partially_paid: 0, paid: 0, overdue: 0};

  for (const {id: billId, bill} of bills) {
    const residentSummary = summariesByResident.get(bill.residentId);
    if (!residentSummary) fail('invalid_financial_history');
    const isOverdue = isPastLocalDueDate(nowMs, bill);
    let expected;
    try {
      expected = ledger.calculateBillProjection({
        amountMinor: bill.amountMinor,
        paidAmountMinor: residentSummary.payments.paidByBill[billId] || 0,
        creditAppliedMinor: residentSummary.creditSummary.creditAppliedByBill[billId] || 0,
        currency: 'INR',
        isOverdue,
      });
    } catch (_) {
      fail('ledger_projection_mismatch');
    }

    const keys = ['paidAmountMinor', 'creditAppliedMinor', 'outstandingAmountMinor'];
    if (keys.some(key => bill[key] !== expected[key])) {
      fail('ledger_projection_mismatch');
    }

    billedMinor += BigInt(expected.amountMinor);
    paidAllocationMinor += BigInt(expected.paidAmountMinor);
    creditAppliedMinor += BigInt(expected.creditAppliedMinor);
    outstandingMinor += BigInt(expected.outstandingAmountMinor);
    if (expected.status === 'overdue') overdueOutstandingMinor += BigInt(expected.outstandingAmountMinor);
    statusCounts[expected.status]++;
  }

  const methodTotals = {
    upi: {count: 0, totalMinor: 0n},
    cash: {count: 0, totalMinor: 0n},
    bank_transfer: {count: 0, totalMinor: 0n},
    cheque: {count: 0, totalMinor: 0n},
  };

  let totalReceivedMinor = 0n;
  let transactionCount = 0;
  const allTransactions = [...transactionsByResident.values()].flat();
  for (const tx of allTransactions) {
    if (!METHODS.includes(tx.method) || !Number.isSafeInteger(tx.receivedAt) || tx.receivedAt < 0) {
      fail('invalid_financial_history');
    }
    const txPeriod = localBillingPeriodFromMillis(tx.receivedAt, community);
    if (txPeriod !== input.billingPeriod) continue;
    totalReceivedMinor += BigInt(money(tx.amountMinor, 'invalid_financial_history'));
    methodTotals[tx.method].count++;
    methodTotals[tx.method].totalMinor += BigInt(tx.amountMinor);
    transactionCount++;
  }

  let totalAvailableCreditMinor = 0n;
  let residentsWithCreditCount = 0;
  for (const account of accountsByResident.values()) {
    totalAvailableCreditMinor += BigInt(account.availableCreditMinor);
    if (account.availableCreditMinor > 0) residentsWithCreditCount++;
  }

  return {
    success: true,
    schemaVersion: 1,
    communityId: input.communityId,
    billingPeriod: input.billingPeriod,
    generatedAtMs: Math.trunc(nowMs),
    liabilitySummary: {
      billsCount: bills.length,
      billedMinor: safeMoney(billedMinor, 'overflow'),
      paidAllocationMinor: safeMoney(paidAllocationMinor, 'overflow'),
      creditAppliedMinor: safeMoney(creditAppliedMinor, 'overflow'),
      outstandingMinor: safeMoney(outstandingMinor, 'overflow'),
      overdueOutstandingMinor: safeMoney(overdueOutstandingMinor, 'overflow'),
      statusCounts,
    },
    collectionActivity: {
      transactionCount,
      totalReceivedMinor: safeMoney(totalReceivedMinor, 'overflow'),
      methods: {
        upi: {count: methodTotals.upi.count, totalMinor: safeMoney(methodTotals.upi.totalMinor, 'overflow')},
        cash: {count: methodTotals.cash.count, totalMinor: safeMoney(methodTotals.cash.totalMinor, 'overflow')},
        bank_transfer: {
          count: methodTotals.bank_transfer.count,
          totalMinor: safeMoney(methodTotals.bank_transfer.totalMinor, 'overflow'),
        },
        cheque: {count: methodTotals.cheque.count, totalMinor: safeMoney(methodTotals.cheque.totalMinor, 'overflow')},
      },
    },
    creditPosition: {
      accountsCount: accountsByResident.size,
      residentsWithCreditCount,
      totalAvailableCreditMinor: safeMoney(totalAvailableCreditMinor, 'overflow'),
    },
  };
}

// Detailed Community Admin report. This reads only the selected community and
// joins deleted-resident identity from the request-time deletion snapshot.
async function getBillingV2DetailedReportCore({db, auth, data, now = Date.now, requireAuthority = requireOperationalAdmin}) {
  const allowed = ['communityId', 'fromMs', 'toMs', 'residentId', 'listResidents'];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !allowed.includes(key)) || !validId(data.communityId) ||
      !Number.isSafeInteger(data.fromMs) || !Number.isSafeInteger(data.toMs) ||
      data.fromMs < 0 || data.toMs < data.fromMs ||
      data.fromMs > 8640000000000000 || data.toMs > 8640000000000000 ||
      (data.residentId != null && !validId(data.residentId)) ||
      (data.listResidents != null && typeof data.listResidents !== 'boolean') ||
      (data.listResidents && data.residentId)) {
    fail('invalid_detailed_request', 'invalid-argument');
  }
  await requireAuthority(db, auth, data.communityId);
  const nowMs = now();
  if (!Number.isSafeInteger(nowMs) || nowMs < 0) fail('invalid_now');
  const [billSnapshot, txSnapshot, allocationSnapshot, creditSnapshot, accountSnapshot,
    residentSnapshot, deletionSnapshot, legacyPaymentSnapshot] = await Promise.all([
    db.collection('bills').where('communityId', '==', data.communityId).limit(MAX_BILLS + 1).get(),
    db.collection('paymentTransactions').where('communityId', '==', data.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
    db.collection('paymentAllocations').where('communityId', '==', data.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
    db.collection('residentCreditEntries').where('communityId', '==', data.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
    db.collection('residentFinancialAccounts').where('communityId', '==', data.communityId).limit(MAX_ACCOUNTS + 1).get(),
    db.collection('users').where('communityId', '==', data.communityId).limit(MAX_ACCOUNTS + 1).get(),
    db.collection('accountDeletionRequests').where('communityId', '==', data.communityId).limit(MAX_ACCOUNTS + 1).get(),
    db.collection('payments').where('communityId', '==', data.communityId).limit(MAX_HISTORY_DOCUMENTS + 1).get(),
  ]);
  const billsRaw = rootDocs(billSnapshot, 'bills');
  const txRaw = rootDocs(txSnapshot, 'paymentTransactions');
  const allocationRaw = rootDocs(allocationSnapshot, 'paymentAllocations');
  const creditRaw = rootDocs(creditSnapshot, 'residentCreditEntries');
  const accountsRaw = rootDocs(accountSnapshot, 'residentFinancialAccounts');
  const residentsRaw = rootDocs(residentSnapshot, 'users');
  const deletionRaw = rootDocs(deletionSnapshot, 'accountDeletionRequests');
  const legacyPayments = rootDocs(legacyPaymentSnapshot, 'payments');
  checkCount(billsRaw, MAX_BILLS, 'bill_limit');
  checkCount(txRaw, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  checkCount(allocationRaw, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  checkCount(creditRaw, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');
  checkCount(accountsRaw, MAX_ACCOUNTS, 'financial_account_limit');
  checkCount(residentsRaw, MAX_ACCOUNTS, 'resident_limit');
  checkCount(deletionRaw, MAX_ACCOUNTS, 'resident_limit');
  checkCount(legacyPayments, MAX_HISTORY_DOCUMENTS, 'financial_history_limit');

  const transactionsByResident = groupByResident(txRaw, data.communityId, 'invalid_financial_history');
  const allocationsByResident = groupByResident(allocationRaw, data.communityId, 'invalid_financial_history');
  const creditsByResident = groupByResident(creditRaw, data.communityId, 'invalid_financial_history');
  const accountsByResident = new Map();
  for (const row of accountsRaw) {
    const account = validateAccountRoot(row, data.communityId);
    if (accountsByResident.has(account.residentId)) fail('invalid_financial_account');
    accountsByResident.set(account.residentId, account);
  }
  const identityByResident = new Map();
  for (const row of residentsRaw) {
    const profile = row.data();
    if (profile?.uid !== row.id || profile.role !== 'resident' || profile.communityId !== data.communityId) continue;
    identityByResident.set(row.id, {name: profile.fullName || profile.name || profile.residentName || '',
      phone: profile.phoneNumber || profile.phone || '', unit: profile.flatLabel || profile.unitId || profile.flatId || '',
      residentType: profile.residentType || profile.ownershipType || '', deleted: false});
  }
  for (const row of deletionRaw) {
    const request = row.data();
    const snapshot = request?.retainedResidentIdentity;
    if (request?.sourceApp !== 'resident' || request.status !== 'completed' ||
        request.communityId !== data.communityId || request.communityScopeVerified !== true ||
        !validId(request.uid)) continue;
    const retained = snapshot && typeof snapshot === 'object' ? snapshot : {};
    identityByResident.set(request.uid, {name: retained.name || '', phone: retained.phoneNumber || '',
      unit: retained.unit || '', residentType: retained.residentType || '', deleted: true,
      completedAtMs: request.completedAt instanceof Timestamp ? request.completedAt.toMillis() : null});
  }

  // V1 bills are independent from the V2 ledger. A completed V1 payment is
  // linked by paymentId and is evidence of that bill's settlement, not another
  // liability or another V2 allocation.
  const legacyByResident = new Map(), legacyReceiptsByResident = new Map();
  const legacyBillById = new Map();
  const warnings = new Set();
  const add = (map, key, value) => { if (!map.has(key)) map.set(key, []); map.get(key).push(value); };
  const minor = value => {
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 ||
        !Number.isSafeInteger(Math.round(value * 100)) || Math.abs(value * 100 - Math.round(value * 100)) > 0.000001) return null;
    return Math.round(value * 100);
  };
  const millis = value => value instanceof Timestamp ? value.toMillis() : Number.isSafeInteger(value) && value >= 0 ? value : null;
  for (const doc of billsRaw) {
    const bill = doc.data();
    if (bill.schemaVersion != null) continue;
    if (!validId(bill.residentId) || (bill.userId != null && bill.userId !== bill.residentId)) {
      warnings.add('Some legacy bills have no reliable resident identity and require reconciliation.'); continue;
    }
    const amount = minor(bill.amount), createdAt = millis(bill.createdAt);
    if (amount == null || createdAt == null || !['paid', 'pending', 'overdue'].includes(bill.status)) {
      warnings.add('Some legacy bills have unsupported amounts, status or timestamps and require reconciliation.'); continue;
    }
    const item = {id: doc.id, bill, amount, createdAt};
    legacyBillById.set(doc.id, item);
    add(legacyByResident, bill.residentId, item);
    const identity = identityByResident.get(bill.residentId);
    if (identity && identity.deleted) {
      identity.name ||= bill.residentName || '';
      identity.unit ||= bill.flatLabel || bill.flatId || '';
    }
  }
  const v2Sources = new Set(txRaw.map(doc => doc.data().sourceId));
  for (const doc of legacyPayments) {
    const payment = doc.data();
    if (payment.status !== 'completed') continue;
    if (v2Sources.has(doc.id)) continue;
    const bill = legacyBillById.get(payment.billId);
    const receivedAt = millis(payment.paymentDate) ?? millis(payment.reviewedAt) ?? millis(payment.createdAt);
    const createdAt = millis(payment.createdAt) ?? receivedAt;
    const amount = minor(payment.amount);
    if (!validId(payment.userId) || amount == null || receivedAt == null || createdAt == null ||
        (bill && (bill.bill.residentId !== payment.userId || bill.bill.paymentId !== doc.id || bill.amount !== amount || bill.bill.status !== 'paid'))) {
      warnings.add('Some legacy payment records could not be matched safely and require reconciliation.'); continue;
    }
    if (!bill) warnings.add('Some verified legacy payments have no matching supported bill; receipts are shown separately.');
    const receipt = {transactionId: doc.id, amountMinor: bill ? amount : 0, receivedAmountMinor: amount,
      method: payment.method || 'unknown', reference: payment.transactionId || null, receivedAtMs: receivedAt, createdAtMs: createdAt};
    add(legacyReceiptsByResident, payment.userId, {...receipt, billId: bill?.id});
  }
  if (data.listResidents) {
    const residents = [...identityByResident].map(([residentId, identity]) => ({residentId, identity}));
    residents.sort((a, b) => a.identity.name.localeCompare(b.identity.name) || a.residentId.localeCompare(b.residentId));
    return {success: true, schemaVersion: 1, communityId: data.communityId, residents};
  }

  const billsByResident = new Map();
  for (const doc of billsRaw) {
    const value = doc.data();
    if (value?.schemaVersion !== 2 || value.communityId !== data.communityId || value.currency !== 'INR' ||
        value.billingKind !== 'recurring' || !validId(value.residentId) || !(value.createdAt instanceof Timestamp)) continue;
    if (!billsByResident.has(value.residentId)) billsByResident.set(value.residentId, []);
    billsByResident.get(value.residentId).push({id: doc.id, value});
  }
  const residentIds = new Set([...identityByResident.keys(), ...billsByResident.keys(),
    ...transactionsByResident.keys(), ...allocationsByResident.keys(), ...creditsByResident.keys(), ...accountsByResident.keys(),
    ...legacyByResident.keys(), ...legacyReceiptsByResident.keys()]);
  if (data.residentId) {
    const hasIdentity = identityByResident.has(data.residentId);
    const hasFinancialRows = residentIds.has(data.residentId);
    if (!hasIdentity && !hasFinancialRows) fail('resident_not_found', 'not-found');
    residentIds.clear(); residentIds.add(data.residentId);
  }
  const fromDate = new Date(data.fromMs), toDate = new Date(data.toMs);
  const inRange = ms => ms >= data.fromMs && ms <= data.toMs;
  const rows = [];
  let totals = {billedMinor: 0n, paidMinor: 0n, creditAppliedMinor: 0n, outstandingMinor: 0n, availableCreditMinor: 0n};
  for (const residentId of residentIds) {
    const scope = {communityId: data.communityId, residentId, currency: 'INR'};
    const txs = transactionsByResident.get(residentId) || [];
    const allocations = allocationsByResident.get(residentId) || [];
    const credits = creditsByResident.get(residentId) || [];
    let paymentSummary, creditSummary;
    try {
      paymentSummary = ledger.summarizeAllocations({...scope, transactions: txs, events: allocations});
      creditSummary = ledger.summarizeCreditEntries({...scope, entries: credits});
    } catch (_) { fail('invalid_financial_history'); }
    if ((accountsByResident.get(residentId)?.availableCreditMinor || 0) !== creditSummary.availableCreditMinor) {
      fail('account_projection_mismatch');
    }
    const selectedBills = (billsByResident.get(residentId) || []).filter(({value}) =>
      inRange(value.createdAt.toMillis()));
    let billedMinor = 0n, paidMinor = 0n, creditAppliedMinor = 0n, outstandingMinor = 0n;
    const reportBills = [];
    const usedTransactions = new Map();
    for (const {id, value: bill} of selectedBills) {
      validateBillDocument({id, data: () => bill}, data.communityId, bill.billingPeriod);
      const projection = ledger.calculateBillProjection({amountMinor: bill.amountMinor,
        paidAmountMinor: paymentSummary.paidByBill[id] || 0,
        creditAppliedMinor: creditSummary.creditAppliedByBill[id] || 0,
        currency: 'INR', isOverdue: isPastLocalDueDate(nowMs, bill)});
      if (['paidAmountMinor', 'creditAppliedMinor', 'outstandingAmountMinor'].some(key => bill[key] !== projection[key])) {
        fail('ledger_projection_mismatch');
      }
      billedMinor += BigInt(projection.amountMinor); paidMinor += BigInt(projection.paidAmountMinor);
      creditAppliedMinor += BigInt(projection.creditAppliedMinor);
      outstandingMinor += BigInt(projection.outstandingAmountMinor);
      const chargeLines = Array.isArray(bill.chargeLines) ? bill.chargeLines : [];
      const settlementByTx = new Map();
      for (const event of paymentSummary.remainingAllocations) {
        if (event.billId !== id || event.remainingAmountMinor <= 0) continue;
        const tx = txs.find(item => item.id === event.transactionId);
        if (!tx) fail('invalid_financial_history');
        const add = (map) => map.set(tx.id, (map.get(tx.id) || 0) + event.remainingAmountMinor);
        add(settlementByTx); add(usedTransactions);
      }
      reportBills.push({billId: id, description: chargeLines.map(line => line.label || line.description).filter(Boolean).join(', ') || 'Community charge',
        billingPeriod: bill.billingPeriod, amountMinor: projection.amountMinor, paidMinor: projection.paidAmountMinor,
        creditAppliedMinor: projection.creditAppliedMinor,
        outstandingMinor: projection.outstandingAmountMinor, status: projection.status,
        settlements: [...settlementByTx].map(([transactionId, appliedMinor]) => {
          const tx = txs.find(item => item.id === transactionId);
          return {transactionId, amountMinor: appliedMinor, receivedAmountMinor: tx.amountMinor,
            method: tx.method, reference: tx.reference || null, receivedAtMs: tx.receivedAt,
            createdAtMs: tx.createdAt};
        })});
    }
    const legacyReceipts = legacyReceiptsByResident.get(residentId) || [];
    for (const {id, bill, amount, createdAt} of legacyByResident.get(residentId) || []) {
      if (!inRange(createdAt)) continue;
      const isPaid = bill.status === 'paid';
      if (isPaid && millis(bill.paidAt) == null) {
        warnings.add('Some legacy paid bills lack a settlement timestamp and require reconciliation.');
      }
      const receipt = legacyReceipts.find(item => item.billId === id);
      if (isPaid && !receipt) warnings.add('Some legacy paid bills have no matching verified receipt.');
      billedMinor += BigInt(amount);
      paidMinor += BigInt(isPaid ? amount : 0);
      outstandingMinor += BigInt(isPaid ? 0 : amount);
      const billingPeriod = bill.billingPeriod || (Number.isInteger(bill.year) && Number.isInteger(bill.month) ? `${bill.year}-${String(bill.month).padStart(2, '0')}` : '');
      reportBills.push({billId: id, description: bill.description || bill.chargeType || 'Community charge', billingPeriod,
        amountMinor: amount, paidMinor: isPaid ? amount : 0, creditAppliedMinor: 0,
        outstandingMinor: isPaid ? 0 : amount, status: bill.status, settlements: receipt ? [receipt] : []});
    }
    // Liabilities are the current net position of bills created in the range.
    // Receipts are independent activity in that range, including excess credit
    // and payments toward older bills. Never sum receipts into paid allocations.
    const transactionRows = txs.filter(tx => inRange(tx.receivedAt)).map(tx => {
      return {transactionId: tx.id, amountMinor: usedTransactions.get(tx.id) || 0, receivedAmountMinor: tx.amountMinor, method: tx.method,
        reference: tx.reference || null, receivedAtMs: tx.receivedAt, createdAtMs: tx.createdAt};
    });
    transactionRows.push(...legacyReceipts.filter(tx => inRange(tx.receivedAtMs)));
    rows.push({residentId, identity: identityByResident.get(residentId) || {name: '', phone: '', unit: '', residentType: '', deleted: false},
      bills: reportBills, payments: transactionRows,
      billedMinor: safeMoney(billedMinor, 'overflow'), paidMinor: safeMoney(paidMinor, 'overflow'),
      creditAppliedMinor: safeMoney(creditAppliedMinor, 'overflow'),
      availableCreditMinor: creditSummary.availableCreditMinor,
      outstandingMinor: safeMoney(outstandingMinor, 'overflow'),
      paymentStatus: outstandingMinor === 0n ? 'settled' : paidMinor + creditAppliedMinor > 0n ? 'partially_paid' : 'outstanding'});
    totals.billedMinor += billedMinor; totals.paidMinor += paidMinor;
    totals.creditAppliedMinor += creditAppliedMinor; totals.outstandingMinor += outstandingMinor;
    totals.availableCreditMinor += BigInt(creditSummary.availableCreditMinor);
  }
  rows.sort((a, b) => String(a.identity.name).localeCompare(String(b.identity.name)) || a.residentId.localeCompare(b.residentId));
  return {success: true, schemaVersion: 1, communityId: data.communityId,
    reportingPeriod: {fromMs: data.fromMs, toMs: data.toMs, from: fromDate.toISOString(), to: toDate.toISOString()},
    generatedAtMs: Math.trunc(nowMs), reportType: data.residentId ? 'individual' : 'all', rows, coverageWarnings: [...warnings],
    totals: {residentsCount: rows.length, billedMinor: safeMoney(totals.billedMinor, 'overflow'),
      paidMinor: safeMoney(totals.paidMinor, 'overflow'), creditAppliedMinor: safeMoney(totals.creditAppliedMinor, 'overflow'),
      availableCreditMinor: safeMoney(totals.availableCreditMinor, 'overflow'), outstandingMinor: safeMoney(totals.outstandingMinor, 'overflow')}};
}

module.exports = {getBillingV2FinancialReportCore, getBillingV2DetailedReportCore};
