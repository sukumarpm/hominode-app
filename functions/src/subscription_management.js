const {
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");

const {
  RegistrationError,
  verifiedPhoneAuth,
} = require("./register_resident");

const {
  normalizeCommunityId,
  requireActiveSuperAdmin,
} = require("./tenant_management");

const PLAN_DEFINITIONS = Object.freeze({
  essential: Object.freeze({
    id: "essential",
    name: "Hominode Essential",
    rank: 10,
    features: Object.freeze({
      communityManagement: true,
      buildingManagement: true,
      unitManagement: true,
      adminManagement: true,
      residentManagement: true,
      familyMembers: true,
      residentVehicles: true,
      visitorManagement: true,
      securityManagement: true,
      complaints: true,
      noticesAnnouncements: true,
      documentsCirculars: true,
      emergencySos: true,
      pushNotifications: true,
      facilityDirectory: true,
      maintenanceBilling: true,
      residentDues: true,
      paymentProofUpload: true,
      paymentVerification: true,
      paymentHistory: true,
      paymentReceipts: true,
      unitOwnershipTransfer: true,
      bankAccountGovernance: true,
      facilityBooking: false,
      events: false,
      polls: false,
      communityWall: false,
      communityMessaging: false,
      domesticStaff: false,
      marketplace: false,
      onlinePayments: false,
      automaticPaymentReconciliation: false,
      advancedAuditReports: false,
      communityAssetManagement: false,
      paidParking: false,
      manualVehicleLookup: false,
      advancedOwnershipTransfer: false,
      reportsCsv: false,
      advancedPaymentReconciliation: false,
      vendorSupplierManagement: false,
      supplierBillsPayments: false,
      advancedAssetManagement: false,
      whatsappNotifications: false,
      automatedBillReminders: false,
      emailPaymentConfirmation: false,
      anpr: false,
      advancedAnalytics: false,
      advancedGovernance: false,
      customBranding: false,
      integrationsApi: false,
    }),
    limits: Object.freeze({
      maxCommunityBankAccounts: 1,
    }),
  }),

  plus: Object.freeze({
    id: "plus",
    name: "Hominode Plus",
    rank: 20,
    features: Object.freeze({
      communityManagement: true,
      buildingManagement: true,
      unitManagement: true,
      adminManagement: true,
      residentManagement: true,
      familyMembers: true,
      residentVehicles: true,
      visitorManagement: true,
      securityManagement: true,
      complaints: true,
      noticesAnnouncements: true,
      documentsCirculars: true,
      emergencySos: true,
      pushNotifications: true,
      facilityDirectory: true,
      maintenanceBilling: true,
      residentDues: true,
      paymentProofUpload: true,
      paymentVerification: true,
      paymentHistory: true,
      paymentReceipts: true,
      unitOwnershipTransfer: true,
      bankAccountGovernance: true,
      facilityBooking: true,
      events: true,
      polls: true,
      communityWall: true,
      communityMessaging: true,
      domesticStaff: true,
      marketplace: true,
      onlinePayments: true,
      automaticPaymentReconciliation: true,
      advancedAuditReports: true,
      communityAssetManagement: true,
      paidParking: true,
      manualVehicleLookup: true,
      advancedOwnershipTransfer: true,
      reportsCsv: true,
      advancedPaymentReconciliation: false,
      vendorSupplierManagement: false,
      supplierBillsPayments: false,
      advancedAssetManagement: false,
      whatsappNotifications: false,
      automatedBillReminders: false,
      emailPaymentConfirmation: false,
      anpr: false,
      advancedAnalytics: false,
      advancedGovernance: false,
      customBranding: false,
      integrationsApi: false,
    }),
    limits: Object.freeze({
      maxCommunityBankAccounts: 2,
    }),
  }),

  pro: Object.freeze({
    id: "pro",
    name: "Hominode Pro",
    rank: 30,
    features: Object.freeze({
      communityManagement: true,
      buildingManagement: true,
      unitManagement: true,
      adminManagement: true,
      residentManagement: true,
      familyMembers: true,
      residentVehicles: true,
      visitorManagement: true,
      securityManagement: true,
      complaints: true,
      noticesAnnouncements: true,
      documentsCirculars: true,
      emergencySos: true,
      pushNotifications: true,
      facilityDirectory: true,
      maintenanceBilling: true,
      residentDues: true,
      paymentProofUpload: true,
      paymentVerification: true,
      paymentHistory: true,
      paymentReceipts: true,
      unitOwnershipTransfer: true,
      bankAccountGovernance: true,
      facilityBooking: true,
      events: true,
      polls: true,
      communityWall: true,
      communityMessaging: true,
      domesticStaff: true,
      marketplace: true,
      onlinePayments: true,
      automaticPaymentReconciliation: true,
      advancedAuditReports: true,
      communityAssetManagement: true,
      paidParking: true,
      manualVehicleLookup: true,
      advancedOwnershipTransfer: true,
      reportsCsv: true,
      advancedPaymentReconciliation: true,
      vendorSupplierManagement: true,
      supplierBillsPayments: true,
      advancedAssetManagement: true,
      whatsappNotifications: true,
      automatedBillReminders: true,
      emailPaymentConfirmation: true,
      anpr: true,
      advancedAnalytics: true,
      advancedGovernance: true,
      customBranding: true,
      integrationsApi: true,
    }),
    limits: Object.freeze({
      // V1 intentionally leaves the Pro hard cap open until pricing is final.
      maxCommunityBankAccounts: null,
    }),
  }),
});

const VALID_STATUSES = new Set([
  "trial",
  "active",
  "grace",
  "expired",
  "suspended",
  "cancelled",
]);

const hasOwn = (object, key) =>
  Object.prototype.hasOwnProperty.call(object, key);

function assertObjectWithOnlyKeys(data, allowedKeys, message) {
  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    Object.keys(data).some((key) => !allowedKeys.has(key))
  ) {
    throw new RegistrationError("invalid-argument", message);
  }
}

function normalizePlanId(value) {
  const planId = String(value ?? "").trim().toLowerCase();
  if (!PLAN_DEFINITIONS[planId]) {
    throw new RegistrationError(
      "invalid-argument",
      "Subscription plan must be essential, plus, or pro.",
    );
  }
  return planId;
}

function normalizeStatus(value, fallback = null) {
  const status = String(value ?? fallback ?? "").trim().toLowerCase();
  if (!VALID_STATUSES.has(status)) {
    throw new RegistrationError(
      "invalid-argument",
      "Unsupported subscription status.",
    );
  }
  return status;
}

function optionalNotes(value) {
  if (value == null) return null;
  const notes = String(value).trim();
  if (notes.length > 500) {
    throw new RegistrationError(
      "invalid-argument",
      "Subscription notes must be 500 characters or fewer.",
    );
  }
  return notes || null;
}

function optionalMillis(value, fieldName) {
  if (value == null) return null;
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new RegistrationError(
      "invalid-argument",
      `${fieldName} must be a positive millisecond timestamp.`,
    );
  }
  return value;
}

function validateCreateSubscriptionInput(data) {
  assertObjectWithOnlyKeys(
    data,
    new Set([
      "communityId",
      "planId",
      "status",
      "startsAtMs",
      "endsAtMs",
      "notes",
    ]),
    "Unsupported subscription creation field.",
  );

  const communityId = normalizeCommunityId(data.communityId);
  if (!communityId || communityId !== String(data.communityId ?? "").trim()) {
    throw new RegistrationError(
      "invalid-argument",
      "Enter a valid canonical community ID.",
    );
  }

  const planId = normalizePlanId(data.planId);
  const status = normalizeStatus(data.status, "active");
  const startsAtMs = optionalMillis(data.startsAtMs, "startsAtMs");
  const endsAtMs = optionalMillis(data.endsAtMs, "endsAtMs");
  const notes = optionalNotes(data.notes);

  const effectiveStartsAtMs = startsAtMs ?? Date.now();

  if (endsAtMs != null && endsAtMs <= effectiveStartsAtMs) {
    throw new RegistrationError(
      "invalid-argument",
      "endsAtMs must be later than the subscription start time.",
    );
  }

  if ((status === "trial" || status === "grace") && endsAtMs == null) {
    throw new RegistrationError(
      "invalid-argument",
      `${status} subscriptions require endsAtMs.`,
    );
  }

  return {
    communityId,
    planId,
    status,
    startsAtMs,
    endsAtMs,
    notes,
  };
}

function validatePlanChangeInput(data) {
  assertObjectWithOnlyKeys(
    data,
    new Set(["communityId", "planId", "notes"]),
    "Only communityId, planId, and notes may be changed here.",
  );
  const communityId = normalizeCommunityId(data.communityId);
  if (!communityId || communityId !== String(data.communityId ?? "").trim()) {
    throw new RegistrationError("invalid-argument", "Enter a valid canonical community ID.");
  }
  return {
    communityId,
    planId: normalizePlanId(data.planId),
    notes: optionalNotes(data.notes),
  };
}

function validateExtensionInput(data) {
  assertObjectWithOnlyKeys(
    data,
    new Set(["communityId", "endsAtMs", "notes"]),
    "Only communityId, endsAtMs, and notes may be changed here.",
  );
  const communityId = normalizeCommunityId(data.communityId);
  if (!communityId || communityId !== String(data.communityId ?? "").trim()) {
    throw new RegistrationError("invalid-argument", "Enter a valid canonical community ID.");
  }
  const endsAtMs = optionalMillis(data.endsAtMs, "endsAtMs");
  if (endsAtMs == null) {
    throw new RegistrationError("invalid-argument", "endsAtMs is required.");
  }
  return {
    communityId,
    endsAtMs,
    notes: optionalNotes(data.notes),
  };
}

function validateStatusChangeInput(data) {
  assertObjectWithOnlyKeys(
    data,
    new Set(["communityId", "status", "notes"]),
    "Only communityId, status, and notes may be changed here.",
  );
  const communityId = normalizeCommunityId(data.communityId);
  if (!communityId || communityId !== String(data.communityId ?? "").trim()) {
    throw new RegistrationError("invalid-argument", "Enter a valid canonical community ID.");
  }
  return {
    communityId,
    status: normalizeStatus(data.status),
    notes: optionalNotes(data.notes),
  };
}

function planRecord(plan) {
  return {
    id: plan.id,
    name: plan.name,
    rank: plan.rank,
    features: {...plan.features},
    limits: {...plan.limits},
    schemaVersion: 1,
    isActive: true,
  };
}

function subscriptionSummary(value) {
  if (!value) return null;
  return {
    planId: value.planId ?? null,
    status: value.status ?? null,
    startsAt: value.startsAt ?? null,
    endsAt: value.endsAt ?? null,
  };
}

function subscriptionEvent({
  communityId,
  type,
  actorUid,
  previous,
  current,
  notes,
}) {
  return {
    communityId,
    subscriptionId: communityId,
    type,
    actorUid,
    actorRole: "superAdmin",
    previous: subscriptionSummary(previous),
    current: subscriptionSummary(current),
    notes: notes ?? null,
    createdAt: FieldValue.serverTimestamp(),
    schemaVersion: 1,
  };
}

async function requireExistingCommunity(transaction, db, communityId) {
  const ref = db.collection("communities").doc(communityId);
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists) {
    throw new RegistrationError("not-found", "Community was not found.");
  }
  return snapshot.data();
}

async function requireSubscriptionViewer(db, auth, communityId) {
  const {uid} = verifiedPhoneAuth(auth);
  const snapshot = await db.collection("admins").doc(uid).get();
  const profile = snapshot.data();

  if (
    snapshot.exists &&
    profile?.uid === uid &&
    profile?.isActive === true &&
    profile?.role === "superAdmin"
  ) {
    return {uid, role: "superAdmin"};
  }

  if (
    snapshot.exists &&
    profile?.uid === uid &&
    profile?.isActive === true &&
    profile?.role === "admin" &&
    Array.isArray(profile?.authorizedCommunityIds) &&
    profile.authorizedCommunityIds.includes(communityId)
  ) {
    return {uid, role: "admin"};
  }

  throw new RegistrationError(
    "permission-denied",
    "You are not authorized to view this community subscription.",
  );
}

async function seedSubscriptionPlansCore({db, auth}) {
  const uid = await requireActiveSuperAdmin(db, auth);
  const batch = db.batch();

  for (const plan of Object.values(PLAN_DEFINITIONS)) {
    batch.set(
      db.collection("subscriptionPlans").doc(plan.id),
      {
        ...planRecord(plan),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      },
      {merge: true},
    );
  }

  await batch.commit();
  return {
    seededPlanIds: Object.keys(PLAN_DEFINITIONS),
    schemaVersion: 1,
  };
}

async function createCommunitySubscriptionCore({db, auth, data}) {
  const actorUid = await requireActiveSuperAdmin(db, auth);
  const input = validateCreateSubscriptionInput(data);
  const subscriptionRef = db.collection("subscriptions").doc(input.communityId);
  const eventRef = db.collection("subscriptionEvents").doc();

  return db.runTransaction(async (transaction) => {
    await requireExistingCommunity(transaction, db, input.communityId);
    const existing = await transaction.get(subscriptionRef);
    if (existing.exists) {
      throw new RegistrationError(
        "already-exists",
        "A subscription already exists for this community.",
      );
    }

    const startsAt = input.startsAtMs == null ? Timestamp.now() : Timestamp.fromMillis(input.startsAtMs);
    const endsAt = input.endsAtMs == null ? null : Timestamp.fromMillis(input.endsAtMs);

    const subscription = {
      communityId: input.communityId,
      planId: input.planId,
      status: input.status,
      startsAt,
      endsAt,
      schemaVersion: 1,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: actorUid,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    };

    transaction.create(subscriptionRef, subscription);
    transaction.create(
      eventRef,
      subscriptionEvent({
        communityId: input.communityId,
        type: "subscription_created",
        actorUid,
        previous: null,
        current: subscription,
        notes: input.notes,
      }),
    );

    return {
      communityId: input.communityId,
      planId: input.planId,
      status: input.status,
    };
  });
}

async function changeCommunitySubscriptionPlanCore({db, auth, data}) {
  const actorUid = await requireActiveSuperAdmin(db, auth);
  const input = validatePlanChangeInput(data);
  const subscriptionRef = db.collection("subscriptions").doc(input.communityId);
  const eventRef = db.collection("subscriptionEvents").doc();

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(subscriptionRef);
    if (!snapshot.exists) {
      throw new RegistrationError("not-found", "Community subscription was not found.");
    }
    const previous = snapshot.data();
    if (previous.planId === input.planId) {
      return {
        communityId: input.communityId,
        planId: input.planId,
        status: previous.status,
        idempotent: true,
      };
    }

    const current = {
      ...previous,
      planId: input.planId,
    };

    transaction.update(subscriptionRef, {
      planId: input.planId,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    });
    transaction.create(
      eventRef,
      subscriptionEvent({
        communityId: input.communityId,
        type: "subscription_plan_changed",
        actorUid,
        previous,
        current,
        notes: input.notes,
      }),
    );

    return {
      communityId: input.communityId,
      planId: input.planId,
      status: previous.status,
      idempotent: false,
    };
  });
}

async function extendCommunitySubscriptionCore({db, auth, data}) {
  const actorUid = await requireActiveSuperAdmin(db, auth);
  const input = validateExtensionInput(data);
  const subscriptionRef = db.collection("subscriptions").doc(input.communityId);
  const eventRef = db.collection("subscriptionEvents").doc();

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(subscriptionRef);
    if (!snapshot.exists) {
      throw new RegistrationError("not-found", "Community subscription was not found.");
    }
    const previous = snapshot.data();
    const existingEndsAtMs = previous.endsAt?.toMillis?.() ?? null;
    if (existingEndsAtMs != null && input.endsAtMs <= existingEndsAtMs) {
      throw new RegistrationError(
        "failed-precondition",
        "The new subscription end date must be later than the current end date.",
      );
    }

    const newEndsAt = Timestamp.fromMillis(input.endsAtMs);
    const current = {
      ...previous,
      endsAt: newEndsAt,
    };

    transaction.update(subscriptionRef, {
      endsAt: newEndsAt,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    });
    transaction.create(
      eventRef,
      subscriptionEvent({
        communityId: input.communityId,
        type: "subscription_extended",
        actorUid,
        previous,
        current,
        notes: input.notes,
      }),
    );

    return {
      communityId: input.communityId,
      endsAtMs: input.endsAtMs,
    };
  });
}

async function setCommunitySubscriptionStatusCore({db, auth, data}) {
  const actorUid = await requireActiveSuperAdmin(db, auth);
  const input = validateStatusChangeInput(data);
  const subscriptionRef = db.collection("subscriptions").doc(input.communityId);
  const eventRef = db.collection("subscriptionEvents").doc();

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(subscriptionRef);
    if (!snapshot.exists) {
      throw new RegistrationError("not-found", "Community subscription was not found.");
    }
    const previous = snapshot.data();

    if (
      (input.status === "trial" || input.status === "grace") &&
      previous.endsAt == null
    ) {
      throw new RegistrationError(
        "failed-precondition",
        `${input.status} status requires an existing subscription end date.`,
      );
    }

    if (previous.status === input.status) {
      return {
        communityId: input.communityId,
        status: input.status,
        idempotent: true,
      };
    }

    const current = {
      ...previous,
      status: input.status,
    };

    transaction.update(subscriptionRef, {
      status: input.status,
      statusChangedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    });
    transaction.create(
      eventRef,
      subscriptionEvent({
        communityId: input.communityId,
        type: "subscription_status_changed",
        actorUid,
        previous,
        current,
        notes: input.notes,
      }),
    );

    return {
      communityId: input.communityId,
      status: input.status,
      idempotent: false,
    };
  });
}

function toMillis(value) {
  return value?.toMillis?.() ?? null;
}

async function resolveCommunitySubscriptionCore({db, communityId}) {
  const canonicalCommunityId = normalizeCommunityId(communityId);
  if (!canonicalCommunityId) {
    throw new RegistrationError("invalid-argument", "A valid community ID is required.");
  }

  const snapshot = await db.collection("subscriptions").doc(canonicalCommunityId).get();
  if (!snapshot.exists) return null;

  const subscription = snapshot.data();
  const plan = PLAN_DEFINITIONS[subscription.planId];
  if (!plan) {
    throw new RegistrationError(
      "failed-precondition",
      "The community subscription references an unsupported plan.",
    );
  }

  return {
    communityId: canonicalCommunityId,
    planId: subscription.planId,
    planName: plan.name,
    status: subscription.status,
    startsAtMs: toMillis(subscription.startsAt),
    endsAtMs: toMillis(subscription.endsAt),
    features: {...plan.features},
    limits: {...plan.limits},
    schemaVersion: subscription.schemaVersion ?? 1,
  };
}

async function getCommunitySubscriptionCore({db, auth, data}) {
  assertObjectWithOnlyKeys(
    data,
    new Set(["communityId"]),
    "Only communityId is accepted.",
  );
  const communityId = normalizeCommunityId(data.communityId);
  if (!communityId || communityId !== String(data.communityId ?? "").trim()) {
    throw new RegistrationError("invalid-argument", "Enter a valid canonical community ID.");
  }

  await requireSubscriptionViewer(db, auth, communityId);
  return resolveCommunitySubscriptionCore({db, communityId});
}

module.exports = {
  PLAN_DEFINITIONS,
  VALID_STATUSES,
  normalizePlanId,
  normalizeStatus,
  validateCreateSubscriptionInput,
  validatePlanChangeInput,
  validateExtensionInput,
  validateStatusChangeInput,
  seedSubscriptionPlansCore,
  createCommunitySubscriptionCore,
  changeCommunitySubscriptionPlanCore,
  extendCommunitySubscriptionCore,
  setCommunitySubscriptionStatusCore,
  getCommunitySubscriptionCore,
  resolveCommunitySubscriptionCore,
};
