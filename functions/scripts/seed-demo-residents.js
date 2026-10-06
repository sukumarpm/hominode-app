#!/usr/bin/env node

const admin = require("firebase-admin");

const {
  approveResidentRegistrationCore,
  deactivateResidentCore,
  moveOutResidentCore,
} = require("../src/resident_identity");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN = {
  uid: "demo-admin-green-wave",
  phoneNumber: "+919000000001",
};

const BUILDINGS = [
  { key: "nova", name: "Nova", initial: "N" },
  { key: "vertex", name: "Vertex", initial: "V" },
  { key: "horizon", name: "Horizon", initial: "H" },
  { key: "pulse", name: "Pulse", initial: "P" },
];

const RESIDENT_NAMES = [
  "Aarav Mehta",
  "Mira Kapoor",
  "Rhea Menon",
  "Neil Shah",
  "Tara Khanna",
  "Kabir Rao",
  "Ishaan Verma",
  "Anya Nair",
  "Reyansh Malhotra",
  "Kiara Sen",
  "Vivaan Sethi",
  "Myra Iyer",
  "Arjun Bhatia",
  "Nikhil Arora",
  "Sara Thomas",
  "Aditya Jain",
  "Naina Bose",
  "Karan Gill",
  "Ira Pillai",
  "Rohan Khurana",
  "Aisha D'Souza",
  "Dev Mehra",
  "Meera Sood",
  "Vihaan Reddy",
  "Tanya Desai",
  "Samar Oberoi",
  "Aanya George",
  "Rishabh Kohli",
  "Diya Anand",
  "Yuvan Prakash",
  "Anika Mathew",
  "Dhruv Talwar",
  "Sia Chawla",
  "Arnav Krishnan",
  "Reva Bansal",
  "Ayaan Roy",
  "Navya Shetty",
  "Kiaan Chopra",
  "Trisha Narang",
  "Vedant Kulkarni",
  "Aarohi Bedi",
  "Rian Fernandes",
  "Maya Raman",
  "Advait Saxena",
  "Ishita Grover",
  "Arin Joseph",
  "Nyla Khatri",
  "Shaurya Das",
  "Aahana Vohra",
  "Kavin Nambiar",
  "Vanya Bhalla",
  "Yash Mehta",
];

const MOVED_OUT = new Set([
  "nova:12",
  "horizon:12",
]);

const SUSPENDED = new Set([
  "vertex:6",
  "pulse:9",
]);

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

function isTransientFirestoreError(error) {
  return [4, 10, 13, 14].includes(Number(error?.code)) ||
    [
      "deadline-exceeded",
      "aborted",
      "internal",
      "unavailable",
    ].includes(String(error?.code || "").toLowerCase());
}

async function withRetry(label, operation, maxAttempts = 4) {
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      if (
        !isTransientFirestoreError(error) ||
        attempt === maxAttempts
      ) {
        throw error;
      }

      const delayMs = attempt * 2000;

      console.warn(
        `[RETRY] ${label}: transient Firestore error ` +
        `${error.code}; retrying in ${delayMs}ms ` +
        `(${attempt}/${maxAttempts - 1})`
      );

      await sleep(delayMs);
    }
  }

  throw lastError;
}

function seedAuth() {
  return {
    uid: SEED_ADMIN.uid,
    token: {
      phone_number: SEED_ADMIN.phoneNumber,
      firebase: {
        sign_in_provider: "phone",
      },
    },
  };
}

function emailFor(name, sequence) {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z]+/g, ".")
    .replace(/^\.+|\.+$/g, "");

  return `${slug}.gw${String(sequence).padStart(2, "0")}@example.invalid`;
}

function demoPhone(sequence) {
  // Intentionally non-routable-looking demo data.
  // No Firebase Auth users are created for these numbers.
  return `+91000000${String(sequence).padStart(4, "0")}`;
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
    throw new Error("Expected Green Wave demo community was not found.");
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
    seedAdmin.data()?.seedBatch !== SEED_BATCH ||
    !seedAdmin.data()?.authorizedCommunityIds?.includes(COMMUNITY_ID)
  ) {
    throw new Error("Expected Green Wave demo admin was not found.");
  }
}

async function loadBuilding(db, definition) {
  const snapshot = await db
    .collection("buildings")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const matches = snapshot.docs.filter((doc) => {
    const data = doc.data() || {};

    return (
      data.seedBatch === SEED_BATCH &&
      data.seedKey === `building:${definition.key}`
    );
  });

  if (matches.length !== 1) {
    throw new Error(
      `Expected exactly one seeded ${definition.name} building, found ${matches.length}.`
    );
  }

  const building = matches[0];

  const flatSnapshot = await db
    .collection("flats")
    .where("buildingId", "==", building.id)
    .get();

  const flats = flatSnapshot.docs
    .map((doc) => ({
      ref: doc.ref,
      id: doc.id,
      data: doc.data(),
    }))
    .sort((a, b) => {
      const floorDiff = a.data.floor - b.data.floor;
      if (floorDiff !== 0) return floorDiff;
      return a.data.flatNumber - b.data.flatNumber;
    });

  if (flats.length !== 16) {
    throw new Error(
      `${definition.name} should contain 16 units; found ${flats.length}.`
    );
  }

  return {
    definition,
    building,
    flats,
  };
}

function plannedState(buildingKey, unitIndex) {
  const key = `${buildingKey}:${unitIndex}`;

  if (MOVED_OUT.has(key)) return "moved_out";
  if (SUSPENDED.has(key)) return "suspended";

  return "active";
}

function buildResidentPlan(structures) {
  const plans = [];
  let sequence = 0;

  for (const structure of structures) {
    // Seed first 13 of 16 units in each building.
    for (let index = 0; index < 13; index += 1) {
      sequence += 1;

      const flat = structure.flats[index];
      const unitIndex = index + 1;
      const name = RESIDENT_NAMES[sequence - 1];
      const residentType =
        sequence % 5 === 0 ? "tenant" : "owner";

      const userId =
        `demo-resident-${structure.definition.key}-${String(unitIndex).padStart(2, "0")}`;

      plans.push({
        sequence,
        userId,
        name,
        residentId:
          `GW-${structure.definition.initial}-${String(unitIndex).padStart(3, "0")}`,
        residentType,
        phoneNumber: demoPhone(sequence),
        email: emailFor(name, sequence),

        buildingId: structure.building.id,
        buildingName: structure.definition.name,

        flatId: flat.id,
        flatLabel:
          flat.data.flatLabel ||
          flat.data.flatId ||
          flat.id,
        unitId:
          flat.data.unitId ||
          flat.data.flatId ||
          flat.id,

        unitIndex,
        buildingKey: structure.definition.key,
        targetState:
          plannedState(
            structure.definition.key,
            unitIndex
          ),
      });
    }
  }

  if (plans.length !== 52) {
    throw new Error(
      `Resident plan should contain 52 profiles; found ${plans.length}.`
    );
  }

  return plans;
}

async function createPendingResident(db, plan) {
  const timestamp =
    admin.firestore.FieldValue.serverTimestamp();

  await db.collection("users").doc(plan.userId).create({
    uid: plan.userId,

    residentId: plan.residentId,
    name: plan.name,
    fullName: plan.name,

    phoneNumber: plan.phoneNumber,
    phone: plan.phoneNumber,
    email: plan.email,

    role: "resident",
    communityId: COMMUNITY_ID,

    declaredResidentType: plan.residentType,
    residentType: plan.residentType,
    ownershipType: plan.residentType,

    approvalStatus: "pending",
    isActive: false,
    status: "pending",
    occupancyStatus: "pending",

    // Demo identities are treated as verified so tenant approval follows
    // the same production approval contract without storing fake proofs.
    identityVerified: true,
    identityVerificationStatus: "verified",

    buildingId: plan.buildingId,
    buildingName: plan.buildingName,

    flatId: plan.flatId,
    flatLabel: plan.flatLabel,
    unitId: plan.unitId,

    familyMembers: 0,

    creationSource: "demo_seed",

    isDemoData: true,
    seedBatch: SEED_BATCH,
    seedVersion: SEED_VERSION,
    seedKey: `resident:${plan.buildingKey}:${plan.unitIndex}`,

    createdBy: SEED_ADMIN.uid,
    createdAt: timestamp,
    updatedAt: timestamp,
  });
}

function assertDemoResident(existing, plan) {
  if (
    existing.uid !== plan.userId ||
    existing.role !== "resident" ||
    existing.communityId !== COMMUNITY_ID ||
    existing.isDemoData !== true ||
    existing.seedBatch !== SEED_BATCH ||
    existing.seedKey !==
      `resident:${plan.buildingKey}:${plan.unitIndex}`
  ) {
    throw new Error(
      `Conflicting user exists at users/${plan.userId}.`
    );
  }

  if (
    existing.name !== plan.name ||
    existing.residentType !== plan.residentType ||
    existing.ownershipType !== plan.residentType
  ) {
    throw new Error(
      `Resident ${plan.userId} does not match the seed plan.`
    );
  }
}

async function ensureResident(db, plan, apply) {
  const ref = db.collection("users").doc(plan.userId);
  let snapshot = await ref.get();

  if (!snapshot.exists) {
    if (!apply) {
      console.log(
        `[PLAN] ${plan.name} → ${plan.buildingName} ${plan.flatLabel} (${plan.residentType})`
      );
      return;
    }

    await createPendingResident(db, plan);

    console.log(
      `[CREATED] Pending profile: ${plan.name}`
    );

    snapshot = await ref.get();
  }

  let resident = snapshot.data() || {};
  assertDemoResident(resident, plan);

  if (!apply) {
    console.log(
      `[OK] ${plan.name}: existing demo resident profile`
    );
    return;
  }

  if (
    resident.approvalStatus === "pending" &&
    resident.isActive === false
  ) {
    await approveResidentRegistrationCore({
      db,
      auth: seedAuth(),
      data: {
        communityId: COMMUNITY_ID,
        userId: plan.userId,
        buildingId: plan.buildingId,
        flatId: plan.flatId,
        residentType: plan.residentType,
      },
    });

    console.log(
      `[APPROVED] ${plan.name} → ${plan.buildingName} ${plan.flatLabel}`
    );

    snapshot = await ref.get();
    resident = snapshot.data() || {};
  }

  if (
    plan.targetState === "active"
  ) {
    if (
      resident.approvalStatus !== "approved" ||
      resident.isActive !== true ||
      resident.status !== "active" ||
      resident.occupancyStatus !== "current" ||
      resident.flatId !== plan.flatId
    ) {
      throw new Error(
        `${plan.name} is not in the expected active state.`
      );
    }

    return;
  }

  if (plan.targetState === "suspended") {
    if (
      resident.approvalStatus === "approved" &&
      resident.isActive === false &&
      resident.status === "inactive" &&
      resident.occupancyStatus === "suspended"
    ) {
      return;
    }

    if (
      resident.approvalStatus === "approved" &&
      resident.isActive === true &&
      resident.status === "active" &&
      resident.occupancyStatus === "current"
    ) {
      await deactivateResidentCore({
        db,
        auth: seedAuth(),
        data: {
          communityId: COMMUNITY_ID,
          userId: plan.userId,
        },
      });

      console.log(
        `[SUSPENDED] ${plan.name}`
      );

      return;
    }

    throw new Error(
      `${plan.name} cannot be reconciled to suspended state safely.`
    );
  }

  if (plan.targetState === "moved_out") {
    if (
      resident.approvalStatus === "approved" &&
      resident.isActive === false &&
      resident.status === "inactive" &&
      resident.occupancyStatus === "moved_out" &&
      resident.previousFlatId === plan.flatId &&
      !resident.flatId
    ) {
      return;
    }

    if (
      resident.approvalStatus === "approved" &&
      resident.isActive === true &&
      resident.status === "active" &&
      resident.occupancyStatus === "current" &&
      resident.flatId === plan.flatId
    ) {
      await moveOutResidentCore({
        db,
        auth: seedAuth(),
        data: {
          communityId: COMMUNITY_ID,
          userId: plan.userId,
        },
      });

      console.log(
        `[MOVED OUT] ${plan.name}`
      );

      return;
    }

    throw new Error(
      `${plan.name} cannot be reconciled to moved-out state safely.`
    );
  }
}

async function printSummary(db) {
  const users = await db
    .collection("users")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const residents = users.docs
    .map((doc) => doc.data())
    .filter(
      (data) =>
        data.isDemoData === true &&
        data.seedBatch === SEED_BATCH &&
        data.role === "resident"
    );

  let active = 0;
  let suspended = 0;
  let movedOut = 0;
  let owners = 0;
  let tenants = 0;

  for (const resident of residents) {
    if (
      resident.isActive === true &&
      resident.status === "active" &&
      resident.occupancyStatus === "current"
    ) {
      active += 1;
    }

    if (
      resident.isActive === false &&
      resident.occupancyStatus === "suspended"
    ) {
      suspended += 1;
    }

    if (
      resident.isActive === false &&
      resident.occupancyStatus === "moved_out"
    ) {
      movedOut += 1;
    }

    if (resident.residentType === "owner") owners += 1;
    if (resident.residentType === "tenant") tenants += 1;
  }

  const flats = await db
    .collection("flats")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  let occupied = 0;
  let vacant = 0;

  for (const doc of flats.docs) {
    const flat = doc.data();

    if (flat.status === "occupied") occupied += 1;
    if (flat.status === "vacant") vacant += 1;
  }

  console.log("\n===== GREEN WAVE RESIDENT SUMMARY =====");
  console.log(`Resident profiles: ${residents.length}`);
  console.log(`Active current:    ${active}`);
  console.log(`Suspended:         ${suspended}`);
  console.log(`Moved out:         ${movedOut}`);
  console.log(`Owners:            ${owners}`);
  console.log(`Tenants:           ${tenants}`);
  console.log(`Occupied units:    ${occupied}`);
  console.log(`Vacant units:      ${vacant}`);

  if (
    residents.length !== 52 ||
    active !== 48 ||
    suspended !== 2 ||
    movedOut !== 2 ||
    owners !== 42 ||
    tenants !== 10 ||
    occupied !== 50 ||
    vacant !== 14
  ) {
    throw new Error(
      "Demo resident totals do not match the expected dataset."
    );
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
      `Refusing to run against unexpected project: ${projectId}`
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp({ projectId });
  }

  const db = admin.firestore();

  await requireEnvironment(db);

  const structures = [];

  for (const definition of BUILDINGS) {
    structures.push(
      await loadBuilding(db, definition)
    );
  }

  const plans = buildResidentPlan(structures);

  console.log("===== HOMINODE DEMO RESIDENTS =====");
  console.log(`Project:     ${projectId}`);
  console.log(`Community:   ${COMMUNITY_ID}`);
  console.log(`Seed batch:  ${SEED_BATCH}`);
  console.log(`Mode:        ${apply ? "APPLY" : "DRY RUN"}`);
  console.log("");
  console.log("Planned profiles: 52");
  console.log("Final occupied:   50");
  console.log("Active:           48");
  console.log("Suspended:         2");
  console.log("Moved out:         2");
  console.log("Owners/Tenants:   42 / 10");
  console.log("");

  for (const plan of plans) {
    await withRetry(
      plan.name,
      () => ensureResident(db, plan, apply)
    );
  }

  if (apply) {
    await printSummary(db);
    console.log("\nDemo resident seed complete.");
  } else {
    console.log("\nNo Firestore writes performed.");
  }
}

main().catch((error) => {
  console.error("\nDemo resident seed failed.");
  console.error(error);
  process.exitCode = 1;
});
