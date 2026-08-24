const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeCommunityId,
  normalizeSlug,
  validateCommunityInput,
  isIdempotentCommunity,
  createCommunityCore,
} = require("../src/create_community");

const auth = { uid: "actor-1", token: { phone_number: "+15550000001", firebase: { sign_in_provider: "phone" } } };

function fakeDb(admin) {
  const values = new Map([["admins/actor-1", admin]]);
  const snapshot = (path) => ({ id: path.split("/").pop(), exists: values.has(path), data: () => values.get(path) });
  const doc = (name, id) => ({ path: `${name}/${id}`, get: async () => snapshot(`${name}/${id}`), update: async (changes) => values.set(`${name}/${id}`, { ...values.get(`${name}/${id}`), ...changes }) });
  return {
    values,
    collection: (name) => ({
      doc: (id) => doc(name, id),
      where: (field, _op, expected) => ({ limit: () => ({ get: async () => ({ docs: [...values.entries()].filter(([path, data]) => path.startsWith(`${name}/`) && data[field] === expected).map(([path]) => snapshot(path)) }) }) }),
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => snapshot(ref.path),
      set: (ref, data) => values.set(ref.path, data),
      update: (ref, changes) => values.set(ref.path, { ...values.get(ref.path), ...changes }),
      delete: (ref) => values.delete(ref.path),
    }),
  };
}

test("community ID and slug normalization are deterministic", () => {
  assert.equal(normalizeCommunityId(" gv 0701 "), "GV-0701");
  assert.equal(normalizeCommunityId("GV--0701"), "GV-0701");
  assert.equal(normalizeSlug(" Green Valley Phase 1 "), "green-valley-phase-1");
});

test("input requires a lowercase kebab-case slug", () => {
  const input = validateCommunityInput({ communityId: "gv 0701", name: " Green Valley ", slug: "green-valley" });
  assert.equal(input.communityId, "GV-0701");
  assert.equal(input.websitePath, "green-valley");
  assert.equal(input.databaseId, "(default)");
  assert.throws(() => validateCommunityInput({ communityId: "GV-0701", name: "Green Valley", slug: "Green Valley" }), { code: "invalid-argument" });
  assert.throws(() => validateCommunityInput({ communityId: "GV-0701", name: "Green Valley", slug: "green-valley", isActive: false }), { code: "invalid-argument" });
});

test("community may be created without a configured location", () => {
  const input = validateCommunityInput({
    communityId: "GV-0701",
    name: "Green Valley",
    slug: "green-valley",
    locationConfigured: false,
  });

  assert.equal(
    input.locationConfigured,
    false,
  );

  assert.equal(
    input.location,
    null,
  );
});

test("valid community location is normalized", () => {
  const input = validateCommunityInput({
    communityId: "GV-0701",
    name: "Green Valley",
    slug: "green-valley",
    locationConfigured: true,
    location: {
      latitude: 14.554729,
      longitude: 121.024445,
      formattedAddress:
        " Green Valley, Taguig ",
      placeId: " sample-place-id ",
      attendanceRadiusMeters: 150,
    },
  });

  assert.equal(
    input.locationConfigured,
    true,
  );

  assert.equal(
    input.location.latitude,
    14.554729,
  );

  assert.equal(
    input.location.longitude,
    121.024445,
  );

  assert.equal(
    input.location.formattedAddress,
    "Green Valley, Taguig",
  );

  assert.equal(
    input.location.placeId,
    "sample-place-id",
  );

  assert.equal(
    input.location.attendanceRadiusMeters,
    150,
  );
});

test("invalid community latitude is rejected", () => {
  assert.throws(
    () =>
      validateCommunityInput({
        communityId: "GV-0701",
        name: "Green Valley",
        slug: "green-valley",
        locationConfigured: true,
        location: {
          latitude: 100,
          longitude: 121.024445,
          formattedAddress:
            "Green Valley, Taguig",
          attendanceRadiusMeters: 150,
        },
      }),
    {
      code: "invalid-argument",
    },
  );
});

test("invalid community longitude is rejected", () => {
  assert.throws(
    () =>
      validateCommunityInput({
        communityId: "GV-0701",
        name: "Green Valley",
        slug: "green-valley",
        locationConfigured: true,
        location: {
          latitude: 14.554729,
          longitude: 200,
          formattedAddress:
            "Green Valley, Taguig",
          attendanceRadiusMeters: 150,
        },
      }),
    {
      code: "invalid-argument",
    },
  );
});

test("empty community address is rejected", () => {
  assert.throws(
    () =>
      validateCommunityInput({
        communityId: "GV-0701",
        name: "Green Valley",
        slug: "green-valley",
        locationConfigured: true,
        location: {
          latitude: 14.554729,
          longitude: 121.024445,
          formattedAddress: "",
          attendanceRadiusMeters: 150,
        },
      }),
    {
      code: "invalid-argument",
    },
  );
});

test("invalid attendance radius is rejected", () => {
  assert.throws(
    () =>
      validateCommunityInput({
        communityId: "GV-0701",
        name: "Green Valley",
        slug: "green-valley",
        locationConfigured: true,
        location: {
          latitude: 14.554729,
          longitude: 121.024445,
          formattedAddress:
            "Green Valley, Taguig",
          attendanceRadiusMeters: 10,
        },
      }),
    {
      code: "invalid-argument",
    },
  );
});

test("client supplied location timestamp is rejected", () => {
  assert.throws(
    () =>
      validateCommunityInput({
        communityId: "GV-0701",
        name: "Green Valley",
        slug: "green-valley",
        locationConfigured: true,
        location: {
          latitude: 14.554729,
          longitude: 121.024445,
          formattedAddress:
            "Green Valley, Taguig",
          attendanceRadiusMeters: 150,
          updatedAt: "client-value",
        },
      }),
    {
      code: "invalid-argument",
    },
  );
});

test("active superAdmin creates a community with location", async () => {
  const admin = {
    uid: "actor-1",
    role: "superAdmin",
    isActive: true,
    authorizedCommunityIds: [],
  };

  const db = fakeDb(admin);

  const result =
    await createCommunityCore({
      db,
      auth,
      data: {
        communityId: "LOC-001",
        name: "Location Community",
        slug: "location-community",
        locationConfigured: true,
        location: {
          latitude: 14.554729,
          longitude: 121.024445,
          formattedAddress:
            "Green Valley, Taguig",
          placeId:
            "sample-place-id",
          attendanceRadiusMeters:
            150,
        },
      },
    });

  assert.deepEqual(result, {
    communityId: "LOC-001",
    idempotent: false,
  });

  const stored =
    db.values.get(
      "communities/LOC-001",
    );

  assert.equal(
    stored.locationConfigured,
    true,
  );

  assert.equal(
    stored.location.latitude,
    14.554729,
  );

  assert.equal(
    stored.location.longitude,
    121.024445,
  );

  assert.equal(
    stored.location.formattedAddress,
    "Green Valley, Taguig",
  );

  assert.equal(
    stored.location.attendanceRadiusMeters,
    150,
  );

  assert.ok(
    stored.location.updatedAt,
  );
});

test("idempotency requires matching values and creator", () => {
  const input = { communityId: "GV-0701", name: "Green Valley", slug: "green-valley", websitePath: "green-valley" };
  assert.equal(isIdempotentCommunity({ name: "Green Valley", slug: "green-valley", isActive: true, createdBy: "admin-1" }, input, "admin-1"), true);
  assert.equal(isIdempotentCommunity({ name: "Other", slug: "green-valley", isActive: true, createdBy: "admin-1" }, input, "admin-1"), false);
  assert.equal(isIdempotentCommunity({ name: "Green Valley", slug: "green-valley", isActive: true, createdBy: "admin-2" }, input, "admin-1"), false);
});

test("ordinary admin cannot create a community", async () => {
  const db = fakeDb({ uid: "actor-1", role: "admin", isActive: true, authorizedCommunityIds: ["EXISTING"] });
  await assert.rejects(
    createCommunityCore({ db, auth, data: { communityId: "NEW", name: "New Community", slug: "new-community" } }),
    { code: "permission-denied" },
  );
  assert.equal(db.values.has("communities/NEW"), false);
});

test("active superAdmin creates a community without self-assignment", async () => {
  const admin = { uid: "actor-1", role: "superAdmin", isActive: true, authorizedCommunityIds: [] };
  const db = fakeDb(admin);
  const result = await createCommunityCore({ db, auth, data: { communityId: "NEW", name: "New Community", slug: "new-community" } });
  assert.deepEqual(result, { communityId: "NEW", idempotent: false });
  assert.equal(db.values.get("communities/NEW").createdBy, "actor-1");
  assert.deepEqual(db.values.get("admins/actor-1").authorizedCommunityIds, []);
});
