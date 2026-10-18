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
