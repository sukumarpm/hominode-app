#!/usr/bin/env node

const admin = require("firebase-admin");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const MONTHS = [
  { year: 2026, month: 5, label: "2026-05" },
  { year: 2026, month: 6, label: "2026-06" },
  { year: 2026, month: 7, label: "2026-07" },
  { year: 2026, month: 8, label: "2026-08" },
  { year: 2026, month: 9, label: "2026-09" },
  { year: 2026, month: 10, label: "2026-10" },
];

const CASES = [
  {
    title: "Low water pressure in bathroom",
    description:
      "Water pressure has been unusually low during the morning hours.",
    category: "plumbing",
    priority: "medium",
    assignedTo: "Plumbing Team",
  },
  {
    title: "Corridor light not working",
    description:
      "The common corridor light near the apartment has stopped working.",
    category: "electrical",
    priority: "low",
    assignedTo: "Electrical Team",
  },
  {
    title: "EV charger intermittently unavailable",
    description:
      "The resident EV charging point disconnects intermittently during charging.",
    category: "electrical",
    priority: "high",
    assignedTo: "Electrical Team",
  },
  {
    title: "Parcel locker door not closing",
    description:
      "One of the smart parcel locker doors is not locking correctly.",
    category: "maintenance",
    priority: "medium",
    assignedTo: "Facility Maintenance",
  },
  {
    title: "Housekeeping required near lift lobby",
    description:
      "The lift lobby requires additional cleaning after maintenance activity.",
    category: "cleaning",
    priority: "low",
    assignedTo: "Housekeeping Team",
  },
  {
    title: "Smart access reader delayed",
    description:
      "The access reader takes several seconds to recognize resident credentials.",
    category: "security",
    priority: "high",
    assignedTo: "Security Desk",
  },
  {
    title: "Kitchen sink drainage slow",
    description:
      "The kitchen sink is draining slowly and may require inspection.",
    category: "plumbing",
    priority: "medium",
    assignedTo: "Plumbing Team",
  },
  {
    title: "Co-working lounge AC issue",
    description:
      "Cooling in the co-working lounge is weaker than usual.",
    category: "maintenance",
    priority: "medium",
    assignedTo: "Facility Maintenance",
  },
  {
    title: "Rooftop fitness equipment inspection",
    description:
      "One treadmill is making an unusual sound and should be inspected.",
    category: "maintenance",
    priority: "medium",
    assignedTo: "Facility Maintenance",
  },
  {
    title: "Parking area lighting dim",
    description:
      "Lighting near the resident parking bays is noticeably dim.",
    category: "electrical",
    priority: "medium",
    assignedTo: "Electrical Team",
  },
  {
    title: "Waste segregation bin needs replacement",
    description:
      "A sustainability waste-segregation bin is damaged and needs replacement.",
    category: "cleaning",
    priority: "low",
    assignedTo: "Housekeeping Team",
  },
  {
    title: "Unusual noise near service area",
    description:
      "Intermittent mechanical noise is audible near the service corridor.",
    category: "other",
    priority: "low",
    assignedTo: "Facility Maintenance",
  },
];

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function transient(error) {
  return (
    [4, 10, 13, 14].includes(Number(error?.code)) ||
    [
      "deadline-exceeded",
      "aborted",
      "internal",
      "unavailable",
    ].includes(String(error?.code || "").toLowerCase())
  );
}

function istDate(year, month, day, hour, minute = 0) {
  return new Date(
    Date.UTC(year, month - 1, day, hour, minute) -
      330 * 60 * 1000
  );
}

function addHours(date, hours) {
  return new Date(date.getTime() + hours * 60 * 60 * 1000);
}

function timestamp(date) {
  return admin.firestore.Timestamp.fromDate(date);
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
      "Expected active Green Wave demo community was not found."
    );
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
    .filter(({ data }) => {
      return (
        data.role === "resident" &&
        data.isDemoData === true &&
        data.seedBatch === SEED_BATCH &&
        data.approvalStatus === "approved" &&
        data.occupancyStatus !== "moved_out" &&
        typeof data.flatId === "string" &&
        data.flatId.length > 0 &&
        typeof data.buildingId === "string" &&
        data.buildingId.length > 0
      );
    })
    .sort((a, b) =>
      String(a.data.seedKey || a.id).localeCompare(
        String(b.data.seedKey || b.id)
      )
    );

  if (residents.length !== 50) {
    throw new Error(
      `Expected 50 current/suspended households; found ${residents.length}.`
    );
  }

  return residents;
}

function statusFor(sequence) {
  // 36 records:
  // first 25 resolved
  // next 6 in-progress
  // final 5 pending
  if (sequence <= 25) return "resolved";
  if (sequence <= 31) return "in-progress";
  return "pending";
}

function buildPlan(residents) {
  const plan = [];
  let sequence = 0;

  MONTHS.forEach((month, monthIndex) => {
    for (let itemIndex = 0; itemIndex < 6; itemIndex += 1) {
      sequence += 1;

      const resident =
        residents[
          (sequence * 5 + monthIndex * 7 + itemIndex) %
            residents.length
        ];

      const definition =
        CASES[(sequence + monthIndex * 2) % CASES.length];

      const day =
        month.month === 10
          ? 1 + (itemIndex % 6)
          : 3 + ((itemIndex * 4 + monthIndex * 3) % 24);

      const createdAt = istDate(
        month.year,
        month.month,
        day,
        8 + ((sequence * 3) % 10),
        (sequence * 13) % 60
      );

      const status = statusFor(sequence);

      const assignedAt =
        status === "pending"
          ? null
          : addHours(createdAt, 2 + (sequence % 8));

      const resolvedAt =
        status === "resolved"
          ? addHours(
              assignedAt,
              4 + ((sequence * 5) % 44)
            )
          : null;

      const updatedAt =
        resolvedAt || assignedAt || createdAt;

      const data = {
        communityId: COMMUNITY_ID,

        userId: resident.id,
        residentId: resident.id,

        residentName:
          resident.data.name ||
          resident.data.fullName ||
          resident.id,

        userName:
          resident.data.name ||
          resident.data.fullName ||
          resident.id,

        userEmail: resident.data.email || "",

        flatId: resident.data.flatId,
        flatLabel:
          resident.data.flatLabel ||
          resident.data.unitId ||
          resident.data.flatId,

        buildingId: resident.data.buildingId,

        adminId: "demo-admin-green-wave",

        title: definition.title,
        description: definition.description,
        category: definition.category,
        priority: definition.priority,

        status,

        assignedTo:
          status === "pending"
            ? null
            : definition.assignedTo,

        technicianPhone: null,
        assignedStaffId: null,
        assignedStaffRole: null,

        isResolved: status === "resolved",
        resolvedAt:
          resolvedAt == null
            ? null
            : timestamp(resolvedAt),

        createdAt: timestamp(createdAt),
        updatedAt: timestamp(updatedAt),

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey:
          `complaint:${month.label}:` +
          `${String(itemIndex + 1).padStart(2, "0")}`,
      };

      plan.push({
        id:
          `demo-complaint-${month.label}-` +
          `${String(itemIndex + 1).padStart(2, "0")}`,
        monthLabel: month.label,
        data,
      });
    }
  });

  const resolved = plan.filter(
    (item) => item.data.status === "resolved"
  ).length;

  const inProgress = plan.filter(
    (item) => item.data.status === "in-progress"
  ).length;

  const pending = plan.filter(
    (item) => item.data.status === "pending"
  ).length;

  if (
    plan.length !== 36 ||
    resolved !== 25 ||
    inProgress !== 6 ||
    pending !== 5
  ) {
    throw new Error(
      `Unexpected complaint plan: total=${plan.length}, resolved=${resolved}, inProgress=${inProgress}, pending=${pending}.`
    );
  }

  return plan;
}

function timestampMillis(value) {
  return value?.toMillis?.() ?? null;
}

function assertExisting(snapshot, item) {
  if (!snapshot.exists) return;

  const data = snapshot.data() || {};

  if (
    data.communityId !== COMMUNITY_ID ||
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    data.seedVersion !== SEED_VERSION ||
    data.seedKey !== item.data.seedKey ||
    data.residentId !== item.data.residentId ||
    data.flatId !== item.data.flatId ||
    data.buildingId !== item.data.buildingId ||
    data.title !== item.data.title ||
    data.category !== item.data.category ||
    data.priority !== item.data.priority ||
    data.status !== item.data.status ||
    timestampMillis(data.createdAt) !==
      timestampMillis(item.data.createdAt)
  ) {
    throw new Error(
      `Conflicting complaint exists at complaints/${snapshot.id}.`
    );
  }
}

async function findMissing(db, plan) {
  const missing = [];

  for (const item of plan) {
    const snapshot = await db
      .collection("complaints")
      .doc(item.id)
      .get();

    assertExisting(snapshot, item);

    if (!snapshot.exists) {
      missing.push(item);
    }
  }

  return missing;
}

async function writeMissing(db, missing) {
  if (missing.length === 0) return 0;

  const commit = async () => {
    const batch = db.batch();

    for (const item of missing) {
      batch.create(
        db.collection("complaints").doc(item.id),
        item.data
      );
    }

    await batch.commit();
  };

  try {
    await commit();
    return missing.length;
  } catch (error) {
    if (!transient(error)) throw error;

    await sleep(2000);

    const remaining =
      await findMissing(db, missing);

    if (remaining.length === 0) {
      console.log(
        "[RECOVERED] Complaint batch committed despite timeout."
      );
      return missing.length;
    }

    if (remaining.length !== missing.length) {
      throw new Error(
        "Unexpected partial complaint batch state."
      );
    }

    await commit();
    return missing.length;
  }
}

function istMonthLabel(date) {
  const shifted = new Date(
    date.getTime() + 330 * 60 * 1000
  );

  return (
    `${shifted.getUTCFullYear()}-` +
    `${String(
      shifted.getUTCMonth() + 1
    ).padStart(2, "0")}`
  );
}

async function validateFinal(db) {
  const snapshot = await db
    .collection("complaints")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const docs = snapshot.docs.filter((doc) => {
    const data = doc.data();

    return (
      data.isDemoData === true &&
      data.seedBatch === SEED_BATCH &&
      typeof data.seedKey === "string" &&
      data.seedKey.startsWith("complaint:")
    );
  });

  let resolved = 0;
  let inProgress = 0;
  let pending = 0;

  const months = {};

  for (const doc of docs) {
    const data = doc.data();

    if (data.status === "resolved") {
      resolved += 1;

      if (
        data.isResolved !== true ||
        data.resolvedAt == null
      ) {
        throw new Error(
          `Resolved complaint ${doc.id} has inconsistent resolution fields.`
        );
      }
    } else if (data.status === "in-progress") {
      inProgress += 1;
    } else if (data.status === "pending") {
      pending += 1;
    } else {
      throw new Error(
        `Unexpected complaint status at ${doc.id}: ${data.status}`
      );
    }

    const created = data.createdAt?.toDate?.();

    if (!created) {
      throw new Error(
        `Complaint ${doc.id} has invalid createdAt.`
      );
    }

    const label = istMonthLabel(created);

    months[label] =
      (months[label] || 0) + 1;
  }

  console.log(
    "\n===== GREEN WAVE COMPLAINT SUMMARY ====="
  );

  console.log(`Complaints:   ${docs.length}`);
  console.log(`Resolved:     ${resolved}`);
  console.log(`In progress:  ${inProgress}`);
  console.log(`Pending:      ${pending}`);

  console.log("");

  for (const month of MONTHS) {
    console.log(
      `${month.label}: ${months[month.label] || 0}`
    );
  }

  if (
    docs.length !== 36 ||
    resolved !== 25 ||
    inProgress !== 6 ||
    pending !== 5
  ) {
    throw new Error(
      "Complaint totals do not match the expected dataset."
    );
  }

  for (const month of MONTHS) {
    if (months[month.label] !== 6) {
      throw new Error(
        `Expected 6 complaints for ${month.label}.`
      );
    }
  }
}

async function main() {
  const apply = hasArg("--apply");

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
    admin.initializeApp({ projectId });
  }

  const db = admin.firestore();

  await requireEnvironment(db);

  const residents =
    await loadResidents(db);

  const plan =
    buildPlan(residents);

  const missing =
    await findMissing(db, plan);

  console.log(
    "===== HOMINODE DEMO COMPLAINTS ====="
  );

  console.log(`Project:       ${projectId}`);
  console.log(`Community:     ${COMMUNITY_ID}`);
  console.log(`Seed batch:    ${SEED_BATCH}`);
  console.log(
    `Mode:          ${apply ? "APPLY" : "DRY RUN"}`
  );

  console.log("");
  console.log(`Households:       ${residents.length}`);
  console.log("Planned complaints: 36");
  console.log("Resolved:           25");
  console.log("In progress:         6");
  console.log("Pending:             5");
  console.log("Months:              May-Oct 2026");
  console.log(`Missing docs:       ${missing.length}`);

  if (!apply) {
    console.log(
      "\nNo Firestore writes performed."
    );
    return;
  }

  const writes =
    await writeMissing(db, missing);

  console.log(
    `\n[OK] Complaint seed reconciled (${writes} writes).`
  );

  await validateFinal(db);

  console.log(
    "\nDemo complaint seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo complaint seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
