"use strict";

// One-time manifest from the read-only Green Wave inspection, 2026-10-31.
// Default: node scripts/cleanup-green-wave-unit-allocation.js
// Writes:  node scripts/cleanup-green-wave-unit-allocation.js --apply
// No discovery-based writes: newly rejected/deleted accounts are outside this manifest.
const { initializeApp, applicationDefault, deleteApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { assertSafelyVacant, occupancyStats, unitLabel } = require("../src/unit_schema");

const PROJECT = "hominode-prod";
const COMMUNITY = "GREEN-WAVE";
const TARGET = Object.freeze({
  flatId: "EhO9WqWKRbXTEwVfZo5L", buildingId: "8dyUGzQtKgo8n5EGrlHF",
  uid: "XtMKuKEe0VeKXahBZC6A6UJjYAz1", requestId: "z3d8gdJlMbDcsmQw4dhK",
  label: "N016", residentType: "owner",
});
const ensure = (condition, reason) => { if (!condition) throw new Error(reason); };
const millis = (value) => value?.toMillis?.() ?? null;

function verifyEvidence({ community, request, cleanup, profileStep, authStep, unit, profileExists }) {
  ensure(community?.name === "Green Wave Residences" && community.isActive === true && community.isDemoData === true,
    "Community identity, development-data marker, or activity changed.");
  ensure(request?.requestId === TARGET.requestId && request.uid === TARGET.uid && request.sourceApp === "resident" &&
    request.communityId === COMMUNITY && request.communityScopeVerified === true && request.status === "completed" &&
    request.completionVerified === true && request.authUidDeleted === TARGET.uid &&
    request.residentProfilePath === `users/${TARGET.uid}` && millis(request.completedAt) > 0,
  "Verified completed Resident deletion evidence is missing or changed.");
  for (const field of ["processingBlockers", "lastEligibilityBlockers", "blockers", "unresolvedChecks"]) {
    ensure(request[field] == null || Array.isArray(request[field]) && request[field].length === 0,
      `Deletion has unresolved or ambiguous ${field}; skip without reconciliation.`);
  }
  ensure(!request.reconciliationReason && !request.reconciliationStep && request.processing !== true,
    "Deletion retains reconciliation or in-flight processing state.");
  ensure(!profileExists, "Resident profile exists; never release an existing Resident's allocation.");
  for (const step of [cleanup, profileStep, authStep]) {
    ensure(step?.requestId === TARGET.requestId && step.uid === TARGET.uid && step.status === "completed",
      "Request-bound deletion processing evidence is incomplete.");
  }
  ensure(profileStep.communityId === COMMUNITY && profileStep.verifiedAbsent === true && authStep.verifiedAbsent === true &&
    authStep.operationStarted === true, "Profile/Auth completion cannot be verified.");
  ensure(Array.isArray(cleanup.memberships) && cleanup.memberships.some((m) =>
    m.collection === "flats" && m.id === TARGET.flatId && m.communityId === COMMUNITY),
  "Completed cleanup does not bind the deleted Resident to this exact unit.");
  ensure(unit?.communityId === COMMUNITY && unit.buildingId === TARGET.buildingId && unitLabel(unit) === TARGET.label,
    "Unit identity, label, or building changed.");
  // Older requests did not retain residentType. The pinned original unit retains
  // ownershipType; the timestamp guard below requires no post-cleanup unit edit.
  ensure(unit.ownershipType === TARGET.residentType &&
    (unit.residentType == null || unit.residentType === TARGET.residentType) &&
    (request.retainedResidentIdentity?.residentType == null || request.retainedResidentIdentity.residentType === TARGET.residentType),
  "Owner/tenant evidence is missing or inconsistent.");
  ensure(["occupied", "vacant"].includes(unit.status), "Unit is reserved, under maintenance, or has an unsupported status.");
  // Preserves shared occupants, all UID aliases, reservations, and inactive units.
  assertSafelyVacant({ ...unit, status: "vacant" });
  if (unit.status !== "vacant") {
    ensure(millis(unit.updatedAt) > 0 && millis(cleanup.completedAt) > 0 &&
      millis(unit.updatedAt) <= millis(cleanup.completedAt),
    "Unit was edited after deletion cleanup; possible reassignment requires skipping.");
  }
}

async function verifyAuthAbsent(auth) {
  try { await auth.getUser(TARGET.uid); }
  catch (error) { if (error.code === "auth/user-not-found") return; throw error; }
  throw new Error("Deleted Resident exists in Firebase Auth; skip.");
}

async function inspectOrApply({ db, auth, apply = false }) {
  await verifyAuthAbsent(auth);
  return db.runTransaction(async (tx) => {
    const requestRef = db.collection("accountDeletionRequests").doc(TARGET.requestId);
    const unitRef = db.collection("flats").doc(TARGET.flatId);
    const buildingRef = db.collection("buildings").doc(TARGET.buildingId);
    const [community, request, cleanup, profileStep, authStep, unit, profile, building] = await Promise.all([
      tx.get(db.collection("communities").doc(COMMUNITY)), tx.get(requestRef),
      tx.get(requestRef.collection("processing").doc("membershipAndBookingCleanup")),
      tx.get(requestRef.collection("processing").doc("residentProfile")),
      tx.get(requestRef.collection("processing").doc("firebaseAuth")), tx.get(unitRef),
      tx.get(db.collection("users").doc(TARGET.uid)), tx.get(buildingRef),
    ]);
    verifyEvidence({community: community.data(), request: request.data(), cleanup: cleanup.data(),
      profileStep: profileStep.data(), authStep: authStep.data(), unit: unit.data(), profileExists: profile.exists});
    ensure(building.exists && building.data().communityId === COMMUNITY && building.data().isActive !== false,
      "Building is missing, inactive, or outside Green Wave.");
    // Canonical document IDs are global. Any reverse assignment, including an
    // inactive profile or a foreign-community reference, prevents release.
    for (const collection of ["users", "residentOnboarding"]) {
      for (const field of ["flatId", "unitId"]) {
        const matches = await tx.get(db.collection(collection).where(field, "==", TARGET.flatId).limit(1));
        ensure(matches.empty, `Conflicting ${collection}.${field} assignment; preserve it and skip.`);
      }
    }
    const units = await tx.get(db.collection("flats").where("buildingId", "==", TARGET.buildingId));
    ensure(units.docs.every((d) => d.data().communityId === COMMUNITY), "Building contains cross-community unit data.");
    const alreadyVacant = unit.data().status === "vacant";
    const before = occupancyStats(units.docs);
    const after = occupancyStats(units.docs, new Map([[TARGET.flatId, "vacant"]]));
    await verifyAuthAbsent(auth);
    const result = { unit: `flats/${TARGET.flatId}`, label: TARGET.label, building: TARGET.buildingId,
      requestId: TARGET.requestId, reason: "Verified completed owner account deletion; original membership cleared but unit status remains occupied.",
      action: alreadyVacant ? "SKIP_ALREADY_VACANT" : "RELEASE_STATUS_AND_UPDATE_COUNTERS",
      affectedUnits: alreadyVacant ? 0 : 1, from: unit.data().status, to: "vacant", countersBefore: before,
      countersStored: Object.fromEntries(["occupied", "vacant", "reserved", "occupancyRate"].map((k) => [k, building.data()[k] ?? null])),
      countersAfter: after, writes: apply && !alreadyVacant ? 2 : 0 };
    if (apply && !alreadyVacant) {
      tx.update(unitRef, { status: "vacant", updatedAt: FieldValue.serverTimestamp() });
      tx.update(buildingRef, { ...after, updatedAt: FieldValue.serverTimestamp() });
    }
    return result;
  }, apply ? {} : { readOnly: true });
}

async function main() {
  const args = process.argv.slice(2);
  ensure(args.length <= 1 && args.every((a) => ["--dry-run", "--apply"].includes(a)), "Use no argument, --dry-run, or --apply.");
  ensure(!process.env.FIRESTORE_EMULATOR_HOST && !process.env.FIREBASE_AUTH_EMULATOR_HOST,
    "Emulator overrides are not allowed for this fixed project.");
  const apply = args.includes("--apply");
  const app = initializeApp({ projectId: PROJECT, credential: applicationDefault() }, "green-wave-allocation-cleanup");
  try {
    const result = await inspectOrApply({ db: getFirestore(app), auth: getAuth(app), apply });
    console.log(JSON.stringify({ mode: apply ? "APPLY" : "DRY_RUN", project: PROJECT, communityId: COMMUNITY, ...result }, null, 2));
  } finally { await deleteApp(app); }
}

if (require.main === module) main().catch((error) => {
  console.error(JSON.stringify({ action: "SKIP", affectedUnits: 0, reason: error.message }));
  process.exitCode = 1;
});
module.exports = { TARGET, verifyEvidence, inspectOrApply };
