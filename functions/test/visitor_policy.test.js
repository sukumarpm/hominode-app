const test = require("node:test");
const assert = require("node:assert/strict");
const {
  WINDOW_MS,
  PET_MESSAGE,
  validatePolicy,
  communityPolicy,
  residentIdentity,
  bringingPet,
  invitationDecision,
  assertVisitorAuthorized,
} = require("../src/visitor_policy");

const now = Date.UTC(2026, 10, 9, 5);
const owner = {
  residentType: "owner",
  ownershipType: "owner",
  identityVerified: true,
  identityVerificationStatus: "verified",
};
const tenant = { ...owner, residentType: "tenant", ownershipType: "tenant" };
const config = (extra = {}) => ({
  schemaVersion: 1,
  enabled: true,
  timeZone: "Asia/Manila",
  approvalMode: "resident_authorized",
  emergency: null,
  pets: { mode: "allowed", normalMode: "allowed", restriction: null },
  ...extra,
});
const decide = (
  policy,
  profile = owner,
  time = now,
  arrival = now,
  pet = false,
) =>
  invitationDecision({
    community: { visitorPolicy: policy },
    profile,
    now: time,
    arrival,
    pet,
  });

for (const mode of [
  "resident_authorized",
  "tenant_approval_required",
  "all_approval_required",
]) {
  for (const [role, profile] of [
    ["owner", owner],
    ["tenant", tenant],
  ]) {
    test(`${mode}: trusted ${role} decision`, () => {
      const pending =
        mode === "all_approval_required" ||
        (mode === "tenant_approval_required" && role === "tenant");
      assert.equal(
        decide(config({ approvalMode: mode }), profile).authorizationState,
        pending ? "pending_admin" : "auto_authorized",
      );
    });
  }
}
test("unconfigured and disabled defaults preserve existing resident authorization", () => {
  assert.equal(communityPolicy({}).enabled, false);
  assert.equal(
    invitationDecision({
      community: {},
      profile: owner,
      now,
      arrival: now,
      pet: false,
    }).authorizationState,
    "auto_authorized",
  );
  assert.equal(
    decide(
      config({ enabled: false, approvalMode: "all_approval_required" }),
      tenant,
    ).authorizationState,
    "auto_authorized",
  );
});
test("owner exemption remains explicit; verification and conflicting roles fail closed", () => {
  const exempt = {
    ...owner,
    identityVerified: false,
    identityVerificationStatus: "not_required",
  };
  assert.deepEqual(residentIdentity(exempt, {}), {
    residentType: "owner",
    identityVerified: false,
    identityBasis: "community_owner_exemption",
  });
  assert.throws(() =>
    residentIdentity(exempt, { ownerIdentityVerificationRequired: true }),
  );
  assert.throws(() =>
    residentIdentity({ ...tenant, identityVerified: false }, {}),
  );
  for (const profile of [
    { ...owner, ownershipType: "tenant" },
    { ...owner, declaredResidentType: "tenant" },
    { residentType: "family_member" },
    { ...owner, declaredResidentType: "family" },
  ]) {
    assert.throws(() => residentIdentity(profile, {}));
  }
  assert.equal(
    residentIdentity({ ...owner, familyRole: "member" }, {}).residentType,
    "owner",
  );
});
for (const profile of [owner, tenant]) {
  for (const [offset, pending] of [
    [-1, false],
    [0, true],
    [999, true],
    [1000, false],
    [1001, false],
  ]) {
    test(`emergency boundary ${profile.residentType} at ${offset}ms`, () => {
      const policy = config({ emergency: { startAt: now, endAt: now + 1000 } });
      assert.equal(
        decide(policy, profile, now + offset).authorizationState,
        pending ? "pending_admin" : "auto_authorized",
      );
    });
  }
}
test("temporary restrictions use the whole inclusive credential window and half-open restriction", () => {
  const policy = config({
    pets: {
      mode: "temporarily_restricted",
      normalMode: "allowed",
      restriction: { startAt: now, endAt: now + 1000 },
    },
  });
  for (const arrival of [now - WINDOW_MS, now, now + 999 + WINDOW_MS]) {
    assert.throws(() => decide(policy, owner, now, arrival, true), {
      message: PET_MESSAGE,
    });
    assert.equal(
      decide(policy, owner, now, arrival, false).authorizationState,
      "auto_authorized",
    );
  }
  for (const arrival of [now - WINDOW_MS - 1, now + 1000 + WINDOW_MS]) {
    assert.equal(
      decide(policy, owner, now, arrival, true).authorizationState,
      "auto_authorized",
    );
  }
  assert.throws(
    () =>
      decide(
        config({
          pets: {
            mode: "not_allowed",
            normalMode: "not_allowed",
            restriction: null,
          },
        }),
        owner,
        now,
        now,
        true,
      ),
    { message: PET_MESSAGE },
  );
  assert.equal(
    decide(config(), owner, now, now, true).authorizationState,
    "auto_authorized",
  );
});
test("legacy pets default false; malformed declarations are rejected", () => {
  assert.equal(bringingPet(undefined), false);
  for (const value of [null, "false", 0, {}, []])
    assert.throws(() => bringingPet(value));
});
test("current approval requirements reject historical automatic or unattributed authorization", () => {
  const community = {
    visitorPolicy: {
      ...config({ approvalMode: "all_approval_required", revision: 1 }),
      enforcementStartedAt: now,
    },
  };
  const visitor = { expectedArrival: now, authorizationManaged: true };
  for (const authorizationState of [
    "pending_admin",
    "rejected",
    "revoked",
    "invented",
    "auto_authorized",
    "admin_authorized",
  ]) {
    assert.throws(() =>
      assertVisitorAuthorized({ ...visitor, authorizationState }, community, { now, profile: owner }),
    );
  }
  // These fields have provenance only because client writes cannot set them
  // and the Admin decision callable derives them from transaction authority.
  assert.doesNotThrow(() => assertVisitorAuthorized({ ...visitor,
    authorizationState: "admin_authorized", authorizationActorUid: "admin", approvedBy: "admin",
    isApproved: true, authorizationPolicyRevision: 1, approvedAt: now,
  }, community, { now, profile: owner }));
});
test("creation dates and compatibility snapshots never exempt a visit from the current policy", () => {
  for (const createdAt of [now - 1, now, now + 1, undefined]) {
    for (const snapshot of [undefined, {schemaVersion: 1, enforced: false}]) {
      const visitor = {expectedArrival: now, createdAt, visitorPolicySnapshot: snapshot};
      assert.doesNotThrow(() => assertVisitorAuthorized(visitor, {visitorPolicy: config()}, {now, profile: owner}));
      assert.throws(() => assertVisitorAuthorized(visitor, {visitorPolicy: config({approvalMode: 'all_approval_required'})}, {now, profile: owner}), {code: 'failed-precondition'});
    }
  }
});
test("approvals must match the effective policy revision and the active emergency boundary", () => {
  const visitor = {expectedArrival: now, authorizationManaged: true, isApproved: true,
    authorizationState: 'admin_authorized', authorizationActorUid: 'admin', approvedBy: 'admin',
    authorizationPolicyRevision: 2, approvedAt: now - 1};
  const policy = config({revision: 2, approvalMode: 'all_approval_required'});
  const check = (value = visitor, current = policy) => assertVisitorAuthorized(value, {visitorPolicy: current}, {now, profile: owner});
  assert.doesNotThrow(() => check());
  for (const revision of [undefined, 0, 1]) assert.throws(() => check({...visitor, authorizationPolicyRevision: revision}));
  assert.throws(() => check(visitor, {...policy, revision: 3}));
  assert.throws(() => check(visitor, {...policy, emergency: {startAt: now, endAt: now + 1000}}));
  assert.doesNotThrow(() => check({...visitor, approvedAt: now}, {...policy, emergency: {startAt: now, endAt: now + 1000}}));
  for (const approvedAt of [undefined, now + 1]) assert.throws(() => check({...visitor, approvedAt}));
  assert.throws(() => check({...visitor, authorizationManaged: false}));
  assert.throws(() => assertVisitorAuthorized({expectedArrival: now}, {}, {now}));
});
test("previously issued pet passes are evaluated without rewriting their authorization", () => {
  const visitor = {
    expectedArrival: now,
    authorizationManaged: true,
    authorizationState: "auto_authorized",
    bringingPet: true,
  };
  const community = {
    visitorPolicy: config({
      pets: {
        mode: "not_allowed",
        normalMode: "not_allowed",
        restriction: null,
      },
    }),
  };
  assert.throws(() => assertVisitorAuthorized(visitor, community, { now, profile: owner }), {
    message: PET_MESSAGE,
  });
  assert.equal(visitor.authorizationState, "auto_authorized");
  assert.doesNotThrow(() =>
    assertVisitorAuthorized({ ...visitor, bringingPet: false }, community, { now, profile: owner }),
  );
});
test("schema rejects unsupported modes, categories, invalid timeZones and ambiguous schedules", () => {
  assert.equal(validatePolicy(config()).timeZone, "Asia/Manila");
  for (const policy of [
    config({ approvalMode: "category" }),
    { ...config(), categories: [] },
    config({ timeZone: "invalid/zone" }),
    config({ enabled: "true" }),
    config({ emergency: { startAt: "2026-11-09T12:00", endAt: now } }),
    config({ emergency: { startAt: now, endAt: now } }),
    config({
      pets: {
        mode: "temporarily_restricted",
        normalMode: "allowed",
        restriction: null,
      },
    }),
  ]) {
    assert.throws(() => validatePolicy(policy), { code: "invalid-argument" });
  }
  assert.throws(() =>
    communityPolicy({ visitorPolicy: { schemaVersion: 99 } }),
  );
});
