const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createSecurityStaffCore,
  assignSecurityWorkCore,
  removeSecurityAssignmentCore,
} = require("../src/security_management");

const auth = {
  uid: "admin-a",
  token: {
    phone_number: "+15550000001",
    firebase: {sign_in_provider: "phone"},
  },
};

function fakeDb(seed) {
  const values = new Map(Object.entries(seed));
  let autoId = 0;
  const snapshot = (path) => ({
    id: path.split("/").pop(),
    exists: values.has(path),
    data: () => values.get(path),
  });
  const ref = (path) => ({
    id: path.split("/").pop(),
    path,
    get: async () => snapshot(path),
    create: async (data) => {
      if (values.has(path)) throw new Error("already exists");
      values.set(path, data);
    },
    update: async (changes) => {
      values.set(path, {...values.get(path), ...changes});
    },
  });
  return {
    values,
    collection(name) {
      return {
        doc(id) {
          return ref(`${name}/${id ?? `auto-${++autoId}`}`);
        },
      };
    },
    async runTransaction(callback) {
      const writes = [];
      const result = await callback({
        get: async (target) => snapshot(target.path),
        update: (target, changes) => writes.push({target, changes}),
      });
      for (const {target, changes} of writes) {
        values.set(target.path, {...values.get(target.path), ...changes});
      }
      return result;
    },
  };
}

const seed = {
  "admins/admin-a": {
    uid: "admin-a",
    role: "admin",
    isActive: true,
    authorizedCommunityIds: ["COMMUNITY_A"],
  },
  "communities/COMMUNITY_A": {isActive: true},
  "gates/gate-a": {
    communityId: "COMMUNITY_A",
    gateName: "Main Gate",
    workingStatus: "Active",
  },
};

test("security create, assignment, and removal append tenant-safe audit records", async () => {
  const db = fakeDb(seed);
  const authAdmin = {
    getUserByPhoneNumber: async () => ({uid: "security-a"}),
  };

  await createSecurityStaffCore({
    db,
    auth,
    authAdmin,
    data: {
      communityId: "COMMUNITY_A",
      phoneNumber: "+15550000002",
      name: "Security One",
    },
  });
  await assignSecurityWorkCore({
    db,
    auth,
    data: {
      communityId: "COMMUNITY_A",
      staffUid: "security-a",
      gateId: "gate-a",
      shiftTiming: "08:00-16:00",
      workStatus: "On Duty",
      specialInstructions: "Do not place this text in audit logs.",
    },
  });
  await removeSecurityAssignmentCore({
    db,
    auth,
    data: {communityId: "COMMUNITY_A", staffUid: "security-a"},
  });

  const auditLogs = [...db.values.entries()]
    .filter(([path]) => path.startsWith("auditLogs/"))
    .map(([, value]) => value);
  assert.deepEqual(
    auditLogs.map((log) => log.action),
    [
      "security_staff.create",
      "security_staff.assign",
      "security_staff.assignment_remove",
    ],
  );
  for (const log of auditLogs) {
    assert.equal(log.actorUid, "admin-a");
    assert.equal(log.actorRole, "admin");
    assert.equal(log.communityId, "COMMUNITY_A");
    assert.equal(log.targetId, "security-a");
    assert.equal(log.targetType, "security_staff");
    const serialized = JSON.stringify(log);
    assert.doesNotMatch(serialized, /15550000002|Security One|Do not place/);
  }
});
