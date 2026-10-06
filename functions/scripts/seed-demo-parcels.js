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

const COURIERS = [
  "Amazon",
  "Flipkart",
  "Myntra",
  "Blue Dart",
  "Delhivery",
  "DTDC",
  "India Post",
  "BigBasket",
  "Blinkit",
  "Swiggy Instamart",
];

const NOTES = [
  "",
  "Received at parcel desk.",
  "Received at Service & Delivery gate.",
  "Resident pickup requested.",
  "",
  "Small package.",
  "",
  "Fragile package.",
  "",
  "Kept securely at parcel desk.",
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
  // Green Wave community timezone: Asia/Calcutta / Asia/Kolkata.
  // IST = UTC +05:30.
  return new Date(
    Date.UTC(year, month - 1, day, hour, minute) -
      330 * 60 * 1000
  );
}

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
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

async function loadEligibleResidents(db) {
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
        data.isActive === true &&
        data.status === "active" &&
        data.occupancyStatus === "current" &&
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

  if (residents.length !== 48) {
    throw new Error(
      `Expected 48 active/current Green Wave residents; found ${residents.length}.`
    );
  }

  return residents;
}

function historicalDay(monthIndex, itemIndex) {
  return 3 + ((itemIndex * 2 + monthIndex * 3) % 24);
}

function octoberDay(itemIndex) {
  if (itemIndex < 4) {
    return itemIndex + 1;
  }

  const pendingDays = [2, 3, 4, 5, 6, 6];

  return pendingDays[itemIndex - 4];
}

function buildPlan(residents) {
  const plan = [];

  let sequence = 0;

  MONTHS.forEach((month, monthIndex) => {
    for (let itemIndex = 0; itemIndex < 10; itemIndex += 1) {
      sequence += 1;

      const resident =
        residents[
          (sequence * 7 + monthIndex * 5 + itemIndex) %
            residents.length
        ];

      const pending =
        month.month === 10 && itemIndex >= 4;

      const day =
        month.month === 10
          ? octoberDay(itemIndex)
          : historicalDay(monthIndex, itemIndex);

      const hour = 9 + ((sequence * 3) % 7);
      const minute = (sequence * 11) % 60;

      const receivedAt = istDate(
        month.year,
        month.month,
        day,
        hour,
        minute
      );

      const collectedAt = pending
        ? null
        : addMinutes(
            receivedAt,
            90 + ((sequence * 37) % 900)
          );

      const courier =
        COURIERS[(sequence + monthIndex * 2) % COURIERS.length];

      const note =
        NOTES[(sequence * 3 + monthIndex) % NOTES.length];

      const trackingId =
        `GW-DEMO-${month.year}` +
        `${String(month.month).padStart(2, "0")}-` +
        `${String(itemIndex + 1).padStart(2, "0")}`;

      const data = {
        communityId: COMMUNITY_ID,

        residentId: resident.id,
        residentName:
          resident.data.name ||
          resident.data.fullName ||
          resident.id,

        flatId: resident.data.flatId,
        flatLabel:
          resident.data.flatLabel ||
          resident.data.unitId ||
          resident.data.flatId,

        buildingId: resident.data.buildingId,

        courier,
        trackingId,

        receivedAt: timestamp(receivedAt),
        collectedAt:
          collectedAt == null
            ? null
            : timestamp(collectedAt),

        status: pending ? "pending" : "collected",

        // No notification is actually sent by this seed.
        isResidentNotified: false,

        notes: note,

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey:
          `parcel:${month.label}:` +
          `${String(itemIndex + 1).padStart(2, "0")}`,

        createdAt: timestamp(receivedAt),
        updatedAt: timestamp(
          collectedAt || receivedAt
        ),
      };

      plan.push({
        id:
          `demo-parcel-${month.label}-` +
          `${String(itemIndex + 1).padStart(2, "0")}`,
        monthLabel: month.label,
        data,
      });
    }
  });

  if (plan.length !== 60) {
    throw new Error(
      `Expected 60 planned parcels; found ${plan.length}.`
    );
  }

  const collected = plan.filter(
    (item) => item.data.status === "collected"
  ).length;

  const pending = plan.filter(
    (item) => item.data.status === "pending"
  ).length;

  if (collected !== 54 || pending !== 6) {
    throw new Error(
      `Unexpected status mix: collected=${collected}, pending=${pending}.`
    );
  }

  return plan;
}

function timestampMillis(value) {
  if (
    value &&
    typeof value.toMillis === "function"
  ) {
    return value.toMillis();
  }

  return null;
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
    data.status !== item.data.status ||
    data.trackingId !== item.data.trackingId ||
    timestampMillis(data.receivedAt) !==
      timestampMillis(item.data.receivedAt)
  ) {
    throw new Error(
      `Conflicting parcel exists at parcels/${snapshot.id}.`
    );
  }

  if (
    item.data.status === "collected" &&
    timestampMillis(data.collectedAt) !==
      timestampMillis(item.data.collectedAt)
  ) {
    throw new Error(
      `Collected timestamp differs at parcels/${snapshot.id}.`
    );
  }

  if (
    item.data.status === "pending" &&
    data.collectedAt != null
  ) {
    throw new Error(
      `Pending parcel unexpectedly has collectedAt at parcels/${snapshot.id}.`
    );
  }
}

async function findMissing(db, plan) {
  const missing = [];

  for (const item of plan) {
    const snapshot = await db
      .collection("parcels")
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
  if (missing.length === 0) {
    return 0;
  }

  const commit = async () => {
    const batch = db.batch();

    for (const item of missing) {
      batch.create(
        db.collection("parcels").doc(item.id),
        item.data
      );
    }

    await batch.commit();
  };

  try {
    await commit();
    return missing.length;
  } catch (error) {
    if (!transient(error)) {
      throw error;
    }

    await sleep(2000);

    const remaining = await findMissing(
      db,
      missing
    );

    if (remaining.length === 0) {
      console.log(
        "[RECOVERED] Parcel batch committed despite client timeout."
      );

      return missing.length;
    }

    if (remaining.length !== missing.length) {
      throw new Error(
        "Unexpected partial parcel batch state."
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
    .collection("parcels")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const docs = snapshot.docs.filter((doc) => {
    const data = doc.data();

    return (
      data.isDemoData === true &&
      data.seedBatch === SEED_BATCH &&
      data.seedVersion === SEED_VERSION &&
      typeof data.seedKey === "string" &&
      data.seedKey.startsWith("parcel:")
    );
  });

  let collected = 0;
  let pending = 0;

  const months = {};

  for (const doc of docs) {
    const data = doc.data();

    if (data.status === "collected") {
      collected += 1;

      if (data.collectedAt == null) {
        throw new Error(
          `Collected parcel ${doc.id} is missing collectedAt.`
        );
      }
    } else if (data.status === "pending") {
      pending += 1;

      if (data.collectedAt != null) {
        throw new Error(
          `Pending parcel ${doc.id} has collectedAt.`
        );
      }
    } else {
      throw new Error(
        `Unexpected parcel status at ${doc.id}: ${data.status}`
      );
    }

    if (data.isResidentNotified !== false) {
      throw new Error(
        `Parcel ${doc.id} incorrectly claims resident notification.`
      );
    }

    const received =
      data.receivedAt?.toDate?.();

    if (!received) {
      throw new Error(
        `Parcel ${doc.id} has invalid receivedAt.`
      );
    }

    const label = istMonthLabel(received);

    months[label] =
      (months[label] || 0) + 1;
  }

  console.log(
    "\n===== GREEN WAVE PARCEL SUMMARY ====="
  );

  console.log(`Parcels:    ${docs.length}`);
  console.log(`Collected: ${collected}`);
  console.log(`Pending:   ${pending}`);

  console.log("");

  for (const month of MONTHS) {
    console.log(
      `${month.label}: ${months[month.label] || 0}`
    );
  }

  if (
    docs.length !== 60 ||
    collected !== 54 ||
    pending !== 6
  ) {
    throw new Error(
      "Parcel totals do not match the expected Green Wave dataset."
    );
  }

  for (const month of MONTHS) {
    if (months[month.label] !== 10) {
      throw new Error(
        `Expected 10 parcels in ${month.label}.`
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
    admin.initializeApp({
      projectId,
    });
  }

  const db = admin.firestore();

  await requireEnvironment(db);

  const residents =
    await loadEligibleResidents(db);

  const plan =
    buildPlan(residents);

  const missing =
    await findMissing(db, plan);

  console.log(
    "===== HOMINODE DEMO PARCELS ====="
  );

  console.log(`Project:       ${projectId}`);
  console.log(`Community:     ${COMMUNITY_ID}`);
  console.log(`Seed batch:    ${SEED_BATCH}`);
  console.log(
    `Mode:          ${apply ? "APPLY" : "DRY RUN"}`
  );

  console.log("");
  console.log(`Eligible residents: ${residents.length}`);
  console.log("Planned parcels:    60");
  console.log("Collected:          54");
  console.log("Pending:             6");
  console.log("Months:              May-Oct 2026");
  console.log(`Missing docs:       ${missing.length}`);

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
    `\n[OK] Parcel seed reconciled (${writes} writes).`
  );

  await validateFinal(db);

  console.log(
    "\nDemo parcel seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo parcel seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
