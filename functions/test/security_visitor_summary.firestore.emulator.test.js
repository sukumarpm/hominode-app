const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {randomUUID} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails} = require("@firebase/rules-unit-testing");
const {getSecurityVisitorSummaryCore} = require("../src/security_visitor_summary");

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = "demo-hominode-visitor-policy";
const now = Date.parse("2026-11-14T16:00:00Z"); // Community midnight on Nov 15.
let app, env, db;
test.before(async () => {
  if (!enabled) return;
  env = await initializeTestEnvironment({projectId, firestore: {
    host: "127.0.0.1", port: Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").pop()),
    rules: fs.readFileSync(`${__dirname}/../../firestore.rules`, "utf8"),
  }});
  app = initializeApp({projectId}, `summary-${randomUUID()}`);
  db = getFirestore(app);
});
test.after(async () => {
  if (app) await deleteApp(app);
  if (env) await env.cleanup();
});

async function fixture() {
  const uid = `summary-staff-${randomUUID()}`, communityId = `summary-community-${randomUUID()}`;
  const phone = "+639170000000";
  await db.collection("communities").doc(communityId).set({isActive: true, timeZone: "Asia/Manila"});
  await db.collection("securityStaff").doc(uid).set({uid, role: "security", isActive: true, phoneNumber: phone, communityId});
  const auth = {uid, token: {phone_number: phone, firebase: {sign_in_provider: "phone"}}};
  return {uid, communityId, auth, load: (data = {}) => getSecurityVisitorSummaryCore({db, auth, data, now: () => now})};
}

test("summary returns accurate uncapped totals without exposing visitor rows or requiring client reads", {skip: !enabled}, async () => {
  const f = await fixture(), batch = db.batch();
  for (let i = 0; i < 301; i++) batch.set(db.collection("visitors").doc(), {
    communityId: f.communityId, status: "inside", actualArrival: new Date(now), departure: null,
    visitorName: "Private Guest", qrToken: "private-token",
  });
  batch.set(db.collection("visitors").doc(), {communityId: f.communityId, status: "expected", isApproved: false});
  batch.set(db.collection("visitors").doc(), {communityId: f.communityId, status: "completed", actualArrival: new Date(now - 1), departure: new Date(now)});
  batch.set(db.collection("visitors").doc(), {communityId: `foreign-${randomUUID()}`, status: "inside", actualArrival: new Date(now)});
  await batch.commit();
  const result = await f.load({communityId: "forged-other-community"});
  assert.deepEqual(result, {communityId: f.communityId, timeZone: "Asia/Manila", localDate: "2026-11-15",
    refreshedAt: now, totalToday: 301, activeInside: 301, pendingRequests: 1, exitsToday: 1});
  assert.equal(JSON.stringify(result).includes("Private Guest"), false);
  assert.equal(JSON.stringify(result).includes("private-token"), false);
  const client = env.authenticatedContext(f.uid, f.auth.token).firestore();
  await assertFails(client.collection("visitors").where("communityId", "==", f.communityId).get());
});

test("authorized empty community produces real zero values", {skip: !enabled}, async () => {
  const f = await fixture(), result = await f.load();
  for (const key of ["totalToday", "activeInside", "pendingRequests", "exitsToday"]) assert.equal(result[key], 0);
});

test("staff reassignment scopes the next summary to the new trusted community", {skip: !enabled}, async () => {
  const f = await fixture();
  await db.collection("visitors").doc().set({communityId: f.communityId, status: "expected", isApproved: false});
  assert.equal((await f.load()).pendingRequests, 1);
  const next = `summary-next-${randomUUID()}`;
  await db.collection("communities").doc(next).set({isActive: true, timeZone: "America/New_York"});
  await db.collection("securityStaff").doc(f.uid).update({communityId: next});
  const result = await f.load({communityId: f.communityId});
  assert.equal(result.communityId, next);
  assert.equal(result.pendingRequests, 0);
  assert.equal(result.localDate, "2026-11-14");
});

test("revoked staff and inactive community cannot receive counts", {skip: !enabled}, async () => {
  const f = await fixture();
  await db.collection("securityStaff").doc(f.uid).update({isActive: false});
  await assert.rejects(f.load(), (error) => error.code === "permission-denied");
  await db.collection("securityStaff").doc(f.uid).update({isActive: true});
  await db.collection("communities").doc(f.communityId).update({isActive: false});
  await assert.rejects(f.load(), (error) => error.code === "permission-denied");
});

test("missing canonical timezone fails rather than substituting device or UTC dates", {skip: !enabled}, async () => {
  const f = await fixture();
  await db.collection("communities").doc(f.communityId).set({isActive: true});
  await assert.rejects(f.load(), (error) => error.code === "failed-precondition");
});
