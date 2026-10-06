#!/usr/bin/env node

const admin = require("firebase-admin");
const { createHash } = require("node:crypto");

const {
  recordOfflinePaymentV2Core,
} = require("../src/payment_v2");

const {
  getBillingV2FinancialReportCore,
} = require("../src/billing_v2_reports");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";

const SEED_ADMIN_UID = "demo-admin-green-wave";
const SEED_ADMIN_PHONE = "+919000000001";

const BILL_MINOR = 350000;

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

function hash(value) {
  return createHash("sha256")
    .update(JSON.stringify(value))
    .digest("hex");
}

function settlementId(idempotencyKey) {
  return (
    "settlement_v2_" +
    hash([
      "offline",
      COMMUNITY_ID,
      idempotencyKey,
    ])
  );
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

function istMillis(
  year,
  month,
  day,
  hour,
  minute = 0
) {
  return (
    Date.UTC(
      year,
      month - 1,
      day,
      hour,
      minute
    ) -
    330 * 60 * 1000
  );
}

async function requireEnvironment(db) {
  const community = await db
    .collection("communities")
    .doc(COMMUNITY_ID)
    .get();

  if (
    !community.exists ||
    community.data()?.isDemoData !== true ||
    community.data()?.seedBatch !== SEED_BATCH ||
    community.data()?.isActive !== true
  ) {
    throw new Error(
      "GREEN-WAVE demo guard failed."
    );
  }

  const adminDoc = await db
    .collection("admins")
    .doc(SEED_ADMIN_UID)
    .get();

  const actor = adminDoc.data() || {};

  if (
    !adminDoc.exists ||
    actor.uid !== SEED_ADMIN_UID ||
    actor.role !== "admin" ||
    actor.isActive !== true ||
    !Array.isArray(
      actor.authorizedCommunityIds
    ) ||
    !actor.authorizedCommunityIds.includes(
      COMMUNITY_ID
    )
  ) {
    throw new Error(
      "Green Wave seed admin guard failed."
    );
  }
}

async function loadResidents(db) {
  const snapshot = await db
    .collection("users")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const residents = snapshot.docs
    .map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }))
    .filter((r) =>
      r.role === "resident" &&
      r.isDemoData === true &&
      r.seedBatch === SEED_BATCH &&
      r.approvalStatus === "approved" &&
      r.isActive === true &&
      r.status === "active" &&
      r.occupancyStatus === "current"
    )
    .sort((a, b) =>
      String(a.seedKey || a.id)
        .localeCompare(
          String(b.seedKey || b.id)
        )
    );

  if (residents.length !== 48) {
    throw new Error(
      `Expected 48 active residents; found ${residents.length}.`
    );
  }

  return residents;
}

function buildPlan(residents) {
  const selected = residents.slice(0, 12);

  if (selected.length !== 12) {
    throw new Error(
      "Could not select 12 residents."
    );
  }

  const plan = [];

  for (let i = 0; i < 4; i++) {
    plan.push({
      resident: selected[i],
      amountMinor: 6 * BILL_MINOR,
      paymentMethod: "bank_transfer",
      paymentReference:
        `GW-DEMO-BANK-${String(i + 1).padStart(2, "0")}`,
      idempotencyKey:
        `green-wave-demo-payment-full-${String(i + 1).padStart(2, "0")}`,
      nowMs: istMillis(
        2026,
        10,
        5,
        10,
        i * 5
      ),
      group: "fully-paid",
    });
  }

  for (let i = 4; i < 8; i++) {
    plan.push({
      resident: selected[i],
      amountMinor:
        5 * BILL_MINOR +
        BILL_MINOR / 2,
      paymentMethod: "cash",
      paymentReference:
        `GW-DEMO-CASH-${String(i - 3).padStart(2, "0")}`,
      idempotencyKey:
        `green-wave-demo-payment-partial-${String(i - 3).padStart(2, "0")}`,
      nowMs: istMillis(
        2026,
        10,
        5,
        12,
        (i - 4) * 5
      ),
      group: "partial-october",
    });
  }

  for (let i = 8; i < 12; i++) {
    plan.push({
      resident: selected[i],
      amountMinor: 2 * BILL_MINOR,
      paymentMethod: "cheque",
      paymentReference:
        `GW-DEMO-CHQ-${String(i - 7).padStart(2, "0")}`,
      idempotencyKey:
        `green-wave-demo-payment-two-months-${String(i - 7).padStart(2, "0")}`,
      nowMs: istMillis(
        2026,
        7,
        5,
        11,
        (i - 8) * 5
      ),
      group: "may-june-paid",
    });
  }

  return plan.sort(
    (a, b) => a.nowMs - b.nowMs
  );
}

async function verifyBillsExist(
  db,
  plan
) {
  for (const item of plan) {
    const snapshot = await db
      .collection("bills")
      .where(
        "communityId",
        "==",
        COMMUNITY_ID
      )
      .where(
        "residentId",
        "==",
        item.resident.id
      )
      .get();

    const bills = snapshot.docs.filter(
      (doc) => {
        const d = doc.data();

        return (
          d.schemaVersion === 2 &&
          d.billingKind === "recurring" &&
          /^2026-(05|06|07|08|09|10)$/.test(
            d.billingPeriod
          )
        );
      }
    );

    if (bills.length !== 6) {
      throw new Error(
        `Expected 6 V2 bills for ${item.resident.id}; found ${bills.length}.`
      );
    }

    if (
      bills.some(
        (doc) =>
          doc.data().amountMinor !==
          BILL_MINOR
      )
    ) {
      throw new Error(
        `Unexpected bill amount for ${item.resident.id}.`
      );
    }
  }
}

async function inspectSettlements(
  db,
  plan
) {
  let existing = 0;
  let missing = 0;

  for (const item of plan) {
    const id =
      settlementId(
        item.idempotencyKey
      );

    const snapshot = await db
      .collection(
        "paymentSettlementsV2"
      )
      .doc(id)
      .get();

    if (!snapshot.exists) {
      missing += 1;
      continue;
    }

    existing += 1;

    const d = snapshot.data() || {};
    const tx = d.transaction || {};

    if (
      d.schemaVersion !== 2 ||
      d.createdBy !==
        SEED_ADMIN_UID ||
      tx.communityId !==
        COMMUNITY_ID ||
      tx.residentId !==
        item.resident.id ||
      tx.amountMinor !==
        item.amountMinor
    ) {
      throw new Error(
        `Conflicting settlement ${id}.`
      );
    }
  }

  return { existing, missing };
}

async function applyPayment(
  db,
  item
) {
  const result =
    await recordOfflinePaymentV2Core({
      db,
      auth: authContext(),
      data: {
        communityId:
          COMMUNITY_ID,

        residentId:
          item.resident.id,

        amountMinor:
          item.amountMinor,

        paymentMethod:
          item.paymentMethod,

        paymentReference:
          item.paymentReference,

        idempotencyKey:
          item.idempotencyKey,
      },

      now: () => item.nowMs,
    });

  console.log(
    `${item.group}: ` +
    `${item.resident.name || item.resident.fullName || item.resident.id} ` +
    `₹${(item.amountMinor / 100).toFixed(2)} ` +
    `${item.paymentMethod} ` +
    `alreadyCompleted=${result.alreadyCompleted}`
  );
}

async function validateFinal(
  db,
  plan
) {
  const [
    settlements,
    transactions,
    allocations,
    credits,
    accounts,
    bills,
  ] = await Promise.all([
    db
      .collection("paymentSettlementsV2")
      .where(
        "createdBy",
        "==",
        SEED_ADMIN_UID
      )
      .get(),

    db
      .collection("paymentTransactions")
      .where(
        "communityId",
        "==",
        COMMUNITY_ID
      )
      .get(),

    db
      .collection("paymentAllocations")
      .where(
        "communityId",
        "==",
        COMMUNITY_ID
      )
      .get(),

    db
      .collection("residentCreditEntries")
      .where(
        "communityId",
        "==",
        COMMUNITY_ID
      )
      .get(),

    db
      .collection("residentFinancialAccounts")
      .where(
        "communityId",
        "==",
        COMMUNITY_ID
      )
      .get(),

    db
      .collection("bills")
      .where(
        "communityId",
        "==",
        COMMUNITY_ID
      )
      .get(),
  ]);

  const targetSettlementIds =
    new Set(
      plan.map((item) =>
        settlementId(
          item.idempotencyKey
        )
      )
    );

  const demoSettlements =
    settlements.docs.filter((doc) =>
      targetSettlementIds.has(doc.id)
    );

  const statusCounts = {};

  let paidMinor = 0;

  for (const doc of bills.docs) {
    const d = doc.data();

    if (
      d.schemaVersion !== 2 ||
      !/^2026-(05|06|07|08|09|10)$/.test(
        d.billingPeriod || ""
      )
    ) {
      continue;
    }

    statusCounts[d.status] =
      (statusCounts[d.status] || 0) +
      1;

    paidMinor +=
      Number(d.paidAmountMinor) || 0;
  }

  console.log(
    "\n===== GREEN WAVE PAYMENT V2 SUMMARY ====="
  );

  console.log(
    `Settlements:       ${demoSettlements.length}`
  );
  console.log(
    `Transactions:      ${transactions.size}`
  );
  console.log(
    `Allocations:       ${allocations.size}`
  );
  console.log(
    `Credit entries:    ${credits.size}`
  );
  console.log(
    `Financial accounts:${accounts.size}`
  );

  console.log(
    `Paid allocations:  ₹${(
      paidMinor / 100
    ).toFixed(2)}`
  );

  console.log(
    "Stored bill statuses:",
    statusCounts
  );

  if (
    demoSettlements.length !== 12 ||
    transactions.size !== 12 ||
    allocations.size !== 56 ||
    credits.size !== 0 ||
    accounts.size !== 12 ||
    paidMinor !== 18900000 ||
    statusCounts.paid !== 52 ||
    statusCounts.partially_paid !== 4 ||
    statusCounts.pending !== 232
  ) {
    throw new Error(
      "Final payment history totals are not as expected."
    );
  }

  const auditNow =
    istMillis(
      2026,
      10,
      6,
      12,
      0
    );

  console.log(
    "\n===== V2 REPORT CHECK ====="
  );

  for (const period of [
    "2026-05",
    "2026-06",
    "2026-07",
    "2026-08",
    "2026-09",
    "2026-10",
  ]) {
    const report =
      await getBillingV2FinancialReportCore({
        db,
        auth: authContext(),
        data: {
          communityId:
            COMMUNITY_ID,
          billingPeriod:
            period,
        },
        now: () => auditNow,
      });

    const s =
      report.liabilitySummary
        .statusCounts;

    console.log(
      `${period}: ` +
      `paid=${s.paid}, ` +
      `partial=${s.partially_paid}, ` +
      `overdue=${s.overdue}, ` +
      `pending=${s.pending}`
    );
  }
}

async function main() {
  const apply = hasArg("--apply");

  const projectId =
    valueArg("--project");

  if (
    projectId !== "hominode-prod"
  ) {
    throw new Error(
      "Explicit --project hominode-prod is required."
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

  const residents =
    await loadResidents(db);

  const plan =
    buildPlan(residents);

  await verifyBillsExist(
    db,
    plan
  );

  const state =
    await inspectSettlements(
      db,
      plan
    );

  console.log(
    "===== HOMINODE GREEN WAVE PAYMENT V2 ====="
  );

  console.log(
    `Project:              ${projectId}`
  );
  console.log(
    `Community:            ${COMMUNITY_ID}`
  );
  console.log(
    `Mode:                 ${apply ? "APPLY" : "DRY RUN"}`
  );
  console.log("");
  console.log(
    "Planned residents:    12"
  );
  console.log(
    "Planned settlements:  12"
  );
  console.log(
    "Fully paid residents: 4"
  );
  console.log(
    "Partial Oct residents:4"
  );
  console.log(
    "May-Jun paid only:    4"
  );
  console.log(
    "Expected allocations: 56"
  );
  console.log(
    "Expected received:    ₹189000.00"
  );
  console.log(
    `Existing settlements: ${state.existing}`
  );
  console.log(
    `Missing settlements:  ${state.missing}`
  );

  if (!apply) {
    console.log(
      "\nNo Firestore writes performed."
    );
    return;
  }

  for (const item of plan) {
    await applyPayment(
      db,
      item
    );
  }

  await validateFinal(
    db,
    plan
  );

  console.log(
    "\nDemo Billing V2 payment history complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo payment V2 seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
