const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canonicalResidentType,
  identityVerificationRequired,
  operationalAccessFailure,
  resolveFlatOccupant,
  verificationStatus,
  approveResidentRegistrationCore,
  rejectResidentRegistrationCore,
  deactivateResidentCore,
  reactivateResidentCore,
  reassignResidentCore,
  createResidentOnboardingCore,
  createAdminResidentCore,
  submitResidentIdentityProofCore,
  moveOutResidentCore,
  reviewResidentIdentityProofCore,
  getResidentIdentityProofUrlCore,
} = require("../src/resident_identity");
const {claimImportedOnboardingCore} = require("../src/register_resident");

const community = (overrides = {}) => ({id: "A", isActive: true, ...overrides});
const profile = (overrides = {}) => ({
  role: "resident",
  approvalStatus: "approved",
  isActive: true,
  communityId: "A",
  residentType: "owner",
  ownershipType: "owner",
  identityVerified: false,
  identityVerificationStatus: "not_required",
  ...overrides,
});

test("owner without proof proceeds when owner verification is optional", () => {
  assert.equal(identityVerificationRequired("owner", community()), false);
  assert.equal(operationalAccessFailure(profile(), community()), null);
});

test("owner proof can be explicitly required by community configuration", () => {
  const configured = community({ownerIdentityVerificationRequired: true});
  assert.equal(identityVerificationRequired("owner", configured), true);
  assert.equal(
    operationalAccessFailure(profile({identityVerificationStatus: "verification_required"}), configured),
    "identity-verification-required",
  );
});

test("tenant remains restricted for required, pending, and rejected proof states", () => {
  for (const status of ["verification_required", "pending", "rejected"]) {
    assert.equal(
      operationalAccessFailure(profile({residentType: "tenant", ownershipType: "tenant", identityVerificationStatus: status}), community()),
      "identity-verification-required",
    );
  }
});

test("only a verified tenant can use operational features", () => {
  assert.equal(
    operationalAccessFailure(profile({residentType: "tenant", ownershipType: "tenant", identityVerified: true, identityVerificationStatus: "verified"}), community()),
    null,
  );
  assert.equal(
    operationalAccessFailure(profile({residentType: "tenant", ownershipType: "tenant", identityVerified: true, identityVerificationStatus: "pending"}), community()),
    "identity-verification-required",
  );
});

test("wrong-community, inactive, pending, and ambiguous profiles fail closed", () => {
  assert.equal(operationalAccessFailure(profile(), community({id: "B"})), "wrong-community");
  assert.equal(operationalAccessFailure(profile({isActive: false}), community()), "inactive");
  assert.equal(operationalAccessFailure(profile({status: "inactive"}), community()), "inactive");
  assert.equal(operationalAccessFailure(profile({approvalStatus: "pending"}), community()), "not-approved");
  assert.equal(operationalAccessFailure(profile({residentType: "owner", ownershipType: "tenant"}), community()), "resident-type-ambiguous");
});

test("bulk owner and tenant types remain canonical and imports are not auto-verified", () => {
  assert.equal(canonicalResidentType({residentType: "owner", ownershipType: "owner"}), "owner");
  assert.equal(canonicalResidentType({residentType: "tenant", ownershipType: "tenant"}), "tenant");
  assert.equal(verificationStatus({identityVerified: false}), "verification_required");
});

function phoneAuth(uid) {
  return {uid, token: {phone_number: "+639171100000", firebase: {sign_in_provider: "phone"}}};
}

function fakeDb(seed, {onUpdate} = {}) {
  const values = new Map(Object.entries(seed));
  const applyChanges = (path, changes) => {
    const next = {...values.get(path)};
    for (const [field, value] of Object.entries(changes)) {
      if (value?.constructor?.name === "DeleteTransform") delete next[field];
      else next[field] = value;
    }
    values.set(path, next);
  };
  const snapshot = (path) => ({
    id: path.split("/").pop(),
    exists: values.has(path),
    data: () => values.get(path),
  });
  const ref = (path) => ({
    _path: path,
    id: path.split("/").pop(),
    get: async () => snapshot(path),
    update: async (changes) => {
      if (onUpdate) await onUpdate(path, changes);
      applyChanges(path, changes);
    },
  });
  const query = (collection, clauses = []) => ({
    _query: true,
    collection,
    clauses,
    where(field, _operator, expected) {
      return query(collection, [...clauses, {field, expected}]);
    },
    limit() { return this; },
    get: async () => querySnapshot({collection, clauses}),
  });
  const querySnapshot = (value) => ({
    docs: [...values.entries()]
      .filter(([path, data]) => path.startsWith(`${value.collection}/`) &&
        !path.slice(value.collection.length + 1).includes("/") &&
        value.clauses.every(({field, expected}) => data[field] === expected))
      .map(([path]) => snapshot(path)),
  });
  return {
    values,
    collection(name) {
      return {...query(name), doc: (id) => ref(`${name}/${id}`)};
    },
    async runTransaction(action) {
      const pendingWrites = [];
      const result = await action({
        get: async (target) => target._query ? querySnapshot(target) : snapshot(target._path),
        update(target, changes) {
          pendingWrites.push({kind: "update", target, changes});
        },
        create(target, changes) {
          if (values.has(target._path)) throw new Error("already exists");
          pendingWrites.push({kind: "create", target, changes});
        },
        set(target, changes) {
          pendingWrites.push({kind: "set", target, changes});
        },
      });
      for (const {kind, target, changes} of pendingWrites) {
        if (onUpdate) await onUpdate(target._path, changes);
        if (kind === "update") applyChanges(target._path, changes);
        else values.set(target._path, {...changes});
      }
      return result;
    },
  };
}

const approvalSeed = (residentOverrides = {}, extras = {}) => ({
  "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
  "communities/A": {isActive: true},
  "buildings/building-a": {communityId: "A", name: "Ivory"},
  "flats/flat-a": {communityId: "A", buildingId: "building-a", flatId: "I002", status: "vacant"},
  "users/resident-a": {
    role: "resident",
    communityId: "A",
    approvalStatus: "pending",
    isActive: false,
    declaredResidentType: "owner",
    identityVerified: false,
    identityVerificationStatus: "verification_required",
    ...residentOverrides,
  },
  ...extras,
});

const approvalData = (residentType) => ({
  communityId: "A",
  userId: "resident-a",
  buildingId: "building-a",
  flatId: "flat-a",
  residentType,
});

const activeOccupant = (residentType, overrides = {}) => ({
  role: "resident",
  communityId: "A",
  buildingId: "building-a",
  flatId: "flat-a",
  residentType,
  ownershipType: residentType,
  approvalStatus: "approved",
  isActive: true,
  status: "active",
  occupancyStatus: "current",
  identityVerified: residentType === "tenant",
  identityVerificationStatus: residentType === "tenant" ? "verified" : "not_required",
  ...overrides,
});

const lifecycleSeed = (residentOverrides = {}, extras = {}) => ({
  "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
  "communities/A": {isActive: true},
  "buildings/building-a": {communityId: "A", name: "Ivory"},
  "flats/flat-a": {
    communityId: "A",
    buildingId: "building-a",
    flatId: "I002",
    status: "occupied",
    residentUserId: "resident-a",
  },
  "users/resident-a": activeOccupant("owner", {
    uid: "resident-a",
    name: "Resident A",
    phoneNumber: "+639171100000",
    residentId: "RES1001",
    ...residentOverrides,
  }),
  ...extras,
});

test("Tenant ID enforcement: explicit verified status is mandatory", () => {
  for (const status of [undefined, null, "", "unknown", "pending", "rejected", "not_required"]) {
    assert.equal(operationalAccessFailure(profile({ residentType: "tenant", ownershipType: "tenant",
      identityVerified: true, identityVerificationStatus: status }), community()), "identity-verification-required");
  }
});

test("Tenant ID enforcement: upload, scoped review, correction and approval reuse the same resident", async () => {
  const db = fakeDb(lifecycleSeed({ residentType: "tenant", ownershipType: "tenant",
    identityVerificationStatus: "verification_required", identityVerified: false }, {
    "admins/admin-b": { uid: "admin-b", role: "admin", isActive: true, authorizedCommunityIds: ["B"] },
    "communities/B": { isActive: true },
  }));
  const resident = () => db.values.get("users/resident-a");
  assert.equal(operationalAccessFailure(resident(), community()), "identity-verification-required");
  const paths = [];
  const bucket = { file: (path) => ({
    save: async () => paths.push(path), delete: async () => {},
    getSignedUrl: async ({ action, expires }) => {
      assert.equal(action, "read");
      assert.ok(expires > Date.now() && expires <= Date.now() + 600000);
      return ["https://example.test/short-lived-proof"];
    },
  }) };
  const upload = () => submitResidentIdentityProofCore({ db, bucket, auth: phoneAuth("resident-a"),
    data: { contentType: "image/png", base64: Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,1]).toString("base64") } });
  await upload();
  assert.equal(resident().identityVerificationStatus, "pending");
  assert.equal(operationalAccessFailure(resident(), community()), "identity-verification-required");
  const review = { communityId: "A", userId: "resident-a", decision: "verified" };
  await assert.rejects(reviewResidentIdentityProofCore({ db, auth: phoneAuth("admin-b"), data: review }), { code: "permission-denied" });
  await assert.rejects(getResidentIdentityProofUrlCore({ db, bucket, auth: phoneAuth("admin-b"), data: { communityId: "B", userId: "resident-a" } }), { code: "permission-denied" });
  const preview = await getResidentIdentityProofUrlCore({ db, bucket, auth: phoneAuth("admin-a"), data: { communityId: "A", userId: "resident-a" } });
  assert.equal(preview.url, "https://example.test/short-lived-proof");
  await reviewResidentIdentityProofCore({ db, auth: phoneAuth("admin-a"), data: { ...review, decision: "rejected", reason: "Upload a legible proof" } });
  assert.notEqual(operationalAccessFailure(resident(), community()), null);
  await upload();
  await reviewResidentIdentityProofCore({ db, auth: phoneAuth("admin-a"), data: review });
  assert.equal(resident().identityVerified, true);
  assert.equal(resident().identityVerificationReviewedBy, "admin-a");
  assert.equal(operationalAccessFailure(resident(), community()), null);
  assert.equal(paths.length, 2);
  assert.equal(resident().uid, "resident-a");
});

test("trusted rejection accepts only an inactive pending resident", async () => {
  const db = fakeDb(approvalSeed());
  const result = await rejectResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a", reason: "Duplicate application"},
  });
  const resident = db.values.get("users/resident-a");
  assert.equal(result.status, "rejected");
  assert.equal(resident.approvalStatus, "rejected");
  assert.equal(resident.isActive, false);
  assert.equal(resident.rejectedBy, "admin-a");
  assert.equal(resident.rejectedReason, "Duplicate application");

  await assert.rejects(
    () => rejectResidentRegistrationCore({
      db: fakeDb(lifecycleSeed()),
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "resident-a"},
    }),
    {code: "failed-precondition"},
  );
});

test("rejection denies cross-community and unauthorized Admin requests", async () => {
  await assert.rejects(
    () => rejectResidentRegistrationCore({
      db: fakeDb(approvalSeed()),
      auth: phoneAuth("admin-a"),
      data: {communityId: "B", userId: "resident-a"},
    }),
    {code: "permission-denied"},
  );
  await assert.rejects(
    () => rejectResidentRegistrationCore({
      db: fakeDb(approvalSeed()),
      auth: phoneAuth("unknown-admin"),
      data: {communityId: "A", userId: "resident-a"},
    }),
    {code: "permission-denied"},
  );
});

test("deactivate suspends operational access without vacating the unit", async () => {
  const db = fakeDb(lifecycleSeed());
  const result = await deactivateResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a"},
  });
  const resident = db.values.get("users/resident-a");
  const flat = db.values.get("flats/flat-a");
  assert.deepEqual(result, {
    status: "inactive",
    occupancyStatus: "suspended",
    occupantRetained: true,
  });
  assert.equal(resident.isActive, false);
  assert.equal(resident.occupancyStatus, "suspended");
  assert.equal(operationalAccessFailure(resident, community()), "inactive");
  assert.equal(flat.status, "occupied");
  assert.equal(flat.residentUserId, "resident-a");
});

test("reactivate restores only the eligible resident who remains the unit occupant", async () => {
  const db = fakeDb(lifecycleSeed());
  await deactivateResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a"},
  });
  const result = await reactivateResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a"},
  });
  const resident = db.values.get("users/resident-a");
  assert.equal(result.status, "active");
  assert.equal(resident.isActive, true);
  assert.equal(resident.occupancyStatus, "current");
  assert.equal(operationalAccessFailure(resident, community()), null);
  assert.equal(db.values.get("flats/flat-a").residentUserId, "resident-a");
});

test("reactivate fails for another occupant, ineligible identity, and cross-community input", async () => {
  const wrongOccupant = fakeDb(lifecycleSeed({isActive: false, status: "inactive", occupancyStatus: "suspended"}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "other-resident",
    },
  }));
  await assert.rejects(
    () => reactivateResidentCore({
      db: wrongOccupant,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "resident-a"},
    }),
    {code: "failed-precondition"},
  );

  const unverifiedTenant = fakeDb(lifecycleSeed({
    residentType: "tenant",
    ownershipType: "tenant",
    isActive: false,
    status: "inactive",
    occupancyStatus: "suspended",
    identityVerified: false,
    identityVerificationStatus: "pending",
  }));
  await assert.rejects(
    () => reactivateResidentCore({
      db: unverifiedTenant,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "resident-a"},
    }),
    {code: "failed-precondition"},
  );
  await assert.rejects(
    () => reactivateResidentCore({
      db: fakeDb(lifecycleSeed({isActive: false, status: "inactive", occupancyStatus: "suspended"})),
      auth: phoneAuth("admin-a"),
      data: {communityId: "B", userId: "resident-a"},
    }),
    {code: "permission-denied"},
  );
});

test("reactivate requires the exact suspended lifecycle state", async () => {
  for (const occupancyStatus of ["", "current", "moved_out"]) {
    await assert.rejects(
      () => reactivateResidentCore({
        db: fakeDb(lifecycleSeed({
          isActive: false,
          status: "inactive",
          occupancyStatus,
        })),
        auth: phoneAuth("admin-a"),
        data: {communityId: "A", userId: "resident-a"},
      }),
      {code: "failed-precondition"},
    );
  }
});

function adminCreationFixture() {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true, countryCode: "IN"},
    "buildings/building-a": {communityId: "A", buildingName: "Tower A", isActive: true},
    "flats/flat-a": {communityId: "A", buildingId: "building-a", flatLabel: "A101", unitId: "A101", status: "vacant"},
  });
  let user;
  const calls = [];
  const authAdmin = {
    async getUserByPhoneNumber(phoneNumber) {
      calls.push(["lookup", phoneNumber]);
      if (!user) throw Object.assign(Error("No phone account"), {code: "auth/user-not-found"});
      return user;
    },
    async createUser(value) {
      calls.push(["create", value]);
      assert.deepEqual(Object.keys(value).sort(), ["disabled", "phoneNumber"]);
      user = {uid: "new-resident", ...value};
      return user;
    },
  };
  const data = {communityId: "A", residentName: "Admin Added Owner", phoneNumber: "+639171234567", residentType: "owner", familyMembers: 2, buildingId: "building-a", flatId: "flat-a"};
  return {db, calls, authAdmin, data, run: (overrides = {}) => createAdminResidentCore({db, authAdmin, auth: phoneAuth("admin-a"), data, ...overrides})};
}

test("Admin direct creation: creates assigned Resident without a Resident request or OTP/session claim", async () => {
  const f = adminCreationFixture();
  const result = await f.run();
  assert.equal(result.userId, "new-resident");
  const resident = f.db.values.get("users/new-resident");
  assert.equal(resident.role, "resident");
  assert.equal(resident.communityId, "A");
  assert.equal(resident.flatId, "flat-a");
  assert.equal(resident.creationSource, "admin_direct");
  assert.equal(resident.approvalStatus, "approved");
  assert.equal(resident.phoneVerified, false);
  assert.equal(resident.identityVerified, false);
  assert.equal(f.db.values.get("flats/flat-a").residentUserId, result.userId);
  assert.equal(f.db.values.get("buildings/building-a").occupied, 1);
  assert.equal([...f.db.values.keys()].some((path) => path.startsWith("residentOnboarding/")), false);
  assert.equal(result.token, undefined);
  assert.equal(result.password, undefined);
  assert.equal((await f.run()).idempotent, true);
  assert.equal(f.calls.filter(([kind]) => kind === "create").length, 1);
});

test("Admin test phone: selected PH national input binds the existing OTP UID and retries without duplicates", async () => {
  const f = adminCreationFixture();
  f.data.phoneNumber = "9400000000";
  f.data.phoneCountryCode = "PH";
  const lookups = [];
  const authAdmin = {
    async getUserByPhoneNumber(phoneNumber) {
      lookups.push(phoneNumber);
      return {uid: "test-phone-uid", phoneNumber: "+639400000000", disabled: false};
    },
    async createUser() { assert.fail("Existing test phone UID must be reused"); },
  };
  const result = await f.run({authAdmin});
  assert.equal(result.userId, "test-phone-uid");
  const resident = f.db.values.get("users/test-phone-uid");
  assert.equal(resident.uid, "test-phone-uid");
  assert.equal(resident.phoneNumber, "+639400000000");
  assert.equal(resident.communityId, "A");
  assert.equal(resident.approvalStatus, "approved");
  assert.equal(resident.phoneVerified, false);
  assert.equal(resident.identityVerified, false);
  assert.equal(f.db.values.get("flats/flat-a").residentUserId, "test-phone-uid");
  assert.equal((await f.run({authAdmin})).idempotent, true);
  assert.deepEqual(lookups, ["+639400000000", "+639400000000"]);
  assert.equal([...f.db.values.keys()].filter((key) => key.startsWith("users/")).length, 1);
});

test("Admin test phone: configured test phone without an Auth user creates exactly one identity", async () => {
  const f = adminCreationFixture();
  f.data.phoneNumber = "9400000000";
  f.data.phoneCountryCode = "PH";
  await f.run();
  assert.equal((await f.run()).idempotent, true);
  assert.equal(f.calls.filter(([kind]) => kind === "create").length, 1);
  assert.equal(f.db.values.get("users/new-resident").phoneNumber, "+639400000000");
  assert.equal([...f.db.values.keys()].filter((key) => key.startsWith("users/")).length, 1);
});

test("Admin direct creation: denies unauthenticated, foreign-community, inactive and non-Admin callers before Auth writes", async () => {
  for (const kind of ["unauthenticated", "foreign", "inactive", "resident", "superAdmin"]) {
    const f = adminCreationFixture();
    if (kind === "foreign") f.db.values.get("admins/admin-a").authorizedCommunityIds = ["B"];
    if (kind === "inactive") f.db.values.get("admins/admin-a").isActive = false;
    if (["resident", "superAdmin"].includes(kind)) f.db.values.get("admins/admin-a").role = kind;
    await assert.rejects(f.run(kind === "unauthenticated" ? {auth: null} : {}));
    assert.deepEqual(f.calls, [], kind);
    assert.equal(f.db.values.has("users/new-resident"), false);
  }
});

test("Admin direct creation: rejects invalid, occupied, reserved and cross-community units", async () => {
  for (const kind of ["missing", "foreign", "wrongBuilding", "occupied", "reserved", "inactiveBuilding"]) {
    const f = adminCreationFixture();
    const flat = f.db.values.get("flats/flat-a");
    if (kind === "missing") f.db.values.delete("flats/flat-a");
    if (kind === "foreign") flat.communityId = "B";
    if (kind === "wrongBuilding") flat.buildingId = "building-b";
    if (kind === "occupied") { flat.status = "occupied"; flat.residentUserId = "other"; }
    if (kind === "reserved") { flat.status = "reserved"; flat.reservedOnboardingId = "pending"; }
    if (kind === "inactiveBuilding") f.db.values.get("buildings/building-a").isActive = false;
    await assert.rejects(f.run());
    assert.deepEqual(f.calls, [], kind);
  }
});

test("Admin direct creation: preserves international phones and rejects duplicate profiles and pending requests", async () => {
  for (const phone of ["+639171234567", "+14155552671", "+919876543210", "+639400000000"]) {
    const f = adminCreationFixture();
    f.data.phoneNumber = phone;
    await f.run();
    assert.equal(f.db.values.get("users/new-resident").phoneNumber, phone);
  }
  for (const collection of ["users", "residentOnboarding"]) {
    const f = adminCreationFixture();
    f.db.values.set(`${collection}/existing`, {communityId: "A", phoneNumber: "+63 917 123 4567", status: "pending_registration"});
    await assert.rejects(f.run(), {code: "already-exists"});
    assert.deepEqual(f.calls, []);
    const ph940 = adminCreationFixture();
    ph940.data.phoneNumber = "+639400000000";
    ph940.db.values.set(`${collection}/existing`, {communityId: "A", phoneNumber: "+63 9400000000"});
    await assert.rejects(ph940.run(), {code: "already-exists"});
    assert.deepEqual(ph940.calls, []);
  }
});

test("Admin direct creation: rejects role escalation, malformed phone and missing unit; keeps identity safeguards", async () => {
  for (const changes of [{role: "admin"}, {uid: "other"}, {phoneVerified: true}, {phoneNumber: "+6394000000000"}, {flatId: ""}]) {
    const f = adminCreationFixture();
    await assert.rejects(f.run({data: {...f.data, ...changes}}));
    assert.deepEqual(f.calls, []);
  }
  const f = adminCreationFixture();
  f.data.residentType = "tenant";
  await f.run();
  const resident = f.db.values.get("users/new-resident");
  assert.equal(resident.identityVerificationStatus, "verification_required");
  assert.equal(resident.approvalStatus, "pending");
  assert.equal(resident.isActive, false);
  assert.equal(operationalAccessFailure(resident, community()), "not-approved");
});

test("Admin direct creation: does not attach an existing Admin or foreign Resident phone to this community", async () => {
  for (const collection of ["admins", "securityStaff", "users"]) {
    const f = adminCreationFixture();
    f.db.values.set(`${collection}/new-resident`, {uid: "new-resident", role: collection === "users" ? "resident" : "admin", communityId: "B"});
    await assert.rejects(f.run(), {code: "already-exists"});
    assert.equal(f.db.values.get("flats/flat-a").status, "vacant");
  }
});

test("Admin direct creation: rechecks unit availability and Admin scope inside the profile transaction", async () => {
  for (const changed of ["unit", "authorization"]) {
    const f = adminCreationFixture();
    const provision = f.authAdmin.createUser;
    f.authAdmin.createUser = async (value) => {
      const user = await provision(value);
      if (changed === "unit") f.db.values.get("flats/flat-a").status = "reserved";
      else f.db.values.get("admins/admin-a").authorizedCommunityIds = ["B"];
      return user;
    };
    await assert.rejects(f.run());
    assert.equal(f.db.values.has("users/new-resident"), false, changed);
    assert.equal(f.db.values.get("flats/flat-a").residentUserId, undefined);
  }
});

test("Admin single onboarding creates no user and is claimed by the OTP uid", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
  });
  const created = await createResidentOnboardingCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {
      communityId: "A",
      residentName: "Returning Owner",
      phoneNumber: "+639171100000",
      residentType: "owner",
      email: "owner@example.com",
      familyMembers: 2,
      buildingReference: "Ivory",
      unitReference: "I002",
    },
  });
  assert.equal(created.status, "pending_registration");
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("users/")).length, 0);
  const onboarding = db.values.get(`residentOnboarding/${created.onboardingId}`);
  assert.equal(onboarding.isActive, false);
  assert.equal(onboarding.identityVerified, false);

  const claimed = await claimImportedOnboardingCore({
    db,
    identity: {uid: "resident-returning", phoneNumber: "+639171100000"},
  });
  assert.equal(claimed.status, "pending");
  const resident = db.values.get("users/resident-returning");
  assert.equal(resident.uid, "resident-returning");
  assert.equal(resident.creationSource, "admin_single_onboarding_claim");
  assert.equal(resident.approvalStatus, "pending");
  assert.equal(resident.isActive, false);
  assert.equal(resident.identityVerified, false);
});

test("returning resident reassignment reuses the same profile and preserves move-out history", async () => {
  const db = fakeDb(lifecycleSeed({}, {
    "flats/flat-b": {
      communityId: "A",
      buildingId: "building-a",
      flatId: "I003",
      flatLabel: "I003",
      status: "vacant",
    },
  }));
  await moveOutResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a"},
  });
  const movedOut = db.values.get("users/resident-a");
  assert.equal(movedOut.previousFlatId, "flat-a");
  assert.ok(movedOut.movedOutAt);

  const result = await reassignResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {
      communityId: "A",
      userId: "resident-a",
      buildingId: "building-a",
      flatId: "flat-b",
    },
  });
  const returning = db.values.get("users/resident-a");
  assert.equal(result.userId, "resident-a");
  assert.equal(returning.uid, "resident-a");
  assert.equal(returning.flatId, "flat-b");
  assert.equal(returning.flatLabel, "I003");
  assert.equal(returning.isActive, true);
  assert.equal(returning.occupancyStatus, "current");
  assert.equal(returning.previousFlatId, "flat-a");
  assert.ok(returning.movedOutAt);
  assert.ok(returning.reassignedAt);
  assert.ok(returning.reactivatedAt);
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("users/")).length, 1);
  assert.equal(db.values.get("flats/flat-b").residentUserId, "resident-a");
  assert.equal(db.values.get("buildings/building-a").occupied, 1);
  assert.equal(db.values.get("buildings/building-a").vacant, 1);
});

test("returning resident reassignment fails closed for occupied, ineligible, duplicate, and cross-community state", async () => {
  const movedOutProfile = {
    ...activeOccupant("owner"),
    uid: "resident-a",
    name: "Resident A",
    phoneNumber: "+639171100000",
    buildingId: null,
    flatId: null,
    isActive: false,
    status: "inactive",
    occupancyStatus: "moved_out",
    previousBuildingId: "building-a",
    previousFlatId: "flat-a",
  };
  const seed = (overrides = {}) => lifecycleSeed({}, {
    "users/resident-a": {...movedOutProfile, ...(overrides.resident ?? {})},
    "flats/flat-a": {communityId: "A", buildingId: "building-a", status: "vacant"},
    "flats/flat-b": {
      communityId: "A",
      buildingId: "building-a",
      flatId: "I003",
      status: "vacant",
      ...(overrides.flat ?? {}),
    },
    ...(overrides.extra ?? {}),
  });
  const request = {
    communityId: "A",
    userId: "resident-a",
    buildingId: "building-a",
    flatId: "flat-b",
  };

  await assert.rejects(
    () => reassignResidentCore({
      db: fakeDb(seed({flat: {status: "occupied", residentUserId: "other-resident"}})),
      auth: phoneAuth("admin-a"),
      data: request,
    }),
    {code: "failed-precondition"},
  );
  await assert.rejects(
    () => reassignResidentCore({
      db: fakeDb(seed({resident: {
        residentType: "tenant",
        ownershipType: "tenant",
        identityVerified: false,
        identityVerificationStatus: "pending",
      }})),
      auth: phoneAuth("admin-a"),
      data: request,
    }),
    {code: "failed-precondition"},
  );
  await assert.rejects(
    () => reassignResidentCore({
      db: fakeDb(seed({resident: {uid: "different-auth-uid"}})),
      auth: phoneAuth("admin-a"),
      data: request,
    }),
    {code: "permission-denied"},
  );
  await assert.rejects(
    () => reassignResidentCore({
      db: fakeDb(seed({extra: {
        "users/duplicate-active": activeOccupant("owner", {
          uid: "duplicate-active",
          phoneNumber: "+639171100000",
          flatId: "flat-c",
        }),
      }})),
      auth: phoneAuth("admin-a"),
      data: request,
    }),
    {code: "failed-precondition"},
  );
  await assert.rejects(
    () => reassignResidentCore({
      db: fakeDb(seed()),
      auth: phoneAuth("admin-a"),
      data: {...request, communityId: "B"},
    }),
    {code: "permission-denied"},
  );
  await assert.rejects(
    () => reassignResidentCore({
      db: fakeDb(seed()),
      auth: phoneAuth("admin-a"),
      data: {...request, residentType: "tenant"},
    }),
    {code: "invalid-argument"},
  );
});

test("an already claimed onboarding retries against the same OTP uid without a duplicate profile", async () => {
  const db = fakeDb({
    "communities/A": {isActive: true},
    "residentOnboarding/onboarding-a": {
      communityId: "A",
      phoneNumber: "+639171100000",
      residentName: "Existing Resident",
      residentType: "owner",
      creationSource: "admin_single_onboarding",
      status: "claimed",
      claimedByUid: "resident-a",
    },
    "users/resident-a": {
      uid: "resident-a",
      phoneNumber: "+639171100000",
      role: "resident",
      communityId: "A",
      approvalStatus: "pending",
      isActive: false,
    },
  });
  const result = await claimImportedOnboardingCore({
    db,
    identity: {uid: "resident-a", phoneNumber: "+639171100000"},
  });
  assert.equal(result.idempotent, true);
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("users/")).length, 1);
  assert.equal(db.values.get("users/resident-a").uid, "resident-a");
});

test("Admin onboarding cannot create a second profile path for an existing moved-out resident", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "users/resident-a": {
      uid: "resident-a",
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      approvalStatus: "approved",
      isActive: false,
      status: "inactive",
      occupancyStatus: "moved_out",
      residentType: "owner",
      ownershipType: "owner",
    },
  });
  await assert.rejects(
    () => createResidentOnboardingCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {
        communityId: "A",
        residentName: "Existing Resident",
        phoneNumber: "+639171100000",
        residentType: "owner",
      },
    }),
    {code: "already-exists"},
  );
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("users/")).length, 1);
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("residentOnboarding/")).length, 0);
});

test("single onboarding accepts E.164 independent of community and detects legacy formatted records", async () => {
  const numbers = [
    ["+91 98765 43210", "+919876543210"],
    ["+63 917 123 4567", "+639171234567"],
    ["+1 415 555 2671", "+14155552671"],
    ["+44 20 7946 0958", "+442079460958"],
  ];
  for (const [input, expected] of numbers) {
    const db = fakeDb({
      "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
      "communities/A": {isActive: true, countryCode: "IN"},
    });
    const created = await createResidentOnboardingCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", residentName: "International Resident", phoneNumber: input, residentType: "owner"},
    });
    assert.equal(db.values.get(`residentOnboarding/${created.onboardingId}`).phoneNumber, expected);
  }

  const legacyDb = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true, countryCode: "IN"},
    "users/legacy": {uid: "legacy", role: "resident", communityId: "A", phoneNumber: "98765-43210"},
  });
  await assert.rejects(() => createResidentOnboardingCore({
    db: legacyDb,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", residentName: "Duplicate Resident", phoneNumber: "+919876543210", phoneCountryCode: "IN", residentType: "owner"},
  }), {code: "already-exists"});
  assert.equal(legacyDb.values.has("users/legacy"), true);
});

test("Add Resident phone country is independent of community and preserves international records", async () => {
  for (const [phone, countryCode, phoneCountryCode, expected] of [
    ["+63 (917) 123-4567", "IN", null, "+639171234567"],
    ["+1 (415) 555-2671", "IN", null, "+14155552671"],
    ["+91 98765 43210", "PH", null, "+919876543210"],
    ["09171234567", "IN", "PH", "+639171234567"],
    ["(415) 555-2671", "IN", "US", "+14155552671"],
    ["09876543210", "PH", "IN", "+919876543210"],
    ["+44 20 7946 0958", "PH", "IN", "+442079460958"],
    ["+639400000000", "PH", null, "+639400000000"],
    ["+6309171234567", "PH", null, null],
    ["09171234567", "PH", null, null],
    ["9876543210", "IN", null, null],
  ]) {
    const db = fakeDb({
      "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
      "communities/A": {isActive: true, countryCode},
      "users/existing": {uid: "existing", role: "resident", communityId: "A", phoneNumber: "+14155552672"},
    });
    const request = {db, auth: phoneAuth("admin-a"), data: {
      communityId: "A", residentName: "Phone Test Resident", phoneNumber: phone, phoneCountryCode, residentType: "owner",
    }};
    if (expected) {
      const result = await createResidentOnboardingCore(request);
      assert.equal(db.values.get(`residentOnboarding/${result.onboardingId}`).phoneNumber, expected);
    } else {
      await assert.rejects(createResidentOnboardingCore(request), {code: "invalid-argument", message: "Enter a valid resident phone number."});
      assert.equal([...db.values.keys()].some((path) => path.startsWith("residentOnboarding/")), false);
    }
    assert.equal(db.values.get("users/existing").phoneNumber, "+14155552672");
  }
});

test("trusted approval activates optional-proof owner and blocks unverified tenant approval", async () => {
  const ownerDb = fakeDb(approvalSeed());
  const owner = await approveResidentRegistrationCore({db: ownerDb, auth: phoneAuth("admin-a"), data: approvalData("owner")});
  assert.equal(owner.isActive, true);
  assert.equal(ownerDb.values.get("users/resident-a").identityVerificationStatus, "not_required");
  assert.equal(ownerDb.values.get("buildings/building-a").occupied, 1);
  assert.equal(ownerDb.values.get("buildings/building-a").vacant, 0);

  const tenantDb = fakeDb(approvalSeed({declaredResidentType: "tenant"}));
  await assert.rejects(
    () => approveResidentRegistrationCore({db: tenantDb, auth: phoneAuth("admin-a"), data: approvalData("tenant")}),
    {code: "failed-precondition"},
  );
});

test("approval cannot change the persisted registered resident type", async () => {
  const db = fakeDb(approvalSeed({
    declaredResidentType: "tenant",
    identityVerified: true,
    identityVerificationStatus: "verified",
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    (error) => error.code === "failed-precondition" &&
      /registered resident type/.test(error.message),
  );
});

test("empty flat allows a verified tenant approval", async () => {
  const db = fakeDb(approvalSeed({
    declaredResidentType: "tenant",
    identityVerified: true,
    identityVerificationStatus: "verified",
  }));
  const result = await approveResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: approvalData("tenant"),
  });
  assert.equal(result.status, "approved");
  assert.equal(db.values.get("users/resident-a").isActive, true);
  assert.equal(db.values.get("flats/flat-a").residentUserId, "resident-a");
});

test("trusted approval prevents an active duplicate owner and cross-community requests", async () => {
  const duplicateDb = fakeDb(approvalSeed({}, {
    "users/other-owner": activeOccupant("owner"),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({db: duplicateDb, auth: phoneAuth("admin-a"), data: approvalData("owner")}),
    {code: "failed-precondition"},
  );
  await assert.rejects(
    () => approveResidentRegistrationCore({db: fakeDb(approvalSeed()), auth: phoneAuth("admin-a"), data: {...approvalData("owner"), communityId: "B"}}),
    {code: "permission-denied"},
  );
});

test("all owner and tenant combinations reject a second active occupant", async (t) => {
  for (const [existingType, candidateType] of [
    ["owner", "owner"],
    ["owner", "tenant"],
    ["tenant", "owner"],
    ["tenant", "tenant"],
  ]) {
    await t.test(`${existingType} occupant rejects ${candidateType} candidate`, async () => {
      const candidate = {
        declaredResidentType: candidateType,
        ...(candidateType === "tenant"
          ? {identityVerified: true, identityVerificationStatus: "verified"}
          : {}),
      };
      const db = fakeDb(approvalSeed(candidate, {
        "flats/flat-a": {
          communityId: "A",
          buildingId: "building-a",
          status: "occupied",
          residentUserId: "current-resident",
        },
        "users/current-resident": activeOccupant(existingType),
      }));
      const before = structuredClone([...db.values.entries()]);
      await assert.rejects(
        () => approveResidentRegistrationCore({
          db,
          auth: phoneAuth("admin-a"),
          data: approvalData(candidateType),
        }),
        (error) => error.code === "failed-precondition" &&
          /unit is not available or reserved/.test(error.message),
      );
      assert.deepEqual([...db.values.entries()], before);
    });
  }
});

test("legacy occupant aliases reconcile safely and conflicts fail closed", async () => {
  assert.equal(resolveFlatOccupant({residentUid: "resident-a"}).uid, "resident-a");
  assert.equal(resolveFlatOccupant({residentUserId: "resident-a", residentUid: "resident-a"}).uid, "resident-a");
  assert.throws(
    () => resolveFlatOccupant({residentUserId: "resident-a", residentUid: "resident-b"}),
    {code: "failed-precondition"},
  );

  for (const flatAliases of [
    {residentUid: "resident-a"},
    {residentUserId: "resident-a", residentUid: "resident-a"},
    {residentIds: ["resident-a"]},
  ]) {
    const db = fakeDb(approvalSeed({
      buildingId: "building-a",
      flatId: "flat-a",
    }, {
      "flats/flat-a": {
        communityId: "A",
        buildingId: "building-a",
        status: "occupied",
        ...flatAliases,
      },
    }));
    await approveResidentRegistrationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    });
    const flat = db.values.get("flats/flat-a");
    assert.equal(flat.residentUserId, "resident-a");
    assert.equal("residentUid" in flat, false);
    assert.equal("residentIds" in flat, false);
  }

  const conflictDb = fakeDb(approvalSeed({}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "resident-a",
      residentUid: "resident-b",
    },
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: conflictDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
});

test("approval never takes over an inactive or suspended occupant", async () => {
  const staleDb = fakeDb(approvalSeed({}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUid: "old-resident",
    },
    "users/old-resident": activeOccupant("owner", {
      isActive: false,
      status: "inactive",
      occupancyStatus: "suspended",
    }),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: staleDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
  assert.equal(staleDb.values.get("flats/flat-a").residentUid, "old-resident");

  const ambiguousDb = fakeDb(approvalSeed({}, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "old-resident",
    },
    "users/old-resident": activeOccupant("owner", {flatId: "different-flat", isActive: false}),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: ambiguousDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
});

test("unauthorized Admin and inactive community are rejected", async () => {
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: fakeDb(approvalSeed()),
      auth: phoneAuth("unknown-admin"),
      data: approvalData("owner"),
    }),
    {code: "permission-denied"},
  );
  const inactiveDb = fakeDb(approvalSeed({}, {"communities/A": {isActive: false}}));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db: inactiveDb,
      auth: phoneAuth("admin-a"),
      data: approvalData("owner"),
    }),
    {code: "failed-precondition"},
  );
});

test("bulk-import claimed tenant follows verification and occupancy approval rules", async () => {
  const db = fakeDb(approvalSeed({
    creationSource: "admin_bulk_import_claim",
    declaredResidentType: "tenant",
    residentType: "tenant",
    ownershipType: "tenant",
    identityVerified: true,
    identityVerificationStatus: "verified",
  }, {
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "current-resident",
    },
    "users/current-resident": activeOccupant("owner"),
  }));
  await assert.rejects(
    () => approveResidentRegistrationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: approvalData("tenant"),
    }),
    {code: "failed-precondition"},
  );
});

test("tenant can upload and re-upload proof while operational access stays restricted", async () => {
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
    },
  });
  const saved = [];
  const bucket = {
    file: (path) => ({save: async (bytes, options) => saved.push({path, bytes, options})}),
  };
  const result = await submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });
  assert.equal(result.status, "pending");
  assert.equal(saved.length, 1);
  const tenant = db.values.get("users/tenant-a");
  assert.equal(tenant.identityVerificationStatus, "pending");
  assert.equal(tenant.identityVerified, false);
  assert.match(tenant.identityProofStoragePath, /^residentIdentityProofs\/A\/tenant-a\//);
});

test("replacement upload preserves the new proof and cleans up only the previous owned path", async () => {
  const oldPath = "residentIdentityProofs/A/tenant-a/old.png";
  const events = [];
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
      identityProofStoragePath: oldPath,
    },
  }, {onUpdate: async () => events.push("update")});
  const bucket = {
    file: (path) => ({
      save: async () => events.push(`save:${path}`),
      delete: async () => events.push(`delete:${path}`),
    }),
  };

  await submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });

  const newPath = db.values.get("users/tenant-a").identityProofStoragePath;
  assert.notEqual(newPath, oldPath);
  assert.match(newPath, /^residentIdentityProofs\/A\/tenant-a\/[^/]+\.png$/);
  assert.deepEqual(events.slice(1), ["update", `delete:${oldPath}`]);
});

test("replacement cleanup never deletes an arbitrary or cross-resident path", async () => {
  for (const previousPath of [
    "residentIdentityProofs/A/other-resident/old.png",
    "residentIdentityProofs/A/tenant-a/nested/old.png",
    "unrelated/private-object.png",
  ]) {
    const deleted = [];
    const db = fakeDb({
      "communities/A": {isActive: true},
      "users/tenant-a": {
        role: "resident",
        communityId: "A",
        phoneNumber: "+639171100000",
        residentType: "tenant",
        ownershipType: "tenant",
        approvalStatus: "pending",
        isActive: false,
        identityVerified: false,
        identityVerificationStatus: "rejected",
        identityProofStoragePath: previousPath,
      },
    });
    const bucket = {
      file: () => ({save: async () => {}, delete: async () => deleted.push(previousPath)}),
    };
    await submitResidentIdentityProofCore({
      db,
      bucket,
      auth: phoneAuth("tenant-a"),
      data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
    });
    assert.deepEqual(deleted, []);
  }
});

test("failed old-proof cleanup does not lose the newly submitted proof", async () => {
  const oldPath = "residentIdentityProofs/A/tenant-a/old.png";
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
      identityProofStoragePath: oldPath,
    },
  });
  const bucket = {
    file: () => ({save: async () => {}, delete: async () => { throw new Error("cleanup failed"); }}),
  };
  const result = await submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });
  assert.equal(result.status, "pending");
  assert.notEqual(db.values.get("users/tenant-a").identityProofStoragePath, oldPath);
});

test("previous proof is retained when the Firestore replacement commit fails", async () => {
  const oldPath = "residentIdentityProofs/A/tenant-a/old.png";
  const saved = [];
  const deleted = [];
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "rejected",
      identityProofStoragePath: oldPath,
    },
  }, {onUpdate: async () => { throw new Error("commit failed"); }});
  const bucket = {
    file: (path) => ({
      save: async () => saved.push(path),
      delete: async () => deleted.push(path),
    }),
  };
  await assert.rejects(() => submitResidentIdentityProofCore({
    db,
    bucket,
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  }), /commit failed/);
  assert.equal(saved.length, 1);
  assert.deepEqual(deleted, []);
  assert.equal(db.values.get("users/tenant-a").identityProofStoragePath, oldPath);
});

test("pending resident can still submit proof", async () => {
  const db = fakeDb({
    "communities/A": {isActive: true},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "pending",
      isActive: false,
      identityVerified: false,
      identityVerificationStatus: "pending",
    },
  });
  const result = await submitResidentIdentityProofCore({
    db,
    bucket: {file: () => ({save: async () => {}})},
    auth: phoneAuth("tenant-a"),
    data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
  });
  assert.equal(result.status, "pending");
});

test("verified resident cannot use the standard proof upload flow", async () => {
  let uploaded = false;
  const db = fakeDb({
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      phoneNumber: "+639171100000",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "approved",
      isActive: true,
      identityVerified: true,
      identityVerificationStatus: "verified",
    },
  });
  await assert.rejects(
    () => submitResidentIdentityProofCore({
      db,
      bucket: {file: () => ({save: async () => { uploaded = true; }})},
      auth: phoneAuth("tenant-a"),
      data: {contentType: "image/png", base64: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]).toString("base64")},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(uploaded, false);
});

test("trusted tenant move-out deactivates the resident and vacates only the matching unit", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A", name: "Ivory"},
    "users/tenant-a": {
      role: "resident",
      communityId: "A",
      residentType: "tenant",
      ownershipType: "tenant",
      approvalStatus: "approved",
      isActive: true,
      status: "active",
      occupancyStatus: "current",
      buildingId: "building-a",
      flatId: "flat-a",
    },
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "tenant-a",
      status: "occupied",
    },
  });
  const result = await moveOutResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "tenant-a"},
  });
  assert.equal(result.status, "moved_out");
  assert.equal(db.values.get("users/tenant-a").status, "inactive");
  assert.equal(db.values.get("users/tenant-a").isActive, false);
  assert.equal(db.values.get("users/tenant-a").occupancyStatus, "moved_out");
  assert.equal(db.values.get("flats/flat-a").status, "vacant");
  assert.equal(db.values.get("flats/flat-a").residentUserId, null);
  assert.equal(db.values.get("buildings/building-a").occupied, 0);
  assert.equal(db.values.get("buildings/building-a").vacant, 1);
});

test("move-out requires an active current resident", async () => {
  for (const overrides of [
    {isActive: false, status: "inactive", occupancyStatus: "suspended"},
    {isActive: true, status: "active", occupancyStatus: "moved_out"},
    {isActive: true, status: "inactive", occupancyStatus: "current"},
  ]) {
    await assert.rejects(
      () => moveOutResidentCore({
        db: fakeDb(lifecycleSeed(overrides)),
        auth: phoneAuth("admin-a"),
        data: {communityId: "A", userId: "resident-a"},
      }),
      {code: "failed-precondition"},
    );
  }
});

test("move-out rejects another resident's occupant reference", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A"},
    "users/tenant-a": activeOccupant("tenant"),
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "other-resident",
      status: "occupied",
    },
  });
  await assert.rejects(
    () => moveOutResidentCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "tenant-a"},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(db.values.get("users/tenant-a").isActive, true);
  assert.equal(db.values.get("flats/flat-a").residentUserId, "other-resident");
  assert.equal(db.values.get("flats/flat-a").status, "occupied");
});

test("move-out accepts matching legacy aliases and rejects conflicts", async () => {
  for (const aliases of [
    {residentUid: "tenant-a"},
    {residentUserId: "tenant-a", residentUid: "tenant-a"},
  ]) {
    const db = fakeDb({
      "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
      "communities/A": {isActive: true},
      "buildings/building-a": {communityId: "A"},
      "users/tenant-a": activeOccupant("tenant"),
      "flats/flat-a": {
        communityId: "A",
        buildingId: "building-a",
        status: "occupied",
        ...aliases,
      },
    });
    const result = await moveOutResidentCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "tenant-a"},
    });
    assert.equal(result.occupantCleared, true);
    assert.equal(db.values.get("flats/flat-a").residentUserId, null);
    assert.equal("residentUid" in db.values.get("flats/flat-a"), false);
  }

  const conflictDb = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A"},
    "users/tenant-a": activeOccupant("tenant"),
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "tenant-a",
      residentUid: "other-resident",
      status: "occupied",
    },
  });
  await assert.rejects(
    () => moveOutResidentCore({
      db: conflictDb,
      auth: phoneAuth("admin-a"),
      data: {communityId: "A", userId: "tenant-a"},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(conflictDb.values.get("users/tenant-a").isActive, true);
});

test("a new resident can be approved after the prior occupant properly moves out", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A", name: "Ivory"},
    "users/old-resident": activeOccupant("owner"),
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      residentUserId: "old-resident",
      status: "occupied",
    },
  });
  await moveOutResidentCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "old-resident"},
  });
  db.values.set("users/resident-a", {
    role: "resident",
    communityId: "A",
    approvalStatus: "pending",
    isActive: false,
    declaredResidentType: "owner",
    identityVerified: false,
    identityVerificationStatus: "verification_required",
  });
  const approval = await approveResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: approvalData("owner"),
  });
  assert.equal(approval.status, "approved");
  assert.equal(db.values.get("flats/flat-a").residentUserId, "resident-a");
  assert.equal(db.values.get("users/old-resident").occupancyStatus, "moved_out");
});

test("normal declared tenant can be proof-verified before canonical Admin approval", async () => {
  const db = fakeDb(approvalSeed({
    declaredResidentType: "tenant",
    identityVerificationStatus: "pending",
    identityProofStoragePath: "residentIdentityProofs/A/resident-a/proof.png",
  }));
  await reviewResidentIdentityProofCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "resident-a", decision: "verified"},
  });
  assert.equal(db.values.get("users/resident-a").identityVerified, true);
  assert.equal(db.values.get("users/resident-a").isActive, false);

  const approval = await approveResidentRegistrationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: approvalData("tenant"),
  });
  assert.equal(approval.isActive, true);
  assert.equal(db.values.get("users/resident-a").residentType, "tenant");
});

test("identity review cannot reactivate an approved resident assigned to another occupant", async () => {
  const db = fakeDb({
    "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
    "communities/A": {isActive: true},
    "buildings/building-a": {communityId: "A"},
    "users/tenant-a": {
      ...activeOccupant("tenant"),
      isActive: false,
      status: "inactive",
      identityVerified: false,
      identityVerificationStatus: "pending",
      identityProofStoragePath: "residentIdentityProofs/A/tenant-a/proof.png",
    },
    "flats/flat-a": {
      communityId: "A",
      buildingId: "building-a",
      status: "occupied",
      residentUserId: "other-resident",
    },
  });
  await reviewResidentIdentityProofCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "tenant-a", decision: "verified"},
  });
  assert.equal(db.values.get("users/tenant-a").identityVerificationStatus, "verified");
  assert.equal(db.values.get("users/tenant-a").isActive, false);
  assert.equal(db.values.get("users/tenant-a").status, "inactive");
});


test("rejection releases a claimed reservation atomically and retries preserve a new occupant", async () => {
  const {residentOnboardingId} = require("../src/resident_import_ids");
  const phone = "+639171100000";
  const id = residentOnboardingId("A", phone);
  const db = fakeDb(approvalSeed({phoneNumber: phone, flatId: "flat-a", buildingId: "building-a"}, {
    "flats/flat-a": {communityId: "A", buildingId: "building-a", status: "reserved", reservedOnboardingId: id, reservedForPhone: phone},
    [`residentOnboarding/${id}`]: {communityId: "A", buildingId: "building-a", flatId: "flat-a", status: "claimed", claimedByUid: "resident-a"},
    "bills/history": {flatId: "flat-a", residentId: "resident-a", status: "paid"},
  }));
  const run = () => rejectResidentRegistrationCore({db, auth: phoneAuth("admin-a"), data: {communityId: "A", userId: "resident-a"}});
  await run();
  assert.equal(db.values.get("flats/flat-a").status, "vacant");
  assert.equal(db.values.get("flats/flat-a").reservedOnboardingId, undefined);
  assert.equal(db.values.get("buildings/building-a").reserved, 0);
  assert.equal(db.values.get("buildings/building-a").vacant, 1);
  assert.equal(db.values.get(`residentOnboarding/${id}`).flatId, undefined);
  assert.equal(db.values.get("users/resident-a").flatId, undefined);
  assert.equal(db.values.get("bills/history").flatId, "flat-a");
  db.values.set("flats/flat-a", {communityId: "A", buildingId: "building-a", status: "occupied", residentUserId: "other"});
  assert.equal((await run()).idempotent, true);
  assert.equal(db.values.get("flats/flat-a").residentUserId, "other");
});

test("rejection preserves a different reservation or reassigned occupant", async () => {
  for (const allocation of [{status: "reserved", reservedOnboardingId: "other"}, {status: "occupied", residentUserId: "other"}]) {
    const flat = {communityId: "A", buildingId: "building-a", ...allocation};
    const db = fakeDb(approvalSeed({phoneNumber: "+639171100000", flatId: "flat-a", buildingId: "building-a"}, {"flats/flat-a": flat}));
    await rejectResidentRegistrationCore({db, auth: phoneAuth("admin-a"), data: {communityId: "A", userId: "resident-a"}});
    assert.deepEqual(db.values.get("flats/flat-a"), flat);
  }
});

test("rejection clears stale own occupancy and refreshes counters, but refuses foreign legacy links", async () => {
  for (const foreign of [false, true]) {
    const db = fakeDb(approvalSeed({flatId: "flat-a", buildingId: "building-a"}, {
      "flats/flat-a": {communityId: "A", buildingId: "building-a", status: "occupied", residentUserId: "resident-a", residentId: foreign ? "other" : null},
    }));
    const run = () => rejectResidentRegistrationCore({db, auth: phoneAuth("admin-a"), data: {communityId: "A", userId: "resident-a"}});
    if (foreign) await assert.rejects(run(), {code: "failed-precondition"});
    else {
      await run();
      assert.equal(db.values.get("flats/flat-a").status, "vacant");
      assert.equal(db.values.get("buildings/building-a").occupied, 0);
    }
  }
});


test("rejection releases a legacy-only own allocation", async () => {
  const db = fakeDb(approvalSeed({flatId: "flat-a", buildingId: "building-a", residentId: "legacy"}, {
    "flats/flat-a": {communityId: "A", buildingId: "building-a", status: "occupied", residentId: "legacy"},
  }));
  await rejectResidentRegistrationCore({db, auth: phoneAuth("admin-a"), data: {communityId: "A", userId: "resident-a"}});
  assert.equal(db.values.get("flats/flat-a").residentId, null);
  assert.equal(db.values.get("flats/flat-a").status, "vacant");
});


async function adminAwaitingFixture({legacy = false, owner = false} = {}) {
  const f = adminCreationFixture();
  f.data.residentType = owner ? "owner" : "tenant";
  if (owner) f.db.values.get("communities/A").ownerIdentityVerificationRequired = true;
  await f.run();
  const user = f.db.values.get("users/new-resident");
  Object.assign(user, {identityVerificationStatus: "pending", identityProofStoragePath: "residentIdentityProofs/A/new-resident/proof.png"});
  if (legacy) Object.assign(user, {approvalStatus: "approved", isActive: true, status: "active"});
  f.reject = (auth = phoneAuth("admin-a")) => rejectResidentRegistrationCore({db: f.db, auth, data: {communityId: "A", userId: "new-resident"}});
  f.review = (decision) => reviewResidentIdentityProofCore({db: f.db, auth: phoneAuth("admin-a"), data: {communityId: "A", userId: "new-resident", decision}});
  return f;
}

test("Admin onboarding rejection: new and legacy identity-pending registrations release only their allocation atomically", async () => {
  for (const legacy of [false, true]) for (const owner of [false, true]) {
    const f = await adminAwaitingFixture({legacy, owner});
    assert.equal(f.db.values.get("users/new-resident").registrationCompletedAt, undefined);
    const result = await f.reject();
    assert.equal(result.status, "rejected");
    assert.equal(f.db.values.get("users/new-resident").approvalStatus, "rejected");
    assert.equal(f.db.values.get("users/new-resident").isActive, false);
    assert.equal(f.db.values.get("users/new-resident").flatId, undefined);
    assert.equal(f.db.values.get("flats/flat-a").status, "vacant");
    assert.equal(f.db.values.get("flats/flat-a").residentUserId, null);
    assert.equal(f.db.values.get("buildings/building-a").occupied, 0);
    assert.equal(f.db.values.get("buildings/building-a").vacant, 1);
    assert.equal(f.calls.filter(([kind]) => kind === "create").length, 1);
    f.db.values.set("flats/flat-a", {communityId: "A", buildingId: "building-a", status: "occupied", residentUserId: "other"});
    assert.equal((await f.reject()).idempotent, true);
    assert.equal(f.db.values.get("flats/flat-a").residentUserId, "other");
  }
});

test("Admin onboarding rejection: proof rejection keeps the unit and permits resubmission; proof approval completes registration", async () => {
  const f = await adminAwaitingFixture();
  await f.review("rejected");
  assert.equal(f.db.values.get("users/new-resident").approvalStatus, "pending");
  assert.equal(f.db.values.get("flats/flat-a").status, "occupied");
  const bucket = {file: () => ({save: async () => {}, delete: async () => {}})};
  const residentAuth = phoneAuth("new-resident");
  residentAuth.token.phone_number = f.data.phoneNumber;
  await submitResidentIdentityProofCore({db: f.db, bucket, auth: residentAuth, data: {
    contentType: "image/png", base64: Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,1]).toString("base64"),
  }});
  assert.equal(f.db.values.get("users/new-resident").identityVerificationStatus, "pending");
  await f.review("verified");
  const user = f.db.values.get("users/new-resident");
  assert.equal(user.approvalStatus, "approved");
  assert.equal(user.isActive, true);
  assert.ok(user.registrationCompletedAt);
  await assert.rejects(f.reject(), {code: "failed-precondition"});
  assert.equal(f.db.values.get("flats/flat-a").status, "occupied");
});

test("Admin onboarding rejection: financial obligations, pending submissions, and ambiguous records block every write", async () => {
  for (const kind of ["due", "payment", "unknown", "deletion"]) {
    const f = await adminAwaitingFixture({legacy: true});
    if (kind === "due") f.db.values.set("bills/due", {residentId: "new-resident", communityId: "A", amount: 100, month: 10, year: 2026, status: "pending"});
    if (kind === "payment") f.db.values.set("payments/pending", {userId: "new-resident", communityId: "A", status: "pending"});
    if (kind === "unknown") f.db.values.set("bills/unknown", {residentId: "new-resident", communityId: "A"});
    if (kind === "deletion") f.db.values.set("accountDeletionRequests/existing", {uid: "new-resident", status: "pending_review"});
    await assert.rejects(f.reject(), {code: "failed-precondition"});
    assert.equal(f.db.values.get("users/new-resident").approvalStatus, "approved", kind);
    assert.equal(f.db.values.get("flats/flat-a").status, "occupied", kind);
  }
});

test("Admin onboarding rejection: shared occupants and reassigned units remain protected", async () => {
  for (const shared of [false, true]) {
    const f = await adminAwaitingFixture({legacy: true});
    const flat = f.db.values.get("flats/flat-a");
    Object.assign(flat, {residentIds: shared ? ["new-resident", "other"] : ["other"], residentUid: "other"});
    if (!shared) flat.residentUserId = "other";
    f.db.values.set("users/other", {role: "resident", communityId: "A", flatId: "flat-a"});
    await f.reject();
    assert.equal(flat.status, "occupied"); // original snapshot itself is never mutated by writes
    assert.equal(f.db.values.get("flats/flat-a").status, "occupied");
    assert.equal(f.db.values.get("flats/flat-a").residentUid, "other");
    assert.deepEqual(f.db.values.get("flats/flat-a").residentIds, ["other"]);
    assert.equal(f.db.values.get("users/other").flatId, "flat-a");
    assert.equal(f.db.values.get("buildings/building-a").occupied, 1);
  }
});

test("Admin onboarding rejection: settled financial history keeps its original unit links and Auth identities are retained", async () => {
  const f = await adminAwaitingFixture();
  const bill = {residentId: "new-resident", communityId: "A", flatId: "flat-a", amount: 100, month: 10, year: 2026, status: "paid", paidAt: new Date(1)};
  const payment = {userId: "new-resident", communityId: "A", flatId: "flat-a", status: "paid"};
  f.db.values.set("bills/settled", bill); f.db.values.set("payments/settled", payment);
  await f.reject();
  assert.deepEqual(f.db.values.get("bills/settled"), bill);
  assert.deepEqual(f.db.values.get("payments/settled"), payment);
  assert.ok(f.db.values.has("users/new-resident"));
  assert.equal(f.db.values.get("buildings/building-a").buildingName, "Tower A");
});

test("Admin onboarding rejection: community isolation and final-rejection identity guards stay authoritative", async () => {
  const f = await adminAwaitingFixture();
  f.db.values.set("admins/foreign", {uid: "foreign", role: "admin", isActive: true, authorizedCommunityIds: ["B"]});
  await assert.rejects(f.reject(phoneAuth("foreign")), {code: "permission-denied"});
  assert.equal(f.db.values.get("flats/flat-a").status, "occupied");
  await f.reject();
  await assert.rejects(f.review("verified"), {code: "failed-precondition"});
  assert.equal(f.db.values.get("users/new-resident").approvalStatus, "rejected");
});

test("Admin onboarding rejection: required, pending, and resubmittable proofs remain cancellable; completed approval does not", async () => {
  for (const status of ["verification_required", "pending", "rejected"]) {
    const f = await adminAwaitingFixture({legacy: true});
    f.db.values.get("users/new-resident").identityVerificationStatus = status;
    await f.reject();
    assert.equal(f.db.values.get("flats/flat-a").status, "vacant");
  }
  for (const change of [{identityVerified: true}, {identityVerificationStatus: "verified"}, {registrationCompletedAt: new Date(1)}]) {
    const f = await adminAwaitingFixture({legacy: true});
    Object.assign(f.db.values.get("users/new-resident"), change);
    await assert.rejects(f.reject(), {code: "failed-precondition"});
    assert.equal(f.db.values.get("flats/flat-a").status, "occupied");
  }
  const optionalOwner = adminCreationFixture();
  await optionalOwner.run();
  await assert.rejects(rejectResidentRegistrationCore({db: optionalOwner.db, auth: phoneAuth("admin-a"),
    data: {communityId: "A", userId: "new-resident"}}), {code: "failed-precondition"});
});

test("Admin onboarding rejection: an upload completing after final rejection cannot overwrite the cancelled registration", async () => {
  const f = await adminAwaitingFixture();
  const residentAuth = phoneAuth("new-resident");
  residentAuth.token.phone_number = f.data.phoneNumber;
  const previousPath = f.db.values.get("users/new-resident").identityProofStoragePath;
  const bucket = {file: () => ({save: async () => {await f.reject();}, delete: async () => {}})};
  await assert.rejects(submitResidentIdentityProofCore({db: f.db, bucket, auth: residentAuth, data: {
    contentType: "image/png", base64: Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,1]).toString("base64"),
  }}), {code: "failed-precondition"});
  const user = f.db.values.get("users/new-resident");
  assert.equal(user.approvalStatus, "rejected");
  assert.equal(user.isActive, false);
  assert.equal(user.identityProofStoragePath, previousPath);
  assert.equal(f.db.values.get("flats/flat-a").status, "vacant");
});
