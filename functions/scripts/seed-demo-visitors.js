#!/usr/bin/env node

const admin = require("firebase-admin");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN_UID = "demo-admin-green-wave";

const SECURITY_BY_GATE = {
  "demo-gate-main-entrance": "demo-security-01",
  "demo-gate-service-delivery": "demo-security-03",
  "demo-gate-clubhouse": "demo-security-04",
};

const MONTHS = [
  { year: 2026, month: 5, label: "2026-05" },
  { year: 2026, month: 6, label: "2026-06" },
  { year: 2026, month: 7, label: "2026-07" },
  { year: 2026, month: 8, label: "2026-08" },
  { year: 2026, month: 9, label: "2026-09" },
  { year: 2026, month: 10, label: "2026-10" },
];

const FIRST_NAMES = [
  "Aditi", "Rahul", "Neha", "Vikram", "Pooja",
  "Rohit", "Simran", "Kunal", "Megha", "Akash",
  "Nisha", "Varun", "Ritika", "Siddharth", "Priya",
  "Manav", "Sneha", "Arjun", "Anjali", "Karthik",
  "Divya", "Nitin", "Riya", "Sanjay", "Anusha",
  "Harsh", "Shreya", "Abhinav", "Tanvi", "Gautam",
];

const LAST_NAMES = [
  "Shah", "Kapoor", "Rao", "Menon", "Nair",
  "Mehta", "Reddy", "Bose", "Iyer", "Khanna",
  "Verma", "Jain", "Thomas", "Gill", "Desai",
  "Bhatia", "Sethi", "Roy", "Shetty", "Mathew",
];

const PURPOSES = [
  {
    text: "Family visit",
    gateId: "demo-gate-main-entrance",
  },
  {
    text: "Friends visit",
    gateId: "demo-gate-main-entrance",
  },
  {
    text: "Personal guest",
    gateId: "demo-gate-main-entrance",
  },
  {
    text: "Healthcare visit",
    gateId: "demo-gate-main-entrance",
  },
  {
    text: "Home appliance service",
    gateId: "demo-gate-service-delivery",
  },
  {
    text: "Internet service",
    gateId: "demo-gate-service-delivery",
  },
  {
    text: "Interior contractor",
    gateId: "demo-gate-service-delivery",
  },
  {
    text: "Clubhouse guest",
    gateId: "demo-gate-clubhouse",
  },
];

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function istDate(
  year,
  month,
  day,
  hour,
  minute = 0
) {
  // Asia/Kolkata = UTC+05:30
  return new Date(
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

function addMinutes(date, minutes) {
  return new Date(
    date.getTime() + minutes * 60 * 1000
  );
}

function addHours(date, hours) {
  return addMinutes(date, hours * 60);
}

function addDays(date, days) {
  return addHours(date, days * 24);
}

function timestamp(date) {
  return admin.firestore.Timestamp.fromDate(date);
}

function currentResident(data) {
  return (
    data.role === "resident" &&
    data.isDemoData === true &&
    data.seedBatch === SEED_BATCH &&
    data.approvalStatus === "approved" &&
    data.flatId &&
    (
      data.occupancyStatus === "current" ||
      data.occupancyStatus === "suspended"
    )
  );
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
      "Green Wave demo community is unavailable."
    );
  }

  for (const gateId of Object.keys(
    SECURITY_BY_GATE
  )) {
    const gate = await db
      .collection("gates")
      .doc(gateId)
      .get();

    if (
      !gate.exists ||
      gate.data()?.communityId !== COMMUNITY_ID ||
      gate.data()?.isDemoData !== true ||
      gate.data()?.seedBatch !== SEED_BATCH ||
      gate.data()?.workingStatus !== "Active"
    ) {
      throw new Error(
        `Expected active demo security place ${gateId}.`
      );
    }
  }
}

async function loadResidents(db) {
  const snapshot = await db
    .collection("users")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const residents = snapshot.docs
    .map((doc) => ({
      id: doc.id,
      data: doc.data(),
    }))
    .filter(({ data }) =>
      currentResident(data)
    )
    .sort((a, b) =>
      String(a.data.seedKey).localeCompare(
        String(b.data.seedKey)
      )
    );

  if (residents.length !== 50) {
    throw new Error(
      `Expected 50 current households; found ${residents.length}.`
    );
  }

  return residents;
}

function visitorName(sequence) {
  return (
    FIRST_NAMES[
      sequence % FIRST_NAMES.length
    ] +
    " " +
    LAST_NAMES[
      Math.floor(sequence / 3) %
        LAST_NAMES.length
    ]
  );
}

function visitorPhone(sequence) {
  // Demo-only contact value. No Auth account
  // or outbound SMS is created by this seed.
  return `+9100001${String(
    1000 + sequence
  ).padStart(4, "0")}`;
}

function passCode(sequence) {
  return `GW${String(sequence).padStart(
    2,
    "0"
  )}-${String(
    5000 + sequence
  ).slice(-4)}`;
}

function stateFor(monthIndex, itemIndex) {
  if (monthIndex < 5) {
    return itemIndex < 18
      ? "completed"
      : "rejected";
  }

  if (itemIndex < 8) return "completed";
  if (itemIndex < 10) return "rejected";
  if (itemIndex < 14) return "expected";
  if (itemIndex < 16) return "approved";

  return "inside";
}

function historicalDay(
  monthIndex,
  itemIndex
) {
  if (monthIndex === 5) {
    // October historical records stay before
    // the live-demo anchor of 6 October.
    return 1 + (itemIndex % 5);
  }

  return (
    2 +
    ((itemIndex * 3 + monthIndex * 4) % 25)
  );
}

function buildVisitorData({
  sequence,
  resident,
  month,
  monthIndex,
  itemIndex,
}) {
  const state =
    stateFor(monthIndex, itemIndex);

  const purpose =
    PURPOSES[
      (sequence * 3) % PURPOSES.length
    ];

  let expectedArrival;

  if (
    month.year === 2026 &&
    month.month === 10 &&
    ["expected", "approved", "inside"].includes(
      state
    )
  ) {
    const liveOffset =
      state === "inside"
        ? itemIndex - 16
        : itemIndex - 10;

    expectedArrival = istDate(
      2026,
      10,
      6,
      state === "inside"
        ? 8 + liveOffset
        : 12 + liveOffset,
      (sequence * 7) % 60
    );
  } else {
    expectedArrival = istDate(
      month.year,
      month.month,
      historicalDay(
        monthIndex,
        itemIndex
      ),
      9 + (sequence % 10),
      (sequence * 11) % 60
    );
  }

  const createdAt =
    addDays(
      expectedArrival,
      -(1 + (sequence % 3))
    );

  const approvedAt =
    addMinutes(
      expectedArrival,
      -(30 + (sequence % 90))
    );

  const actualArrival =
    addMinutes(
      expectedArrival,
      (sequence % 17) - 5
    );

  const departure =
    addMinutes(
      actualArrival,
      45 + (sequence % 150)
    );

  const rejectedAt =
    addHours(
      createdAt,
      2 + (sequence % 8)
    );

  const name = visitorName(sequence);
  const phone = visitorPhone(sequence);

  const vehicleNumber =
    sequence % 4 === 0
      ? `KA53VG${String(
          2000 + sequence
        )}`
      : null;

  const base = {
    hostUserId: resident.id,
    residentId: resident.id,

    hostName: resident.data.name,
    residentName: resident.data.name,
    hostEmail:
      resident.data.email || "",

    flatId: resident.data.flatId,
    flatLabel:
      resident.data.flatLabel,
    buildingId:
      resident.data.buildingId,
    buildingIds: [
      resident.data.buildingId,
    ],

    adminId: SEED_ADMIN_UID,
    communityId: COMMUNITY_ID,

    visitorName: name,

    phone,
    phoneNumber: phone,

    purpose: purpose.text,

    expectedArrival:
      timestamp(expectedArrival),
    expectedTime:
      timestamp(expectedArrival),

    vehicleNumber,

    gateId: purpose.gateId,

    visitorPassCode:
      passCode(sequence),
    qrToken:
      `demo-green-wave-visitor-${String(
        sequence
      ).padStart(3, "0")}`,

    isDemoData: true,
    seedBatch: SEED_BATCH,
    seedVersion: SEED_VERSION,
    seedKey:
      `visitor:${month.label}:${String(
        itemIndex + 1
      ).padStart(2, "0")}`,

    createdAt:
      timestamp(createdAt),
  };

  if (state === "expected") {
    return {
      ...base,
      status: "expected",
      isApproved: false,

      approvedBy: null,
      approvedAt: null,

      rejectedBy: null,
      rejectedAt: null,

      actualArrival: null,
      departure: null,

      checkedInBy: null,
      checkedOutBy: null,

      updatedAt:
        timestamp(createdAt),
    };
  }

  if (state === "approved") {
    return {
      ...base,
      status: "approved",
      isApproved: true,

      approvedBy:
        SEED_ADMIN_UID,
      approvedAt:
        timestamp(approvedAt),

      rejectedBy: null,
      rejectedAt: null,

      actualArrival: null,
      departure: null,

      checkedInBy: null,
      checkedOutBy: null,

      updatedAt:
        timestamp(approvedAt),
    };
  }

  if (state === "inside") {
    const securityUid =
      SECURITY_BY_GATE[
        purpose.gateId
      ];

    return {
      ...base,
      status: "inside",
      isApproved: true,

      approvedBy:
        SEED_ADMIN_UID,
      approvedAt:
        timestamp(approvedAt),

      rejectedBy: null,
      rejectedAt: null,

      actualArrival:
        timestamp(actualArrival),
      departure: null,

      checkedInBy:
        securityUid,
      checkedOutBy: null,

      updatedAt:
        timestamp(actualArrival),
    };
  }

  if (state === "rejected") {
    return {
      ...base,
      status: "rejected",
      isApproved: false,

      approvedBy: null,
      approvedAt: null,

      rejectedBy:
        SEED_ADMIN_UID,
      rejectedAt:
        timestamp(rejectedAt),

      actualArrival: null,
      departure: null,

      checkedInBy: null,
      checkedOutBy: null,

      updatedAt:
        timestamp(rejectedAt),
    };
  }

  const securityUid =
    SECURITY_BY_GATE[
      purpose.gateId
    ];

  return {
    ...base,
    status: "completed",
    isApproved: true,

    approvedBy:
      SEED_ADMIN_UID,
    approvedAt:
      timestamp(approvedAt),

    rejectedBy: null,
    rejectedAt: null,

    actualArrival:
      timestamp(actualArrival),
    departure:
      timestamp(departure),

    checkedInBy:
      securityUid,
    checkedOutBy:
      securityUid,

    updatedAt:
      timestamp(departure),
  };
}

function buildPlan(residents) {
  const plan = [];

  let sequence = 0;

  MONTHS.forEach(
    (month, monthIndex) => {
      for (
        let itemIndex = 0;
        itemIndex < 20;
        itemIndex += 1
      ) {
        sequence += 1;

        const resident =
          residents[
            (sequence * 7 + monthIndex * 3) %
              residents.length
          ];

        plan.push({
          id:
            `demo-visitor-${month.label}-` +
            `${String(
              itemIndex + 1
            ).padStart(2, "0")}`,

          monthLabel: month.label,

          data: buildVisitorData({
            sequence,
            resident,
            month,
            monthIndex,
            itemIndex,
          }),
        });
      }
    }
  );

  if (plan.length !== 120) {
    throw new Error(
      `Expected 120 visitors; planned ${plan.length}.`
    );
  }

  return plan;
}

function assertVisitor(
  snapshot,
  plan
) {
  if (!snapshot.exists) return;

  const data = snapshot.data() || {};

  if (
    data.communityId !== COMMUNITY_ID ||
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    data.seedKey !==
      plan.data.seedKey ||
    data.hostUserId !==
      plan.data.hostUserId ||
    data.status !==
      plan.data.status
  ) {
    throw new Error(
      `Conflicting visitor exists at visitors/${plan.id}.`
    );
  }
}

async function findMissing(
  db,
  plan
) {
  const missing = [];

  for (const item of plan) {
    const snapshot = await db
      .collection("visitors")
      .doc(item.id)
      .get();

    assertVisitor(
      snapshot,
      item
    );

    if (!snapshot.exists) {
      missing.push(item);
    }
  }

  return missing;
}

async function writeMissing(
  db,
  missing
) {
  if (missing.length === 0) {
    return 0;
  }

  const commit = async () => {
    const batch = db.batch();

    for (const item of missing) {
      batch.create(
        db
          .collection("visitors")
          .doc(item.id),
        item.data
      );
    }

    await batch.commit();
  };

  try {
    await commit();
    return missing.length;
  } catch (error) {
    const transient =
      [4, 10, 13, 14].includes(
        Number(error?.code)
      );

    if (!transient) {
      throw error;
    }

    // Firestore may have committed the atomic
    // batch even if the client timed out.
    const remaining =
      await findMissing(
        db,
        missing
      );

    if (remaining.length === 0) {
      console.log(
        "[RECOVERED] Visitor batch committed despite timeout."
      );
      return missing.length;
    }

    if (
      remaining.length !==
      missing.length
    ) {
      throw new Error(
        "Unexpected partial visitor batch state."
      );
    }

    await new Promise((resolve) =>
      setTimeout(resolve, 2000)
    );

    await commit();

    return missing.length;
  }
}

async function validateFinal(
  db,
  plan
) {
  const snapshot = await db
    .collection("visitors")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const docs =
    snapshot.docs.filter(
      (doc) =>
        doc.data()?.isDemoData === true &&
        doc.data()?.seedBatch ===
          SEED_BATCH
    );

  const status = {
    completed: 0,
    rejected: 0,
    expected: 0,
    approved: 0,
    inside: 0,
  };

  const months = {};

  for (const doc of docs) {
    const data = doc.data();

    if (status[data.status] != null) {
      status[data.status] += 1;
    }

    const created =
      data.expectedArrival?.toDate();

    if (created) {
      const year =
        created.getUTCFullYear();

      // Convert UTC timestamp back far enough for
      // our deterministic IST month grouping.
      const ist = new Date(
        created.getTime() +
          330 * 60 * 1000
      );

      const label =
        `${ist.getUTCFullYear()}-` +
        `${String(
          ist.getUTCMonth() + 1
        ).padStart(2, "0")}`;

      months[label] =
        (months[label] || 0) + 1;
    }
  }

  console.log(
    "\n===== GREEN WAVE VISITOR SUMMARY ====="
  );

  console.log(
    `Visitors:   ${docs.length}`
  );
  console.log(
    `Completed:  ${status.completed}`
  );
  console.log(
    `Rejected:   ${status.rejected}`
  );
  console.log(
    `Expected:   ${status.expected}`
  );
  console.log(
    `Approved:   ${status.approved}`
  );
  console.log(
    `Inside:     ${status.inside}`
  );

  console.log("");
  for (const month of MONTHS) {
    console.log(
      `${month.label}: ${months[month.label] || 0}`
    );
  }

  if (
    docs.length !== 120 ||
    status.completed !== 98 ||
    status.rejected !== 12 ||
    status.expected !== 4 ||
    status.approved !== 2 ||
    status.inside !== 4
  ) {
    throw new Error(
      "Visitor totals do not match the expected dataset."
    );
  }

  for (const month of MONTHS) {
    if (
      months[month.label] !== 20
    ) {
      throw new Error(
        `Expected 20 visitors for ${month.label}.`
      );
    }
  }

  if (plan.length !== docs.length) {
    throw new Error(
      "Unexpected visitor dataset size."
    );
  }
}

async function main() {
  const apply =
    hasArg("--apply");

  const projectId =
    valueArg("--project") ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT;

  if (!projectId) {
    throw new Error(
      "Provide --project hominode-prod explicitly."
    );
  }

  if (projectId !== "hominode-prod") {
    throw new Error(
      `Refusing unexpected project: ${projectId}`
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

  const missing =
    await findMissing(
      db,
      plan
    );

  console.log(
    "===== HOMINODE DEMO VISITORS ====="
  );
  console.log(
    `Project:       ${projectId}`
  );
  console.log(
    `Community:     ${COMMUNITY_ID}`
  );
  console.log(
    `Seed batch:    ${SEED_BATCH}`
  );
  console.log(
    `Mode:          ${apply ? "APPLY" : "DRY RUN"}`
  );
  console.log("");
  console.log(
    "Visitors:      120"
  );
  console.log(
    "Completed:      98"
  );
  console.log(
    "Rejected:       12"
  );
  console.log(
    "Expected:        4"
  );
  console.log(
    "Approved:        2"
  );
  console.log(
    "Inside now:      4"
  );
  console.log(
    `Missing docs:   ${missing.length}`
  );

  if (!apply) {
    console.log(
      "\nNo Firestore writes performed."
    );
    return;
  }

  const writes =
    await writeMissing(
      db,
      missing
    );

  console.log(
    `\n[OK] Visitor seed reconciled (${writes} writes).`
  );

  await validateFinal(
    db,
    plan
  );

  console.log(
    "\nDemo visitor seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo visitor seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
