#!/usr/bin/env node

const admin = require("firebase-admin");
const { createHash } = require("node:crypto");

const {
  monthlyBillIdV2,
  monthlyBillingBatchId,
} = require("../src/billing_batch");

const {
  residentFinancialAccountId,
} = require("../src/billing_v2_ledger");

const PROJECT_ID = "hominode-prod";
const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";

const SEED_ADMIN_UID = "demo-admin-green-wave";

// Exact login-enabled demo persona created for Green Wave testing.
const LOGIN_ADMIN_UID =
  "76gnwll2zdPY8hQ5ie9Ys3xakmp1";
const LOGIN_ADMIN_PHONE =
  "+919100000001";

const PERIODS = [
  "2026-05",
  "2026-06",
  "2026-07",
  "2026-08",
  "2026-09",
  "2026-10",
];

const MARKED_COLLECTIONS = [
  ["buildings", 4],
  ["flats", 64],
  ["users", 52],
  ["familyMembers", 60],
  ["vehicles", 40],
  ["gates", 4],
  ["securityStaff", 6],
  ["visitors", 120],
  ["parcels", 60],
  ["complaints", 36],
  ["amenities", 6],
  ["bookings", 24],
  ["amenityBookingSlots", 24],
  ["events_announcements", 12],
];

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0
    ? process.argv[index + 1]
    : null;
}

function hash(value) {
  return createHash("sha256")
    .update(JSON.stringify(value))
    .digest("hex");
}

function settlementId(key) {
  return (
    "settlement_v2_" +
    hash([
      "offline",
      COMMUNITY_ID,
      key,
    ])
  );
}

function billingKey(period) {
  return `green-wave-demo-billing-${period}-v1`;
}

function expectedSettlementIds() {
  const keys = [];

  for (let i = 1; i <= 4; i++) {
    const suffix =
      String(i).padStart(2, "0");

    keys.push(
      `green-wave-demo-payment-full-${suffix}`,
      `green-wave-demo-payment-partial-${suffix}`,
      `green-wave-demo-payment-two-months-${suffix}`
    );
  }

  return new Set(
    keys.map(settlementId)
  );
}

function assertDemoMarker(data, path) {
  if (
    data?.isDemoData !== true ||
    data?.seedBatch !== SEED_BATCH
  ) {
    throw new Error(
      `Refusing reset: ${path} is not owned by ${SEED_BATCH}.`
    );
  }
}

async function communityQuery(
  db,
  collection
) {
  return db
    .collection(collection)
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();
}

async function collectMarked(
  db,
  collection,
  maximum
) {
  const snapshot =
    await communityQuery(
      db,
      collection
    );

  if (snapshot.size > maximum) {
    throw new Error(
      `Refusing reset: ${collection} has ${snapshot.size} records; expected at most ${maximum}.`
    );
  }

  for (const doc of snapshot.docs) {
    assertDemoMarker(
      doc.data(),
      `${collection}/${doc.id}`
    );
  }

  return snapshot.docs;
}

async function requireDemoCommunity(db) {
  const snapshot = await db
    .collection("communities")
    .doc(COMMUNITY_ID)
    .get();

  if (!snapshot.exists) {
    throw new Error(
      `${COMMUNITY_ID} does not exist.`
    );
  }

  const data =
    snapshot.data() || {};

  if (
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    data.slug !== "green-wave" ||
    (data.websitePath ?? data.slug) !==
      "green-wave"
  ) {
    throw new Error(
      "GREEN-WAVE demo community ownership guard failed."
    );
  }

  return {
    snapshot,
    data,
  };
}

async function collectDemoAdmins(db) {
  const snapshot = await db
    .collection("admins")
    .where(
      "authorizedCommunityIds",
      "array-contains",
      COMMUNITY_ID
    )
    .get();

  const owned = [];

  for (const doc of snapshot.docs) {
    const data =
      doc.data() || {};

    if (data.role === "superAdmin") {
      continue;
    }

    if (
      data.isDemoData !== true ||
      data.seedBatch !== SEED_BATCH
    ) {
      throw new Error(
        `Refusing reset: non-demo Admin ${doc.id} is assigned to GREEN-WAVE.`
      );
    }

    if (
      doc.id === SEED_ADMIN_UID &&
      data.seedActor !== true
    ) {
      throw new Error(
        "Seed Admin ownership guard failed."
      );
    }

    if (
      data.loginEnabled === true &&
      doc.id !== LOGIN_ADMIN_UID
    ) {
      throw new Error(
        `Unexpected login-enabled demo Admin: ${doc.id}`
      );
    }

    owned.push(doc);
  }

  return owned;
}

async function inspectAuthUser() {
  try {
    const user =
      await admin.auth().getUser(
        LOGIN_ADMIN_UID
      );

    if (
      user.phoneNumber !==
      LOGIN_ADMIN_PHONE
    ) {
      throw new Error(
        "Demo Auth user phone guard failed."
      );
    }

    return user;
  } catch (error) {
    if (
      error?.code ===
      "auth/user-not-found"
    ) {
      return null;
    }

    throw error;
  }
}

async function collectBilling(db) {
  const batchSnapshot =
    await communityQuery(
      db,
      "billingBatches"
    );

  if (batchSnapshot.size > 6) {
    throw new Error(
      "Unexpected extra GREEN-WAVE Billing V2 batches."
    );
  }

  const batchIds =
    new Set();

  const batchRoots = [];
  const batchChildren = [];

  for (const doc of batchSnapshot.docs) {
    const d =
      doc.data() || {};

    if (
      !PERIODS.includes(
        d.billingPeriod
      )
    ) {
      throw new Error(
        `Unexpected billing period at billingBatches/${doc.id}.`
      );
    }

    const expectedId =
      monthlyBillingBatchId(
        COMMUNITY_ID,
        billingKey(
          d.billingPeriod
        )
      );

    if (
      doc.id !== expectedId ||
      d.schemaVersion !== 2 ||
      d.communityId !==
        COMMUNITY_ID ||
      d.amountMinor !== 350000 ||
      d.idempotencyKey !==
        billingKey(
          d.billingPeriod
        )
    ) {
      throw new Error(
        `Billing batch ownership guard failed: ${doc.id}`
      );
    }

    batchIds.add(doc.id);
    batchRoots.push(doc);

    const subcollections =
      await doc.ref.listCollections();

    const unexpected =
      subcollections.filter(
        (ref) =>
          ![
            "targets",
            "revisions",
          ].includes(ref.id)
      );

    if (unexpected.length) {
      throw new Error(
        `Unexpected billing batch subcollection at ${doc.id}: ${unexpected
          .map((r) => r.id)
          .join(", ")}`
      );
    }

    const revisions =
      await doc.ref
        .collection("revisions")
        .get();

    for (
      const child of
      revisions.docs
    ) {
      const value =
        child.data() || {};

      if (
        value.communityId !==
          COMMUNITY_ID ||
        value.billingBatchId !==
          doc.id
      ) {
        throw new Error(
          `Batch revision ownership guard failed: ${child.ref.path}`
        );
      }

      batchChildren.push(child);
    }

    const targets =
      await doc.ref
        .collection("targets")
        .get();

    if (targets.size > 64) {
      throw new Error(
        `Too many billing targets in ${doc.id}.`
      );
    }

    for (
      const child of
      targets.docs
    ) {
      const value =
        child.data() || {};

      const expectedBillId =
        monthlyBillIdV2(
          COMMUNITY_ID,
          child.id,
          d.billingPeriod
        );

      if (
        value.communityId !==
          COMMUNITY_ID ||
        value.flatId !==
          child.id ||
        value.billId !==
          expectedBillId
      ) {
        throw new Error(
          `Billing target ownership guard failed: ${child.ref.path}`
        );
      }

      batchChildren.push(child);
    }
  }

  const billsSnapshot =
    await communityQuery(
      db,
      "bills"
    );

  if (billsSnapshot.size > 288) {
    throw new Error(
      "Unexpected extra GREEN-WAVE bills."
    );
  }

  const billIds =
    new Set();

  const billRoots = [];
  const billChildren = [];

  for (const doc of billsSnapshot.docs) {
    const d =
      doc.data() || {};

    if (
      d.schemaVersion !== 2 ||
      d.billingKind !==
        "recurring" ||
      d.communityId !==
        COMMUNITY_ID ||
      !PERIODS.includes(
        d.billingPeriod
      ) ||
      d.amountMinor !== 350000
    ) {
      throw new Error(
        `Bill ownership guard failed: ${doc.id}`
      );
    }

    const expectedId =
      monthlyBillIdV2(
        COMMUNITY_ID,
        d.flatId,
        d.billingPeriod
      );

    if (
      doc.id !== expectedId ||
      !batchIds.has(
        d.billingBatchId
      )
    ) {
      throw new Error(
        `Unexpected V2 bill identity: ${doc.id}`
      );
    }

    billIds.add(doc.id);
    billRoots.push(doc);

    const subcollections =
      await doc.ref.listCollections();

    const unexpected =
      subcollections.filter(
        (ref) =>
          ref.id !== "revisions"
      );

    if (unexpected.length) {
      throw new Error(
        `Unexpected bill subcollection at ${doc.id}: ${unexpected
          .map((r) => r.id)
          .join(", ")}`
      );
    }

    const revisions =
      await doc.ref
        .collection("revisions")
        .get();

    for (
      const child of
      revisions.docs
    ) {
      const value =
        child.data() || {};

      if (
        value.communityId !==
          COMMUNITY_ID ||
        value.billId !== doc.id
      ) {
        throw new Error(
          `Bill revision ownership guard failed: ${child.ref.path}`
        );
      }

      billChildren.push(child);
    }
  }

  const assignments =
    await communityQuery(
      db,
      "billingAssignments"
    );

  if (assignments.size > 288) {
    throw new Error(
      "Unexpected extra Billing V2 assignments."
    );
  }

  for (const doc of assignments.docs) {
    const d =
      doc.data() || {};

    const expectedId =
      monthlyBillIdV2(
        COMMUNITY_ID,
        d.flatId,
        d.billingPeriod
      );

    if (
      d.schemaVersion !== 2 ||
      d.communityId !==
        COMMUNITY_ID ||
      doc.id !== expectedId ||
      d.billId !== expectedId ||
      !PERIODS.includes(
        d.billingPeriod
      )
    ) {
      throw new Error(
        `Billing assignment ownership guard failed: ${doc.id}`
      );
    }
  }

  return {
    batchRoots,
    batchChildren,
    billRoots,
    billChildren,
    assignmentRoots:
      assignments.docs,
    billIds,
  };
}

async function collectPayments(
  db,
  billing,
  demoResidentIds
) {
  const legacyPayments =
    await communityQuery(
      db,
      "payments"
    );

  if (!legacyPayments.empty) {
    throw new Error(
      "Refusing reset: unexpected V1 payments exist for GREEN-WAVE."
    );
  }

  const proofs =
    await communityQuery(
      db,
      "paymentProofsV2"
    );

  if (!proofs.empty) {
    throw new Error(
      "Refusing reset: V2 payment proofs exist. Receipt storage must be reviewed first."
    );
  }

  const expectedSettlements =
    expectedSettlementIds();

  const settlementSnapshot =
    await db
      .collection(
        "paymentSettlementsV2"
      )
      .where(
        "transaction.communityId",
        "==",
        COMMUNITY_ID
      )
      .get();

  if (
    settlementSnapshot.size > 12
  ) {
    throw new Error(
      "Unexpected extra V2 settlements."
    );
  }

  const settlementIds =
    new Set();

  for (
    const doc of
    settlementSnapshot.docs
  ) {
    const d =
      doc.data() || {};

    if (
      !expectedSettlements.has(
        doc.id
      ) ||
      d.schemaVersion !== 2 ||
      d.createdBy !==
        SEED_ADMIN_UID ||
      d.transaction?.communityId !==
        COMMUNITY_ID
    ) {
      throw new Error(
        `Settlement ownership guard failed: ${doc.id}`
      );
    }

    settlementIds.add(doc.id);
  }

  const transactions =
    await communityQuery(
      db,
      "paymentTransactions"
    );

  if (transactions.size > 12) {
    throw new Error(
      "Unexpected extra payment transactions."
    );
  }

  const transactionIds =
    new Set();

  for (const doc of transactions.docs) {
    const d =
      doc.data() || {};

    if (
      d.schemaVersion !== 2 ||
      d.communityId !==
        COMMUNITY_ID ||
      !settlementIds.has(
        d.sourceId
      ) ||
      ![
        "admin_cash",
        "bank_transfer",
        "cheque",
      ].includes(d.sourceType)
    ) {
      throw new Error(
        `Payment transaction ownership guard failed: ${doc.id}`
      );
    }

    transactionIds.add(doc.id);
  }

  const allocations =
    await communityQuery(
      db,
      "paymentAllocations"
    );

  if (allocations.size > 56) {
    throw new Error(
      "Unexpected extra payment allocations."
    );
  }

  for (const doc of allocations.docs) {
    const d =
      doc.data() || {};

    if (
      d.schemaVersion !== 2 ||
      d.communityId !==
        COMMUNITY_ID ||
      !transactionIds.has(
        d.transactionId
      ) ||
      !billing.billIds.has(
        d.billId
      )
    ) {
      throw new Error(
        `Payment allocation ownership guard failed: ${doc.id}`
      );
    }
  }

  const credits =
    await communityQuery(
      db,
      "residentCreditEntries"
    );

  if (!credits.empty) {
    throw new Error(
      "Unexpected resident credit entries exist."
    );
  }

  const accounts =
    await communityQuery(
      db,
      "residentFinancialAccounts"
    );

  if (accounts.size > 12) {
    throw new Error(
      "Unexpected extra financial accounts."
    );
  }

  for (const doc of accounts.docs) {
    const d =
      doc.data() || {};

    const expectedId =
      residentFinancialAccountId({
        communityId:
          COMMUNITY_ID,
        residentId:
          d.residentId,
        currency: "INR",
      });

    if (
      d.schemaVersion !== 2 ||
      d.communityId !==
        COMMUNITY_ID ||
      d.currency !== "INR" ||
      !demoResidentIds.has(
        d.residentId
      ) ||
      doc.id !== expectedId
    ) {
      throw new Error(
        `Financial account ownership guard failed: ${doc.id}`
      );
    }
  }

  return {
    settlementRoots:
      settlementSnapshot.docs,
    transactionRoots:
      transactions.docs,
    allocationRoots:
      allocations.docs,
    creditRoots:
      credits.docs,
    accountRoots:
      accounts.docs,
    settlementIds,
  };
}

async function collectAuditLogs(
  db,
  demoAdminIds,
  settlementIds
) {
  const snapshot =
    await communityQuery(
      db,
      "auditLogs"
    );

  const owned = [];

  for (const doc of snapshot.docs) {
    const d =
      doc.data() || {};

    const isDemoActor =
      demoAdminIds.has(
        d.actorUid
      );

    const isPaymentAudit =
      settlementIds.has(doc.id);

    if (
      !isDemoActor &&
      !isPaymentAudit
    ) {
      throw new Error(
        `Refusing reset: unowned GREEN-WAVE audit log ${doc.id}.`
      );
    }

    owned.push(doc);
  }

  return owned;
}

async function deleteDocs(
  db,
  docs,
  label
) {
  if (!docs.length) {
    console.log(
      `[SKIP] ${label}: 0`
    );
    return;
  }

  const writer =
    db.bulkWriter();

  writer.onWriteError(
    (error) =>
      error.failedAttempts < 3
  );

  for (const doc of docs) {
    writer.delete(doc.ref);
  }

  await writer.close();

  console.log(
    `[DELETED] ${label}: ${docs.length}`
  );
}

async function main() {
  const apply =
    hasArg("--apply");

  const projectId =
    valueArg("--project");

  const confirmation =
    valueArg("--confirm");

  if (
    projectId !== PROJECT_ID
  ) {
    throw new Error(
      `Explicit --project ${PROJECT_ID} is required.`
    );
  }

  if (
    apply &&
    confirmation !==
      COMMUNITY_ID
  ) {
    throw new Error(
      `Destructive reset requires --confirm ${COMMUNITY_ID}.`
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      projectId,
    });
  }

  const db =
    admin.firestore();

  const community =
    await requireDemoCommunity(db);

  const marked = {};

  for (
    const [
      collection,
      maximum,
    ] of MARKED_COLLECTIONS
  ) {
    marked[collection] =
      await collectMarked(
        db,
        collection,
        maximum
      );
  }

  const residentIds =
    new Set(
      marked.users.map(
        (doc) => doc.id
      )
    );

  const demoAdmins =
    await collectDemoAdmins(db);

  const demoAdminIds =
    new Set([
      SEED_ADMIN_UID,
      LOGIN_ADMIN_UID,
      ...demoAdmins.map(
        (doc) => doc.id
      ),
    ]);

  const billing =
    await collectBilling(db);

  const payments =
    await collectPayments(
      db,
      billing,
      residentIds
    );

  const audits =
    await collectAuditLogs(
      db,
      demoAdminIds,
      payments.settlementIds
    );

  const slugRef =
    db.collection(
      "tenant_slugs"
    ).doc(
      community.data.slug
    );

  const pathRef =
    db.collection(
      "tenant_websitePaths"
    ).doc(
      community.data.websitePath ??
        community.data.slug
    );

  const [
    slugSnapshot,
    pathSnapshot,
  ] = await Promise.all([
    slugRef.get(),
    pathRef.get(),
  ]);

  for (const reservation of [
    slugSnapshot,
    pathSnapshot,
  ]) {
    if (
      reservation.exists &&
      reservation.data()?.communityId !==
        COMMUNITY_ID
    ) {
      throw new Error(
        `Tenant reservation ownership guard failed: ${reservation.ref.path}`
      );
    }
  }

  const authUser =
    await inspectAuthUser();

  console.log(
    "\n===== GREEN WAVE V1 RESET PREFLIGHT ====="
  );

  console.log(
    `Project:              ${PROJECT_ID}`
  );
  console.log(
    `Community:            ${COMMUNITY_ID}`
  );
  console.log(
    `Seed batch:           ${SEED_BATCH}`
  );
  console.log(
    `Mode:                 ${apply ? "APPLY" : "DRY RUN"}`
  );

  console.log(
    "\nMarked demo documents:"
  );

  for (
    const [
      collection,
    ] of MARKED_COLLECTIONS
  ) {
    console.log(
      `${collection.padEnd(24)} ${marked[collection].length}`
    );
  }

  console.log(
    "\nBilling V2:"
  );
  console.log(
    `billingBatches          ${billing.batchRoots.length}`
  );
  console.log(
    `batch children          ${billing.batchChildren.length}`
  );
  console.log(
    `billingAssignments      ${billing.assignmentRoots.length}`
  );
  console.log(
    `bills                   ${billing.billRoots.length}`
  );
  console.log(
    `bill revisions          ${billing.billChildren.length}`
  );

  console.log(
    "\nPayments V2:"
  );
  console.log(
    `settlements             ${payments.settlementRoots.length}`
  );
  console.log(
    `transactions            ${payments.transactionRoots.length}`
  );
  console.log(
    `allocations             ${payments.allocationRoots.length}`
  );
  console.log(
    `credit entries          ${payments.creditRoots.length}`
  );
  console.log(
    `financial accounts      ${payments.accountRoots.length}`
  );

  console.log(
    "\nOther:"
  );
  console.log(
    `audit logs              ${audits.length}`
  );
  console.log(
    `demo Admin docs         ${demoAdmins.length}`
  );
  console.log(
    `login Auth user         ${authUser ? "present" : "absent"}`
  );
  console.log(
    `slug reservation        ${slugSnapshot.exists ? "present" : "absent"}`
  );
  console.log(
    `website reservation     ${pathSnapshot.exists ? "present" : "absent"}`
  );

  if (!apply) {
    console.log(
      "\nNo Firestore or Firebase Auth writes performed."
    );
    console.log(
      `Actual reset requires BOTH --apply and --confirm ${COMMUNITY_ID}.`
    );
    return;
  }

  console.log(
    "\n===== DESTRUCTIVE RESET START ====="
  );

  // Children before their parent financial documents.
  await deleteDocs(
    db,
    billing.billChildren,
    "bill revisions"
  );

  await deleteDocs(
    db,
    billing.batchChildren,
    "billing batch children"
  );

  await deleteDocs(
    db,
    payments.allocationRoots,
    "payment allocations"
  );

  await deleteDocs(
    db,
    payments.transactionRoots,
    "payment transactions"
  );

  await deleteDocs(
    db,
    payments.creditRoots,
    "resident credit entries"
  );

  await deleteDocs(
    db,
    payments.accountRoots,
    "resident financial accounts"
  );

  await deleteDocs(
    db,
    payments.settlementRoots,
    "payment settlements"
  );

  await deleteDocs(
    db,
    billing.assignmentRoots,
    "billing assignments"
  );

  await deleteDocs(
    db,
    billing.billRoots,
    "bills"
  );

  await deleteDocs(
    db,
    billing.batchRoots,
    "billing batches"
  );

  await deleteDocs(
    db,
    audits,
    "audit logs"
  );

  const operationalOrder = [
    "amenityBookingSlots",
    "bookings",
    "events_announcements",
    "complaints",
    "parcels",
    "visitors",
    "amenities",
    "securityStaff",
    "gates",
    "vehicles",
    "familyMembers",
    "users",
    "flats",
    "buildings",
  ];

  for (
    const collection of
    operationalOrder
  ) {
    await deleteDocs(
      db,
      marked[collection],
      collection
    );
  }

  // Delete Auth before deleting its Firestore Admin guard document.
  if (authUser) {
    await admin.auth().deleteUser(
      LOGIN_ADMIN_UID
    );

    console.log(
      `[DELETED] Firebase Auth demo user: ${LOGIN_ADMIN_UID}`
    );
  } else {
    console.log(
      "[SKIP] Firebase Auth demo user already absent."
    );
  }

  await deleteDocs(
    db,
    demoAdmins,
    "demo Admin profiles"
  );

  if (slugSnapshot.exists) {
    await slugRef.delete();

    console.log(
      `[DELETED] ${slugRef.path}`
    );
  }

  if (pathSnapshot.exists) {
    await pathRef.delete();

    console.log(
      `[DELETED] ${pathRef.path}`
    );
  }

  await community.snapshot.ref.delete();

  console.log(
    `[DELETED] communities/${COMMUNITY_ID}`
  );

  console.log(
    "\n===== GREEN WAVE V1 RESET COMPLETE ====="
  );
}

main().catch((error) => {
  console.error(
    "\nGreen Wave reset failed."
  );
  console.error(error);
  process.exitCode = 1;
});
