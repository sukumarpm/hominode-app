"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { securitySupportRequestCore: request, COLLECTION } = require("../src/security_support_requests");
const auth = { uid: "guard-a", token: { phone_number: "+639171234567", firebase: { sign_in_provider: "phone" } } };
function harness() {
  const seed = {
    "securityStaff/guard-a": { uid: "guard-a", role: "security", isActive: true, phoneNumber: auth.token.phone_number, communityId: "C1", name: "Officer One", gateId: "gate-a" },
    "communities/C1": { name: "Community One", isActive: true },
    "communities/C2": { name: "Community Two", isActive: true },
    "admins/admin-a": { uid: "admin-a", role: "admin", isActive: true, authorizedCommunityIds: ["C1"] },
    "admins/admin-b": { uid: "admin-b", role: "admin", isActive: true, authorizedCommunityIds: ["C2"] },
    "admins/disabled": { uid: "disabled", role: "admin", isActive: false, authorizedCommunityIds: ["C1"] },
    "admins/wrong-role": { uid: "wrong-role", role: "resident", isActive: true, authorizedCommunityIds: ["C1"] },
    "securityAccountDeletionRequests/p0": { uid: auth.uid, reference: "existing-deletion", status: "pending_review" },
    "auditLogs/audit-a": { actorUid: auth.uid }, "visitors/visit-a": { checkedInBy: auth.uid },
  };
  const records = new Map(Object.entries(seed)), writes = [], emails = [];
  let serial = Promise.resolve(), clock = 100000, failWrites = false;
  const snapshot = path => ({ id: path.split("/").at(-1), exists: records.has(path), data: () => records.get(path) });
  const db = {
    collection: name => ({
      doc: key => ({ id: key, path: `${name}/${key}` }),
      where: (field, op, value) => ({ limit() { return { query: { name, field, value, op } }; } }),
    }),
    runTransaction(fn) {
      const result = serial.then(async () => {
        const pending = [];
        const value = await fn({
          get: async target => target.query ? { docs: [...records.keys()].filter(path => path.startsWith(`${target.query.name}/`) && records.get(path)[target.query.field]?.includes(target.query.value)).map(snapshot) } : snapshot(target.path),
          set: (ref, data) => pending.push({ path: ref.path, data }),
          update: (ref, data) => pending.push({ path: ref.path, data: { ...records.get(ref.path), ...data } }),
        });
        if (failWrites && pending.length) throw new Error("Synthetic persistence failure");
        for (const write of pending) { writes.push(write); records.set(write.path, write.data); }
        return value;
      });
      serial = result.catch(() => {});
      return result;
    },
  };
  return { records, seed, writes, emails, advance: ms => { clock += ms; }, failWrites: () => { failWrites = true; },
    options: { db, auth, data: { action: "submit", topic: "technical_issue", message: "The gate scanner screen is not responding.", requestKey: "a".repeat(32) },
      now: () => clock, sendMail: async mail => { emails.push(mail); } } };
}
function unchanged(h) {
  for (const [key, value] of Object.entries(h.seed)) assert.deepEqual(h.records.get(key), value, key);
  assert(h.writes.every(write => [COLLECTION, "securitySupportRequestLimits", "notifications"].includes(write.path.split("/")[0])));
}

test("context is read-only, verifies the officer and exposes no private account routing", async () => {
  const h = harness();
  assert.deepEqual(await request({ ...h.options, data: { action: "context" } }), { communityName: "Community One" });
  assert.equal(h.writes.length, 0); assert.equal(h.emails.length, 0);
});

for (const topic of ["technical_issue", "other"]) {
  test(`${topic} reuses platform support mailbox with server-derived identity`, async () => {
    const h = harness();
    const response = await request({ ...h.options, data: { ...h.options.data, topic } });
    assert.equal(response.status, "received");
    assert.equal(response.destination, "hominode_support");
    assert.match(response.reference, /^HSP-[A-F0-9]{24}$/);
    assert.equal(h.emails.length, 1);
    assert.equal(h.emails[0].to, "hominodecare@gmail.com");
    assert.match(h.emails[0].text, /Officer One/);
    assert.match(h.emails[0].text, /Community One \(C1\)/);
    assert.match(h.emails[0].text, /\+639171234567/);
    assert.match(h.emails[0].text, /not an account-deletion request/);
    assert.doesNotMatch(JSON.stringify(response), /@|phone_number|guard-a/);
    unchanged(h);
  });
}

for (const topic of ["phone_number", "gate_shift", "account_access"]) {
  test(`${topic} reaches only active authorized Community Admin notifications`, async () => {
    const h = harness();
    const response = await request({ ...h.options, data: { ...h.options.data, topic } });
    assert.equal(response.destination, "community_admin");
    assert.equal(h.emails.length, 0);
    const notices = h.writes.filter(write => write.path.startsWith("notifications/"));
    assert.equal(notices.length, 1);
    assert.equal(notices[0].data.recipientId, "admin-a");
    assert.equal(notices[0].data.communityId, "C1");
    assert.equal(notices[0].data.appId, "admin");
    assert.equal(notices[0].data.role, "admin");
    assert.match(notices[0].data.message, /Officer One/);
    assert.match(notices[0].data.message, /gate scanner screen/);
    assert.match(notices[0].data.message, new RegExp(response.reference));
    unchanged(h);
  });
}

test("replays return the same reference without duplicate mail or notification", async () => {
  for (const topic of ["technical_issue", "account_access"]) {
    const h = harness(), options = { ...h.options, data: { ...h.options.data, topic } };
    const first = await request(options);
    const writes = h.writes.length;
    assert.deepEqual(await request(options), first);
    assert.equal(h.writes.length, writes);
    assert.equal(h.emails.length, topic === "technical_issue" ? 1 : 0);
  }
});

test("SMTP errors never confirm success and retry preserves the request reference", async () => {
  const h = harness();
  await assert.rejects(request({ ...h.options, sendMail: async () => { throw new Error("SMTP offline"); } }), { code: "unavailable" });
  const saved = h.writes.find(write => write.path.startsWith(`${COLLECTION}/`)).data;
  const result = await request(h.options);
  assert.equal(result.reference, saved.reference);
  assert.equal(result.status, "received"); unchanged(h);
});

test("concurrent requests cannot send a second email", async () => {
  const h = harness(); let release, started;
  const blocked = new Promise(resolve => { release = resolve; });
  const entered = new Promise(resolve => { started = resolve; });
  const first = request({ ...h.options, sendMail: async mail => { h.emails.push(mail); started(); await blocked; } });
  await entered;
  await assert.rejects(request(h.options), { code: "aborted" });
  release(); await first; assert.equal(h.emails.length, 1);
});

test("unauthenticated, Resident/Admin roles, mismatched phone and inactive community are rejected", async () => {
  const missing = harness(); await assert.rejects(request({ ...missing.options, auth: null }), { code: "unauthenticated" });
  for (const change of [{ role: "resident" }, { role: "admin" }, { uid: "other" }, { phoneNumber: "+639999999999" }, { isActive: false }, { communityId: "C2/other" }]) {
    const h = harness(); h.records.set("securityStaff/guard-a", { ...h.seed["securityStaff/guard-a"], ...change });
    await assert.rejects(request(h.options), { code: "permission-denied" });
    assert.equal(h.writes.length, 0);
  }
  const h = harness(); h.records.set("communities/C1", { isActive: false });
  await assert.rejects(request(h.options), { code: "permission-denied" });
});

test("client identity, cross-community and recipient overrides and invalid messages are rejected", async () => {
  for (const change of [{ uid: "victim" }, { communityId: "C2" }, { to: "attacker@example.test" }, { message: "short" }, { message: "x".repeat(2001) }, { topic: "unknown" }, { requestKey: "../path" }]) {
    const h = harness();
    await assert.rejects(request({ ...h.options, data: { ...h.options.data, ...change } }), { code: "invalid-argument" });
    assert.equal(h.writes.length, 0); assert.equal(h.emails.length, 0);
  }
});

test("missing own-community administrator fails without contacting another community", async () => {
  const h = harness(); h.records.delete("admins/admin-a");
  await assert.rejects(request({ ...h.options, data: { ...h.options.data, topic: "gate_shift" } }), { code: "failed-precondition" });
  assert.equal(h.writes.length, 0); assert.equal(h.emails.length, 0);
});

test("one request key cannot be used to change content or follow an account to another community", async () => {
  const h = harness(); await request(h.options);
  await assert.rejects(request({ ...h.options, data: { ...h.options.data, message: "Changed request content completely" } }), { code: "failed-precondition" });
  h.records.set("securityStaff/guard-a", { ...h.seed["securityStaff/guard-a"], communityId: "C2" });
  await assert.rejects(request(h.options), { code: "failed-precondition" });
});

test("account rate limits apply to fresh requests, without blocking replay of confirmed requests", async () => {
  const h = harness(); const first = await request(h.options);
  await assert.rejects(request({ ...h.options, data: { ...h.options.data, requestKey: "b".repeat(32) } }), { code: "resource-exhausted" });
  assert.deepEqual(await request(h.options), first);
  for (let i = 1; i < 10; i++) {
    h.advance(60001);
    await request({ ...h.options, data: { ...h.options.data, requestKey: i.toString(16).padStart(32, "0") } });
  }
  h.advance(60001);
  await assert.rejects(request({ ...h.options, data: { ...h.options.data, requestKey: "c".repeat(32) } }), { code: "resource-exhausted" });
});

test("failed atomic persistence cannot confirm an Admin request or send platform email", async () => {
  for (const topic of ["gate_shift", "technical_issue"]) {
    const h = harness(); h.failWrites();
    await assert.rejects(request({ ...h.options, data: { ...h.options.data, topic } }));
    assert.equal(h.writes.length, 0); assert.equal(h.emails.length, 0);
  }
});

test("support callable enforces App Check and leaves public CAPTCHA and P0 wiring in place", () => {
  const source = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.match(source, /exports\.securitySupportRequest = onCall\(\s*\{ region: REGION, enforceAppCheck: true, secrets: \[DELETION_SMTP_PASSWORD\]/);
  assert.match(source, /exports\.securityAccountDeletionRequest = onCall/);
  assert.match(source, /exports\.submitPublicContactInquiry = inquiryOnRequest/);
});
