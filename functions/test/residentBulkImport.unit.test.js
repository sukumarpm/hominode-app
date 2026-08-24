const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizePhone,
  validateResidentBulkImportCore,
  importResidentsBulkCore,
} = require("../src/resident_bulk_import");
const {registerResidentCore} = require("../src/register_resident");
const {residentOnboardingId} = require("../src/resident_import_ids");

function phoneAuth(uid, phone = "+14155550100") {
  return {uid, token: {phone_number: phone, firebase: {sign_in_provider: "phone"}}};
}

function fakeDb(seed = {}) {
  const values = new Map(Object.entries(seed));
  const writes = [];
  const makeSnapshot = (path) => ({
    id: path.split("/").pop(),
    exists: values.has(path),
    data: () => values.get(path),
  });
  const makeRef = (path) => ({
    id: path.split("/").pop(),
    _path: path,
    async get() { return makeSnapshot(path); },
    async create(data) {
      if (values.has(path)) throw new Error("already exists");
      values.set(path, data);
      writes.push({operation: "create", path, data});
    },
    async set(data) {
      values.set(path, data);
      writes.push({operation: "set", path, data});
    },
    async update(data) {
      if (!values.has(path)) throw new Error("missing");
      values.set(path, {...values.get(path), ...data});
      writes.push({operation: "update", path, data});
    },
  });
  function queryFor(collectionName, clauses = []) {
    return {
      where(field, operator, expected) {
        assert.equal(operator, "==");
        return queryFor(collectionName, [...clauses, {field, expected}]);
      },
      async get() {
        const prefix = `${collectionName}/`;
        const docs = [];
        for (const [path, data] of values) {
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes("/")) continue;
          if (clauses.every(({field, expected}) => data?.[field] === expected)) docs.push(makeSnapshot(path));
        }
        return {docs, empty: docs.length === 0, size: docs.length};
      },
    };
  }
  return {
    values,
    writes,
    collection(name) {
      return {...queryFor(name), doc: (id) => makeRef(`${name}/${id}`)};
    },
    async runTransaction(action) {
      return action({
        get: (ref) => ref.get(),
        create(ref, data) {
          if (values.has(ref._path)) throw new Error("already exists");
          values.set(ref._path, data);
          writes.push({operation: "create", path: ref._path, data});
        },
        update(ref, data) {
          values.set(ref._path, {...values.get(ref._path), ...data});
          writes.push({operation: "update", path: ref._path, data});
        },
        set(ref, data) {
          values.set(ref._path, data);
          writes.push({operation: "set", path: ref._path, data});
        },
      });
    },
  };
}

const baseSeed = {
  "admins/admin-a": {uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["A"]},
  "admins/resident-a": {uid: "resident-a", role: "resident", isActive: true, authorizedCommunityIds: ["A"]},
  "admins/security-a": {uid: "security-a", role: "security", isActive: true, authorizedCommunityIds: ["A"]},
  "communities/A": {name: "Alpha", isActive: true, countryCode: "US"},
  "communities/B": {name: "Beta", isActive: true, countryCode: "US"},
  "buildings/building-a": {communityId: "A", buildingId: "building-a", name: "Tower A"},
  "buildings/building-b": {communityId: "B", buildingId: "building-b", name: "Tower B"},
  "flats/flat-a-101": {communityId: "A", buildingId: "building-a", flatId: "A101", flatLabel: "A-101", flatNumber: 101},
  "flats/flat-a-102": {communityId: "A", buildingId: "building-a", flatId: "A102", flatLabel: "A-102", flatNumber: 102},
  "flats/flat-b-101": {communityId: "B", buildingId: "building-b", flatId: "B101", flatLabel: "B-101", flatNumber: 101},
};

const row = (overrides = {}) => ({
  rowNumber: 2,
  building: "Tower A",
  unit: "A101",
  residentName: "Alex Resident",
  phoneNumber: "+14155552671",
  residentType: "owner",
  email: "alex@example.com",
  countryCode: "US",
  ...overrides,
});

const args = (db, rows, extras = {}) => ({
  db,
  auth: phoneAuth("admin-a"),
  data: {communityId: "A", sourceFileName: "residents.csv", rows, ...extras},
});

test("valid owner and tenant rows validate with canonical building and unit IDs", async () => {
  const result = await validateResidentBulkImportCore(args(fakeDb(baseSeed), [
    row(),
    row({rowNumber: 3, unit: "A102", residentName: "Taylor Tenant", phoneNumber: "+14155552672", residentType: "tenant"}),
  ]));
  assert.deepEqual(result.summary, {totalRows: 2, validRows: 2, errorRows: 0, alreadyImportedRows: 0});
  assert.equal(result.rows[0].buildingId, "building-a");
  assert.equal(result.rows[0].flatId, "flat-a-101");
  assert.equal(result.rows[1].residentType, "tenant");
});

test("mixed validation returns actionable phone, building, unit, and duplicate errors", async () => {
  const result = await validateResidentBulkImportCore(args(fakeDb(baseSeed), [
    row(),
    row({rowNumber: 3, unit: "A102"}),
    row({rowNumber: 4, phoneNumber: "not-a-phone"}),
    row({rowNumber: 5, phoneNumber: "+14155552673", building: "Missing"}),
    row({rowNumber: 6, phoneNumber: "+14155552674", unit: "Missing"}),
  ]));
  assert.deepEqual(result.rows.map((item) => item.code ?? item.status), [
    "ready", "duplicate_in_file", "invalid_phone_number", "building_not_found", "unit_not_found",
  ]);
});

test("existing resident and pending registration duplicates are community scoped", async () => {
  const db = fakeDb({
    ...baseSeed,
    "users/existing-a": {communityId: "A", role: "resident", phoneNumber: "+14155552671"},
    "residentOnboarding/pending": {communityId: "A", phoneNumber: "+14155552672", status: "pending_registration"},
    "users/existing-b": {communityId: "B", role: "resident", phoneNumber: "+14155552673"},
  });
  const result = await validateResidentBulkImportCore(args(db, [
    row(),
    row({rowNumber: 3, unit: "A102", phoneNumber: "+14155552672"}),
    row({rowNumber: 4, unit: "A102", residentName: "Community Scoped", phoneNumber: "+14155552673", residentType: "tenant"}),
  ]));
  assert.equal(result.rows[0].code, "resident_already_exists");
  assert.equal(result.rows[1].code, "pending_registration_exists");
  assert.equal(result.rows[2].status, "ready");
});

test("forged community and cross-community building or unit references fail closed", async () => {
  const db = fakeDb(baseSeed);
  await assert.rejects(() => validateResidentBulkImportCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "B", rows: [row({building: "Tower B", unit: "B101"})]},
  }), {code: "permission-denied"});
  const result = await validateResidentBulkImportCore(args(db, [
    row({building: "building-b"}),
    row({rowNumber: 3, phoneNumber: "+14155552672", unit: "B101"}),
  ]));
  assert.deepEqual(result.rows.map((item) => item.code), ["building_not_found", "unit_not_found"]);
});

test("inactive Admin, inactive community, Resident, Security, unknown role, and unauthenticated are denied", async () => {
  const cases = [
    {auth: phoneAuth("admin-a"), seed: {...baseSeed, "admins/admin-a": {...baseSeed["admins/admin-a"], isActive: false}}, code: "permission-denied"},
    {auth: phoneAuth("admin-a"), seed: {...baseSeed, "communities/A": {...baseSeed["communities/A"], isActive: false}}, code: "failed-precondition"},
    {auth: phoneAuth("resident-a"), seed: baseSeed, code: "permission-denied"},
    {auth: phoneAuth("security-a"), seed: baseSeed, code: "permission-denied"},
    {auth: phoneAuth("unknown"), seed: {...baseSeed, "admins/unknown": {uid: "unknown", role: "auditor", isActive: true, authorizedCommunityIds: ["A"]}}, code: "permission-denied"},
    {auth: null, seed: baseSeed, code: "unauthenticated"},
  ];
  for (const item of cases) {
    await assert.rejects(() => validateResidentBulkImportCore({db: fakeDb(item.seed), auth: item.auth, data: {communityId: "A", rows: [row()]}}), {code: item.code});
  }
});

test("malformed payload, too many rows, and client-owned trusted fields are rejected", async () => {
  const db = fakeDb(baseSeed);
  for (const data of [
    {communityId: "A", rows: []},
    {communityId: "A", rows: Array.from({length: 501}, () => row())},
    {communityId: "A", rows: [{...row(), role: "admin"}]},
    {communityId: "A", rows: [{...row(), identityVerified: true}]},
    {communityId: "A", rows: [{...row(), isActive: true}]},
  ]) {
    await assert.rejects(() => validateResidentBulkImportCore({db, auth: phoneAuth("admin-a"), data}), {code: "invalid-argument"});
  }
});

test("national phones require context and normalize to E.164", () => {
  assert.equal(normalizePhone("(415) 555-2671", "US"), "+14155552671");
  assert.throws(() => normalizePhone("4155552671", null), {rowCode: "missing_country_context"});
});

test("import writes only pending unverified onboarding records and audit data", async () => {
  const db = fakeDb(baseSeed);
  const result = await importResidentsBulkCore(args(db, [row()], {importJobId: "job_20260825_alpha"}));
  assert.equal(result.rows[0].status, "imported");
  const onboarding = [...db.values.entries()].find(([path]) => path.startsWith("residentOnboarding/"))[1];
  assert.equal(onboarding.role, "resident");
  assert.equal(onboarding.approvalStatus, "pending");
  assert.equal(onboarding.isActive, false);
  assert.equal(onboarding.identityVerified, false);
  assert.equal(onboarding.creationSource, "admin_bulk_import");
  assert.equal(onboarding.communityId, "A");
  assert.equal(onboarding.createdBy, "admin-a");
  assert.equal(db.values.get("residentImportJobs/job_20260825_alpha").status, "completed");
});

test("same job and row retry is idempotent", async () => {
  const db = fakeDb(baseSeed);
  const request = args(db, [row()], {importJobId: "job_20260825_retry"});
  assert.equal((await importResidentsBulkCore(request)).rows[0].status, "imported");
  assert.equal((await importResidentsBulkCore(request)).rows[0].status, "already_imported");
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("residentOnboarding/")).length, 1);
  const forgedReplacement = await importResidentsBulkCore(args(db, [
    row({residentName: "Replacement Person", phoneNumber: "+14155552679"}),
  ], {importJobId: "job_20260825_retry"}));
  assert.equal(forgedReplacement.rows[0].status, "already_imported");
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("residentOnboarding/")).length, 1);
});

test("retry cannot introduce a row number outside the original job", async () => {
  const db = fakeDb(baseSeed);
  const importJobId = "job_20260825_scope";
  await importResidentsBulkCore(args(db, [row()], {importJobId}));
  await assert.rejects(() => importResidentsBulkCore(args(db, [
    row({rowNumber: 9, unit: "A102", phoneNumber: "+14155552672"}),
  ], {importJobId})), {code: "failed-precondition"});
});

test("a corrected failed row can be retried in the same job without duplicating successful rows", async () => {
  const db = fakeDb(baseSeed);
  const importJobId = "job_20260825_rows";
  const first = await importResidentsBulkCore(args(db, [
    row(),
    row({rowNumber: 3, unit: "Missing", phoneNumber: "+14155552672", residentType: "tenant"}),
  ], {importJobId}));
  assert.deepEqual(first.rows.map((item) => item.status), ["imported", "error"]);
  const retry = await importResidentsBulkCore(args(db, [
    row({rowNumber: 3, unit: "A102", phoneNumber: "+14155552672", residentType: "tenant"}),
  ], {importJobId}));
  assert.equal(retry.rows[0].status, "imported");
  assert.equal([...db.values.keys()].filter((path) => path.startsWith("residentOnboarding/")).length, 2);
  const job = db.values.get(`residentImportJobs/${importJobId}`);
  assert.equal(job.totalRows, 2);
  assert.equal(job.successCount, 2);
  assert.equal(job.failedCount, 0);
});

test("existing OTP registration binds matching imported onboarding without verifying or activating identity", async () => {
  const phone = "+14155552671";
  const onboardingPath = `residentOnboarding/${residentOnboardingId("A", phone)}`;
  const db = fakeDb({
    ...baseSeed,
    "communityInvites/ALPHA1": {communityId: "A", isActive: true, useCount: 0, usedCount: 0, maxUses: 10},
    [onboardingPath]: {
      communityId: "A",
      phoneNumber: phone,
      status: "pending_registration",
      claimedByUid: null,
      buildingId: "building-a",
      buildingName: "Tower A",
      buildingReference: "Tower A",
      flatId: "flat-a-101",
      unitId: "A101",
      flatLabel: "A-101",
      unitReference: "A101",
      residentType: "owner",
      importJobId: "job_20260825_claim",
    },
  });
  const result = await registerResidentCore({
    db,
    auth: phoneAuth("resident-auth-uid", phone),
    data: {
      inviteCode: "ALPHA1",
      fullName: "Alex Resident",
      buildingReference: "Typed value",
      unitReference: "Typed value",
      email: "alex@example.com",
    },
  });
  assert.equal(result.status, "pending");
  const profile = db.values.get("users/resident-auth-uid");
  assert.equal(profile.role, "resident");
  assert.equal(profile.approvalStatus, "pending");
  assert.equal(profile.isActive, false);
  assert.equal(profile.buildingId, "building-a");
  assert.equal(profile.flatId, "flat-a-101");
  assert.equal(profile.ownershipType, "owner");
  assert.equal(profile.creationSource, "admin_bulk_import_claim");
  assert.equal(profile.identityVerified, undefined);
  const onboarding = db.values.get(onboardingPath);
  assert.equal(onboarding.status, "claimed");
  assert.equal(onboarding.claimedByUid, "resident-auth-uid");
});
