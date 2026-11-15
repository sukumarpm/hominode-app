"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { buildDiagnostic } = require("../scripts/diagnose-account-deletion-blockers");

test("diagnostic exposes other blockers and record paths without resident identifiers or record contents", () => {
  const report = {
    uid: "private-resident-uid",
    eligible: false,
    communities: ["GREEN-WAVE"],
    linkedProfiles: { users: { communityId: "GREEN-WAVE" } },
    eligiblePersonalRecords: [{ type: "identity_proof_upload", storagePath: "residentIdentityProofs/GREEN-WAVE/private-resident-uid/proof.jpg" }],
    coverage: {
      additionalResidentReferences: {
        notifications: { status: "MATCHING_REFERENCE", records: [
          { collection: "notifications", id: "notice-1", path: "notifications/notice-1", communityId: "GREEN-WAVE", body: "private message" },
        ] },
        notificationDevices: { status: "MATCHING_REFERENCE", cleanupEligible: true, records: [
          { id: "device-1", path: "notificationDevices/device-1", communityId: "GREEN-WAVE", fcmToken: "private-token" },
        ] },
      },
      preservedHistoricalReferences: [{ type: "audit_history", count: 1, records: [
        { id: "audit-1", communityId: "GREEN-WAVE", actorUid: "private-resident-uid", targetId: "private-target", summary: "private summary" },
      ] }],
    },
    unresolvedChecks: [
      { check: "identityProofReview", reason: "Identity-proof review is pending." },
      { check: "reference:notifications", reason: "Notification reference remains." },
      { check: "reference:notificationDevices", reason: "Device cleanup is pending." },
      { check: "auditRetentionCondition", reason: "Audit review is pending." },
      { check: "visitorCredential:private-visitor-id", reason: "Credential discovery remains unresolved." },
    ],
  };

  const output = buildDiagnostic(report);
  const serialized = JSON.stringify(output);
  assert.equal(output.otherBlockerCount, 1);
  assert.deepEqual(output.otherBlockers, [{ check: "visitorCredential", reason: "Credential discovery remains unresolved." }]);
  assert.match(output.identityProof.recordPath, /\[resident-uid\]/);
  assert.doesNotMatch(serialized, /private-resident-uid|private-visitor-id|private-token|private message|private summary|private-target/);
  assert.equal(output.auditRecords.records[0].path, "auditLogs/audit-1");
});
