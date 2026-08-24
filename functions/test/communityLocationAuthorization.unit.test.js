const test = require("node:test");
const assert = require("node:assert/strict");
const {
  communityLocationSearchCore,
  resolveCommunityLocationPlaceCore,
  reverseGeocodeCommunityLocationCore,
} = require("../src/community_geocoding");
const {
  updateCommunityLocationCore,
  validateLocationUpdateInput,
} = require("../src/community_location_management");

function phoneAuth(uid) {
  return {
    uid,
    token: {
      phone_number: "+639171234567",
      firebase: {sign_in_provider: "phone"},
    },
  };
}

const validLocation = {
  latitude: 14.5995,
  longitude: 120.9842,
  formattedAddress: "Community A, Manila",
  placeId: "place-a",
  attendanceRadiusMeters: 150,
};

function snapshot(id, data) {
  return {id, exists: data != null, data: () => data};
}

function fakeDb({admins = {}, communities = {}} = {}) {
  const updates = [];
  return {
    updates,
    collection(name) {
      return {
        doc(id) {
          return {
            id,
            async get() {
              return snapshot(
                id,
                name === "admins" ? admins[id] : communities[id],
              );
            },
            async update(value) {
              updates.push({name, id, value});
            },
          };
        },
      };
    },
  };
}

const adminA = {
  uid: "admin-a",
  role: "admin",
  isActive: true,
  authorizedCommunityIds: ["COMMUNITY_A"],
};
const communityA = {isActive: true, name: "A", slug: "a"};
const communityB = {isActive: true, name: "B", slug: "b"};

test("authorized Admin A updates only Community A location fields", async () => {
  const db = fakeDb({
    admins: {"admin-a": adminA},
    communities: {COMMUNITY_A: communityA},
  });
  const result = await updateCommunityLocationCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {communityId: "COMMUNITY_A", location: validLocation},
  });
  assert.equal(result.communityId, "COMMUNITY_A");
  assert.equal(db.updates.length, 1);
  assert.deepEqual(Object.keys(db.updates[0].value).sort(), ["location", "locationConfigured"]);
  assert.equal(db.updates[0].value.location.updatedAt.constructor.name, "ServerTimestampTransform");
});

test("Admin A updating Community B is denied, including forged communityId", async () => {
  const db = fakeDb({
    admins: {"admin-a": adminA},
    communities: {COMMUNITY_A: communityA, COMMUNITY_B: communityB},
  });
  await assert.rejects(
    () => updateCommunityLocationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {communityId: "COMMUNITY_B", location: validLocation},
    }),
    {code: "permission-denied"},
  );
  assert.equal(db.updates.length, 0);
});

test("inactive target community is denied", async () => {
  const db = fakeDb({
    admins: {"admin-a": adminA},
    communities: {COMMUNITY_A: {isActive: false}},
  });
  await assert.rejects(
    () => updateCommunityLocationCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {communityId: "COMMUNITY_A", location: validLocation},
    }),
    {code: "failed-precondition"},
  );
});

test("invalid latitude, longitude, and radius are denied", () => {
  for (const location of [
    {...validLocation, latitude: 91},
    {...validLocation, longitude: -181},
    {...validLocation, attendanceRadiusMeters: 24},
    {...validLocation, attendanceRadiusMeters: 150.5},
    {...validLocation, formattedAddress: 123},
    {...validLocation, placeId: 123},
  ]) {
    assert.throws(
      () => validateLocationUpdateInput({communityId: "COMMUNITY_A", location}),
      {code: "invalid-argument"},
    );
  }
});

test("active authorized admin location search succeeds", async () => {
  const db = fakeDb({
    admins: {"admin-a": adminA},
    communities: {COMMUNITY_A: communityA},
  });
  const result = await communityLocationSearchCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {query: "Community A", sessionToken: "session_admin_a", countryCode: "PH"},
    apiKey: "server-secret",
    fetchImpl: async (url, options) => {
      assert.equal(url, "https://places.googleapis.com/v1/places:autocomplete");
      assert.equal(options.headers["X-Goog-Api-Key"], "server-secret");
      assert.deepEqual(JSON.parse(options.body), {
        input: "Community A",
        sessionToken: "session_admin_a",
        includedRegionCodes: ["ph"],
      });
      return {
        ok: true,
        async json() {
          return {suggestions: [{placePrediction: {
            placeId: "place-a",
            text: {text: "Green Valley, Manila"},
            structuredFormat: {
              mainText: {text: "Green Valley"},
              secondaryText: {text: "Manila"},
            },
          }}]};
        },
      };
    },
  });
  assert.deepEqual(result.suggestions[0], {
    placeId: "place-a",
    primaryText: "Green Valley",
    secondaryText: "Manila",
    displayText: "Green Valley, Manila",
  });
});

test("active superAdmin location search succeeds", async () => {
  const db = fakeDb({
    admins: {
      root: {uid: "root", role: "superAdmin", isActive: true},
    },
  });
  const result = await communityLocationSearchCore({
    db,
    auth: phoneAuth("root"),
    data: {query: "Manila", sessionToken: "session_root"},
    apiKey: "server-secret",
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({status: "ZERO_RESULTS", results: []}),
    }),
  });
  assert.deepEqual(result, {suggestions: []});
});

test("inactive admin location search is denied", async () => {
  const db = fakeDb({
    admins: {"admin-a": {...adminA, isActive: false}},
    communities: {COMMUNITY_A: communityA},
  });
  await assert.rejects(
    () => communityLocationSearchCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {query: "Manila"},
      apiKey: "server-secret",
    }),
    {code: "permission-denied"},
  );
});

test("resident, security, and unauthenticated location search are denied", async () => {
  const db = fakeDb({
    admins: {
      "resident-a": {
        uid: "resident-a",
        role: "resident",
        isActive: true,
        authorizedCommunityIds: ["COMMUNITY_A"],
      },
      "security-a": {
        uid: "security-a",
        role: "security",
        isActive: true,
        authorizedCommunityIds: ["COMMUNITY_A"],
      },
    },
    communities: {COMMUNITY_A: communityA},
  });
  for (const auth of [phoneAuth("resident-a"), phoneAuth("security-a"), null]) {
    await assert.rejects(
      () => communityLocationSearchCore({
        db,
        auth,
        data: {query: "Manila"},
        apiKey: "server-secret",
      }),
      {code: auth == null ? "unauthenticated" : "permission-denied"},
    );
  }
});

test("autocomplete rejects malformed query/token and supports optional countryCode", async () => {
  const db = fakeDb({admins: {"admin-a": adminA}, communities: {COMMUNITY_A: communityA}});
  for (const data of [
    {query: "ab", sessionToken: "session_123"},
    {query: "Manila", sessionToken: "short"},
    {query: "Manila", sessionToken: "session_123", countryCode: "PHL"},
  ]) {
    await assert.rejects(() => communityLocationSearchCore({
      db,
      auth: phoneAuth("admin-a"),
      data,
      apiKey: "server-secret",
    }), {code: "invalid-argument"});
  }
  const result = await communityLocationSearchCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {query: "Global Place", sessionToken: "session_global"},
    apiKey: "server-secret",
    fetchImpl: async (_, options) => {
      assert.equal(JSON.parse(options.body).includedRegionCodes, undefined);
      return {ok: true, json: async () => ({suggestions: []})};
    },
  });
  assert.deepEqual(result, {suggestions: []});
});

test("selected Place Details returns canonical address and coordinates", async () => {
  const db = fakeDb({admins: {"admin-a": adminA}, communities: {COMMUNITY_A: communityA}});
  const result = await resolveCommunityLocationPlaceCore({
    db,
    auth: phoneAuth("admin-a"),
    data: {placeId: "place-a", sessionToken: "session_admin_a"},
    apiKey: "server-secret",
    fetchImpl: async (url, options) => {
      assert.equal(url.pathname, "/v1/places/place-a");
      assert.equal(url.searchParams.get("sessionToken"), "session_admin_a");
      assert.equal(options.headers["X-Goog-FieldMask"], "id,displayName,formattedAddress,location");
      return {ok: true, json: async () => ({
        id: "place-a",
        displayName: {text: "Green Valley"},
        formattedAddress: "Green Valley, Manila",
        location: {latitude: 14.5995, longitude: 120.9842},
      })};
    },
  });
  assert.deepEqual(result.result, {
    placeId: "place-a",
    displayName: "Green Valley",
    formattedAddress: "Green Valley, Manila",
    latitude: 14.5995,
    longitude: 120.9842,
  });
});

test("Place Details rejects missing or invalid placeId", async () => {
  const db = fakeDb({admins: {"admin-a": adminA}, communities: {COMMUNITY_A: communityA}});
  for (const placeId of [null, "", "bad place id"]) {
    await assert.rejects(() => resolveCommunityLocationPlaceCore({
      db,
      auth: phoneAuth("admin-a"),
      data: {placeId, sessionToken: "session_admin_a"},
      apiKey: "server-secret",
    }), {code: "invalid-argument"});
  }
});

test("authorized admin reverse geocode succeeds and ZERO_RESULTS is safe", async () => {
  const db = fakeDb({admins: {"admin-a": adminA}, communities: {COMMUNITY_A: communityA}});
  const base = {
    db,
    auth: phoneAuth("admin-a"),
    data: {latitude: 14.5995, longitude: 120.9842},
    apiKey: "server-secret",
  };
  const success = await reverseGeocodeCommunityLocationCore({
    ...base,
    fetchImpl: async (url) => {
      assert.equal(url.searchParams.get("latlng"), "14.5995,120.9842");
      return {ok: true, json: async () => ({
        status: "OK",
        results: [{formatted_address: "Manila, Philippines", place_id: "place-manila"}],
      })};
    },
  });
  assert.equal(success.result.formattedAddress, "Manila, Philippines");
  assert.equal(success.result.placeId, "place-manila");
  const zero = await reverseGeocodeCommunityLocationCore({
    ...base,
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({status: "ZERO_RESULTS", results: []}),
    }),
  });
  assert.deepEqual(zero, {result: null});
});

test("reverse geocode denies invalid coordinates and unauthorized identities", async () => {
  const db = fakeDb({
    admins: {
      "admin-a": adminA,
      "inactive-a": {...adminA, uid: "inactive-a", isActive: false},
      "resident-a": {...adminA, uid: "resident-a", role: "resident"},
      "security-a": {...adminA, uid: "security-a", role: "security"},
    },
    communities: {COMMUNITY_A: communityA},
  });
  for (const data of [
    {latitude: 91, longitude: 120},
    {latitude: 14, longitude: -181},
  ]) {
    await assert.rejects(() => reverseGeocodeCommunityLocationCore({
      db,
      auth: phoneAuth("admin-a"),
      data,
      apiKey: "server-secret",
    }), {code: "invalid-argument"});
  }
  for (const auth of [
    phoneAuth("inactive-a"),
    phoneAuth("resident-a"),
    phoneAuth("security-a"),
    null,
  ]) {
    await assert.rejects(() => reverseGeocodeCommunityLocationCore({
      db,
      auth,
      data: {latitude: 14, longitude: 120},
      apiKey: "server-secret",
    }), {code: auth == null ? "unauthenticated" : "permission-denied"});
  }
});
