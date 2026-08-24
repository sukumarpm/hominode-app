const test = require("node:test");
const assert = require("node:assert/strict");
const {
  generateInviteCode,
  listCommunityInvitesCore,
  createCommunityInviteCore,
  revokeCommunityInviteCore,
} = require("../src/community_invites");

const auth = {uid: "admin-1", token: {phone_number: "+15550000001", firebase: {sign_in_provider: "phone"}}};

function fakeDb(seed = {}) {
  const values = new Map(Object.entries(seed));
  const snapshot = (path) => ({
    id: path.split("/").pop(),
    exists: values.has(path),
    data: () => values.get(path),
  });
  const doc = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
    get: async () => snapshot(`${collection}/${id}`),
    create: async (data) => {
      const path = `${collection}/${id}`;
      if (values.has(path)) throw Object.assign(new Error("collision"), {code: 6});
      values.set(path, data);
    },
  });
  return {
    values,
    collection: (name) => ({
      doc: (id) => doc(name, id),
      where: (field, operator, expected) => {
        assert.equal(field, "communityId");
        assert.equal(operator, "==");
        return {get: async () => ({
          docs: [...values.entries()]
            .filter(([path, data]) => path.startsWith(`${name}/`) && data[field] === expected)
            .map(([path]) => snapshot(path)),
        })};
      },
    }),
    runTransaction: async (callback) => callback({
      get: async (ref) => snapshot(ref.path),
      update: (ref, changes) => values.set(ref.path, {...values.get(ref.path), ...changes}),
    }),
  };
}

function authorizedSeed() {
  return {
    "admins/admin-1": {
      uid: "admin-1",
      role: "admin",
      isActive: true,
      authorizedCommunityIds: ["GV-0701"],
    },
    "communities/GV-0701": {isActive: true},
  };
}

test("secure generated invite codes match the resident normalization alphabet", () => {
  const code = generateInviteCode();
  assert.match(code, /^[A-Z2-9]{24}$/);
});

test("list is tenant-authorized and sorted newest first", async () => {
  const db = fakeDb({
    ...authorizedSeed(),
    "communityInvites/OLD": {code: "OLD", communityId: "GV-0701", createdAt: {toMillis: () => 10}},
    "communityInvites/NEW": {code: "NEW", communityId: "GV-0701", createdAt: {toMillis: () => 20}},
    "communityInvites/OTHER": {code: "OTHER", communityId: "OTHER", createdAt: {toMillis: () => 30}},
  });
  const result = await listCommunityInvitesCore({db, auth, data: {communityId: "GV-0701"}});
  assert.deepEqual(result.invites.map((invite) => invite.code), ["NEW", "OLD"]);
  await assert.rejects(
    listCommunityInvitesCore({db, auth, data: {communityId: "OTHER"}}),
    {code: "permission-denied"},
  );
});

test("inactive communities fail closed for invite operations", async () => {
  const db = fakeDb({
    ...authorizedSeed(),
    "communities/GV-0701": {isActive: false},
  });
  await assert.rejects(
    listCommunityInvitesCore({db, auth, data: {communityId: "GV-0701"}}),
    {code: "failed-precondition"},
  );
});

test("create retries a collision and writes server-owned fields", async () => {
  const collidingCode = "AAAAAAAAAAAAAAAAAAAAAAAA";
  const nextCode = "BBBBBBBBBBBBBBBBBBBBBBBB";
  const db = fakeDb({...authorizedSeed(), [`communityInvites/${collidingCode}`]: {communityId: "GV-0701"}});
  const codes = [collidingCode, nextCode];
  const result = await createCommunityInviteCore({
    db,
    auth,
    data: {communityId: "GV-0701", maxUses: 4},
    codeGenerator: () => codes.shift(),
  });
  assert.equal(result.code, nextCode);
  const created = db.values.get(`communityInvites/${nextCode}`);
  assert.equal(created.createdBy, "admin-1");
  assert.equal(created.isActive, true);
  assert.equal(created.useCount, 0);
  assert.equal(created.usedCount, 0);
});

test("revoke preserves the invite and rejects a cross-community request", async () => {
  const db = fakeDb({
    ...authorizedSeed(),
    "communityInvites/KNOWN_CODE": {code: "KNOWN_CODE", communityId: "GV-0701", isActive: true},
  });
  await revokeCommunityInviteCore({db, auth, data: {communityId: "GV-0701", inviteCode: "KNOWN_CODE"}});
  const invite = db.values.get("communityInvites/KNOWN_CODE");
  assert.equal(invite.isActive, false);
  assert.equal(invite.revokedBy, "admin-1");
  assert.equal(db.values.has("communityInvites/KNOWN_CODE"), true);

  await assert.rejects(
    revokeCommunityInviteCore({db, auth, data: {communityId: "OTHER", inviteCode: "KNOWN_CODE"}}),
    {code: "permission-denied"},
  );
});
