#!/usr/bin/env node

const admin = require("firebase-admin");
const { createHash } = require("node:crypto");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const EXPECTED_TIME_ZONES = new Set([
  "Asia/Calcutta",
  "Asia/Kolkata",
]);

const MONTHS = [
  { year: 2026, month: 5, label: "2026-05" },
  { year: 2026, month: 6, label: "2026-06" },
  { year: 2026, month: 7, label: "2026-07" },
  { year: 2026, month: 8, label: "2026-08" },
  { year: 2026, month: 9, label: "2026-09" },
  { year: 2026, month: 10, label: "2026-10" },
];

const AMENITY_IDS = [
  "demo-amenity-coworking-lounge",
  "demo-amenity-rooftop-fitness",
  "demo-amenity-multipurpose-hall",
  "demo-amenity-badminton-court",
  "demo-amenity-swimming-pool",
  "demo-amenity-ev-charging",
];

const EXPECTED_AMENITIES = {
  "demo-amenity-coworking-lounge": {
    name: "Co-working Lounge",
    pricePerDay: 0,
  },
  "demo-amenity-rooftop-fitness": {
    name: "Rooftop Fitness",
    pricePerDay: 0,
  },
  "demo-amenity-multipurpose-hall": {
    name: "Multipurpose Hall",
    pricePerDay: 1500,
  },
  "demo-amenity-badminton-court": {
    name: "Badminton Court",
    pricePerDay: 250,
  },
  "demo-amenity-swimming-pool": {
    name: "Swimming Pool",
    pricePerDay: 0,
  },
  "demo-amenity-ev-charging": {
    name: "EV Charging Bay",
    pricePerDay: 0,
  },
};

const CANCELLATION_REASONS = [
  "Resident plans changed.",
  "Schedule changed.",
  "Booking no longer required.",
  "Resident cancelled the reservation.",
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

function pad2(value) {
  return String(value).padStart(2, "0");
}

function localDateKey(year, month, day) {
  return `${year}-${pad2(month)}-${pad2(day)}`;
}

function istDate(year, month, day, hour = 0, minute = 0) {
  return new Date(
    Date.UTC(year, month - 1, day, hour, minute) -
      330 * 60 * 1000
  );
}

function timestamp(date) {
  return admin.firestore.Timestamp.fromDate(date);
}

function addHours(date, hours) {
  return new Date(
    date.getTime() + hours * 60 * 60 * 1000
  );
}

function addDays(date, days) {
  return addHours(date, days * 24);
}

function bookingDayKey(communityId, amenityId, dateKey) {
  return createHash("sha256")
    .update(
      JSON.stringify([
        communityId,
        amenityId,
        dateKey,
      ])
    )
    .digest("hex");
}

function bookingSlotKey(dayKey, timeSlot) {
  return createHash("sha256")
    .update(
      JSON.stringify([
        dayKey,
        timeSlot,
      ])
    )
    .digest("hex");
}

function timestampMillis(value) {
  return value?.toMillis?.() ?? null;
}

async function requireEnvironment(db) {
  const snapshot = await db
    .collection("communities")
    .doc(COMMUNITY_ID)
    .get();

  const data = snapshot.data() || {};

  if (
    !snapshot.exists ||
    data.isActive !== true ||
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH
  ) {
    throw new Error(
      "Expected active Green Wave demo community was not found."
    );
  }

  const timeZone =
    typeof data.timeZone === "string"
      ? data.timeZone.trim()
      : "";

  if (!EXPECTED_TIME_ZONES.has(timeZone)) {
    throw new Error(
      `Unexpected Green Wave timezone: ${timeZone || "(missing)"}`
    );
  }

  return { timeZone };
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
        data.isActive === true &&
        data.status === "active" &&
        data.occupancyStatus === "current" &&
        typeof data.flatId === "string" &&
        data.flatId.trim().length > 0 &&
        typeof data.buildingId === "string" &&
        data.buildingId.trim().length > 0
      );
    })
    .sort((a, b) =>
      String(a.data.seedKey || a.id).localeCompare(
        String(b.data.seedKey || b.id)
      )
    );

  if (residents.length !== 48) {
    throw new Error(
      `Expected 48 active/current residents; found ${residents.length}.`
    );
  }

  return residents;
}

async function loadAmenities(db) {
  const result = new Map();

  for (const amenityId of AMENITY_IDS) {
    const snapshot = await db
      .collection("amenities")
      .doc(amenityId)
      .get();

    if (!snapshot.exists) {
      throw new Error(
        `Expected facility ${amenityId} was not found.`
      );
    }

    const data = snapshot.data() || {};
    const expected = EXPECTED_AMENITIES[amenityId];

    if (
      data.communityId !== COMMUNITY_ID ||
      data.isDemoData !== true ||
      data.seedBatch !== SEED_BATCH ||
      data.name !== expected.name ||
      data.isAvailable !== true ||
      !Array.isArray(data.timeSlots) ||
      data.timeSlots.length === 0 ||
      !Number.isInteger(data.maxCapacity) ||
      data.maxCapacity <= 0 ||
      Number(data.pricePerDay) !==
        expected.pricePerDay
    ) {
      throw new Error(
        `Facility ${amenityId} does not match the expected demo contract.`
      );
    }

    result.set(amenityId, {
      id: amenityId,
      ...data,
    });
  }

  return result;
}

function peopleFor(amenity, sequence) {
  switch (amenity.id) {
    case "demo-amenity-coworking-lounge":
      return 1 + (sequence % 3);

    case "demo-amenity-rooftop-fitness":
      return 1 + (sequence % 2);

    case "demo-amenity-multipurpose-hall":
      return 12 + ((sequence * 3) % 19);

    case "demo-amenity-badminton-court":
      return 2 + (sequence % 3);

    case "demo-amenity-swimming-pool":
      return 2 + (sequence % 4);

    case "demo-amenity-ev-charging":
      return 1;

    default:
      return 1;
  }
}

function dayFor(month, itemIndex) {
  if (month.month === 10) {
    return [2, 4, 8, 10][itemIndex];
  }

  return [4, 10, 16, 22][itemIndex];
}

function buildPlan({
  residents,
  amenities,
  timeZone,
}) {
  const plan = [];

  let sequence = 0;
  let cancellationIndex = 0;

  for (
    let monthIndex = 0;
    monthIndex < MONTHS.length;
    monthIndex += 1
  ) {
    const month = MONTHS[monthIndex];

    for (
      let itemIndex = 0;
      itemIndex < 4;
      itemIndex += 1
    ) {
      sequence += 1;

      const amenityId =
        AMENITY_IDS[(sequence - 1) % AMENITY_IDS.length];

      const amenity =
        amenities.get(amenityId);

      if (!amenity) {
        throw new Error(
          `Missing loaded facility ${amenityId}.`
        );
      }

      const resident =
        residents[
          (sequence * 7 + monthIndex * 3) %
            residents.length
        ];

      const day =
        dayFor(month, itemIndex);

      const dateKey =
        localDateKey(
          month.year,
          month.month,
          day
        );

      const bookingDate =
        istDate(
          month.year,
          month.month,
          day,
          0,
          0
        );

      const timeSlot =
        amenity.timeSlots[
          (sequence + itemIndex) %
            amenity.timeSlots.length
        ];

      const dayKey =
        bookingDayKey(
          COMMUNITY_ID,
          amenity.id,
          dateKey
        );

      const slotKey =
        bookingSlotKey(
          dayKey,
          timeSlot
        );

      const cancelled =
        sequence % 6 === 0;

      const createdAt =
        addDays(
          bookingDate,
          -(2 + (sequence % 5))
        );

      const cancellationDate =
        cancelled
          ? addHours(
              createdAt,
              8 + (sequence % 12)
            )
          : null;

      const numberOfPeople =
        peopleFor(
          amenity,
          sequence
        );

      if (
        numberOfPeople >
        amenity.maxCapacity
      ) {
        throw new Error(
          `${amenity.name}: planned people exceed capacity.`
        );
      }

      const pricePerDay =
        Number(amenity.pricePerDay) || 0;

      const price = pricePerDay;

      const bookingData = {
        userId: resident.id,
        userName:
          resident.data.name ||
          resident.data.fullName ||
          "Resident",
        userEmail:
          typeof resident.data.email === "string"
            ? resident.data.email
            : "",

        flatId: resident.data.flatId,
        flatLabel:
          resident.data.flatLabel ||
          resident.data.flatNumber ||
          resident.data.flatId,
        buildingId:
          resident.data.buildingId,
        organizationId:
          resident.data.organizationId || null,

        communityId: COMMUNITY_ID,

        amenityId: amenity.id,
        amenityName: amenity.name,

        bookingType: "daily",
        packageType: null,

        date: timestamp(bookingDate),
        bookingDateKey: dateKey,
        bookingDayKey: dayKey,
        bookingSlotKey: slotKey,
        bookingTimeZone: timeZone,
        timeSlot,

        subscriptionStartDate:
          timestamp(bookingDate),
        subscriptionEndDate:
          timestamp(bookingDate),
        validityDays: 1,

        numberOfPeople,

        price,
        pricePerDay,

        status:
          cancelled
            ? "cancelled"
            : "confirmed",

        cancellationDate:
          cancellationDate == null
            ? null
            : timestamp(cancellationDate),

        cancellationReason:
          cancelled
            ? CANCELLATION_REASONS[
                cancellationIndex++ %
                  CANCELLATION_REASONS.length
              ]
            : null,

        createdAt:
          timestamp(createdAt),

        updatedAt:
          timestamp(
            cancellationDate ||
              createdAt
          ),

        adminId:
          amenity.adminId || "demo-admin-green-wave",

        ...(amenity.adminName
          ? { adminName: amenity.adminName }
          : {}),

        ...(amenity.adminEmail
          ? { adminEmail: amenity.adminEmail }
          : {}),

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey:
          `booking:${month.label}:` +
          `${pad2(itemIndex + 1)}`,
      };

      const slotData = {
        communityId: COMMUNITY_ID,
        amenityId: amenity.id,
        bookingDateKey: dateKey,
        timeSlot,

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey:
          `booking-slot:${month.label}:` +
          `${pad2(itemIndex + 1)}`,

        updatedAt:
          timestamp(createdAt),
      };

      plan.push({
        id:
          `demo-booking-${month.label}-` +
          `${pad2(itemIndex + 1)}`,
        monthLabel: month.label,
        amenityId: amenity.id,
        slotId: slotKey,
        bookingData,
        slotData,
      });
    }
  }

  const confirmed =
    plan.filter(
      (item) =>
        item.bookingData.status === "confirmed"
    ).length;

  const cancelled =
    plan.filter(
      (item) =>
        item.bookingData.status === "cancelled"
    ).length;

  if (
    plan.length !== 24 ||
    confirmed !== 20 ||
    cancelled !== 4
  ) {
    throw new Error(
      `Unexpected booking plan: total=${plan.length}, confirmed=${confirmed}, cancelled=${cancelled}.`
    );
  }

  const slotIds =
    new Set(plan.map((item) => item.slotId));

  if (slotIds.size !== plan.length) {
    throw new Error(
      "Planned booking slot collision detected."
    );
  }

  return plan;
}

function assertBookingExisting(
  snapshot,
  item
) {
  if (!snapshot.exists) return;

  const actual =
    snapshot.data() || {};

  const expected =
    item.bookingData;

  if (
    actual.communityId !== COMMUNITY_ID ||
    actual.isDemoData !== true ||
    actual.seedBatch !== SEED_BATCH ||
    actual.seedVersion !== SEED_VERSION ||
    actual.seedKey !== expected.seedKey ||
    actual.userId !== expected.userId ||
    actual.flatId !== expected.flatId ||
    actual.buildingId !== expected.buildingId ||
    actual.amenityId !== expected.amenityId ||
    actual.amenityName !== expected.amenityName ||
    actual.bookingType !== "daily" ||
    actual.bookingDateKey !==
      expected.bookingDateKey ||
    actual.bookingDayKey !==
      expected.bookingDayKey ||
    actual.bookingSlotKey !==
      expected.bookingSlotKey ||
    actual.bookingTimeZone !==
      expected.bookingTimeZone ||
    actual.timeSlot !== expected.timeSlot ||
    Number(actual.numberOfPeople) !==
      Number(expected.numberOfPeople) ||
    Number(actual.price) !==
      Number(expected.price) ||
    Number(actual.pricePerDay) !==
      Number(expected.pricePerDay) ||
    actual.status !== expected.status ||
    timestampMillis(actual.date) !==
      timestampMillis(expected.date)
  ) {
    throw new Error(
      `Conflicting booking exists at bookings/${snapshot.id}.`
    );
  }

  if (
    expected.status === "cancelled" &&
    timestampMillis(
      actual.cancellationDate
    ) !==
      timestampMillis(
        expected.cancellationDate
      )
  ) {
    throw new Error(
      `Cancellation timestamp differs at bookings/${snapshot.id}.`
    );
  }

  if (
    expected.status === "confirmed" &&
    actual.cancellationDate != null
  ) {
    throw new Error(
      `Confirmed booking unexpectedly has cancellationDate at bookings/${snapshot.id}.`
    );
  }
}

function assertSlotExisting(
  snapshot,
  item
) {
  if (!snapshot.exists) return;

  const actual =
    snapshot.data() || {};

  const expected =
    item.slotData;

  if (
    actual.communityId !== COMMUNITY_ID ||
    actual.amenityId !== expected.amenityId ||
    actual.bookingDateKey !==
      expected.bookingDateKey ||
    actual.timeSlot !== expected.timeSlot ||
    actual.isDemoData !== true ||
    actual.seedBatch !== SEED_BATCH ||
    actual.seedVersion !== SEED_VERSION ||
    actual.seedKey !== expected.seedKey
  ) {
    throw new Error(
      `Conflicting booking slot exists at amenityBookingSlots/${snapshot.id}.`
    );
  }
}

async function refuseOperationalCollisions(
  db,
  plan
) {
  const snapshot = await db
    .collection("bookings")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const targetIds =
    new Set(
      plan.map((item) => item.id)
    );

  const targetSlotKeys =
    new Set(
      plan.map(
        (item) =>
          item.bookingData.bookingSlotKey
      )
    );

  for (const doc of snapshot.docs) {
    if (targetIds.has(doc.id)) {
      continue;
    }

    const data =
      doc.data() || {};

    if (
      typeof data.bookingSlotKey === "string" &&
      targetSlotKeys.has(
        data.bookingSlotKey
      )
    ) {
      throw new Error(
        `Refusing seed: existing booking ${doc.id} already occupies a planned demo slot.`
      );
    }
  }

  return snapshot.docs.length;
}

async function findMissing(
  db,
  plan
) {
  const missingBookings = [];
  const missingSlots = [];

  for (const item of plan) {
    const bookingSnapshot =
      await db
        .collection("bookings")
        .doc(item.id)
        .get();

    assertBookingExisting(
      bookingSnapshot,
      item
    );

    if (!bookingSnapshot.exists) {
      missingBookings.push(item);
    }

    const slotSnapshot =
      await db
        .collection(
          "amenityBookingSlots"
        )
        .doc(item.slotId)
        .get();

    assertSlotExisting(
      slotSnapshot,
      item
    );

    if (!slotSnapshot.exists) {
      missingSlots.push(item);
    }
  }

  return {
    missingBookings,
    missingSlots,
  };
}

async function writeMissing(
  db,
  missing
) {
  const totalWrites =
    missing.missingBookings.length +
    missing.missingSlots.length;

  if (totalWrites === 0) {
    return {
      bookingWrites: 0,
      slotWrites: 0,
    };
  }

  const commit = async () => {
    const batch =
      db.batch();

    for (
      const item of
      missing.missingSlots
    ) {
      batch.create(
        db
          .collection(
            "amenityBookingSlots"
          )
          .doc(item.slotId),
        item.slotData
      );
    }

    for (
      const item of
      missing.missingBookings
    ) {
      batch.create(
        db
          .collection("bookings")
          .doc(item.id),
        item.bookingData
      );
    }

    await batch.commit();
  };

  try {
    await commit();

    return {
      bookingWrites:
        missing.missingBookings.length,
      slotWrites:
        missing.missingSlots.length,
    };
  } catch (error) {
    if (!transient(error)) {
      throw error;
    }

    await sleep(2000);

    const remaining =
      await findMissing(
        db,
        [
          ...new Map(
            [
              ...missing.missingBookings,
              ...missing.missingSlots,
            ].map((item) => [
              item.id,
              item,
            ])
          ).values(),
        ]
      );

    if (
      remaining.missingBookings.length === 0 &&
      remaining.missingSlots.length === 0
    ) {
      console.log(
        "[RECOVERED] Booking batch committed despite client timeout."
      );

      return {
        bookingWrites:
          missing.missingBookings.length,
        slotWrites:
          missing.missingSlots.length,
      };
    }

    if (
      remaining.missingBookings.length !==
        missing.missingBookings.length ||
      remaining.missingSlots.length !==
        missing.missingSlots.length
    ) {
      throw new Error(
        "Unexpected partial booking batch state."
      );
    }

    await commit();

    return {
      bookingWrites:
        missing.missingBookings.length,
      slotWrites:
        missing.missingSlots.length,
    };
  }
}

async function validateFinal(
  db,
  plan
) {
  const snapshot = await db
    .collection("bookings")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const docs =
    snapshot.docs.filter((doc) => {
      const data =
        doc.data();

      return (
        data.isDemoData === true &&
        data.seedBatch === SEED_BATCH &&
        data.seedVersion === SEED_VERSION &&
        typeof data.seedKey === "string" &&
        data.seedKey.startsWith(
          "booking:"
        )
      );
    });

  let confirmed = 0;
  let cancelled = 0;
  let totalPrice = 0;

  const months = {};
  const facilities = {};

  for (const doc of docs) {
    const data =
      doc.data();

    if (
      data.status === "confirmed"
    ) {
      confirmed += 1;

      if (
        data.cancellationDate != null
      ) {
        throw new Error(
          `${doc.id} is confirmed but has cancellationDate.`
        );
      }
    } else if (
      data.status === "cancelled"
    ) {
      cancelled += 1;

      if (
        data.cancellationDate == null
      ) {
        throw new Error(
          `${doc.id} is cancelled but has no cancellationDate.`
        );
      }
    } else {
      throw new Error(
        `Unexpected booking status at ${doc.id}: ${data.status}`
      );
    }

    if (
      data.bookingType !== "daily" ||
      data.validityDays !== 1 ||
      data.bookingTimeZone == null ||
      data.bookingDateKey == null ||
      data.bookingDayKey == null ||
      data.bookingSlotKey == null
    ) {
      throw new Error(
        `${doc.id} is missing canonical booking fields.`
      );
    }

    totalPrice +=
      Number(data.price) || 0;

    months[
      data.bookingDateKey.slice(0, 7)
    ] =
      (months[
        data.bookingDateKey.slice(0, 7)
      ] || 0) + 1;

    facilities[data.amenityId] =
      (facilities[data.amenityId] || 0) +
      1;
  }

  console.log(
    "\n===== GREEN WAVE BOOKING SUMMARY ====="
  );

  console.log(
    `Bookings:   ${docs.length}`
  );
  console.log(
    `Confirmed:  ${confirmed}`
  );
  console.log(
    `Cancelled:  ${cancelled}`
  );
  console.log(
    `Price total: ₹${totalPrice}`
  );

  console.log("");

  for (const month of MONTHS) {
    console.log(
      `${month.label}: ${months[month.label] || 0}`
    );
  }

  console.log("");

  for (const amenityId of AMENITY_IDS) {
    console.log(
      `${EXPECTED_AMENITIES[amenityId].name}: ` +
        `${facilities[amenityId] || 0}`
    );
  }

  if (
    docs.length !== 24 ||
    confirmed !== 20 ||
    cancelled !== 4
  ) {
    throw new Error(
      "Booking totals do not match the expected Green Wave dataset."
    );
  }

  for (const month of MONTHS) {
    if (
      months[month.label] !== 4
    ) {
      throw new Error(
        `Expected 4 bookings in ${month.label}.`
      );
    }
  }

  for (const amenityId of AMENITY_IDS) {
    if (
      facilities[amenityId] !== 4
    ) {
      throw new Error(
        `Expected 4 bookings for ${EXPECTED_AMENITIES[amenityId].name}.`
      );
    }
  }

  for (const item of plan) {
    const bookingSnapshot =
      await db
        .collection("bookings")
        .doc(item.id)
        .get();

    assertBookingExisting(
      bookingSnapshot,
      item
    );

    const slotSnapshot =
      await db
        .collection(
          "amenityBookingSlots"
        )
        .doc(item.slotId)
        .get();

    assertSlotExisting(
      slotSnapshot,
      item
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

  if (
    projectId !== "hominode-prod"
  ) {
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

  const { timeZone } =
    await requireEnvironment(db);

  const residents =
    await loadResidents(db);

  const amenities =
    await loadAmenities(db);

  const plan =
    buildPlan({
      residents,
      amenities,
      timeZone,
    });

  const existingCommunityBookings =
    await refuseOperationalCollisions(
      db,
      plan
    );

  const missing =
    await findMissing(
      db,
      plan
    );

  console.log(
    "===== HOMINODE DEMO FACILITY BOOKINGS ====="
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
    `Eligible residents:       ${residents.length}`
  );
  console.log(
    `Facilities:               ${amenities.size}`
  );
  console.log(
    "Planned bookings:         24"
  );
  console.log(
    "Confirmed:                20"
  );
  console.log(
    "Cancelled:                 4"
  );
  console.log(
    "Months:              May-Oct 2026"
  );
  console.log(
    `Existing community bookings: ${existingCommunityBookings}`
  );
  console.log(
    `Missing booking docs:     ${missing.missingBookings.length}`
  );
  console.log(
    `Missing slot docs:        ${missing.missingSlots.length}`
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
    `\n[OK] Booking seed reconciled ` +
      `(${writes.bookingWrites} booking writes, ` +
      `${writes.slotWrites} slot writes).`
  );

  await validateFinal(
    db,
    plan
  );

  console.log(
    "\nDemo facility booking seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo facility booking seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
