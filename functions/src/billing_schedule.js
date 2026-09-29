const {createHash} = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {requireOperationalAdmin} = require('./resident_identity');
const {validateChargeLines, localBillingPeriodFromMillis} = require('./billing_batch');

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

function assertExistingGeneration(schedule, generation, scheduleId, communityId, billingPeriodValue) {
  if (!generation || generation.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      generation.scheduleId !== scheduleId || generation.communityId !== communityId ||
      generation.billingPeriod !== billingPeriodValue || generation.status !== 'reserved' ||
      !validId(generation.scheduleRevisionId) || !Number.isSafeInteger(generation.scheduleRevisionNo) ||
      generation.scheduleRevisionNo < 1 || !validId(generation.createdBy) ||
      !timestampIso(generation.createdAt) || !timestampIso(generation.updatedAt) ||
      schedule.generationInProgressBillingPeriod !== billingPeriodValue ||
      schedule.generationInProgressScheduleRevisionId !== generation.scheduleRevisionId) {
    fail('The existing billing schedule generation reservation is inconsistent.', 'failed-precondition');
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

async function reserveBillingSchedulePeriodV2Core({db, auth, data, now = Date.now}) {
  const input = validateReservationRequest(data);
  const nowMs = now();
  if (!Number.isFinite(nowMs)) fail('The current time is invalid.', 'failed-precondition');
  const {schedule: scheduleRef, revisionCollection} = scheduleRefs(db, input.scheduleId);
  const generationRef = db.collection(`billingSchedules/${input.scheduleId}/generations`).doc(input.billingPeriod);
  let result;
  let alreadyCompleted = false;

  await db.runTransaction(async tx => {
    const actor = await requireOperationalAdmin(db, auth, input.communityId, tx);
    const scheduleSnapshot = await tx.get(scheduleRef);
    const generationSnapshot = await tx.get(generationRef);
    if (!scheduleSnapshot.exists) fail('Billing schedule was not found.', 'not-found');
    const schedule = scheduleSnapshot.data();
    assertScheduleIdentity(schedule, input.scheduleId, input.communityId);

    if (generationSnapshot.exists) {
      const generation = generationSnapshot.data();
      assertExistingGeneration(schedule, generation, input.scheduleId, input.communityId, input.billingPeriod);
      assertGenerationFence(schedule);
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
  pauseBillingScheduleV2Core,
  resumeBillingScheduleV2Core,
  stopBillingScheduleV2Core,
};
