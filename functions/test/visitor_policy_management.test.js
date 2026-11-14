const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { getCommunityVisitorPolicyCore } = require("../src/visitor_policy_management");

const now = Date.parse("2026-11-14T09:00:00+08:00");
const auth = { uid: "admin", token: { phone_number: "+639170000000",
  firebase: { sign_in_provider: "phone" } } };
const policy = (extra = {}) => ({ schemaVersion: 1, enabled: true, timeZone: "Asia/Manila",
  approvalMode: "resident_authorized", emergency: null,
  pets: { mode: "allowed", normalMode: "allowed", restriction: null }, ...extra });
function request(community, extra = {}) {
  const documents = {
    admins: { admin: { uid: "admin", role: "admin", isActive: true, authorizedCommunityIds: ["C"] } },
    communities: { C: { isActive: true, timeZone: "Asia/Manila", ...community } },
  };
  const db = { collection: (name) => ({ doc: (id) => ({ get: async () => ({
    exists: documents[name]?.[id] != null, data: () => documents[name]?.[id],
  }) }) }) };
  return getCommunityVisitorPolicyCore({ db, auth, data: { communityId: "C" }, now: () => now, ...extra });
}

test("unconfigured policy returns canonical zone, zero write revision and blocked readiness", async () => {
  const result = await request({});
  assert.equal(result.timeZone, "Asia/Manila");
  assert.equal(result.writeRevision, 0);
  assert.equal(result.policy.revision, 0);
  assert.equal(result.rolloutReady, false);
  assert.equal(result.pendingSchedule, null);
});

test("load separates effective policy from pending schedule and exposes only safe schedule fields", async () => {
  const input = policy({ approvalMode: "all_approval_required" });
  const result = await request({ visitorPolicy: { ...policy(), revision: 4 },
    visitorPolicyRolloutReady: true,
    scheduledVisitorPolicy: { effectiveAt: Timestamp.fromMillis(now + 60_000),
      policy: input, revision: 7, updatedBy: "admin", updatedAt: Timestamp.fromMillis(now - 1) } });
  assert.equal(result.policy.revision, 4);
  assert.equal(result.policy.approvalMode, "resident_authorized");
  assert.equal(result.writeRevision, 7);
  assert.equal(result.rolloutReady, true);
  assert.deepEqual(result.pendingSchedule, { effectiveAt: now + 60_000, revision: 7, policy: input });
  assert.equal(result.serverTime, now);
});

test("at activation load shows the scheduled policy as effective without losing write revision", async () => {
  const result = await request({ visitorPolicy: { ...policy(), revision: 4 },
    scheduledVisitorPolicy: { effectiveAt: now, policy: policy({ approvalMode: "all_approval_required" }), revision: 5 } });
  assert.equal(result.policy.revision, 5);
  assert.equal(result.policy.approvalMode, "all_approval_required");
  assert.equal(result.writeRevision, 5);
  assert.equal(result.pendingSchedule, null);
});

test("write revision fails closed for corrupt revision metadata", async () => {
  for (const revision of [-1, 1.5, "5", Number.NaN]) {
    await assert.rejects(request({ visitorPolicy: { ...policy(), revision } }), { code: "invalid-argument" });
  }
});

test("policy load retains authenticated Admin community scoping", async () => {
  await assert.rejects(request({}, { auth: { ...auth, uid: "resident" } }), { code: "permission-denied" });
  await assert.rejects(request({}, { data: { communityId: "FOREIGN" } }), { code: "permission-denied" });
});
