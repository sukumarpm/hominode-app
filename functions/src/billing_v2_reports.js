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

module.exports = {getBillingV2FinancialReportCore};
