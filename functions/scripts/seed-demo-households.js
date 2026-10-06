#!/usr/bin/env node

const admin = require("firebase-admin");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN = {
  uid: "demo-admin-green-wave",
  name: "Maya Rao",
  phoneNumber: "+919000000001",
};

const BUILDING_ORDER = {
  nova: 0,
  vertex: 1,
  horizon: 2,
  pulse: 3,
};

const FAMILY_FIRST_NAMES = [
  "Aanya", "Vihaan", "Isha", "Reyansh", "Meher",
  "Aarush", "Naira", "Riaan", "Tia", "Ahaan",
  "Myra", "Arnav", "Sana", "Kabir", "Avni",
  "Neil", "Ira", "Vivaan", "Rhea", "Advay",
  "Kiara", "Ayaan", "Mira", "Dhruv", "Anika",
  "Yuvan", "Tara", "Ishaan", "Diya", "Rohan",
  "Navya", "Arjun", "Sia", "Kiaan", "Aarohi",
  "Dev", "Naina", "Ved", "Aisha", "Rian",
  "Trisha", "Kavin", "Vanya", "Samar", "Ishita",
  "Nyla", "Aditya", "Reva", "Arin", "Sara",
  "Aahana", "Yash", "Meera", "Shaurya", "Tanya",
  "Anya", "Karan", "Maya", "Rishabh", "Aanya",
];

const VEHICLE_SPECS = [
  { name: "Tata Nexon EV", type: "Car", color: "Teal" },
  { name: "Hyundai Creta", type: "Car", color: "Titan Grey" },
  { name: "Kia Seltos", type: "Car", color: "White" },
  { name: "Honda City", type: "Car", color: "Silver" },
  { name: "Toyota Urban Cruiser Hyryder", type: "Car", color: "Black" },
  { name: "MG ZS EV", type: "Car", color: "White" },
  { name: "Mahindra XUV 3XO", type: "Car", color: "Grey" },
  { name: "Maruti Suzuki Grand Vitara", type: "Car", color: "Blue" },
  { name: "Skoda Kushaq", type: "Car", color: "Red" },
  { name: "Volkswagen Taigun", type: "Car", color: "Silver" },
  { name: "Tata Punch EV", type: "Car", color: "Seaweed Green" },
  { name: "Hyundai Verna", type: "Car", color: "Black" },

  { name: "Ather 450X", type: "Scooter", color: "Space Grey" },
  { name: "TVS iQube", type: "Scooter", color: "White" },
  { name: "Ola S1 Pro", type: "Scooter", color: "Midnight Blue" },
  { name: "Bajaj Chetak", type: "Scooter", color: "Matte Grey" },

  { name: "Royal Enfield Hunter 350", type: "Bike", color: "Black" },
  { name: "Honda CB350", type: "Bike", color: "Red" },
  { name: "Yamaha MT-15", type: "Bike", color: "Blue" },
  { name: "Hero Xpulse 200", type: "Bike", color: "White" },
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
        `[RETRY] ${label}: Firestore error ${error.code}; ` +
        `retrying in ${delayMs}ms`
      );

      await sleep(delayMs);
    }
  }

  throw lastError;
}

function parseResidentSeedKey(seedKey) {
  const match =
    /^resident:(nova|vertex|horizon|pulse):(\d+)$/.exec(
      String(seedKey || "")
    );

  if (!match) {
    throw new Error(
      `Invalid resident seed key: ${seedKey}`
    );
  }

  return {
    buildingKey: match[1],
    unitIndex: Number(match[2]),
  };
}

function residentSort(a, b) {
  const left = parseResidentSeedKey(a.data.seedKey);
  const right = parseResidentSeedKey(b.data.seedKey);

  const buildingDiff =
    BUILDING_ORDER[left.buildingKey] -
    BUILDING_ORDER[right.buildingKey];

  if (buildingDiff !== 0) return buildingDiff;

  return left.unitIndex - right.unitIndex;
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
      "Expected Green Wave demo community was not found."
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

async function loadCurrentResidents(db) {
  const snapshot = await db
    .collection("users")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const residents = snapshot.docs
    .map((doc) => ({
      id: doc.id,
      ref: doc.ref,
      data: doc.data(),
    }))
    .filter(({ data }) => {
      return (
        data.role === "resident" &&
        data.isDemoData === true &&
        data.seedBatch === SEED_BATCH &&
        data.approvalStatus === "approved" &&
        typeof data.flatId === "string" &&
        data.flatId.length > 0 &&
        (
          data.occupancyStatus === "current" ||
          data.occupancyStatus === "suspended"
        )
      );
    })
    .sort(residentSort);

  if (residents.length !== 50) {
    throw new Error(
      `Expected 50 current occupied demo households; found ${residents.length}.`
    );
  }

  for (const resident of residents) {
    if (
      !resident.data.buildingId ||
      !resident.data.flatId ||
      !resident.data.flatLabel ||
      !resident.data.name
    ) {
      throw new Error(
        `Resident ${resident.id} has incomplete household references.`
      );
    }
  }

  return residents;
}

function familyCountForIndex(index) {
  if (index < 8) return 3;
  if (index < 20) return 2;
  if (index < 32) return 1;
  return 0;
}

function relationForSlot(residentIndex, slot) {
  if (slot === 0) return "Spouse";

  if (slot === 1) {
    return residentIndex % 2 === 0
      ? "Daughter"
      : "Son";
  }

  return residentIndex % 2 === 0
    ? "Mother"
    : "Father";
}

function ageForRelation(relation, index) {
  if (relation === "Spouse") {
    return 29 + (index % 16);
  }

  if (
    relation === "Son" ||
    relation === "Daughter"
  ) {
    return 6 + (index % 12);
  }

  return 58 + (index % 15);
}

function surnameFor(name) {
  const parts = String(name)
    .trim()
    .split(/\s+/);

  return parts[parts.length - 1];
}

function buildFamilyPlan(residents) {
  const family = [];
  const counts = new Map();

  let sequence = 0;

  residents.forEach((resident, residentIndex) => {
    const count = familyCountForIndex(residentIndex);
    counts.set(resident.id, count);

    const identity =
      parseResidentSeedKey(resident.data.seedKey);

    const surname =
      surnameFor(resident.data.name);

    for (let slot = 0; slot < count; slot += 1) {
      const relation =
        relationForSlot(residentIndex, slot);

      const firstName =
        FAMILY_FIRST_NAMES[sequence];

      const memberName =
        `${firstName} ${surname}`;

      sequence += 1;

      family.push({
        id:
          `demo-family-${identity.buildingKey}-` +
          `${String(identity.unitIndex).padStart(2, "0")}-` +
          `${slot + 1}`,

        data: {
          userId: resident.id,
          communityId: COMMUNITY_ID,

          name: memberName,
          relation,
          age: ageForRelation(relation, sequence),
          photoUrl: null,
          isPrimary: false,

          buildingId: resident.data.buildingId,
          flatId: resident.data.flatId,
          flatLabel: resident.data.flatLabel,

          isDemoData: true,
          seedBatch: SEED_BATCH,
          seedVersion: SEED_VERSION,
          seedKey:
            `family:${identity.buildingKey}:` +
            `${identity.unitIndex}:${slot + 1}`,
        },
      });
    }
  });

  if (family.length !== 60) {
    throw new Error(
      `Expected 60 family members; planned ${family.length}.`
    );
  }

  return {
    family,
    counts,
  };
}

function vehicleCountForIndex(index) {
  if (index < 5) return 2;
  if (index < 35) return 1;
  return 0;
}

function buildVehiclePlan(residents) {
  const vehicles = [];
  let sequence = 0;

  residents.forEach((resident, residentIndex) => {
    const count =
      vehicleCountForIndex(residentIndex);

    const identity =
      parseResidentSeedKey(resident.data.seedKey);

    for (let slot = 0; slot < count; slot += 1) {
      const spec =
        VEHICLE_SPECS[
          sequence % VEHICLE_SPECS.length
        ];

      sequence += 1;

      const vehicleNumber =
        `KA53GW${String(1000 + sequence)}`;

      vehicles.push({
        id:
          `demo-vehicle-${identity.buildingKey}-` +
          `${String(identity.unitIndex).padStart(2, "0")}-` +
          `${slot + 1}`,

        data: {
          // Shared identity
          userId: resident.id,
          residentId:
            resident.data.residentId || resident.id,
          ownerName: resident.data.name,

          communityId: COMMUNITY_ID,
          buildingId: resident.data.buildingId,
          buildingIds: [resident.data.buildingId],
          flatId: resident.data.flatId,
          flatNumber: resident.data.flatLabel,
          flatLabel: resident.data.flatLabel,

          // Resident app vehicle contract
          name: spec.name,
          type: spec.type,
          plateNumber: vehicleNumber,
          color: spec.color,
          photoUrl: null,

          // Admin parking vehicle contract
          model: spec.name,
          vehicleNumber,
          vehicleType: spec.type,
          isActive: true,

          // Demo admin compatibility
          adminId: SEED_ADMIN.uid,
          adminName: SEED_ADMIN.name,
          adminPhone: SEED_ADMIN.phoneNumber,
          adminEmail: "",
          organization: "Green Wave Residences",

          isDemoData: true,
          seedBatch: SEED_BATCH,
          seedVersion: SEED_VERSION,
          seedKey:
            `vehicle:${identity.buildingKey}:` +
            `${identity.unitIndex}:${slot + 1}`,
        },
      });
    }
  });

  if (vehicles.length !== 40) {
    throw new Error(
      `Expected 40 vehicles; planned ${vehicles.length}.`
    );
  }

  return vehicles;
}

async function assertCollectionClean(
  db,
  collection,
  expectedIds
) {
  const snapshot = await db
    .collection(collection)
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const expected = new Set(expectedIds);

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};

    if (
      data.seedBatch === SEED_BATCH &&
      data.isDemoData === true
    ) {
      if (!expected.has(doc.id)) {
        throw new Error(
          `Unexpected seeded ${collection}/${doc.id} exists.`
        );
      }

      continue;
    }

    throw new Error(
      `Non-demo ${collection}/${doc.id} exists inside ${COMMUNITY_ID}; ` +
      `refusing to mix production-like data into the controlled dataset.`
    );
  }

  return snapshot;
}

function assertExistingSeedDoc(
  collection,
  snapshot,
  expected
) {
  if (!snapshot.exists) return;

  const data = snapshot.data() || {};

  if (
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    data.communityId !== COMMUNITY_ID ||
    data.userId !== expected.userId
  ) {
    throw new Error(
      `Conflicting document exists at ${collection}/${snapshot.id}.`
    );
  }
}

async function preflightExpectedDocs(
  db,
  collection,
  plans
) {
  const existingIds = new Set();

  for (const plan of plans) {
    const snapshot = await db
      .collection(collection)
      .doc(plan.id)
      .get();

    assertExistingSeedDoc(
      collection,
      snapshot,
      plan.data
    );

    if (snapshot.exists) {
      existingIds.add(plan.id);
    }
  }

  return existingIds;
}

async function writeFamilyData(
  db,
  residents,
  familyPlan,
  familyCounts,
  existingFamilyIds
) {
  const batch = db.batch();
  const timestamp =
    admin.firestore.FieldValue.serverTimestamp();

  let writeCount = 0;

  for (const member of familyPlan) {
    if (existingFamilyIds.has(member.id)) {
      continue;
    }

    const ref = db
      .collection("familyMembers")
      .doc(member.id);

    // merge keeps retry safe if a previous commit succeeded but
    // the client received a transient deadline error.
    batch.set(
      ref,
      {
        ...member.data,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    writeCount += 1;
  }

  for (const resident of residents) {
    const expectedCount =
      familyCounts.get(resident.id) || 0;

    if (
      resident.data.familyMembers === expectedCount
    ) {
      continue;
    }

    batch.set(
      resident.ref,
      {
        familyMembers: expectedCount,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    writeCount += 1;
  }

  if (writeCount > 0) {
    await batch.commit();
  }

  return writeCount;
}

async function writeVehicleData(
  db,
  vehicles,
  existingVehicleIds
) {
  const batch = db.batch();
  const timestamp =
    admin.firestore.FieldValue.serverTimestamp();

  let writeCount = 0;

  for (const vehicle of vehicles) {
    if (existingVehicleIds.has(vehicle.id)) {
      continue;
    }

    const ref = db
      .collection("vehicles")
      .doc(vehicle.id);

    batch.set(
      ref,
      {
        ...vehicle.data,
        registrationDate: timestamp,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
      { merge: true }
    );

    writeCount += 1;
  }

  if (writeCount > 0) {
    await batch.commit();
  }

  return writeCount;
}

async function validateFinalState(
  db,
  residents,
  familyPlan,
  familyCounts,
  vehiclePlan
) {
  const familySnapshot = await db
    .collection("familyMembers")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const vehicleSnapshot = await db
    .collection("vehicles")
    .where("communityId", "==", COMMUNITY_ID)
    .get();

  const familyDocs =
    familySnapshot.docs.filter(
      (doc) =>
        doc.data()?.isDemoData === true &&
        doc.data()?.seedBatch === SEED_BATCH
    );

  const vehicleDocs =
    vehicleSnapshot.docs.filter(
      (doc) =>
        doc.data()?.isDemoData === true &&
        doc.data()?.seedBatch === SEED_BATCH
    );

  if (familyDocs.length !== 60) {
    throw new Error(
      `Expected 60 seeded family members; found ${familyDocs.length}.`
    );
  }

  if (vehicleDocs.length !== 40) {
    throw new Error(
      `Expected 40 seeded vehicles; found ${vehicleDocs.length}.`
    );
  }

  const residentIds =
    new Set(residents.map((resident) => resident.id));

  for (const doc of [
    ...familyDocs,
    ...vehicleDocs,
  ]) {
    if (
      !residentIds.has(doc.data()?.userId)
    ) {
      throw new Error(
        `${doc.ref.path} belongs to a non-current resident.`
      );
    }
  }

  for (const resident of residents) {
    const snapshot =
      await resident.ref.get();

    const expected =
      familyCounts.get(resident.id) || 0;

    if (
      snapshot.data()?.familyMembers !== expected
    ) {
      throw new Error(
        `Family count mismatch for ${resident.data.name}.`
      );
    }
  }

  const vehicleTypes = {
    Car: 0,
    Scooter: 0,
    Bike: 0,
  };

  for (const doc of vehicleDocs) {
    const type = doc.data()?.vehicleType;

    if (vehicleTypes[type] != null) {
      vehicleTypes[type] += 1;
    }
  }

  console.log(
    "\n===== GREEN WAVE HOUSEHOLD SUMMARY ====="
  );
  console.log(`Current households:  ${residents.length}`);
  console.log(`Family members:      ${familyDocs.length}`);
  console.log(`Vehicles:            ${vehicleDocs.length}`);
  console.log(`Cars:                ${vehicleTypes.Car}`);
  console.log(`Scooters:            ${vehicleTypes.Scooter}`);
  console.log(`Bikes:               ${vehicleTypes.Bike}`);

  if (
    vehicleTypes.Car !== 24 ||
    vehicleTypes.Scooter !== 8 ||
    vehicleTypes.Bike !== 8
  ) {
    throw new Error(
      "Vehicle type totals do not match the expected demo dataset."
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

  const residents =
    await loadCurrentResidents(db);

  const {
    family,
    counts: familyCounts,
  } = buildFamilyPlan(residents);

  const vehicles =
    buildVehiclePlan(residents);

  await assertCollectionClean(
    db,
    "familyMembers",
    family.map((item) => item.id)
  );

  await assertCollectionClean(
    db,
    "vehicles",
    vehicles.map((item) => item.id)
  );

  const existingFamilyIds =
    await preflightExpectedDocs(
      db,
      "familyMembers",
      family
    );

  const existingVehicleIds =
    await preflightExpectedDocs(
      db,
      "vehicles",
      vehicles
    );

  console.log("===== HOMINODE DEMO HOUSEHOLDS =====");
  console.log(`Project:             ${projectId}`);
  console.log(`Community:           ${COMMUNITY_ID}`);
  console.log(`Seed batch:          ${SEED_BATCH}`);
  console.log(`Mode:                ${apply ? "APPLY" : "DRY RUN"}`);
  console.log("");
  console.log("Current households:  50");
  console.log("Family members:      60");
  console.log("Family households:   32");
  console.log("Vehicles:            40");
  console.log("Vehicle households:  35");
  console.log("Cars/Scooters/Bikes: 24 / 8 / 8");

  if (!apply) {
    console.log("\nNo Firestore writes performed.");
    return;
  }

  const familyWrites = await withRetry(
    "family member seed",
    () =>
      writeFamilyData(
        db,
        residents,
        family,
        familyCounts,
        existingFamilyIds
      )
  );

  console.log(
    `[OK] Family seed reconciled (${familyWrites} writes).`
  );

  const vehicleWrites = await withRetry(
    "vehicle seed",
    () =>
      writeVehicleData(
        db,
        vehicles,
        existingVehicleIds
      )
  );

  console.log(
    `[OK] Vehicle seed reconciled (${vehicleWrites} writes).`
  );

  await validateFinalState(
    db,
    residents,
    family,
    familyCounts,
    vehicles
  );

  console.log(
    "\nDemo household seed complete."
  );
}

main().catch((error) => {
  console.error(
    "\nDemo household seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
