"use strict";

// Read-only, single-request account-deletion diagnostic. Uses the existing
// eligibility discovery core and deliberately prints no profile fields,
// notification contents, proof contents, actor UID, or target UID.
const { initializeApp, applicationDefault, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { reviewAccountDeletionEligibilityCore } = require("../src/account_deletion_requests");

const PROJECT = "hominode-prod";
const STORAGE_BUCKET = "hominode-prod.firebasestorage.app";
const REQUEST_ID = "0bGkEa01DjQ6imlUoY16";

function safePath(path, uid) {
  return typeof path === "string" && uid ? path.split(uid).join("[resident-uid]") : path ?? null;
}

function unresolved(report, checks) {
  return report.unresolvedChecks.filter((item) => checks.has(item.check)).map(({ check, reason }) => ({ check, reason }));
}

function safeCheckName(check) {
  // Eligibility uses the matched visitor ID in this internal check key.
  return check.startsWith("visitorCredential:") ? "visitorCredential" : check;
}

function buildDiagnostic(report) {
  const uid = report.uid;
  const communityId = report.linkedProfiles?.users?.communityId ?? report.communities?.[0] ?? null;
  const references = report.coverage?.additionalResidentReferences ?? {};
  const notificationClass = references.notifications ?? {};
  const deviceClass = references.notificationDevices ?? {};
  const auditHistory = report.coverage?.preservedHistoricalReferences?.find((item) => item.type === "audit_history");
  const identity = report.eligiblePersonalRecords?.find((item) => item.type === "identity_proof_upload");
  const identityChecks = new Set(["identityProofOwnership", "identityProofReview", "identityProofLegalHold", "identityProofStorage"]);
  const notificationChecks = new Set(["reference:notifications"]);
  const deviceChecks = new Set(["reference:notificationDevices"]);
  const auditChecks = new Set(["auditRetentionCondition"]);
  const surfacedChecks = new Set([...identityChecks, ...notificationChecks, ...deviceChecks, ...auditChecks]);
  const otherBlockers = report.unresolvedChecks.filter((item) => !surfacedChecks.has(item.check))
    .map(({ check, reason }) => ({ check: safeCheckName(check), reason: safePath(reason, uid) }));

  return {
    mode: "READ_ONLY",
    project: PROJECT,
    requestId: REQUEST_ID,
    requestCommunity: communityId,
    eligibility: report.eligible ? "ELIGIBLE" : "BLOCKED",
    identityProof: identity ? {
      recordPath: safePath(identity.storagePath, uid),
      communityId,
      cleanupSupported: true,
      cleanupRequirement: "Only after approved record-specific retention review; existing cleanup pins deletion to the reviewed Storage generation.",
      blockers: unresolved(report, identityChecks),
    } : { status: "No supported identity-proof object path found by eligibility discovery.", blockers: unresolved(report, identityChecks) },
    notifications: {
      status: notificationClass.status ?? "NOT_REPORTED",
      records: (notificationClass.records ?? []).map((item) => ({
        path: safePath(item.path ?? `${item.collection}/${item.id}`, uid),
        communityId: item.communityId ?? null,
        disposition: "Preserve delivered notification/read history; requires a supported retention and identifier disposition. No cleanup operation is supported for these records.",
      })),
      blockers: unresolved(report, new Set(["reference:notifications"])),
    },
    notificationDevices: {
      status: deviceClass.status ?? "NOT_REPORTED",
      records: (deviceClass.records ?? []).map((item) => ({
        path: safePath(item.path ?? `notificationDevices/${item.id}`, uid),
        communityId: item.communityId ?? null,
        cleanupSupported: deviceClass.cleanupEligible === true,
        disposition: deviceClass.cleanupEligible === true
          ? "Disposable registration; existing request-bound backend cleanup can remove it after ownership/scope revalidation."
          : "Do not clean up until ownership and community scope are verified.",
      })),
      blockers: unresolved(report, new Set(["reference:notificationDevices"])),
    },
    auditRecords: {
      count: auditHistory?.count ?? 0,
      records: (auditHistory?.records ?? []).map((item) => ({
        path: safePath(`auditLogs/${item.id}`, uid),
        communityId: item.communityId ?? null,
        disposition: "Immutable history must be preserved; authorized retention/legal review must establish retention conditions and treatment of identifiers in metadata.",
      })),
      blockers: unresolved(report, new Set(["auditRetentionCondition"])),
    },
    otherBlockers,
    otherBlockerCount: otherBlockers.length,
    sensitiveValuesRedacted: true,
  };
}

async function main() {
  if (process.argv.length !== 2) throw new Error("This diagnostic accepts no arguments; the request and project are fixed in the script.");
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw new Error("Emulator environment overrides are set; refusing to run against an unintended target.");
  }

  const app = initializeApp({ projectId: PROJECT, storageBucket: STORAGE_BUCKET, credential: applicationDefault() }, "account-deletion-read-only-diagnostic");
  try {
    const report = await reviewAccountDeletionEligibilityCore({
      db: getFirestore(app),
      bucket: getStorage(app).bucket(),
      data: { requestId: REQUEST_ID },
    });
    process.stdout.write(`${JSON.stringify(buildDiagnostic(report), null, 2)}\n`);
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch(() => {
    process.stderr.write("Read-only deletion diagnostic failed. Check ADC authorization and project access; no writes are performed.\n");
    process.exitCode = 1;
  });
}

module.exports = { buildDiagnostic };
