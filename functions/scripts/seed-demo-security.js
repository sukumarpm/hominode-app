#!/usr/bin/env node

const admin = require("firebase-admin");
const {
  assignSecurityWorkCore,
} = require("../src/security_management");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";
const SEED_VERSION = 1;

const SEED_ADMIN = {
  uid: "demo-admin-green-wave",
  phoneNumber: "+919000000001",
};

const GATES = [
  {
    id: "demo-gate-main-entrance",
    key: "main-entrance",
    gateName: "Main Entrance",
    gateType: "Main Gate",
    shiftTime: "Full Day (24 Hours)",
  },
  {
    id: "demo-gate-resident-exit",
    key: "resident-exit",
    gateName: "Resident Vehicle Exit",
    gateType: "Vehicle Gate",
    shiftTime: "Full Day (24 Hours)",
  },
  {
    id: "demo-gate-service-delivery",
    key: "service-delivery",
    gateName: "Service & Delivery",
    gateType: "Service Gate",
    shiftTime: "Full Day (24 Hours)",
  },
  {
    id: "demo-gate-clubhouse",
    key: "clubhouse",
    gateName: "Clubhouse & Amenities",
    gateType: "Pedestrian Gate",
    shiftTime: "Day Shift (6 AM - 6 PM)",
  },
];

const STAFF = [
  {
    uid: "demo-security-01",
    name: "Arvind Menon",
    securityId: "GW-SEC-001",
    phoneNumber: "+910000000101",
    gateId: "demo-gate-main-entrance",
    shiftTiming: "Morning (6 AM - 2 PM)",
    targetStatus: "on-duty",
    workStatus: "On Duty",
    instructions:
      "Primary visitor verification and resident entry support.",
  },
  {
    uid: "demo-security-02",
    name: "Sameer Khan",
    securityId: "GW-SEC-002",
    phoneNumber: "+910000000102",
    gateId: "demo-gate-resident-exit",
    shiftTiming: "Afternoon (2 PM - 10 PM)",
    targetStatus: "on-duty",
    workStatus: "On Duty",
    instructions:
      "Monitor resident vehicle exit and access exceptions.",
  },
  {
    uid: "demo-security-03",
    name: "Rakesh Gowda",
    securityId: "GW-SEC-003",
    phoneNumber: "+910000000103",
    gateId: "demo-gate-service-delivery",
    shiftTiming: "Morning (6 AM - 2 PM)",
    targetStatus: "on-duty",
    workStatus: "On Duty",
    instructions:
      "Handle delivery partners, vendors, parcels, and service access.",
  },
  {
    uid: "demo-security-04",
    name: "Naveen Kumar",
    securityId: "GW-SEC-004",
    phoneNumber: "+910000000104",
    gateId: "demo-gate-clubhouse",
    shiftTiming: "Day Shift (6 AM - 6 PM)",
    targetStatus: "on-duty",
    workStatus: "On Duty",
    instructions:
      "Monitor clubhouse and common-area access.",
  },
  {
    uid: "demo-security-05",
    name: "Farhan Ali",
    securityId: "GW-SEC-005",
    phoneNumber: "+910000000105",
    gateId: null,
    shiftTiming: null,
    targetStatus: "off-duty",
    workStatus: "Off Duty",
    instructions: null,
  },
  {
    uid: "demo-security-06",
    name: "Prakash Nair",
    securityId: "GW-SEC-006",
    phoneNumber: "+910000000106",
    gateId: null,
    shiftTiming: null,
    targetStatus: "on-leave",
    workStatus: "On Leave",
    instructions: null,
  },
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

function sleep(ms) {
  return new Promise((resolve) =>
    setTimeout(resolve, ms)
  );
}

function transient(error) {
  return [4, 10, 13, 14].includes(
    Number(error?.code)
  ) ||
    [
      "deadline-exceeded",
      "aborted",
      "internal",
      "unavailable",
    ].includes(
      String(error?.code || "").toLowerCase()
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

  const data = seedAdmin.data() || {};

  if (
    !seedAdmin.exists ||
    data.role !== "admin" ||
    data.isActive !== true ||
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    !Array.isArray(
      data.authorizedCommunityIds
    ) ||
    !data.authorizedCommunityIds.includes(
      COMMUNITY_ID
    )
  ) {
    throw new Error(
      "Expected Green Wave seed admin was not found."
    );
  }
}

function assertGate(snapshot, definition) {
  if (!snapshot.exists) return;

  const data = snapshot.data() || {};

  if (
    data.communityId !== COMMUNITY_ID ||
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    data.seedKey !==
      `gate:${definition.key}` ||
    data.gateName !== definition.gateName ||
    data.gateType !== definition.gateType
  ) {
    throw new Error(
      `Conflicting gate exists at gates/${snapshot.id}.`
    );
  }
}

async function ensureGate(
  db,
  definition,
  apply
) {
  const ref = db
    .collection("gates")
    .doc(definition.id);

  let snapshot = await ref.get();

  assertGate(snapshot, definition);

  if (snapshot.exists) {
    console.log(
      `[OK] Security place: ${definition.gateName}`
    );
    return;
  }

  if (!apply) {
    console.log(
      `[PLAN] Create security place: ${definition.gateName}`
    );
    return;
  }

  const timestamp =
    admin.firestore.FieldValue.serverTimestamp();

  try {
    await ref.create({
      gateName: definition.gateName,
      gateType: definition.gateType,
      workingStatus: "Active",
      shiftTime: definition.shiftTime,

      assignedSecurityId: null,
      assignedSecurityName: null,
      assignedShiftTiming: null,
      assignedSpecialInstructions: null,
      assignedAt: null,

      adminId: SEED_ADMIN.uid,
      communityId: COMMUNITY_ID,
      buildingId: null,
      isArchived: false,

      isDemoData: true,
      seedBatch: SEED_BATCH,
      seedVersion: SEED_VERSION,
      seedKey: `gate:${definition.key}`,

      createdAt: timestamp,
      updatedAt: timestamp,
      createdBy: SEED_ADMIN.uid,
      updatedBy: SEED_ADMIN.uid,
    });
  } catch (error) {
    if (!transient(error)) throw error;

    await sleep(1500);

    snapshot = await ref.get();

    if (!snapshot.exists) throw error;

    assertGate(snapshot, definition);
  }

  console.log(
    `[CREATED] Security place: ${definition.gateName}`
  );
}

function assertStaff(snapshot, definition) {
  if (!snapshot.exists) return;

  const data = snapshot.data() || {};

  if (
    data.uid !== definition.uid ||
    data.communityId !== COMMUNITY_ID ||
    data.role !== "security" ||
    data.name !== definition.name ||
    data.securityId !==
      definition.securityId ||
    data.isDemoData !== true ||
    data.seedBatch !== SEED_BATCH ||
    data.seedKey !==
      `security:${definition.securityId}`
  ) {
    throw new Error(
      `Conflicting security profile exists at securityStaff/${snapshot.id}.`
    );
  }
}

async function ensureStaff(
  db,
  definition,
  apply
) {
  const ref = db
    .collection("securityStaff")
    .doc(definition.uid);

  let snapshot = await ref.get();

  assertStaff(snapshot, definition);

  if (snapshot.exists) {
    console.log(
      `[OK] Security staff: ${definition.name}`
    );
    return;
  }

  if (!apply) {
    console.log(
      `[PLAN] Create seed-only security staff: ${definition.name}`
    );
    return;
  }

  const timestamp =
    admin.firestore.FieldValue.serverTimestamp();

  const assigned =
    definition.gateId != null;

  const initialStatus = assigned
    ? "off-duty"
    : definition.targetStatus;

  const initialWorkStatus = assigned
    ? "Off Duty"
    : definition.workStatus;

  try {
    await ref.create({
      uid: definition.uid,
      communityId: COMMUNITY_ID,
      role: "security",
      isActive: true,

      name: definition.name,
      phoneNumber:
        definition.phoneNumber,
      securityId:
        definition.securityId,

      buildingId: null,
      gateId: null,
      gateAssignment: null,

      shift: null,
      shiftTiming: null,

      workStatus: initialWorkStatus,
      status: initialStatus,

      specialInstructions: null,
      lastWorkAssignment: null,

      // Seed-only profiles deliberately have
      // no Firebase Authentication account.
      loginEnabled: false,

      isDemoData: true,
      seedBatch: SEED_BATCH,
      seedVersion: SEED_VERSION,
      seedKey:
        `security:${definition.securityId}`,

      createdBy: SEED_ADMIN.uid,
      updatedBy: SEED_ADMIN.uid,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  } catch (error) {
    if (!transient(error)) throw error;

    await sleep(1500);

    snapshot = await ref.get();

    if (!snapshot.exists) throw error;

    assertStaff(snapshot, definition);
  }

  console.log(
    `[CREATED] Seed-only security staff: ${definition.name}`
  );
}

function assignmentMatches(
  staff,
  gate,
  definition
) {
  return (
    staff.gateId === definition.gateId &&
    staff.shift ===
      definition.shiftTiming &&
    staff.shiftTiming ===
      definition.shiftTiming &&
    staff.workStatus === "On Duty" &&
    staff.status === "on-duty" &&
    gate.assignedSecurityId ===
      definition.uid &&
    gate.assignedSecurityName ===
      definition.name &&
    gate.assignedShiftTiming ===
      definition.shiftTiming
  );
}

async function ensureAssignment(
  db,
  definition,
  apply
) {
  if (!definition.gateId) return;

  if (!apply) {
    const gate = GATES.find(
      (item) => item.id === definition.gateId
    );

    if (!gate) {
      throw new Error(
        `Unknown gate ${definition.gateId} for ${definition.name}.`
      );
    }

    console.log(
      `[PLAN] Assign ${definition.name} → ${gate.gateName}`
    );
    return;
  }

  const staffRef = db
    .collection("securityStaff")
    .doc(definition.uid);

  const gateRef = db
    .collection("gates")
    .doc(definition.gateId);

  let [staffSnapshot, gateSnapshot] =
    await Promise.all([
      staffRef.get(),
      gateRef.get(),
    ]);

  if (
    !staffSnapshot.exists ||
    !gateSnapshot.exists
  ) {
    throw new Error(
      `Cannot assign ${definition.name}; staff or gate is missing.`
    );
  }

  let staff = staffSnapshot.data() || {};
  let gate = gateSnapshot.data() || {};

  if (
    assignmentMatches(
      staff,
      gate,
      definition
    )
  ) {
    console.log(
      `[OK] Assignment: ${definition.name} → ${gate.gateName}`
    );
    return;
  }

  if (
    gate.assignedSecurityId &&
    gate.assignedSecurityId !==
      definition.uid
  ) {
    throw new Error(
      `${gate.gateName} is already assigned to ${gate.assignedSecurityId}.`
    );
  }

  if (
    staff.gateId &&
    staff.gateId !==
      definition.gateId
  ) {
    throw new Error(
      `${definition.name} is already assigned to another security place.`
    );
  }

  if (!apply) {
    console.log(
      `[PLAN] Assign ${definition.name} → ${gate.gateName}`
    );
    return;
  }

  try {
    await assignSecurityWorkCore({
      db,
      auth: seedAuth(),
      data: {
        communityId: COMMUNITY_ID,
        staffUid: definition.uid,
        gateId: definition.gateId,
        shiftTiming:
          definition.shiftTiming,
        workStatus: "On Duty",
        specialInstructions:
          definition.instructions,
      },
    });
  } catch (error) {
    if (!transient(error)) throw error;

    // A deadline error can arrive after
    // the transaction actually committed.
    await sleep(2000);

    [staffSnapshot, gateSnapshot] =
      await Promise.all([
        staffRef.get(),
        gateRef.get(),
      ]);

    staff = staffSnapshot.data() || {};
    gate = gateSnapshot.data() || {};

    if (
      assignmentMatches(
        staff,
        gate,
        definition
      )
    ) {
      console.log(
        `[RECOVERED] Assignment committed despite timeout: ${definition.name}`
      );
      return;
    }

    throw error;
  }

  [staffSnapshot, gateSnapshot] =
    await Promise.all([
      staffRef.get(),
      gateRef.get(),
    ]);

  staff = staffSnapshot.data() || {};
  gate = gateSnapshot.data() || {};

  if (
    !assignmentMatches(
      staff,
      gate,
      definition
    )
  ) {
    throw new Error(
      `Assignment verification failed for ${definition.name}.`
    );
  }

  console.log(
    `[ASSIGNED] ${definition.name} → ${gate.gateName}`
  );
}

async function ensureUnassignedState(
  db,
  definition,
  apply
) {
  if (definition.gateId) return;

  if (!apply) {
    console.log(
      `[PLAN] Set ${definition.name}: ${definition.workStatus}`
    );
    return;
  }

  const ref = db
    .collection("securityStaff")
    .doc(definition.uid);

  const snapshot = await ref.get();

  if (!snapshot.exists) {
    throw new Error(
      `Security staff ${definition.name} is missing.`
    );
  }

  const data = snapshot.data() || {};

  if (
    data.gateId ||
    data.gateAssignment
  ) {
    throw new Error(
      `${definition.name} unexpectedly has a gate assignment.`
    );
  }

  if (
    data.status ===
      definition.targetStatus &&
    data.workStatus ===
      definition.workStatus
  ) {
    console.log(
      `[OK] ${definition.name}: ${definition.workStatus}`
    );
    return;
  }

  if (!apply) {
    console.log(
      `[PLAN] Set ${definition.name}: ${definition.workStatus}`
    );
    return;
  }

  await ref.update({
    gateId: null,
    gateAssignment: null,
    shift: null,
    shiftTiming: null,
    status:
      definition.targetStatus,
    workStatus:
      definition.workStatus,
    specialInstructions: null,
    lastWorkAssignment: null,
    updatedBy: SEED_ADMIN.uid,
    updatedAt:
      admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(
    `[UPDATED] ${definition.name}: ${definition.workStatus}`
  );
}

async function validateFinalState(db) {
  const gatesSnapshot = await db
    .collection("gates")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const staffSnapshot = await db
    .collection("securityStaff")
    .where(
      "communityId",
      "==",
      COMMUNITY_ID
    )
    .get();

  const gates =
    gatesSnapshot.docs.filter(
      (doc) =>
        doc.data()?.isDemoData === true &&
        doc.data()?.seedBatch ===
          SEED_BATCH
    );

  const staff =
    staffSnapshot.docs.filter(
      (doc) =>
        doc.data()?.isDemoData === true &&
        doc.data()?.seedBatch ===
          SEED_BATCH &&
        doc.data()?.role === "security"
    );

  let activePlaces = 0;
  let assignedPlaces = 0;

  for (const doc of gates) {
    const data = doc.data();

    if (
      data.workingStatus === "Active" &&
      data.isArchived !== true
    ) {
      activePlaces += 1;
    }

    if (data.assignedSecurityId) {
      assignedPlaces += 1;
    }
  }

  let onDuty = 0;
  let offDuty = 0;
  let onLeave = 0;

  for (const doc of staff) {
    const status =
      doc.data()?.status;

    if (status === "on-duty") {
      onDuty += 1;
    } else if (
      status === "on-leave"
    ) {
      onLeave += 1;
    } else if (
      status === "off-duty"
    ) {
      offDuty += 1;
    }
  }

  console.log(
    "\n===== GREEN WAVE SECURITY SUMMARY ====="
  );
  console.log(
    `Security places: ${gates.length}`
  );
  console.log(
    `Active places:   ${activePlaces}`
  );
  console.log(
    `Assigned places: ${assignedPlaces}`
  );
  console.log(
    `Security staff:  ${staff.length}`
  );
  console.log(
    `On duty:         ${onDuty}`
  );
  console.log(
    `Off duty:        ${offDuty}`
  );
  console.log(
    `On leave:        ${onLeave}`
  );

  if (
    gates.length !== 4 ||
    activePlaces !== 4 ||
    assignedPlaces !== 4 ||
    staff.length !== 6 ||
    onDuty !== 4 ||
    offDuty !== 1 ||
    onLeave !== 1
  ) {
    throw new Error(
      "Security totals do not match the expected Green Wave dataset."
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
    admin.initializeApp({
      projectId,
    });
  }

  const db = admin.firestore();

  await requireEnvironment(db);

  console.log(
    "===== HOMINODE DEMO SECURITY ====="
  );
  console.log(`Project:     ${projectId}`);
  console.log(`Community:   ${COMMUNITY_ID}`);
  console.log(`Seed batch:  ${SEED_BATCH}`);
  console.log(
    `Mode:        ${apply ? "APPLY" : "DRY RUN"}`
  );
  console.log("");

  for (const gate of GATES) {
    await ensureGate(
      db,
      gate,
      apply
    );
  }

  for (const person of STAFF) {
    await ensureStaff(
      db,
      person,
      apply
    );
  }

  for (const person of STAFF) {
    if (person.gateId) {
      await ensureAssignment(
        db,
        person,
        apply
      );
    } else {
      await ensureUnassignedState(
        db,
        person,
        apply
      );
    }
  }

  if (apply) {
    await validateFinalState(db);

    console.log(
      "\nDemo security seed complete."
    );
  } else {
    console.log("");
    console.log("Planned security places: 4");
    console.log("Planned security staff:  6");
    console.log("On duty / Off / Leave:   4 / 1 / 1");
    console.log(
      "\nNo Firestore writes performed."
    );
  }
}

main().catch((error) => {
  console.error(
    "\nDemo security seed failed."
  );
  console.error(error);
  process.exitCode = 1;
});
