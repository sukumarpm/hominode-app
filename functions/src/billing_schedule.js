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
  if (!revision || revision.schemaVersion !== SCHEDULE_SCHEMA_VERSION ||
      revision.scheduleId !== scheduleId || revision.revisionId !== schedule.currentRevisionId ||
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
  pauseBillingScheduleV2Core,
  resumeBillingScheduleV2Core,
  stopBillingScheduleV2Core,
};
