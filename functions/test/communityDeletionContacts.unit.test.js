"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { normalizeDeletionEmail, validateCommunityId, findActiveRecipient, listActiveCommunities } = require("../src/community_deletion_contacts");

function database(active = true, configured = true) {
  const communityData = { name: "Green Wave", isActive: active };
  return { collection(name) {
    if (name === "communities") return {
      doc(id) { return { async get() { return { exists: id === "GREEN-WAVE", data: () => communityData }; } }; },
      where() { return { async get() { return { docs: [{ id: "GREEN-WAVE" }] }; } }; },
    };
    if (name === "communityDeletionContacts") return { doc(id) { return { async get() {
      return { exists: configured && id === "GREEN-WAVE", data: () => ({ email: "admin@greenwave.example" }) };
    } }; } };
    throw new Error("Unexpected collection");
  } };
}
function response() {
  return { code: 200, headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(v) { this.code = v; return this; },
    json(v) { this.body = v; return this; },
  };
}
test("email is mandatory, normalized and validated", () => {
  assert.equal(normalizeDeletionEmail("  ADMIN@GREENWAVE.EXAMPLE  "), "admin@greenwave.example");
  for (const x of ["", "nobody", "a@b", "one@example.org\r\nBcc:other@example.org", null]) {
    assert.throws(() => normalizeDeletionEmail(x));
  }
});
test("community ID cannot address an arbitrary Firestore path", () => {
  assert.equal(validateCommunityId("GREEN-WAVE"), true);
  assert.equal(validateCommunityId("../admins"), false);
});
test("recipient is private and requires active configured community", async () => {
  assert.deepEqual(await findActiveRecipient(database(), "GREEN-WAVE"), {
    communityId: "GREEN-WAVE", name: "Green Wave", email: "admin@greenwave.example",
  });
  assert.equal(await findActiveRecipient(database(false), "GREEN-WAVE"), null);
  assert.equal(await findActiveRecipient(database(true, false), "GREEN-WAVE"), null);
});
test("public directory returns IDs and names, never recipient email", async () => {
  const res = response();
  await listActiveCommunities({ method: "GET", headers: { origin: "https://hominode.com" } }, res, {
    db: database(), allowedOrigins: new Set(["https://hominode.com"]),
  });
  assert.equal(res.code, 200);
  assert.deepEqual(res.body, { communities: [{ id: "GREEN-WAVE", name: "Green Wave" }] });
  assert.doesNotMatch(JSON.stringify(res.body), /admin@/);
});
test("public directory blocks foreign origins", async () => {
  const res = response();
  await listActiveCommunities({ method: "GET", headers: { origin: "https://evil.example" } }, res, {
    db: database(), allowedOrigins: new Set(["https://hominode.com"]),
  });
  assert.equal(res.code, 403);
});
