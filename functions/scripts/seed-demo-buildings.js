#!/usr/bin/env node

const admin = require("firebase-admin");
const { createBuildingCore } = require("../src/building_reconciliation");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN = {
  uid: "demo-admin-green-wave",
  name: "Maya Rao",
  phoneNumber: "+919000000001",
};

const BUILDINGS = [
  { key: "nova", name: "Nova" },
  { key: "vertex", name: "Vertex" },
  { key: "horizon", name: "Horizon" },
  { key: "pulse", name: "Pulse" },
];

const BHK_GRID = [
  ["1BHK", "2BHK", "2BHK", "1BHK"],
  ["2BHK", "2BHK", "2BHK", "2BHK"],
  ["2BHK", "2BHK", "3BHK", "3BHK"],
  ["3BHK", "3BHK", "3BHK", "4BHK"],
];

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function typeAt(floor, flatNumber) {
  return BHK_GRID[floor - 1][flatNumber - 1];
}

function flatBhkConfig() {
  const config = {};

  for (let floor = 1; floor <= 4; floor += 1) {
    for (let flatNumber = 1; flatNumber <= 4; flatNumber += 1) {
      config[`pos:${floor}:${flatNumber}`] =
        typeAt(floor, flatNumber);
    }
  }

  return config;
}

async function requireDemoCommunity(db) {
  const snapshot = await db
    .collection("communities")
    .doc(COMMUNITY_ID)
    .get();

  if (!snapshot.exists) {
    throw new Error(
      `${COMMUNITY_ID} does not exist. Run create-demo-community first.`
    );
  }

  const community = snapshot.data() || {};

  if (
    community.isActive !== true ||
    community.isDemoData !== true ||
    community.seedBatch !== SEED_BATCH
  ) {
    throw new Error(
      `${COMMUNITY_ID} is not the expected active demo community.`
    );
  }

  return community;
}

async function ensureSeedAdmin(db, apply) {
  const ref = db.collection("admins").doc(SEED_ADMIN.uid);
  const snapshot = await ref.get();

  if (snapshot.exists) {
    const current = snapshot.data() || {};

    if (
      current.uid !== SEED_ADMIN.uid ||
      current.role !== "admin" ||
      current.isActive !== true ||
      current.isDemoData !== true ||
      current.seedBatch !== SEED_BATCH ||
      !Array.isArray(current.authorizedCommunityIds) ||
      !current.authorizedCommunityIds.includes(COMMUNITY_ID)
    ) {
      throw new Error(
        `Conflicting admin profile exists at admins/${SEED_ADMIN.uid}.`
      );
    }

    console.log(
      `[OK] Demo admin already exists: ${SEED_ADMIN.name}`
    );
    return;
  }

  if (!apply) {
    console.log(
      `[PLAN] Create seed-only demo admin: ${SEED_ADMIN.name}`
    );
    return;
  }

  await ref.create({
    uid: SEED_ADMIN.uid,
    name: SEED_ADMIN.name,
    fullName: SEED_ADMIN.name,
    phoneNumber: SEED_ADMIN.phoneNumber,

    role: "admin",
    isActive: true,
    authorizedCommunityIds: [COMMUNITY_ID],

    isDemoData: true,
    seedActor: true,
    loginEnabled: false,
    seedBatch: SEED_BATCH,
    seedVersion: SEED_VERSION,

    createdBy: "system:demo-seed",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(
    `[CREATED] Seed-only demo admin: ${SEED_ADMIN.name}`
  );
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

async function communityBuildings(db) {
  const snapshot = await db
    .collection("buildings")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  return snapshot.docs;
}

async function validateBuilding(db, snapshot, definition) {
  const building = snapshot.data() || {};

  if (
    building.communityId !== COMMUNITY_ID ||
    building.name !== definition.name ||
    building.buildingName !== definition.name ||
    building.structureType !== "apartment_building" ||
    building.floors !== 4 ||
    building.flatsPerFloor !== 4 ||
    building.totalFlats !== 16
  ) {
    throw new Error(
      `Building ${definition.name} exists with an unexpected structure.`
    );
  }

  const flats = await db
    .collection("flats")
    .where("buildingId", "==", snapshot.id)
    .get();

  if (flats.size !== 16) {
    throw new Error(
      `${definition.name} should have 16 units, found ${flats.size}.`
    );
  }

  const positions = new Set();

  for (const flatDoc of flats.docs) {
    const flat = flatDoc.data() || {};

    if (
      flat.communityId !== COMMUNITY_ID ||
      flat.buildingId !== snapshot.id ||
      flat.buildingName !== definition.name
    ) {
      throw new Error(
        `${definition.name} contains a unit with invalid references.`
      );
    }

    const floor = flat.floor;
    const number = flat.flatNumber;

    if (
      !Number.isInteger(floor) ||
      floor < 1 ||
      floor > 4 ||
      !Number.isInteger(number) ||
      number < 1 ||
      number > 4
    ) {
      throw new Error(
        `${definition.name} contains an invalid unit position.`
      );
    }

    const position = `${floor}:${number}`;

    if (positions.has(position)) {
      throw new Error(
        `${definition.name} contains duplicate unit position ${position}.`
      );
    }

    positions.add(position);

    const expectedType = typeAt(floor, number);

    if (
      flat.type !== expectedType ||
      flat.bhkType !== expectedType
    ) {
      throw new Error(
        `${definition.name} ${position} expected ${expectedType}, found ${flat.bhkType || flat.type}.`
      );
    }
  }

  return flats;
}

async function tagBuilding(db, buildingSnapshot, flats, definition) {
  const batch = db.batch();
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  batch.set(
    buildingSnapshot.ref,
    {
      isDemoData: true,
      seedBatch: SEED_BATCH,
      seedVersion: SEED_VERSION,
      seedKey: `building:${definition.key}`,
      updatedAt: timestamp,
    },
    { merge: true }
  );

  for (const flatDoc of flats.docs) {
    const flat = flatDoc.data();

    batch.set(
      flatDoc.ref,
      {
        isDemoData: true,
        seedBatch: SEED_BATCH,
        seedVersion: SEED_VERSION,
        seedKey:
          `unit:${definition.key}:${flat.floor}:${flat.flatNumber}`,
        updatedAt: timestamp,
      },
      { merge: true }
    );
  }

  await batch.commit();
}

async function ensureBuilding(db, definition, apply) {
  const docs = await communityBuildings(db);

  const matches = docs.filter((doc) => {
    const data = doc.data() || {};
    return (
      data.name === definition.name ||
      data.buildingName === definition.name ||
      data.seedKey === `building:${definition.key}`
    );
  });

  if (matches.length > 1) {
    throw new Error(
      `Multiple ${definition.name} buildings exist in ${COMMUNITY_ID}.`
    );
  }

  if (matches.length === 1) {
    const buildingSnapshot = matches[0];
    const building = buildingSnapshot.data() || {};

    if (
      building.seedBatch &&
      building.seedBatch !== SEED_BATCH
    ) {
      throw new Error(
        `${definition.name} belongs to another seed batch.`
      );
    }

    if (
      building.adminId &&
      building.adminId !== SEED_ADMIN.uid
    ) {
      throw new Error(
        `${definition.name} is owned by a non-demo admin.`
      );
    }

    const flats =
      await validateBuilding(db, buildingSnapshot, definition);

    if (apply) {
      await tagBuilding(
        db,
        buildingSnapshot,
        flats,
        definition
      );
    }

    console.log(
      `[OK] ${definition.name}: existing 16-unit demo building`
    );

    return {
      created: false,
      buildingId: buildingSnapshot.id,
    };
  }

  if (!apply) {
    console.log(
      `[PLAN] Create ${definition.name}: 4 floors × 4 units`
    );

    return {
      created: false,
      buildingId: null,
    };
  }

  const result = await createBuildingCore({
    db,
    auth: seedAuth(),
    data: {
      communityId: COMMUNITY_ID,
      name: definition.name,
      floors: 4,
      flatsPerFloor: 4,
      totalFlats: 16,
      structureType: "apartment_building",
      unitType: "apartment",
      flatBhkConfig: flatBhkConfig(),
    },
  });

  const buildingSnapshot = await db
    .collection("buildings")
    .doc(result.buildingId)
    .get();

  const flats =
    await validateBuilding(db, buildingSnapshot, definition);

  await tagBuilding(
    db,
    buildingSnapshot,
    flats,
    definition
  );

  console.log(
    `[CREATED] ${definition.name}: ${result.totalFlats} units`
  );

  return {
    created: true,
    buildingId: result.buildingId,
  };
}

async function printSummary(db) {
  const buildingSnapshot = await db
    .collection("buildings")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const seededBuildings = buildingSnapshot.docs.filter(
    (doc) => doc.data()?.seedBatch === SEED_BATCH
  );

  let unitCount = 0;
  const mix = {
    "1BHK": 0,
    "2BHK": 0,
    "3BHK": 0,
    "4BHK": 0,
  };

  for (const building of seededBuildings) {
    const flats = await db
      .collection("flats")
      .where("buildingId", "==", building.id)
      .get();

    for (const doc of flats.docs) {
      const flat = doc.data();

      if (flat.seedBatch !== SEED_BATCH) continue;

      unitCount += 1;

      if (mix[flat.bhkType] != null) {
        mix[flat.bhkType] += 1;
      }
    }
  }

  console.log("\n===== CURRENT DEMO STRUCTURE =====");
  console.log(`Buildings: ${seededBuildings.length}`);
  console.log(`Units:     ${unitCount}`);
  console.log(`1BHK:      ${mix["1BHK"]}`);
  console.log(`2BHK:      ${mix["2BHK"]}`);
  console.log(`3BHK:      ${mix["3BHK"]}`);
  console.log(`4BHK:      ${mix["4BHK"]}`);
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

  await requireDemoCommunity(db);

  console.log("===== HOMINODE DEMO BUILDINGS =====");
  console.log(`Project:      ${projectId}`);
  console.log(`Community:    ${COMMUNITY_ID}`);
  console.log(`Seed batch:   ${SEED_BATCH}`);
  console.log(`Mode:         ${apply ? "APPLY" : "DRY RUN"}`);
  console.log("");

  await ensureSeedAdmin(db, apply);

  for (const building of BUILDINGS) {
    await ensureBuilding(db, building, apply);
  }

  if (apply) {
    await printSummary(db);
    console.log("\nDemo building seed complete.");
  } else {
    console.log("\nNo Firestore writes performed.");
    console.log(
      "Planned result: 4 buildings, 64 units."
    );
    console.log(
      "BHK mix: 8 × 1BHK, 32 × 2BHK, 20 × 3BHK, 4 × 4BHK."
    );
  }
}

main().catch((error) => {
  console.error("\nDemo building seed failed.");
  console.error(error);
  process.exitCode = 1;
});
