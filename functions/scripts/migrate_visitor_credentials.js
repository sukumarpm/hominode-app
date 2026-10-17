#!/usr/bin/env node
// Dry-run by default. This script intentionally cannot apply to hominode-prod.
const {initializeApp, getApps} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {resolveFlatOccupant} = require("../src/resident_identity");
const {
  credentialHash,
  normalizeManualCode,
  planLegacyCredentialMigration,
  validManualCode,
  validQrToken,
  visitorEligible,
} = require("../src/visitor_credentials");

function millis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (Number.isFinite(value)) return value;
  return null;
}

function sameTime(left, right) {
  const leftMs = millis(left);
  return leftMs != null && leftMs === millis(right);
}

function indexMatches(index, {visitorId, communityId, type, validFrom, expiresAt}) {
  return index?.visitorId === visitorId && index.communityId === communityId &&
    index.credentialType === type && index.credentialVersion === 1 &&
    sameTime(index.validFrom, validFrom) && sameTime(index.expiresAt, expiresAt);
}

function privateSetMatches(credentials, visitor, hostUserId) {
  return credentials?.hostUserId === hostUserId &&
    credentials.communityId === visitor.communityId &&
    credentials.credentialVersion === 1 && validQrToken(credentials.qrToken) &&
    validManualCode(credentials.manualCode) &&
    (visitor.credentialValidFrom == null || sameTime(credentials.validFrom, visitor.credentialValidFrom)) &&
    (visitor.credentialExpiresAt == null || sameTime(credentials.expiresAt, visitor.credentialExpiresAt));
}

function isTerminal(visitor) {
  const status = String(visitor?.status || "").trim().toLowerCase();
  return ["completed", "departed", "checked_out", "checked-out", "exited",
    "rejected", "cancelled", "canceled"].includes(status) ||
    visitor?.actualArrival != null || visitor?.departure != null;
}

function hostEligible(host, hostUserId, communityId, community, flat) {
  if (host?.uid !== hostUserId || host.role !== "resident" ||
      host.communityId !== communityId || host.isActive !== true ||
      host.approvalStatus !== "approved" ||
      (host.status != null && host.status !== "active") || community?.isActive !== true ||
      typeof host.phoneNumber !== "string" || !host.phoneNumber.trim() ||
      typeof host.flatId !== "string" || !host.flatId.trim() ||
      flat?.communityId !== communityId || flat?.status !== "occupied") return false;
  let occupant;
  try { occupant = resolveFlatOccupant(flat); } catch (_) { return false; }
  if (occupant?.uid !== hostUserId) return false;
  const residentType = host.residentType ?? host.ownershipType;
  return residentType === "owner"
    ? community.ownerIdentityVerificationRequired !== true ||
      (host.identityVerified === true && host.identityVerificationStatus === "verified")
    : residentType === "tenant" && host.identityVerified === true &&
      host.identityVerificationStatus === "verified";
}

function assertMigrationMode({project, apply}) {
  if (project === "hominode-prod" && apply) {
    throw Error("Production apply is disabled in this migration script; use a separately reviewed and approved production procedure.");
  }
}

function safeIssue(visitorId, issue) {
  return {visitorId, issue};
}

async function run({db, hmacKey, apply = false, now = Date.now}) {
  const snapshot = await db.collection("visitors").get();
  const counts = {
    scanned: 0, ready: 0, legacySunsetEligible: 0, alreadyMigrated: 0, skipped: 0, conflicts: 0,
    missingHosts: 0, invalidHosts: 0, duplicateManualCodes: 0,
    invalidManualCodes: 0,
    invalidQrTokens: 0, missingQrTokens: 0, missingManualCodes: 0,
    terminalRecords: 0, conflictingIndexes: 0,
  };
  const discrepancies = [];
  const plannedHashes = new Map();
  const sourceManualOwners = new Map();
  const duplicateManualVisitorIds = new Set();

  for (const doc of snapshot.docs) {
    const visitor = doc.data();
    if (visitor.credentialVersion === 1 || visitor.visitorPassCode == null ||
        !validManualCode(visitor.visitorPassCode)) continue;
    const hash = credentialHash(hmacKey, "manual", normalizeManualCode(visitor.visitorPassCode));
    const owners = sourceManualOwners.get(hash) || [];
    owners.push(doc.id);
    sourceManualOwners.set(hash, owners);
  }
  for (const owners of sourceManualOwners.values()) {
    if (owners.length < 2) continue;
    for (const visitorId of owners) duplicateManualVisitorIds.add(visitorId);
  }
  counts.duplicateManualCodes = duplicateManualVisitorIds.size;
  for (const visitorId of duplicateManualVisitorIds) {
    discrepancies.push(safeIssue(visitorId, "duplicate_manual_code_will_be_reissued"));
  }

  for (const doc of snapshot.docs) {
    counts.scanned++;
    const visitor = doc.data();
    if (visitor.credentialVersion !== 1) {
      if (visitor.qrToken == null) counts.missingQrTokens++;
      else if (!validQrToken(visitor.qrToken)) {
        counts.invalidQrTokens++;
        discrepancies.push(safeIssue(doc.id, "invalid_qr_token_will_be_replaced"));
      }
      if (visitor.visitorPassCode == null) counts.missingManualCodes++;
      else if (!validManualCode(visitor.visitorPassCode)) {
        counts.invalidManualCodes++;
        discrepancies.push(safeIssue(doc.id, "invalid_manual_code_will_be_replaced"));
      }
    }
    if (isTerminal(visitor)) {
      counts.terminalRecords++;
      counts.skipped++;
      discrepancies.push(safeIssue(doc.id, "terminal_visit"));
      continue;
    }
    const hostUserId = visitor.hostUserId || visitor.residentId;
    if (!hostUserId || !visitor.communityId ||
        (visitor.hostUserId && visitor.residentId && visitor.hostUserId !== visitor.residentId)) {
      counts.missingHosts++;
      counts.skipped++;
      discrepancies.push(safeIssue(doc.id, "missing_or_conflicting_host_attribution"));
      continue;
    }
    const hostSnapshot = await db.collection("users").doc(hostUserId).get();
    const host = hostSnapshot.data();
    if (!hostSnapshot.exists) {
      counts.missingHosts++;
      counts.skipped++;
      discrepancies.push(safeIssue(doc.id, "host_profile_missing"));
      continue;
    }
    if (host.uid !== hostUserId || host.role !== "resident" ||
        host.communityId !== visitor.communityId || host.isActive !== true ||
        host.approvalStatus !== "approved") {
      counts.invalidHosts++;
      counts.skipped++;
      discrepancies.push(safeIssue(doc.id, "host_profile_not_eligible"));
      continue;
    }
    const communitySnapshot = await db.collection("communities").doc(visitor.communityId).get();
    const flatSnapshot = host.flatId ? await db.collection("flats").doc(host.flatId).get() : null;
    if (!hostEligible(host, hostUserId, visitor.communityId, communitySnapshot.data(), flatSnapshot?.data())) {
      counts.invalidHosts++;
      counts.skipped++;
      discrepancies.push(safeIssue(doc.id, "host_profile_not_eligible"));
      continue;
    }
    const credentialRef = db.collection("visitorHostCredentials").doc(doc.id);
    const existing = await credentialRef.get();
    if (existing.exists) {
      const credentials = existing.data();
      if (!privateSetMatches(credentials, visitor, hostUserId)) {
        counts.conflicts++;
        discrepancies.push(safeIssue(doc.id, "existing_credential_inconsistent"));
        continue;
      }
      const qrIndex = db.collection("visitorGateCredentialIndex")
        .doc(credentialHash(hmacKey, "qr", credentials.qrToken)).get();
      const manualIndex = db.collection("visitorGateCredentialIndex")
        .doc(credentialHash(hmacKey, "manual", credentials.manualCode)).get();
      const [qrSnapshot, manualSnapshot] = await Promise.all([qrIndex, manualIndex]);
      const qrOk = indexMatches(qrSnapshot.data(), {
        visitorId: doc.id, communityId: visitor.communityId, type: "qr",
        validFrom: credentials.validFrom, expiresAt: credentials.expiresAt,
      });
      const manualOk = indexMatches(manualSnapshot.data(), {
        visitorId: doc.id, communityId: visitor.communityId, type: "manual",
        validFrom: credentials.validFrom, expiresAt: credentials.expiresAt,
      });
      if (!qrOk || !manualOk) {
        counts.conflicts++;
        counts.conflictingIndexes += Number(!qrOk) + Number(!manualOk);
        discrepancies.push(safeIssue(doc.id, "existing_credential_or_index_inconsistent"));
        continue;
      }
      if (visitor.credentialVersion === 1) {
        counts.alreadyMigrated++;
        continue;
      }
      counts.ready++;
      counts.legacySunsetEligible++;
      if (!apply) continue;
      try {
        await db.runTransaction(async (tx) => {
          const [current, currentCredentials, currentQr, currentManual, currentHost, currentCommunity, currentFlat] = await Promise.all([
            tx.get(db.collection("visitors").doc(doc.id)), tx.get(credentialRef),
            tx.get(db.collection("visitorGateCredentialIndex").doc(credentialHash(hmacKey, "qr", credentials.qrToken))),
            tx.get(db.collection("visitorGateCredentialIndex").doc(credentialHash(hmacKey, "manual", credentials.manualCode))),
            tx.get(db.collection("users").doc(hostUserId)),
            tx.get(db.collection("communities").doc(visitor.communityId)),
            tx.get(db.collection("flats").doc(host.flatId)),
          ]);
          if (!current.exists || !currentCredentials.exists ||
              !privateSetMatches(currentCredentials.data(), current.data(), hostUserId) ||
              !indexMatches(currentQr.data(), {visitorId: doc.id, communityId: visitor.communityId,
                type: "qr", validFrom: credentials.validFrom, expiresAt: credentials.expiresAt}) ||
              !indexMatches(currentManual.data(), {visitorId: doc.id, communityId: visitor.communityId,
                type: "manual", validFrom: credentials.validFrom, expiresAt: credentials.expiresAt}) ||
              !currentHost.exists || !hostEligible(currentHost.data(), hostUserId, visitor.communityId,
                currentCommunity.data(), currentFlat.data())) {
            throw Error("existing_credential_changed");
          }
          tx.update(db.collection("visitors").doc(doc.id), {
            hostUserId,
            credentialVersion: 1,
            credentialValidFrom: credentials.validFrom,
            credentialExpiresAt: credentials.expiresAt,
            credentialMigratedAt: FieldValue.serverTimestamp(),
            legacyCredentialSunsetAt: FieldValue.serverTimestamp(),
          });
        });
      } catch (_) {
        counts.ready--;
        counts.legacySunsetEligible--;
        counts.conflicts++;
        discrepancies.push(safeIssue(doc.id, "migration_race"));
      }
      continue;
    }

    const plan = planLegacyCredentialMigration({visitorId: doc.id, visitor, hmacKey, now: now(),
      forceNewManualCode: duplicateManualVisitorIds.has(doc.id)});
    if (plan.action !== "migrate") {
      counts.skipped++;
      discrepancies.push(safeIssue(doc.id, plan.reason));
      continue;
    }

    const qrRef = db.collection("visitorGateCredentialIndex").doc(plan.qrHash);
    const manualRef = db.collection("visitorGateCredentialIndex").doc(plan.manualHash);
    const [qrIndex, manualIndex] = await Promise.all([qrRef.get(), manualRef.get()]);
    const qrCollision = qrIndex.exists && !indexMatches(qrIndex.data(), {
      visitorId: doc.id, communityId: plan.communityId, type: "qr",
      validFrom: plan.validFrom, expiresAt: plan.expiresAt,
    });
    const manualCollision = manualIndex.exists && !indexMatches(manualIndex.data(), {
      visitorId: doc.id, communityId: plan.communityId, type: "manual",
      validFrom: plan.validFrom, expiresAt: plan.expiresAt,
    });
    const duplicatePlannedManual = plannedHashes.get(plan.manualHash);
    if (manualCollision || (duplicatePlannedManual && duplicatePlannedManual.visitorId !== doc.id)) {
      counts.conflicts++;
      counts.duplicateManualCodes++;
      counts.conflictingIndexes += Number(manualCollision);
      discrepancies.push(safeIssue(doc.id, "duplicate_manual_code"));
      continue;
    }
    if (qrCollision || (plannedHashes.has(plan.qrHash) && plannedHashes.get(plan.qrHash).visitorId !== doc.id)) {
      counts.conflicts++;
      counts.conflictingIndexes += Number(qrCollision);
      discrepancies.push(safeIssue(doc.id, "credential_index_conflict"));
      continue;
    }
    plannedHashes.set(plan.qrHash, {visitorId: doc.id, type: "qr"});
    plannedHashes.set(plan.manualHash, {visitorId: doc.id, type: "manual"});
    counts.ready++;
    counts.legacySunsetEligible++;
    if (!apply) continue;

    try {
      await db.runTransaction(async (tx) => {
        const visitorRef = db.collection("visitors").doc(doc.id);
        const currentQrRef = db.collection("visitorGateCredentialIndex").doc(plan.qrHash);
        const currentManualRef = db.collection("visitorGateCredentialIndex").doc(plan.manualHash);
        const [current, currentCredentials, currentQr, currentManual, currentHost, currentCommunity, currentFlat] = await Promise.all([
          tx.get(visitorRef), tx.get(credentialRef), tx.get(currentQrRef), tx.get(currentManualRef),
          tx.get(db.collection("users").doc(hostUserId)), tx.get(db.collection("communities").doc(plan.communityId)),
          tx.get(db.collection("flats").doc(host.flatId)),
        ]);
        if (!current.exists) throw Error("migration_race");
        const currentVisitor = current.data();
        const currentHostProfile = currentHost.data();
        if (currentCredentials.exists) throw Error("migration_race");
        if ((currentVisitor.hostUserId || null) !== plan.sourceHostUserId ||
            (currentVisitor.residentId || null) !== plan.sourceResidentId ||
            currentVisitor.communityId !== plan.communityId ||
            currentVisitor.credentialVersion === 1 ||
            !visitorEligible(currentVisitor, now()) ||
            (currentVisitor.qrToken ?? null) !== plan.sourceQrValue ||
            (currentVisitor.visitorPassCode ?? null) !== plan.sourceManualValue ||
            !currentHost.exists || currentHostProfile?.uid !== hostUserId ||
            !currentHost.exists || !currentCommunity.exists || !currentFlat.exists ||
            !hostEligible(currentHostProfile, hostUserId, plan.communityId,
              currentCommunity.data(), currentFlat.data())) {
          throw Error("migration_race");
        }
        if ((currentQr.exists && !indexMatches(currentQr.data(), {visitorId: doc.id,
          communityId: plan.communityId, type: "qr", validFrom: plan.validFrom, expiresAt: plan.expiresAt})) ||
            (currentManual.exists && !indexMatches(currentManual.data(), {visitorId: doc.id,
              communityId: plan.communityId, type: "manual", validFrom: plan.validFrom, expiresAt: plan.expiresAt}))) {
          throw Error("credential_index_conflict");
        }
        tx.create(credentialRef, {
          hostUserId, communityId: plan.communityId,
          qrToken: plan.qrToken, manualCode: plan.manualCode,
          credentialVersion: 1, validFrom: plan.validFrom, expiresAt: plan.expiresAt,
          createdAt: FieldValue.serverTimestamp(), migratedAt: FieldValue.serverTimestamp(),
        });
        if (!currentQr.exists) tx.create(currentQrRef, {
          visitorId: doc.id, communityId: plan.communityId, credentialType: "qr",
          credentialVersion: 1, validFrom: plan.validFrom, expiresAt: plan.expiresAt,
          createdAt: FieldValue.serverTimestamp(),
        });
        if (!currentManual.exists) tx.create(currentManualRef, {
          visitorId: doc.id, communityId: plan.communityId, credentialType: "manual",
          credentialVersion: 1, validFrom: plan.validFrom, expiresAt: plan.expiresAt,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.update(visitorRef, {
          hostUserId,
          credentialVersion: 1,
          credentialValidFrom: plan.validFrom,
          credentialExpiresAt: plan.expiresAt,
          credentialMigratedAt: FieldValue.serverTimestamp(),
          legacyCredentialSunsetAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      counts.ready--;
      counts.legacySunsetEligible--;
      counts.conflicts++;
      if (error.message === "credential_index_conflict") counts.conflictingIndexes++;
      discrepancies.push(safeIssue(doc.id, error.message === "credential_index_conflict" ?
        "credential_index_conflict" : "migration_race"));
    }
  }
  return {counts, discrepancies};
}

async function main() {
  const args = new Set(process.argv.slice(2));
  const apply = args.has("--apply");
  const projectFlag = process.argv.find((arg) => arg.startsWith("--confirm-project="));
  const project = projectFlag?.split("=")[1];
  const configuredProject = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  if (!configuredProject || project !== configuredProject) {
    throw Error("Pass --confirm-project=<active-project-id> matching the configured Firebase project.");
  }
  assertMigrationMode({project: configuredProject, apply});
  const hmacKey = process.env.VISITOR_CREDENTIAL_HMAC_KEY;
  if (!hmacKey || Buffer.byteLength(hmacKey) < 32) {
    throw Error("Set VISITOR_CREDENTIAL_HMAC_KEY to the Secret Manager value; it is never printed.");
  }
  if (!getApps().length) initializeApp({projectId: configuredProject});
  const result = await run({db: getFirestore(), hmacKey, apply});
  console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", project: configuredProject, ...result}, null, 2));
}

if (require.main === module) main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

module.exports = {assertMigrationMode, run};
