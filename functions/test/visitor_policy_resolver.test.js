"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  resolveEffectiveVisitorPolicy,
} = require("../src/visitor_policy_resolver");

const policy = (approvalMode) => ({
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
});

const effectiveAt = Date.UTC(2026, 10, 16, 1);

const community = {
  timeZone: "Asia/Manila",
  visitorPolicy: policy("resident_authorized"),
  scheduledVisitorPolicy: {
    effectiveAt,
    policy: policy("all_approval_required"),
  },
};

test("existing policy remains effective before activation", () => {
  assert.equal(
    resolveEffectiveVisitorPolicy(community, effectiveAt - 1).approvalMode,
    "resident_authorized"
  );
});

test("scheduled policy becomes effective at activation", () => {
  assert.equal(
    resolveEffectiveVisitorPolicy(community, effectiveAt).approvalMode,
    "all_approval_required"
  );
});

test("scheduled policy remains effective after activation", () => {
  assert.equal(
    resolveEffectiveVisitorPolicy(community, effectiveAt + 1).approvalMode,
    "all_approval_required"
  );
});

test("community without schedule uses current policy", () => {
  assert.equal(
    resolveEffectiveVisitorPolicy(
      { timeZone: "Asia/Manila", visitorPolicy: policy("resident_authorized") },
      effectiveAt
    ).approvalMode,
    "resident_authorized"
  );
});

test("invalid scheduled policy fails closed", () => {
  assert.throws(() =>
    resolveEffectiveVisitorPolicy(
      {
        ...community,
        scheduledVisitorPolicy: {
          effectiveAt,
          policy: { schemaVersion: 99 },
        },
      },
      effectiveAt - 1
    )
  );
});

test("invalid server timestamp is rejected", () => {
  assert.throws(() => resolveEffectiveVisitorPolicy(community, NaN));
});

test("first scheduled enforcement starts at the community-local instant", () => {
  const at = Date.parse("2026-11-16T09:00:00+08:00");
  assert.equal(at, effectiveAt);
  const first = { ...community, visitorPolicy: { ...policy("resident_authorized"), enabled: false } };
  assert.equal(resolveEffectiveVisitorPolicy(first, at - 1).enforcementStartedAt, undefined);
  assert.equal(resolveEffectiveVisitorPolicy(first, at).enforcementStartedAt, at);
  assert.equal(resolveEffectiveVisitorPolicy(first, at + 1).enforcementStartedAt, at);
});

test("schedules retain the original cutover through policy changes and disabling", () => {
  const cutover = effectiveAt - 1000;
  for (const enabled of [true, false]) {
    for (const scheduledEnabled of [true, false]) {
      const value = { ...community,
        visitorPolicy: { ...community.visitorPolicy, enabled, enforcementStartedAt: cutover },
        scheduledVisitorPolicy: { ...community.scheduledVisitorPolicy,
          policy: { ...community.scheduledVisitorPolicy.policy, enabled: scheduledEnabled } },
      };
      assert.equal(resolveEffectiveVisitorPolicy(value, effectiveAt).enforcementStartedAt, cutover);
    }
  }
});

test("a missing cutover on an already-enforced policy is not replaced by a later schedule", () => {
  assert.equal(resolveEffectiveVisitorPolicy(community, effectiveAt).enforcementStartedAt, null);
});

test("refresh deadlines include schedules and emergency boundaries without changing authorization", () => {
  const {visitorPolicyRevalidationAt} = require("../src/visitor_policy_resolver");
  const value = {...community, visitorPolicy: {...community.visitorPolicy,
    emergency: {startAt: effectiveAt - 1000, endAt: effectiveAt - 500}}};
  assert.equal(visitorPolicyRevalidationAt(value, effectiveAt - 2000), effectiveAt - 1000);
  assert.equal(visitorPolicyRevalidationAt(value, effectiveAt - 1000), effectiveAt - 500);
  assert.equal(visitorPolicyRevalidationAt(value, effectiveAt - 500), effectiveAt);
  assert.equal(visitorPolicyRevalidationAt(value, effectiveAt), null);
});
