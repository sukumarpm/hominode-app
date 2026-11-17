"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { normalizeInquiry, mailBody, verifyCaptcha, handleInquiry } = require("../src/public_contact_inquiries");
const {captureConsoleErrors} = require("./helpers/capture_console_errors");
const base = {
  name: "Sample User", email: "hello@example.com", phone: "+639991234567",
  orgName: "Green Wave", communityType: "Apartment Community", unitCount: "100–250",
  features: "Resident Management", message: "Please contact me", captchaToken: "validtoken", website: "",
};
function harness(input = base, opts = {}) {
  const records = [], emails = [];
  const res = { statusCode: 200, set() { return this; }, status(n) { this.statusCode = n; return this; }, json(obj) { this.jsonBody = obj; return this; } };
  const req = { method: opts.method || "POST", headers: {origin: opts.origin || "https://hominode.com"}, ip: "127.0.0.1", body: input };
  return {
    records, emails, req, res,
    options: {
      captchaSecret: "secret", smtpPassword: "secret",
      timestamp: () => "server-time",
      verifyCaptcha: async () => true,
      db: { collection(collection) { assert.equal(collection, "publicContactInquiries"); return { doc(id) { return { async create(d) { records.push(d); }, async update(d) { Object.assign(records[0], d); } }; } }; } },
      sendMail: async (m) => { emails.push(m); },
      ...opts.options,
    },
  };
}
test("valid inquiry normalizes, strips control characters and preserves source", () => {
  const x = normalizeInquiry({ ...base, message: "Hello\r\nthere" });
  assert.equal(x.message, "Hello there");
  assert.equal(x.email, base.email);
});
test("missing required fields and malformed phones are rejected", () => {
  for (const changes of [{phone: ""}, {phone: "abc"}, {email: "abc"}, {orgName:""}, {captchaToken:""}]) {
    assert.throws(() => normalizeInquiry({ ...base, ...changes }));
  }
});
test("honeypot and oversized message are rejected", () => {
  assert.throws(() => normalizeInquiry({ ...base, website: "bot" }));
  assert.throws(() => normalizeInquiry({ ...base, message: "x".repeat(2001) }));
});
test("Turnstile checks hostname and distinct client_inquiry action", async () => {
  const response = (data) => async () => ({ ok: true, json: async () => data });
  assert.equal(await verifyCaptcha("t", "s", "1.1.1.1", response({success:true,hostname:"hominode.com",action:"client_inquiry"})), true);
  assert.equal(await verifyCaptcha("t", "s", "1.1.1.1", response({success:true,hostname:"hominode.com",action:"account_deletion"})), false);
  assert.equal(await verifyCaptcha("t", "s", "1.1.1.1", response({success:true,hostname:"evil.com",action:"client_inquiry"})), false);
});
test("successful submission creates request, sends mail, and returns reference", async () => {
  const h = harness(); await handleInquiry(h.req, h.res, h.options);
  assert.equal(h.res.statusCode, 200);
  assert.match(h.res.jsonBody.reference, /^HD-INQ-\d{8}-[A-F0-9]{10}$/);
  assert.equal(h.records.length, 1); assert.equal(h.records[0].status, "received");
  assert.equal(h.emails.length, 1); assert.equal(h.emails[0].to, "hominodecare@gmail.com");
  assert.equal(h.emails[0].replyTo, base.email);
  assert.match(mailBody(base,"HD-INQ-TEST"), /NOT ACCOUNT DELETION/);
});
test("invalid origin is refused without side effects", async () => {
  const h = harness(base, { origin:"https://not-hominode.invalid" });
  await handleInquiry(h.req,h.res,h.options);
  assert.equal(h.res.statusCode,403); assert.equal(h.records.length,0);
});
test("captcha failure blocks persistence and email", async () => {
  const h=harness(base,{ options: { verifyCaptcha: async ()=>false } });
  await handleInquiry(h.req,h.res,h.options);
  assert.equal(h.res.statusCode,400); assert.equal(h.records.length,0); assert.equal(h.emails.length,0);
});
test("SMTP failure records email_failed and does not claim success", async () => {
  const h=harness(base,{ options: { sendMail: async ()=>{ throw new Error("SMTP down"); } } });
  await handleInquiry(h.req,h.res,h.options);
  assert.equal(h.res.statusCode,503); assert.equal(h.records[0].status,"email_failed");
});

test("provider, persistence, and email exceptions are logged without exception details", async () => {
  const sensitive = "SYNTHETIC_SMTP_SECRET captcha-token synthetic-phone synthetic-email";
  const providerError = Object.assign(new Error(`${sensitive} provider response`), {
    stack: `${sensitive} stack`,
    cause: {response: {body: `${sensitive} nested response`}},
  });
  const captcha = harness(base, {options: {verifyCaptcha: async () => { throw providerError; }}});
  const captchaResult = await captureConsoleErrors(() => handleInquiry(captcha.req, captcha.res, captcha.options));
  assert.equal(captcha.res.statusCode, 503);
  assert.deepEqual(captchaResult.calls[0], ["Operational failure", {
    category: "captcha_verification_failed", operation: "captcha_verification",
  }]);

  const persistence = harness(base);
  persistence.options.db = {collection() { return {doc() { return {create: async () => { throw providerError; }}; }}; }};
  const persistenceResult = await captureConsoleErrors(() => handleInquiry(persistence.req, persistence.res, persistence.options));
  assert.equal(persistence.res.statusCode, 503);
  assert.equal(persistence.emails.length, 0);
  assert.equal(persistenceResult.calls[0][1].category, "firestore_persistence_failed");
  assert.match(persistenceResult.calls[0][1].correlationId, /^HD-INQ-\d{8}-[A-F0-9]{10}$/);

  const email = harness(base, {options: {sendMail: async () => { throw providerError; }}});
  const emailResult = await captureConsoleErrors(() => handleInquiry(email.req, email.res, email.options));
  assert.equal(email.res.statusCode, 503);
  assert.equal(email.records[0].status, "email_failed");
  assert.equal(emailResult.calls[0][1].category, "email_delivery_failed");
  assert.match(emailResult.calls[0][1].correlationId, /^HD-INQ-\d{8}-[A-F0-9]{10}$/);

  for (const result of [captchaResult, persistenceResult, emailResult]) {
    assert.doesNotMatch(JSON.stringify(result.calls), /SYNTHETIC_SMTP_SECRET|captcha-token|synthetic-phone|synthetic-email|provider response|nested response/);
  }
});

test("post-email status update failures retain success response and log a safe reference", async () => {
  const h = harness();
  h.options.db = {collection() { return {doc(id) { return {
    async create(data) { h.records.push({...data, reference: id}); },
    async update() { throw Object.assign(new Error("SYNTHETIC_STATUS_FAILURE_SECRET"), {cause: {response: "SYNTHETIC_NESTED_SECRET"}}); },
  }; }}; }};
  const result = await captureConsoleErrors(() => handleInquiry(h.req, h.res, h.options));
  assert.equal(h.res.statusCode, 200);
  assert.equal(h.emails.length, 1);
  assert.deepEqual(result.calls[0], ["Operational failure", {
    category: "email_status_update_failed", operation: "email_status_update",
    correlationId: h.records[0].reference,
  }]);
  assert.doesNotMatch(JSON.stringify(result.calls), /SYNTHETIC_STATUS_FAILURE_SECRET|SYNTHETIC_NESTED_SECRET/);
});
test("missing server secrets returns service unavailable", async () => {
  const h=harness(base,{ options: { captchaSecret: "" } });
  await handleInquiry(h.req,h.res,h.options);
  assert.equal(h.res.statusCode,503); assert.equal(h.emails.length,0);
});
