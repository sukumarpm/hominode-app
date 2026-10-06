#!/usr/bin/env node

const admin = require("firebase-admin");

const {
  createMonthlyBillingBatchV2Core,
  monthlyBillIdV2,
  monthlyBillingBatchId,
} = require("../src/billing_batch");

const PROJECT_ID = "hominode-prod";
const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";

const SEED_ADMIN_UID = "demo-admin-green-wave";
const SEED_ADMIN_PHONE = "+919000000001";

const PERIODS = [
  "2026-05",
  "2026-06",
  "2026-07",
  "2026-08",
  "2026-09",
  "2026-10",
];

const AMOUNT_MINOR = 350000; // ₹3,500.00

const CHARGE_LINES = [
  {
    lineId: "maintenance-base",
    code: "maintenance",
    amountMinor: 250000,
  },
  {
    lineId: "water-common",
    code: "water",
    amountMinor: 40000,
  },
  {
    lineId: "security-services",
    code: "security",
    amountMinor: 60000,
  },
];

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function pad2(value) {
  return String(value).padStart(2, "0");
}

function historicalNow(period) {
  const [year, month] =
    period.split("-").map(Number);

  // 1st of billing month, 09:00 IST.
  return (
    Date.UTC(
      year,
      month - 1,
      1,
      9,
      0
    ) -
    330 * 60 * 1000
  );
}

function dueDate(period) {
  return `${period}-10`;
}

function idempotencyKey(period) {
  return `green-wave-demo-billing-${period}-v1`;
}

function authContext() {
  return {
    uid: SEED_ADMIN_UID,
    token: {
      phone_number: SEED_ADMIN_PHONE,
      firebase: {
        sign_in_provider: "phone",
      },
    },
  };
}

async function requireEnvironment(db) {
  const community = await db
    .collection("communities")
    .doc(COMMUNITY_ID)
    .get();

  if (
    !community.exists ||
    community.data()?.isActive !== true ||
    community.data()?.isDemoData !== true ||
    community.data()?.seedBatch !== SEED_BATCH
  ) {
    throw new Error(
      "Green Wave demo community guard failed."
    );
  }

  const adminDoc = await db
    .collection("admins")
    .doc(SEED_ADMIN_UID)
    .get();

  const a = adminDoc.data() || {};

  if (
    !adminDoc.exists ||
    a.uid !== SEED_ADMIN_UID ||
    a.role !== "admin" ||
    a.isActive !== true ||
    !Array.isArray(a.authorizedCommunityIds) ||
    !a.authorizedCommunityIds.includes(
      COMMUNITY_ID
    )
  ) {
    throw new Error(
      "Green Wave seed admin guard failed."
    );
  }
}

async function loadScope(db) {
  const [users, flats] =
    await Promise.all([
      db
        .collection("users")
        .where(
          "communityId",
          "==",
          COMMUNITY_ID
        )
        .get(),

      db
        .collection("flats")
        .where(
          "communityId",
          "==",
          COMMUNITY_ID
        )
        .get(),
    ]);

  const residents =
    users.docs
      .map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }))
      .filter((r) =>
        r.role === "resident" &&
        r.approvalStatus === "approved" &&
        r.isActive === true &&
        r.status === "active" &&
        r.occupancyStatus === "current" &&
        r.isDemoData === true &&
        r.seedBatch === SEED_BATCH
      );

  if (flats.size !== 64) {
    throw new Error(
      `Expected 64 Green Wave units; found ${flats.size}.`
    );
  }

  if (residents.length !== 48) {
    throw new Error(
      `Expected 48 active residents; found ${residents.length}.`
    );
  }

  const flatIds =
    residents
      .map((r) => r.flatId)
      .filter(Boolean);

  if (
    new Set(flatIds).size !== 48
  ) {
    throw new Error(
      "Active resident flat assignments are not unique."
    );
  }

  return {
    residents,
    flatIds: [...flatIds].sort(),
    totalFlats: flats.size,
  };
}

function requestFor(period) {
  return {
    communityId: COMMUNITY_ID,
    billingPeriod: period,
    idempotencyKey:
      idempotencyKey(period),
    scope: "community",
    chargeLines: CHARGE_LINES,
    dueDate: dueDate(period),
  };
}

async function inspectExisting(
  db,
  flatIds
) {
  let existingBills = 0;
  let missingBills = 0;
  let existingBatches = 0;

  for (const period of PERIODS) {
    const batchId =
      monthlyBillingBatchId(
        COMMUNITY_ID,
        idempotencyKey(period)
      );

    const batch = await db
      .collection("billingBatches")
      .doc(batchId)
      .get();

    if (batch.exists) {
      existingBatches += 1;

      const data = batch.data();

      if (
        data.schemaVersion !== 2 ||
        data.communityId !== COMMUNITY_ID ||
        data.billingPeriod !== period ||
        data.idempotencyKey !==
          idempotencyKey(period) ||
        data.amountMinor !== AMOUNT_MINOR
      ) {
        throw new Error(
          `Conflicting V2 billing batch: ${batchId}`
        );
      }
    }

    for (const flatId of flatIds) {
      const billId =
        monthlyBillIdV2(
          COMMUNITY_ID,
          flatId,
          period
        );

      const bill = await db
        .collection("bills")
        .doc(billId)
        .get();

      if (!bill.exists) {
        missingBills += 1;
        continue;
      }

      existingBills += 1;

      const data = bill.data();

      if (
        data.schemaVersion !== 2 ||
        data.communityId !== COMMUNITY_ID ||
        data.flatId !== flatId ||
        data.billingPeriod !== period ||
        data.amountMinor !== AMOUNT_MINOR ||
        data.currency !== "INR" ||
        data.billingKind !== "recurring" ||
        ![
          "pending",
          "partially_paid",
          "paid",
          "overdue",
        ].includes(data.status)
      ) {
        throw new Error(
          `Conflicting V2 bill: ${billId}`
        );
      }
    }
  }

  return {
    existingBills,
    missingBills,
    existingBatches,
  };
}

async function applyPeriod(
  db,
  period
) {
  const data =
    requestFor(period);

  const nowMs =
    historicalNow(period);

  let result;

  do {
    result =
      await createMonthlyBillingBatchV2Core({
        db,
        auth: authContext(),
        data,
        now: () => nowMs,
      });

    console.log(
      `${period}: created=${result.created}, ` +
      `completed=${result.completed}, ` +
      `skipped=${result.skipped}, ` +
      `reconciliation=${result.reconciliationRequired}, ` +
      `failed=${result.failed}, ` +
      `remaining=${result.remaining}`
    );

    if (
      result.reconciliationRequired !== 0 ||
      result.failed !== 0
    ) {
      throw new Error(
        `Billing generation requires reconciliation for ${period}.`
      );
    }
  } while (result.resumeRequired);

  if (
    result.completed !== 48 ||
    result.skipped !== 16 ||
    result.remaining !== 0 ||
    result.status !== "completed"
  ) {
    throw new Error(
      `Unexpected final batch state for ${period}.`
    );
  }

  return result;
}

async function validateFinal(
  db,
  flatIds
) {
  const audit =
    await inspectExisting(
      db,
      flatIds
    );

  if (
    audit.existingBills !== 288 ||
    audit.missingBills !== 0 ||
    audit.existingBatches !== 6
  ) {
    throw new Error(
      "Final Billing V2 totals are incorrect."
    );
  }

  const snapshot = await db
    .collection("bills")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const expectedPeriods =
    Object.fromEntries(
      PERIODS.map((period) => [
        period,
        0,
      ])
    );

  const statuses = {};

  for (const doc of snapshot.docs) {
    const data = doc.data();

    if (
      data.schemaVersion !== 2 ||
      !PERIODS.includes(
        data.billingPeriod
      )
    ) {
      continue;
    }

    expectedPeriods[
      data.billingPeriod
    ] += 1;

    statuses[data.status] =
      (statuses[data.status] || 0) +
      1;
  }

  console.log(
    "\n===== GREEN WAVE BILLING V2 SUMMARY ====="
  );

  console.log(
    `V2 bills:       ${audit.existingBills}`
  );
  console.log(
    `V2 batches:     ${audit.existingBatches}`
  );
  console.log(
    `Monthly amount: ₹${(
      AMOUNT_MINOR / 100
    ).toFixed(2)}`
  );

  console.log("");

  for (const period of PERIODS) {
    console.log(
      `${period}: ${expectedPeriods[period]} bills`
    );

    if (
      expectedPeriods[period] !== 48
    ) {
      throw new Error(
        `Expected 48 bills for ${period}.`
      );
    }
  }

  console.log(
    "\nStored statuses:",
    statuses
  );
}

async function main() {
  const apply = hasArg("--apply");

  const projectId =
    valueArg("--project");

  if (
    projectId !== PROJECT_ID
  ) {
    throw new Error(
      `Refusing project ${projectId || "(missing)"}. ` +
      `Explicit --project ${PROJECT_ID} is required.`
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      projectId,
    });
  }

  const db =
    admin.firestore();

  await requireEnvironment(db);

  const scope =
    await loadScope(db);

  const existing =
    await inspectExisting(
      db,
      scope.flatIds
    );

  console.log(
    "===== HOMINODE GREEN WAVE BILLING V2 ====="
  );

  console.log(`Project:          ${projectId}`);
  console.log(`Community:        ${COMMUNITY_ID}`);
  console.log(
    `Mode:             ${apply ? "APPLY" : "DRY RUN"}`
  );
  console.log("");
  console.log(
    `Community units:  ${scope.totalFlats}`
  );
  console.log(
    `Eligible residents: ${scope.residents.length}`
  );
  console.log("Periods:          6");
  console.log(
    `Expected bills:   ${48 * PERIODS.length}`
  );
  console.log(
    `Existing bills:   ${existing.existingBills}`
  );
  console.log(
    `Missing bills:    ${existing.missingBills}`
  );
  console.log(
    `Existing batches: ${existing.existingBatches}`
  );
  console.log("");
  console.log(
    "Charge lines: Maintenance ₹2500 + Water ₹400 + Security ₹600"
  );
  console.log(
    "Monthly total: ₹3500"
  );
  console.log(
    "No recurring billing schedule will be created."
  );

  if (!apply) {
    console.log(
      "\nNo Firestore writes performed."
    );
    return;
  }

  for (const period of PERIODS) {
    await applyPeriod(
      db,
      period
    );
  }

  await validateFinal(
    db,
    scope.flatIds
  );

  console.log(
    "\nDemo Billing V2 bill generation complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo Billing V2 seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
