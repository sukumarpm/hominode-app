"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  resolveEffectiveVisitorPolicy,
} = require("../src/visitor_policy_resolver");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test("scheduled policy activates and retains revision", { skip: !enabled }, async () => {
  const app = admin.initializeApp({ projectId: "hominode-policy-schedule-test" });
  const db = admin.firestore(app);

  try {
    const ref = db.collection("communities").doc("SCHEDULE-TEST");
    const effectiveAt = Date.UTC(2026, 10, 20, 10);

    const policy = (approvalMode, revision) => ({
      schemaVersion: 1,
      enabled: true,
      timeZone: "Asia/Manila",
      approvalMode,
      emergency: null,
      pets: {
        mode: "allowed",
        normalMode: "allowed",
        restriction: null,
      },
      revision,
    });

    await ref.set({
      timeZone: "Asia/Manila",
      visitorPolicy: policy("resident_authorized", 1),
      scheduledVisitorPolicy: {
        effectiveAt,
        policy: (({ revision, ...input }) => input)(
          policy("all_approval_required", 2)
        ),
        revision: 2,
      },
    });

    const community = (await ref.get()).data();

    const before = resolveEffectiveVisitorPolicy(community, effectiveAt - 1);
    const after = resolveEffectiveVisitorPolicy(community, effectiveAt);

    assert.equal(before.approvalMode, "resident_authorized");
    assert.equal(before.revision, 1);
    assert.equal(after.approvalMode, "all_approval_required");
    assert.equal(after.revision, 2);
  } finally {
    await app.delete();
  }
});
