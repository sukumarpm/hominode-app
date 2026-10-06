#!/usr/bin/env node

const admin = require("firebase-admin");
const { createCommunityCore } = require("../src/create_community");

const COMMUNITY_ID = "GREEN-WAVE";
const SEED_BATCH = "green-wave-2027-v1";

const COMMUNITY = {
  communityId: COMMUNITY_ID,
  name: "Green Wave Residences",
  brandName: "Green Wave",
  slug: "green-wave",
  websitePath: "green-wave",
  databaseId: "(default)",
  timeZone: "Asia/Kolkata",
  locationConfigured: true,
  location: {
    latitude: 12.9698,
    longitude: 77.7500,
    formattedAddress:
      "Green Wave Residences, Whitefield, Bengaluru, Karnataka 560066, India",
    placeId: null,
    attendanceRadiusMeters: 250,
  },
};

function hasArg(name) {
  return process.argv.includes(name);
}

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
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

  const superAdminUid =
    valueArg("--super-admin-uid") ||
    process.env.SEED_SUPER_ADMIN_UID;

  if (projectId !== "hominode-prod") {
    throw new Error(
      `Refusing to run against unexpected project: ${projectId}`
    );
  }

  if (!superAdminUid) {
    throw new Error(
      "Provide --super-admin-uid <uid> or SEED_SUPER_ADMIN_UID."
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp({ projectId });
  }

  const db = admin.firestore();

  const adminSnapshot = await db
    .collection("admins")
    .doc(superAdminUid)
    .get();

  if (!adminSnapshot.exists) {
    throw new Error(`Super admin ${superAdminUid} was not found.`);
  }

  const superAdmin = adminSnapshot.data() || {};

  if (
    superAdmin.uid !== superAdminUid ||
    superAdmin.role !== "superAdmin" ||
    superAdmin.isActive !== true
  ) {
    throw new Error(
      `${superAdminUid} is not an active superAdmin profile.`
    );
  }

  const phoneNumber =
    typeof superAdmin.phoneNumber === "string"
      ? superAdmin.phoneNumber.trim()
      : typeof superAdmin.phone === "string"
        ? superAdmin.phone.trim()
        : "";

  if (!/^\+[1-9]\d{7,14}$/.test(phoneNumber)) {
    throw new Error(
      "The selected superAdmin must have a valid E.164 phone number."
    );
  }

  console.log("===== HOMINODE DEMO COMMUNITY =====");
  console.log(`Project:       ${projectId}`);
  console.log(`Community:     ${COMMUNITY.name}`);
  console.log(`Community ID:  ${COMMUNITY.communityId}`);
  console.log(`Seed batch:    ${SEED_BATCH}`);
  console.log(`Creator UID:   ${superAdminUid}`);
  console.log(`Mode:          ${apply ? "APPLY" : "DRY RUN"}`);

  if (!apply) {
    console.log("\nNo Firestore writes performed.");
    console.log("Re-run with --apply after reviewing the values above.");
    return;
  }

  const auth = {
    uid: superAdminUid,
    token: {
      phone_number: phoneNumber,
      firebase: {
        sign_in_provider: "phone",
      },
    },
  };

  const result = await createCommunityCore({
    db,
    auth,
    data: COMMUNITY,
  });

  const communityRef = db
    .collection("communities")
    .doc(COMMUNITY_ID);

  await communityRef.set(
    {
      isDemoData: true,
      seedBatch: SEED_BATCH,
      seedVersion: 1,
      demoProfile: "modern-india-2027",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const snapshot = await communityRef.get();
  const created = snapshot.data() || {};

  console.log("\n===== RESULT =====");
  console.log(`Community ID: ${snapshot.id}`);
  console.log(`Created:      ${snapshot.exists}`);
  console.log(`Idempotent:   ${result.idempotent}`);
  console.log(`Name:         ${created.name}`);
  console.log(`Slug:         ${created.slug}`);
  console.log(`Time zone:    ${created.timeZone}`);
  console.log(`Demo data:    ${created.isDemoData === true}`);
  console.log(`Seed batch:   ${created.seedBatch}`);

  console.log("\nDemo community creation complete.");
}

main().catch((error) => {
  console.error("\nDemo community creation failed.");
  console.error(error);
  process.exitCode = 1;
});
