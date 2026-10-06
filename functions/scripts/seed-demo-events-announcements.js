#!/usr/bin/env node

const admin = require("firebase-admin");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN = {
  uid: "demo-admin-green-wave",
  name: "Maya Rao",
};

const MONTHS = [
  {
    label: "2026-05",
    year: 2026,
    month: 5,
    eventDay: 24,
    event: {
      title: "Summer Wellness Morning",
      category: "Wellness",
      description:
        "A community wellness morning with guided stretching, mobility exercises, and healthy-living tips.",
      priority: "medium",
      time: "7:00 AM",
      location: "Rooftop Fitness",
      status: "completed",
      rsvpCount: 28,
      totalCapacity: 50,
    },
    announcement: {
      title: "Water Tank Preventive Maintenance",
      category: "Maintenance",
      priority: "medium",
      description:
        "Preventive water tank cleaning and inspection will be carried out in scheduled phases.",
      status: "archived",
    },
  },
  {
    label: "2026-06",
    year: 2026,
    month: 6,
    eventDay: 21,
    event: {
      title: "EV & Sustainable Mobility Clinic",
      category: "Sustainability",
      description:
        "An interactive resident session covering EV charging etiquette, battery care, and sustainable mobility.",
      priority: "medium",
      time: "10:30 AM",
      location: "Multipurpose Hall",
      status: "completed",
      rsvpCount: 34,
      totalCapacity: 60,
    },
    announcement: {
      title: "EV Charging Bay Usage Guidelines",
      category: "Sustainability",
      priority: "low",
      description:
        "Residents are requested to follow the updated EV charging bay booking and usage guidelines.",
      status: "archived",
    },
  },
  {
    label: "2026-07",
    year: 2026,
    month: 7,
    eventDay: 19,
    event: {
      title: "Monsoon Safety & Smart Access Workshop",
      category: "Safety",
      description:
        "A resident awareness workshop covering monsoon preparedness, emergency response, and smart access safety.",
      priority: "high",
      time: "5:30 PM",
      location: "Multipurpose Hall",
      status: "completed",
      rsvpCount: 42,
      totalCapacity: 80,
    },
    announcement: {
      title: "Monsoon Safety Advisory",
      category: "Safety",
      priority: "high",
      description:
        "Please use designated walkways during heavy rain and report waterlogging or electrical hazards immediately.",
      status: "archived",
    },
  },
  {
    label: "2026-08",
    year: 2026,
    month: 8,
    eventDay: 16,
    event: {
      title: "Independence Weekend Community Meetup",
      category: "Community",
      description:
        "A relaxed community gathering for residents and families with activities and refreshments.",
      priority: "medium",
      time: "5:00 PM",
      location: "Multipurpose Hall",
      status: "completed",
      rsvpCount: 55,
      totalCapacity: 100,
    },
    announcement: {
      title: "Parcel Locker Pilot Now Available",
      category: "Services",
      priority: "medium",
      description:
        "The Green Wave smart parcel locker pilot is now available for supported deliveries.",
      status: "active",
    },
  },
  {
    label: "2026-09",
    year: 2026,
    month: 9,
    eventDay: 20,
    event: {
      title: "Resident Badminton Social",
      category: "Sports",
      description:
        "A friendly badminton evening for residents with rotating doubles matches and casual play.",
      priority: "low",
      time: "6:00 PM",
      location: "Badminton Court",
      status: "completed",
      rsvpCount: 24,
      totalCapacity: 32,
    },
    announcement: {
      title: "Co-working Lounge Quiet Hours",
      category: "Facilities",
      priority: "low",
      description:
        "Quiet working hours are now observed in the co-working lounge on weekday mornings.",
      status: "active",
    },
  },
  {
    label: "2026-10",
    year: 2026,
    month: 10,
    eventDay: 10,
    event: {
      title: "Rooftop Fitness & Wellness Session",
      category: "Wellness",
      description:
        "Join a guided rooftop fitness session focused on mobility, conditioning, and healthy routines.",
      priority: "medium",
      time: "7:00 AM",
      location: "Rooftop Fitness",
      status: "upcoming",
      rsvpCount: 18,
      totalCapacity: 40,
    },
    announcement: {
      title: "Festival Week Security & Visitor Advisory",
      category: "Security",
      priority: "high",
      description:
        "Residents are requested to pre-register expected guests and cooperate with enhanced gate checks during festival week.",
      status: "active",
    },
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

function istDate(year, month, day, hour = 0, minute = 0) {
  return new Date(
    Date.UTC(year, month - 1, day, hour, minute) -
      330 * 60 * 1000
  );
}

function ts(date) {
  return admin.firestore.Timestamp.fromDate(date);
}

function millis(value) {
  return value?.toMillis?.() ?? null;
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

function buildPlan() {
  const plan = [];

  for (const month of MONTHS) {
    const eventDate = istDate(
      month.year,
      month.month,
      month.eventDay,
      9,
      0
    );

    const eventCreatedAt = istDate(
      month.year,
      month.month,
      Math.max(1, month.eventDay - 12),
      10,
      0
    );

    const eventUpdatedAt =
      month.event.status === "completed"
        ? new Date(eventDate.getTime() + 4 * 60 * 60 * 1000)
        : eventCreatedAt;

    plan.push({
      id: `demo-event-${month.label}`,
      monthLabel: month.label,
      data: {
        type: "event",

        title: month.event.title,
        category: month.event.category,
        description: month.event.description,
        priority: month.event.priority,

        date: ts(eventDate),
        eventDate: ts(eventDate),

        time: month.event.time,
        location: month.event.location,

        rsvpCount: month.event.rsvpCount,
        totalCapacity: month.event.totalCapacity,

        imageUrl: null,
        imageUrls: [],
        images: [],
        localImagePath: null,

        status: month.event.status,

        adminId: SEED_ADMIN.uid,
        adminName: SEED_ADMIN.name,
        adminEmail: "",
        adminPhone: "",
        organization: "",

        authorId: SEED_ADMIN.uid,
        authorName: SEED_ADMIN.name,

        communityId: COMMUNITY_ID,

        createdAt: ts(eventCreatedAt),
        updatedAt: ts(eventUpdatedAt),

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey: `publication:event:${month.label}`,
      },
    });

    const announcementCreatedAt = istDate(
      month.year,
      month.month,
      3,
      9,
      30
    );

    const announcementUpdatedAt =
      month.announcement.status === "archived"
        ? istDate(
            month.year,
            month.month,
            27,
            18,
            0
          )
        : announcementCreatedAt;

    plan.push({
      id: `demo-announcement-${month.label}`,
      monthLabel: month.label,
      data: {
        type: "announcement",

        title: month.announcement.title,
        category: month.announcement.category,
        priority: month.announcement.priority,
        description: month.announcement.description,

        status: month.announcement.status,

        adminId: SEED_ADMIN.uid,
        adminName: SEED_ADMIN.name,
        adminEmail: "",
        adminPhone: "",
        organization: "",

        authorId: SEED_ADMIN.uid,
        authorName: SEED_ADMIN.name,

        communityId: COMMUNITY_ID,

        createdAt: ts(announcementCreatedAt),
        updatedAt: ts(announcementUpdatedAt),

        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey: `publication:announcement:${month.label}`,
      },
    });
  }

  if (plan.length !== 12) {
    throw new Error(
      `Expected 12 publication records; planned ${plan.length}.`
    );
  }

  return plan;
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
    actual.type !== expected.type ||
    actual.title !== expected.title ||
    actual.category !== expected.category ||
    actual.priority !== expected.priority ||
    actual.description !== expected.description ||
    actual.status !== expected.status ||
    actual.adminId !== expected.adminId
  ) {
    throw new Error(
      `Conflicting publication exists at events_announcements/${snapshot.id}.`
    );
  }

  if (expected.type === "event") {
    if (
      millis(actual.date) !== millis(expected.date) ||
      millis(actual.eventDate) !== millis(expected.eventDate) ||
      actual.time !== expected.time ||
      actual.location !== expected.location ||
      Number(actual.rsvpCount) !== Number(expected.rsvpCount) ||
      Number(actual.totalCapacity) !== Number(expected.totalCapacity)
    ) {
      throw new Error(
        `Event details differ at events_announcements/${snapshot.id}.`
      );
    }
  }
}

async function refuseDuplicates(db, plan) {
  const snapshot = await db
    .collection("events_announcements")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  for (const item of plan) {
    const duplicate = snapshot.docs.find((doc) => {
      if (doc.id === item.id) return false;

      const data = doc.data() || {};

      return (
        data.title === item.data.title ||
        data.seedKey === item.data.seedKey
      );
    });

    if (duplicate) {
      throw new Error(
        `Refusing duplicate publication "${item.data.title}" at ${duplicate.id}.`
      );
    }
  }

  return snapshot.docs.length;
}

async function findMissing(db, plan) {
  const missing = [];

  for (const item of plan) {
    const snapshot = await db
      .collection("events_announcements")
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
        db
          .collection("events_announcements")
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
    if (!transient(error)) throw error;

    await sleep(2000);

    const remaining = await findMissing(
      db,
      missing
    );

    if (remaining.length === 0) {
      console.log(
        "[RECOVERED] Publication batch committed despite timeout."
      );
      return missing.length;
    }

    if (remaining.length !== missing.length) {
      throw new Error(
        "Unexpected partial publication batch state."
      );
    }

    await commit();
    return missing.length;
  }
}

async function validateFinal(db, plan) {
  const snapshot = await db
    .collection("events_announcements")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const docs = snapshot.docs.filter((doc) => {
    const data = doc.data() || {};

    return (
      data.isDemoData === true &&
      data.seedBatch === SEED_BATCH &&
      data.seedVersion === SEED_VERSION &&
      typeof data.seedKey === "string" &&
      data.seedKey.startsWith("publication:")
    );
  });

  let events = 0;
  let announcements = 0;
  let completedEvents = 0;
  let upcomingEvents = 0;
  let activeAnnouncements = 0;
  let archivedAnnouncements = 0;

  const months = {};

  for (const doc of docs) {
    const data = doc.data();

    const parts = data.seedKey.split(":");
    const monthLabel = parts[2];

    months[monthLabel] =
      (months[monthLabel] || 0) + 1;

    if (data.type === "event") {
      events += 1;

      if (data.status === "completed") {
        completedEvents += 1;
      } else if (data.status === "upcoming") {
        upcomingEvents += 1;
      } else {
        throw new Error(
          `Unexpected demo event status at ${doc.id}: ${data.status}`
        );
      }

      if (
        !(data.date instanceof admin.firestore.Timestamp) ||
        !(data.eventDate instanceof admin.firestore.Timestamp)
      ) {
        throw new Error(
          `${doc.id} is missing canonical event dates.`
        );
      }
    } else if (data.type === "announcement") {
      announcements += 1;

      if (data.status === "active") {
        activeAnnouncements += 1;
      } else if (data.status === "archived") {
        archivedAnnouncements += 1;
      } else {
        throw new Error(
          `Unexpected demo announcement status at ${doc.id}: ${data.status}`
        );
      }
    } else {
      throw new Error(
        `Unexpected publication type at ${doc.id}: ${data.type}`
      );
    }
  }

  console.log(
    "\n===== GREEN WAVE EVENTS & ANNOUNCEMENTS SUMMARY ====="
  );

  console.log(`Records:               ${docs.length}`);
  console.log(`Events:                 ${events}`);
  console.log(`  Completed:            ${completedEvents}`);
  console.log(`  Upcoming:             ${upcomingEvents}`);
  console.log(`Announcements:          ${announcements}`);
  console.log(`  Active:               ${activeAnnouncements}`);
  console.log(`  Archived:             ${archivedAnnouncements}`);

  console.log("");

  for (const month of MONTHS) {
    console.log(
      `${month.label}: ${months[month.label] || 0}`
    );
  }

  if (
    docs.length !== 12 ||
    events !== 6 ||
    announcements !== 6 ||
    completedEvents !== 5 ||
    upcomingEvents !== 1 ||
    activeAnnouncements !== 3 ||
    archivedAnnouncements !== 3
  ) {
    throw new Error(
      "Publication totals do not match the expected Green Wave dataset."
    );
  }

  for (const month of MONTHS) {
    if (months[month.label] !== 2) {
      throw new Error(
        `Expected 2 publication records in ${month.label}.`
      );
    }
  }

  for (const item of plan) {
    const snapshot = await db
      .collection("events_announcements")
      .doc(item.id)
      .get();

    assertExisting(snapshot, item);
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

  const plan = buildPlan();

  const existingCommunityRecords =
    await refuseDuplicates(db, plan);

  const missing =
    await findMissing(db, plan);

  console.log(
    "===== HOMINODE DEMO EVENTS & ANNOUNCEMENTS ====="
  );

  console.log(`Project:       ${projectId}`);
  console.log(`Community:     ${COMMUNITY_ID}`);
  console.log(`Seed batch:    ${SEED_BATCH}`);
  console.log(
    `Mode:          ${apply ? "APPLY" : "DRY RUN"}`
  );

  console.log("");
  console.log("Planned records:        12");
  console.log("Events:                  6");
  console.log("  Completed:             5");
  console.log("  Upcoming:              1");
  console.log("Announcements:           6");
  console.log("  Active:                3");
  console.log("  Archived:              3");
  console.log("Months:             May-Oct 2026");
  console.log(
    `Existing community records: ${existingCommunityRecords}`
  );
  console.log(
    `Missing docs:             ${missing.length}`
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
    `\n[OK] Publication seed reconciled (${writes} writes).`
  );

  await validateFinal(db, plan);

  console.log(
    "\nDemo events & announcements seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo events & announcements seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
