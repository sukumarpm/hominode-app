const test = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {createCommunityCore} = require("../src/create_community");

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test("community creation and retry are atomic and idempotent", {skip: !enabled}, async () => {
  if (!getApps().length) initializeApp({projectId: "demo-hominode"});
  const db = getFirestore();
  const suffix = `${Date.now()}${Math.random().toString(16).slice(2)}`.toUpperCase();
  const uid = `admin-${suffix}`;
  const communityId = `GV-${suffix}`;
  await db.collection("admins").doc(uid).set({uid, phoneNumber: "+919876543210", role: "superAdmin", isActive: true, authorizedCommunityIds: []});
  const slug = `green-valley-${suffix.toLowerCase()}`;
  const request = {db, auth: {uid, token: {phone_number: "+919876543210", firebase: {sign_in_provider: "phone"}}}, data: {communityId, name: "Green Valley", slug}};
  const first = await createCommunityCore(request);
  const retry = await createCommunityCore(request);
  assert.equal(first.idempotent, false);
  assert.equal(retry.idempotent, true);
  const community = (await db.collection("communities").doc(communityId).get()).data();
  const admin = (await db.collection("admins").doc(uid).get()).data();
  assert.equal(community.createdBy, uid);
  assert.deepEqual(admin.authorizedCommunityIds, []);
});

test("conflicting existing community is rejected", {skip: !enabled}, async () => {
  if (!getApps().length) initializeApp({projectId: "demo-hominode"});
  const db = getFirestore();
  const suffix = `${Date.now()}${Math.random().toString(16).slice(2)}`.toUpperCase();
  const uid = `admin-${suffix}`;
  const communityId = `GV-${suffix}`;
  await db.collection("admins").doc(uid).set({uid, role: "superAdmin", isActive: true, authorizedCommunityIds: []});
  await db.collection("communities").doc(communityId).set({name: "Existing", slug: "existing", isActive: true, createdBy: "another-admin"});
  await assert.rejects(() => createCommunityCore({db, auth: {uid, token: {phone_number: "+919876543210", firebase: {sign_in_provider: "phone"}}}, data: {communityId, name: "Green Valley", slug: `green-valley-${suffix.toLowerCase()}`}}), {code: "already-exists"});
});
