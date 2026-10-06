#!/usr/bin/env node

const admin = require("firebase-admin");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN = {
  uid: "demo-admin-green-wave",
  name: "Maya Rao",
};

const BUILDING_NAMES = {
  nova: "Nova",
  vertex: "Vertex",
  horizon: "Horizon",
  pulse: "Pulse",
};

const AMENITIES = [
  {
    id: "demo-amenity-coworking-lounge",
    key: "coworking-lounge",
    buildingKey: "nova",
    name: "Co-working Lounge",
    type: "Facility",
    description:
      "Quiet shared workspace with Wi-Fi, charging points, and collaborative seating.",
    iconName: "hall",
    isFree: true,
    pricingMode: "free",
    pricePerDay: 0,
    timeSlots: [
      "8:00 AM - 10:00 AM",
      "10:00 AM - 12:00 PM",
      "2:00 PM - 4:00 PM",
      "4:00 PM - 6:00 PM",
      "6:00 PM - 8:00 PM",
    ],
    maxCapacity: 12,
    allowMultipleBookings: true,
    bookingDurations: ["2 hours"],
  },
  {
    id: "demo-amenity-rooftop-fitness",
    key: "rooftop-fitness",
    buildingKey: "vertex",
    name: "Rooftop Fitness",
    type: "Sports",
    description:
      "Open-air rooftop fitness area for resident workouts and small group sessions.",
    iconName: "gym",
    isFree: true,
    pricingMode: "free",
    pricePerDay: 0,
    timeSlots: [
      "6:00 AM - 7:00 AM",
      "7:00 AM - 8:00 AM",
      "6:00 PM - 7:00 PM",
      "7:00 PM - 8:00 PM",
    ],
    maxCapacity: 8,
    allowMultipleBookings: true,
    bookingDurations: ["1 hour"],
  },
  {
    id: "demo-amenity-multipurpose-hall",
    key: "multipurpose-hall",
    buildingKey: "horizon",
    name: "Multipurpose Hall",
    type: "Event",
    description:
      "Community hall for celebrations, meetings, workshops, and resident events.",
    iconName: "hall",
    isFree: false,
    pricingMode: "flat",
    pricePerDay: 1500,
    timeSlots: [
      "9:00 AM - 1:00 PM",
      "2:00 PM - 6:00 PM",
      "6:30 PM - 10:00 PM",
    ],
    maxCapacity: 50,
    allowMultipleBookings: false,
    bookingDurations: ["Half day"],
  },
  {
    id: "demo-amenity-badminton-court",
    key: "badminton-court",
    buildingKey: "pulse",
    name: "Badminton Court",
    type: "Sports",
    description:
      "Resident badminton court with bookable morning and evening playing slots.",
    iconName: "playground",
    isFree: false,
    pricingMode: "flat",
    pricePerDay: 250,
    timeSlots: [
      "6:00 AM - 7:00 AM",
      "7:00 AM - 8:00 AM",
      "6:00 PM - 7:00 PM",
      "7:00 PM - 8:00 PM",
      "8:00 PM - 9:00 PM",
    ],
    maxCapacity: 4,
    allowMultipleBookings: false,
    bookingDurations: ["1 hour"],
  },
  {
    id: "demo-amenity-swimming-pool",
    key: "swimming-pool",
    buildingKey: "nova",
    name: "Swimming Pool",
    type: "Recreation",
    description:
      "Community swimming pool with controlled resident capacity during each session.",
    iconName: "pool",
    isFree: true,
    pricingMode: "free",
    pricePerDay: 0,
    timeSlots: [
      "6:00 AM - 7:00 AM",
      "7:00 AM - 8:00 AM",
      "4:00 PM - 5:00 PM",
      "5:00 PM - 6:00 PM",
      "6:00 PM - 7:00 PM",
    ],
    maxCapacity: 20,
    allowMultipleBookings: true,
    bookingDurations: ["1 hour"],
  },
  {
    id: "demo-amenity-ev-charging",
    key: "ev-charging",
    buildingKey: "pulse",
    name: "EV Charging Bay",
    type: "Facility",
    description:
      "Reservable EV charging bays. Booking access is free; electricity billing is handled separately.",
    iconName: "parking",
    isFree: true,
    pricingMode: "free",
    pricePerDay: 0,
    timeSlots: [
      "6:00 AM - 8:00 AM",
      "8:00 AM - 10:00 AM",
      "6:00 PM - 8:00 PM",
      "8:00 PM - 10:00 PM",
    ],
    maxCapacity: 2,
    allowMultipleBookings: true,
    bookingDurations: ["2 hours"],
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

  const seedAdmin = await db
    .collection("admins")
    .doc(SEED_ADMIN.uid)
    .get();

  if (
    !seedAdmin.exists ||
    seedAdmin.data()?.role !== "admin" ||
    seedAdmin.data()?.isActive !== true ||
    seedAdmin.data()?.isDemoData !== true ||
    seedAdmin.data()?.seedBatch !== SEED_BATCH
  ) {
    throw new Error(
      "Expected Green Wave seed admin was not found."
    );
  }
}

async function loadBuildings(db) {
  const snapshot = await db
    .collection("buildings")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const result = {};

  for (const key of Object.keys(BUILDING_NAMES)) {
    const expectedName = BUILDING_NAMES[key];

    const matches = snapshot.docs.filter((doc) => {
      const data = doc.data();

      return (
        data.isDemoData === true &&
        data.seedBatch === SEED_BATCH &&
        data.seedKey === `building:${key}` &&
        (data.name === expectedName ||
          data.buildingName === expectedName)
      );
    });

    if (matches.length !== 1) {
      throw new Error(
        `Expected exactly one demo building for ${expectedName}; found ${matches.length}.`
      );
    }

    result[key] = {
      id: matches[0].id,
      name: expectedName,
    };
  }

  return result;
}

function buildPlan(buildings) {
  const createdAt = timestamp(
    istDate(2026, 4, 15, 10, 0)
  );

  return AMENITIES.map((definition) => {
    const building =
      buildings[definition.buildingKey];

    if (!building) {
      throw new Error(
        `Building unavailable for ${definition.name}.`
      );
    }

    return {
      id: definition.id,
      data: {
        name: definition.name,
        type: definition.type,
        description: definition.description,
        iconName: definition.iconName,

        imageUrl: null,
        images: [],

        isAvailable: true,

        isFree: definition.isFree,
        pricingMode: definition.pricingMode,
        pricePerDay: definition.pricePerDay,

        timeSlots: definition.timeSlots,
        maxCapacity: definition.maxCapacity,
        allowMultipleBookings:
          definition.allowMultipleBookings,
        bookingDurations:
          definition.bookingDurations,

        hasSubscriptionPackages: false,
        subscriptionPackages: {},

        buildingId: building.id,
        buildingName: building.name,

        communityId: COMMUNITY_ID,

        adminId: SEED_ADMIN.uid,
        adminName: SEED_ADMIN.name,
        adminEmail: "",
        organization: "",

        authorId: SEED_ADMIN.uid,
        authorName: SEED_ADMIN.name,

        createdAt,
        updatedAt: createdAt,

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey:
          `amenity:${definition.key}`,
      },
    };
  });
}

function arraysEqual(a, b) {
  return (
    Array.isArray(a) &&
    Array.isArray(b) &&
    a.length === b.length &&
    a.every((value, index) => value === b[index])
  );
}

function assertExisting(snapshot, item) {
  if (!snapshot.exists) return;

  const actual = snapshot.data() || {};
  const expected = item.data;

  if (
    actual.communityId !== COMMUNITY_ID ||
    actual.isDemoData !== true ||
    actual.seedBatch !== SEED_BATCH ||
    actual.seedVersion !== SEED_VERSION ||
    actual.seedKey !== expected.seedKey ||
    actual.name !== expected.name ||
    actual.type !== expected.type ||
    actual.buildingId !== expected.buildingId ||
    actual.buildingName !== expected.buildingName ||
    actual.isAvailable !== true ||
    actual.isFree !== expected.isFree ||
    actual.pricingMode !== expected.pricingMode ||
    Number(actual.pricePerDay) !==
      Number(expected.pricePerDay) ||
    actual.maxCapacity !== expected.maxCapacity ||
    actual.allowMultipleBookings !==
      expected.allowMultipleBookings ||
    !arraysEqual(
      actual.timeSlots,
      expected.timeSlots
    ) ||
    !arraysEqual(
      actual.bookingDurations,
      expected.bookingDurations
    )
  ) {
    throw new Error(
      `Conflicting facility exists at amenities/${snapshot.id}.`
    );
  }
}

async function refuseDuplicateNames(db, plan) {
  const snapshot = await db
    .collection("amenities")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  for (const item of plan) {
    const duplicates = snapshot.docs.filter(
      (doc) =>
        doc.id !== item.id &&
        doc.data()?.name === item.data.name
    );

    if (duplicates.length > 0) {
      throw new Error(
        `Refusing duplicate facility name "${item.data.name}". Existing IDs: ${duplicates
          .map((doc) => doc.id)
          .join(", ")}`
      );
    }
  }
}

async function findMissing(db, plan) {
  const missing = [];

  for (const item of plan) {
    const snapshot = await db
      .collection("amenities")
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
        db.collection("amenities").doc(item.id),
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

    await sleep(1500);

    const remaining =
      await findMissing(db, missing);

    if (remaining.length === 0) {
      console.log(
        "[RECOVERED] Facility batch committed despite timeout."
      );
      return missing.length;
    }

    if (remaining.length !== missing.length) {
      throw new Error(
        "Unexpected partial facility batch state."
      );
    }

    await commit();

    return missing.length;
  }
}

async function validateFinal(db, plan) {
  const snapshot = await db
    .collection("amenities")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const docs = snapshot.docs.filter((doc) => {
    const data = doc.data();

    return (
      data.isDemoData === true &&
      data.seedBatch === SEED_BATCH &&
      typeof data.seedKey === "string" &&
      data.seedKey.startsWith("amenity:")
    );
  });

  let available = 0;
  let free = 0;
  let paid = 0;

  const types = {};

  for (const doc of docs) {
    const data = doc.data();

    if (data.isAvailable === true) {
      available += 1;
    }

    if (data.isFree === true) {
      free += 1;
    } else {
      paid += 1;
    }

    types[data.type] =
      (types[data.type] || 0) + 1;

    if (
      !Array.isArray(data.timeSlots) ||
      data.timeSlots.length === 0
    ) {
      throw new Error(
        `${doc.id} has no booking slots.`
      );
    }

    if (
      !data.buildingId ||
      !data.buildingName
    ) {
      throw new Error(
        `${doc.id} has incomplete building references.`
      );
    }
  }

  console.log(
    "\n===== GREEN WAVE FACILITY SUMMARY ====="
  );

  console.log(`Facilities:  ${docs.length}`);
  console.log(`Available:   ${available}`);
  console.log(`Free:        ${free}`);
  console.log(`Chargeable:  ${paid}`);
  console.log(
    `Facility:    ${types.Facility || 0}`
  );
  console.log(
    `Sports:      ${types.Sports || 0}`
  );
  console.log(
    `Event:       ${types.Event || 0}`
  );
  console.log(
    `Recreation:  ${types.Recreation || 0}`
  );

  if (
    docs.length !== 6 ||
    available !== 6 ||
    free !== 4 ||
    paid !== 2 ||
    types.Facility !== 2 ||
    types.Sports !== 2 ||
    types.Event !== 1 ||
    types.Recreation !== 1
  ) {
    throw new Error(
      "Facility totals do not match the expected Green Wave dataset."
    );
  }

  for (const item of plan) {
    const doc = await db
      .collection("amenities")
      .doc(item.id)
      .get();

    assertExisting(doc, item);
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

  const buildings =
    await loadBuildings(db);

  const plan =
    buildPlan(buildings);

  await refuseDuplicateNames(db, plan);

  const missing =
    await findMissing(db, plan);

  console.log(
    "===== HOMINODE DEMO FACILITIES ====="
  );

  console.log(`Project:       ${projectId}`);
  console.log(`Community:     ${COMMUNITY_ID}`);
  console.log(`Seed batch:    ${SEED_BATCH}`);
  console.log(
    `Mode:          ${apply ? "APPLY" : "DRY RUN"}`
  );

  console.log("");
  console.log("Facilities:       6");
  console.log("Available:        6");
  console.log("Free:             4");
  console.log("Chargeable:       2");
  console.log("Buildings:        4");
  console.log(
    `Missing docs:    ${missing.length}`
  );

  if (!apply) {
    console.log(
      "\nNo Firestore writes performed."
    );
    return;
  }

  const writes =
    await writeMissing(db, missing);

  console.log(
    `\n[OK] Facility seed reconciled (${writes} writes).`
  );

  await validateFinal(db, plan);

  console.log(
    "\nDemo facility seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo facility seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
