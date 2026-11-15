"use strict";

// One-time, request-bound repair. Uses Application Default Credentials only.
// No writes unless --apply is explicitly supplied. Never changes other records.
const { initializeApp, applicationDefault, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { assertSafelyVacant } = require("../src/unit_schema");

const PROJECT = "hominode-prod";
const COMMUNITY = "GREEN-WAVE";
const UNIT = "EhO9WqWKRbXTEwVfZo5L";
const UID = "XtMKuKEe0VeKXahBZC6A6UJjYAz1";
const REQUEST = "z3d8gdJlMbDcsmQw4dhK";

function requireCondition(condition, message) {
  if (!condition) throw new Error(`ABORT: ${message}`);
}

async function main() {
  const args = process.argv.slice(2);
  requireCondition(args.length <= 1 && args.every((arg) => ["--dry-run", "--apply"].includes(arg)),
    "Use no argument, --dry-run, or --apply.");
  requireCondition(!process.env.FIRESTORE_EMULATOR_HOST && !process.env.FIREBASE_AUTH_EMULATOR_HOST,
    "Emulator overrides are not allowed for this production-bound repair.");
  const apply = args.includes("--apply");
  console.log(JSON.stringify({ mode: apply ? "APPLY" : "DRY RUN", project: PROJECT,
    unitPath: `flats/${UNIT}`, community: COMMUNITY, deletedUid: UID, requestId: REQUEST }));
  const app = initializeApp({ projectId: PROJECT, credential: applicationDefault() }, "vacant-unit-repair");
  try {
    const db = getFirestore(app);
    const auth = getAuth(app);
    const unitRef = db.collection("flats").doc(UNIT);
    const requestRef = db.collection("accountDeletionRequests").doc(REQUEST);
    async function verifyAuthAbsent() {
      try {
        await auth.getUser(UID);
      } catch (error) {
        if (error.code === "auth/user-not-found") return;
        throw error;
      }
      throw new Error("ABORT: The deleted UID still exists in Firebase Auth.");
    }
    await verifyAuthAbsent();
    const result = await db.runTransaction(async (tx) => {
      const [unitDoc, requestDoc, cleanupDoc, profileDoc, communityDoc] = await Promise.all([
        tx.get(unitRef), tx.get(requestRef),
        tx.get(requestRef.collection("processing").doc("membershipAndBookingCleanup")),
        tx.get(db.collection("users").doc(UID)),
        tx.get(db.collection("communities").doc(COMMUNITY)),
      ]);
      const unit = unitDoc.data();
      const request = requestDoc.data();
      const cleanup = cleanupDoc.data();
      requireCondition(unitDoc.exists && unit.communityId === COMMUNITY, "Unit community mismatch or unit missing.");
      requireCondition(communityDoc.exists && communityDoc.data().isActive === true, "Community is not confirmed active.");
      requireCondition(requestDoc.exists && request.uid === UID && request.communityId === COMMUNITY &&
        request.status === "completed", "Matching completed deletion request is missing.");
      requireCondition(cleanupDoc.exists && cleanup.uid === UID && cleanup.requestId === REQUEST &&
        cleanup.status === "completed" && Array.isArray(cleanup.memberships) &&
        cleanup.memberships.some((item) => item.collection === "flats" && item.id === UNIT && item.communityId === COMMUNITY),
      "Completed cleanup evidence does not bind this UID to this unit.");
      requireCondition(!profileDoc.exists, "The deleted Resident profile still exists.");
      requireCondition(["occupied", "vacant"].includes(unit.status), "Unexpected unit status.");
      // Reuse the same vacancy guard as Admin assignment. This rejects remaining
      // UID aliases, shared memberships, reservations, and inactive units.
      assertSafelyVacant({ ...unit, status: "vacant" });
      requireCondition(typeof unit.buildingId === "string" && unit.buildingId.trim() !== "", "Building reference is missing.");
      const building = await tx.get(db.collection("buildings").doc(unit.buildingId));
      requireCondition(building.exists && building.data().communityId === COMMUNITY && building.data().isActive !== false,
        "Building scope or activity cannot be verified.");
      // No community filter: a foreign-community reverse assignment is also a conflict.
      // Any profile, including inactive ones, requires manual reconciliation.
      for (const collection of ["users", "residentOnboarding"]) {
        for (const field of ["flatId", "unitId"]) {
          const matches = await tx.get(db.collection(collection).where(field, "==", UNIT).limit(1));
          requireCondition(matches.empty, `Conflicting ${collection}.${field} assignment exists.`);
        }
      }
      await verifyAuthAbsent();
      const changes = unit.status === "vacant" ? {} : { status: { from: "occupied", to: "vacant" } };
      if (apply && unit.status !== "vacant") tx.update(unitRef, { status: "vacant" });
      return { verified: true, changes, alreadyVacant: unit.status === "vacant" };
    }, apply ? {} : { readOnly: true });
    console.log(JSON.stringify({ ...result, writes: apply && !result.alreadyVacant ? 1 : 0,
      result: apply ? "Repair transaction completed" : "DRY RUN passed; no writes performed" }, null, 2));
  } finally {
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(`Repair stopped; verification did not complete: ${error.message}`);
  process.exitCode = 1;
});
