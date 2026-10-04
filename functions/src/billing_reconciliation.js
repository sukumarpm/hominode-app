const { createHash } = require('node:crypto');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { RegistrationError } = require('./register_resident');
const { requireOperationalAdmin } = require('./resident_identity');
const { AUDIT_ACTIONS, AUDIT_COLLECTION, buildAuditLog } = require('./audit_log');

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
const SUPPORTED_STATUS = 'reconciliation_required';
const SUPPORTED_REASON = 'existing_liability_requires_reconciliation';
const SUPPORTED_RESOLUTION = 'existing_liability_confirmed';
const clean = value => typeof value === 'string' ? value.trim() : '';
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const fail = (message, code = 'invalid-argument') => { throw new RegistrationError(code, message); };
const validId = value => typeof value === 'string' && value.length > 0 &&
    Buffer.byteLength(value, 'utf8') <= 128 && value === value.trim() &&
    !/[\/\u0000-\u001f\u007f]/.test(value) && !['.', '..'].includes(value) && !/^__.*__$/.test(value);

function normalizeLegacyBillingPeriod(bill) {
    if (typeof bill?.billingPeriod === 'string' && /^(20\d{2}|2100)-(0[1-9]|1[0-2])$/.test(bill.billingPeriod)) {
        return bill.billingPeriod;
    }
    const month = String(bill?.month ?? '').trim().toLowerCase();
    const index = MONTHS.findIndex((name, i) => [
        name.toLowerCase(), name.slice(0, 3).toLowerCase(), String(i + 1), String(i + 1).padStart(2, '0'),
    ].includes(month));
    return index < 0 || !/^\d{4}$/.test(String(bill?.year)) ? null : `${bill.year}-${String(index + 1).padStart(2, '0')}`;
}

function validateRequest(data) {
    const allowed = ['communityId', 'batchId', 'flatId', 'expectedConflictingBillIds', 'resolutionType', 'note'];
    if (!data || typeof data !== 'object' || Array.isArray(data) ||
        Object.keys(data).some(key => !allowed.includes(key))) {
        fail('Invalid billing reconciliation resolution request.');
    }
    if (!validId(data.communityId) || !validId(data.batchId) || !validId(data.flatId)) {
        fail('Community, batch, and unit are required.');
    }
    if (data.resolutionType !== SUPPORTED_RESOLUTION) {
        fail('Unsupported reconciliation resolution type.');
    }
    if (!Array.isArray(data.expectedConflictingBillIds) || data.expectedConflictingBillIds.length === 0 ||
        data.expectedConflictingBillIds.some(id => !validId(id))) {
        fail('A non-empty list of conflicting bill IDs is required.');
    }
    const expectedConflictingBillIds = [...new Set(data.expectedConflictingBillIds)].sort();
    if (expectedConflictingBillIds.length !== data.expectedConflictingBillIds.length) {
        fail('Conflicting bill IDs must be unique.');
    }
    const note = clean(data.note);
    if (data.note != null && (typeof data.note !== 'string' || note.length > 500)) {
        fail('Resolution note must contain 500 characters or fewer.');
    }
    return {
        communityId: data.communityId,
        batchId: data.batchId,
        flatId: data.flatId,
        expectedConflictingBillIds,
        resolutionType: SUPPORTED_RESOLUTION,
        note: note || null,
    };
}

function generationStatus(generation) {
    const remaining = generation.targetCount - generation.completed - generation.skipped - generation.reconciliationRequired;
    if (remaining > 0) return generation.failed ? 'unresolved' : 'generating';
    return generation.reconciliationRequired ? 'reconciliation_required' : 'completed';
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

function assertCounterShape(generation) {
    const keys = ['targetCount', 'materializedCount', 'completed', 'skipped', 'reconciliationRequired', 'failed'];
    if (!generation || keys.some(key => !Number.isSafeInteger(generation[key]) || generation[key] < 0)) {
        fail('The billing batch progress is invalid.', 'failed-precondition');
    }
}

function resolutionId(batchId, flatId, resolutionType, conflictingBillIds) {
    return `reconciliation_resolution_v2_${hash([batchId, flatId, resolutionType, conflictingBillIds])}`;
}

function auditId(reconciliationResolutionId) {
    return `billing_reconciliation_resolve_v2_${reconciliationResolutionId}`;
}

function sameIdSet(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function assertValidCountersForResolution(generation) {
    assertCounterShape(generation);
    const unresolved = generation.targetCount - generation.completed - generation.skipped - generation.reconciliationRequired;
    if (generation.materializedCount > generation.targetCount ||
        generation.completed + generation.skipped + generation.reconciliationRequired > generation.targetCount ||
        generation.completed + generation.skipped + generation.reconciliationRequired + generation.failed > generation.materializedCount ||
        generation.failed > unresolved ||
        generation.reconciliationRequired < 1) {
        fail('Billing batch reconciliation counters are inconsistent.', 'failed-precondition');
    }
}

function resolveScheduleLinkage(batch) {
    const hasScheduleId = batch?.scheduleId != null;
    const hasRevisionId = batch?.scheduleRevisionId != null;
    if (!hasScheduleId && !hasRevisionId) {
        return { isLinked: false, scheduleId: null, scheduleRevisionId: null };
    }
    if (hasScheduleId !== hasRevisionId) {
        fail('Billing batch schedule linkage is malformed.', 'failed-precondition');
    }
    if (!validId(batch.scheduleId) || !validId(batch.scheduleRevisionId)) {
        fail('Billing batch schedule linkage is malformed.', 'failed-precondition');
    }
    return { isLinked: true, scheduleId: batch.scheduleId, scheduleRevisionId: batch.scheduleRevisionId };
}

function assertLinkedGenerationMatchesBatch(generation, batch, input, scheduleLinkage) {
    if (!generation || generation.schemaVersion !== 2 || generation.communityId !== input.communityId ||
        generation.scheduleId !== scheduleLinkage.scheduleId ||
        generation.scheduleRevisionId !== scheduleLinkage.scheduleRevisionId ||
        generation.billingPeriod !== batch.billingPeriod ||
        generation.batchId !== input.batchId) {
        fail('Schedule generation linkage is inconsistent.', 'failed-precondition');
    }
}

function assertRetryGenerationCoherence(generation, batch) {
    if (generation.status !== batch.status ||
        JSON.stringify(generation.terminalCounters || null) !== JSON.stringify(batch.generation || null) ||
        generation.reconciliationRequiredCount !== batch.generation.reconciliationRequired) {
        fail('Schedule generation state is inconsistent with batch progress.', 'failed-precondition');
    }
}

async function resolveBillingReconciliationV2Core({ db, auth, data, now = Date.now,
    requireAuthority = requireOperationalAdmin }) {
    const input = validateRequest(data);
    const nowMs = now();
    if (!Number.isSafeInteger(nowMs)) {
        fail('The current time is invalid.', 'failed-precondition');
    }
    const resolvedAt = Timestamp.fromMillis(nowMs);

    const batchRef = db.collection('billingBatches').doc(input.batchId);
    const targetRef = db.collection(`billingBatches/${input.batchId}/targets`).doc(input.flatId);

    const state = await db.runTransaction(async transaction => {
        const actor = await requireAuthority(db, auth, input.communityId, transaction);
        const [batchSnapshot, targetSnapshot] = await Promise.all([
            transaction.get(batchRef), transaction.get(targetRef),
        ]);
        if (!batchSnapshot.exists) fail('Billing batch was not found.', 'not-found');
        if (!targetSnapshot.exists) fail('Billing target was not found.', 'not-found');

        const batch = batchSnapshot.data();
        const target = targetSnapshot.data();
        if (!batch || batch.schemaVersion !== 2 || batch.communityId !== input.communityId) {
            fail('Billing batch is outside the authorized community.', 'permission-denied');
        }
        if (!target || target.schemaVersion !== 2 || target.communityId !== input.communityId || target.flatId !== input.flatId) {
            fail('Billing target is outside the authorized community.', 'permission-denied');
        }
        const scheduleLinkage = resolveScheduleLinkage(batch);
        if (target.status !== SUPPORTED_STATUS && target.status !== 'skipped') {
            fail('Billing target is not in a supported reconciliation state.', 'failed-precondition');
        }

        const targetConflicts = Array.isArray(target.billIds) ? [...target.billIds] : null;
        if (!targetConflicts || targetConflicts.length === 0 || targetConflicts.some(id => !validId(id))) {
            fail('Billing target conflicts are invalid.', 'failed-precondition');
        }
        const storedConflictingBillIds = [...new Set(targetConflicts)].sort();
        if (storedConflictingBillIds.length !== targetConflicts.length) {
            fail('Billing target conflicts contain duplicates.', 'failed-precondition');
        }
        if (!sameIdSet(storedConflictingBillIds, input.expectedConflictingBillIds)) {
            fail('Conflicting bill IDs changed. Refresh and retry.', 'failed-precondition');
        }

        const recordId = resolutionId(input.batchId, input.flatId, input.resolutionType, storedConflictingBillIds);
        const resolutionRef = db.collection(`billingBatches/${input.batchId}/reconciliations`).doc(recordId);
        const auditRef = db.collection(AUDIT_COLLECTION).doc(auditId(recordId));

        if (target.status === 'skipped') {
            const resolution = target.reconciliationResolution;
            if (!resolution || resolution.resolutionId !== recordId || resolution.resolutionType !== input.resolutionType) {
                fail('Billing target was skipped without a matching reconciliation resolution.', 'failed-precondition');
            }
            const [existingResolution, existingAudit] = await Promise.all([
                transaction.get(resolutionRef),
                transaction.get(auditRef),
            ]);
            if (!existingResolution.exists || !existingAudit.exists) {
                fail('Reconciliation resolution record is missing.', 'failed-precondition');
            }
            const resolutionRecord = existingResolution.data();
            if (!resolutionRecord || resolutionRecord.schemaVersion !== 2 ||
                resolutionRecord.communityId !== input.communityId ||
                resolutionRecord.batchId !== input.batchId ||
                resolutionRecord.flatId !== input.flatId ||
                resolutionRecord.resolutionType !== input.resolutionType ||
                !sameIdSet([...(resolutionRecord.conflictingBillIds || [])].sort(), storedConflictingBillIds)) {
                fail('Reconciliation resolution record does not match the resolved target.', 'failed-precondition');
            }
            const auditRecord = existingAudit.data();
            if (!auditRecord ||
                auditRecord.action !== AUDIT_ACTIONS.billingReconciliationResolve ||
                auditRecord.communityId !== input.communityId ||
                auditRecord.targetType !== 'billing_batch_target' ||
                auditRecord.targetId !== `${input.batchId}:${input.flatId}` ||
                auditRecord.actorUid !== resolution.resolvedBy ||
                auditRecord?.metadata?.resolutionId !== recordId ||
                auditRecord?.metadata?.resolutionType !== input.resolutionType ||
                !sameIdSet([...(auditRecord?.metadata?.conflictingBillIds || [])].sort(), storedConflictingBillIds)) {
                fail('Reconciliation audit record does not match the resolved target.', 'failed-precondition');
            }
            if (scheduleLinkage.isLinked) {
                const generationRef = db.collection(`billingSchedules/${scheduleLinkage.scheduleId}/generations`).doc(batch.billingPeriod);
                const generationSnapshot = await transaction.get(generationRef);
                if (!generationSnapshot.exists) {
                    fail('Schedule generation record is missing for this reconciliation batch.', 'failed-precondition');
                }
                const generation = generationSnapshot.data();
                assertLinkedGenerationMatchesBatch(generation, batch, input, scheduleLinkage);
                assertRetryGenerationCoherence(generation, batch);
            }
            return {
                alreadyCompleted: true,
                actorUid: actor.uid,
                batchId: input.batchId,
                flatId: input.flatId,
                billingPeriod: batch.billingPeriod,
                conflictingBillIds: storedConflictingBillIds,
                resolutionType: input.resolutionType,
                resolutionId: recordId,
                status: batch.status,
            };
        }

        if (target.reason !== SUPPORTED_REASON) {
            fail('Unsupported reconciliation reason for this resolver.', 'failed-precondition');
        }
        assertValidCountersForResolution(batch.generation);
        if (batch.status !== 'reconciliation_required' || generationStatus(batch.generation) !== 'reconciliation_required') {
            fail('Billing batch is not in a resolvable reconciliation state.', 'failed-precondition');
        }

        const intendedBillId = target.billId;
        if (!validId(intendedBillId)) {
            fail('Billing target identity is invalid.', 'failed-precondition');
        }
        const billRef = db.collection('bills').doc(intendedBillId);
        const assignmentRef = db.collection('billingAssignments').doc(intendedBillId);
        const conflictRefs = storedConflictingBillIds.map(id => db.collection('bills').doc(id));
        const generationRef = scheduleLinkage.isLinked
            ? db.collection(`billingSchedules/${scheduleLinkage.scheduleId}/generations`).doc(batch.billingPeriod)
            : null;

        const readTargets = [
            transaction.get(billRef),
            transaction.get(assignmentRef),
            transaction.get(resolutionRef),
            transaction.get(auditRef),
            ...conflictRefs.map(ref => transaction.get(ref)),
        ];
        if (generationRef) readTargets.push(transaction.get(generationRef));
        const snapshots = await Promise.all(readTargets);
        const existingV2Bill = snapshots[0];
        const existingAssignment = snapshots[1];
        const existingResolution = snapshots[2];
        const existingAudit = snapshots[3];
        const conflictSnapshots = snapshots.slice(4, 4 + conflictRefs.length);
        const generationSnapshot = generationRef ? snapshots[snapshots.length - 1] : null;

        if (existingV2Bill.exists || existingAssignment.exists) {
            fail('The target already has a V2 liability assignment.', 'failed-precondition');
        }
        if (existingResolution.exists || existingAudit.exists) {
            fail('A reconciliation resolution record already exists for this target.', 'failed-precondition');
        }

        for (const snapshot of conflictSnapshots) {
            if (!snapshot.exists) {
                fail('A conflicting legacy bill is missing.', 'failed-precondition');
            }
            const bill = snapshot.data();
            if (bill.communityId !== input.communityId || bill.flatId !== input.flatId) {
                fail('A conflicting bill is outside the authorized community or unit.', 'failed-precondition');
            }
            if (bill.billingKind === 'ad_hoc') {
                fail('Ad-hoc bills are not supported by this reconciliation resolver.', 'failed-precondition');
            }
            if (normalizeLegacyBillingPeriod(bill) !== batch.billingPeriod) {
                fail('A conflicting legacy bill is outside the target billing period.', 'failed-precondition');
            }
        }

        if (generationRef) {
            if (!generationSnapshot.exists) {
                fail('Schedule generation record is missing for this reconciliation batch.', 'failed-precondition');
            }
            const generation = generationSnapshot.data();
            assertLinkedGenerationMatchesBatch(generation, batch, input, scheduleLinkage);
            if (generation.status !== 'reconciliation_required' && generation.status !== 'completed') {
                fail('Schedule generation is not in a reconciliation terminal state.', 'failed-precondition');
            }
        }

        transaction.create(resolutionRef, {
            schemaVersion: 2,
            communityId: input.communityId,
            batchId: input.batchId,
            flatId: input.flatId,
            billingPeriod: batch.billingPeriod,
            resolutionType: input.resolutionType,
            conflictingBillIds: storedConflictingBillIds,
            resolvedBy: actor.uid,
            resolvedAt,
            note: input.note,
        });

        transaction.create(auditRef, buildAuditLog({
            actorUid: actor.uid,
            actorRole: 'admin',
            communityId: input.communityId,
            action: AUDIT_ACTIONS.billingReconciliationResolve,
            targetType: 'billing_batch_target',
            targetId: `${input.batchId}:${input.flatId}`,
            summary: 'Billing reconciliation target resolved without creating a V2 liability.',
            metadata: {
                batchId: input.batchId,
                flatId: input.flatId,
                billingPeriod: batch.billingPeriod,
                resolutionType: input.resolutionType,
                resolutionId: recordId,
                conflictingBillIds: storedConflictingBillIds,
            },
        }));

        const updatedGeneration = {
            ...batch.generation,
            reconciliationRequired: batch.generation.reconciliationRequired - 1,
            skipped: batch.generation.skipped + 1,
        };
        const updatedBatchStatus = generationStatus(updatedGeneration);

        transaction.update(targetRef, {
            status: 'skipped',
            attempts: (target.attempts || 0) + 1,
            conflictStatus: SUPPORTED_STATUS,
            conflictReason: target.reason,
            conflictingBillIds: storedConflictingBillIds,
            reconciliationResolution: {
                resolutionId: recordId,
                resolutionType: input.resolutionType,
                resolvedBy: actor.uid,
                resolvedAt,
                note: input.note,
            },
            updatedBy: actor.uid,
            updatedAt: resolvedAt,
        });

        transaction.update(batchRef, {
            generation: updatedGeneration,
            status: updatedBatchStatus,
            updatedBy: actor.uid,
            updatedAt: resolvedAt,
        });

        if (generationRef) {
            transaction.update(generationRef, {
                status: updatedBatchStatus,
                latestBatchProgress: batchProgress({ status: updatedBatchStatus, generation: updatedGeneration }),
                terminalCounters: updatedGeneration,
                reconciliationRequiredCount: updatedGeneration.reconciliationRequired,
                reconciliationResolutionId: recordId,
                reconciliationResolvedAt: resolvedAt,
                updatedBy: actor.uid,
                updatedAt: resolvedAt,
            });
        }

        return {
            alreadyCompleted: false,
            actorUid: actor.uid,
            batchId: input.batchId,
            flatId: input.flatId,
            billingPeriod: batch.billingPeriod,
            conflictingBillIds: storedConflictingBillIds,
            resolutionType: input.resolutionType,
            resolutionId: recordId,
            status: updatedBatchStatus,
        };
    });

    return {
        success: true,
        batchId: state.batchId,
        flatId: state.flatId,
        billingPeriod: state.billingPeriod,
        resolutionType: state.resolutionType,
        conflictingBillIds: state.conflictingBillIds,
        status: state.status,
        alreadyCompleted: state.alreadyCompleted,
    };
}

module.exports = {
    resolveBillingReconciliationV2Core,
    normalizeLegacyBillingPeriod,
    resolutionId,
};