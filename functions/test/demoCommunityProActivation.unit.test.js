const test = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { sosStore } = require("./helpers/sos_store");
const {
  PLAN_DEFINITIONS,
  createCommunitySubscriptionCore: create,
  getCurrentCommunityEntitlementCore: current,
  subscriptionCanUseFeature: canUse,
} = require("../src/subscription_management");

// Synthetic in-memory records only. This test never initializes an Admin SDK
// app, loads credentials, invokes a deployed callable or contacts Firestore.
const communityId = "GREEN-WAVE";
const startsAtMs = Date.now();
const endsAtMs = startsAtMs + 30 * 24 * 60 * 60 * 1000;
const input = Object.freeze({
  communityId,
  planId: "pro",
  status: "active",
  startsAtMs,
  endsAtMs,
  notes:
    "Approved Green Wave Residences client demo; 30-day Pro access; no subscription charge or renewal requested.",
});
const auth = (uid) => ({
  uid,
  token: {
    phone_number: "+639170000000",
    firebase: { sign_in_provider: "phone" },
  },
});
const snapshot = (db) => JSON.stringify([...db.values]);
function fixture() {
  const db = sosStore();
  db.values.set(`communities/${communityId}`, {
    name: "Green Wave Residences",
    slug: "green-wave",
    isActive: true,
  });
  db.values.set("admins/demo-super-admin", {
    uid: "demo-super-admin",
    role: "superAdmin",
    isActive: true,
  });
  db.values.set("admins/demo-admin", {
    uid: "demo-admin",
    role: "admin",
    isActive: true,
    authorizedCommunityIds: [communityId],
  });
  db.values.set("users/demo-resident", {
    uid: "demo-resident",
    communityId,
    role: "resident",
    isActive: true,
    approvalStatus: "approved",
  });
  db.values.set("users/other-resident", {
    uid: "other-resident",
    communityId: "OTHER-DEMO",
    role: "resident",
    isActive: true,
    approvalStatus: "approved",
  });
  db.values.set("communities/OTHER-DEMO", { isActive: true });
  db.values.set("subscriptions/OTHER-DEMO", {
    communityId: "OTHER-DEMO",
    planId: "essential",
    status: "active",
    startsAt: Timestamp.fromMillis(startsAtMs - 1),
    endsAt: null,
  });
  for (const path of [
    "bills/existing",
    "paymentProofs/existing",
    "billingSchedules/existing",
    "financialTransactions/existing",
  ])
    db.values.set(path, { sentinel: "unchanged", amount: 500 });
  for (const [path, record] of db.values) {
    if (path.startsWith("admins/") || path.startsWith("users/"))
      record.phoneNumber = auth(record.uid).token.phone_number;
  }
  return db;
}
const activate = (db, data = input, uid = "demo-super-admin") =>
  create({ db, auth: auth(uid), data });

test("existing Admin payload can omit start time while retaining a bounded end date", async () => {
  const db = fixture();
  const { startsAtMs: _omitted, ...adminPayload } = input;
  const before = Date.now();
  await activate(db, adminPayload);
  const subscription = db.values.get(`subscriptions/${communityId}`);
  assert.equal(subscription.startsAt.toMillis() >= before, true);
  assert.equal(subscription.startsAt.toMillis() <= Date.now(), true);
  assert.equal(subscription.endsAt.toMillis(), endsAtMs);
  assert.equal(
    await require("../src/phone_auth").hasCanonicalPhoneProfile(
      db,
      auth("demo-super-admin"),
    ),
    true,
  );
});

test("demo activation creates exactly one canonical subscription and audit event; other records are unchanged", async () => {
  const db = fixture(),
    before = new Map(db.values);
  assert.deepEqual(await activate(db), {
    communityId,
    planId: "pro",
    status: "active",
  });
  for (const [path, record] of before)
    assert.deepEqual(db.values.get(path), record);
  const added = [...db.values.keys()].filter((p) => !before.has(p));
  assert.equal(added.length, 2);
  assert.equal(added.includes(`subscriptions/${communityId}`), true);
  const audit = added.filter((p) => p.startsWith("subscriptionEvents/"));
  assert.equal(audit.length, 1);
  const subscription = db.values.get(`subscriptions/${communityId}`);
  assert.equal(subscription.communityId, communityId);
  assert.equal(subscription.startsAt.toMillis(), startsAtMs);
  assert.equal(subscription.endsAt.toMillis(), endsAtMs);
  assert.equal(subscription.schemaVersion, 1);
  assert.equal(subscription.createdBy, "demo-super-admin");
  assert.equal(subscription.updatedBy, "demo-super-admin");
  assert.equal(subscription.createdAt instanceof Timestamp, true);
  assert.equal(subscription.updatedAt instanceof Timestamp, true);
  const event = db.values.get(audit[0]);
  assert.equal(event.type, "subscription_created");
  assert.equal(event.communityId, communityId);
  assert.equal(event.actorRole, "superAdmin");
  assert.equal(event.notes, input.notes);
});

test("GREEN-WAVE resident resolves canonical Pro, Wall and Marketplace without changing another community", async () => {
  const db = fixture();
  await activate(db);
  const entitlement = await current({
    db,
    auth: auth("demo-resident"),
    data: {},
  });
  assert.equal(entitlement.communityId, communityId);
  assert.equal(entitlement.planId, "pro");
  assert.equal(entitlement.status, "active");
  assert.deepEqual(entitlement.features, PLAN_DEFINITIONS.pro.features);
  for (const feature of Object.keys(PLAN_DEFINITIONS.pro.features))
    assert.equal(
      canUse(entitlement, feature, startsAtMs),
      PLAN_DEFINITIONS.pro.features[feature],
    );
  assert.equal(canUse(entitlement, "communityWall", startsAtMs), true);
  assert.equal(canUse(entitlement, "marketplace", startsAtMs), true);
  const other = await current({ db, auth: auth("other-resident"), data: {} });
  assert.equal(other.planId, "essential");
  assert.equal(canUse(other, "marketplace", startsAtMs), false);
  assert.equal(canUse(other, "facilityBooking", startsAtMs), false);
  await assert.rejects(
    current({ db, auth: auth("other-resident"), data: { communityId } }),
    { code: "invalid-argument" },
  );
});

test("demo Pro expires normally even when stored status remains active", async () => {
  const db = fixture();
  await activate(db);
  const entitlement = await current({
    db,
    auth: auth("demo-resident"),
    data: {},
  });
  for (const feature of [
    "communityWall",
    "marketplace",
    "events",
    "facilityBooking",
  ]) {
    assert.equal(canUse(entitlement, feature, startsAtMs - 1), false);
    assert.equal(canUse(entitlement, feature, endsAtMs - 1), true);
    assert.equal(canUse(entitlement, feature, endsAtMs), false);
  }
});

test("repeating the same activation cannot extend dates, duplicate events or overwrite the subscription", async () => {
  const db = fixture();
  await activate(db);
  const before = snapshot(db);
  await assert.rejects(activate(db), { code: "already-exists" });
  assert.equal(snapshot(db), before);
});

test("concurrent activation attempts produce one subscription and one event", async () => {
  const db = fixture();
  const results = await Promise.allSettled([activate(db), activate(db)]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(
    results.find((r) => r.status === "rejected").reason.code,
    "already-exists",
  );
  assert.equal(
    [...db.values.keys()].filter((p) => p.startsWith("subscriptionEvents/"))
      .length,
    1,
  );
});

test("an existing expired, suspended, or different-plan record is not silently changed", async () => {
  for (const [planId, status] of [
    ["pro", "expired"],
    ["pro", "suspended"],
    ["essential", "active"],
  ]) {
    const db = fixture();
    db.values.set(`subscriptions/${communityId}`, {
      communityId,
      planId,
      status,
    });
    const before = snapshot(db);
    await assert.rejects(activate(db), { code: "already-exists" });
    assert.equal(snapshot(db), before);
  }
});

test("ordinary Admin and resident cannot activate a demo subscription", async () => {
  for (const uid of ["demo-admin", "demo-resident"]) {
    const db = fixture(),
      before = snapshot(db);
    await assert.rejects(activate(db, input, uid), {
      code: "permission-denied",
    });
    assert.equal(snapshot(db), before);
  }
});

test("missing community and invalid demo expiry fail without any writes", async () => {
  const db = fixture();
  db.values.delete(`communities/${communityId}`);
  const before = snapshot(db);
  await assert.rejects(activate(db), { code: "not-found" });
  assert.equal(snapshot(db), before);
  await assert.rejects(activate(db, { ...input, endsAtMs: startsAtMs }), {
    code: "invalid-argument",
  });
  assert.equal(snapshot(db), before);
});
