const test = require("node:test");
const assert = require("node:assert/strict");
const {
  getResidentNoticeIdsCore,
  noticeVisibleToResident,
} = require("../src/resident_notices");

const RESIDENT_APP_ID = "1:551984029668:android:ef652ea4d8e070ca0db1f1";

const RESIDENT_WEB = "1:551984029668:web:1a46284d081d68170db1f1";

function snapshot(id, data) {
  return {id, exists: data != null, data: () => data};
}

function fakeDb({profile, community, notices}) {
  return {
    collection(name) {
      if (name === "users") {
        return {doc: (id) => ({get: async () => snapshot(id, profile)})};
      }
      if (name === "communities") {
        return {doc: (id) => ({get: async () => snapshot(id, community)})};
      }
      if (name === "notices") {
        return {
          where(field, operator, value) {
            assert.equal(field, "communityId");
            assert.equal(operator, "==");
            return {
              get: async () => ({
                docs: notices
                  .filter((entry) => entry.data.communityId === value)
                  .map((entry) => snapshot(entry.id, entry.data)),
              }),
            };
          },
        };
      }
      throw new Error(`Unexpected collection: ${name}`);
    },
  };
}

test("notice visibility preserves global, flat, published, and expiry semantics", () => {
  const now = Date.UTC(2026, 7, 28);
  assert.equal(noticeVisibleToResident({status: "published"}, "flat-a", now), true);
  assert.equal(noticeVisibleToResident({isActive: true, targetFlats: []}, "flat-a", now), true);
  assert.equal(noticeVisibleToResident({status: "published", targetFlats: ["flat-a"]}, "flat-a", now), true);
  assert.equal(noticeVisibleToResident({status: "published", targetFlats: ["flat-b"]}, "flat-a", now), false);
  assert.equal(noticeVisibleToResident({status: "draft", targetFlats: []}, "flat-a", now), false);
  assert.equal(noticeVisibleToResident({status: "published", expiresAt: new Date(now - 1)}, "flat-a", now), false);
});

for (const appId of [RESIDENT_APP_ID, RESIDENT_WEB]) {
  test(`trusted resolver derives canonical tenant/flat and returns only authorized IDs: ${appId}`, async () => {
    const profile = {
      uid: "resident-a",
      role: "resident",
      residentType: "owner",
      approvalStatus: "approved",
      isActive: true,
      communityId: "community-a",
      flatId: "flat-a",
    };
    const db = fakeDb({
      profile,
      community: {isActive: true, ownerIdentityVerificationRequired: false},
      notices: [
        {id: "global", data: {communityId: "community-a", status: "published"}},
        {id: "flat-a", data: {communityId: "community-a", status: "published", targetFlats: ["flat-a"]}},
        {id: "flat-b", data: {communityId: "community-a", status: "published", targetFlats: ["flat-b"]}},
        {id: "draft", data: {communityId: "community-a", status: "draft", targetFlats: []}},
        {id: "other-community", data: {communityId: "community-b", status: "published", targetFlats: []}},
      ],
    });

    const result = await getResidentNoticeIdsCore({
      db,
      auth: {uid: "resident-a"},
      app: {appId},
    });
    assert.equal(result.communityId, "community-a");
    assert.equal(result.flatId, "flat-a");
    assert.deepEqual(result.noticeIds, ["global", "flat-a"]);
  });
}

test("trusted resolver rejects forged app context and ineligible resident state", async () => {
  const db = fakeDb({
    profile: {
      uid: "resident-a",
      role: "resident",
      residentType: "tenant",
      identityVerified: false,
      identityVerificationStatus: "pending",
      approvalStatus: "approved",
      isActive: true,
      communityId: "community-a",
      flatId: "flat-a",
    },
    community: {isActive: true},
    notices: [],
  });
  await assert.rejects(
    getResidentNoticeIdsCore({
      db,
      auth: {uid: "resident-a"},
      app: {appId: "forged-app"},
    }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    getResidentNoticeIdsCore({
      db,
      auth: {uid: "resident-a"},
      app: {appId: RESIDENT_APP_ID},
    }),
    (error) => error.code === "permission-denied",
  );
});


test("notice resolution rejects Admin web and unknown or forged Resident web identities before reading data", async () => {
  for (const appId of [
    "1:551984029668:web:5845083359a375d90db1f1",
    "1:551984029668:web:unknown", `${RESIDENT_WEB}-forged`,
  ]) {
    await assert.rejects(getResidentNoticeIdsCore({
      db: {}, auth: {uid: "resident-a"}, app: {appId},
    }), {code: "failed-precondition"});
  }
});

test("Resident web notice resolution preserves canonical role and lifecycle restrictions", async () => {
  const profile = {
    uid: "resident-a", role: "resident", residentType: "owner",
    approvalStatus: "approved", isActive: true, communityId: "community-a", flatId: "flat-a",
  };
  for (const overrides of [
    {uid: "other"}, {role: "admin"}, {isActive: false}, {approvalStatus: "pending"},
    {residentType: "tenant", identityVerified: false},
  ]) {
    await assert.rejects(getResidentNoticeIdsCore({
      db: fakeDb({profile: {...profile, ...overrides}, community: {isActive: true}, notices: []}),
      auth: {uid: "resident-a"}, app: {appId: RESIDENT_WEB},
    }), {code: "permission-denied"});
  }
});
