const test = require("node:test");
const assert = require("node:assert/strict");
const {createResidentAdminChatCore} = require("../src/resident_admin_chat");

const RESIDENT_APP = {appId: "1:551984029668:ios:cb57ef578d5066b50db1f1"};
const auth = (uid = "resident-a") => ({
  uid,
  token: {phone_number: "+639111111111", firebase: {sign_in_provider: "phone"}},
});
const approvedResident = {
  uid: "resident-a", role: "resident", isActive: true,
  approvalStatus: "approved", residentType: "owner", ownershipType: "owner",
  communityId: "COMMUNITY_A", buildingId: "building-a", flatId: "flat-a",
  name: "Test Resident",
};
const activeAdmin = {
  uid: "admin-a", role: "admin", isActive: true, name: "Test Admin",
  authorizedCommunityIds: ["COMMUNITY_A"],
};

function fakeDb(seed) {
  const values = new Map(Object.entries(seed));
  const doc = (path) => ({
    id: path.split("/").pop(),
    get: async () => snapshot(path),
    collection: (name) => collection(path + "/" + name),
    path,
  });
  const snapshot = (path) => ({
    id: path.split("/").pop(),
    exists: values.has(path),
    data: () => values.get(path),
  });
  const collection = (path) => ({
    doc: (id) => doc(path + "/" + id),
    where: (field, op, value) => ({
      get: async () => ({
        docs: [...values.entries()]
          .filter(([key, data]) => key.startsWith(path + "/") &&
            key.slice(path.length + 1).indexOf("/") === -1 &&
            (op === "==" ? data?.[field] === value :
              op === "array-contains" && Array.isArray(data?.[field]) && data[field].includes(value)))
          .map(([key]) => snapshot(key)),
      }),
    }),
  });
  return {
    values, collection,
    runTransaction: async (callback) => callback({
      get: (ref) => ref.get(),
      create: (ref, data) => {
        assert.equal(values.has(ref.path), false, "create must not overwrite");
        values.set(ref.path, data);
      },
      update: (ref, changes) => {
        assert.equal(values.has(ref.path), true, "update requires existing doc");
        values.set(ref.path, {...values.get(ref.path), ...changes});
      },
    }),
  };
}

const seed = () => ({
  "users/resident-a": {...approvedResident},
  "communities/COMMUNITY_A": {isActive: true},
  "buildings/building-a": {communityId: "COMMUNITY_A", name: "Demo Tower"},
  "flats/flat-a": {communityId: "COMMUNITY_A", buildingId: "building-a", label: "A-101"},
  "admins/admin-a": {...activeAdmin},
});
const send = (db, overrides = {}) => createResidentAdminChatCore({
  db, auth: auth(), app: RESIDENT_APP,
  data: {action: "send", category: "billing", message: "When is my next bill due?",
    requestId: "request_123456789012345", isQuery: true, ...overrides},
});

test("Resident quick query creates canonical chat readable by Admin, with initial message", async () => {
  const db = fakeDb(seed());
  const result = await send(db);
  const chat = db.values.get("chats/" + result.chatId);
  assert.equal(chat.communityId, "COMMUNITY_A");
  assert.equal(chat.adminId, "admin-a");
  assert.equal(chat.residentId, "resident-a");
  assert.deepEqual(chat.participants, ["admin-a", "resident-a"]);
  assert.equal(chat.lastMessage, "When is my next bill due?");
  const messages = [...db.values.entries()].filter(([path]) => path.startsWith("chats/" + result.chatId + "/messages/"));
  assert.equal(messages.length, 1);
  assert.equal(messages[0][1].message, "When is my next bill due?");
  assert.equal(messages[0][1].text, messages[0][1].message);
  assert.equal(messages[0][1].isQuery, true);
});

test("same request ID is idempotent; lookup never creates a message", async () => {
  const db = fakeDb(seed());
  const first = await send(db);
  const again = await send(db);
  assert.equal(again.chatId, first.chatId);
  assert.equal(again.duplicate, true);
  const found = await createResidentAdminChatCore({
    db, auth: auth(), app: RESIDENT_APP, data: {action: "lookup"},
  });
  assert.equal(found.chatId, first.chatId);
  assert.equal([...db.values.keys()].filter(x => x.includes("/messages/")).length, 1);
});

test("follow-up messages reuse conversation and are not marked as quick queries", async () => {
  const db = fakeDb(seed());
  const first = await send(db);
  const next = await send(db, {
    message: "Please send the receipt.",
    requestId: "request_222222222222222", isQuery: false,
  });
  assert.equal(next.chatId, first.chatId);
  assert.equal([...db.values.keys()].filter(x => x.includes("/messages/")).length, 2);
  assert.equal(db.values.get("chats/" + first.chatId).lastMessage, "Please send the receipt.");
});

test("wrong app, unauthenticated user and non-approved residents are rejected", async () => {
  const db = fakeDb(seed());
  await assert.rejects(createResidentAdminChatCore({
    db, auth: auth(), app: {appId: "unknown"}, data: {action: "lookup"},
  }), {code: "failed-precondition"});
  await assert.rejects(createResidentAdminChatCore({
    db, auth: {uid: "resident-a"}, app: RESIDENT_APP, data: {action: "lookup"},
  }), {code: "unauthenticated"});
  db.values.set("users/resident-a", {...approvedResident, approvalStatus: "pending"});
  await assert.rejects(send(db), {code: "permission-denied"});
});

test("never creates a placeholder Admin or targets a different community", async () => {
  const db = fakeDb(seed());
  db.values.set("admins/admin-a", {...activeAdmin, authorizedCommunityIds: ["COMMUNITY_B"]});
  await assert.rejects(send(db), {code: "failed-precondition"});
  assert.equal([...db.values.keys()].filter(x => x.startsWith("chats/")).length, 0);
});

test("malformed quick queries are rejected", async () => {
  const db = fakeDb(seed());
  for (const changes of [
    {message: ""}, {requestId: "short"}, {category: "malicious"},
    {isQuery: "yes"}, {message: "x".repeat(2001)},
  ]) {
    await assert.rejects(send(db, changes), {code: "invalid-argument"});
  }
});
