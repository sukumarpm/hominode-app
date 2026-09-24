const {
    FieldValue,
    Timestamp,
} = require("firebase-admin/firestore");

const {
    RegistrationError,
} = require("./register_resident");

const {
    requireOperationalAdmin,
    resolveFlatOccupant,
} = require("./resident_identity");

const BILL_SCOPES = new Set([
    "community",
    "building",
    "unit",
    "units",
]);

function clean(value) {
    return typeof value === "string" ? value.trim() : "";
}

function validateMoney(value) {
    const amount = Number(value);

    if (
        !Number.isFinite(amount) ||
        amount <= 0 ||
        amount > 100000000
    ) {
        throw new RegistrationError(
            "invalid-argument",
            "Enter a valid bill amount.",
        );
    }

    return Number(amount.toFixed(2));
}

function validateDueDate(value) {
    const text = clean(value);
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);

    if (!match) {
        throw new RegistrationError(
            "invalid-argument",
            "A valid due date is required.",
        );
    }

    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);

    const date = new Date(Date.UTC(year, month - 1, day));

    if (
        date.getUTCFullYear() !== year ||
        date.getUTCMonth() !== month - 1 ||
        date.getUTCDate() !== day
    ) {
        throw new RegistrationError(
            "invalid-argument",
            "A valid due date is required.",
        );
    }

    return date;
}

function validateChargeBreakdown(raw, totalAmount) {
    if (raw == null) {
        return {
            Maintenance: totalAmount,
        };
    }

    if (
        typeof raw !== "object" ||
        Array.isArray(raw)
    ) {
        throw new RegistrationError(
            "invalid-argument",
            "Bill charge details are invalid.",
        );
    }

    const entries = Object.entries(raw);

    if (!entries.length || entries.length > 20) {
        throw new RegistrationError(
            "invalid-argument",
            "At least one valid bill charge is required.",
        );
    }

    const result = {};
    let calculatedTotal = 0;

    for (const [rawName, rawAmount] of entries) {
        const name = clean(rawName);

        if (!name || name.length > 80) {
            throw new RegistrationError(
                "invalid-argument",
                "Bill charge name is invalid.",
            );
        }

        const amount = Number(rawAmount);

        if (
            !Number.isFinite(amount) ||
            amount < 0 ||
            amount > 100000000
        ) {
            throw new RegistrationError(
                "invalid-argument",
                `Invalid amount for ${name}.`,
            );
        }

        const normalized = Number(amount.toFixed(2));

        result[name] = normalized;
        calculatedTotal += normalized;
    }

    calculatedTotal = Number(calculatedTotal.toFixed(2));

    if (Math.abs(calculatedTotal - totalAmount) > 0.01) {
        throw new RegistrationError(
            "invalid-argument",
            "Bill total does not match the charge breakdown.",
        );
    }

    return result;
}

function validateRequest(data) {
    const allowed = new Set([
        "communityId",
        "scope",
        "buildingId",
        "flatId",
        "amount",
        "chargeBreakdown",
        "month",
        "year",
        "dueDate",
        "chargeType",
        "flatIds",
    ]);

    if (
        !data ||
        typeof data !== "object" ||
        Array.isArray(data) ||
        Object.keys(data).some((key) => !allowed.has(key))
    ) {
        throw new RegistrationError(
            "invalid-argument",
            "A valid bill request is required.",
        );
    }

    const communityId = clean(data.communityId);
    const scope = clean(data.scope).toLowerCase();
    const buildingId = clean(data.buildingId);
    const flatId = clean(data.flatId);
    const month = normalizeMonth(data.month);
    const year = clean(data.year);

    if (!communityId) {
        throw new RegistrationError(
            "invalid-argument",
            "Community is required.",
        );
    }

    if (!BILL_SCOPES.has(scope)) {
        throw new RegistrationError(
            "invalid-argument",
            "Select Community, Building, or Unit.",
        );
    }

    if (scope === "building" && !buildingId) {
        throw new RegistrationError(
            "invalid-argument",
            "Select a building.",
        );
    }

    if (
        scope === "unit" &&
        (!buildingId || !flatId)
    ) {
        throw new RegistrationError(
            "invalid-argument",
            "Select a building and unit.",
        );
    }

    if (
        !month ||
        month.length > 20 ||
        !/^\d{4}$/.test(year)
    ) {
        throw new RegistrationError(
            "invalid-argument",
            "A valid billing period is required.",
        );
    }

    const numericYear = Number(year);

    if (numericYear < 2000 || numericYear > 2100) {
        throw new RegistrationError(
            "invalid-argument",
            "Billing year is invalid.",
        );
    }

    const amount = validateMoney(data.amount);
    const chargeBreakdown = validateChargeBreakdown(
        data.chargeBreakdown,
        amount,
    );

    return {
        communityId,
        scope,
        buildingId,
        flatId,
        amount,
        chargeBreakdown,
        month,
        year,
        dueDate: validateDueDate(data.dueDate),
        chargeType: normalizeChargeType(data.chargeType),
        flatIds: validateFlatIds(data.flatIds, scope),
        billingPeriod: `${year}-${String(MONTHS.indexOf(month) + 1).padStart(2, "0")}`,
    };
}

const {createHash} = require('node:crypto');
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
function normalizeMonth(value) {
    const text = String(value ?? '').trim().toLowerCase();
    const index = MONTHS.findIndex((month, i) => [month.toLowerCase(), month.slice(0, 3).toLowerCase(), String(i + 1), String(i + 1).padStart(2, '0')].includes(text));
    if (index < 0) throw new RegistrationError('invalid-argument', 'A recognized billing month is required.');
    return MONTHS[index];
}
function normalizeChargeType(value) {
    const type = value == null ? 'maintenance' : clean(value).toLowerCase();
    if (!/^[a-z][a-z0-9_-]{0,39}$/.test(type)) throw new RegistrationError('invalid-argument', 'A valid recurring charge type is required.');
    return type;
}
function validId(value) {
    return typeof value === 'string' && value.length > 0 && value.length <= 128 && value === value.trim() && !value.includes('/');
}
function validateFlatIds(value, scope) {
    if (scope !== 'units') {
        if (value != null) throw new RegistrationError('invalid-argument', 'Unit selection requires units scope.');
        return [];
    }
    if (!Array.isArray(value) || !value.length || value.length > 2000 || value.some(id => !validId(id))) {
        throw new RegistrationError('invalid-argument', 'Select valid units.');
    }
    return [...new Set(value)].sort();
}
function recurringBillId(communityId, flatId, chargeType, billingPeriod) {
    return 'recurring_' + createHash('sha256').update(JSON.stringify([communityId, flatId, chargeType, billingPeriod])).digest('hex');
}
function sameTerms(bill, input) {
    const sorted = object => JSON.stringify(Object.entries(object || {}).sort(([a], [b]) => a.localeCompare(b)));
    return bill.amount === input.amount && bill.dueDate?.toMillis() === input.dueDate.getTime()
        && sorted(bill.chargeBreakdown) === sorted(input.chargeBreakdown);
}
function matchesLegacyContract(bill, input) {
    if (bill.billingKind === 'ad_hoc') return false;
    try {
        const period = bill.billingPeriod || `${String(bill.year)}-${String(MONTHS.indexOf(normalizeMonth(bill.month)) + 1).padStart(2, '0')}`;
        const type = bill.chargeType || (['combined', 'maintenance'].includes(clean(bill.type).toLowerCase()) ? 'maintenance' : clean(bill.type).toLowerCase());
        return period === input.billingPeriod && type === input.chargeType;
    } catch (_) { return false; }
}
async function createMaintenanceBillsCore({db, auth, data}) {
    const input = validateRequest(data);
    if (!validId(input.communityId) || (input.buildingId && !validId(input.buildingId)) || (input.flatId && !validId(input.flatId))) {
        throw new RegistrationError('invalid-argument', 'Invalid billing scope identifier.');
    }
    await requireOperationalAdmin(db, auth, input.communityId);
    if (['building', 'unit'].includes(input.scope)) {
        const building = await db.collection('buildings').doc(input.buildingId).get();
        if (!building.exists || building.data().communityId !== input.communityId) {
            throw new RegistrationError('permission-denied', 'Building is outside the authorized community.');
        }
    }
    let targets;
    if (['unit', 'units'].includes(input.scope)) {
        targets = await Promise.all((input.scope === 'unit' ? [input.flatId] : input.flatIds).map(id => db.collection('flats').doc(id).get()));
        if (targets.some(doc => !doc.exists || doc.data().communityId !== input.communityId ||
            (input.scope === 'unit' && doc.data().buildingId !== input.buildingId))) {
            throw new RegistrationError('permission-denied', 'A selected unit is outside the authorized scope.');
        }
    } else {
        const snapshot = await db.collection('flats').where('communityId', '==', input.communityId).get();
        targets = snapshot.docs.filter(doc => input.scope !== 'building' || doc.data().buildingId === input.buildingId);
    }
    const result = {success: true, scope: input.scope, created: 0, skipped: 0, existing: 0, conflicts: [], legacyMatches: [], createdBills: []};
    for (const target of targets.sort((a, b) => a.id.localeCompare(b.id))) {
        const id = recurringBillId(input.communityId, target.id, input.chargeType, input.billingPeriod);
        const billRef = db.collection('bills').doc(id);
        // Each target commits independently. A retry rediscovers targets and
        // skips committed identities; no batch progress flag can be lost.
        const outcome = await db.runTransaction(async transaction => {
            const actor = await requireOperationalAdmin(db, auth, input.communityId, transaction);
            const existing = await transaction.get(billRef);
            if (existing.exists) return {kind: sameTerms(existing.data(), input) ? 'existing' : 'conflict'};
            const flatSnapshot = await transaction.get(db.collection('flats').doc(target.id));
            const flat = flatSnapshot.data();
            if (!flatSnapshot.exists || flat.communityId !== input.communityId || flat.status !== 'occupied' ||
                !validId(flat.buildingId) || (['building', 'unit'].includes(input.scope) && flat.buildingId !== input.buildingId)) return {kind: 'skipped'};
            const building = await transaction.get(db.collection('buildings').doc(flat.buildingId));
            if (!building.exists || building.data().communityId !== input.communityId) return {kind: 'skipped'};
            let residentId;
            try { residentId = resolveFlatOccupant(flat).uid; } catch (_) { return {kind: 'skipped'}; }
            if (!validId(residentId)) return {kind: 'skipped'};
            const resident = (await transaction.get(db.collection('users').doc(residentId))).data();
            if (!resident || resident.uid !== residentId || resident.role !== 'resident' || resident.isActive !== true ||
                resident.approvalStatus !== 'approved' || (resident.status != null && resident.status !== 'active') ||
                resident.communityId !== input.communityId || resident.flatId !== target.id || resident.buildingId !== flat.buildingId) return {kind: 'skipped'};
            // Existing random-ID bills have no reliable migration marker. Match
            // their old period/type conservatively and report for reconciliation.
            const history = await transaction.get(db.collection('bills').where('flatId', '==', target.id));
            const legacy = history.docs.filter(doc => doc.data().communityId === input.communityId && matchesLegacyContract(doc.data(), input));
            if (legacy.length) return {kind: 'legacy', billIds: legacy.map(doc => doc.id)};
            const admin = (await transaction.get(db.collection('admins').doc(actor.uid))).data();
            const residentName = clean(resident.name) || clean(resident.fullName) || residentId;
            transaction.create(billRef, {
                billingKind: 'recurring', billingPeriod: input.billingPeriod, chargeType: input.chargeType,
                adminId: actor.uid, communityId: input.communityId,
                adminName: clean(admin.name), adminEmail: clean(admin.email), adminPhone: clean(admin.phone) || clean(admin.phoneNumber),
                organization: clean(admin.organization) || clean(actor.community.name),
                buildingId: flat.buildingId, flatId: target.id,
                flatLabel: clean(flat.flatLabel) || clean(flat.unitLabel) || clean(flat.flatNumber) || target.id,
                residentId, residentName, amount: input.amount, chargeBreakdown: input.chargeBreakdown,
                month: input.month, year: input.year, type: 'combined', status: 'pending',
                dueDate: Timestamp.fromDate(input.dueDate), paidAt: null,
                createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
            });
            return {kind: 'created', bill: {billId: id, residentId, amount: input.amount, month: input.month, year: input.year}};
        });
        if (outcome.kind === 'created') { result.created++; result.createdBills.push(outcome.bill); }
        else if (outcome.kind === 'existing') result.existing++;
        else if (outcome.kind === 'conflict') result.conflicts.push(target.id);
        else if (outcome.kind === 'legacy') { result.existing++; result.legacyMatches.push({flatId: target.id, billIds: outcome.billIds}); }
        else result.skipped++;
    }
    return result;
}
module.exports = {createMaintenanceBillsCore, recurringBillId};
