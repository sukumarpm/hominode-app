const test = require("node:test");
const assert = require("node:assert/strict");

const {
  PLAN_DEFINITIONS,
  normalizePlanId,
  normalizeStatus,
  validateCreateSubscriptionInput,
  validatePlanChangeInput,
  validateExtensionInput,
  validateStatusChangeInput,
} = require("../src/subscription_management");

test("canonical plans expose the intended bank-account limits", () => {
  assert.equal(PLAN_DEFINITIONS.essential.limits.maxCommunityBankAccounts, 1);
  assert.equal(PLAN_DEFINITIONS.plus.limits.maxCommunityBankAccounts, 2);
  assert.equal(PLAN_DEFINITIONS.pro.limits.maxCommunityBankAccounts, null);
});

test("billing stays available in Essential", () => {
  const features = PLAN_DEFINITIONS.essential.features;
  assert.equal(features.maintenanceBilling, true);
  assert.equal(features.residentDues, true);
  assert.equal(features.paymentProofUpload, true);
  assert.equal(features.paymentVerification, true);
  assert.equal(features.paymentHistory, true);
  assert.equal(features.paymentReceipts, true);
  assert.equal(features.onlinePayments, false);
});

test("Plus enables online payment with normal automatic reconciliation", () => {
  assert.equal(PLAN_DEFINITIONS.plus.features.onlinePayments, true);
  assert.equal(PLAN_DEFINITIONS.plus.features.automaticPaymentReconciliation, true);
  assert.equal(PLAN_DEFINITIONS.plus.features.advancedPaymentReconciliation, false);
});

test("Pro enables advanced finance and automation features", () => {
  const features = PLAN_DEFINITIONS.pro.features;
  assert.equal(features.advancedPaymentReconciliation, true);
  assert.equal(features.vendorSupplierManagement, true);
  assert.equal(features.whatsappNotifications, true);
  assert.equal(features.anpr, true);
});

test("plan and status normalization is strict", () => {
  assert.equal(normalizePlanId(" PLUS "), "plus");
  assert.equal(normalizeStatus("ACTIVE"), "active");
  assert.throws(() => normalizePlanId("gold"), /essential, plus, or pro/);
  assert.throws(() => normalizeStatus("paused"), /Unsupported subscription status/);
});

test("create subscription defaults to active and supports no fixed end date", () => {
  const input = validateCreateSubscriptionInput({
    communityId: "COMMUNITY_1",
    planId: "essential",
  });
  assert.deepEqual(input, {
    communityId: "COMMUNITY_1",
    planId: "essential",
    status: "active",
    startsAtMs: null,
    endsAtMs: null,
    notes: null,
  });
});

test("trial and grace subscriptions require an end date", () => {
  assert.throws(
    () => validateCreateSubscriptionInput({
      communityId: "COMMUNITY_1",
      planId: "plus",
      status: "trial",
    }),
    /trial subscriptions require endsAtMs/,
  );

  assert.throws(
    () => validateCreateSubscriptionInput({
      communityId: "COMMUNITY_1",
      planId: "plus",
      status: "grace",
    }),
    /grace subscriptions require endsAtMs/,
  );
});

test("subscription date range must be forward-moving", () => {
  assert.throws(
    () => validateCreateSubscriptionInput({
      communityId: "COMMUNITY_1",
      planId: "pro",
      startsAtMs: 2000,
      endsAtMs: 1000,
    }),
    /endsAtMs must be later than the subscription start time/,
  );
});

test("mutation validators reject unexpected fields", () => {
  assert.throws(
    () => validatePlanChangeInput({
      communityId: "COMMUNITY_1",
      planId: "pro",
      price: 123,
    }),
    /Only communityId, planId, and notes/,
  );

  assert.throws(
    () => validateExtensionInput({
      communityId: "COMMUNITY_1",
    }),
    /endsAtMs is required/,
  );

  assert.deepEqual(
    validateStatusChangeInput({
      communityId: "COMMUNITY_1",
      status: "suspended",
      notes: "Manual Super Admin action",
    }),
    {
      communityId: "COMMUNITY_1",
      status: "suspended",
      notes: "Manual Super Admin action",
    },
  );
});

test("subscription end date cannot already be before the effective start", () => {
  assert.throws(
    () => validateCreateSubscriptionInput({
      communityId: "COMMUNITY_1",
      planId: "essential",
      endsAtMs: 1,
    }),
    /endsAtMs must be later than the subscription start time/,
  );
});
