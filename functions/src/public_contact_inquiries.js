"use strict";

// Public product enquiries; completely separate from account deletion records.
const { randomBytes } = require("node:crypto");
const SUPPORT = "hominodecare@gmail.com";
const MAX_BODY = 8_000;
const ALLOWED_ORIGINS = new Set([
  "https://hominode.com", "https://www.hominode.com",
  "https://hominode-prod.web.app", "https://hominde-web-portfolio.web.app",
  "http://localhost:5173", "http://127.0.0.1:5173",
]);
const ALLOWED_HOSTNAMES = new Set([
  "hominode.com", "www.hominode.com", "hominode-prod.web.app",
  "hominde-web-portfolio.web.app",
]);
if (process.env.FUNCTIONS_EMULATOR === "true") {
  ALLOWED_HOSTNAMES.add("localhost");
  ALLOWED_HOSTNAMES.add("127.0.0.1");
}
class BadInput extends Error {}
function textField(data, name, max, required = true) {
  const value = data?.[name];
  if (typeof value !== "string") {
    if (!required && (value === undefined || value === null)) return "";
    throw new BadInput(`Please enter a valid ${name}.`);
  }
  const clean = value.trim().replace(/[\x00-\x1f\x7f]+/g, " ");
  if ((required && clean.length < 2) || clean.length > max) throw new BadInput(`Please enter a valid ${name}.`);
  return clean;
}
function normalizeInquiry(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new BadInput("Invalid submission.");
  if (data.website !== undefined && data.website !== "") throw new BadInput("Unable to accept submission.");
  const name = textField(data, "name", 100);
  const email = textField(data, "email", 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new BadInput("Enter a valid email address.");
  const phone = textField(data, "phone", 32);
  if (!/^[+0-9()\s.\-]{8,32}$/.test(phone) || phone.replace(/\D/g, "").length < 8 || phone.replace(/\D/g, "").length > 15) {
    throw new BadInput("Enter a valid phone number.");
  }
  const orgName = textField(data, "orgName", 140);
  const communityType = textField(data, "communityType", 80);
  const unitCount = textField(data, "unitCount", 30, false);
  const features = textField(data, "features", 900, false);
  const message = textField(data, "message", 2000, false);
  const captchaToken = textField(data, "captchaToken", 2048);
  return { name, email, phone, orgName, communityType, unitCount, features, message, captchaToken };
}
function reference(now = new Date(), random = randomBytes) {
  return `HD-INQ-${now.toISOString().slice(0, 10).replaceAll("-", "")}-${random(5).toString("hex").toUpperCase()}`;
}
function mailBody(data, ref) {
  return [
    "New Hominode website inquiry", "",
    `Reference: ${ref}`,
    `Name: ${data.name}`,
    `Email: ${data.email}`,
    `Phone: ${data.phone}`,
    `Organisation / community: ${data.orgName}`,
    `Community type: ${data.communityType}`,
    `Units: ${data.unitCount || "Not specified"}`,
    `Interested features: ${data.features || "Not specified"}`,
    `Message: ${data.message || "Not provided"}`,
    "", "Source: Hominode website inquiry form", "Category: PRODUCT INQUIRY (NOT ACCOUNT DELETION)",
  ].join("\n");
}
async function verifyCaptcha(token, secret, ip, fetchImpl = fetch) {
  const params = new URLSearchParams({ secret, response: token });
  if (ip) params.set("remoteip", ip);
  const response = await fetchImpl("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST", body: params, signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new Error("Turnstile verification service unavailable");
  const result = await response.json();
  return result.success === true && ALLOWED_HOSTNAMES.has(result.hostname) && result.action === "client_inquiry";
}
async function handleInquiry(req, res, options = {}) {
  res.set("Cache-Control", "no-store");
  res.set("X-Content-Type-Options", "nosniff");
  if (!ALLOWED_ORIGINS.has(req.headers.origin)) return res.status(403).json({ error: "Origin not allowed." });
  if (req.method !== "POST") return res.status(405).json({ error: "Use POST." });
  let data;
  try {
    if (JSON.stringify(req.body || {}).length > MAX_BODY) throw new BadInput("Submission too large.");
    data = normalizeInquiry(req.body);
  } catch (error) {
    return res.status(400).json({ error: error instanceof BadInput ? error.message : "Invalid submission." });
  }
  if (!options.captchaSecret || !options.smtpPassword) {
    console.error("Hominode website inquiry missing server-side secrets");
    return res.status(503).json({ error: "Inquiry service is temporarily unavailable." });
  }
  try {
    const valid = await (options.verifyCaptcha || verifyCaptcha)(data.captchaToken, options.captchaSecret, req.ip);
    if (!valid) return res.status(400).json({ error: "Verification failed or expired. Please retry." });
  } catch (error) {
    console.error("Website inquiry verification unavailable", error);
    return res.status(503).json({ error: "Verification is temporarily unavailable." });
  }
  const { captchaToken, ...details } = data;
  const ref = reference();
  const doc = options.db.collection("publicContactInquiries").doc(ref);
  try {
    await doc.create({ ...details, reference: ref, status: "pending_email", submittedAt: options.timestamp() });
  } catch (error) {
    console.error("Website inquiry persistence failed", error);
    return res.status(503).json({ error: "Couldn't save your inquiry. Please retry." });
  }
  try {
    await options.sendMail({
      from: `Hominode Contact <${SUPPORT}>`, to: SUPPORT, replyTo: details.email,
      subject: `[Hominode] Website inquiry ${ref}`,
      text: mailBody(details, ref),
    }, options.smtpPassword);
  } catch (error) {
    console.error("Website inquiry email failed", ref, error);
    try { await doc.update({ status: "email_failed", updatedAt: options.timestamp() }); }
    catch (updateError) { console.error(updateError); }
    return res.status(503).json({ error: "Inquiry could not be delivered. Please retry later." });
  }
  try { await doc.update({ status: "received", emailSentAt: options.timestamp() }); }
  catch (error) { console.error("Inquiry email sent but status update failed", ref, error); }
  return res.status(200).json({ status: "received", reference: ref });
}
module.exports = { BadInput, normalizeInquiry, reference, mailBody, verifyCaptcha, handleInquiry, ALLOWED_ORIGINS };
