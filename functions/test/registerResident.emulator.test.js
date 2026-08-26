const test = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {registerResidentCore} = require("../src/register_resident");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test("transaction creates one profile and increments invite only once on retry", {skip: !enabled}, async () => {
  if (!getApps().length) initializeApp({projectId: "demo-hominode"});
  const db = getFirestore();
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const code = `TEST_${suffix.replace(/[^A-Z0-9_]/gi, "").toUpperCase()}`;
  const uid = `uid-${suffix}`;
  const communityId = `community-${suffix}`;
  await db.collection("communities").doc(communityId).set({name: "Test", isActive: true});
  await db.collection("communityInvites").doc(code).set({code, communityId, isActive: true, expiresAt: Timestamp.fromMillis(Date.now() + 60000), maxUses: 1, useCount: 0, usedCount: 0});
  const request = {db, auth: {uid, token: {phone_number: "+919876543210", firebase: {sign_in_provider: "phone"}}}, data: {inviteCode: code, fullName: "Resident Name", email: null, buildingReference: "Tower A", unitReference: "A-101", residentType: "owner"}};
  const first = await registerResidentCore(request);
  const retry = await registerResidentCore(request);
  assert.equal(first.idempotent, false);
  assert.equal(retry.idempotent, true);
  const invite = (await db.collection("communityInvites").doc(code).get()).data();
  const user = (await db.collection("users").doc(uid).get()).data();
  assert.equal(invite.useCount, 1);
  assert.equal(invite.usedCount, 1);
  assert.equal(user.phoneNumber, "+919876543210");
  assert.equal(user.communityId, communityId);
  assert.equal(user.role, "resident");
  assert.equal(user.isActive, false);
  assert.equal(user.approvalStatus, "pending");
});
