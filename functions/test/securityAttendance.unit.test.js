const test = require("node:test");
const assert = require("node:assert/strict");
const {
  LOCATION_NOT_CONFIGURED,
  validateGps,
  haversineMeters,
  validatedCommunityLocation,
  locationAudit,
  requireInsideGeofence,
  loadAttendanceAuthority,
  securityCheckInCore,
} = require("../src/security_attendance");

const auth = {
  uid: "security-a",
  token: {
    phone_number: "+639171234567",
    firebase: {sign_in_provider: "phone"},
  },
};
const activeStaff = {
  uid: "security-a",
  role: "security",
  isActive: true,
  communityId: "COMMUNITY_A",
  name: "Guard A",
};
const activeCommunity = {
  isActive: true,
  locationConfigured: true,
  location: {latitude: 14.5995, longitude: 120.9842, attendanceRadiusMeters: 150},
};

function snapshot(data) {
  return {exists: data != null, data: () => data};
}

function authorityDb({staff = activeStaff, communities = {COMMUNITY_A: activeCommunity}} = {}) {
  return {
    collection(name) {
      return {
        doc(id) {
          return {
            get: async () => snapshot(name === "securityStaff" ? staff : communities[id]),
          };
        },
      };
    },
  };
}

test("inside-radius location validates", () => {
  const distance = haversineMeters(
    {latitude: 14.5995, longitude: 120.9842},
    {latitude: 14.5996, longitude: 120.9842},
  );
  assert.ok(distance < 150);
  assert.doesNotThrow(() => requireInsideGeofence(locationAudit(
    {latitude: 14.5995, longitude: 120.9842, accuracyMeters: 5},
    {latitude: 14.5996, longitude: 120.9842, allowedRadiusMeters: 150},
  )));
});

test("outside-radius location is distinguishable", () => {
  const distance = haversineMeters(
    {latitude: 14.5995, longitude: 120.9842},
    {latitude: 14.61, longitude: 120.9842},
  );
  assert.ok(distance > 150);
  assert.throws(() => requireInsideGeofence(locationAudit(
    {latitude: 14.5995, longitude: 120.9842, accuracyMeters: 5},
    {latitude: 14.61, longitude: 120.9842, allowedRadiusMeters: 150},
  )), {code: "failed-precondition"});
});

test("missing and legacy community locations fail closed", () => {
  for (const community of [{isActive: true}, {isActive: true, locationConfigured: false}]) {
    assert.throws(() => validatedCommunityLocation(community), {message: LOCATION_NOT_CONFIGURED});
  }
});

test("invalid coordinates and accuracy are rejected", () => {
  assert.throws(() => validateGps({latitude: 91, longitude: 1, accuracyMeters: 5}));
  assert.throws(() => validateGps({latitude: 1, longitude: 181, accuracyMeters: 5}));
  assert.throws(() => validateGps({latitude: 1, longitude: 1, accuracyMeters: 0}));
  assert.throws(() => validateGps({latitude: 1, longitude: 1, accuracyMeters: 101}));
});

test("inactive Security profile is rejected", async () => {
  await assert.rejects(
    () => loadAttendanceAuthority(authorityDb({staff: {...activeStaff, isActive: false}}), auth),
    {code: "permission-denied"},
  );
});

test("inactive community is rejected", async () => {
  await assert.rejects(
    () => loadAttendanceAuthority(authorityDb({communities: {COMMUNITY_A: {...activeCommunity, isActive: false}}}), auth),
    {code: "failed-precondition"},
  );
});

test("forged communityId is ignored and staff profile remains authoritative", async () => {
  const result = await loadAttendanceAuthority(authorityDb(), auth, {communityId: "COMMUNITY_B"});
  assert.equal(result.communityId, "COMMUNITY_A");
  assert.equal(result.community, activeCommunity);
});

test("Security A cannot use Community B location", async () => {
  const communityB = {...activeCommunity, location: {...activeCommunity.location, latitude: 20}};
  const result = await loadAttendanceAuthority(
    authorityDb({communities: {COMMUNITY_A: activeCommunity, COMMUNITY_B: communityB}}),
    auth,
  );
  assert.notEqual(result.community.location.latitude, communityB.location.latitude);
});

test("open attendance marker prevents duplicate check-in", async () => {
  const refs = new Map();
  const db = {
    collection(name) {
      const collection = {
        doc(id = "new-attendance") {
          const key = `${name}/${id}`;
          return {
            id,
            key,
            get: async () => {
              if (name === "securityStaff") return snapshot(activeStaff);
              if (name === "communities") return snapshot(activeCommunity);
              return snapshot(refs.get(key));
            },
          };
        },
        where() {
          return collection;
        },
        limit() {
          return collection;
        },
        async get() {
          return {empty: true, docs: []};
        },
      };
      return collection;
    },
    async runTransaction(callback) {
      return callback({
        get: async (ref) => snapshot(refs.get(ref.key) || (ref.key === "securityAttendanceOpen/security-a" ? {attendanceId: "old"} : null)),
        create() {},
      });
    },
  };
  await assert.rejects(
    () => securityCheckInCore({db, auth, data: {latitude: 14.5995, longitude: 120.9842, accuracyMeters: 5}}),
    {code: "already-exists"},
  );
});
