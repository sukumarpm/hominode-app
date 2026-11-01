"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { normalizeRequest, makeReference, emailBody, handleDeletionRequest } = require("../src/public_deletion_requests");
const base = { name: "Alex Rivera", email: "alex@example.org", phone: "+639912345678", contactPhone: "+639998765432", communityId: "GREEN-WAVE", unit: "Tower A, 1204", confirmed: true, captchaToken: "test-token", website: "" };

test("normalizes valid form and requires the account-registered phone", () => {
  assert.equal(normalizeRequest(base).communityId, "GREEN-WAVE");
  assert.equal(normalizeRequest(base).phone, base.phone);
  assert.equal(normalizeRequest(base).contactPhone, base.contactPhone);
  assert.equal(normalizeRequest({ ...base, contactPhone: base.phone }).contactPhone, base.phone);
  for (const phone of ["", " ", undefined, "1234567"]) {
    assert.throws(() => normalizeRequest({ ...base, phone }));
  }
});
test("rejects unconfirmed, malformed email, markup-sized values, and honeypot", () => {
  for (const mutation of [{ confirmed: false }, { email: "wrong" }, { name: "X" }, { communityId: "A" }, { unit: "" }, { website: "spam" }, { captchaToken: "" }, { phone: "not-a-phone" }]) {
    assert.throws(() => normalizeRequest({ ...base, ...mutation }));
  }
});
test("reference is specific format, email only requests human review", () => {
  const ref = makeReference(new Date("2026-11-01T00:00:00.000Z"), () => Buffer.from("0011223344", "hex"));
  assert.equal(ref, "HD-DEL-20261101-0011223344");
  assert.match(emailBody(base, ref), /AWAITING IDENTITY VERIFICATION/);
  assert.match(emailBody(base, ref), /Registered phone .*\+639912345678/);
  assert.match(emailBody(base, ref), /Current contact phone .*\+639998765432/);
});
function mockResponse() {
  return {
    statusCode: 200, headers: {},
    set(key, value) { this.headers[key] = value; return this; },
    status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; return this; },
  };
}
function harness(body = base) {
  const records = []; const emails = [];
  const db = { collection(name) { return { doc(id) {
    if (name === "communities") return { async get() { return { exists: true, data: () => ({ name: "Green Wave", isActive: true }) }; } };
    if (name === "communityDeletionContacts") return { async get() { return { exists: true, data: () => ({ email: "greenwave@example.org" }) }; } };
    return { async create(data) { records.push({ id, ...data }); }, async update(data) { records.at(-1).update = data; } };
  } }; } };
  const req = { method: "POST", body, ip: "127.0.0.1", headers: { origin: "http://localhost:5173" } };
  const res = mockResponse();
  const options = { db, captchaSecret: "test", smtpPassword: "test", verifyCaptcha: async () => true, timestamp: () => "NOW", sendMail: async mail => { emails.push(mail); } };
  return { req, res, options, records, emails };
}
test("valid request persists, sends the correct community email, then returns reference", async () => {
  const h = harness();
  await handleDeletionRequest(h.req, h.res, h.options);
  assert.equal(h.res.statusCode, 200);
  assert.equal(h.records[0].reference, h.res.body.reference);
  assert.equal(h.records[0].status, "pending_email");
  assert.equal(h.records[0].update.status, "received");
  assert.equal(h.emails[0].to, "greenwave@example.org");
  assert.equal(h.emails[0].replyTo, base.email);
  assert.equal(h.records[0].contactPhone, base.contactPhone);
  assert.match(h.emails[0].text, /\+639998765432/);
});
test("blocks foreign origin and failed captcha without saving or emailing", async () => {
  const foreign = harness(); foreign.req.headers.origin = "https://attacker.example";
  await handleDeletionRequest(foreign.req, foreign.res, foreign.options);
  assert.equal(foreign.res.statusCode, 403); assert.equal(foreign.records.length, 0);
  const bad = harness(); bad.options.verifyCaptcha = async () => false;
  await handleDeletionRequest(bad.req, bad.res, bad.options);
  assert.equal(bad.res.statusCode, 400); assert.equal(bad.records.length, 0);
});
test("SMTP failure never falsely displays success", async () => {
  const h = harness(); h.options.sendMail = async () => { throw new Error("SMTP offline"); };
  await handleDeletionRequest(h.req, h.res, h.options);
  assert.equal(h.res.statusCode, 503);
  assert.equal(h.records[0].update.status, "email_failed");
});

// A malicious/old browser must not bypass the new frontend required attribute.
test("rejects absent phone before saving or sending support email", async () => {
  for (const phone of ["", " ", undefined]) {
    const h = harness({ ...base, phone });
    await handleDeletionRequest(h.req, h.res, h.options);
    assert.equal(h.res.statusCode, 400);
    assert.equal(h.records.length, 0);
    assert.equal(h.emails.length, 0);
  }
});

// A contact number is required even when the resident's old registered SIM is inactive.
test("rejects absent or invalid current contact phone before saving or emailing", async () => {
  for (const contactPhone of ["", " ", undefined, "1234", "not-a-number"]) {
    const h = harness({ ...base, contactPhone });
    await handleDeletionRequest(h.req, h.res, h.options);
    assert.equal(h.res.statusCode, 400);
    assert.equal(h.records.length, 0);
    assert.equal(h.emails.length, 0);
  }
});


test("rejects missing or forged community ID before sending", async () => {
  for (const communityId of ["", "A", "../other", undefined]) {
    const h = harness({ ...base, communityId });
    await handleDeletionRequest(h.req, h.res, h.options);
    assert.equal(h.res.statusCode, 400);
    assert.equal(h.emails.length, 0);
  }
});


test("legacy public form remains functional during dropdown rollout", async () => {
  const { communityId, ...legacy } = base;
  const h = harness({ ...legacy, community: "Green Wave" });
  await handleDeletionRequest(h.req, h.res, h.options);
  assert.equal(h.res.statusCode, 200);
  assert.equal(h.emails[0].to, "hominodecare@gmail.com");
  assert.equal(h.records[0].community, "Green Wave");
});
