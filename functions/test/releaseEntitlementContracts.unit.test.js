const test = require("node:test");
const assert = require("node:assert/strict");
const {
  getCurrentCommunityEntitlementCore,
} = require("../src/subscription_management");
const auth = {
  uid: "resident",
  token: {
    phone_number: "+639170000000",
    firebase: { sign_in_provider: "phone" },
  },
};
function fixture(
  patch = {},
  subscription = { planId: "plus", status: "active" },
) {
  const reads = [];
  const docs = {
    "users/resident": {
      uid: auth.uid,
      phoneNumber: auth.token.phone_number,
      role: "resident",
      isActive: true,
      approvalStatus: "approved",
      communityId: "A",
      ...patch,
    },
    ...(subscription ? { "subscriptions/A": subscription } : {}),
  };
  const db = {
    collection: (name) => ({
      doc: (id) => ({
        get: async () => {
          const path = `${name}/${id}`;
          reads.push(path);
          return { exists: Object.hasOwn(docs, path), data: () => docs[path] };
        },
      }),
    }),
  };
  return { db, reads };
}
test("canonical current entitlement resolves only the resident community and ignores stored permission overrides", async () => {
  const { db, reads } = fixture(
    {},
    { planId: "plus", status: "active", features: { facilityBooking: false } },
  );
  const result = await getCurrentCommunityEntitlementCore({
    db,
    auth,
    data: {},
  });
  assert.equal(result.communityId, "A");
  assert.equal(result.resolvedRole, "resident");
  assert.equal(result.features.facilityBooking, true);
  assert.deepEqual(reads, ["users/resident", "subscriptions/A"]);
  await assert.rejects(
    getCurrentCommunityEntitlementCore({
      db,
      auth,
      data: { communityId: "foreign" },
    }),
    { code: "invalid-argument" },
  );
});
test("missing subscription fails closed for an otherwise approved resident", async () => {
  const { db } = fixture({}, null);
  await assert.rejects(
    getCurrentCommunityEntitlementCore({ db, auth, data: {} }),
    { code: "failed-precondition" },
  );
});
test("inactive, pending and wrong-role residents are rejected before subscription lookup", async () => {
  for (const patch of [
    { isActive: false },
    { approvalStatus: "pending" },
    { role: "guest" },
  ]) {
    const { db, reads } = fixture(patch);
    await assert.rejects(
      getCurrentCommunityEntitlementCore({ db, auth, data: {} }),
      { code: "permission-denied" },
    );
    assert.equal(
      reads.some((path) => path.startsWith("subscriptions/")),
      false,
    );
  }
});

test("reviewed Release 1 plans include Wall without granting premium Events, bookings or Marketplace", () => {
  const { PLAN_DEFINITIONS } = require("../src/subscription_management");
  for (const plan of Object.values(PLAN_DEFINITIONS))
    assert.equal(plan.features.communityWall, true);
  for (const feature of ["events", "facilityBooking", "marketplace"])
    assert.equal(PLAN_DEFINITIONS.essential.features[feature], false);
});

for (const planId of ["essential", "plus", "pro"])
  test(`${planId}: current-community callable enables Wall using canonical subscription`, async () => {
    const { db, reads } = fixture(
      {},
      { planId, status: "active", features: { communityWall: false } },
    );
    const result = await getCurrentCommunityEntitlementCore({
      db,
      auth,
      data: {},
    });
    assert.equal(result.features.communityWall, true);
    assert.equal(result.features.marketplace, planId !== "essential");
    assert.equal(result.features.events, planId !== "essential");
    assert.deepEqual(reads, ["users/resident", "subscriptions/A"]);
  });

for (const planId of ["essential", "plus", "pro"]) {
  test(`${planId}: Wall obeys subscription lifecycle without unlocking premium features`, async () => {
    const { Timestamp } = require("firebase-admin/firestore");
    const {
      subscriptionCanUseFeature,
    } = require("../src/subscription_management");
    const now = 1000;
    const allowed = [
      { status: "active" },
      {
        status: "active",
        startsAt: Timestamp.fromMillis(now),
        endsAt: Timestamp.fromMillis(now + 1),
      },
      { status: "trial", endsAt: Timestamp.fromMillis(now + 1) },
      { status: "grace", endsAt: Timestamp.fromMillis(now + 1) },
    ];
    const denied = [
      { status: "expired" },
      { status: "suspended" },
      { status: "cancelled" },
      { status: "inactive" },
      { status: "unknown" },
      { status: null },
      { status: "active", endsAt: Timestamp.fromMillis(now) },
      { status: "active", startsAt: Timestamp.fromMillis(now + 1) },
      { status: "trial" },
      { status: "grace" },
      { status: "trial", endsAt: Timestamp.fromMillis(now) },
      { status: "grace", endsAt: Timestamp.fromMillis(now) },
    ];
    for (const [subscriptions, expected] of [
      [allowed, true],
      [denied, false],
    ]) {
      for (const fields of subscriptions) {
        const { db } = fixture({}, { planId, ...fields });
        const result = await getCurrentCommunityEntitlementCore({
          db,
          auth,
          data: {},
        });
        assert.equal(
          subscriptionCanUseFeature(result, "communityWall", now),
          expected,
        );
        for (const feature of ["marketplace", "events", "facilityBooking"]) {
          assert.equal(
            subscriptionCanUseFeature(result, feature, now),
            expected && planId !== "essential",
          );
        }
      }
    }
  });
}

test("missing and malformed subscription plans fail closed", async () => {
  for (const subscription of [
    null,
    {},
    { planId: "gold", status: "active" },
    { planId: null, status: "active" },
  ]) {
    const { db } = fixture({}, subscription);
    await assert.rejects(
      getCurrentCommunityEntitlementCore({ db, auth, data: {} }),
      { code: "failed-precondition" },
    );
  }
});

test("malformed stored dates cannot turn an active subscription into unlimited access", async () => {
  for (const field of ["startsAt", "endsAt"]) {
    for (const value of [
      "invalid-date",
      1000,
      {},
      { seconds: 1, nanoseconds: 0 },
    ]) {
      const { db } = fixture(
        {},
        { planId: "essential", status: "active", [field]: value },
      );
      await assert.rejects(
        getCurrentCommunityEntitlementCore({ db, auth, data: {} }),
        { code: "failed-precondition" },
      );
    }
  }
});

test("current entitlement rejects missing phone authentication without reading subscription data", async () => {
  for (const caller of [
    null,
    { uid: "resident" },
    {
      uid: "resident",
      token: {
        phone_number: auth.token.phone_number,
        firebase: { sign_in_provider: "password" },
      },
    },
  ]) {
    const { db, reads } = fixture();
    await assert.rejects(
      getCurrentCommunityEntitlementCore({ db, auth: caller, data: {} }),
      { code: "unauthenticated" },
    );
    assert.deepEqual(reads, []);
  }
});

test("entitlement export retains region, App Check and canonical phone-profile wrapper", () => {
  const source = require("node:fs").readFileSync(
    require.resolve("../src/index"),
    "utf8",
  );
  assert.match(
    source,
    /exports\.getCurrentCommunityEntitlement = appCheckedCallable\(\s*getCurrentCommunityEntitlementCore,/,
  );
  assert.match(source, /const REGION = ['"]asia-southeast1['"]/);
  assert.match(source, /region: REGION, enforceAppCheck: true/);
  assert.match(source, /requirePhoneAuth: !allowUnauthenticated/);
  assert.match(
    source,
    /requireCanonicalPhoneProfile: !allowUnauthenticated && !allowProfilelessPhoneAuth/,
  );
});
