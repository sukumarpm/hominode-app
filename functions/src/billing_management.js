const {
    FieldValue,
    Timestamp,
} = require("firebase-admin/firestore");

const {
    RegistrationError,
} = require("./register_resident");

const {
    requireOperationalAdmin,
} = require("./resident_identity");

const BILL_SCOPES = new Set([
    "community",
    "building",
    "unit",
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
    const month = clean(data.month);
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
    };
}

async function validateScope(db, input) {
    if (input.scope === "community") {
        return;
    }

    const buildingRef = db
        .collection("buildings")
        .doc(input.buildingId);

    const buildingSnapshot = await buildingRef.get();

    if (
        !buildingSnapshot.exists ||
        buildingSnapshot.data()?.communityId !==
        input.communityId
    ) {
        throw new RegistrationError(
            "permission-denied",
            "Building is outside the authorized community.",
        );
    }

    if (input.scope !== "unit") {
        return;
    }

    const flatSnapshot = await db
        .collection("flats")
        .doc(input.flatId)
        .get();

    const flat = flatSnapshot.data();

    if (
        !flatSnapshot.exists ||
        flat?.communityId !== input.communityId ||
        flat?.buildingId !== input.buildingId
    ) {
        throw new RegistrationError(
            "permission-denied",
            "Unit is outside the selected building or community.",
        );
    }
}

async function createMaintenanceBillsCore({
    db,
    auth,
    data,
}) {
    const input = validateRequest(data);

    const actor = await requireOperationalAdmin(
        db,
        auth,
        input.communityId,
    );

    await validateScope(db, input);

    const [
        residentSnapshot,
        flatSnapshot,
        adminSnapshot,
    ] = await Promise.all([
        db
            .collection("users")
            .where("communityId", "==", input.communityId)
            .where("role", "==", "resident")
            .get(),

        db
            .collection("flats")
            .where("communityId", "==", input.communityId)
            .get(),

        db
            .collection("admins")
            .doc(actor.uid)
            .get(),
    ]);

    const flats = new Map(
        flatSnapshot.docs.map((doc) => [
            doc.id,
            doc.data(),
        ]),
    );

    const residents = residentSnapshot.docs.filter((doc) => {
        const resident = doc.data();
        const flatId = clean(resident.flatId);

        if (!flatId) {
            return false;
        }

        if (
            input.scope === "building" &&
            clean(resident.buildingId) !== input.buildingId
        ) {
            return false;
        }

        if (
            input.scope === "unit" &&
            flatId !== input.flatId
        ) {
            return false;
        }

        return true;
    });

    if (!residents.length) {
        throw new RegistrationError(
            "failed-precondition",
            "No assigned residents were found for the selected billing scope.",
        );
    }

    const admin = adminSnapshot.data() || {};
    const community = actor.community;

    let created = 0;
    let skipped = 0;
    let batch = db.batch();
    let batchWrites = 0;

    async function commitBatch() {
        if (!batchWrites) {
            return;
        }

        await batch.commit();
        batch = db.batch();
        batchWrites = 0;
    }

    for (const residentDoc of residents) {
        const resident = residentDoc.data();

        const flatId = clean(resident.flatId);
        const residentId =
            clean(resident.residentId) ||
            clean(resident.uid) ||
            residentDoc.id;

        const residentName = clean(resident.name);

        const flat = flats.get(flatId) || {};

        const flatLabel =
            clean(resident.flatLabel) ||
            clean(flat.flatLabel) ||
            clean(flat.unitLabel) ||
            clean(flat.flatNumber) ||
            clean(flat.unitId) ||
            flatId;

        if (
            !flatId ||
            !residentId ||
            !residentName ||
            !flatLabel
        ) {
            skipped += 1;
            continue;
        }

        const billRef = db.collection("bills").doc();

        batch.set(billRef, {
            adminId: actor.uid,

            communityId: input.communityId,

            adminName: clean(admin.name),
            adminEmail: clean(admin.email),
            adminPhone:
                clean(admin.phone) ||
                clean(admin.phoneNumber),

            organization:
                clean(admin.organization) ||
                clean(community.name),

            flatId,
            flatLabel,

            residentId,
            residentName,

            amount: input.amount,
            chargeBreakdown: input.chargeBreakdown,

            month: input.month,
            year: input.year,

            type: "combined",
            status: "pending",

            dueDate: Timestamp.fromDate(input.dueDate),
            paidAt: null,

            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
        });

        created += 1;
        batchWrites += 1;

        // Leave room below Firestore's 500-write batch limit.
        if (batchWrites >= 400) {
            await commitBatch();
        }
    }

    await commitBatch();

    if (!created) {
        throw new RegistrationError(
            "failed-precondition",
            "No valid resident bill records could be created.",
        );
    }

    return {
        success: true,
        scope: input.scope,
        created,
        skipped,
    };
}

module.exports = {
    createMaintenanceBillsCore,
};