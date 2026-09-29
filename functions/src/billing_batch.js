const {createHash} = require('node:crypto');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin, resolveFlatOccupant} = require('./resident_identity');

const STANDARD_LABELS = Object.freeze({
  maintenance: 'Maintenance', water: 'Water', parking: 'Parking', service: 'Service',
  electricity: 'Electricity', security: 'Security', other: 'Other',
});
const REVISION_ID = 'revision_1';
const MAX_TARGETS = 5000;
const PAGE_SIZE = 100;
const DAY_MS = 86400000;
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];
const clean = value => typeof value === 'string' ? value.trim() : '';
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const invalid = message => {throw new RegistrationError('invalid-argument', message);};
const validId = value => typeof value === 'string' && value.length > 0 &&
  Buffer.byteLength(value, 'utf8') <= 128 && value === value.trim() &&
  !value.includes('/') && !['.', '..'].includes(value) && !/^__.*__$/.test(value);

// Charge type and revision are deliberately absent: future subset-targeted
// lines must be added to this same unit/month bill, never a second liability.
function monthlyBillIdV2(communityId, flatId, billingPeriod) {
  return `monthly_v2_${hash([communityId, flatId, billingPeriod])}`;
}

function validateChargeLines(raw) {
  if (!Array.isArray(raw) || !raw.length || raw.length > 20) invalid('Provide 1 to 20 charge lines.');
  const ids = new Set();
  const labels = new Set();
  let amountMinor = 0;
  const chargeLines = raw.map(line => {
    if (!line || typeof line !== 'object' || Array.isArray(line) ||
        Object.keys(line).some(key => !['lineId', 'code', 'label', 'amountMinor'].includes(key))) {
      invalid('Invalid charge line.');
    }
    if (!validId(line.lineId) || ids.has(line.lineId)) invalid('Each charge needs a unique stable lineId.');
    ids.add(line.lineId);
    const code = line.code;
    if (code !== 'custom' && !Object.hasOwn(STANDARD_LABELS, code)) invalid('Invalid charge code.');
    const label = code === 'custom' ? clean(line.label).replace(/\s+/g, ' ') : STANDARD_LABELS[code];
    if (!label || label.length > 80) invalid('Custom charge labels must contain 1 to 80 characters.');
    const comparison = label.toLowerCase();
    if (code === 'custom' && Object.values(STANDARD_LABELS).some(name => name.toLowerCase() === comparison)) {
      invalid('Custom charge labels cannot use a reserved standard label.');
    }
    if (code !== 'custom' && line.label != null && clean(line.label).toLowerCase() !== comparison) {
      invalid('Standard charge labels must match their code.');
    }
    if (labels.has(comparison)) invalid('Duplicate charge labels are not allowed.');
    labels.add(comparison);
    if (!Number.isSafeInteger(line.amountMinor) || line.amountMinor < 0) {
      invalid('Charge amounts must be nonnegative safe integers in paise.');
    }
    amountMinor += line.amountMinor;
    if (!Number.isSafeInteger(amountMinor)) invalid('The total charge amount is too large.');
    return {lineId: line.lineId, code, label, amountMinor: line.amountMinor};
  }).sort((a, b) => a.lineId.localeCompare(b.lineId));
  if (amountMinor === 0) invalid('The bill total must be positive.');
  return {chargeLines, amountMinor};
}

// Same Intl validation and local-calendar binary search as amenity_booking.js.
// Kept local to avoid changing the existing booking API in this billing phase.
function requireCommunityTimeZone(community) {
  const timeZone = clean(community.timeZone);
  try {
    if (!timeZone) throw new Error('missing');
    return new Intl.DateTimeFormat('en', {timeZone}).resolvedOptions().timeZone;
  } catch (_) {
    throw new RegistrationError('failed-precondition', 'The community time zone is not configured correctly.');
  }
}

function localDateKeyFromMillis(value, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date(value));
  const part = type => parts.find(item => item.type === type).value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function localBillingPeriodFromMillis(value, community) {
  if (!Number.isFinite(value)) {
    throw new RegistrationError('failed-precondition', 'The current time is invalid.');
  }
  const timeZone = requireCommunityTimeZone(community);
  return localDateKeyFromMillis(value, timeZone).slice(0, 7);
}

function startOfLocalDay(key, timeZone) {
  const nominal = Date.parse(`${key}T00:00:00Z`);
  let low = nominal - 2 * DAY_MS;
  let high = nominal + 2 * DAY_MS;
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (localDateKeyFromMillis(middle, timeZone) < key) low = middle + 1;
    else high = middle;
  }
  // A few IANA transitions skip an entire local date.
  if (localDateKeyFromMillis(low, timeZone) !== key) invalid('The due date does not exist in the community time zone.');
  return low;
}

function calendarDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) invalid('Use a YYYY-MM-DD due date.');
  const millis = Date.parse(`${value}T00:00:00Z`);
  if (!Number.isFinite(millis) || new Date(millis).toISOString().slice(0, 10) !== value) invalid('Invalid calendar due date.');
  return value;
}

function validateDueDateV2(value, community, nowMs) {
  const dueDateKey = calendarDate(value);
  const timeZone = requireCommunityTimeZone(community);
  const creationLocalDate = localDateKeyFromMillis(nowMs, timeZone);
  const [year, month, day] = creationLocalDate.split('-').map(Number);
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const maxDueDateKey = new Date(Date.UTC(year, month, Math.min(day, lastDay))).toISOString().slice(0, 10);
  if (dueDateKey < creationLocalDate || dueDateKey > maxDueDateKey) {
    invalid(`Due date must be between ${creationLocalDate} and ${maxDueDateKey}.`);
  }
  return {dueDateKey, timeZone, creationLocalDate, maxDueDateKey,
    dueDate: Timestamp.fromMillis(startOfLocalDay(dueDateKey, timeZone))};
}

function validateRequest(data) {
  const allowed = ['communityId', 'billingPeriod', 'idempotencyKey', 'scope', 'buildingId',
    'flatId', 'flatIds', 'chargeLines', 'dueDate'];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !allowed.includes(key))) invalid('Invalid V2 batch request.');
  if (!validId(data.communityId) || !validId(data.idempotencyKey)) invalid('Community and idempotencyKey are required.');
  if (typeof data.billingPeriod !== 'string' || !/^(20\d{2}|2100)-(0[1-9]|1[0-2])$/.test(data.billingPeriod)) {
    invalid('Use a YYYY-MM billing period between 2000 and 2100.');
  }
  if (!['community', 'building', 'unit', 'units'].includes(data.scope)) invalid('Invalid billing scope.');
  const needsBuilding = ['building', 'unit'].includes(data.scope);
  if ((needsBuilding && !validId(data.buildingId)) || (!needsBuilding && data.buildingId != null) ||
      (data.scope === 'unit' && !validId(data.flatId)) || (data.scope !== 'unit' && data.flatId != null)) {
    invalid('Invalid scope identifiers.');
  }
  if (data.scope === 'units') {
    if (!Array.isArray(data.flatIds) || !data.flatIds.length || data.flatIds.length > MAX_TARGETS ||
        data.flatIds.some(id => !validId(id))) invalid('Select valid units (at most 5000).');
  } else if (data.flatIds != null) invalid('flatIds requires units scope.');
  return {
    communityId: data.communityId, billingPeriod: data.billingPeriod, idempotencyKey: data.idempotencyKey,
    scope: data.scope, buildingId: data.buildingId || null, flatId: data.flatId || null,
    flatIds: data.scope === 'units' ? [...new Set(data.flatIds)].sort() : [],
    ...validateChargeLines(data.chargeLines), dueDateKey: calendarDate(data.dueDate),
  };
}

function snapshotAssignment(flatId, flat) {
  let residentId = null;
  let occupancyState = 'missing';
  try {
    const uid = resolveFlatOccupant(flat).uid;
    if (validId(uid)) {residentId = uid; occupancyState = 'assigned';}
  } catch (_) { occupancyState = 'ambiguous'; }
  return {flatId, buildingId: validId(flat.buildingId) ? flat.buildingId : null,
    residentId, occupancyState, flatStatus: typeof flat.status === 'string' ? flat.status : null};
}

function eligibleResident(resident, assignment, communityId) {
  return resident && resident.uid === assignment.residentId && resident.role === 'resident' && resident.isActive === true &&
    resident.approvalStatus === 'approved' && (resident.status == null || resident.status === 'active') &&
    resident.communityId === communityId && resident.flatId === assignment.flatId && resident.buildingId === assignment.buildingId;
}

async function resolveInitialScope(db, transaction, input) {
  if (input.buildingId) {
    const building = await transaction.get(db.collection('buildings').doc(input.buildingId));
    if (!building.exists || building.data().communityId !== input.communityId) {
      throw new RegistrationError('permission-denied', 'Building is outside the authorized community.');
    }
  }
  let targets;
  if (['unit', 'units'].includes(input.scope)) {
    const ids = input.scope === 'unit' ? [input.flatId] : input.flatIds;
    targets = await Promise.all(ids.map(id => transaction.get(db.collection('flats').doc(id))));
    if (targets.some(doc => !doc.exists || doc.data().communityId !== input.communityId ||
        (input.scope === 'unit' && doc.data().buildingId !== input.buildingId))) {
      throw new RegistrationError('permission-denied', 'A selected unit is outside the authorized scope.');
    }
  } else {
    let query = db.collection('flats').where('communityId', '==', input.communityId);
    if (input.scope === 'building') query = query.where('buildingId', '==', input.buildingId);
    targets = (await transaction.get(query.limit(MAX_TARGETS + 1))).docs;
  }
  // Bound the frozen assignment manifest below Firestore's document size limit. Bills
  // are NOT created in this transaction. Larger scopes must be split by units.
  if (targets.length > MAX_TARGETS || targets.some(doc => !validId(doc.id))) {
    invalid('The scope exceeds 5000 units or contains invalid unit identifiers.');
  }
  const reads = new Map();
  const read = (collection, id) => {
    const key = `${collection}/${id}`;
    if (!reads.has(key)) reads.set(key, transaction.get(db.collection(collection).doc(id)));
    return reads.get(key);
  };
  const assignments = await Promise.all(targets.map(async doc => {
    const assignment = snapshotAssignment(doc.id, doc.data());
    let ineligibleReason = null;
    if (assignment.flatStatus !== 'occupied' || !assignment.buildingId) ineligibleReason = 'unit_not_eligible';
    else {
      const building = await read('buildings', assignment.buildingId);
      if (!building.exists || building.data().communityId !== input.communityId) ineligibleReason = 'building_not_eligible';
      else if (assignment.occupancyState === 'ambiguous') ineligibleReason = 'ambiguous_occupant';
      else if (!assignment.residentId) ineligibleReason = 'missing_occupant';
      else if (!eligibleResident((await read('users', assignment.residentId)).data(), assignment, input.communityId)) {
        ineligibleReason = 'resident_not_eligible';
      }
    }
    return {...assignment, ineligibleReason};
  }));
  assignments.sort((a, b) => a.flatId < b.flatId ? -1 : a.flatId > b.flatId ? 1 : 0);
  const initialScope = {scope: input.scope, buildingId: input.buildingId,
    flatIds: assignments.map(assignment => assignment.flatId), targets: assignments};
  if (Buffer.byteLength(JSON.stringify(initialScope), 'utf8') > 700000) invalid('The frozen scope is too large. Select fewer units.');
  return initialScope;
}

function validateTrustedSource(source) {
  if (source === undefined) return null;
  if (!source || typeof source !== 'object' || Array.isArray(source) ||
      Object.keys(source).sort().join(',') !== 'scheduleId,scheduleRevisionId' ||
      !validId(source.scheduleId) || !validId(source.scheduleRevisionId)) {
    invalid('Invalid trusted schedule source.');
  }
  return {scheduleId: source.scheduleId, scheduleRevisionId: source.scheduleRevisionId};
}

async function ensureBatch(db, auth, input, now, source) {
  const batchId = `monthly_batch_v2_${hash([input.communityId, input.idempotencyKey])}`;
  const batchRef = db.collection('billingBatches').doc(batchId);
  // Preserve the exact legacy hash for existing direct V2 batch requests.
  const requestHash = source ? hash({input, source}) : hash(input);
  await db.runTransaction(async transaction => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const existing = await transaction.get(batchRef);
    if (existing.exists) {
      if (existing.data().requestHash !== requestHash) {
        throw new RegistrationError('already-exists', 'This idempotencyKey belongs to different batch terms.');
      }
      return; // Original local creation date and immutable revision survive retries.
    }
    const nowMs = now();
    const dates = validateDueDateV2(input.dueDateKey, actor.community, nowMs);
    const initialScope = await resolveInitialScope(db, transaction, input);
    const createdAt = Timestamp.fromMillis(nowMs);
    const terms = {schemaVersion: 2, communityId: input.communityId, billingPeriod: input.billingPeriod,
      currency: 'INR', chargeLines: input.chargeLines, amountMinor: input.amountMinor, ...dates};
    transaction.create(batchRef, {
      ...terms, scope: input.scope, initialScope, currentRevisionId: REVISION_ID, revisionNo: 1,
      idempotencyKey: input.idempotencyKey, requestHash, createdBy: actor.uid, createdAt,
      ...(source || {}),
      updatedAt: FieldValue.serverTimestamp(), status: initialScope.flatIds.length ? 'generating' : 'completed',
      generation: {targetCount: initialScope.flatIds.length, materializedCount: 0,
        completed: 0, skipped: 0, reconciliationRequired: 0, failed: 0},
    });
    transaction.create(db.collection(`billingBatches/${batchId}/revisions`).doc(REVISION_ID), {
      ...terms, billingBatchId: batchId, revisionId: REVISION_ID, revisionNo: 1,
      ...(source || {}),
      initialScope, createdBy: actor.uid, createdAt,
      // Applicability belongs to each line. This initial revision applies all
      // lines to the frozen scope; future revisions can describe subsets.
      lineApplicability: input.chargeLines.map(line => ({lineId: line.lineId, scope: 'initialScope'})),
    });
  });
  return batchId;
}

async function materializeNextPage(db, auth, input, batchId) {
  const batchRef = db.collection('billingBatches').doc(batchId);
  await db.runTransaction(async transaction => {
    await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const batch = (await transaction.get(batchRef)).data();
    const generation = {...batch.generation};
    if (!Array.isArray(batch.initialScope.targets)) {
      throw new RegistrationError('failed-precondition', 'This batch has no frozen assignments and requires reconciliation.');
    }
    const assignments = batch.initialScope.targets.slice(generation.materializedCount, generation.materializedCount + PAGE_SIZE);
    if (!assignments.length) return;
    for (const frozenAssignment of assignments) {
      const {flatId} = frozenAssignment;
      transaction.create(db.collection(`billingBatches/${batchId}/targets`).doc(flatId), {
        schemaVersion: 2, communityId: input.communityId, flatId, frozenAssignment,
        billId: monthlyBillIdV2(input.communityId, flatId, input.billingPeriod),
        status: 'pending', attempts: 0, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
    }
    generation.materializedCount += assignments.length;
    transaction.update(batchRef, {generation, updatedAt: FieldValue.serverTimestamp()});
  });
}

function legacyPeriod(bill) {
  if (typeof bill.billingPeriod === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(bill.billingPeriod)) return bill.billingPeriod;
  const month = String(bill.month ?? '').trim().toLowerCase();
  const index = MONTHS.findIndex((name, i) => [name.toLowerCase(), name.slice(0, 3).toLowerCase(),
    String(i + 1), String(i + 1).padStart(2, '0')].includes(month));
  return index < 0 || !/^\d{4}$/.test(String(bill.year)) ? null : `${bill.year}-${String(index + 1).padStart(2, '0')}`;
}

function generationStatus(generation) {
  const remaining = generation.targetCount - generation.completed - generation.skipped - generation.reconciliationRequired;
  if (remaining > 0) return generation.failed ? 'unresolved' : 'generating';
  return generation.reconciliationRequired ? 'reconciliation_required' : 'completed';
}

function finishTarget(transaction, batchRef, batch, targetRef, target, status, detail = {}) {
  const generation = {...batch.generation};
  if (target.status === 'failed') generation.failed--;
  const counter = {completed: 'completed', skipped: 'skipped', reconciliation_required: 'reconciliationRequired', failed: 'failed'}[status];
  generation[counter]++;
  transaction.update(targetRef, {status, reason: null, ...detail, attempts: target.attempts + 1, updatedAt: FieldValue.serverTimestamp()});
  transaction.update(batchRef, {generation, status: generationStatus(generation), updatedAt: FieldValue.serverTimestamp()});
  return status;
}

async function generateTarget(db, auth, input, batchId, flatId) {
  const batchRef = db.collection('billingBatches').doc(batchId);
  const targetRef = db.collection(`billingBatches/${batchId}/targets`).doc(flatId);
  return db.runTransaction(async transaction => {
    await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const batch = (await transaction.get(batchRef)).data();
    const target = (await transaction.get(targetRef)).data();
    if (!['pending', 'failed'].includes(target.status)) return 'alreadyCompleted';
    const finish = (status, detail) => finishTarget(transaction, batchRef, batch, targetRef, target, status, detail);
    const billId = target.billId;
    const billRef = db.collection('bills').doc(billId);
    const assignmentRef = db.collection('billingAssignments').doc(billId);
    const assignment = await transaction.get(assignmentRef);
    const bill = await transaction.get(billRef);
    if (assignment.exists || bill.exists) {
      return finish('reconciliation_required', {reason: 'unit_period_already_assigned',
        conflictingBatchId: assignment.data()?.billingBatchId || bill.data()?.billingBatchId || null, billIds: [billId]});
    }
    // Report existing liability even if occupancy has since changed. All
    // charge types/statuses consume the old recurring liability; unknown
    // legacy periods are conservatively reported. Unchanged V1 writers do
    // not participate in V2 reservations.
    const history = await transaction.get(db.collection('bills').where('flatId', '==', flatId));
    const conflicts = history.docs.filter(doc => {
      const old = doc.data();
      const period = legacyPeriod(old);
      return old.communityId === input.communityId && old.billingKind !== 'ad_hoc' &&
        (period === input.billingPeriod || period === null);
    });
    if (conflicts.length) return finish('reconciliation_required', {
      reason: 'existing_liability_requires_reconciliation', billIds: conflicts.map(doc => doc.id),
    });
    const frozen = target.frozenAssignment;
    if (!frozen) return finish('reconciliation_required', {reason: 'frozen_assignment_missing', billIds: []});
    // Eligibility is frozen too: a later move-in/approval must not expand the
    // original liability population. Preserve existing legacy-conflict priority.
    if (frozen.ineligibleReason) return finish('skipped', {reason: frozen.ineligibleReason});
    const changed = () => finish('reconciliation_required', {
      reason: 'occupancy_changed_since_batch_creation', billIds: [],
    });
    const flatSnapshot = await transaction.get(db.collection('flats').doc(flatId));
    const flat = flatSnapshot.data();
    if (!flatSnapshot.exists || flat.communityId !== input.communityId) return changed();
    const live = snapshotAssignment(flatId, flat);
    if (['flatId', 'buildingId', 'residentId', 'occupancyState', 'flatStatus'].some(key => live[key] !== frozen[key])) {
      return changed();
    }
    const building = await transaction.get(db.collection('buildings').doc(flat.buildingId));
    if (!building.exists || building.data().communityId !== input.communityId) return finish('skipped', {reason: 'building_not_eligible'});
    const residentId = frozen.residentId;
    const resident = (await transaction.get(db.collection('users').doc(residentId))).data();
    if (!eligibleResident(resident, frozen, input.communityId)) return changed();
    // Materialize independent per-target terms. The batch is never a live
    // shared source of a bill's line applicability or financial projection.
    const chargeLines = batch.chargeLines.map(line => ({...line}));
    const terms = {
      schemaVersion: 2, billingKind: 'recurring', billingBatchId: batchId,
      appliedBatchRevisionId: REVISION_ID, billingPeriod: input.billingPeriod,
      currency: 'INR', chargeLines, amountMinor: batch.amountMinor,
      amount: batch.amountMinor / 100,
      chargeBreakdown: Object.fromEntries(chargeLines.map(line => [line.label, line.amountMinor / 100])),
      paidAmountMinor: 0, creditAppliedMinor: 0, outstandingAmountMinor: batch.amountMinor,
      dueDate: batch.dueDate, dueDateKey: batch.dueDateKey, timeZone: batch.timeZone,
    };
    const identity = {communityId: input.communityId, flatId, buildingId: flat.buildingId,
      residentId, residentName: clean(resident.name) || clean(resident.fullName) || residentId,
      flatLabel: clean(flat.flatLabel) || clean(flat.unitLabel) || clean(flat.flatNumber) || flatId};
    transaction.create(assignmentRef, {schemaVersion: 2, communityId: input.communityId, flatId,
      billingPeriod: input.billingPeriod, billingBatchId: batchId, billId,
      createdAt: FieldValue.serverTimestamp()});
    transaction.create(billRef, {...terms, ...identity, adminId: batch.createdBy,
      month: MONTHS[Number(input.billingPeriod.slice(5)) - 1], year: input.billingPeriod.slice(0, 4),
      type: 'combined', status: 'pending', currentRevisionId: REVISION_ID, revisionNo: 1,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection(`bills/${billId}/revisions`).doc(REVISION_ID), {
      ...terms, ...identity, billId, revisionId: REVISION_ID, revisionNo: 1,
      createdBy: batch.createdBy, createdAt: FieldValue.serverTimestamp(),
    });
    return finish('completed');
  });
}

async function recordFailure(db, auth, input, batchId, flatId) {
  const batchRef = db.collection('billingBatches').doc(batchId);
  const targetRef = db.collection(`billingBatches/${batchId}/targets`).doc(flatId);
  await db.runTransaction(async transaction => {
    await requireOperationalAdmin(db, auth, input.communityId, transaction);
    const batch = (await transaction.get(batchRef)).data();
    const target = (await transaction.get(targetRef)).data();
    if (!['pending', 'failed'].includes(target.status)) return;
    finishTarget(transaction, batchRef, batch, targetRef, target, 'failed', {reason: 'generation_failed_retry_required'});
  });
}

// Contract: retry the identical payload/idempotencyKey until resumeRequired is
// false. Each call materializes <=100 targets and attempts <=100 bills. Failed
// targets remain retryable; skipped/conflicted targets require a later workflow.
async function createMonthlyBillingBatchV2Core({db, auth, data, now = Date.now, source: rawSource}) {
  const input = validateRequest(data);
  const source = validateTrustedSource(rawSource);
  await requireOperationalAdmin(db, auth, input.communityId);
  const batchId = await ensureBatch(db, auth, input, now, source);
  await materializeNextPage(db, auth, input, batchId);
  const batchRef = db.collection('billingBatches').doc(batchId);
  const before = (await batchRef.get()).data();
  const targets = db.collection(`billingBatches/${batchId}/targets`);
  const pending = (await targets.where('status', '==', 'pending').limit(PAGE_SIZE).get()).docs;
  const failures = pending.length < PAGE_SIZE
    ? (await targets.where('status', '==', 'failed').limit(PAGE_SIZE - pending.length).get()).docs : [];
  let created = 0;
  const unresolved = [];
  for (const target of [...pending, ...failures]) {
    try {
      if (await generateTarget(db, auth, input, batchId, target.id) === 'completed') created++;
    } catch (error) {
      if (error instanceof RegistrationError) throw error;
      unresolved.push({flatId: target.id, reason: 'generation_failed_retry_required'});
      // A storage outage can also prevent the failure checkpoint. The durable
      // pending target still permits recovery, and this call reports the error.
      try { await recordFailure(db, auth, input, batchId, target.id); } catch (failure) {
        if (failure instanceof RegistrationError) throw failure;
      }
    }
  }
  const batch = (await batchRef.get()).data();
  const conflicts = (await targets.where('status', '==', 'reconciliation_required').get()).docs
    .map(doc => ({flatId: doc.id, reason: doc.data().reason, billIds: doc.data().billIds,
      conflictingBatchId: doc.data().conflictingBatchId || null}));
  const failedTargets = (await targets.where('status', '==', 'failed').get()).docs
    .map(doc => ({flatId: doc.id, reason: doc.data().reason}));
  const unresolvedTargets = [...new Map([...failedTargets, ...unresolved].map(item => [item.flatId, item])).values()];
  const generation = batch.generation;
  const remaining = generation.targetCount - generation.completed - generation.skipped - generation.reconciliationRequired;
  return {batchId, revisionId: REVISION_ID, status: batch.status, created,
    existing: before.generation.completed, alreadyCompleted: before.generation.completed,
    completed: generation.completed, skipped: generation.skipped,
    reconciliationRequired: generation.reconciliationRequired, conflicts,
    failed: unresolvedTargets.length, unresolved: unresolvedTargets,
    remaining, resumeRequired: remaining > 0, generation};
}

module.exports = {createMonthlyBillingBatchV2Core, monthlyBillIdV2, validateChargeLines,
  validateDueDateV2, localBillingPeriodFromMillis};
