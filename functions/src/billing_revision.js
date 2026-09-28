const {createHash} = require('node:crypto');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin} = require('./resident_identity');
const {validateChargeLines, monthlyBillIdV2} = require('./billing_batch');
const {residentFinancialAccountId, buildResidentFinancialAccount, summarizeAllocations,
  summarizeCreditEntries, calculateBillProjection, planDownwardRevision, assertImmutableRetry} = require('./billing_v2_ledger');

const PAGE_SIZE = 100;
const stamp = () => FieldValue.serverTimestamp();
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const validId = value => typeof value === 'string' && value.length > 0 && value === value.trim() &&
  Buffer.byteLength(value, 'utf8') <= 128 && !/[\/\u0000-\u001f\u007f]/.test(value) &&
  !['.', '..'].includes(value) && !/^__.*__$/.test(value) && Buffer.from(value).toString() === value;
const fail = (message, code = 'failed-precondition') => {throw new RegistrationError(code, message);};
const rootDocs = (snapshot, collection) => snapshot.docs.filter(doc => doc.ref.path === `${collection}/${doc.id}`);
const frozenId = value => validId(value) ? value : null;
function billingRevisionId(billingBatchId, idempotencyKey) {
  if (!validId(billingBatchId) || !validId(idempotencyKey)) fail('Invalid revision identity.', 'invalid-argument');
  return `revision_v2_${hash([billingBatchId, idempotencyKey])}`;
}
function validateRequest(data) {
  const fields = ['communityId', 'billingBatchId', 'idempotencyKey', 'expectedRevisionId', 'chargeLines', 'reason'];
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !fields.includes(key)) ||
      fields.slice(0, 4).some(key => !validId(data[key])) ||
      (data.reason != null && (typeof data.reason !== 'string' || data.reason.trim().length > 300))) {
    fail('Invalid monthly billing revision request.', 'invalid-argument');
  }
  return {communityId: data.communityId, billingBatchId: data.billingBatchId, idempotencyKey: data.idempotencyKey,
    expectedRevisionId: data.expectedRevisionId, ...validateChargeLines(data.chargeLines), reason: data.reason?.trim() || null};
}
function refs(db, batchId, revisionId) {
  const path = `billingBatches/${batchId}/revisions/${revisionId}`;
  return {batch: db.collection('billingBatches').doc(batchId), revision: db.collection(`billingBatches/${batchId}/revisions`).doc(revisionId),
    state: db.collection(`${path}/state`).doc('progress'), targets: db.collection(`${path}/targets`)};
}
function requireBatch(batch, input) {
  if (!batch || batch.schemaVersion !== 2 || batch.communityId !== input.communityId || batch.currency !== 'INR') {
    fail('The batch is not a V2 batch in the authorized community.');
  }
}

// Compare liability only. Settlement projections can legitimately change
// between revisions and are checked against ledger history separately.
function sameLiabilityTerms(current, previous) {
  if (!current || !previous || current.schemaVersion !== 2 || previous.schemaVersion !== 2 ||
      current.amountMinor !== previous.amountMinor || current.currency !== previous.currency ||
      !(current.dueDate instanceof Timestamp) || !(previous.dueDate instanceof Timestamp) ||
      !current.dueDate.isEqual(previous.dueDate) ||
      typeof previous.dueDateKey !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(previous.dueDateKey) ||
      current.dueDateKey !== previous.dueDateKey || typeof previous.timeZone !== 'string' ||
      !previous.timeZone || current.timeZone !== previous.timeZone) return false;
  try {
    const a = validateChargeLines(current.chargeLines), b = validateChargeLines(previous.chargeLines);
    return a.amountMinor === current.amountMinor && b.amountMinor === previous.amountMinor &&
      JSON.stringify(a.chargeLines) === JSON.stringify(b.chargeLines);
  } catch (error) {
    if (error.code === 'invalid-argument') return false;
    throw error;
  }
}
function verifyBatchPredecessor(batch, previous, batchId) {
  if (!sameLiabilityTerms(batch, previous) || previous.billingBatchId !== batchId ||
      previous.communityId !== batch.communityId || previous.revisionId !== batch.currentRevisionId ||
      previous.revisionNo !== batch.revisionNo ||
      (previous.billingPeriod != null && previous.billingPeriod !== batch.billingPeriod)) {
    fail('batch_projection_mismatch');
  }
}
function verifyBillPredecessor(bill, previous, target) {
  check(sameLiabilityTerms(bill, previous) && previous.billId === target.billId &&
    previous.revisionId === target.previousRevisionId && previous.revisionId === bill.currentRevisionId &&
    previous.appliedBatchRevisionId === target.previousBatchRevisionId &&
    ['billingBatchId', 'revisionNo', 'communityId', 'residentId', 'flatId', 'buildingId',
      'billingKind', 'billingPeriod', 'appliedBatchRevisionId'].every(key =>
      previous[key] != null && previous[key] === bill[key]), 'previous_bill_revision_mismatch');
}
function isPastLocalDueDate(nowMs, bill) {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {timeZone: bill.timeZone, calendar: 'gregory',
      numberingSystem: 'latn', year: 'numeric', month: '2-digit', day: '2-digit'}).formatToParts(new Date(nowMs));
    const date = Object.fromEntries(parts.map(part => [part.type, part.value]));
    return `${date.year.padStart(4, '0')}-${date.month}-${date.day}` > bill.dueDateKey;
  } catch (error) {
    if (error instanceof RangeError) throw new ReconciliationError('bill_due_date_mismatch');
    throw error;
  }
}

// Contract for the later V2 settlement writer: check this INSIDE the same
// transaction that reads the bill/batch and writes the financial account.
// No payment flow is wired to this helper in Phase 4A.
function assertV2SettlementReady({bill, batch, billingBatchId}) {
  if (!bill || !batch || bill.schemaVersion !== 2 || batch.schemaVersion !== 2 ||
      bill.billingBatchId !== billingBatchId || bill.communityId !== batch.communityId ||
      batch.activeRevisionId != null || !validId(batch.currentRevisionId) ||
      bill.appliedBatchRevisionId !== batch.currentRevisionId) {
    fail('V2 settlement is blocked until the batch revision is fully applied.');
  }
}

async function reserveRevision(db, auth, input, now) {
  const revisionId = billingRevisionId(input.billingBatchId, input.idempotencyKey);
  const ref = refs(db, input.billingBatchId, revisionId);
  await db.runTransaction(async tx => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, tx);
    const batch = (await tx.get(ref.batch)).data();
    requireBatch(batch, input);
    const existing = await tx.get(ref.revision);
    const requestHash = hash(input);
    if (existing.exists) {
      if (existing.data().requestHash !== requestHash) fail('This revision key already has different terms.', 'already-exists');
      return;
    }
    if (batch.activeRevisionId != null) fail('Another batch revision is active.');
    if (batch.currentRevisionId !== input.expectedRevisionId) fail('The completed batch revision has changed.');
    const previous = (await tx.get(refs(db, input.billingBatchId, batch.currentRevisionId).revision)).data();
    verifyBatchPredecessor(batch, previous, input.billingBatchId);
    const g = batch.generation;
    if (!g || g.failed !== 0 || g.materializedCount !== g.targetCount ||
        g.completed + g.skipped + g.reconciliationRequired !== g.targetCount) fail('Finish initial batch generation before revising.');
    if (!Number.isSafeInteger(batch.revisionNo) || batch.revisionNo < 1 || !Number.isSafeInteger(batch.revisionNo + 1)) fail('Invalid batch revision number.');
    const bills = rootDocs(await tx.get(db.collection('bills').where('billingBatchId', '==', input.billingBatchId)), 'bills')
      .filter(doc => doc.data().schemaVersion === 2);
    if (bills.length !== g.completed) fail('Generated bill population disagrees with the initial generation checkpoint.');
    const targets = bills.map(doc => {
      const bill = doc.data();
      return {billId: doc.id, communityId: frozenId(bill.communityId), flatId: frozenId(bill.flatId),
        residentId: frozenId(bill.residentId), buildingId: frozenId(bill.buildingId),
        previousRevisionId: frozenId(bill.currentRevisionId), previousBatchRevisionId: frozenId(bill.appliedBatchRevisionId)};
    }).sort((a, b) => a.billId < b.billId ? -1 : a.billId > b.billId ? 1 : 0);
    if (targets.length > 5000 || Buffer.byteLength(JSON.stringify(targets), 'utf8') > 700000) fail('The frozen revision scope is too large.');
    const revisionNo = batch.revisionNo + 1;
    const createdAt = Timestamp.fromMillis(now());
    const revision = {schemaVersion: 2, billingBatchId: previous.billingBatchId, communityId: previous.communityId,
      revisionId, revisionNo, previousRevisionId: previous.revisionId, currency: previous.currency,
      billingPeriod: previous.billingPeriod ?? batch.billingPeriod,
      chargeLines: input.chargeLines, amountMinor: input.amountMinor,
      dueDate: previous.dueDate, dueDateKey: previous.dueDateKey, timeZone: previous.timeZone,
      requestHash, idempotencyKey: input.idempotencyKey, reason: input.reason,
      createdBy: actor.uid, createdAt, targets, targetCount: targets.length, progressPath: ref.state.path,
      // Applicability is per line and references this immutable generated-bill
      // manifest. Later subset revisions need not change monthly bill identity.
      lineApplicability: input.chargeLines.map(line => ({lineId: line.lineId, scope: 'revisionTargets'}))};
    tx.create(ref.revision, revision);
    tx.create(ref.state, {revisionId, revisionNo, targetCount: targets.length, materializedCount: 0,
      completed: 0, reconciliationRequired: 0, failed: 0, remaining: targets.length,
      status: targets.length ? 'applying' : 'completed', updatedAt: stamp()});
    tx.update(ref.batch, targets.length ? {activeRevisionId: revisionId, activeRevisionNo: revisionNo, revisionStatus: 'applying', updatedAt: stamp()}
      : completedBatchUpdate(revision));
  });
  return {revisionId, ref};
}
function completedBatchUpdate(revision) {
  return {currentRevisionId: revision.revisionId, revisionNo: revision.revisionNo,
    chargeLines: revision.chargeLines, amountMinor: revision.amountMinor,
    activeRevisionId: null, activeRevisionNo: null, revisionStatus: 'completed', updatedAt: stamp()};
}
async function materializePage(db, auth, input, ref) {
  await db.runTransaction(async tx => {
    await requireOperationalAdmin(db, auth, input.communityId, tx);
    const revision = (await tx.get(ref.revision)).data();
    const state = (await tx.get(ref.state)).data();
    const page = revision.targets.slice(state.materializedCount, state.materializedCount + PAGE_SIZE);
    if (!page.length) return;
    for (const target of page) tx.create(ref.targets.doc(target.billId), {
      ...target, schemaVersion: 2, targetRevisionId: revision.revisionId, status: 'pending', attempts: 0, updatedAt: stamp(),
    });
    tx.update(ref.state, {materializedCount: state.materializedCount + page.length, updatedAt: stamp()});
  });
}

class ReconciliationError extends Error {
  constructor(reason) {super(reason); this.reason = reason;}
}
function check(condition, reason) {if (!condition) throw new ReconciliationError(reason);}
function finish(tx, ref, revision, state, target, status, reason = null) {
  const next = {...state};
  const counters = {completed: 'completed', reconciliation_required: 'reconciliationRequired', failed: 'failed'};
  if (counters[target.status]) next[counters[target.status]]--;
  next[counters[status]]++;
  next.remaining = next.targetCount - next.completed;
  next.status = next.remaining === 0 ? 'completed' : next.reconciliationRequired ? 'reconciliation_required' : next.failed ? 'unresolved' : 'applying';
  next.updatedAt = stamp();
  tx.update(ref.targets.doc(target.billId), {status, reason, attempts: target.attempts + 1, updatedAt: stamp()});
  tx.update(ref.state, next);
  tx.update(ref.batch, next.remaining === 0 ? completedBatchUpdate(revision) : {revisionStatus: next.status, updatedAt: stamp()});
  return status;
}
function financialDocuments(snapshot, collection, scope) {
  return rootDocs(snapshot, collection).map(doc => {
    const event = doc.data();
    check(event.id === doc.id && event.schemaVersion === 2 && event.communityId === scope.communityId &&
      event.residentId === scope.residentId && event.currency === scope.currency, 'invalid_financial_history');
    return event;
  });
}
function validBill(bill, target, revision, batch) {
  check(bill && bill.schemaVersion === 2 && bill.billingKind === 'recurring' && bill.currency === 'INR' &&
    bill.billingBatchId === revision.billingBatchId && bill.billingPeriod === batch.billingPeriod &&
    bill.communityId === revision.communityId && ['communityId', 'flatId', 'residentId', 'buildingId'].every(key =>
      validId(target[key]) && target[key] === bill[key]) &&
    target.billId === monthlyBillIdV2(bill.communityId, bill.flatId, bill.billingPeriod) &&
    bill.currentRevisionId === target.previousRevisionId && bill.appliedBatchRevisionId === target.previousBatchRevisionId &&
    target.previousBatchRevisionId === revision.previousRevisionId && target.previousRevisionId === revision.previousRevisionId &&
    bill.revisionNo === revision.revisionNo - 1, 'bill_identity_or_revision_mismatch');
  check(bill.dueDate instanceof Timestamp && revision.dueDate instanceof Timestamp && bill.dueDate.isEqual(revision.dueDate) &&
    bill.dueDateKey === revision.dueDateKey && bill.timeZone === revision.timeZone, 'bill_due_date_mismatch');
  check(validateChargeLines(bill.chargeLines).amountMinor === bill.amountMinor, 'bill_terms_mismatch');
}

async function applyTarget(db, auth, input, ref, billId, now) {
  return db.runTransaction(async tx => {
    await requireOperationalAdmin(db, auth, input.communityId, tx);
    const batch = (await tx.get(ref.batch)).data();
    requireBatch(batch, input);
    const revision = (await tx.get(ref.revision)).data();
    const state = (await tx.get(ref.state)).data();
    const target = (await tx.get(ref.targets.doc(billId))).data();
    if (target.status === 'completed') return 'alreadyCompleted';
    if (batch.activeRevisionId !== revision.revisionId) fail('The active batch revision has changed.');
    const billRef = db.collection('bills').doc(billId);
    const bill = (await tx.get(billRef)).data();
    const previous = validId(target.previousRevisionId)
      ? (await tx.get(db.collection(`bills/${billId}/revisions`).doc(target.previousRevisionId))).data() : undefined;
    try {
      verifyBillPredecessor(bill, previous, target);
      validBill(bill, target, revision, batch);
    } catch (error) {
      if (error instanceof ReconciliationError || error.code === 'invalid-argument') {
        return finish(tx, ref, revision, state, target, 'reconciliation_required', error.reason || 'bill_terms_mismatch');
      }
      throw error;
    }
    const scope = {communityId: bill.communityId, residentId: bill.residentId, currency: bill.currency};
    const accountRef = db.collection('residentFinancialAccounts').doc(residentFinancialAccountId(scope));
    const accountDoc = await tx.get(accountRef);
    const account = accountDoc.data();
    const billRevisionRef = db.collection(`bills/${billId}/revisions`).doc(revision.revisionId);
    const existingBillRevision = await tx.get(billRevisionRef);
    const history = {};
    for (const name of ['paymentTransactions', 'paymentAllocations', 'residentCreditEntries']) {
      history[name] = await tx.get(db.collection(name).where('communityId', '==', scope.communityId).where('residentId', '==', scope.residentId));
    }
    // Detect a foreign/malformed event pointing at this bill even if it was
    // excluded by the account query. Never import it as this resident's money.
    const billAllocations = await tx.get(db.collection('paymentAllocations').where('billId', '==', billId));
    const billCredits = await tx.get(db.collection('residentCreditEntries').where('billId', '==', billId));
    let plan, snapshot, eventWrites;
    try {
      financialDocuments(billAllocations, 'paymentAllocations', scope);
      financialDocuments(billCredits, 'residentCreditEntries', scope);
      const transactions = financialDocuments(history.paymentTransactions, 'paymentTransactions', scope);
      const allocationEvents = financialDocuments(history.paymentAllocations, 'paymentAllocations', scope);
      const creditEntries = financialDocuments(history.residentCreditEntries, 'residentCreditEntries', scope);
      const payments = summarizeAllocations({...scope, transactions, events: allocationEvents});
      const credits = summarizeCreditEntries({...scope, entries: creditEntries});
      const paidAmountMinor = payments.paidByBill[billId] || 0;
      const creditAppliedMinor = credits.creditAppliedByBill[billId] || 0;
      const nowMs = now();
      const isOverdue = isPastLocalDueDate(nowMs, bill);
      const previous = calculateBillProjection({amountMinor: bill.amountMinor, paidAmountMinor, creditAppliedMinor, currency: 'INR', isOverdue});
      check(['paidAmountMinor', 'creditAppliedMinor', 'outstandingAmountMinor'].every(key => bill[key] === previous[key]), 'ledger_projection_mismatch');
      if (accountDoc.exists) {
        check(account.schemaVersion === 2 && account.id === accountRef.id && account.communityId === scope.communityId &&
          account.residentId === scope.residentId && account.currency === scope.currency &&
          Number.isSafeInteger(account.version) && account.version >= 0 && Number.isSafeInteger(account.version + 1), 'invalid_financial_account');
        check(account.availableCreditMinor === credits.availableCreditMinor, 'account_projection_mismatch');
      }
      if (revision.amountMinor < bill.amountMinor) {
        plan = planDownwardRevision({...scope, billId, revisionId: revision.revisionId, originalAmountMinor: bill.amountMinor,
          revisedAmountMinor: revision.amountMinor, transactions, allocationEvents, creditEntries, createdAt: nowMs, isOverdue});
      } else {
        // Equal-total edits preserve existing allocation/application history,
        // including previously recorded overallocations; they only edit lines.
        check(revision.amountMinor === bill.amountMinor ||
          BigInt(paidAmountMinor) + BigInt(creditAppliedMinor) <= BigInt(revision.amountMinor), 'existing_overallocation_requires_reconciliation');
        plan = {allocationEvents: [], creditEntries: [], availableCreditMinor: credits.availableCreditMinor,
          projection: calculateBillProjection({amountMinor: revision.amountMinor, paidAmountMinor, creditAppliedMinor, currency: 'INR', isOverdue})};
      }
      const chargeLines = revision.chargeLines.map(line => ({...line}));
      snapshot = {...plan.projection, billId, billingBatchId: revision.billingBatchId,
        billingKind: bill.billingKind, billingPeriod: bill.billingPeriod,
        revisionId: revision.revisionId, revisionNo: revision.revisionNo, previousRevisionId: target.previousRevisionId,
        appliedBatchRevisionId: revision.revisionId, ...scope, flatId: bill.flatId, buildingId: bill.buildingId,
        chargeLines, amount: revision.amountMinor / 100,
        chargeBreakdown: Object.fromEntries(chargeLines.map(line => [line.label, line.amountMinor / 100])),
        dueDate: bill.dueDate, dueDateKey: bill.dueDateKey, timeZone: bill.timeZone,
        createdBy: revision.createdBy, createdAt: Timestamp.fromMillis(nowMs)};
      if (existingBillRevision.exists) assertImmutableRetry(existingBillRevision.data(), snapshot);
      eventWrites = [...plan.allocationEvents.map(event => ({collection: 'paymentAllocations', event})),
        ...plan.creditEntries.map(event => ({collection: 'residentCreditEntries', event}))];
      check(eventWrites.length <= 440, 'too_many_financial_events_for_atomic_revision');
    } catch (error) {
      if (error instanceof ReconciliationError || error.code === 'invalid-argument') {
        return finish(tx, ref, revision, state, target, 'reconciliation_required', error.reason || 'invalid_financial_history');
      }
      throw error;
    }
    // Point reads also catch deterministic-ID collisions outside the account
    // queries. All reads and immutable comparisons precede any staged writes.
    const missingEvents = [];
    for (const {collection, event} of eventWrites) {
      const eventRef = db.collection(collection).doc(event.id);
      const existing = await tx.get(eventRef);
      if (existing.exists) {
        try {assertImmutableRetry(existing.data(), event);} catch (_) {
          return finish(tx, ref, revision, state, target, 'reconciliation_required', 'immutable_event_conflict');
        }
      } else missingEvents.push({eventRef, event});
    }
    for (const {eventRef, event} of missingEvents) tx.create(eventRef, event);
    if (plan.creditEntries.length) {
      const accountUpdate = {availableCreditMinor: plan.availableCreditMinor, version: (account?.version || 0) + 1, updatedAt: now()};
      if (accountDoc.exists) tx.update(accountRef, accountUpdate);
      else tx.create(accountRef, {...buildResidentFinancialAccount({...scope, createdAt: snapshot.createdAt.toMillis()}), ...accountUpdate});
    }
    if (!existingBillRevision.exists) tx.create(billRevisionRef, snapshot);
    tx.update(billRef, {...plan.projection, currentRevisionId: revision.revisionId, revisionNo: revision.revisionNo,
      appliedBatchRevisionId: revision.revisionId, chargeLines: snapshot.chargeLines,
      amount: snapshot.amount, chargeBreakdown: snapshot.chargeBreakdown, updatedAt: stamp()});
    return finish(tx, ref, revision, state, target, 'completed');
  });
}
async function recordFailure(db, auth, input, ref, billId) {
  await db.runTransaction(async tx => {
    await requireOperationalAdmin(db, auth, input.communityId, tx);
    const revision = (await tx.get(ref.revision)).data();
    const state = (await tx.get(ref.state)).data();
    const target = (await tx.get(ref.targets.doc(billId))).data();
    if (target.status === 'completed') return;
    finish(tx, ref, revision, state, target, 'failed', 'revision_failed_retry_required');
  });
}

async function reviseMonthlyBillingBatchV2Core({db, auth, data, now = Date.now}) {
  const input = validateRequest(data);
  const {revisionId, ref} = await reserveRevision(db, auth, input, now);
  await materializePage(db, auth, input, ref);
  const before = (await ref.state.get()).data();
  const pending = (await ref.targets.where('status', '==', 'pending').limit(PAGE_SIZE).get()).docs;
  const retry = pending.length < PAGE_SIZE
    ? (await ref.targets.where('status', 'in', ['failed', 'reconciliation_required']).limit(PAGE_SIZE - pending.length).get()).docs : [];
  let applied = 0;
  const errors = [];
  for (const target of [...pending, ...retry]) {
    try {if (await applyTarget(db, auth, input, ref, target.id, now) === 'completed') applied++;} catch (error) {
      if (error instanceof RegistrationError) throw error;
      errors.push({billId: target.id, reason: 'revision_failed_retry_required'});
      try {await recordFailure(db, auth, input, ref, target.id);} catch (failure) {
        if (failure instanceof RegistrationError) throw failure;
      }
    }
  }
  const state = (await ref.state.get()).data();
  const issues = (await ref.targets.where('status', 'in', ['failed', 'reconciliation_required']).get()).docs
    .map(doc => ({billId: doc.id, status: doc.data().status, reason: doc.data().reason}));
  const unresolved = [...new Map([...errors, ...issues].map(item => [item.billId, item])).values()];
  return {revisionId, revisionNo: state.revisionNo, created: applied, applied, alreadyCompleted: before.completed,
    targetCount: state.targetCount, completed: state.completed, reconciliationRequired: state.reconciliationRequired,
    failed: state.failed, unresolved, remaining: state.remaining, resumeRequired: state.remaining > 0, status: state.status};
}

module.exports = {reviseMonthlyBillingBatchV2Core, billingRevisionId, assertV2SettlementReady};
