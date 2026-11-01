"use strict";

// Public, manually reviewed account-deletion requests. Never delete a user here.
const { randomBytes } = require("node:crypto");
const SUPPORT_ADDRESS = "hominodecare@gmail.com";
const { findActiveRecipient, validateCommunityId } = require("./community_deletion_contacts");
const MAX_JSON_LENGTH = 8_000;
const ALLOWED_HOSTNAMES = new Set([
  "hominode.com", "www.hominode.com", "hominode-prod.web.app",
  "hominde-web-portfolio.web.app",
]);
if (process.env.FUNCTIONS_EMULATOR === "true") {
  ALLOWED_HOSTNAMES.add("localhost");
  ALLOWED_HOSTNAMES.add("127.0.0.1");
}
const ALLOWED_ORIGINS = new Set([
  "https://hominode.com", "https://www.hominode.com",
  "https://hominode-prod.web.app", "https://hominde-web-portfolio.web.app",
  "http://localhost:5173", "http://127.0.0.1:5173",
]);

class InputError extends Error {
  constructor(message) { super(message); this.name = "InputError"; }
}
function field(input, name, max, required = true) {
  const raw = input?.[name];
  if (typeof raw !== "string") {
    if (!required && (raw === undefined || raw === null || raw === "")) return "";
    throw new InputError(`Please enter a valid ${name}.`);
  }
  const value = raw.trim().replace(/[\r\n\t]+/g, " ");
  if ((required && value.length < 2) || value.length > max) {
    throw new InputError(`Please enter a valid ${name} (${max} characters maximum).`);
  }
  return value;
}
function normalizeRequest(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new InputError("Invalid request body.");
  }
  if (typeof input.website !== "undefined" && input.website !== "") {
    throw new InputError("Request could not be accepted."); // honeypot
  }
  if (input.confirmed !== true) throw new InputError("Confirm the deletion request first.");
  const name = field(input, "name", 100);
  const email = field(input, "email", 254);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new InputError("Enter a valid contact email.");
  const phone = field(input, "phone", 32);
  if (!/^[+0-9()\s.\-]{8,32}$/.test(phone) || !/^\+?\d/.test(phone.replace(/[()\s.\-]/g, "")) || phone.replace(/\D/g, "").length < 8 || phone.replace(/\D/g, "").length > 15) {
    throw new InputError("Enter the phone number registered to your Hominode account (8–15 digits, include country code if available).");
  }
  const contactPhone = field(input, "contactPhone", 32);
  if (!/^[+0-9()\s.\-]{8,32}$/.test(contactPhone) || !/^\+?\d/.test(contactPhone.replace(/[()\s.\-]/g, "")) || contactPhone.replace(/\D/g, "").length < 8 || contactPhone.replace(/\D/g, "").length > 15) {
    throw new InputError("Enter a current contact phone number (8–15 digits, include country code if available).");
  }
  const communityId = field(input, "communityId", 80);
  if (!validateCommunityId(communityId)) throw new InputError("Select a valid community.");
  const unit = field(input, "unit", 80);
  const captchaToken = field(input, "captchaToken", 2048);
  return { name, email, phone, contactPhone, communityId, unit, captchaToken };
}
function makeReference(clock = new Date(), random = randomBytes) {
  return `HD-DEL-${clock.toISOString().slice(0, 10).replaceAll("-", "")}-${random(5).toString("hex").toUpperCase()}`;
}
function emailBody(request, reference) {
  return [
    "A resident has submitted an account deletion request.", "",
    `Reference: ${reference}`, `Name: ${request.name}`, `Contact email: ${request.email}`,
    `Registered phone (account lookup): ${request.phone}`,
    `Current contact phone (for follow-up): ${request.contactPhone}`,
    `Community: ${request.communityName} (${request.communityId})`, `Building / unit: ${request.unit}`, "",
    "Status: AWAITING IDENTITY VERIFICATION AND MANUAL REVIEW", "",
    "This message is a request only. Do not delete an account without verifying ownership and completing required retention checks.",
  ].join("\n");
}
async function verifyCaptcha(token, secret, ip, fetchImpl = fetch) {
  const body = new URLSearchParams({ secret, response: token });
  if (ip) body.set("remoteip", ip);
  const response = await fetchImpl("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST", body, signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new Error("Captcha provider unavailable");
  const result = await response.json();
  return result.success === true && ALLOWED_HOSTNAMES.has(result.hostname) && result.action === "account_deletion";
}

async function handleDeletionRequest(req, res, options = {}) {
  res.set("Cache-Control", "no-store");
  res.set("X-Content-Type-Options", "nosniff");
  const origin = req.headers.origin;
  if (!ALLOWED_ORIGINS.has(origin)) return res.status(403).json({ error: "Origin not allowed." });
  if (req.method !== "POST") return res.status(405).json({ error: "Use POST." });
  let input;
  try {
    if (JSON.stringify(req.body || {}).length > MAX_JSON_LENGTH) throw new InputError("Request too large.");
    input = normalizeRequest(req.body);
  } catch (e) {
    return res.status(400).json({ error: e instanceof InputError ? e.message : "Invalid request." });
  }
  const captchaSecret = options.captchaSecret;
  const smtpPassword = options.smtpPassword;
  if (!captchaSecret || !smtpPassword) {
    console.error("Account deletion form is missing server-side secrets.");
    return res.status(503).json({ error: "Deletion requests are temporarily unavailable. Please try again later." });
  }
  try {
    const isHuman = await (options.verifyCaptcha || verifyCaptcha)(input.captchaToken, captchaSecret, req.ip);
    if (!isHuman) return res.status(400).json({ error: "Verification expired or failed. Please retry." });
  } catch (e) {
    console.error("Deletion request verification failed", e);
    return res.status(503).json({ error: "Verification is temporarily unavailable. Please retry." });
  }

  let recipient;
  try { recipient = await findActiveRecipient(options.db, input.communityId); }
  catch (error) { console.error("Community routing lookup failed", error); return res.status(503).json({ error: "Community routing temporarily unavailable." }); }
  if (!recipient) return res.status(400).json({ error: "Selected community is unavailable for deletion requests." });

  // Preflight succeeded; only now touch Firestore and mail transport.
  const { captchaToken, ...requestDetails } = input;
  const details = { ...requestDetails, communityName: recipient.name };
  const ref = makeReference();
  const db = options.db;
  const doc = db.collection("publicAccountDeletionRequests").doc(ref);
  try {
    await doc.create({ ...details, reference: ref, status: "pending_email", requestedAt: options.timestamp() });
  } catch (e) {
    console.error("Account deletion request persistence failed", e);
    return res.status(503).json({ error: "Request could not be saved. Please retry." });
  }

  try {
    await options.sendMail({
      from: `Hominode Account Deletion <${SUPPORT_ADDRESS}>`,
      to: recipient.email,
      replyTo: details.email,
      subject: `[Hominode] Account deletion request ${ref}`,
      text: emailBody(details, ref),
    }, smtpPassword);
  } catch (e) {
    console.error("Account deletion request email delivery failed", ref, e);
    try { await doc.update({ status: "email_failed", updatedAt: options.timestamp() }); } catch (ignored) { console.error(ignored); }
    return res.status(503).json({ error: "Could not complete submission. Please retry later." });
  }
  try { await doc.update({ status: "received", emailSentAt: options.timestamp() }); }
  catch (e) { console.error("Email delivered but status update failed", ref, e); }
  return res.status(200).json({ status: "received", reference: ref });
}
module.exports = { InputError, normalizeRequest, makeReference, emailBody, verifyCaptcha, handleDeletionRequest, ALLOWED_ORIGINS };
