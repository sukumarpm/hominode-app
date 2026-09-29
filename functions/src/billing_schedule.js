const {createHash} = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin} = require('./resident_identity');
const {validateChargeLines, localBillingPeriodFromMillis, monthlyBillingBatchId,
  createMonthlyBillingBatchV2Core} = require('./billing_batch');

const SCHEDULE_SCHEMA_VERSION = 2;
const MAX_TARGETS = 5000;
const PERIOD_PATTERN = /^(20\d{2}|2100)-(0[1-9]|1[0-2])$/;
const SCHEDULE_TERMS = Object.freeze([
  'scope', 'buildingId', 'flatId', 'flatIds', 'generationDay', 'dueDay',
  'startBillingPeriod', 'endBillingPeriod', 'chargeLines',
]);
const clean = value => typeof value === 'string' ? value.trim() : '';
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const fail = (message, code = 'invalid-argument') => {throw new RegistrationError(code, message);};
const validId = value => typeof value === 'string' && value.length > 0 &&
  Buffer.byteLength(value, 'utf8') <= 128 && value === value.trim() &&
  !/[\/\u0000-\u001f\u007f]/.test(value) && !['.', '..'].includes(value) && !/^__.*__$/.test(value);

function billingScheduleId(communityId, idempotencyKey) {
  if (!validId(communityId) || !validId(idempotencyKey)) fail('Invalid schedule identity.');
  return `billing_schedule_v2_${hash([communityId, idempotencyKey])}`;
}

function billingScheduleRevisionId(scheduleId, idempotencyKey) {
  if (!validId(scheduleId) || !validId(idempotencyKey)) fail('Invalid schedule revision identity.');
  return `schedule_revision_v2_${hash([scheduleId, idempotencyKey])}`;
}

function billingPeriod(value, label) {
  if (typeof value !== 'string' || !PERIOD_PATTERN.test(value)) {
    fail(`${label} must be a valid YYYY-MM period between 2000 and 2100.`);
  }
  return value;
}

function nextBillingPeriod(value) {
  if (typeof value !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(value)) {
    fail('Invalid billing period.', 'failed-precondition');
  }
  const [year, month] = value.split('-').map(Number);
  return month === 12 ? `${year + 1}-01` : `${year}-${String(month + 1).padStart(2, '0')}`;
}

function optionalEndPeriod(value, start) {
  if (value === null) return null;
  const end = billingPeriod(value, 'endBillingPeriod');
  if (end < start) fail('endBillingPeriod must not be before startBillingPeriod.');
  return end;
}

function validateScheduleTerms(data) {
  if (!['community', 'building', 'unit', 'units'].includes(data.scope)) fail('Invalid billing schedule scope.');
  const needsBuilding = ['building', 'unit'].includes(data.scope);
  if ((needsBuilding && !validId(data.buildingId)) || (!needsBuilding && data.buildingId != null) ||
      (data.scope === 'unit' && !validId(data.flatId)) || (data.scope !== 'unit' && data.flatId != null)) {
    fail('Invalid billing schedule scope identifiers.');
  }
  let flatIds = [];
  if (data.scope === 'units') {
    if (!Array.isArray(data.flatIds) || !data.flatIds.length || data.flatIds.length > MAX_TARGETS ||
        data.flatIds.some(id => !validId(id))) fail('Select valid units (at most 5000).');
    flatIds = [...new Set(data.flatIds)].sort();
  } else if (data.flatIds != null) fail('flatIds requires units scope.');

  for (const key of ['generationDay', 'dueDay']) {
    if (!Number.isInteger(data[key]) || data[key] < 1 || data[key] > 28) {
      fail(`${key} must be an integer from 1 to 28.`);
    }
  }
  if (data.dueDay < data.generationDay) {
    fail('dueDay must be on or after generationDay.');
  }
  const startBillingPeriod = billingPeriod(data.startBillingPeriod, 'startBillingPeriod');
  const endBillingPeriod = optionalEndPeriod(data.endBillingPeriod, startBillingPeriod);
  const {chargeLines} = validateChargeLines(data.chargeLines);
  return {
    scope: data.scope,
    buildingId: needsBuilding ? data.buildingId : null,
    flatId: data.scope === 'unit' ? data.flatId : null,
    flatIds,
    generationDay: data.generationDay,
    dueDay: data.dueDay,
    startBillingPeriod,
    endBillingPeriod,
    chargeLines,
  };
}

function validateCreateRequest(data) {
  const allowed = [
    'schemaVersion', 'communityId', 'currency', 'frequency', 'idempotencyKey', ...SCHEDULE_TERMS,
  ];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !allowed.includes(key))) fail('Invalid billing schedule request.');
  if (data.schemaVersion !== SCHEDULE_SCHEMA_VERSION) fail('Billing schedule schema version must be 2.');
  if (!validId(data.communityId) || !validId(data.idempotencyKey)) fail('Community and idempotencyKey are required.');
  if (data.currency !== 'INR') fail('Billing schedules support INR only.');
  if (data.frequency !== 'monthly') fail('Billing schedules must use monthly frequency.');
  if (!Object.hasOwn(data, 'endBillingPeriod')) fail('endBillingPeriod must be a period or null.');
  return {
    communityId: data.communityId,
    idempotencyKey: data.idempotencyKey,
    currency: 'INR',
    frequency: 'monthly',
    ...validateScheduleTerms(data),
  };
}

function validateRevisionRequest(data) {
  const allowed = ['communityId', 'scheduleId', 'expectedRevisionId', 'idempotencyKey', ...SCHEDULE_TERMS, 'reason'];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !allowed.includes(key)) ||
      !['communityId', 'scheduleId', 'expectedRevisionId', 'idempotencyKey']
        .every(key => validId(data[key]))) {
    fail('Invalid billing schedule revision request.');
  }
  if (!Object.hasOwn(data, 'endBillingPeriod')) fail('endBillingPeriod must be a period or null.');
  if (data.reason != null && (typeof data.reason !== 'string' || data.reason.trim().length > 300)) {
    fail('Revision reason must contain 300 characters or fewer.');
  }
  return {
    communityId: data.communityId,
    scheduleId: data.scheduleId,
    expectedRevisionId: data.expectedRevisionId,
    idempotencyKey: data.idempotencyKey,
    ...validateScheduleTerms(data),
    reason: clean(data.reason) || null,
  };
}

function scheduleTerms(schedule) {
  return {
    schemaVersion: SCHEDULE_SCHEMA_VERSION,
    communityId: schedule.communityId,
    currency: 'INR',
    frequency: 'monthly',
    scope: schedule.scope,
    buildingId: schedule.buildingId,
    flatId: schedule.flatId,
    flatIds: schedule.flatIds,
    generationDay: schedule.generationDay,
    dueDay: schedule.dueDay,
    startBillingPeriod: schedule.startBillingPeriod,
    endBillingPeriod: schedule.endBillingPeriod,
    chargeLines: schedule.chargeLines,
  };
}

function hasValidStoredScheduleTerms(schedule) {
  try {
    const flatIds = schedule.scope === 'units' ? schedule.flatIds : null;
    const normalized = validateScheduleTerms({...schedule, flatIds});
    return schedule.scope === 'units' ?
      JSON.stringify(normalized.flatIds) === JSON.stringify(schedule.flatIds) :
      Array.isArray(schedule.flatIds) && schedule.flatIds.length === 0;
  } catch (_) {
    return false;
  }
}

function isBillingPeriodInSchedule(schedule, period) {
  if (typeof period !== 'string' || !PERIOD_PATTERN.test(period) ||
      typeof schedule?.startBillingPeriod !== 'string' || !PERIOD_PATTERN.test(schedule.startBillingPeriod) ||
      (schedule.endBillingPeriod !== null &&
        (typeof schedule.endBillingPeriod !== 'string' || !PERIOD_PATTERN.test(schedule.endBillingPeriod)))) return false;
  return period >= schedule.startBillingPeriod &&
    (schedule.endBillingPeriod === null || period <= schedule.endBillingPeriod);
}

function effectivePeriodForRevision(schedule, input, community, nowMs) {
  const candidates = [input.startBillingPeriod, localBillingPeriodFromMillis(nowMs, community)];
  const hasReservation = assertGenerationFence(schedule);
  if (hasReservation) candidates.push(nextBillingPeriod(schedule.generationInProgressBillingPeriod));
  if (schedule.generatedThroughBillingPeriod != null) {
    if (typeof schedule.generatedThroughBillingPeriod !== 'string' ||
        !PERIOD_PATTERN.test(schedule.generatedThroughBillingPeriod)) {
      fail('The stored generated-through period is invalid.', 'failed-precondition');
    }
    const generatedThrough = schedule.generatedThroughBillingPeriod;
    candidates.push(nextBillingPeriod(generatedThrough));
  }
  const effectiveFromBillingPeriod = candidates.sort().at(-1);
  if (!PERIOD_PATTERN.test(effectiveFromBillingPeriod)) {
    fail('The effective billing period is outside the supported range.', 'failed-precondition');
  }
  if (input.endBillingPeriod !== null && input.endBillingPeriod < effectiveFromBillingPeriod) {
    fail('endBillingPeriod must not be before the effective billing period.');
  }
  return effectiveFromBillingPeriod;
}

function assertGenerationFence(schedule) {
  const period = schedule.generationInProgressBillingPeriod;
  const revisionId = schedule.generationInProgressScheduleRevisionId;
  if ((period == null) !== (revisionId == null)) {
    fail('The schedule generation fence is inconsistent.', 'failed-precondition');
  }
  if (period == null) return false;
  if (typeof period !== 'string' || !PERIOD_PATTERN.test(period) || !validId(revisionId)) {
    fail('The schedule generation fence is invalid.', 'failed-precondition');
  }
  return true;
}

/** Calendar keys are strings; interpretation as local dates belongs to community time zone logic. */
function billingScheduleDateKeys(schedule, period) {
  if (!isBillingPeriodInSchedule(schedule, period) ||
      !Number.isInteger(schedule.generationDay) || schedule.generationDay < 1 || schedule.generationDay > 28 ||
      !Number.isInteger(schedule.dueDay) || schedule.dueDay < 1 || schedule.dueDay > 28) return null;
  const dayKey = day => `${period}-${String(day).padStart(2, '0')}`;
  return {generationDateKey: dayKey(schedule.generationDay), dueDateKey: dayKey(schedule.dueDay)};
}

function scheduleRefs(db, scheduleId) {
  return {
    schedule: db.collection('billingSchedules').doc(scheduleId),
    revisionCollection: db.collection(`billingSchedules/${scheduleId}/revisions`),
  };
}

async function validateScopeOwnership(db, tx, input) {
  if (input.scope === 'building' || input.scope === 'unit') {
    const building = await tx.get(db.collection('buildings').doc(input.buildingId));
    if (!building.exists || building.data().communityId !== input.communityId) {
      fail('Building is outside the authorized community.', 'permission-denied');
    }
  }
  if (input.scope === 'unit') {
    const flat = await tx.get(db.collection('flats').doc(input.flatId));
    if (!flat.exists || flat.data().communityId !== input.communityId ||
        flat.data().buildingId !== input.buildingId) {
      fail('Selected unit is outside the authorized scope.', 'permission-denied');
    }
  }
  if (input.scope === 'units') {
    const flats = await Promise.all(input.flatIds.map(id => tx.get(db.collection('flats').doc(id))));
    if (flats.some(flat => !flat.exists || flat.data().communityId !== input.communityId)) {
      fail('A selected unit is outside the authorized community.', 'permission-denied');
    }
  }
}

function assertScheduleIdentity(schedule, scheduleId, communityId) {
  if (!schedule || schedule.schemaVersion !== SCHEDULE_SCHEMA_VERSION || schedule.id !== scheduleId ||
      schedule.communityId !== communityId || schedule.currency !== 'INR' || schedule.frequency !== 'monthly' ||
      !['active', 'paused', 'stopped'].includes(schedule.status)) {
    fail('The schedule is invalid or outside the authorized community.', 'permission-denied');
  }
}

async function createBillingScheduleV2Core({db, auth, data, now = Date.now}) {
  const input = validateCreateRequest(data);
  const scheduleId = billingScheduleId(input.communityId, input.idempotencyKey);
  const revisionId = 'revision_1';
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, scheduleId);
  const revisionRef = revisionCollection.doc(revisionId);
  const requestHash = hash(input);
  let alreadyCompleted = false;

  await db.runTransaction(async tx => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, tx);
    const existing = await tx.get(scheduleRef);
    const existingRevision = await tx.get(revisionRef);
    if (existing.exists) {
      const schedule = existing.data();
      assertScheduleIdentity(schedule, scheduleId, input.communityId);
      if (schedule.requestHash !== requestHash || !existingRevision.exists ||
          existingRevision.data().requestHash !== requestHash) {
        fail('This idempotencyKey belongs to different billing schedule terms.', 'already-exists');
      }
      const currentRevisionSnapshot = schedule.currentRevisionId === revisionId ?
        existingRevision : await tx.get(revisionCollection.doc(schedule.currentRevisionId));
      if (!currentRevisionSnapshot.exists) fail('The current schedule revision is missing.', 'failed-precondition');
      assertCurrentRevision(schedule, currentRevisionSnapshot.data(), scheduleId);
      alreadyCompleted = true;
      return;
    }
    if (existingRevision.exists) fail('Schedule revision exists without its schedule root.', 'failed-precondition');
    await validateScopeOwnership(db, tx, input);

    const createdAt = Timestamp.fromMillis(now());
    const terms = scheduleTerms(input);
    const effectiveFromBillingPeriod = input.startBillingPeriod;
    tx.create(scheduleRef, {
      ...terms,
      id: scheduleId,
      status: 'active',
      currentRevisionId: revisionId,
      currentRevisionEffectiveFromBillingPeriod: effectiveFromBillingPeriod,
      revisionNo: 1,
      idempotencyKey: input.idempotencyKey,
      requestHash,
      createdBy: actor.uid,
      createdAt,
      updatedBy: actor.uid,
      updatedAt: createdAt,
      statusChangedBy: actor.uid,
      statusChangedAt: createdAt,
      lifecycleRevision: 0,
      generatedThroughBillingPeriod: null,
      generationInProgressBillingPeriod: null,
      generationInProgressScheduleRevisionId: null,
    });
    tx.create(revisionRef, {
      ...terms,
      effectiveFromBillingPeriod,
      scheduleId,
      revisionId,
      revisionNo: 1,
      idempotencyKey: input.idempotencyKey,
      requestHash,
      reason: null,
      createdBy: actor.uid,
      createdAt,
    });
  });

  return {success: true, scheduleId, revisionId, revisionNo: 1, alreadyCompleted};
}

function assertCurrentRevision(schedule, revision, scheduleId) {
  if (!revision || !hasValidStoredScheduleTerms(revision) || !hasValidStoredScheduleTerms(schedule) ||
      !validId(schedule.currentRevisionId) ||
      !Number.isSafeInteger(schedule.revisionNo) || schedule.revisionNo < 1 ||
      revision.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      revision.scheduleId !== scheduleId || revision.revisionId !== schedule.currentRevisionId ||
      !Number.isSafeInteger(revision.revisionNo) || revision.revisionNo < 1 ||
      revision.revisionNo !== schedule.revisionNo || revision.communityId !== schedule.communityId ||
      revision.currency !== schedule.currency || revision.frequency !== schedule.frequency ||
      schedule.currentRevisionEffectiveFromBillingPeriod !== revision.effectiveFromBillingPeriod ||
      typeof revision.effectiveFromBillingPeriod !== 'string' ||
      !PERIOD_PATTERN.test(revision.effectiveFromBillingPeriod) ||
      !isBillingPeriodInSchedule(revision, revision.effectiveFromBillingPeriod) ||
      JSON.stringify(scheduleTerms(schedule)) !== JSON.stringify(scheduleTerms(revision))) {
    fail('The current immutable schedule revision is inconsistent.', 'failed-precondition');
  }
}

async function reviseBillingScheduleV2Core({db, auth, data, now = Date.now}) {
  const input = validateRevisionRequest(data);
  const revisionId = billingScheduleRevisionId(input.scheduleId, input.idempotencyKey);
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, input.scheduleId);
  const revisionRef = revisionCollection.doc(revisionId);
  const requestHash = hash(input);
  let revisionNo;
  let alreadyCompleted = false;
  const nowMs = now();

  await db.runTransaction(async tx => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, tx);
    const scheduleSnapshot = await tx.get(scheduleRef);
    const existingRevision = await tx.get(revisionRef);
    if (!scheduleSnapshot.exists) fail('Billing schedule was not found.', 'not-found');
    const schedule = scheduleSnapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);
    if (existingRevision.exists) {
      const existing = existingRevision.data();
      if (existing.requestHash !== requestHash || existing.scheduleId !== input.scheduleId) {
        fail('This revision idempotencyKey belongs to different schedule terms.', 'already-exists');
      }
      if (typeof existing.effectiveFromBillingPeriod !== 'string' ||
          !PERIOD_PATTERN.test(existing.effectiveFromBillingPeriod) ||
          !isBillingPeriodInSchedule(existing, existing.effectiveFromBillingPeriod)) {
        fail('The immutable schedule revision is inconsistent.', 'failed-precondition');
      }
      const currentRevisionSnapshot = existing.revisionId === schedule.currentRevisionId ?
        existingRevision : await tx.get(revisionCollection.doc(schedule.currentRevisionId));
      if (!currentRevisionSnapshot.exists) fail('The current schedule revision is missing.', 'failed-precondition');
      assertCurrentRevision(schedule, currentRevisionSnapshot.data(), input.scheduleId);
      revisionNo = existing.revisionNo;
      alreadyCompleted = true;
      return;
    }
    if (schedule.status === 'stopped') fail('A stopped billing schedule cannot be revised.');
    if (schedule.currentRevisionId !== input.expectedRevisionId) {
      fail('The schedule revision is stale. Refresh and try again.', 'failed-precondition');
    }
    if (!Number.isSafeInteger(schedule.revisionNo) || schedule.revisionNo < 1 ||
        !Number.isSafeInteger(schedule.revisionNo + 1)) fail('Invalid schedule revision number.', 'failed-precondition');
    const previousSnapshot = await tx.get(revisionCollection.doc(schedule.currentRevisionId));
    if (!previousSnapshot.exists) fail('The current schedule revision is missing.', 'failed-precondition');
    assertCurrentRevision(schedule, previousSnapshot.data(), input.scheduleId);
    await validateScopeOwnership(db, tx, input);

    const terms = scheduleTerms({...schedule, ...input});
    const effectiveFromBillingPeriod = effectivePeriodForRevision(schedule, input, actor.community, nowMs);
    const createdAt = Timestamp.fromMillis(nowMs);
    revisionNo = schedule.revisionNo + 1;
    tx.create(revisionRef, {
      ...terms,
      effectiveFromBillingPeriod,
      scheduleId: input.scheduleId,
      revisionId,
      revisionNo,
      previousRevisionId: schedule.currentRevisionId,
      idempotencyKey: input.idempotencyKey,
      requestHash,
      reason: input.reason,
      createdBy: actor.uid,
      createdAt,
    });
    tx.update(scheduleRef, {
      ...terms,
      currentRevisionId: revisionId,
      currentRevisionEffectiveFromBillingPeriod: effectiveFromBillingPeriod,
      revisionNo,
      updatedBy: actor.uid,
      updatedAt: createdAt,
    });
  });

  return {success: true, scheduleId: input.scheduleId, revisionId, revisionNo, alreadyCompleted};
}

function validateLifecycleRequest(data) {
  const allowed = ['communityId', 'scheduleId', 'reason'];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !allowed.includes(key)) ||
      !validId(data.communityId) || !validId(data.scheduleId) ||
      (data.reason != null && (typeof data.reason !== 'string' || data.reason.trim().length > 300))) {
    fail('Invalid billing schedule lifecycle request.');
  }
  return {communityId: data.communityId, scheduleId: data.scheduleId, reason: clean(data.reason) || null};
}

function validateReservationRequest(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !['communityId', 'scheduleId', 'billingPeriod'].includes(key)) ||
      !validId(data.communityId) || !validId(data.scheduleId)) {
    fail('Invalid billing schedule generation reservation request.');
  }
  return {
    communityId: data.communityId,
    scheduleId: data.scheduleId,
    billingPeriod: billingPeriod(data.billingPeriod, 'billingPeriod'),
  };
}

function localDateKeyFromMillis(value, community) {
  // Validate the trusted time zone through the same community-local period helper
  // used by billing batches before formatting the day key.
  localBillingPeriodFromMillis(value, community);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: clean(community.timeZone), year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date(value));
  const part = type => parts.find(item => item.type === type).value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function assertPinnedRevision(schedule, revision, generation, scheduleId, communityId) {
  const period = generation.billingPeriod;
  const dateKeys = billingScheduleDateKeys(revision || {}, period);
  if (!revision || !hasValidStoredScheduleTerms(revision) || revision.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      revision.scheduleId !== scheduleId || revision.revisionId !== generation.scheduleRevisionId ||
      !Number.isSafeInteger(revision.revisionNo) || revision.revisionNo !== generation.scheduleRevisionNo || revision.communityId !== communityId ||
      revision.currency !== 'INR' || revision.frequency !== 'monthly' ||
      typeof revision.effectiveFromBillingPeriod !== 'string' ||
      !PERIOD_PATTERN.test(revision.effectiveFromBillingPeriod) || revision.effectiveFromBillingPeriod > period ||
      !isBillingPeriodInSchedule(revision, period) || !dateKeys ||
      generation.generationDateKey !== dateKeys.generationDateKey ||
      generation.dueDateKey !== dateKeys.dueDateKey) {
    fail('The reserved generation does not match its immutable schedule revision.', 'failed-precondition');
  }
}

function assertExistingGeneration(generation, scheduleId, communityId, billingPeriodValue) {
  if (!generation || generation.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      generation.scheduleId !== scheduleId || generation.communityId !== communityId ||
      generation.billingPeriod !== billingPeriodValue ||
      !['reserved', 'executing', 'completed', 'reconciliation_required'].includes(generation.status) ||
      !validId(generation.scheduleRevisionId) || !Number.isSafeInteger(generation.scheduleRevisionNo) ||
      generation.scheduleRevisionNo < 1 || !validId(generation.createdBy) ||
      !timestampIso(generation.createdAt) || !timestampIso(generation.updatedAt) ||
      typeof generation.generationDateKey !== 'string' || typeof generation.dueDateKey !== 'string') {
    fail('The existing billing schedule generation reservation is inconsistent.', 'failed-precondition');
  }
}

function assertGenerationFenceMatches(schedule, generation) {
  assertGenerationFence(schedule);
  if (schedule.generationInProgressBillingPeriod !== generation.billingPeriod ||
      schedule.generationInProgressScheduleRevisionId !== generation.scheduleRevisionId) {
    fail('The schedule generation fence does not match its reservation.', 'failed-precondition');
  }
}

function timestampIso(value) {
  if (typeof value?.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return null;
}

function reservationResult(generation, alreadyCompleted) {
  return {
    ...generation,
    createdAt: timestampIso(generation.createdAt),
    updatedAt: timestampIso(generation.updatedAt),
    alreadyCompleted,
  };
}

async function reserveBillingSchedulePeriodV2Core({db, auth, data, now = Date.now,
  requireAuthority = requireOperationalAdmin}) {
  const input = validateReservationRequest(data);
  const nowMs = now();
  if (!Number.isFinite(nowMs)) fail('The current time is invalid.', 'failed-precondition');
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, input.scheduleId);
  const generationRef = db.collection(`billingSchedules/${input.scheduleId}/generations`).doc(input.billingPeriod);
  let result;
  let alreadyCompleted = false;

  await db.runTransaction(async tx => {
    const actor = await requireAuthority(db, auth, input.communityId, tx);
    const scheduleSnapshot = await tx.get(scheduleRef);
    const generationSnapshot = await tx.get(generationRef);
    if (!scheduleSnapshot.exists) fail('Billing schedule was not found.', 'not-found');
    const schedule = scheduleSnapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);

    if (generationSnapshot.exists) {
      const generation = generationSnapshot.data();
      assertExistingGeneration(generation, input.scheduleId, input.communityId, input.billingPeriod);
      if (['reserved', 'executing'].includes(generation.status)) {
        assertGenerationFenceMatches(schedule, generation);
      } else {
        const generatedThrough = schedule.generatedThroughBillingPeriod;
        if (typeof generatedThrough !== 'string' || !PERIOD_PATTERN.test(generatedThrough) ||
            generatedThrough < input.billingPeriod) {
          fail('The terminal generation is not accounted by the schedule.', 'failed-precondition');
        }
      }
      const currentRevisionSnapshot = await tx.get(revisionCollection.doc(schedule.currentRevisionId));
      if (!currentRevisionSnapshot.exists) fail('The current schedule revision is missing.', 'failed-precondition');
      assertCurrentRevision(schedule, currentRevisionSnapshot.data(), input.scheduleId);
      const pinnedRevisionSnapshot = generation.scheduleRevisionId === schedule.currentRevisionId ?
        currentRevisionSnapshot : await tx.get(revisionCollection.doc(generation.scheduleRevisionId));
      if (!pinnedRevisionSnapshot.exists) fail('The pinned schedule revision is missing.', 'failed-precondition');
      assertPinnedRevision(schedule, pinnedRevisionSnapshot.data(), generation, input.scheduleId, input.communityId);
      result = generation;
      alreadyCompleted = true;
      return;
    }

    if (schedule.status !== 'active') fail('Only an active billing schedule can reserve a new period.', 'failed-precondition');
    if (assertGenerationFence(schedule)) {
      fail('Another billing period is already reserved for this schedule.', 'failed-precondition');
    }
    if (!isBillingPeriodInSchedule(schedule, input.billingPeriod)) {
      fail('The billing period is outside the schedule bounds.', 'failed-precondition');
    }
    let expectedPeriod = schedule.startBillingPeriod;
    if (schedule.generatedThroughBillingPeriod != null) {
      if (typeof schedule.generatedThroughBillingPeriod !== 'string' ||
          !PERIOD_PATTERN.test(schedule.generatedThroughBillingPeriod)) {
        fail('The stored generated-through period is invalid.', 'failed-precondition');
      }
      expectedPeriod = nextBillingPeriod(schedule.generatedThroughBillingPeriod);
    }
    if (input.billingPeriod !== expectedPeriod) {
      fail('Only the next ungenerated billing period can be reserved.', 'failed-precondition');
    }

    const currentRevisionSnapshot = await tx.get(revisionCollection.doc(schedule.currentRevisionId));
    if (!currentRevisionSnapshot.exists) fail('The current schedule revision is missing.', 'failed-precondition');
    const revision = currentRevisionSnapshot.data();
    assertCurrentRevision(schedule, revision, input.scheduleId);
    if (revision.effectiveFromBillingPeriod > input.billingPeriod ||
        !isBillingPeriodInSchedule(revision, input.billingPeriod)) {
      fail('The current schedule revision is not effective for this billing period.', 'failed-precondition');
    }

    const localPeriod = localBillingPeriodFromMillis(nowMs, actor.community);
    if (input.billingPeriod !== localPeriod) {
      fail('Only the community-local current billing period can be reserved.', 'failed-precondition');
    }
    const dateKeys = billingScheduleDateKeys(revision, input.billingPeriod);
    const localDateKey = localDateKeyFromMillis(nowMs, actor.community);
    if (!dateKeys || localDateKey < dateKeys.generationDateKey || localDateKey > dateKeys.dueDateKey) {
      fail('The current community-local date is outside the generation window.', 'failed-precondition');
    }

    const createdAt = Timestamp.fromMillis(nowMs);
    result = {
      schemaVersion: SCHEDULE_SCHEMA_VERSION,
      scheduleId: input.scheduleId,
      communityId: input.communityId,
      billingPeriod: input.billingPeriod,
      scheduleRevisionId: schedule.currentRevisionId,
      scheduleRevisionNo: schedule.revisionNo,
      generationDateKey: dateKeys.generationDateKey,
      dueDateKey: dateKeys.dueDateKey,
      status: 'reserved',
      createdBy: actor.uid,
      updatedBy: actor.uid,
      createdAt,
      updatedAt: createdAt,
    };
    tx.create(generationRef, result);
    tx.update(scheduleRef, {
      generationInProgressBillingPeriod: input.billingPeriod,
      generationInProgressScheduleRevisionId: schedule.currentRevisionId,
      updatedBy: actor.uid,
      updatedAt: createdAt,
    });
  });

  return {success: true, ...reservationResult(result, alreadyCompleted)};
}

function validateExecutionRequest(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !['communityId', 'scheduleId', 'billingPeriod'].includes(key)) ||
      !validId(data.communityId) || !validId(data.scheduleId)) {
    fail('Invalid billing schedule execution request.');
  }
  return {
    communityId: data.communityId,
    scheduleId: data.scheduleId,
    billingPeriod: billingPeriod(data.billingPeriod, 'billingPeriod'),
  };
}

function timestampMillis(value) {
  const millis = typeof value?.toMillis === 'function' ? value.toMillis() :
    value instanceof Date ? value.getTime() : NaN;
  return Number.isSafeInteger(millis) ? millis : null;
}

function scheduleBatchIdempotencyKey(scheduleId, billingPeriodValue) {
  return `schedule_v2_${hash(['billing-schedule', scheduleId, billingPeriodValue])}`;
}

function batchProgress(batch) {
  const generation = batch.generation;
  return {
    status: batch.status,
    generation: {
      targetCount: generation.targetCount,
      materializedCount: generation.materializedCount,
      completed: generation.completed,
      skipped: generation.skipped,
      reconciliationRequired: generation.reconciliationRequired,
      failed: generation.failed,
    },
  };
}

function assertBatchLinkage(batch, batchRevision, batchId, generation, revision, idempotencyKey) {
  const chargeTerms = validateChargeLines(revision.chargeLines);
  if (!batch || batch.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      batch.communityId !== generation.communityId || batch.billingPeriod !== generation.billingPeriod ||
      batch.scheduleId !== generation.scheduleId || batch.scheduleRevisionId !== generation.scheduleRevisionId ||
      batch.idempotencyKey !== idempotencyKey || batch.currentRevisionId !== 'revision_1' ||
      batch.currency !== 'INR' || batch.dueDateKey !== generation.dueDateKey ||
      batch.amountMinor !== chargeTerms.amountMinor ||
      JSON.stringify(batch.chargeLines) !== JSON.stringify(chargeTerms.chargeLines) ||
      !batchRevision || batchRevision.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      batchRevision.billingBatchId !== batchId || batchRevision.revisionId !== 'revision_1' ||
      batchRevision.revisionNo !== 1 || batchRevision.communityId !== generation.communityId ||
      batchRevision.billingPeriod !== generation.billingPeriod ||
      batchRevision.scheduleId !== generation.scheduleId ||
      batchRevision.scheduleRevisionId !== generation.scheduleRevisionId ||
      batchRevision.currency !== 'INR' || batchRevision.dueDateKey !== generation.dueDateKey ||
      batchRevision.amountMinor !== chargeTerms.amountMinor ||
      JSON.stringify(batchRevision.chargeLines) !== JSON.stringify(chargeTerms.chargeLines)) {
    fail('The persisted billing batch does not match its schedule reservation.', 'failed-precondition');
  }
}

function assertBatchProgressState(batch) {
  const generation = batch?.generation;
  if (!generation || !['generating', 'unresolved', 'completed', 'reconciliation_required'].includes(batch.status) ||
      !['targetCount', 'materializedCount', 'completed', 'skipped', 'reconciliationRequired', 'failed']
        .every(key => Number.isSafeInteger(generation[key]) && generation[key] >= 0) ||
      generation.materializedCount > generation.targetCount ||
      generation.completed + generation.skipped + generation.reconciliationRequired > generation.targetCount) {
    fail('The persisted billing batch progress is invalid.', 'failed-precondition');
  }
}

function assertTerminalBatch(batch, generation) {
  assertBatchProgressState(batch);
  const progress = batch.generation;
  const accounted = progress.completed + progress.skipped + progress.reconciliationRequired;
  if (!['completed', 'reconciliation_required'].includes(batch.status) || progress.failed !== 0 ||
      progress.materializedCount !== progress.targetCount || accounted !== progress.targetCount ||
      (batch.status === 'completed' && progress.reconciliationRequired !== 0) ||
      (batch.status === 'reconciliation_required' && progress.reconciliationRequired === 0) ||
      (generation && generation.status !== batch.status)) {
    fail('The billing batch is not in a terminal accounted state.', 'failed-precondition');
  }
}

function assertReservationCreatedDuringWindow(generation, revision, community) {
  const createdAtMs = timestampMillis(generation.createdAt);
  const dateKeys = billingScheduleDateKeys(revision, generation.billingPeriod);
  if (createdAtMs === null || !dateKeys ||
      localBillingPeriodFromMillis(createdAtMs, community) !== generation.billingPeriod) {
    fail('The reservation creation time is invalid.', 'failed-precondition');
  }
  const localDate = localDateKeyFromMillis(createdAtMs, community);
  if (localDate < dateKeys.generationDateKey || localDate > dateKeys.dueDateKey) {
    fail('The reservation was not created during its generation window.', 'failed-precondition');
  }
  return createdAtMs;
}

function assertTerminalGenerationAccounting(schedule, generation) {
  const generatedThrough = schedule.generatedThroughBillingPeriod;
  if (typeof generatedThrough !== 'string' || !PERIOD_PATTERN.test(generatedThrough) ||
      generatedThrough < generation.billingPeriod || !timestampIso(generation.completedAt) ||
      !validId(generation.batchId)) {
    fail('The terminal generation is not accounted by the schedule.', 'failed-precondition');
  }
}

function assertGenerationSequence(schedule, generation, pinnedRevision) {
  let expectedPeriod;
  if (schedule.generatedThroughBillingPeriod == null) {
    expectedPeriod = pinnedRevision.startBillingPeriod;
  } else {
    if (typeof schedule.generatedThroughBillingPeriod !== 'string' ||
        !PERIOD_PATTERN.test(schedule.generatedThroughBillingPeriod)) {
      fail('The stored generated-through period is invalid.', 'failed-precondition');
    }
    expectedPeriod = nextBillingPeriod(schedule.generatedThroughBillingPeriod);
  }
  if (generation.billingPeriod !== expectedPeriod) {
    fail('The reserved billing period is not next in the generation sequence.', 'failed-precondition');
  }
}

function trustedBatchRequest(generation, revision, idempotencyKey) {
  const request = {
    communityId: generation.communityId,
    billingPeriod: generation.billingPeriod,
    idempotencyKey,
    scope: revision.scope,
    chargeLines: revision.chargeLines,
    dueDate: generation.dueDateKey,
  };
  if (revision.scope === 'building' || revision.scope === 'unit') request.buildingId = revision.buildingId;
  if (revision.scope === 'unit') request.flatId = revision.flatId;
  if (revision.scope === 'units') request.flatIds = revision.flatIds;
  return request;
}

function terminalExecutionResult(generation, alreadyCompleted) {
  return {
    success: true,
    ...reservationResult(generation, alreadyCompleted),
    resumeRequired: false,
  };
}

async function executeBillingSchedulePeriodV2Core({db, auth, data, now = Date.now,
  createBatch = createMonthlyBillingBatchV2Core, requireAuthority = requireOperationalAdmin}) {
  const input = validateExecutionRequest(data);
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, input.scheduleId);
  const generationRef = db.collection(`billingSchedules/${input.scheduleId}/generations`).doc(input.billingPeriod);
  const idempotencyKey = scheduleBatchIdempotencyKey(input.scheduleId, input.billingPeriod);
  const expectedBatchId = monthlyBillingBatchId(input.communityId, idempotencyKey);
  const nowMs = now();
  if (!Number.isSafeInteger(nowMs)) fail('The current time is invalid.', 'failed-precondition');
  let context;
  let terminalResult;

  await db.runTransaction(async tx => {
    const actor = await requireAuthority(db, auth, input.communityId, tx);
    const [scheduleSnapshot, generationSnapshot] = await Promise.all([tx.get(scheduleRef), tx.get(generationRef)]);
    if (!scheduleSnapshot.exists) fail('Billing schedule was not found.', 'not-found');
    if (!generationSnapshot.exists) fail('The billing period has not been reserved.', 'failed-precondition');
    const schedule = scheduleSnapshot.data();
    const generation = generationSnapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);
    assertExistingGeneration(generation, input.scheduleId, input.communityId, input.billingPeriod);

    if (['completed', 'reconciliation_required'].includes(generation.status)) {
      assertTerminalGenerationAccounting(schedule, generation);
      const revisionSnapshot = await tx.get(revisionCollection.doc(generation.scheduleRevisionId));
      const batchRef = db.collection('billingBatches').doc(generation.batchId);
      const batchSnapshot = await tx.get(batchRef);
      const batchRevisionSnapshot = await tx.get(db.collection(`billingBatches/${generation.batchId}/revisions`).doc('revision_1'));
      if (!revisionSnapshot.exists || !batchSnapshot.exists || !batchRevisionSnapshot.exists) {
        fail('The terminal generation record is incomplete.', 'failed-precondition');
      }
      const pinnedRevision = revisionSnapshot.data();
      assertPinnedRevision(schedule, pinnedRevision, generation, input.scheduleId, input.communityId);
      if (generation.batchIdempotencyKey !== idempotencyKey || expectedBatchId !== generation.batchId) {
        fail('The terminal generation batch identity is inconsistent.', 'failed-precondition');
      }
      const batch = batchSnapshot.data();
      assertBatchLinkage(batch, batchRevisionSnapshot.data(), generation.batchId, generation, pinnedRevision, idempotencyKey);
      assertTerminalBatch(batch, generation);
      terminalResult = terminalExecutionResult(generation, true);
      return;
    }

    if (!['reserved', 'executing'].includes(generation.status)) {
      fail('The billing period is not available for execution.', 'failed-precondition');
    }
    assertGenerationFenceMatches(schedule, generation);
    if (generation.batchId != null && generation.batchId !== expectedBatchId) {
      fail('The generation is linked to a different billing batch.', 'failed-precondition');
    }
    if (generation.batchIdempotencyKey != null && generation.batchIdempotencyKey !== idempotencyKey) {
      fail('The generation idempotency identity is inconsistent.', 'failed-precondition');
    }
    const revisionSnapshot = await tx.get(revisionCollection.doc(generation.scheduleRevisionId));
    if (!revisionSnapshot.exists) fail('The pinned schedule revision is missing.', 'failed-precondition');
    const pinnedRevision = revisionSnapshot.data();
    assertPinnedRevision(schedule, pinnedRevision, generation, input.scheduleId, input.communityId);
    assertGenerationSequence(schedule, generation, pinnedRevision);
    const dueDateValidationNowMs = assertReservationCreatedDuringWindow(generation, pinnedRevision, actor.community);
    const updatedAt = Timestamp.fromMillis(nowMs);
    tx.update(generationRef, {
      status: 'executing',
      batchId: expectedBatchId,
      batchIdempotencyKey: idempotencyKey,
      updatedBy: actor.uid,
      updatedAt,
    });
    context = {generation, pinnedRevision, dueDateValidationNowMs};
  });

  if (terminalResult) return terminalResult;
  const {generation, pinnedRevision, dueDateValidationNowMs} = context;
  const request = trustedBatchRequest(generation, pinnedRevision, idempotencyKey);
  const source = {scheduleId: input.scheduleId, scheduleRevisionId: generation.scheduleRevisionId};
  const batchResult = await createBatch({db, auth, data: request, now, source, dueDateValidationNowMs,
    requireAuthority});

  if (batchResult?.batchId !== expectedBatchId) {
    fail('The billing batch returned an unexpected identity.', 'failed-precondition');
  }
  if (batchResult.resumeRequired === true) {
    await persistExecutingBatchProgress({db, auth, input, generation, pinnedRevision, idempotencyKey,
      batchId: expectedBatchId, now, requireAuthority});
    const latest = (await generationRef.get()).data();
    return {...reservationResult(latest, false), success: true, resumeRequired: true,
      batchProgress: latest.latestBatchProgress};
  }
  if (batchResult.resumeRequired !== false || batchResult.failed !== 0 ||
      !['completed', 'reconciliation_required'].includes(batchResult.status)) {
    fail('The billing batch has not reached a terminal accounted state.', 'failed-precondition');
  }
  return finalizeScheduleGeneration({db, auth, input, generation, pinnedRevision, idempotencyKey,
    batchId: expectedBatchId, now, requireAuthority});
}

async function persistExecutingBatchProgress({db, auth, input, generation, pinnedRevision,
  idempotencyKey, batchId, now, requireAuthority}) {
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, input.scheduleId);
  const generationRef = db.collection(`billingSchedules/${input.scheduleId}/generations`).doc(input.billingPeriod);
  const batchRef = db.collection('billingBatches').doc(batchId);
  const batchRevisionRef = db.collection(`billingBatches/${batchId}/revisions`).doc('revision_1');
  await db.runTransaction(async tx => {
    const actor = await requireAuthority(db, auth, input.communityId, tx);
    const [scheduleSnapshot, generationSnapshot, batchSnapshot, batchRevisionSnapshot] = await Promise.all([
      tx.get(scheduleRef), tx.get(generationRef), tx.get(batchRef), tx.get(batchRevisionRef),
    ]);
    if (!scheduleSnapshot.exists || !generationSnapshot.exists || !batchSnapshot.exists || !batchRevisionSnapshot.exists) {
      fail('The executing billing batch state is incomplete.', 'failed-precondition');
    }
    const schedule = scheduleSnapshot.data();
    const currentGeneration = generationSnapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);
    assertExistingGeneration(currentGeneration, input.scheduleId, input.communityId, input.billingPeriod);
    if (currentGeneration.status !== 'executing') fail('The generation is no longer executing.', 'failed-precondition');
    assertGenerationFenceMatches(schedule, currentGeneration);
    if (currentGeneration.scheduleRevisionId !== generation.scheduleRevisionId ||
        currentGeneration.batchId !== batchId || currentGeneration.batchIdempotencyKey !== idempotencyKey) {
      fail('The executing generation identity changed.', 'failed-precondition');
    }
    const pinnedSnapshot = await tx.get(revisionCollection.doc(currentGeneration.scheduleRevisionId));
    if (!pinnedSnapshot.exists) fail('The pinned schedule revision is missing.', 'failed-precondition');
    const currentPinned = pinnedSnapshot.data();
    assertPinnedRevision(schedule, currentPinned, currentGeneration, input.scheduleId, input.communityId);
    assertBatchLinkage(batchSnapshot.data(), batchRevisionSnapshot.data(), batchId,
      currentGeneration, currentPinned, idempotencyKey);
    assertBatchProgressState(batchSnapshot.data());
    if (['completed', 'reconciliation_required'].includes(batchSnapshot.data().status)) {
      fail('The batch is terminal but execution reported more work.', 'failed-precondition');
    }
    tx.update(generationRef, {
      status: 'executing',
      batchId,
      batchIdempotencyKey: idempotencyKey,
      latestBatchProgress: batchProgress(batchSnapshot.data()),
      updatedBy: actor.uid,
      updatedAt: Timestamp.fromMillis(now()),
    });
  });
}

async function finalizeScheduleGeneration({db, auth, input, generation, pinnedRevision,
  idempotencyKey, batchId, now, requireAuthority}) {
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, input.scheduleId);
  const generationRef = db.collection(`billingSchedules/${input.scheduleId}/generations`).doc(input.billingPeriod);
  const batchRef = db.collection('billingBatches').doc(batchId);
  const batchRevisionRef = db.collection(`billingBatches/${batchId}/revisions`).doc('revision_1');
  let result;
  await db.runTransaction(async tx => {
    const actor = await requireAuthority(db, auth, input.communityId, tx);
    const [scheduleSnapshot, generationSnapshot, batchSnapshot, batchRevisionSnapshot] = await Promise.all([
      tx.get(scheduleRef), tx.get(generationRef), tx.get(batchRef), tx.get(batchRevisionRef),
    ]);
    if (!scheduleSnapshot.exists || !generationSnapshot.exists || !batchSnapshot.exists || !batchRevisionSnapshot.exists) {
      fail('The final billing generation state is incomplete.', 'failed-precondition');
    }
    const schedule = scheduleSnapshot.data();
    const currentGeneration = generationSnapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);
    assertExistingGeneration(currentGeneration, input.scheduleId, input.communityId, input.billingPeriod);
    const pinnedSnapshot = await tx.get(revisionCollection.doc(currentGeneration.scheduleRevisionId));
    if (!pinnedSnapshot.exists) fail('The pinned schedule revision is missing.', 'failed-precondition');
    const currentPinned = pinnedSnapshot.data();
    assertPinnedRevision(schedule, currentPinned, currentGeneration, input.scheduleId, input.communityId);
    assertBatchLinkage(batchSnapshot.data(), batchRevisionSnapshot.data(), batchId,
      currentGeneration, currentPinned, idempotencyKey);

    if (['completed', 'reconciliation_required'].includes(currentGeneration.status)) {
      assertTerminalGenerationAccounting(schedule, currentGeneration);
      assertTerminalBatch(batchSnapshot.data(), currentGeneration);
      result = terminalExecutionResult(currentGeneration, true);
      return;
    }
    if (currentGeneration.status !== 'executing') fail('The generation is no longer executing.', 'failed-precondition');
    assertGenerationFenceMatches(schedule, currentGeneration);
    if (currentGeneration.scheduleRevisionId !== generation.scheduleRevisionId ||
        currentGeneration.batchId !== batchId || currentGeneration.batchIdempotencyKey !== idempotencyKey) {
      fail('The generation identity changed before finalization.', 'failed-precondition');
    }
    assertTerminalBatch(batchSnapshot.data(), null);
    assertGenerationSequence(schedule, currentGeneration, currentPinned);
    const batchStatus = batchSnapshot.data().status;
    const completedAt = Timestamp.fromMillis(now());
    const counters = {...batchSnapshot.data().generation};
    const terminalPatch = {
      status: batchStatus,
      batchId,
      batchIdempotencyKey: idempotencyKey,
      latestBatchProgress: batchProgress(batchSnapshot.data()),
      terminalCounters: counters,
      updatedBy: actor.uid,
      completedAt,
      updatedAt: completedAt,
    };
    if (batchStatus === 'reconciliation_required') {
      terminalPatch.reconciliationRequiredCount = counters.reconciliationRequired;
    }
    tx.update(generationRef, terminalPatch);
    tx.update(scheduleRef, {
      generatedThroughBillingPeriod: input.billingPeriod,
      generationInProgressBillingPeriod: null,
      generationInProgressScheduleRevisionId: null,
      updatedBy: actor.uid,
      updatedAt: completedAt,
    });
    result = {...currentGeneration, ...terminalPatch};
  });
  return terminalExecutionResult(result, false);
}

async function transitionBillingSchedule({db, auth, data, now, fromStatuses, toStatus}) {
  const input = validateLifecycleRequest(data);
  const {schedule: scheduleRef} = scheduleRefs(db, input.scheduleId);
  let lifecycleRevision;
  await db.runTransaction(async tx => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, tx);
    const snapshot = await tx.get(scheduleRef);
    if (!snapshot.exists) fail('Billing schedule was not found.', 'not-found');
    const schedule = snapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);
    const currentRevisionSnapshot = await tx.get(db.collection(`billingSchedules/${input.scheduleId}/revisions`).doc(schedule.currentRevisionId));
    if (!currentRevisionSnapshot.exists) fail('The current schedule revision is missing.', 'failed-precondition');
    assertCurrentRevision(schedule, currentRevisionSnapshot.data(), input.scheduleId);
    if (!fromStatuses.includes(schedule.status)) {
      fail(`Cannot change billing schedule from ${schedule.status} to ${toStatus}.`, 'failed-precondition');
    }
    if (!Number.isSafeInteger(schedule.lifecycleRevision) || schedule.lifecycleRevision < 0 ||
        !Number.isSafeInteger(schedule.lifecycleRevision + 1)) fail('Invalid schedule lifecycle revision.', 'failed-precondition');
    lifecycleRevision = schedule.lifecycleRevision + 1;
    const changedAt = Timestamp.fromMillis(now());
    const eventRef = db.collection(`billingSchedules/${input.scheduleId}/lifecycleEvents`).doc(`transition_${lifecycleRevision}`);
    tx.create(eventRef, {
      scheduleId: input.scheduleId,
      communityId: input.communityId,
      fromStatus: schedule.status,
      toStatus,
      reason: input.reason,
      lifecycleRevision,
      changedBy: actor.uid,
      changedAt,
    });
    tx.update(scheduleRef, {
      status: toStatus,
      lifecycleRevision,
      statusChangedBy: actor.uid,
      statusChangedAt: changedAt,
      updatedBy: actor.uid,
      updatedAt: changedAt,
    });
  });
  return {success: true, scheduleId: input.scheduleId, status: toStatus, lifecycleRevision};
}

async function pauseBillingScheduleV2Core({db, auth, data, now = Date.now}) {
  return transitionBillingSchedule({db, auth, data, now, fromStatuses: ['active'], toStatus: 'paused'});
}

async function resumeBillingScheduleV2Core({db, auth, data, now = Date.now}) {
  return transitionBillingSchedule({db, auth, data, now, fromStatuses: ['paused'], toStatus: 'active'});
}

async function stopBillingScheduleV2Core({db, auth, data, now = Date.now}) {
  return transitionBillingSchedule({db, auth, data, now, fromStatuses: ['active', 'paused'], toStatus: 'stopped'});
}

module.exports = {
  billingScheduleId,
  billingScheduleRevisionId,
  billingScheduleDateKeys,
  isBillingPeriodInSchedule,
  nextBillingPeriod,
  createBillingScheduleV2Core,
  reviseBillingScheduleV2Core,
  reserveBillingSchedulePeriodV2Core,
  executeBillingSchedulePeriodV2Core,
  scheduleBatchIdempotencyKey,
  pauseBillingScheduleV2Core,
  resumeBillingScheduleV2Core,
  stopBillingScheduleV2Core,
};
