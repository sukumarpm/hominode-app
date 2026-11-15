"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { COLLECTION, securityAccountDeletionRequestCore: request } = require("../src/security_account_deletion_requests");

const auth = { uid: "guard-a", token: { phone_number: "+639171234567", firebase: { sign_in_provider: "phone" } } };
function harness() {
  const seed = {
    "securityStaff/guard-a": { uid: "guard-a", role: "security", isActive: true, communityId: "C1", phoneNumber: auth.token.phone_number, name: "Officer A", gateId: "gate-a" },
    "communities/C1": { name: "Community One", isActive: true },
    "communities/C2": { name: "Community Two", isActive: true },
    "communityDeletionContacts/C1": { email: "private-one@example.test" },
    "communityDeletionContacts/C2": { email: "private-two@example.test" },
    "visitors/visitor-a": { checkedInBy: auth.uid, status: "completed", communityId: "C1" },
    "staffAttendance/shift-a": { securityId: auth.uid, communityId: "C1" },
    "auditLogs/audit-a": { actorUid: auth.uid, action: "gate-entry", communityId: "C1" },
    "incidents/incident-a": { reportedBy: auth.uid, communityId: "C1" },
  };
  const records = new Map(Object.entries(seed));
  const writes = [], emails = [];
  let serial = Promise.resolve();
  let failWrites = false;
  const snapshot = path => ({ exists: records.has(path), data: () => records.get(path) });
  const db = {
    collection: name => ({ doc: id => ({ path: `${name}/${id}` }) }),
    runTransaction(fn) {
      const current = serial.then(async () => {
        const pending = [];
        const result = await fn({
          get: async ref => snapshot(ref.path),
          set: (ref, data) => pending.push({ path: ref.path, data }),
          update: (ref, data) => pending.push({ path: ref.path, data: { ...records.get(ref.path), ...data } }),
        });
        if (failWrites && pending.length) throw new Error("Synthetic Firestore failure");
        for (const write of pending) { records.set(write.path, write.data); writes.push(write); }
        return result;
      });
      serial = current.catch(() => {});
      return current;
    },
  };
  const options = { db, auth, data: { action: "submit", confirmed: true }, now: () => 1000,
    sendMail: async message => { emails.push(message); } };
  return { options, records, seed, writes, emails, failWrites: () => { failWrites = true; } };
}
function assertHistoryUnchanged(h) {
  for (const [key, value] of Object.entries(h.seed)) assert.deepEqual(h.records.get(key), value, key);
  assert(h.writes.every(write => write.path.startsWith(`${COLLECTION}/`)));
  assert.equal([...h.records.keys()].filter(key => key.startsWith("accountDeletionRequests/")).length, 0);
}

test("Security request derives verified identity and community privately; creates review intake only", async () => {
  const h = harness();
  const result = await request(h.options);
  assert.equal(result.communityName, "Community One");
  assert.equal(result.request.status, "pending_review");
  assert.equal(result.request.submitted, true);
  assert.match(result.request.reference, /^SDR-[A-F0-9]{24}$/);
  assert.equal(h.emails.length, 1);
  assert.equal(h.emails[0].to, "private-one@example.test");
  assert.match(h.emails[0].text, /MANUAL REVIEW ONLY/);
  assert.match(h.emails[0].text, /Preserve security\/audit history, gate logs and incident records/);
  assert.doesNotMatch(JSON.stringify(result), /private-one|private-two|guard-a|\+639/);
  const saved = h.writes.at(-1).data;
  assert.equal(saved.uid, auth.uid);
  assert.equal(saved.communityId, "C1");
  assert.equal(saved.sourceApp, "security");
  assert.equal(saved.manualReviewOnly, true);
  assert.equal(saved.retry, undefined);
  assertHistoryUnchanged(h);
});

test("status and repeated submission reuse one request and send no duplicate notification", async () => {
  const h = harness();
  assert.equal((await request({ ...h.options, data: { action: "status" } })).request, null);
  assert.equal(h.writes.length, 0);
  const first = await request(h.options);
  const replay = await request(h.options);
  const status = await request({ ...h.options, data: { action: "status" } });
  assert.deepEqual(replay.request, first.request);
  assert.deepEqual(status.request, first.request);
  assert.equal(replay.idempotent, true);
  assert.equal(h.emails.length, 1);
  assertHistoryUnchanged(h);
});

test("unauthenticated and non-phone sessions cannot read status or submit", async () => {
  for (const invalid of [null, { uid: auth.uid, token: {} }, { ...auth, token: { ...auth.token, firebase: { sign_in_provider: "password" } } }]) {
    const h = harness();
    for (const data of [{ action: "status" }, h.options.data]) {
      await assert.rejects(request({ ...h.options, auth: invalid, data }), { code: "unauthenticated" });
    }
    assert.equal(h.writes.length, 0);
    assert.equal(h.emails.length, 0);
  }
});

test("Resident/Admin accounts, disabled Security, mismatched UID/phone and inactive community are rejected", async () => {
  for (const mutation of ["resident", "admin", "missing", "disabled", "wrong-uid", "wrong-phone", "inactive-community"]) {
    const h = harness();
    const staff = { ...h.records.get("securityStaff/guard-a") };
    if (["resident", "admin", "missing"].includes(mutation)) {
      h.records.delete("securityStaff/guard-a");
      h.records.set(`${mutation === "resident" ? "users" : "admins"}/guard-a`, { ...staff, role: mutation });
    } else if (mutation === "disabled") h.records.set("securityStaff/guard-a", { ...staff, isActive: false });
    else if (mutation === "wrong-uid") h.records.set("securityStaff/guard-a", { ...staff, uid: "other-guard" });
    else if (mutation === "wrong-phone") h.records.set("securityStaff/guard-a", { ...staff, phoneNumber: "+639171234568" });
    else h.records.set("communities/C1", { isActive: false });
    await assert.rejects(request(h.options), { code: "permission-denied" });
    assert.equal(h.writes.length, 0);
    assert.equal(h.emails.length, 0);
  }
});

test("client target IDs, cross-community requests, recipient overrides and missing consent are rejected", async () => {
  for (const data of [null, {}, [], { action: "submit", confirmed: false },
    ...[{ uid: "other-guard" }, { communityId: "C2" }, { to: "attacker@example.test" }, { sourceApp: "resident" }].map(extra => ({ action: "submit", confirmed: true, ...extra }))]) {
    const h = harness();
    await assert.rejects(request({ ...h.options, data }), { code: "invalid-argument" });
    assert.equal(h.writes.length, 0);
    assert.equal(h.emails.length, 0);
  }
  const h = harness();
  await request({ ...h.options, auth: { ...auth, token: { ...auth.token, communityId: "C2" } } });
  assert.equal(h.emails[0].to, "private-one@example.test");
});

test("missing or malformed own community route never falls through to another community", async () => {
  for (const contact of [undefined, { email: "" }, { email: "invalid" }, { email: "one@example.test\r\nBcc:other@example.test" }]) {
    const h = harness();
    if (contact) h.records.set("communityDeletionContacts/C1", contact);
    else h.records.delete("communityDeletionContacts/C1");
    await assert.rejects(request(h.options), { code: "failed-precondition" });
    assert.equal(h.writes.length, 0);
    assert.equal(h.emails.length, 0);
  }
});

test("email failure does not confirm submission; retry uses the same reference", async () => {
  const h = harness();
  await assert.rejects(request({ ...h.options, sendMail: async () => { throw new Error("Synthetic SMTP error"); } }), { code: "unavailable" });
  const status = await request({ ...h.options, data: { action: "status" } });
  assert.equal(status.request.submitted, false);
  const result = await request(h.options);
  assert.equal(result.request.reference, status.request.reference);
  assert.equal(result.request.submitted, true);
  assert.equal([...h.records.keys()].filter(key => key.startsWith(`${COLLECTION}/`)).length, 1);
  assertHistoryUnchanged(h);
});

test("concurrent submissions cannot reserve a second record or send duplicate email", async () => {
  const h = harness();
  let release, started;
  const waiting = new Promise(resolve => { release = resolve; });
  const entered = new Promise(resolve => { started = resolve; });
  const first = request({ ...h.options, sendMail: async message => { h.emails.push(message); started(); await waiting; } });
  await entered;
  await assert.rejects(request(h.options), { code: "aborted" });
  assert.equal((await request({ ...h.options, data: { action: "status" } })).request.submitted, false);
  release();
  await first;
  assert.equal(h.emails.length, 1);
});

test("persistence failures never send an email or return false submission success", async () => {
  const h = harness(); h.failWrites();
  await assert.rejects(request(h.options));
  assert.equal(h.emails.length, 0);
  const afterMail = harness();
  await assert.rejects(request({ ...afterMail.options, sendMail: async () => afterMail.failWrites() }));
  const status = await request({ ...afterMail.options, data: { action: "status" } });
  assert.equal(status.request.submitted, false);
});

test("a changed community after submission cannot read or reroute the original request", async () => {
  const h = harness(); await request(h.options);
  h.records.set("securityStaff/guard-a", { ...h.records.get("securityStaff/guard-a"), communityId: "C2" });
  for (const data of [{ action: "status" }, h.options.data]) {
    await assert.rejects(request({ ...h.options, data }), { code: "failed-precondition" });
  }
  assert.equal(h.emails.length, 1);
});

test("callable enforces App Check and uses existing SMTP secret without changing public CAPTCHA entry point", () => {
  const index = fs.readFileSync(require.resolve("../src/index"), "utf8");
  assert.match(index, /exports\.securityAccountDeletionRequest = onCall\(\s*\{ region: REGION, enforceAppCheck: true, secrets: \[DELETION_SMTP_PASSWORD\]/);
  assert.match(index, /result\.accepted\?\.some\(address => String\(address\)\.toLowerCase\(\) === message\.to\)/);
  assert.match(index, /exports\.submitPublicAccountDeletionRequest = deletionOnRequest/);
});
