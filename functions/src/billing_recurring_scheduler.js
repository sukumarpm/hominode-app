const {FieldPath, FieldValue} = require('firebase-admin/firestore');
const {RegistrationError} = require('./register_resident');
const {operationalBillingSystemAuthority} = require('./resident_identity');
const {
  nextBillingPeriod,
  reserveBillingSchedulePeriodV2Core,
  executeBillingSchedulePeriodV2Core,
} = require('./billing_schedule');

const JOB_PATH = 'systemJobs/recurringBillingScheduler';
const PERIOD_PATTERN = /^(20\d{2}|2100)-(0[1-9]|1[0-2])$/;
const MAX_IN_PROGRESS_PER_RUN = 100;
const MAX_ACTIVE_PER_RUN = 100;
const QUERY_PAGE_SIZE = 50;
const MAX_RECORDED_ERRORS = 50;

function localCalendarKeys(nowMs, timeZone) {
  if (!Number.isFinite(nowMs) || typeof timeZone !== 'string' || !timeZone.trim()) {
    throw new RegistrationError('failed-precondition', 'Community calendar configuration is invalid.');
  }
  let parts;
  try {
    parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date(nowMs));
  } catch (_) {
    throw new RegistrationError('failed-precondition', 'Community time zone is invalid.');
  }
  const part = type => parts.find(item => item.type === type)?.value;
  const date = `${part('year')}-${part('month')}-${part('day')}`;
  return {billingPeriod: date.slice(0, 7), date};
}

function validateScheduleRow(row) {
  const schedule = row?.data;
  if (!row || typeof row.id !== 'string' || !row.id || !schedule || typeof schedule !== 'object' ||
      schedule.id !== row.id || schedule.schemaVersion !== 2 ||
      typeof schedule.communityId !== 'string' || !schedule.communityId.trim() ||
      schedule.communityId !== schedule.communityId.trim()) {
    throw new RegistrationError('failed-precondition', 'Stored recurring schedule identity is malformed.');
  }
  return schedule;
}

function classifyActivePeriod(schedule, local) {
  if (typeof schedule.startBillingPeriod !== 'string' || !PERIOD_PATTERN.test(schedule.startBillingPeriod) ||
      ![null, undefined].includes(schedule.generatedThroughBillingPeriod) &&
        (typeof schedule.generatedThroughBillingPeriod !== 'string' || !PERIOD_PATTERN.test(schedule.generatedThroughBillingPeriod)) ||
      !Number.isInteger(schedule.generationDay) || schedule.generationDay < 1 || schedule.generationDay > 28 ||
      !Number.isInteger(schedule.dueDay) || schedule.dueDay < schedule.generationDay || schedule.dueDay > 28) {
    throw new RegistrationError('failed-precondition', 'Stored recurring schedule terms are malformed.');
  }
  const expectedPeriod = schedule.generatedThroughBillingPeriod == null ?
    schedule.startBillingPeriod : nextBillingPeriod(schedule.generatedThroughBillingPeriod);
  if (expectedPeriod < schedule.startBillingPeriod ||
      (schedule.endBillingPeriod != null && (typeof schedule.endBillingPeriod !== 'string' ||
        !PERIOD_PATTERN.test(schedule.endBillingPeriod) || schedule.endBillingPeriod < schedule.startBillingPeriod))) {
    throw new RegistrationError('failed-precondition', 'Stored recurring schedule period bounds are malformed.');
  }
  if (schedule.endBillingPeriod != null && expectedPeriod > schedule.endBillingPeriod) {
    return {result: 'notDue', billingPeriod: expectedPeriod};
  }
  if (expectedPeriod < local.billingPeriod) return {result: 'missedPeriod', billingPeriod: expectedPeriod};
  if (expectedPeriod > local.billingPeriod) return {result: 'notDue', billingPeriod: expectedPeriod};
  const generationDate = `${expectedPeriod}-${String(schedule.generationDay).padStart(2, '0')}`;
  const dueDate = `${expectedPeriod}-${String(schedule.dueDay).padStart(2, '0')}`;
  if (local.date < generationDate) return {result: 'beforeWindow', billingPeriod: expectedPeriod};
  if (local.date > dueDate) return {result: 'missedWindow', billingPeriod: expectedPeriod};
  return {result: 'eligible', billingPeriod: expectedPeriod};
}

function emptySummary() {
  return {
    scanned: 0,
    resumed: 0,
    reserved: 0,
    completed: 0,
    reconciliationRequired: 0,
    executing: 0,
    notDue: 0,
    beforeWindow: 0,
    missedPeriod: 0,
    missedWindow: 0,
    errors: [],
  };
}

function addError(summary, row, period, error, logger) {
  const code = typeof error?.code === 'string' ? error.code.slice(0, 80) : 'internal';
  const expected = error instanceof RegistrationError;
  const reason = expected && typeof error.message === 'string' ? error.message.slice(0, 180) : 'Unexpected scheduler error.';
  if (summary.errors.length < MAX_RECORDED_ERRORS) {
    summary.errors.push({
      ...(typeof row?.id === 'string' ? {scheduleId: row.id} : {}),
      ...(typeof row?.data?.communityId === 'string' ? {communityId: row.data.communityId} : {}),
      ...(typeof period === 'string' ? {billingPeriod: period} : {}),
      code,
      reason,
    });
  }
  if (!expected) logger?.error?.('Unexpected recurring billing scheduler failure.', {
    scheduleId: typeof row?.id === 'string' ? row.id : null,
    communityId: typeof row?.data?.communityId === 'string' ? row.data.communityId : null,
    code,
  });
}

function countExecution(summary, result) {
  if (result?.resumeRequired === true) {
    summary.executing++;
  } else if (result?.status === 'reconciliation_required') {
    summary.reconciliationRequired++;
  } else if (result?.status === 'completed') {
    summary.completed++;
  } else {
    throw new RegistrationError('failed-precondition', 'Recurring billing execution returned an unknown state.');
  }
}

async function firestoreSchedulePage({db, phase, cursor, limit}) {
  const collection = db.collection('billingSchedules');
  let query = collection;
  if (phase === 'inProgress') {
    query = query.where('generationInProgressBillingPeriod', '!=', null)
      .orderBy('generationInProgressBillingPeriod').orderBy(FieldPath.documentId());
    if (cursor && Object.hasOwn(cursor, 'billingPeriod') && typeof cursor.scheduleId === 'string') {
      query = query.startAfter(cursor.billingPeriod, cursor.scheduleId);
    }
  } else {
    query = query.where('status', '==', 'active')
      .where('generationInProgressBillingPeriod', '==', null)
      .orderBy(FieldPath.documentId());
    if (typeof cursor === 'string' && cursor) query = query.startAfter(cursor);
  }
  const snapshot = await query.limit(limit + 1).get();
  const docs = snapshot.docs.slice(0, limit);
  const last = docs.at(-1);
  const lastData = last?.data();
  return {
    rows: docs.map(doc => ({id: doc.id, data: doc.data()})),
    hasMore: snapshot.docs.length > limit,
    cursor: phase === 'inProgress' && last ? {
      billingPeriod: lastData.generationInProgressBillingPeriod,
      scheduleId: last.id,
    } : last?.id ?? null,
  };
}

async function readJobState(db) {
  const snapshot = await db.collection('systemJobs').doc('recurringBillingScheduler').get();
  return snapshot.exists ? snapshot.data() : {};
}

async function persistJobState(db, state, summary, nowMs) {
  const ref = db.collection('systemJobs').doc('recurringBillingScheduler');
  await db.runTransaction(async tx => {
    await tx.get(ref);
    tx.set(ref, {
      ...state,
      lastRunAt: new Date(nowMs),
      lastRunSummary: summary,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

async function runRecurringBillingV2SchedulerCore({
  db,
  now = Date.now,
  requireAuthority = operationalBillingSystemAuthority,
  reserveCore = reserveBillingSchedulePeriodV2Core,
  executeCore = executeBillingSchedulePeriodV2Core,
  listPage = firestoreSchedulePage,
  logger = console,
  maxActiveSchedules = MAX_ACTIVE_PER_RUN,
  maxInProgressSchedules = MAX_IN_PROGRESS_PER_RUN,
  pageSize = QUERY_PAGE_SIZE,
}) {
  const nowMs = now();
  const summary = emptySummary();
  const job = await readJobState(db);
  const nextState = {};

  const processInProgress = async row => {
    let period;
    try {
      const schedule = validateScheduleRow(row);
      period = schedule.generationInProgressBillingPeriod;
      if (typeof period !== 'string' || !PERIOD_PATTERN.test(period)) {
        throw new RegistrationError('failed-precondition', 'Stored in-progress billing period is malformed.');
      }
      summary.resumed++;
      const result = await executeCore({
        db, auth: null,
        data: {communityId: schedule.communityId, scheduleId: row.id, billingPeriod: period},
        requireAuthority,
        now: () => nowMs,
      });
      countExecution(summary, result);
    } catch (error) {
      addError(summary, row, period, error, logger);
    }
  };

  let inProgressCursor = null;
  if (Object.hasOwn(job, 'inProgressCursorBillingPeriod') && typeof job.inProgressCursorScheduleId === 'string') {
    inProgressCursor = {billingPeriod: job.inProgressCursorBillingPeriod,
      scheduleId: job.inProgressCursorScheduleId};
  }
  let inProgressPage;
  let inProgressProcessed = 0;
  let inProgressPages = 0;
  let inProgressWrapped = false;
  const maxInProgressPages = Math.ceil(maxInProgressSchedules / pageSize) + 2;
  try {
    while (inProgressProcessed < maxInProgressSchedules && inProgressPages < maxInProgressPages) {
      inProgressPage = await listPage({db, phase: 'inProgress', cursor: inProgressCursor,
        limit: Math.min(pageSize, maxInProgressSchedules - inProgressProcessed)});
      inProgressPages++;
      if (!inProgressPage.rows.length && inProgressCursor && !inProgressWrapped) {
        inProgressCursor = null;
        inProgressWrapped = true;
        continue;
      }
      if (!inProgressPage.rows.length) {
        inProgressCursor = null;
        break;
      }
      for (const row of inProgressPage.rows) {
        summary.scanned++;
        inProgressProcessed++;
        await processInProgress(row);
      }
      if (!inProgressPage.hasMore || !inProgressPage.cursor) {
        inProgressCursor = null;
        break;
      }
      inProgressCursor = inProgressPage.cursor;
    }
    nextState.inProgressCursorBillingPeriod = inProgressCursor?.billingPeriod ?? null;
    nextState.inProgressCursorScheduleId = inProgressCursor?.scheduleId ?? null;
  } catch (error) {
    addError(summary, null, null, error, logger);
    nextState.inProgressCursorBillingPeriod = null;
    nextState.inProgressCursorScheduleId = null;
  }

  let activeCursor = typeof job.activeCursorScheduleId === 'string' ? job.activeCursorScheduleId : null;
  let activeProcessed = 0;
  let activePages = 0;
  let wrapped = false;
  while (activeProcessed < maxActiveSchedules && activePages < Math.ceil(maxActiveSchedules / pageSize) + 2) {
    let page;
    try {
      page = await listPage({db, phase: 'active', cursor: activeCursor,
        limit: Math.min(pageSize, maxActiveSchedules - activeProcessed)});
      if (!page.rows.length && activeCursor && !wrapped) {
        activeCursor = null;
        wrapped = true;
        activePages++;
        continue;
      }
      if (!page.rows.length) {
        activeCursor = null;
        break;
      }
      activePages++;
      for (const row of page.rows) {
        summary.scanned++;
        activeProcessed++;
        activeCursor = row.id;
        let period;
        try {
          const schedule = validateScheduleRow(row);
          if (schedule.status !== 'active' || schedule.generationInProgressBillingPeriod != null) continue;
          const {community} = await requireAuthority(db, null, schedule.communityId);
          const local = localCalendarKeys(nowMs, community.timeZone);
          const eligibility = classifyActivePeriod(schedule, local);
          period = eligibility.billingPeriod;
          if (eligibility.result === 'notDue') summary.notDue++;
          else if (eligibility.result === 'missedPeriod') summary.missedPeriod++;
          else if (eligibility.result === 'beforeWindow') summary.beforeWindow++;
          else if (eligibility.result === 'missedWindow') summary.missedWindow++;
          else {
            await reserveCore({
              db, auth: null,
              data: {communityId: schedule.communityId, scheduleId: row.id,
                billingPeriod: eligibility.billingPeriod},
              requireAuthority,
              now: () => nowMs,
            });
            summary.reserved++;
            const result = await executeCore({
              db, auth: null,
              data: {communityId: schedule.communityId, scheduleId: row.id,
                billingPeriod: eligibility.billingPeriod},
              requireAuthority,
              now: () => nowMs,
            });
            countExecution(summary, result);
          }
        } catch (error) {
          addError(summary, row, period, error, logger);
        }
      }
      if (!page.hasMore) {
        activeCursor = null;
        break;
      }
    } catch (error) {
      addError(summary, null, null, error, logger);
      activeCursor = null;
      break;
    }
  }
  nextState.activeCursorScheduleId = activeCursor;
  await persistJobState(db, nextState, summary, nowMs);
  return summary;
}

module.exports = {
  JOB_PATH,
  MAX_IN_PROGRESS_PER_RUN,
  MAX_ACTIVE_PER_RUN,
  QUERY_PAGE_SIZE,
  localCalendarKeys,
  classifyActivePeriod,
  firestoreSchedulePage,
  runRecurringBillingV2SchedulerCore,
};
